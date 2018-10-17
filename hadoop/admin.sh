#!/bin/bash
#
# Author: superz
# Date: 2018-09-30
# Description: hadoop管理


# 初始化
function init()
{
    # 出错立即退出
    set -e

    # 启动journalnode
    echo "$HOSTS" | grep namenode | head -1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/hadoop-daemons.sh start journalnode"
    done

    # 格式化zkfc
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/bin/hdfs zkfc -formatZK -force -nonInteractive"
    done

    # 如果从non-HA转HA，需要初始化journalnode
    # hdfs namenode -initializeSharedEdits -force

    # 等待journalnode启动
    sleep 5
    # 格式化hdfs
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/bin/hdfs namenode -format"
    done

    # 启动zkfc
    echo "$HOSTS" | grep zkfc | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/hadoop-daemon.sh start zkfc"
    done

    # 启动active namenode
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/hadoop-daemon.sh start namenode"
    done

    # 同步active namenode数据到standby namenode，并启动standby namenode
    echo "$HOSTS" | grep namenode | sed '1 d' | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/bin/hdfs namenode -bootstrapStandby -force"
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/hadoop-daemon.sh start namenode"
    done

    # 启动所有datanode
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/hadoop-daemons.sh start datanode"
    done

    # 启动yarn（resourcemanager、nodemanager）
    echo "$HOSTS" | grep yarn | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/start-yarn.sh"
    done

    # 启动standby resourcemanager
    echo "$HOSTS" | grep yarn | sed '1 d' | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/yarn-daemon.sh start resourcemanager"
    done

    # 启动historyserver
    echo "$HOSTS" | grep historyserver | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver"
    done

    # 启动httpfs
    echo "$HOSTS" | grep httpfs | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/httpfs.sh start"
    done
}

# 启动集群
function start()
{
    # 出错立即退出
    set -e

    # 启动dfs（namenode、datanode、journalnode、zkfc）
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/start-dfs.sh"
    done

    # 启动yarn（resourcemanager、nodemanager）
    echo "$HOSTS" | grep yarn | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/start-yarn.sh"
    done

    # 启动standby resourcemanager
    echo "$HOSTS" | grep yarn | sed '1 d' | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/yarn-daemon.sh start resourcemanager"
    done

    # 启动historyserver
    echo "$HOSTS" | grep historyserver | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh start historyserver"
    done

    # 启动httpfs
    echo "$HOSTS" | grep httpfs | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/httpfs.sh start"
    done
}

# 停止集群
function stop()
{
    # 停止dfs（namenode、datanode、journalnode、zkfc）
    echo "$HOSTS" | grep namenode | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/stop-dfs.sh"
    done

    # 停止yarn（resourcemanager、nodemanager）
    echo "$HOSTS" | grep yarn | head -n 1 | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/stop-yarn.sh"
    done

    # 停止standby resourcemanager
    echo "$HOSTS" | grep yarn | sed '1 d' | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/yarn-daemon.sh stop resourcemanager"
    done

    # 停止historyserver
    echo "$HOSTS" | grep historyserver | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/mr-jobhistory-daemon.sh stop historyserver"
    done

    # 停止httpfs
    echo "$HOSTS" | grep httpfs | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        autossh "$owner_passwd" ${HDFS_USER}@${ip} "$HADOOP_HOME/sbin/httpfs.sh stop"
    done
}

# 滚动重启
function rolling_restart()
{
    # active namenode ip
    ACTIVE_IP="192.168.1.227"
    STANDBY_IP="192.168.1.229"
    ACTIVE_HOST=(`echo "$HOSTS" | grep $ACTIVE_IP`)
    STANDBY_HOST=(`echo "$HOSTS" | grep $STANDBY_IP`)
    ACTIVE_ID="nn1"
    STANDBY_ID="nn2"

    # 重启namenode
    # 1 创建fsimage
    hdfs dfsadmin -rollingUpgrade prepare
    sleep 3
    # 2 等待fsimage创建成功
    local msg=`hdfs dfsadmin -rollingUpgrade query`
    while [[ -z `echo "$msg" | grep "Proceed with rolling upgrade"` ]]; do
        sleep 3
        msg=`hdfs dfsadmin -rollingUpgrade query`
    done
    # 3 关闭standby namenode
    $HADOOP_HOME/sbin/hadoop-daemon.sh stop namenode
    # 4 重启standby namenode
    hdfs namenode -rollingUpgrade started
    # 5 切换active/standby namenode
    hdfs haadmin -failover --forcefence --forceactive $STANDBY_ID $ACTIVE_ID
    # 6 关闭active namenode
    $HADOOP_HOME/sbin/hadoop-daemon.sh stop namenode
    # 7 重启active namenode
    hdfs namenode -rollingUpgrade started

    # 重启datanode
    echo "$HOSTS" | grep datanode | while read ip hostname admin_user admin_passwd owner_passwd roles; do
        # 1 关闭datanode
        hdfs dfsadmin -shutdownDatanode $hostname:$DATANODE_IPC_PORT upgrade
        sleep 3
        # 2 获取datanode状态
        msg=`hdfs dfsadmin -getDatanodeInfo $hostname:$DATANODE_IPC_PORT`
        while [[ -z `echo "$msg" | grep "Proceed"` ]]; do
            sleep 3
            msg=`hdfs dfsadmin -getDatanodeInfo $hostname:$DATANODE_IPC_PORT`
        done
        # 3 重启datanode
        $HADOOP_HOME/sbin/hadoop-daemon.sh start datanode
    done

    # 结束本次升级
    hdfs dfsadmin -rollingUpgrade finalize
}

