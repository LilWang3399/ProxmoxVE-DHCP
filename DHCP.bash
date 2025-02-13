#!/bin/bash
# PVE多网卡网络配置脚本
# 支持混合模式（DHCP/静态IP）和跨平台配置
# 版本：3.0

#==================== 用户配置 ====================
declare -A NET_CONFIG=(
    # 格式： [网卡名称]="模式|IP/掩码|网关|DNS服务器"
    # 模式：dhcp 或 static
    # 例1：DHCP配置
    ["ens18"]="dhcp"
    
    # 例2：静态IP配置（DNS用空格分隔）
    ["ens19"]="static|192.168.2.100/24|192.168.2.1|8.8.8.8 1.1.1.1"
    
    # 例3：仅IP配置（无网关和DNS）
    ["ens20"]="static|10.0.0.5/24"
)

VM_ID="100"                    # 虚拟机ID
VM_USER="root"                # 虚拟机登录用户
VM_SSH_KEY="/path/to/ssh_key"  # SSH私钥路径

#==================== 函数定义 ====================
check_status() {
  if [ $? -ne 0 ]; then
    echo "[错误] 操作失败: $1"
    exit 1
  fi
}

validate_input() {
  local iface=$1
  local config=(${2//|/ })
  
  case ${config[0]} in
    "dhcp")
      echo "接口 $iface 配置为DHCP模式"
      ;;
    "static")
      if [[ ! "${config[1]}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        echo "[错误] 无效的IP格式: ${config[1]}"
        exit 1
      fi
      echo "接口 $iface 配置为静态IP: ${config[1]}"
      ;;
    *)
      echo "[错误] 未知模式: ${config[0]}"
      exit 1
      ;;
  esac
}

#==================== 主程序 ====================
# 检查虚拟机状态
VM_STATUS=$(qm status $VM_ID | awk '{print $2}')
[ "$VM_STATUS" = "running" ] || check_status "虚拟机未运行"

# 获取当前IP信息
echo "当前网络配置:"
qm guest exec $VM_ID -- ip -brief address show | while read line; do
  echo "  $line"
done

# 遍历配置每个接口
for interface in "${!NET_CONFIG[@]}"; do
  echo -e "\n正在配置接口 $interface ..."
  config=${NET_CONFIG[$interface]}
  validate_input $interface "$config"
  
  ssh -i $VM_SSH_KEY $VM_USER@$(qm guest ip $VM_ID) <<EOF
  if [ -d /etc/netplan ]; then
    # Ubuntu/Debian配置
    CONFIG_FILE="/etc/netplan/multi-${interface}.yaml"
    IFS='|' read -r mode ip gateway dns <<< "$config"
    
    if [ "\$mode" = "dhcp" ]; then
      sudo tee \$CONFIG_FILE > /dev/null <<NETPLAN
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      dhcp4: true
NETPLAN
    else
      sudo tee \$CONFIG_FILE > /dev/null <<NETPLAN
network:
  version: 2
  ethernets:
    $interface:
      addresses: [${ip}]
      $( [ -n "$gateway" ] && echo "gateway4: ${gateway}" )
      nameservers:
        addresses: [${dns:-8.8.8.8}]
NETPLAN
    fi
    sudo netplan apply

  elif [ -f /etc/redhat-release ]; then
    # RHEL/CentOS配置
    CONFIG_FILE="/etc/sysconfig/network-scripts/ifcfg-${interface}"
    IFS='|' read -r mode ip gateway dns <<< "$config"
    
    sudo tee \$CONFIG_FILE > /dev/null <<IFCFG
DEVICE=$interface
ONBOOT=yes
NM_CONTROLLED=no
$( [ "\$mode" = "dhcp" ] && echo "BOOTPROTO=dhcp" || echo """
BOOTPROTO=static
IPADDR=${ip%/*}
PREFIX=${ip#*/}
$( [ -n "$gateway" ] && echo "GATEWAY=$gateway" )
$( [ -n "$dns" ] && echo "DNS1=${dns%% *}" )
$( [ -n "$dns" ] && echo "DNS2=${dns##* }" ) 
""" )
IFCFG
    sudo nmcli dev reapply $interface

  else
    echo "不支持的发行版"
    exit 1
  fi
EOF
  check_status "接口 $interface 配置失败"
done

echo -e "\n最终网络配置验证:"
qm guest exec $VM_ID -- ip -brief address show
