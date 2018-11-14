#!/bin/bash
#
# nginx自动编译安装程序


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


# 初始化
function init()
{
    # 安装依赖
    yum install -y wget bzip2 unzip
    yum install -y gcc gcc-c++ make automake autoconf
    yum install -y lua-devel gd-devel
}

# 下载安装包
function download()
{
    # 出错立即退出
    set -e

    # 下载
    if [[ ! -f $NGINX_PKG ]]; then
        debug "Wget $NGINX_URL"
        wget -c $NGINX_URL
    fi
    if [[ ! -f $PCRE_PKG ]]; then
        debug "Wget $PCRE_URL"
        wget -c $PCRE_URL
    fi
    if [[ ! -f $OPENSSL_PKG ]]; then
        debug "Wget $OPENSSL_URL"
        wget -c $OPENSSL_URL
    fi
    if [[ ! -f $ZLIB_PKG ]]; then
        debug "Wget $ZLIB_URL"
        wget -c $ZLIB_URL
    fi
    if [[ ! -f $CACHE_PURGE_PKG ]]; then
        debug "Wget $CACHE_PURGE_URL"
        wget -c $CACHE_PURGE_URL
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

# 安装
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
--with-ld-opt="-Wl,-rpath,/usr/local/lib"

    # 构建
    make

    # 安装
    make install

    # 清理
    cd - > /dev/null
    rm -rf $NGINX_NAME $PCRE_NAME $OPENSSL_NAME $ZLIB_NAME $CACHE_PURGE_NAME $DEVEL_KIT_NAME $FORM_INPUT_NAME $UPSTREAM_NAME $LUA_NAME
}

# 注册服务
function reg_service()
{
    if [[ "$SYS_VERSION" =~ 6 ]]; then
        conf_service > /etc/init.d/nginx
        chmod +x /etc/init.d/nginx
        chkconfig --add /etc/init.d/nginx
        chkconfig nginx on
    elif [[ "$SYS_VERSION" =~ 7 ]]; then
        conf_service_7 > /lib/systemd/system/nginx.service
        chmod +x /lib/systemd/system/nginx.service
        systemctl enable nginx.service
    fi
}

# 卸载nginx
function clean_nginx()
{
    # 关闭nginx
    nginx -s quit

    # 删除安装目录 配置文件目录 日志目录
    rm -rf $NGINX_INSTALL_DIR $NGINX_CONF_DIR $NGINX_LOG_DIR /usr/sbin/nginx

    if [[ "$SYS_VERSION" =~ 6 ]]; then
        chkconfig --del /etc/init.d/nginx
        chkconfig nginx off
        rm -f /etc/init.d/nginx
    elif [[ "$SYS_VERSION" =~ 7 ]]; then
        systemctl disable nginx.service
        rm -f /lib/systemd/system/nginx.service
    fi
}

# 用法
function usage()
{
    echo "Usage: $0 [ -c create user ] [ -d download source package ] [ -i install ] [ -r register system service ] [ -u uninstall ] [ -v verbose ]"
}

function main()
{
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    while getopts "acdirsuv" name; do
        case "$name" in
            c)
                create_flag=1;;
            d)
                download_flag=1;;
            i)
                install_flag=1;;
            r)
                register_flag=1;;
            u)
                clean_flag=1;;
            v)
                debug_flag=1;;
            ?)
                usage
                exit 1;;
        esac
    done

    [[ $create_flag ]] && log_fn create_user

    [[ $download_flag ]] && log_fn download

    [[ $install_flag ]] && log_fn install

    [[ $register_flag ]] && log_fn reg_service

    [[ $clean_flag ]] && log_fn clean_nginx
}
main "$@"