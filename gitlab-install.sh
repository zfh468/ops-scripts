#!/usr/bin/env bash
set -e

# ===========================
# 基础参数
# ===========================
GITLAB_PORT=8888
GITLAB_PROTO=http
GITLAB_HOST=$(hostname -I | awk '{print $1}')
EXTERNAL_URL="${GITLAB_PROTO}://${GITLAB_HOST}:${GITLAB_PORT}"

# ===========================
# 输出样式
# ===========================
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

info()  { echo -e "${GREEN}[INFO] $*${RESET}"; }
warn()  { echo -e "${YELLOW}[WARN] $*${RESET}"; }
error() { echo -e "${RED}[ERROR] $*${RESET}"; exit 1; }

# ===========================
# Root 检查
# ===========================
[[ $EUID -ne 0 ]] && error "请使用 root 用户运行该脚本"

# ===========================
# 系统检测
# ===========================
if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  error "无法识别操作系统"
fi

info "检测到系统：$PRETTY_NAME"
info "GitLab external_url：$EXTERNAL_URL"

# ===========================
# 防火墙放行端口
# ===========================
open_firewall_port() {
  if command -v firewall-cmd >/dev/null 2>&1; then
    firewall-cmd --permanent --add-port=${GITLAB_PORT}/tcp || true
    firewall-cmd --reload || true
  elif command -v ufw >/dev/null 2>&1; then
    ufw allow ${GITLAB_PORT}/tcp || true
  fi
}

# ===========================
# 安装依赖 & GitLab
# ===========================
if [[ "$ID" =~ (centos|rocky|almalinux|rhel) ]]; then
  info "使用 YUM 安装 GitLab"

  yum install -y curl policycoreutils openssh-server postfix
  systemctl enable sshd postfix
  systemctl start sshd postfix

  curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.rpm.sh | bash
  EXTERNAL_URL="${EXTERNAL_URL}" yum install -y gitlab-ce

elif [[ "$ID" =~ (ubuntu|debian) ]]; then
  info "使用 APT 安装 GitLab"

  apt update
  apt install -y curl openssh-server ca-certificates postfix

  curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash
  EXTERNAL_URL="${EXTERNAL_URL}" apt install -y gitlab-ce

else
  error "不支持的系统：$ID"
fi

# ===========================
# GitLab 低内存优化
# ===========================
info "应用低内存优化配置"

cat >> /etc/gitlab/gitlab.rb <<EOF

# ==== Low Memory Optimization ====
puma['worker_processes'] = 2
sidekiq['concurrency'] = 5

prometheus_monitoring['enable'] = false
alertmanager['enable'] = false
node_exporter['enable'] = false
postgres_exporter['enable'] = false
redis_exporter['enable'] = false
EOF

# ===========================
# 重新配置 & 启动
# ===========================
info "重新生成 GitLab 配置（可能需要几分钟）"
gitlab-ctl reconfigure

info "启动 GitLab"
gitlab-ctl restart

open_firewall_port

# ===========================
# 完成提示
# ===========================
info "GitLab 安装完成 🎉"
info "访问地址：${EXTERNAL_URL}"
info "查看日志：gitlab-ctl tail puma"
info "查看初始密码命令：sudo cat /etc/gitlab/initial_root_password"