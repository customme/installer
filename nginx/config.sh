#!/bin/bash
#
# nginx配置


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


# 生成服务脚本
function conf_service()
{
    echo '''
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
'''
}

# 生成服务脚本 centos 7
function conf_service_7()
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
