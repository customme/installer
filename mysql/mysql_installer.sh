#!/bin/bash
#
# MySQL安装运维手册


MYSQL_VERSION=5.7.22
MYSQL_RPM=mysql-community-${MYSQL_VERSION}-1.el7.src.rpm
MYSQL_URL=https://cdn.mysql.com/archives/mysql-${MYSQL_VERSION%.*}/$MYSQL_RPM
MYSQL_GROUP=mysql
MYSQL_USER=mysql
MYSQL_INSTALL_DIR=/usr/local
MYSQL_HOME=/usr/local/mysql-$MYSQL_VERSION
MYSQL_CONF_DIR=/etc
MYSQL_DATA_DIR=/data/mysql
MYSQL_LOG_DIR=/log/mysql
MYSQL_TMP_DIR=/tmp/mysql
MYSQL_PORT=3306
MYSQL_CHARSET=utf8

BOOST_VERSION=1.66.0
BOOST_PKG=boost_${BOOST_VERSION//./_}.tar.gz
BOOST_URL=https://sourceforge.net/projects/boost/files/boost/$BOOST_VERSION/$BOOST_PKG
BOOST_INSTALL_DIR=/usr/local
BOOST_HOME=/usr/local/boost-$BOOST_VERSION


# 安装环境
function install_env()
{
    yum install -y gcc gcc-c++ ncurses ncurses-devel bison libgcrypt perl make cmake
}

# 创建用户/组
function create_user()
{
    groupadd $MYSQL_GROUP
    useradd -r -M -s /bin/nologin -g $MYSQL_GROUP $MYSQL_USER
}

# 创建目录并授权
function create_dir()
{
    mkdir -p $MYSQL_CONF_DIR $MYSQL_DATA_DIR $MYSQL_LOG_DIR $MYSQL_TMP_DIR
    chown -R $MYSQL_USER:$MYSQL_GROUP $MYSQL_DATA_DIR $MYSQL_LOG_DIR $MYSQL_TMP_DIR
}

# 编译
function build()
{
    # 下载boost
    if [[ ! -s $BOOST_PKG ]]; then
        wget -c $BOOST_PKG
    fi
    tar -zxf $BOOST_PKG -C $BOOST_INSTALL_DIR

    # 下载mysql
    if [[ ! -s $MYSQL_RPM ]]; then
        wget -c $MYSQL_URL
    fi
    rpm -i $MYSQL_RPM
    tar -zxf ./rpmbuild/SOURCES/mysql-${MYSQL_VERSION}.tar.gz
    cd mysql-${MYSQL_VERSION}

    make clean

    cmake . -DCMAKE_INSTALL_PREFIX=$MYSQL_HOME \
-DSYSCONFDIR=$MYSQL_CONF_DIR \
-DMYSQL_DATADIR=$MYSQL_DATA_DIR \
-DMYSQL_UNIX_ADDR=$MYSQL_HOME/mysql.sock \
-DMYSQL_TCP_PORT=$MYSQL_PORT \
-DMYSQL_USER=$MYSQL_USER \
-DDOWNLOAD_BOOST=1 \
-DWITH_BOOST=$BOOST_HOME \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_PARTITION_STORAGE_ENGINE=1 \
-DWITH_ARCHIVE_STORAGE_ENGINE=1 \
-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
-DWITH_MEMORY_STORAGE_ENGINE=1 \
-DENABLED_LOCAL_INFILE=1 \
-DDEFAULT_CHARSET=$MYSQL_CHARSET \
-DDEFAULT_COLLATION=${MYSQL_CHARSET}_general_ci \
-DENABLE_DTRACE=0 \
-DWITH_EMBEDDED_SERVER=1

    make -j `grep processor /proc/cpuinfo | wc -l`

    make install
}

# 启动
function start()
{
    mysqld_safe --defaults-file=/etc/my.cnf &
}
