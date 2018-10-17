#!/bin/bash
#
# Author: superz
# Date: 2018-09-30
# Description: hadoop高可用集群自动安装脚本
# Dependency: yum autossh autoscp


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/../common/common.sh
source $DIR/config.sh


# 创建hadoop相关目录
function create_dir()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 临时文件目录
            mkdir -p $HADOOP_TMP_DIR
            chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_TMP_DIR

            # 数据文件目录
            mkdir -p $HADOOP_DATA_DIR
            chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_DATA_DIR

            # 日志文件目录
            mkdir -p $HADOOP_LOG_DIR
            chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_LOG_DIR
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HADOOP_TMP_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_TMP_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HADOOP_DATA_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_DATA_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HADOOP_LOG_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_LOG_DIR"
        fi
    done
}

# 设置hadoop环境变量
function set_env()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            sed -i '/^# hadoop config start/,/^# hadoop config end/d' /etc/profile
            sed -i '$ G' /etc/profile
            sed -i '$ a # hadoop config start' /etc/profile
            sed -i "$ a export HADOOP_HOME=$HADOOP_HOME" /etc/profile
            sed -i "$ a export HADOOP_CONF_DIR=$HADOOP_CONF_DIR" /etc/profile
            sed -i "$ a export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" /etc/profile
            sed -i '$ a # hadoop config end' /etc/profile
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# hadoop config start/,/^# hadoop config end/d' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ G' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # hadoop config start' /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export HADOOP_HOME=$HADOOP_HOME\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export HADOOP_CONF_DIR=$HADOOP_CONF_DIR\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"$ a export PATH=\\\$PATH:\\\$HADOOP_HOME/bin:\\\$HADOOP_HOME/sbin\" /etc/profile"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '$ a # hadoop config end' /etc/profile"
        fi
    done
}

