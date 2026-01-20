#!/usr/bin/env bash
# MongoDB binary install script
# Author: zfh468
# Support: All Linux distributions

###################################################################################
# 控制台颜色定义
###################################################################################
BLACK="\033[1;30m"
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
CYAN="\033[1;36m"
RESET="$(tput sgr0)"
###################################################################################

printf "${BLUE}"
cat << EOF

###################################################################################
# MongoDB 安装脚本（Binary 方式）
# - 自动创建 mongod 系统用户
# - 自动配置 PATH（/etc/profile.d）
# - 当前 shell 立即生效
###################################################################################

EOF
printf "${RESET}"

printf "${GREEN}>>>>>>>> install mongodb begin.${RESET}\n"

###################################################################################
# 脚本参数
###################################################################################
if [[ $# -lt 1 ]] || [[ $# -lt 2 ]]; then
  printf "${PURPLE}[Hint]\n"
  printf "\t sh mongodb-install.sh [version] [path]\n"
  printf "\t Example: sh mongodb-install.sh rhel93-8.2.3 /usr/local/mongodb\n"
  printf "${RESET}\n"
fi

###################################################################################
# 参数处理
###################################################################################
version="rhel93-8.2.3"
[[ -n $1 ]] && version="$1"

path="/usr/local/mongodb"
[[ -n $2 ]] && path="$2"

printf "${PURPLE}[Info]\n"
printf "\t version = %s\n" "$version"
printf "\t path    = %s\n" "$path"
printf "${RESET}\n"

###################################################################################
# 必须使用 root
###################################################################################
if [[ $EUID -ne 0 ]]; then
  printf "${RED}[Error] Please run this script as root.${RESET}\n"
  exit 1
fi

###################################################################################
# 创建 mongod 系统用户（如不存在）
###################################################################################
if ! id mongod &>/dev/null; then
  useradd -r -s /sbin/nologin mongod
  printf "${GREEN}[OK] system user 'mongod' created.${RESET}\n"
else
  printf "${YELLOW}[Info] system user 'mongod' already exists.${RESET}\n"
fi

###################################################################################
# 下载并解压 MongoDB
###################################################################################
mkdir -p "${path}"

PKG="mongodb-linux-x86_64-${version}.tgz"
URL="https://fastdl.mongodb.org/linux/${PKG}"

curl -fLo "${path}/${PKG}" "${URL}" || {
  printf "${RED}[Error] download failed.${RESET}\n"
  exit 1
}

tar zxf "${path}/${PKG}" -C "${path}"

MONGO_HOME="${path}/mongodb-linux-x86_64-${version}"

###################################################################################
# 创建数据和日志目录，并设置权限
###################################################################################
mkdir -p /var/lib/mongo /var/log/mongo
chown -R mongod:mongod /var/lib/mongo /var/log/mongo

###################################################################################
# 配置 PATH（/etc/profile.d）
###################################################################################
PROFILE_FILE="/etc/profile.d/mongodb.sh"

cat > "${PROFILE_FILE}" << EOF
# MongoDB environment variables
export MONGO_HOME=${MONGO_HOME}
export PATH=\$MONGO_HOME/bin:\$PATH
EOF

chmod 644 "${PROFILE_FILE}"

printf "${GREEN}[OK] MongoDB PATH configured: ${PROFILE_FILE}${RESET}\n"
# source，方便检查安装输出，但是还需要自己手动source，系统会使用一个子shell运行脚本，脚本里的export和source命令只在子shell生效
# 当子shell执行完退出，返回你原来的shell，原来的shell的环境变量没有变化
source /etc/profile.d/mongodb.sh


###################################################################################
# 检查安装
###################################################################################
printf "${PURPLE}[Check]\n"
printf "\t mongod  : %s\n" "$(which mongod)"
printf "\t mongos  : %s\n" "$(which mongos)"
printf "${RESET}\n"

mongod --version | head -n 1

printf "${GREEN}<<<<<<<< install mongodb end.${RESET}\n"
###################################################################################
printf "please input this follow command: \n"
printf " source /etc/profile.d/mongodb.sh \n"

printf "${GREEN}[OK] MongoDB environment loaded into current shell.${RESET}\n"