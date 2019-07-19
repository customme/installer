#!/bin/bash
#
# Author: superz
# Date: 2019-07-16
# Description: Cloudera Manager集群管理


# 初始化
function init()
{
    # 出错立即退出
    set -e

    # 开机自启动
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            systemctl enable cloudera-scm-server
            systemctl enable cloudera-scm-agent
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "systemctl enable cloudera-scm-server"
            autossh "$admin_passwd" ${admin_user}@${ip} "systemctl enable cloudera-scm-agent"
        fi
    done

    # 启动
    start
}

# 启动集群
function start()
{
    # 出错立即退出
    set -e

    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            systemctl start cloudera-scm-server
            systemctl start cloudera-scm-agent
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "systemctl start cloudera-scm-server"
            autossh "$admin_passwd" ${admin_user}@${ip} "systemctl start cloudera-scm-agent"
        fi
    done
}

# 停止集群
function stop()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            systemctl stop cloudera-scm-server
            systemctl stop cloudera-scm-agent
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "systemctl stop cloudera-scm-server"
            autossh "$admin_passwd" ${admin_user}@${ip} "systemctl stop cloudera-scm-agent"
        fi
    done
}

# 管理
function admin()
{
    todo_fn
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-i init] [-r restart] [-s start] [-t stop] [-v verbose]"
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    # -i 初始化
    # -r 重启
    # -s 启动
    # -t 关闭
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
}
main "$@"