#!/bin/bash

# ========================================
# system: AlmaLinux 10.1 
# @author: zfh468
# description: 安装 PostgreSQL 并初始化数据库
# usage: sh posrgresql18_install.sh
# ========================================

# 设置 PostgreSQL 版本
PG_VERSION=18

# 更新系统
echo "更新系统..."
sudo dnf update -y

# 安装必要工具
echo "安装必要工具..."
sudo dnf install -y dnf-utils

# 添加 PostgreSQL 官方仓库
echo "添加 PostgreSQL 官方仓库..."
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# 禁用默认模块仓库
echo "禁用默认 PostgreSQL 模块..."
sudo dnf -qy module disable postgresql

# 安装 PostgreSQL
echo "安装 PostgreSQL $PG_VERSION..."
sudo dnf install -y postgresql${PG_VERSION}-server postgresql${PG_VERSION}-contrib postgresql${PG_VERSION}-libs

# 初始化数据库
echo "初始化数据库..."
sudo /usr/pgsql-${PG_VERSION}/bin/postgresql-${PG_VERSION}-setup initdb

# 启动 PostgreSQL 并设置开机自启
echo "启动 PostgreSQL 服务..."
sudo systemctl enable postgresql-${PG_VERSION}
sudo systemctl start postgresql-${PG_VERSION}

# 检查服务状态
sudo systemctl status postgresql-${PG_VERSION} --no-pager


echo "======================================="
echo "PostgreSQL $PG_VERSION 安装完成！"
echo "默认用户: postgres"
echo "使用: sudo -i -u postgres psql 查看是否安装成功！"
echo "如果想退出postgresql提示符，输入： \q 命令"
echo "======================================="
