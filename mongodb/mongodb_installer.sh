#!/bin/bash
#
# 日期: 2018-09-04
# mongodb 安装运维手册


# mongodb 集群配置信息
# ip hostname admin_user admin_passwd owner_passwd roles
HOSTS="192.168.1.227 dc-1-227 root 123456 123456 config,mongos,primary-shard1:22001,arbiter-shard2:22002,shard3:22003
192.168.1.229 dc-1-229 root 123456 123456 config,mongos,shard1:22001,primary-shard2:22002,arbiter-shard3:22003
192.168.1.230 dc-1-230 root 123456 123456 config,mongos,arbiter-shard1:22001,shard2:22002,primary-shard3:22003"

# mongodb 版本
MONGODB_VERSION=4.0.2
# mongodb 安装包名
MONGODB_NAME=mongodb-linux-x86_64-amazon2-${MONGODB_VERSION}
MONGODB_PKG=${MONGODB_NAME}.tgz
# mongodb 下载地址
MONGODB_URL=https://fastdl.mongodb.org/linux/$MONGODB_PKG

# 用户/组
MONGODB_USER=mongodb
MONGODB_GROUP=mongodb

# 相关目录
MONGODB_HOME=/usr/mongodb/current
MONGODB_INSTALL_DIR=`dirname $MONGODB_HOME`
MONGODB_CONF_DIR=/etc/mongodb
MONGODB_DATA_DIR=/var/mongodb/data
MONGODB_LOG_DIR=/var/mongodb/log
MONGODB_CONFIG_PORT=20000
MONGODB_MONGOS_PORT=21000


# 配置 config
function config_conf()
{
    echo -e "
configsvr = true
port = $MONGODB_CONFIG_PORT
dppath = $MONGODB_DATA_DIR/config
logpath = $MONGODB_LOG_DIR/config.log
logappend = true
fork = true
maxConns = 1000
replSet = config
"
}

# 配置 mongos
function mongos_conf()
{
    local config_dbs=`echo "$HOSTS" | awk '$NF ~ /config/ {printf("%s:%s,",$1,"'$MONGODB_CONFIG_PORT'")}' | sed 's/,$//'`

    echo -e "
configdb = $config_dbs
port = $MONGODB_MONGOS_PORT
chunkSize = 5
logpath = $MONGODB_LOG_DIR/mongos.log
logappend = true
fork = true
maxConns = 1000
"
}

# 配置 shard
function shard_conf()
{
    echo -e "
shardsvr = true
dbpath = $MONGODB_DATA_DIR/$shard
replSet = $shard
port = $port
oplogSize = 100
logpath = $MONGODB_LOG_DIR/${shard}.log
logappend = true
nojournal = true
fork = true
maxConns = 1000
"
}

# 创建目录
function create_dir()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 安装目录
            mkdir -p $MONGODB_INSTALL_DIR
            # 配置文件目录
            mkdir -p $MONGODB_CONF_DIR
            # 数据文件目录
            mkdir -p $MONGODB_DATA_DIR
            chown -R ${MONGODB_USER}:${MONGODB_GROUP} $MONGODB_DATA_DIR
            # 日志文件目录
            mkdir -p $MONGODB_LOG_DIR
            # 目录授权
            chown -R ${MONGODB_USER}:${MONGODB_GROUP} $MONGODB_LOG_DIR
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $MONGODB_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $MONGODB_CONF_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $MONGODB_DATA_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${MONGODB_USER}:${MONGODB_GROUP} $MONGODB_DATA_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $MONGODB_LOG_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${MONGODB_USER}:${MONGODB_GROUP} $MONGODB_LOG_DIR"
        fi
    done
}

# 设置环境变量
function set_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# mongodb config start/,/^# mongodb config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # mongodb config start' /etc/profile
            sed -i "$ a export MONGODB_HOME=$MONGODB_HOME" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$MONGODB_HOME/bin" /etc/profile
            sed -i '$ a # mongodb config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# mongodb config start/,/^# mongodb config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # mongodb config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export MONGODB_HOME=$MONGODB_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$MONGODB_HOME/bin\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # mongodb config end' /etc/profile"
        fi
    done
}

