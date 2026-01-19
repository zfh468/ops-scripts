#!/usr/bin/env bash
# -----------------------------------------------------------------------------------------------------
# MySQL 安装脚本（兼容 AlmaLinux 10 / RHEL 10）
#
# 功能：
#   1. 使用 MySQL 官方 RPM 源安装 MySQL 8.4
#   2. 适配 dnf 包管理器
#   3. 初始化日志目录与权限
#   4. 配置系统资源限制
#   5. 启动 mysqld 并输出初始 root 密码
#
# 适用系统：
#   - AlmaLinux 10
#   - Rocky Linux 10
#   - RHEL 10
#
# -----------------------------------------------------------------------------------------------------

# ------------------------------------------------------------------------------ env

# ---------- color
# 颜色定义（日志美化）

export ENV_COLOR_RED="\033[0;31m"
export ENV_COLOR_GREEN="\033[1;32m"
export ENV_COLOR_YELLOW="\033[1;33m"
export ENV_COLOR_BLUE="\033[0;34m"
export ENV_COLOR_RESET="$(tput sgr0)"

# ---------- status code 
# 状态码
export ENV_SUCCEED=0
export ENV_FAILED=1

# ------------------------------------------------------------------------------ functions
# 输出函数

printInfo() {
    echo -e "${ENV_COLOR_GREEN}[INFO] $@${ENV_COLOR_RESET}"
}

printWarn() {
    echo -e "${ENV_COLOR_YELLOW}[WARN] $@${ENV_COLOR_RESET}"
}

printError() {
    echo -e "${ENV_COLOR_RED}[ERROR] $@${ENV_COLOR_RESET}"
}

blueOutput() {
    echo -e "${ENV_COLOR_BLUE}$@${ENV_COLOR_RESET}"
}

# ------------------------------------------------------------------------------ main
# 开始安装MySQL

printInfo ">>>> Install MySQL begin"

# ---------- 必须使用 root
if [[ $EUID -ne 0 ]]; then
    printError "Please run this script as root"
    exit 1
fi

# ---------- 依赖检查
for cmd in wget rpm dnf systemctl; do
    command -v ${cmd} >/dev/null 2>&1 || {
        printError "Require ${cmd} but it is not installed"
        exit 1
    }
done

# ------------------------------------------------------------------------------ MySQL Repo
# 使用MySQL官方RPM包安装MySQL

printInfo ">>>> Install MySQL official repository"

MYSQL_REPO_RPM="mysql84-community-release-el10-2.noarch.rpm"

if [[ ! -f ${MYSQL_REPO_RPM} ]]; then
    wget https://dev.mysql.com/get/${MYSQL_REPO_RPM}
fi

rpm -Uvh ${MYSQL_REPO_RPM}

# ------------------------------------------------------------------------------ Install MySQL

printInfo ">>>> Install mysql-community-server"

dnf -y install mysql-community-server

# ------------------------------------------------------------------------------ configure my.cnf

# 作者维护的 my.cnf 地址：https://gitee.com/turnon/linux-tutorial/raw/master/codes/linux/soft/config/mysql/my.cnf

# 配置 my.cnf

printInfo ">>>> Configure my.cnf"

[[ -f /etc/my.cnf ]] && cp /etc/my.cnf /etc/my.cnf.bak.$(date +%F)

cat >/etc/my.cnf <<EOF
[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
log-error=/var/log/mysql/mysql.log
slow_query_log=ON
slow_query_log_file=/var/log/mysql/mysql_slow_query_log.log
pid-file=/var/run/mysqld/mysqld.pid
character-set-server=utf8mb4
skip-name-resolve

[client]
socket=/var/lib/mysql/mysql.sock
EOF

# ------------------------------------------------------------------------------ Log dir

printInfo ">>>> Create MySQL log directory"

mkdir -p /var/log/mysql
touch /var/log/mysql/mysql.log
touch /var/log/mysql/mysql_slow_query_log.log

chown -R mysql:mysql /var/log/mysql
chmod 640 /var/log/mysql/*.log

# ------------------------------------------------------------------------------ limits
# 设置系统资源限制，高并发情况下 MySQL 很容易 hit Too many open files

printInfo ">>>> Set system limits for mysql"

grep -q "^mysql.*nofile" /etc/security/limits.conf || cat >> /etc/security/limits.conf <<EOF
mysql soft nofile 65536
mysql hard nofile 65536
EOF

# ------------------------------------------------------------------------------ SELinux

printWarn ">>>> Disable SELinux (recommended for learning environment)"

setenforce 0 2>/dev/null || true
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

# ------------------------------------------------------------------------------ Start MySQL

printInfo ">>>> Enable and start mysqld"

systemctl daemon-reload
systemctl enable mysqld
systemctl start mysqld

# ------------------------------------------------------------------------------ Password

printInfo ">>>> Fetch MySQL temporary root password"

MYSQL_LOG="/var/log/mysql/mysql.log"
sleep 3

ROOT_PASS=$(grep "temporary password" ${MYSQL_LOG} | awk '{print $NF}')

blueOutput "MySQL temporary root password:"
blueOutput "${ROOT_PASS}"

printInfo "<<<< Install MySQL success"
