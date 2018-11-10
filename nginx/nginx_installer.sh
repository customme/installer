#!/bin/bash
#
# nginx自动编译安装程序


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


# 系统版本号
SYS_VERSION=`sed 's/.* release \([0-9]\.[0-9]\).*/\1/' /etc/redhat-release`

NGINX_NAME=nginx-1.14.0
NGINX_PKG=${NGINX_NAME}.tar.gz
NGINX_URL=http://nginx.org/download/$NGINX_PKG
NGINX_USER=nginx
NGINX_GROUP=nginx
NGINX_INSTALL_DIR=/usr/local/$NGINX_NAME
NGINX_CONF_DIR=/etc/nginx
NGINX_LOG_DIR=/var/log/nginx
NGINX_TMP_DIR=/var/tmp/nginx

PCRE_NAME=pcre-8.39
PCRE_PKG=${PCRE_NAME}.tar.bz2
PCRE_URL=https://ftp.pcre.org/pub/pcre/$PCRE_PKG

OPENSSL_VERSION=1.0.2n
OPENSSL_NAME=openssl-$OPENSSL_VERSION
OPENSSL_PKG=${OPENSSL_NAME}.tar.gz
OPENSSL_URL=https://www.openssl.org/source/old/${OPENSSL_VERSION%[a-z]}/$OPENSSL_PKG

ZLIB_NAME=zlib-1.2.11
ZLIB_PKG=${ZLIB_NAME}.tar.gz
ZLIB_URL=http://www.zlib.net/$ZLIB_PKG

CACHE_PURGE_NAME=ngx_cache_purge-2.3
CACHE_PURGE_PKG=${CACHE_PURGE_NAME}.tar.gz
CACHE_PURGE_URL=http://labs.frickle.com/files/$CACHE_PURGE_PKG

DEVEL_KIT_VERSION=0.3.0
DEVEL_KIT_NAME=ngx_devel_kit-${DEVEL_KIT_VERSION}
DEVEL_KIT_PKG=${DEVEL_KIT_NAME}.tar.gz
DEVEL_KIT_URL=https://github.com/simplresty/ngx_devel_kit/archive/v${DEVEL_KIT_VERSION}.tar.gz

FORM_INPUT_VERSION=0.12
FORM_INPUT_NAME=form-input-nginx-module-$FORM_INPUT_VERSION
FORM_INPUT_PKG=${FORM_INPUT_NAME}.tar.gz
FORM_INPUT_URL=https://github.com/calio/form-input-nginx-module/archive/v${FORM_INPUT_VERSION}.tar.gz

UPSTREAM_VERSION=master
UPSTREAM_NAME=nginx-upstream-fair-$UPSTREAM_VERSION
UPSTREAM_PKG=${UPSTREAM_NAME}.zip
UPSTREAM_URL=https://github.com/gnosek/nginx-upstream-fair/archive/${UPSTREAM_VERSION}.zip

LUA_VERSION=0.10.11
LUA_NAME=lua-nginx-module-$LUA_VERSION
LUA_PKG=${LUA_NAME}.tar.gz
LUA_URL=https://github.com/openresty/lua-nginx-module/archive/v${LUA_VERSION}.tar.gz


# 记录日志
function log()
{
    echo "$(date +'%F %T') [ $@ ]"
}

# 在方法执行前后记录日志
function log_fn()
{
    log "Call function [ $@ ] begin"
    $@
    log "Call function [ $@ ] end"
}

# 记录详细日志
function debug()
{
    if [[ -n "$debug_flag" && $debug_flag -eq 1 ]]; then
        log "$@"
    fi
}

# 初始化
function init()
{
    # 安装依赖
    yum -y install wget bzip2 unzip
    yum -y install gcc gcc-c++ make automake autoconf
    yum -y install lua-devel gd-devel
}

# 下载安装包
function download()
{
    # 出错立即退出
    set -e

    # 下载
    if [[ ! -f $NGINX_PKG ]]; then
        debug "Wget $NGINX_URL"
        wget -c $NGINX_URL -O $NGINX_PKG
    fi
    if [[ ! -f $PCRE_PKG ]]; then
        debug "Wget $PCRE_URL"
        wget -c $PCRE_URL -O $PCRE_PKG
    fi
    if [[ ! -f $OPENSSL_PKG ]]; then
        debug "Wget $OPENSSL_URL"
        wget -c $OPENSSL_URL -O $OPENSSL_PKG
    fi
    if [[ ! -f $ZLIB_PKG ]]; then
        debug "Wget $ZLIB_URL"
        wget -c $ZLIB_URL -O $ZLIB_PKG
    fi
    if [[ ! -f $CACHE_PURGE_PKG ]]; then
        debug "Wget $CACHE_PURGE_URL"
        wget -c $CACHE_PURGE_URL -O $CACHE_PURGE_PKG
    fi
    if [[ ! -f $DEVEL_KIT_PKG ]]; then
        debug "Wget $DEVEL_KIT_URL"
        wget -c $DEVEL_KIT_URL -O $DEVEL_KIT_PKG
    fi
    if [[ ! -f $FORM_INPUT_PKG ]]; then
        debug "Wget $FORM_INPUT_URL"
        wget -c $FORM_INPUT_URL -O $FORM_INPUT_PKG
    fi
    if [[ ! -f $UPSTREAM_PKG ]]; then
        debug "Wget $UPSTREAM_URL"
        wget -c $UPSTREAM_URL -O $UPSTREAM_PKG
    fi
    if [[ ! -f $LUA_PKG ]]; then
        debug "Wget $LUA_URL"
        wget -c $LUA_URL -O $LUA_PKG
    fi
}