# 配置hadoop
function config_hadoop()
{
    # 修改hadoop-env.sh
    sed -i "s@.*\(export JAVA_HOME=\).*@\1${JAVA_HOME}@" $HADOOP_NAME/etc/hadoop/hadoop-env.sh

    # jvm heap
    if [[ -n "$HADOOP_NAMENODE_HEAP" ]]; then
        sed -i "s/.*\(export HADOOP_NAMENODE_OPTS=.*\)\"/\1 ${HADOOP_NAMENODE_HEAP}\"/" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi
    if [[ -n "$HADOOP_DATANODE_HEAP" ]]; then
        sed -i "s/.*\(export HADOOP_DATANODE_OPTS=.*\)\"/\1 ${HADOOP_DATANODE_HEAP}\"/" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi
    if [[ -n "$HADOOP_CLIENT_HEAP" ]]; then
        sed -i "s/\(.*export HADOOP_CLIENT_OPTS=.*\)-Xm[sx][[:alnum:]]\+[ ]\?\(.*\)/\1\2/g" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
        sed -i "s/.*\(export HADOOP_CLIENT_OPTS=.*\)\"/\1 ${HADOOP_CLIENT_HEAP}\"/" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi

    # log/pid directory
    sed -i "s@.*\(export HADOOP_LOG_DIR=\).*@\1${HADOOP_LOG_DIR}@" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    if [[ -n "$HADOOP_PID_DIR" ]]; then
        sed -i "s@.*\(export HADOOP_PID_DIR=\).*@\1${HADOOP_PID_DIR}@" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi

    # jmx
    if [[ -n "$HADOOP_NAMENODE_JMX_PORT" ]]; then
        if [[ -z `grep "export HADOOP_JMX_BASE" $HADOOP_NAME/etc/hadoop/hadoop-env.sh` ]]; then
            sed -i "$ a \\\n# enable JMX exporting\\nexport HADOOP_JMX_BASE=\"${HADOOP_JMX_BASE}\"" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
        fi
        sed -i "$ a export HADOOP_NAMENODE_OPTS=\"\$HADOOP_NAMENODE_OPTS \$HADOOP_JMX_BASE -Dcom.sun.management.jmxremote.port=${HADOOP_NAMENODE_JMX_PORT}\"" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi
    if [[ -n "$HADOOP_DATANODE_JMX_PORT" ]]; then
        if [[ -z `grep "export HADOOP_JMX_BASE" $HADOOP_NAME/etc/hadoop/hadoop-env.sh` ]]; then
            sed -i "$ a \\\n# enable JMX exporting\\nexport HADOOP_JMX_BASE=\"${HADOOP_JMX_BASE}\"" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
        fi
        sed -i "$ a export HADOOP_DATANODE_OPTS=\"\$HADOOP_DATANODE_OPTS \$HADOOP_JMX_BASE -Dcom.sun.management.jmxremote.port=${HADOOP_DATANODE_JMX_PORT}\"" $HADOOP_NAME/etc/hadoop/hadoop-env.sh
    fi

    # 删除连续空行为一个
    sed -i '/^$/{N;/^\n$/d}' $HADOOP_NAME/etc/hadoop/hadoop-env.sh

    # 修改yarn-env.sh
    sed -i "s@^\# \(export JAVA_HOME=\).*@\1${JAVA_HOME}@" $HADOOP_NAME/etc/hadoop/yarn-env.sh

    # jvm heap
    if [[ -n "$YARN_RESOURCEMANAGER_HEAP" ]]; then
        sed -i "/export YARN_RESOURCEMANAGER_HEAPSIZE/ a\export YARN_RESOURCEMANAGER_OPTS=\"\$YARN_RESOURCEMANAGER_OPTS ${YARN_RESOURCEMANAGER_HEAP}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi
    if [[ -n "$YARN_NODEMANAGER_HEAP" ]]; then
        sed -i "/export YARN_NODEMANAGER_HEAPSIZE/ a\export YARN_NODEMANAGER_OPTS=\"\$YARN_NODEMANAGER_OPTS ${YARN_NODEMANAGER_HEAP}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi

    # log/pid directory
    if [[ -n "$YARN_LOG_DIR" ]]; then
        sed -i "/\"\$YARN_LOG_DIR/ i\export YARN_LOG_DIR=${YARN_LOG_DIR}" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi
    if [[ -n "$YARN_PID_DIR" ]]; then
        sed -i "$ a \\\nexport YARN_PID_DIR=${YARN_PID_DIR}" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi

    # jmx
    if [[ -n "$YARN_RESOURCEMANAGER_JMX_PORT" ]]; then
        if [[ -z `grep "export HADOOP_JMX_BASE" $HADOOP_NAME/etc/hadoop/yarn-env.sh` ]]; then
            sed -i "$ a \\\n# enable JMX exporting\\nexport HADOOP_JMX_BASE=\"${HADOOP_JMX_BASE}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
        fi
        sed -i "$ a export YARN_RESOURCEMANAGER_OPTS=\"\$YARN_RESOURCEMANAGER_OPTS \$HADOOP_JMX_BASE -Dcom.sun.management.jmxremote.port=${YARN_RESOURCEMANAGER_JMX_PORT}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi
    if [[ -n "$YARN_NODEMANAGER_JMX_PORT" ]]; then
        if [[ -z `grep "export HADOOP_JMX_BASE" $HADOOP_NAME/etc/hadoop/yarn-env.sh` ]]; then
            sed -i "$ a \\\n# enable JMX exporting\\nexport HADOOP_JMX_BASE=\"${HADOOP_JMX_BASE}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
        fi
        sed -i "$ a export YARN_NODEMANAGER_OPTS=\"\$YARN_NODEMANAGER_OPTS \$HADOOP_JMX_BASE -Dcom.sun.management.jmxremote.port=${YARN_NODEMANAGER_JMX_PORT}\"" $HADOOP_NAME/etc/hadoop/yarn-env.sh
    fi

    # 删除连续空行为一个
    sed -i '/^$/{N;/^\n$/d}' $HADOOP_NAME/etc/hadoop/yarn-env.sh

    # 修改mapred-env.sh
    sed -i "s@^\# \(export JAVA_HOME=\).*@\1${JAVA_HOME}@" $HADOOP_NAME/etc/hadoop/mapred-env.sh

    # jvm heap
    if [[ -n "$MR_HISTORYSERVER_HEAP" ]]; then
        sed -i "s/\(export HADOOP_JOB_HISTORYSERVER_HEAPSIZE=\).*/\1${MR_HISTORYSERVER_HEAP}/" $HADOOP_NAME/etc/hadoop/mapred-env.sh
    fi

    # log/pid directory
    if [[ -n "$HADOOP_MAPRED_LOG_DIR" ]]; then
        sed -i "$ a \\\nexport HADOOP_MAPRED_LOG_DIR=${HADOOP_MAPRED_LOG_DIR}" $HADOOP_NAME/etc/hadoop/mapred-env.sh
    fi
    if [[ -n "$HADOOP_MAPRED_PID_DIR" ]]; then
        sed -i "$ a \\\nexport HADOOP_MAPRED_PID_DIR=${HADOOP_MAPRED_PID_DIR}" $HADOOP_NAME/etc/hadoop/mapred-env.sh
    fi

    # 删除连续空行为一个
    sed -i '/^$/{N;/^\n$/d}' $HADOOP_NAME/etc/hadoop/mapred-env.sh

    # 配置core-site.xml
    core_config | config_xml $HADOOP_NAME/etc/hadoop/core-site.xml

    # 配置hdfs-site.xml
    hdfs_config | config_xml $HADOOP_NAME/etc/hadoop/hdfs-site.xml

    # 配置mapred-site.xml
    if [[ ! -f $HADOOP_NAME/etc/hadoop/mapred-site.xml ]]; then
        cp $HADOOP_NAME/etc/hadoop/mapred-site.xml.template $HADOOP_NAME/etc/hadoop/mapred-site.xml
    fi
    mapred_config | config_xml $HADOOP_NAME/etc/hadoop/mapred-site.xml

    # 配置yarn-site.xml
    yarn_config | config_xml $HADOOP_NAME/etc/hadoop/yarn-site.xml

    # 配置httpfs-site.xml
    if [[ -f $CONF_DIR/httpfs-site.cfg ]]; then
        sed -i "s@.*\(export HTTPFS_LOG=\).*@\1${HTTPFS_LOG_DIR}@" $HADOOP_NAME/etc/hadoop/httpfs-env.sh
        sed -i "s@.*\(export HTTPFS_TEMP=\).*@\1${HTTPFS_TMP_DIR}@" $HADOOP_NAME/etc/hadoop/httpfs-env.sh
        sed -i "$ a \\\nexport CATALINA_PID=${HADOOP_TMP_DIR}/httpfs.pid" $HADOOP_NAME/etc/hadoop/httpfs-env.sh

        # 删除连续空行
        sed -i '/^$/{N;/^\n$/d}' $HADOOP_NAME/etc/hadoop/httpfs-env.sh

        httpfs_config | config_xml $HADOOP_NAME/etc/hadoop/httpfs-site.xml
    fi

    # 修改slaves文件
    echo "$HOSTS" | awk '$0 ~ /datanode/ {print $2}' > $HADOOP_NAME/etc/hadoop/slaves

    # exclude hosts
    if [[ ! -f $HADOOP_NAME/etc/hadoop/$DFS_EXCLUDE_FILE ]]; then
        touch $HADOOP_NAME/etc/hadoop/$DFS_EXCLUDE_FILE
    fi

    # hadoop本地库
    hadoop_native_lib=`find $LIB_DIR -name "hadoop-native-64-*.tar" | head -n 1`
    if [[ -n "$hadoop_native_lib" ]]; then
        tar -xf $hadoop_native_lib -C $HADOOP_NAME/lib/native
    fi

    # hadoop监控
    if [[ -f $CONF_DIR/hadoop-metrics.properties ]]; then
        cp -f $CONF_DIR/hadoop-metrics.properties $HADOOP_NAME/etc/hadoop
    fi
    if [[ -f $CONF_DIR/hadoop-metrics2.properties ]]; then
        cp -f $CONF_DIR/hadoop-metrics2.properties $HADOOP_NAME/etc/hadoop
    fi
}

