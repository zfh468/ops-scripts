#!/bin/bash
# ==========================================================
# Interactive Redis Source Install Script
# OS      : AlmaLinux 10.1
# Mode    : daemonize + systemd (forking)
# Author  : zfh468
# ==========================================================

set -e

# ---------------- 基础变量 ----------------
DEFAULT_REDIS_VERSION="8.4.0"
DEFAULT_PORT="6379"

PREFIX="/usr/local/redis"
CONF_DIR="${PREFIX}/etc"
DATA_DIR="/data/redis"
LOG_DIR="/var/log/redis"
REDIS_USER="redis"

# ---------------- root 检查 ----------------
if [ "$(id -u)" -ne 0 ]; then
    echo " 请使用 root 用户执行该脚本"
    exit 1
fi

echo "=========================================="
echo " Redis 编译安装脚本（交互式）"
echo "=========================================="

# ---------------- 交互输入 ----------------
read -p "请输入要安装的 Redis 版本 [默认: ${DEFAULT_REDIS_VERSION}]: " REDIS_VERSION
REDIS_VERSION=${REDIS_VERSION:-$DEFAULT_REDIS_VERSION}

read -p "请输入 Redis 监听端口 [默认: ${DEFAULT_PORT}]: " REDIS_PORT
REDIS_PORT=${REDIS_PORT:-$DEFAULT_PORT}

read -s -p "请输入 Redis 密码（不输入表示不设置密码）: " REDIS_PASSWORD
echo

echo
echo " 安装信息确认："
echo "------------------------------------------"
echo " Redis 版本 : ${REDIS_VERSION}"
echo " Redis 端口 : ${REDIS_PORT}"
echo " Redis 密码 : $( [ -z "$REDIS_PASSWORD" ] && echo "未设置" || echo "已设置" )"
echo "------------------------------------------"
read -p "确认开始安装？[y/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "已取消安装"
    exit 0
fi

# ---------------- 安装依赖 ----------------
echo "[1/11] 安装依赖..."
dnf install -y gcc gcc-c++ make wget tar systemd-devel

# ---------------- redis 用户 ----------------
if ! id redis &>/dev/null; then
    echo "[2/11] 创建 redis 用户..."
    useradd -r -s /sbin/nologin redis
fi

# ---------------- 下载源码 ----------------
cd /usr/local/src
if [ ! -f redis-${REDIS_VERSION}.tar.gz ]; then
    echo "[3/11] 下载 Redis ${REDIS_VERSION}..."
    wget https://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz
fi

# ---------------- 编译安装 ----------------
echo "[4/11] 编译 Redis..."
tar xf redis-${REDIS_VERSION}.tar.gz
cd redis-${REDIS_VERSION}
make -j$(nproc)
make PREFIX=${PREFIX} install

# ---------------- 目录准备 ----------------
echo "[5/11] 创建目录..."
mkdir -p ${CONF_DIR} ${DATA_DIR} ${LOG_DIR}

cp redis.conf ${CONF_DIR}/redis.conf

# ---------------- 配置备份 ----------------
echo "[6/11] 备份 redis.conf..."
cp ${CONF_DIR}/redis.conf ${CONF_DIR}/redis.conf.bak

# ---------------- 修改配置 ----------------
echo "[7/11] 修改 redis.conf..."

sed -i \
    -e "s/^daemonize no/daemonize yes/" \
    -e "s/^port .*/port ${REDIS_PORT}/" \
    -e "s|^dir .*|dir ${DATA_DIR}|" \
    -e "s/^bind .*/bind 0.0.0.0/" \
    -e "s|^logfile .*|logfile ${LOG_DIR}/redis.log|" \
    -e "s/^appendonly no/appendonly yes/" \
    ${CONF_DIR}/redis.conf

# 设置密码（如果输入了）
if [ -n "$REDIS_PASSWORD" ]; then
    sed -i "s/^# requirepass .*/requirepass ${REDIS_PASSWORD}/" \
        ${CONF_DIR}/redis.conf
fi

# ---------------- 权限 ----------------
chown -R ${REDIS_USER}:${REDIS_USER} \
    ${PREFIX} \
    ${DATA_DIR} \
    ${LOG_DIR}

# ---------------- systemd ----------------
echo "[8/11] 创建 systemd 服务..."

cat > /etc/systemd/system/redis.service <<EOF
[Unit]
Description=Redis In-Memory Data Store
After=network.target

[Service]
Type=forking
User=${REDIS_USER}
Group=${REDIS_USER}
ExecStart=${PREFIX}/bin/redis-server ${CONF_DIR}/redis.conf
ExecStop=${PREFIX}/bin/redis-cli -p ${REDIS_PORT} shutdown
Restart=always
LimitNOFILE=100000

[Install]
WantedBy=multi-user.target
EOF

# ---------------- 启动 ----------------
echo "[9/11] 启动 Redis..."
systemctl daemon-reload
systemctl enable redis
systemctl start redis

# ---------------- 验证 ----------------
echo "[10/11] 服务状态："
systemctl status redis --no-pager

# ---------------- firewalld 放行端口 ----------------
echo "[11/12] 配置 firewalld 防火墙规则..."

if systemctl list-unit-files | grep -q firewalld.service; then
    if systemctl is-active --quiet firewalld; then
        echo "检测到 firewalld 正在运行，放行 Redis 端口 ${REDIS_PORT}..."

        firewall-cmd --permanent --add-port=${REDIS_PORT}/tcp
        firewall-cmd --reload

        echo " firewalld 已放行端口 ${REDIS_PORT}/tcp"
    else
        echo " firewalld 已安装但未运行，跳过防火墙配置"
    fi
else
    echo " 系统未安装 firewalld，跳过防火墙配置"
fi

# ---------------- 使用说明 ----------------
echo
echo "=========================================="
echo "  Redis 安装完成"
echo "=========================================="
echo "▶ Redis 版本    : ${REDIS_VERSION}"
echo "▶ 监听端口      : ${REDIS_PORT}"
echo "▶ 安装路径      : ${PREFIX}"
echo "▶ 配置文件      : ${CONF_DIR}/redis.conf"
echo "▶ 备份配置      : ${CONF_DIR}/redis.conf.bak"
echo "▶ 数据目录      : ${DATA_DIR}"
echo "▶ 日志文件      : ${LOG_DIR}/redis.log"
echo
echo "▶ 常用命令："
echo "  systemctl start redis"
echo "  systemctl stop redis"
echo "  systemctl restart redis"
echo
echo "▶ 连接 Redis："
if [ -n "$REDIS_PASSWORD" ]; then
    echo "  ${PREFIX}/bin/redis-cli -p ${REDIS_PORT} -a <密码>"
else
    echo "  ${PREFIX}/bin/redis-cli -p ${REDIS_PORT}"
fi
echo
echo "▶ 如果嫌输入绝对路径使用redis-cli和redis-server麻烦，可以使用链接："
echo "  ln -sf /usr/local/redis/bin/redis-server /usr/local/bin/redis-server"
echo "  ln -sf /usr/local/redis/bin/redis-cli    /usr/local/bin/redis-cli"
echo
echo "=========================================="