# 创建用户
function create_user()
{
    # 出错不要立即退出
    set +e

    groupadd -f $NGINX_GROUP
    useradd -M -s /bin/nologin $NGINX_USER -g $NGINX_GROUP
}

function install()
{
    init

    # 出错立即退出
    set -e

    # 解压
    tar -xzf $NGINX_PKG
    tar -xjf $PCRE_PKG
    tar -xzf $OPENSSL_PKG
    tar -xzf $ZLIB_PKG
    tar -xzf $CACHE_PURGE_PKG
    tar -xzf $DEVEL_KIT_PKG
    tar -xzf $FORM_INPUT_PKG
    unzip -o $UPSTREAM_PKG
    tar -xzf $LUA_PKG

    cd $NGINX_NAME

    # 配置
    ./configure --user=$NGINX_USER --group=$NGINX_GROUP \
--prefix=$NGINX_INSTALL_DIR \
--sbin-path=/usr/sbin/nginx \
--conf-path=$NGINX_CONF_DIR/nginx.conf \
--http-log-path=$NGINX_LOG_DIR/access.log \
--error-log-path=$NGINX_LOG_DIR/error.log \
--pid-path=$NGINX_LOG_DIR/nginx.pid \
--lock-path=$NGINX_LOG_DIR/nginx.lock \
--with-poll_module \
--with-http_ssl_module \
--with-http_sub_module \
--with-http_gzip_static_module \
--with-http_random_index_module \
--with-http_secure_link_module \
--with-http_stub_status_module \
--with-http_realip_module \
--with-http_image_filter_module \
--with-pcre=$DIR/$PCRE_NAME \
--with-openssl=$DIR/$OPENSSL_NAME \
--with-zlib=$DIR/$ZLIB_NAME \
--add-module=$DIR/$CACHE_PURGE_NAME \
--add-module=$DIR/$DEVEL_KIT_NAME \
--add-module=$DIR/$FORM_INPUT_NAME \
--add-module=$DIR/$UPSTREAM_NAME \
--add-module=$DIR/$LUA_NAME \
--with-ld-opt="-Wl,-rpath,/usr/local/lib" \
--http-client-body-temp-path=$NGINX_TMP_DIR/client \
--http-proxy-temp-path=$NGINX_TMP_DIR/proxy \
--http-fastcgi-temp-path=$NGINX_TMP_DIR/fcgi \
--http-uwsgi-temp-path=$NGINX_TMP_DIR/uwsgi \
--http-scgi-temp-path=$NGINX_TMP_DIR/scgi

    # 构建
    make

    # 安装
    make install

    # 清理
    cd -
    rm -rf $NGINX_NAME $PCRE_NAME $OPENSSL_NAME $ZLIB_NAME $CACHE_PURGE_NAME $DEVEL_KIT_NAME $FORM_INPUT_NAME $UPSTREAM_NAME $LUA_NAME
}

# 生成服务脚本
function gen_service()
{
    echo -e "
#!/bin/bash
#
# nginx - this script starts and stops the nginx daemon
#
# chkconfig: - 85 15
# description: Nginx is an HTTP(S) server, HTTP(S) reverse
# proxy and IMAP/POP3 proxy server
# processname: nginx
# config: /etc/nginx/nginx.conf
# config: /etc/sysconfig/nginx
# pidfile: /var/run/nginx.pid

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ "$NETWORKING" = "no" ] && exit 0

TENGINE_HOME="/work/install/nginx-1.10.3"
nginx="/usr/sbin/nginx"
prog=$(basename $nginx)

NGINX_CONF_FILE="/work/install/nginx-1.10.3/conf/nginx.conf"

[ -f /etc/sysconfig/nginx ] && /etc/sysconfig/nginx

lockfile=/var/lock/subsys/nginx

start() {
    [ -x $nginx ] || exit 5
    [ -f $NGINX_CONF_FILE ] || exit 6
    echo -n $"Starting $prog: "
    daemon $nginx -c $NGINX_CONF_FILE
    retval=$?
    echo
    [ $retval -eq 0 ] && touch $lockfile
    return $retval
}

