#!/bin/bash
#
# Author: superz
# Date: 2019-07-16
# Description: Cloudera Manager集群自动安装脚本
# Dependency: yum autossh autoscp


readonly WORK_DIR=`pwd`
readonly REL_DIR=`dirname $0`
cd $REL_DIR
readonly DIR=`pwd`
cd ..
readonly BASE_DIR=`pwd`
cd $WORK_DIR


source /etc/profile
source ~/.bash_profile
source $BASE_DIR/common/common.sh
source $DIR/config.sh


# 下载
function download()
{
    # 下载CM(agent,daemons,server)
    if [[ ! -f $PKG_DIR/$CM_AGENT_RPM ]]; then
        wget $CM_AGENT_URL -P $PKG_DIR
    fi
    if [[ ! -f $PKG_DIR/$CM_DAEMONS_RPM ]]; then
        wget $CM_DAEMONS_URL -P $PKG_DIR
    fi
    if [[ ! -f $PKG_DIR/$CM_SERVER_RPM ]]; then
        wget $CM_SERVER_URL -P $PKG_DIR
    fi

    # 下载MySQL JDBC驱动
    if [[ ! -f $PKG_DIR/$MYSQL_JDBC_PKG ]]; then
        wget $MYSQL_JDBC_URL -P $PKG_DIR
    fi
    # 解压
    tar -zxf $PKG_DIR/$MYSQL_JDBC_PKG -C $PKG_DIR

    # 下载CDH(parcel,manifest)
    mkdir -p $CDH_PARCEL_DIR
    if [[ ! -f $CDH_PARCEL_DIR/$CDH_PARCEL ]]; then
        if [[ ! -f $PKG_DIR/$CDH_PARCEL ]]; then
            wget $CDH_PARCEL_URL -P $CDH_PARCEL_DIR
        else
            cp $PKG_DIR/$CDH_PARCEL $CDH_PARCEL_DIR
        fi
    fi
    if [[ ! -f $CDH_PARCEL_DIR/$CDH_MANIFEST ]]; then
        if [[ ! -f $PKG_DIR/$CDH_MANIFEST ]]; then
            wget $CDH_MANIFEST_URL -P $CDH_PARCEL_DIR
        else
            cp $PKG_DIR/$CDH_MANIFEST $CDH_PARCEL_DIR
        fi
    fi
    # 生成parcel校验和
    sha1sum $CDH_PARCEL_DIR/$CDH_PARCEL | awk '{print $1}' > $CDH_PARCEL_DIR/${CDH_PARCEL}.sha
}

# 安装CM
function install_cm()
{
    local cm_server=`echo "$HOSTS" | grep cm-server | awk '{print $2}'`
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            yum localinstall -y $PKG_DIR/$CM_DAEMONS_RPM $PKG_DIR/$CM_AGENT_RPM $PKG_DIR/$CM_SERVER_RPM
            sed -i "s/^\(server_host=\).*$/\1${cm_server}/" /etc/cloudera-scm-agent/config.ini
        else
            autoscp "$admin_passwd" $PKG_DIR/$CM_DAEMONS_RPM ${admin_user}@${ip}:$PKG_DIR $SSH_PORT 100
            autoscp "$admin_passwd" $PKG_DIR/$CM_AGENT_RPM ${admin_user}@${ip}:$PKG_DIR $SSH_PORT 100
            autossh "$admin_passwd" ${admin_user}@${ip} "yum localinstall -y $PKG_DIR/$CM_DAEMONS_RPM $PKG_DIR/$CM_AGENT_RPM"
            autossh "$admin_passwd" ${admin_user}@${ip} "sed -i \"s/^\(server_host=\).*$/\1${cm_server}/\" /etc/cloudera-scm-agent/config.ini"
        fi
    done
}

# 安装MySQL JDBC驱动
function install_jdbc()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            mkdir -p $SHARE_LIB_DIR
            cp -f $PKG_DIR/$MYSQL_JDBC_NAME/$MYSQL_JDBC_JAR $SHARE_LIB_DIR/mysql-connector-java.jar
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "mkdir -p $SHARE_LIB_DIR"
            autoscp "$admin_passwd" $PKG_DIR/$MYSQL_JDBC_NAME/$MYSQL_JDBC_JAR ${admin_user}@${ip}:$SHARE_LIB_DIR/mysql-connector-java.jar
        fi
    done
}

# 设置数据库
function setup_db()
{
    # 创建数据库以及数据库用户
    echo "$DBS" | while read db user password; do
        echo "CREATE DATABASE IF NOT EXISTS $db DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;"
        echo "GRANT ALL ON $db.* TO '$user'@'%' IDENTIFIED BY '$password';"
    done | mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD

    # 设置数据库
    /opt/cloudera/cm/schema/scm_prepare_database.sh mysql -h$DB_HOST `echo "$DBS" | grep scm`
}

# 安装
function install()
{
    # 下载软件包
    log_fn download

    # 安装CM
    log_fn install_cm

    # 安装JDBC驱动
    log_fn install_jdbc

    # 设置数据库
    log_fn setup_db
}

# 删除数据库
function drop_db()
{
    echo "$DBS" | while read db user password; do
        echo "DROP DATABASE IF EXISTS $db;"
    done | mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD
}

# 卸载
function uninstall()
{
    echo "$HOSTS" | while read ip hostname admin_user admin_passwd others; do
        if [[ "$ip" = "$LOCAL_IP" ]]; then
            yum remove -y cloudera-manager-server cloudera-manager-agent cloudera-manager-daemons
            find / -name "*cloudera*" | grep -v $PKG_DIR | xargs -r rm -rf
        else
            autossh "$admin_passwd" ${admin_user}@${ip} "yum remove -y cloudera-manager-agent cloudera-manager-daemons"
            autossh "$admin_passwd" ${admin_user}@${ip} "find / -name \"*cloudera*\" | grep -v $PKG_DIR | xargs -r rm -rf"
        fi
    done

    # 删除数据库
    drop_db
}

# 打印用法
function print_usage()
{
    echo "Usage: $0 [-c create user<add/delete>] [-d detect environment] [-h config host<hostname,hosts>] [-i install] [-k config ssh] [-s start>] [-u uninstall file,conf,data,user] [-v verbose]"
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
    # -u 卸载[file,conf,data,user]
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
    log_fn install_deps

    # 备份重要文件
    log_fn backup

    # 检测环境
    [[ $detect_flag ]] && log_fn detect_env

    # 卸载CM
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

    # 安装CM
    [[ $install_flag ]] && log_fn install

    # 启动CM
    [[ $start_flag ]] && sh admin.sh -i
}
main "$@"