# 安装
function install()
{
    # 下载
    if [[ ! -s $MONGODB_PKG ]]; then
        wget $MONGODB_URL
    fi

    # 安装
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        local mongodb_dir=$MONGODB_INSTALL_DIR/$MONGODB_NAME
        local mongodb_name=`basename $MONGODB_HOME`
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 删除旧目录
            rm -rf $mongodb_dir

            # 解压到安装目录
            tar -zxf $MONGODB_PKG -C $MONGODB_INSTALL_DIR

            # 目录授权
            chown -R ${MONGODB_USER}:${MONGODB_GROUP} $mongodb_dir

            # 创建软连接
            if [[ $MONGODB_NAME != $mongodb_name ]]; then
                ln -snf $mongodb_dir $MONGODB_HOME
            fi
        else
            # 拷贝安装包
            autoscp "$admin_passwd" $MONGODB_PKG ${admin_user}@${ip}:~

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $mongodb_dir"

            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $MONGODB_PKG -C $MONGODB_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${MONGODB_USER}:${MONGODB_GROUP} $mongodb_dir"

            if [[ $MONGODB_NAME != $mongodb_name ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "ln -snf $mongodb_dir $MONGODB_HOME"
            fi
        fi
    done
}

# 配置
function config()
{
    # 生成 config 配置文件
    config_conf > config.conf
    # 生成 mongos 配置文件
    mongos_conf > mongos.conf

    # 拷贝配置文件
    echo "$HOSTS" | grep -E "config|mongos" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            if [[ "$roles" =~ config ]]; then
                cp -f config.conf $MONGODB_CONF_DIR
            fi
            if [[ "$roles" =~ mongos ]]; then
                cp -f mongos.conf $MONGODB_CONF_DIR
            fi
        else
            if [[ "$roles" =~ config ]]; then
                autoscp "$admin_passwd" config.conf ${admin_user}@${ip}:$MONGODB_CONF_DIR
            fi
            if [[ "$roles" =~ mongos ]]; then
                autoscp "$admin_passwd" mongos.conf ${admin_user}@${ip}:$MONGODB_CONF_DIR
            fi
        fi
    done
}

# 分片
function shard()
{
    echo "$HOSTS" | grep shard | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        echo "$roles" | awk -F ':' 'BEGIN{
            RS=","
        } $1 ~ /shard/ {
            sub(/.*-/,"",$1);
            print $1" "$2
        }' | sed '/^$/d' |
        while read shard port; do
            # 生成 shard 配置文件
            shard_conf > ${shard}.conf

            if [[ "$ip" = "$LOCAL_IP" ]]; then
                # 创建数据文件目录
                mkdir -p $MONGODB_CONF_DIR/$shard
                # 拷贝配置文件
                cp -f ${shard}.conf $MONGODB_CONF_DIR
            else
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $MONGODB_CONF_DIR/$shard"
                autoscp "$admin_passwd" ${shard}.conf ${admin_user}@${ip}:$MONGODB_CONF_DIR
            fi
        done
    done
}

# 生成 config 副本集初始化脚本
function config_replica()
{
    echo "$HOSTS" awk 'BEGIN {
        print "use admin"
        print "config = {"
        print ""
        printf("    _id: \"config\",\n")
    } $NF ~ /config/ {
        printf()
    }'

    echo -e "


    configsvr: true,
    members: [
        { _id: 0, host: "dc-1-227:20000" },
        { _id: 1, host: "dc-1-229:20000" },
        { _id: 2, host: "dc-1-230:20000" }
    ]
}
rs.initiate(config)
"
}

# 生成 shard 副本集初始化脚本
function shard_replica()
{
    echo -e "
use admin
config = {
    _id: \"$shard\",
    members: [
        { _id: 0, host: "dc-1-227:22001" },
        { _id: 1, host: "dc-1-229:22001" },
        { _id: 2, host: "dc-1-230:22001", arbiterOnly: true }
    ]
}
rs.initiate(config)
"
}

# 添加分片到集群
function add_shard()
{
    echo -e "
use admin
sh.status()
sh.addShard("shard1/dc-1-227:22001,dc-1-229:22001,dc-1-230:22001")
sh.addShard("shard2/dc-1-227:22002,dc-1-229:22002,dc-1-230:22002")
sh.addShard("shard3/dc-1-227:22003,dc-1-229:22003,dc-1-230:22003")
sh.status()
"
}

# 启动
function start()
{
    # 启动 config
    echo "$HOSTS" | grep config | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            $MONGODB_HOME/bin/mongod -f $MONGODB_CONF_DIR/config.conf
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "$MONGODB_HOME/bin/mongod -f $MONGODB_CONF_DIR/config.conf"
        fi
    done

    # 初始化 config 副本集
    echo "$HOSTS" | grep config | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        config_replica > config_replica.js
    done
    $MONGODB_HOME/bin/mongo -port $MONGODB_CONFIG_PORT config_replica.js

    # 启动 primary shard
    echo "$HOSTS" | grep primary-shard | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        echo "$roles" | awk -F ':' 'BEGIN{
            RS=","
        } $1 ~ /shard/ {
            sub(/.*-/,"",$1);
            print $1
        }' | sed '/^$/d' |
        while read shard port; do
            $MONGODB_HOME/bin/mongod -f $MONGODB_CONF_DIR/${shard}.conf
        done
    done

    # 启动其他 shard
    echo "$HOSTS" | grep shard | grep -v primary | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        echo "$roles" | awk -F ':' 'BEGIN{
            RS=","
        } $1 ~ /shard/ {
            sub(/.*-/,"",$1);
            print $1
        }' | sed '/^$/d' |
        while read shard port; do
            $MONGODB_HOME/bin/mongod -f $MONGODB_CONF_DIR/${shard}.conf
        done
    done

    # 初始化 shard 副本集
    echo "$HOSTS" | grep primary-shard | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        shard_replica > shard_replica.js
    done
    $MONGODB_HOME/bin/mongo -port $MONGODB_CONFIG_PORT shard_replica.js

    # 启动 mongos
    echo "$HOSTS" | grep mongos | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            $MONGODB_HOME/bin/mongos -f $MONGODB_CONF_DIR/mongos.conf
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "$MONGODB_HOME/bin/mongos -f $MONGODB_CONF_DIR/mongos.conf"
        fi
    done

    # 添加分片到集群
    echo "$HOSTS" | grep shard | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        add_shard > add_shard.js
        $MONGODB_HOME/bin/mongo -port $MONGODB_CONFIG_PORT add_shard.js
    done

    # 启用数据库分片
    echo "$HOSTS" | grep shard | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        $MONGODB_HOME/bin/mongo -port $MONGODB_CONFIG_PORT --eval "printjson(sh.enableSharding('test'))"
    done
}

# 关闭
function stop()
{
    # 关闭 mongod
    echo "$HOSTS" | grep mongod | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            killall mongod
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "killall mongod"
        fi
    done

    # 关闭 mongos
    echo "$HOSTS" | grep mongos | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            killall mongos
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "killall mongos"
        fi
    done
}

# 管理
function admin()
{
    systemctl start mongod.service       # 启动mongodb服务
    systemctl stop mongod.service        # 关闭mongodb服务
    systemctl restart mongod.service     # 重启mongodb服务
}
