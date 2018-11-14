#!/bin/bash
#
# nginx管理


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


if [[ -f $DIR/common.sh ]]; then
    source $DIR/common.sh
elif [[ -f $DIR/../common/common.sh ]]; then
    source $DIR/../common/common.sh
fi
source $DIR/config.sh


# 启动
function start()
{
    # 创建日志文件目录
    mkdir -p $NGINX_LOG_DIR
    # 创建临时文件目录
    nginx -V 2>&1 | grep "configure arguments" | awk -F '=' 'BEGIN{RS=" "} /-temp-path/ {print $2}' | xargs -r mkdir -p

    # 修改目录所有者
    chown -R $NGINX_USER:$NGINX_GROUP $NGINX_LOG_DIR
    if [[ -n "$NGINX_TMP_DIR" && -d $NGINX_LOG_DIR ]]; then
        chown -R $NGINX_USER:$NGINX_GROUP $NGINX_TMP_DIR
    fi

    if [[ "$SYS_VERSION" =~ 6 ]]; then
        service nginx start
    elif [[ "$SYS_VERSION" =~ 7 ]]; then
        systemctl start nginx.service
    fi
}

# 用法
function usage()
{
    echo "Usage: $0 [-s start] [-v verbose]"
}

# 管理
function admin()
{
    # 启动
    nginx -c /etc/nginx/nginx.conf

    # 快速关闭
    nginx -s stop
    # 正常关闭
    nginx -s quit

    # 重新加载配置
    nginx -s reload

    # 检查配置文件
    nginx -t -c /etc/nginx/nginx.conf

    # 查看版本
    nginx -V

    # 重新打开日志文件
    nginx -s reopen
}

function main()
{
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    while getopts "acdirsuv" name; do
        case "$name" in
            s)
                start_flag=1;;
            v)
                debug_flag=1;;
            ?)
                usage
                exit 1;;
        esac
    done

    [[ $start_flag ]] && log_fn start
}
main "$@"