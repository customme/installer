#!/bin/bash
#
# 日期: 2018-09-04
# mongodb 安装运维手册


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/common.sh


# mongodb 集群配置信息
# ip hostname admin_user admin_passwd owner_passwd roles
HOSTS="192.168.1.17 yygz-17.inserv.com root 1234567 mongodb123 config,mongos,primary-shard1:22001,shard2:22002,shard3:22003
192.168.1.18 yygz-18.inserv.com root 1234567 mongodb123 config,mongos,shard1:22001,primary-shard2:22002,shard3:22003
192.168.1.19 yygz-19.inserv.com root 1234567 mongodb123 config,mongos,shard1:22001,shard2:22002,primary-shard3:22003"

# mongodb 版本
MONGODB_VERSION=4.0.3
# mongodb 安装包名
MONGODB_NAME=mongodb-linux-x86_64-amazon2-${MONGODB_VERSION}
MONGODB_PKG=${MONGODB_NAME}.tgz
# mongodb 下载地址
MONGODB_URL=https://fastdl.mongodb.org/linux/$MONGODB_PKG

# 当前用户名，所属组
THE_USER=$MONGODB_USER
THE_GROUP=$MONGODB_GROUP

# 相关目录
MONGODB_HOME=/usr/mongodb/current
MONGODB_INSTALL_DIR=`dirname $MONGODB_HOME`
MONGODB_CONF_DIR=/etc/mongodb
MONGODB_DATA_DIR=/var/mongodb/data
MONGODB_LOG_DIR=/var/mongodb/log
MONGODB_MONGOS_PORT=20000
MONGODB_CONFIG_PORT=21000


# 配置 config
function config_conf()
{
    echo -e "
systemLog:
  destination: file
  logAppend: true
  path: $MONGODB_LOG_DIR/config.log
storage:
  dbPath: $MONGODB_DATA_DIR/config
  journal:
    enabled: true
processManagement:
  fork: true
  pidFilePath: $MONGODB_LOG_DIR/config.pid
  timeZoneInfo: /usr/share/zoneinfo
net:
  port: $MONGODB_CONFIG_PORT
  bindIp: 0.0.0.0
  maxIncomingConnections: 1000
replication:
  replSetName: config
sharding:
  clusterRole: configsvr
"
}

# 配置 mongos
function mongos_conf()
{
    local config_dbs=`echo "$HOSTS" | awk '$NF ~ /config/ {printf("%s:%s,",$1,"'$MONGODB_CONFIG_PORT'")}' | sed 's/,$//'`

    echo -e "
systemLog:
  destination: file
  logAppend: true
  path: $MONGODB_LOG_DIR/mongos.log
processManagement:
  fork: true
  pidFilePath: $MONGODB_LOG_DIR/mongos.pid
  timeZoneInfo: /usr/share/zoneinfo
net:
  port: $MONGODB_MONGOS_PORT
  bindIp: 0.0.0.0
  maxIncomingConnections: 1000
sharding:
  configDB: config/$config_dbs
"
}

# 配置 shard
function shard_conf()
{
    echo -e "
systemLog:
  destination: file
  logAppend: true
  path: $MONGODB_LOG_DIR/${shard}.log
storage:
  dbPath: $MONGODB_DATA_DIR/$shard
  journal:
    enabled: true
processManagement:
  fork: true
  pidFilePath: $MONGODB_LOG_DIR/${shard}.pid
  timeZoneInfo: /usr/share/zoneinfo
net:
  port: $port
  bindIp: 0.0.0.0
  maxIncomingConnections: 1000
replication:
  replSetName: $shard
sharding:
  clusterRole: shardsvr
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
    # 出错立即退出
    set -e

    # 下载
    if [[ ! -s $MONGODB_PKG ]]; then
        wget $MONGODB_URL
    fi

    # 创建目录
    create_dir

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

    config

    shard

    # 设置环境变量
    set_env
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
                # 创建数据文件目录
                su -l $MONGODB_USER -c "mkdir -p $MONGODB_DATA_DIR/config"

                cp -f config.conf $MONGODB_CONF_DIR
            fi
            if [[ "$roles" =~ mongos ]]; then
                cp -f mongos.conf $MONGODB_CONF_DIR
            fi
        else
            if [[ "$roles" =~ config ]]; then
                autossh "$owner_passwd" ${MONGODB_USER}@${ip} "mkdir -p $MONGODB_DATA_DIR/config"
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
                su -l $MONGODB_USER -c "mkdir -p $MONGODB_DATA_DIR/$shard"
                # 拷贝配置文件
                cp -f ${shard}.conf $MONGODB_CONF_DIR
            else
                autossh "$owner_passwd" ${MONGODB_USER}@${ip} "mkdir -p $MONGODB_DATA_DIR/$shard"
                autoscp "$admin_passwd" ${shard}.conf ${admin_user}@${ip}:$MONGODB_CONF_DIR
            fi
        done
    done
}