# 安装
function install()
{
    # 下载hadoop
    if [[ ! -f $HADOOP_PKG ]]; then
        wget $HADOOP_URL
    fi

    # 解压hadoop
    tar -zxf $HADOOP_PKG

    # 配置hadoop
    config_hadoop

    # 压缩配置好的hadoop
    mv -f $HADOOP_PKG ${HADOOP_PKG}.o
    tar -zcf $HADOOP_PKG $HADOOP_NAME

    echo "$HOSTS" | while read ip hostname admin_user admin_passwd owner_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            # 创建hadoop安装目录
            mkdir -p $HADOOP_INSTALL_DIR

            # 安装hadoop
            rm -rf $HADOOP_INSTALL_DIR/$HADOOP_NAME
            mv -f $HADOOP_NAME $HADOOP_INSTALL_DIR
            chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_INSTALL_DIR
            if [[ `basename $HADOOP_HOME` != $HADOOP_NAME ]]; then
                su -l $HDFS_USER -c "ln -snf $HADOOP_INSTALL_DIR/$HADOOP_NAME $HADOOP_HOME"
            fi

            # 配置文件
            if [[ $HADOOP_CONF_DIR != $HADOOP_HOME/etc/hadoop ]]; then
                mkdir -p $HADOOP_CONF_DIR
                mv -f $HADOOP_HOME/etc/hadoop/* $HADOOP_CONF_DIR
                chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_CONF_DIR
            fi
        else
            autoscp "$admin_passwd" $HADOOP_PKG ${admin_user}@${ip}:~/$HADOOP_PKG $SSH_PORT 100
            autossh "$admin_passwd" ${admin_user}@${ip} "tar -zxf $HADOOP_PKG"

            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HADOOP_INSTALL_DIR"

            autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $HADOOP_INSTALL_DIR/$HADOOP_NAME"
            autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $HADOOP_NAME $HADOOP_INSTALL_DIR"
            autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_INSTALL_DIR"
            if [[ `basename $HADOOP_HOME` != $HADOOP_NAME ]]; then
                autossh "$owner_passwd" ${HDFS_USER}@${ip} "ln -snf $HADOOP_INSTALL_DIR/$HADOOP_NAME $HADOOP_HOME"
            fi

            if [[ $HADOOP_CONF_DIR != $HADOOP_HOME/etc/hadoop ]]; then
                autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $HADOOP_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "mv -f $HADOOP_HOME/etc/hadoop/* $HADOOP_CONF_DIR"
                autossh "$admin_passwd" ${admin_user}@${ip} "chown -R ${HDFS_USER}:${HDFS_GROUP} $HADOOP_CONF_DIR"
            fi
        fi
    done

    # 删除安装文件
    rm -rf $HADOOP_NAME

    # 创建hadoop相关目录
    create_dir

    # 设置hadoop环境变量
    set_env
}

# 卸载
function uninstall()
{
    local jps="JournalNode|DataNode|NameNode|ResourceManager|DFSZKFailoverController|NodeManager|JobHistoryServer"
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        autossh "$admin_passwd" ${admin_user}@${ip} "ps aux | grep -E \"$jps\" | grep -v grep | awk '{print \$2}' | xargs -r kill -9"
        autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $HADOOP_HOME $HADOOP_TMP_DIR $HADOOP_LOG_DIR /tmp/hsperfdata_* /tmp/Jetty_* /tmp/hadoop-* /tmp/*_resources"
        autossh "$admin_passwd" ${admin_user}@${ip} "sed -i '/^# hadoop config start/,/^# hadoop config end/d' /etc/profile"
        [[ $remove_conf ]] && autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $HADOOP_CONF_DIR"
        [[ $remove_data ]] && autossh "$admin_passwd" ${admin_user}@${ip} "rm -rf $HADOOP_DATA_DIR"
        [[ $remove_user ]] && autossh "$admin_passwd" ${admin_user}@${ip} "userdel -rf $HDFS_USER"
    done
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-b backup] [-c create user<add/delete>] [-d detect environment] [-h config host<hostname,hosts>] [-i install] [-k config ssh] [-s start>] [-u uninstall file,conf,data,user] [-v verbose]"
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    # -c [add/delete] 创建用户
    # -d 检测环境
    # -h [hostname,hosts] 配置host
    # -i 安装集群
    # -k 配置ssh免密码登录
    # -s 启动
    # -v debug模式
    while getopts "c:dh:iksu:v" name; do
        case "$name" in
            c)
                create_cmd="$OPTARG"
                [[ "$create_cmd" = "delete" ]] && delete_flag=1
                create_flag=1;;
            d)
                detect_flag=1;;
            h)
                local command="$OPTARG"
                [[ "$command" =~ "hostname" ]] && hostname_flag=1
                [[ "$command" =~ "hosts" ]] && hosts_flag=1;;
            i)
                install_flag=1;;
            k)
                ssh_flag=1;;
            s)
                start_flag=1;;
            u)
                local command="$OPTARG"
                [[ "$command" =~ "conf" ]] && remove_conf=1
                [[ "$command" =~ "data" ]] && remove_data=1
                [[ "$command" =~ "user" ]] && remove_user=1
                uninstall_flag=1;;
            v)
                debug_flag=1;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    # 安装依赖
    install_deps

    # 备份重要文件
    backup

    # 检测环境
    [[ $detect_flag ]] && log_fn detect_env

    # 卸载hadoop
    [[ $uninstall_flag ]] && uninstall

    # 删除用户
    [[ $delete_flag ]] && log_fn delete_user
    # 创建用户
    [[ $create_flag ]] && log_fn create_user

    # 配置host
    [[ $hostname_flag ]] && log_fn modify_hostname
    [[ $hosts_flag ]] && log_fn add_host

    # 配置ssh免密码登录
    [[ $ssh_flag ]] && log_fn config_ssh

    # 安装jdk
    log_fn install_jdk

    # 安装hadoop
    [[ $install_flag ]] && log_fn install

    # 启动hadoop集群
    [[ $start_flag ]] && sh admin.sh -i
}
main "$@"