stop() {
    echo -n $"Stopping $prog: "
    killproc $prog -QUIT
    retval=$?
    echo
    [ $retval -eq 0 ] && rm -f $lockfile
    return $retval
    killall -9 nginx
}

restart() {
    configtest || return $?
    stop
    sleep 1
    start
}

reload() {
    configtest || return $?
    echo -n $"Reloading $prog: "
    killproc $nginx -HUP
    RETVAL=$?
    echo
}

force_reload() {
    restart
}

configtest() {
    $nginx -t -c $NGINX_CONF_FILE
}

rh_status() {
    status $prog
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}

case "$1" in
start)
    rh_status_q && exit 0
    $1
;;
stop)
    rh_status_q || exit 0
    $1
;;
restart|configtest)
    $1
;;
reload)
    rh_status_q || exit 7
    $1
;;
force-reload)
    force_reload
;;
status)
    rh_status
;;
condrestart|try-restart)
    rh_status_q || exit 0
;;
*)

echo $"Usage: $0 {start|stop|status|restart|condrestart|try-restart|reload|force-reload|configtest}"
exit 2
esac
"
}

# 生成服务脚本 centos 7
function gen_service_7()
{
    echo -e "
[Unit]
Description=The nginx HTTP and reverse proxy server
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=$NGINX_LOG_DIR/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
"
}

# 注册服务
function reg_service()
{
    if [[ "$SYS_VERSION" =~ 6 ]]; then
        gen_service > /etc/init.d/nginx
        chmod +x /etc/init.d/nginx
    elif [[ "$SYS_VERSION" =~ 7 ]]; then
        gen_service_7 > /lib/systemd/system/nginx.service
        chmod +x /lib/systemd/system/nginx.service
    fi
}

# 启动
function start()
{
    # 创建目录
    mkdir -p $NGINX_LOG_DIR $NGINX_TMP_DIR
    nginx -V 2>&1 | grep "configure arguments" | awk -F '=' 'BEGIN{RS=" "} /-temp-path/ {print $2}' | xargs -r mkdir -p

    # 修改目录所有者
    chown -R $NGINX_USER:$NGINX_GROUP $NGINX_LOG_DIR $NGINX_TMP_DIR

    if [[ "$SYS_VERSION" =~ 6 ]]; then
        service nginx start
    elif [[ "$SYS_VERSION" =~ 7 ]]; then
        systemctl start nginx.service
    fi
}

# 开机自启动
function auto_start()
{
    if [[ "$SYS_VERSION" =~ 6 ]]; then
        chkconfig --add /etc/init.d/nginx
        chkconfig nginx on
    elif [[ "$SYS_VERSION" =~ 7 ]]; then
        systemctl enable nginx.service
    fi
}

# 卸载nginx
function clean_nginx()
{
    # 关闭nginx
    nginx -s quit

    # 删除安装目录 配置文件目录 日志目录 临时目录
    rm -rf $NGINX_INSTALL_DIR $NGINX_CONF_DIR $NGINX_LOG_DIR $NGINX_TMP_DIR /usr/sbin/nginx

    if [[ "$SYS_VERSION" =~ 6 ]]; then
        chkconfig --del /etc/init.d/nginx
        chkconfig nginx off
        rm -f /etc/init.d/nginx
    elif [[ "$SYS_VERSION" =~ 7 ]]; then
        systemctl disable nginx.service
        rm -f /lib/systemd/system/nginx.service
    fi
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-a auto start] [-c create user] [-d download] [-i install] [-r register system service] [-s start] [-u uninstall] [-v verbose]"
}

# 管理
function admin()
{
    # 启动
    nginx -c nginx.conf

    # 快速关闭
    nginx -s stop
    # 正常关闭
    nginx -s quit

    # 重新加载配置
    nginx -s reload

    # 检查配置文件
    nginx -t -c nginx.conf

    # 查看版本
    nginx -V

    # 重新打开日志文件
    nginx -s reopen
}

function main()
{
    if [[ $# -eq 0 ]]; then
        print_usage
        exit 1
    fi

    while getopts "acdirsuv" name; do
        case "$name" in
            a)
                auto_flag=1;;
            c)
                create_flag=1;;
            d)
                download_flag=1;;
            i)
                install_flag=1;;
            r)
                register_flag=1;;
            s)
                start_flag=1;;
            u)
                clean_flag=1;;
            v)
                debug_flag=1;;
            ?)
                print_usage
                exit 1;;
        esac
    done

    [[ $create_flag ]] && log_fn create_user

    [[ $download_flag ]] && log_fn download

    [[ $install_flag ]] && log_fn install

    [[ $register_flag ]] && log_fn reg_service

    [[ $auto_flag ]] && log_fn auto_start

    [[ $start_flag ]] && log_fn start

    [[ $clean_flag ]] && log_fn clean_nginx
}
main "$@"