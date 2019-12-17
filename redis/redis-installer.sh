#!/bin/bash
#
# 日期: 2018-09-04
# redis安装运维手册


REDIS_VERSION=4.0.11
REDIS_NAME=redis-$REDIS_VERSION
REDIS_PKG=${REDIS_NAME}.tar.gz
REDIS_URL=http://download.redis.io/releases/$REDIS_PKG


# 安装
function install()
{
    if [[ ! -s $REDIS_PKG ]]; then
        wget $REDIS_URL
    fi

    # 安装依赖
    yum install -y make gcc

    tar -zxf $REDIS_PKG
    cd $REDIS_NAME
    make
    make install PREFIX=/usr/local/redis
}

# 管理
function admin()
{
    redis-server redis.conf          # 启动redis服务
    pkill redis-server               # 关闭redis服务
    redis-cli -h host -p port        # 启动redis客户端
    redis-cli -h host -p port cmd    # 执行命令
    redis-cli -r 3 -i 1 ping         # 每隔1秒执行一次命令重复3次
}
