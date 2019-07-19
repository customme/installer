#!/bin/bash
#
# Author: superz
# Date: 2018-09-30
# Description: 公共配置信息


# 集群配置信息
# ip hostname admin_user admin_passwd roles
HOSTS="192.168.30.120 cdh1 root Xs.admin! cm-server,cm-agent
192.168.30.21 cdh2 root Xs.admin! cm-agent,database
192.168.30.22 cdh3 root Xs.admin! cm-agent
192.168.30.23 cdh4 root Xs.admin! cm-agent
192.168.30.24 cdh5 root Xs.admin! cm-agent"

# 时间服务器
TIME_SERVER=1.asia.pool.ntp.org

# ssh端口
SSH_PORT=22

# 网卡(获取IP用)
NETCARDS=(eno1 ens3 ens33 ens192)

# 组件版本
JAVA_VERSION=1.8.0_211

# 软件包目录
PKG_DIR=/usr/local/src

# jdk安装包
JAVA_NAME=jdk${JAVA_VERSION}
JAVA_PKG=jdk-8u211-linux-x64.tar.gz

# scala安装包
SCALA_NAME=scala-${SCALA_VERSION}
SCALA_PKG=${SCALA_NAME}.tgz
# scala安装包下载地址
SCALA_URL=http://downloads.lightbend.com/scala/${SCALA_VERSION}/${SCALA_NAME}.tgz

# 安装目录
BASE_INSTALL_DIR=/usr
JAVA_INSTALL_DIR=$BASE_INSTALL_DIR/java

# 环境变量
JAVA_HOME=$JAVA_INSTALL_DIR/current
