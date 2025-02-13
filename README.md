# Proxmox VE 虚拟机网络配置自动化脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
![Shell Script](https://img.shields.io/badge/Shell_Script-89E051?style=flat&logo=gnu-bash&logoColor=white)

专为 Proxmox VE 设计的智能网络配置工具，支持多网卡混合模式（静态IP/DHCP）和定时任务功能。

## 📦 功能特性

- **多模式支持**  
  ✅ 静态IP配置 ✅ DHCP自动获取 ✅ 混合模式部署
- **跨平台兼容**  
  📌 Debian/Ubuntu (netplan) 📌 RHEL/CentOS (NetworkManager)
- **企业级功能**  
  🔒 SSH密钥认证 📈 操作审计日志 🔄 失败回滚机制
- **扩展能力**  
  ⏰ 定时任务支持 🖇️ Ansible集成准备 🐳 Docker化部署（开发中）

## 🚀 快速开始

### 前置要求
- Proxmox VE 6.0+
- qemu-guest-agent 已安装
- 目标虚拟机开启SSH服务

### 安装步骤
```bash
# 克隆仓库
git clone https://github.com/LilWang3399/ProxmoxVE-DHCP/DHCP.bash
cd DHCP

# 设置执行权限
chmod +x change_vm_ip.sh

# 复制示例配置文件
cp config.example.sh user.config.sh