# 管理
function admin()
{
    # 查看dfs报告
    hdfs dfsadmin -report

    # 检测块
    hdfs fsck /

    # 查看正在被打开的文件
    hdfs fsck / -openforwrite

    # 查看缺失块
    hdfs fsck / -list-corruptfileblocks

    # 恢复租约
    hdfs debug recoverLease [-path path] [-retries <num-retries>]

    # 删除坏块
    hdfs fsck / -delete

    # 刷新节点
    hdfs dfsadmin -refreshNodes

    # 备份namenode元数据
    hdfs dfsadmin -fetchImage fsimage.`date +'%Y%m%d%H%M%S'`

    # 查看namenode状态
    hdfs haadmin -getServiceState nn1/nn2

    # 手动切换namenode状态 nn1 -> standby nn2 -> active
    hdfs haadmin -failover --forcefence --forceactive nn1 nn2

    # 强制切换
    hdfs haadmin -transitionToActive/transitionToStandby --forcemanual nn1/nn2

    # 查看resourcemanager状态
    yarn rmadmin -getServiceState rm1/rm2

    # 手动切换resourcemanager状态
    yarn rmadmin -failover --forcefence --forceactive rm1 rm2

    # 强制切换
    yarn rmadmin -transitionToActive/transitionToStandby --forcemanual rm1/rm2

    # 查看运行节点
    yarn node -list

    # 查看application
    yarn application -list -appStates ALL

    # 杀掉application
    yarn application -kill applicationId

    # 刷新节点
    yarn rmadmin -refreshNodes

    # 查看job
    mapred job -list all

    # 杀掉job
    mapred job -kill jobId

    # 查看日志级别
    hadoop daemonlog -getlevel hdpc1-mn01:50070 log4j.logger.http.requests.namenode
    hadoop daemonlog -getlevel hdpc1-mn01:8088 log4j.logger.http.requests.resourcemanager
    # 设置日志级别
    hadoop daemonlog -setlevel hdpc1-mn01:50070 log4j.logger.http.requests.namenode DEBUG
    hadoop daemonlog -setlevel hdpc1-mn01:8088 log4j.logger.http.requests.resourcemanager DEBUG

    # 获取配置信息
    hdfs getconf -confKey dfs.datanode.max.transfer.threads

    # 设置数据平衡临时带宽
    hdfs dfsadmin -setBalancerBandwidth 52428800
    # 运行数据平衡(前台运行)
    hdfs balancer -threshold 5
    # 运行数据平衡(后台运行)
    $HADOOP_HOME/sbin/start-balancer.sh -threshold 5
    # 停止数据平衡
    $HADOOP_HOME/sbin/stop-balancer.sh

    # 打印xml配置信息
    print_config < $HADOOP_CONF_DIR/core-site.xml
    print_config < $HADOOP_CONF_DIR/hdfs-site.xml
    print_config < $HADOOP_CONF_DIR/mapred-site.xml
    print_config < $HADOOP_CONF_DIR/yarn-site.xml

    # namenode Web UI: http://hdpc1-mn01:50070/

    # yarn Web UI: http://hdpc1-mn01:8088/
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-b backup] [-c create user<add/delete>] [-d detect environment] [-h config host<hostname,hosts>] [-i install] [-k config ssh] [-s start<init/start/stop/restart>] [-u uninstall file,log,conf,data,env,user] [-v verbose]"
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    # -b 备份重要文件
    # -c [add/delete] 创建用户
    # -d 检测环境
    # -h [hostname,hosts] 配置host
    # -i 安装集群
    # -k 配置ssh免密码登录
    # -s [init/start/stop/restart] 启动/停止集群
    # -v debug模式
    while getopts "iksr" name; do
        case "$name" in
            i)
                init_flag=1;;
            r)
                restart_flag=1;;
            s)
                start_flag=1;;
            t)
                stop_flag=1;;
            u)
                upgrade_flag=1;;
            v)
                debug_flag=1;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    # 初始化
    [[ $init_flag ]] && log_fn init

    # 启动
    [[ $start_flag ]] && log_fn start

    # 停止
    [[ $stop_flag ]] && log_fn stop

    # 重启
    [[ $restart_flag ]] && log_fn restart

    # 滚动重启
    [[ $upgrade_flag ]] && log_fn rolling_restart
}
main "$@"