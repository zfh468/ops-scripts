#!/usr/bin/env bash
# ============================================================
#  Ansible Full Auto Installer (Universal Linux)
#  Author: zfh468
#  Usage : bash install_ansible.sh
# ============================================================

set -e

LOG_FILE="/var/log/ansible_install.log"
exec > >(tee -a ${LOG_FILE}) 2>&1

echo "========== Ansible 自动化部署开始 =========="

# 必须 root
if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] 请使用 root 用户执行"
    exit 1
fi

# 系统识别
OS=""
PM=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
fi

case "$OS" in
    centos|rhel|rocky|almalinux)
        PM="yum"
        ;;
    ubuntu|debian)
        PM="apt"
        ;;
    *)
        echo "[ERROR] 不支持的系统: $OS"
        exit 1
        ;;
esac

echo "[INFO] 系统识别成功: $OS / 包管理器: $PM"

# 安装基础依赖
install_base_packages() {
    echo "[INFO] 安装基础依赖..."
    if [ "$PM" = "yum" ]; then
        yum install -y epel-release || true
        yum install -y python3 python3-pip sshpass git curl
    else
        apt update -y
        apt install -y python3 python3-pip sshpass git curl
    fi
}

# 升级 pip
upgrade_pip() {
    echo "[INFO] 升级 pip..."
    python3 -m pip install --upgrade pip
}

# 安装 Ansible
install_ansible() {
    echo "[INFO] 安装 Ansible..."

    if [ "$PM" = "yum" ]; then
        yum install -y ansible || {
            echo "[WARN] yum 安装失败，切换 pip 安装"
            pip3 install ansible
        }
    else
        apt install -y ansible || {
            echo "[WARN] apt 安装失败，切换 pip 安装"
            pip3 install ansible
        }
    fi
}

# 校验安装
verify() {
    echo "[INFO] 校验 Ansible 安装状态..."
    ansible --version || {
        echo "[ERROR] Ansible 安装失败"
        exit 1
    }
}

# 执行流程
install_base_packages
upgrade_pip
install_ansible
verify

echo "========== Ansible 安装完成 =========="
ansible --version