# 生成 config 副本集初始化脚本
function config_replica()
{
    echo "$HOSTS" | grep config | awk 'BEGIN {
        print "rs.initiate({"
        printf("  _id: \"config\",\n")
        print "  configsvr: true,"
        print "  members: ["
    } {
        if(NR > 1){
            printf(",\n")
        }
        printf("    { _id: %d, host: \"%s:%d\" }",i++,$2,"'$MONGODB_CONFIG_PORT'")
    } END {
        print "\n  ]"
        print "})"
    }'
}

# 生成 shard 副本集初始化脚本
function shard_replica()
{
    echo "$HOSTS" | sed "s/^[^ ]\+ \([^ ]\+\).*,\(.*${shard}\):\([0-9]\+\).*/\1 \2 \3/" | awk 'BEGIN{
        print "rs.initiate({"
        printf("  _id: \"%s\",\n","'$shard'")
        print "  members: ["
    }{
        if(NR > 1){
            printf(",\n")
        }
        if($2 ~ /arbiter/){
            printf("    { _id: %d, host: \"%s:%d\", arbiterOnly: true }",i++,$1,$3)
        }else{
            printf("    { _id: %d, host: \"%s:%d\" }",i++,$1,$3)
        }
    }END{
        print "\n  ]"
        print "})"
    }'
}

# 添加分片到集群
function add_shard()
{
    echo "$HOSTS" | sed "s/^[^ ]\+ \([^ ]\+\).*,\(.*${shard}\):\([0-9]\+\).*/\1 \2 \3/" | awk 'BEGIN{
        print "use admin"
        printf("sh.addShard(\"%s/","'$shard'")
    }{
        if(NR > 1){
            printf(",")
        }
        printf("%s:%d",$1,$3)
    }END{
        print "\")\nsh.status();"
    }'
}

# 初始化
function init()
{
    # 出错立即退出
    set -e

    # 启动 config
    log "Start mongod config"
    echo "$HOSTS" | grep config | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${MONGODB_USER}@${ip} "$MONGODB_HOME/bin/mongod -f $MONGODB_CONF_DIR/config.conf"
    done

    # 初始化 config 副本集
    log "Initiate config replication set"
    echo "$HOSTS" | grep config | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        config_replica > config_replica.js
    done
    $MONGODB_HOME/bin/mongo -port $MONGODB_CONFIG_PORT config_replica.js

    # 启动 primary shard
    log "Start mongod primary shard"
    echo "$HOSTS" | grep primary-shard | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        echo "$roles" | awk -F ':' 'BEGIN{
            RS=","
        } $1 ~ /shard/ {
            sub(/.*-/,"",$1);
            print $1
        }' | sed '/^$/d' |
        while read shard port; do
            autossh "$owner_passwd" ${MONGODB_USER}@${ip} "$MONGODB_HOME/bin/mongod -f $MONGODB_CONF_DIR/${shard}.conf"
        done
    done

    # 启动其他 shard
    log "Start mongod shard"
    echo "$HOSTS" | grep shard | grep -v primary | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        echo "$roles" | awk -F ':' 'BEGIN{
            RS=","
        } $1 ~ /shard/ {
            sub(/.*-/,"",$1);
            print $1
        }' | sed '/^$/d' |
        while read shard port; do
            autossh "$owner_passwd" ${MONGODB_USER}@${ip} "$MONGODB_HOME/bin/mongod -f $MONGODB_CONF_DIR/${shard}.conf"
        done
    done

    # 初始化 shard 副本集
    log "Initiate shard replication set"
    echo "$HOSTS" | grep primary-shard | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        shard=`echo "$roles" | sed 's/.*,primary-\([^:]\+\):.*/\1/'`
        port=`echo "$roles" | sed 's/.*primary-[^:]\+:\([0-9]\+\).*/\1/'`
        shard_replica > ${shard}_replica.js
        $MONGODB_HOME/bin/mongo -port $port ${shard}_replica.js
    done

    # 启动 mongos
    log "Start mongos"
    echo "$HOSTS" | grep mongos | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${MONGODB_USER}@${ip} "$MONGODB_HOME/bin/mongos -f $MONGODB_CONF_DIR/mongos.conf"
    done

    # 添加分片到集群
    log "Add shard to cluster"
    echo "$HOSTS" | grep primary-shard | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        shard=`echo "$roles" | sed 's/.*,primary-\([^:]\+\):.*/\1/'`
        add_shard > ${shard}.js
        $MONGODB_HOME/bin/mongo -port $MONGODB_MONGOS_PORT ${shard}.js
    done
}

