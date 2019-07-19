#!/bin/bash
#
# 用yum安装mysql


MYSQL_VERSION=5.7.26
MYSQL_YUM_RPM=mysql80-community-release-el7-3.noarch.rpm
MYSQL_YUM_URL=https://repo.mysql.com/$MYSQL_YUM_RPM
MYSQL_GROUP=mysql
MYSQL_USER=mysql
MYSQL_CONF_DIR=/etc
MYSQL_DATA_DIR=/var/mysql/data
MYSQL_LOG_DIR=/var/mysql/log
MYSQL_PORT=3306
MYSQL_CHARSET=utf8
MYSQL_PASSWD=mysql


# 安装
function install()
{
    # 下载mysql yum源RPM包
    if [[ ! -f $MYSQL_YUM_RPM ]]; then
        wget $MYSQL_YUM_URL
    fi

    # 安装mysql yum源
    yum localinstall -y $MYSQL_YUM_RPM

    # 启用指定版本并禁用其他版本
    local version=`echo $MYSQL_VERSION | awk -F '.' '{print $1$2}'`
    sed -i '/mysql[0-9][0-9]/{n;n;n;s/enabled=1/enabled=0/}' /etc/yum.repos.d/mysql-community.repo
    sed -i "/mysql$version/{n;n;n;s/enabled=0/enabled=1/}" /etc/yum.repos.d/mysql-community.repo
#    yum-config-manager --enable mysql$version-community
#    yum-config-manager --disable mysql$version-community

    # 安装
    yum install -y mysql-community-server mysql-community-devel
}

# 配置
function config()
{
    sed -i "/\[mysqld\]/a\character_set_server=$MYSQL_CHARSET" $MYSQL_CONF_DIR/my.cnf
    sed -i "/\[mysqld\]/a\port=$MYSQL_PORT" $MYSQL_CONF_DIR/my.cnf
    sed -i "s#^\(datadir=\).*#\1$MYSQL_DATA_DIR#" $MYSQL_CONF_DIR/my.cnf
    sed -i "s#^\(log-error=\).*\(\/mysqld\.log\)#\1$MYSQL_LOG_DIR\2#" $MYSQL_CONF_DIR/my.cnf
    sed -i "$ a \\\n[client]" $MYSQL_CONF_DIR/my.cnf
    sed -i "$ a default-character_set=$MYSQL_CHARSET" $MYSQL_CONF_DIR/my.cnf
}

# 创建目录
function create_dir()
{
    mkdir -p $MYSQL_DATA_DIR $MYSQL_LOG_DIR
    chown -R $MYSQL_USER:$MYSQL_GROUP $MYSQL_DATA_DIR $MYSQL_LOG_DIR
}

# 初始化
function init()
{
    # 启动
    systemctl start mysqld
    # 重置密码
    mysql_secure_installation
}

# 初始化mysql57
function init_57()
{
    # 启动
    systemctl start mysqld

    # 获取默认密码
    local password=`awk '$0 ~ /temporary password/ {print $NF}' $MYSQL_LOG_DIR/mysqld.log`
    # 修改密码
    echo "SET GLOBAL validate_password_policy=0;
    SET GLOBAL validate_password_length=1;
    ALTER USER USER() IDENTIFIED BY '$MYSQL_PASSWD';" |
    mysql -uroot -p"$password" --connect-expired-password
}

function main()
{
    # 出错立即退出
    set -e

    # 安装
    install

    # 配置
    config

    # 创建目录
    create_dir

    # 初始化
    if [[ $MYSQL_VERSION =~ 5.7 ]]; then
        init_57
    else
        init
    fi
}
main "$@"