# 启动
function start()
{
    # 出错立即退出
    set -e

    # 启动 config
    log "Start mongod config"
    echo "$HOSTS" | grep config | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${MONGODB_USER}@${ip} "$MONGODB_HOME/bin/mongod -f $MONGODB_CONF_DIR/config.conf"
    done

    # 启动 primary shard
    log "Start mongod primary shard"
    echo "$HOSTS" | grep primary-shard | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        echo "$roles" | awk -F ':' 'BEGIN{
            RS=","
        } $1 ~ /shard/ {
            sub(/.*-/,"",$1);
            print $1
        }' | sed '/^$/d' |
        while read shard port; do
            autossh "$owner_passwd" ${MONGODB_USER}@${ip} "$MONGODB_HOME/bin/mongod -f $MONGODB_CONF_DIR/${shard}.conf"
        done
    done

    # 启动其他 shard
    log "Start mongod shard"
    echo "$HOSTS" | grep shard | grep -v primary | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        echo "$roles" | awk -F ':' 'BEGIN{
            RS=","
        } $1 ~ /shard/ {
            sub(/.*-/,"",$1);
            print $1
        }' | sed '/^$/d' |
        while read shard port; do
            autossh "$owner_passwd" ${MONGODB_USER}@${ip} "$MONGODB_HOME/bin/mongod -f $MONGODB_CONF_DIR/${shard}.conf"
        done
    done

    # 启动 mongos
    log "Start mongos"
    echo "$HOSTS" | grep mongos | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${MONGODB_USER}@${ip} "$MONGODB_HOME/bin/mongos -f $MONGODB_CONF_DIR/mongos.conf"
    done
}

# 关闭
function stop()
{
    # 关闭 mongod
    echo "$HOSTS" | grep mongod | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${MONGODB_USER}@${ip} "killall mongod"
    done

    # 关闭 mongos
    echo "$HOSTS" | grep mongos | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${MONGODB_USER}@${ip} "killall mongos"
    done
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-c create user<add/delete>] [-h config host<hostname,hosts>] [-i install] [-s start<init/start/stop/restart>] [-v verbose]"
}

# 重置环境
function reset_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"mongod|mongos\" | grep -v grep | awk '{print $2}' | xargs -r kill"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $MONGODB_HOME $MONGODB_CONF_DIR $MONGODB_DATA_DIR $MONGODB_LOG_DIR"
    done
}

# 管理
function admin()
{
    # 启用数据库分片
    $MONGODB_HOME/bin/mongo -port $MONGODB_MONGOS_PORT --eval "printjson(sh.enableSharding('test'))"
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    # -c [add/delete] 创建用户
    # -h [hostname,hosts] 配置host
    # -i 安装集群
    # -s [init/start/stop/restart] 启动/停止集群
    # -v debug模式
    while getopts "c:h:is:v" name; do
        case "$name" in
            c)
                local command="$OPTARG"
                if [[ "$command" = "delete" ]]; then
                    delete_flag=1
                fi
                create_flag=1;;
            h)
                local $command="$OPTARG"
                if [[ "$command" = "hostname" ]]; then
                    hostname_flag=1
                fi
                hosts_flag=1;;
            i)
                install_flag=1;;
            s)
                start_cmd="$OPTARG";;
            v)
                debug_flag=1;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    # 安装环境
    log_fn install_env

    # 删除用户
    [[ $delete_flag ]] && log_fn delete_user
    # 创建用户
    [[ $create_flag ]] && log_fn create_user

    # 配置host
    [[ $hostname_flag ]] && log_fn modify_hostname
    [[ $hosts_flag ]] && log_fn add_host

    # 安装集群
    [[ $install_flag ]] && log_fn install

    # 启动集群
    [[ $start_cmd ]] && log_fn $start_cmd
}
main "$@"