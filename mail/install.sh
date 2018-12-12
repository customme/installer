#!/bin/bash
#
# 安装邮件服务器


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


source /etc/profile
source ~/.bash_profile
source $DIR/../common/common.sh
source $DIR/config.sh


# 安装环境
function install_env()
{
    # 编译环境
    yum install -y gcc gcc-c++

    # 依赖软件
    yum install -y openssl openssl-devel cyrus-sasl libtool-ltdl libtool-ltdl-devel db4 db4-devel expect expect-devel pcre pcre-devel libidn libidn-devel
}

# 安装mysql
function install_mysql()
{
    sh $DIR/../mysql/yum_install.sh

    echo "GRANT ALL ON extmail.* TO extmail@'%' IDENTIFIED BY 'extmail';" | mysql -uroot -pmysql
}

# 安装php
function install_php()
{
    yum install -y php php-mysql
}

# 安装postfix
function install_postfix()
{
    yum install -y postfix

    # 配置
    cp /etc/postfix/main.cf /etc/postfix/main.cf.old
    postconf -n > /etc/postfix/main.cf
#    vim /etc/postfix/main.cf
: '
inet_interfaces = all
mynetworks = 127.0.0.1
myhostname = mail.9zhitx.con
mydestination = $myhostname, localhost.$mydomain, localhost
# 显示连接信息
mail_name = Postfix - by 9zhitx.con
smtpd_banner = $myhostname ESMTP $mail_name
# 立即响应
smtpd_error_sleep_time = 0s
# 邮件大小和邮箱大小限制10M、2G
message_size_limit = 10485760
mailbox_size_limit = 2097152000
show_user_unknown_table_name = no
# 队列超时限制 1天
bounce_queue_lifetime = 1d
maximal_queue_lifetime = 1d
# 控制maildrop一次只处理一封邮件
maildrop_destination_recipient_limit = 1
# 添加 extmail 配置
virtual_alias_maps = mysql:/etc/postfix/mysql_virtual_alias_maps.cf
virtual_mailbox_domains = mysql:/etc/postfix/mysql_virtual_domains_maps.cf
virtual_mailbox_maps = mysql:/etc/postfix/mysql_virtual_mailbox_maps.cf
virtual_transport = maildrop
virtual_uid_maps = static:1000
virtual_gid_maps = static:1000
'

    # 启动
    systemctl start postfix
    systemctl enable postfix

    # 检查
    postfix check    # 没有错误返回表示配置正确
    postconf -a      # 出现cyrus表示可以支持cyrus认证用户
    postconf -m      # 出现mysql表示可以支持mysql存储
}

# 安装Courier-Authlib
function install_courier()
{
    # 下载软件包
    wget https://nchc.dl.sourceforge.net/project/courier/authlib/0.69.0/courier-authlib-0.69.0.tar.bz2
    wget https://nchc.dl.sourceforge.net/project/courier/courier-unicode/2.1/courier-unicode-2.1.tar.bz2
    wget https://jaist.dl.sourceforge.net/project/courier/imap/5.0.4/courier-imap-5.0.4.tar.bz2
    wget https://jaist.dl.sourceforge.net/project/courier/maildrop/3.0.0/maildrop-3.0.0.tar.bz2

    # 创建用户
    groupadd vmail -g 1000
    useradd vmail -u 1000 -g 1000 -d /home/domains

    # 编译安装courier-unicode
    tar -jxf courier-unicode-2.1.tar.bz2
    cd courier-unicode-2.1
    ./configure
    make
    make install

    # 编译安装courier-authlib
    tar -jxf courier-authlib-0.69.0.tar.bz2
    cd courier-authlib-0.69.0
    ./configure --with-mysql-libs --with-mysql-includes --with-authmysql --with-authmysql=yes --with-mailuser=vmail --with-mailgroup=vmail
    make
    make install
    make install-configure

    # 配置courier-authlib
#    vim /usr/local/etc/authlib/authmysqlrc
: '
MYSQL_SERVER            localhost
MYSQL_USERNAME          extmail
MYSQL_PASSWORD          extmail
MYSQL_SOCKET            /var/lib/mysql/mysql.sock
MYSQL_PORT              3306
MYSQL_OPT               0
MYSQL_DATABASE          extmail
MYSQL_USER_TABLE        mailbox
MYSQL_CRYPT_PWFIELD     password
MYSQL_UID_FIELD         1000
MYSQL_GID_FIELD         1000
MYSQL_LOGIN_FIELD       username
MYSQL_HOME_FIELD        homedir
MYSQL_NAME_FIELD        name
MYSQL_MAILDIR_FIELD     maildir
MYSQL_QUOTA_FIELD       quota
MYSQL_SELECT_CLAUSE     SELECT username,password,"",uidnumber,gidnumber,
                        CONCAT('/home/domains/',homedir),
                        CONCAT('/home/domains/',maildir),
                        quota,
                        name
                        FROM mailbox
                        WHERE username = '$(local_part)@$(domain)'
'
#    vim /usr/local/etc/authlib/authdaemonrc
: '
authmodulelist="authmysql" 
authmodulelistorig="authmysql"
'
    ln -s /usr/local/etc/authlib /etc/authlib

    # 启动courier-authlib
    authdaemond start
    echo "/usr/local/sbin/authdaemond start" >> /etc/rc.d/rc.local

    # 编译安装maildrop
    tar -jxf maildrop-3.0.0.tar.bz2
    cd maildrop-3.0.0
    ./configure --enable-maildirquota --enable-maildrop-uid=1000 --enable-maildrop-gid=1000 --with-trashquota
    make
    make install

    # 配置maildrop
#    vim /etc/postfix/master.cf
: '
maildrop   unix        -       n        n        -        -        pipe
  flags=DRhu user=vmail argv=/usr/local/bin/maildrop -w 90 -d ${user}@${nexthop} ${recipient} ${user} ${extension} {nexthop}
'
}

# 安装extmail
function install_extmail()
{
    tar -zxf extmail-1.2.tar.gz
    tar -zxf extman-1.1.tar.gz
    mkdir -p /var/www/extsuite
    mv extmail-1.2 /var/www/extsuite/extmail
    mv extman-1.1 /var/www/extsuite/extman

    # 配置extmail
    cp /var/www/extsuite/extmail/webmail.cf.default /var/www/extsuite/extmail/webmail.cf
#    vim /var/www/extsuite/extmail/webmail.cf
: '
SYS_MYSQL_USER = extmail
SYS_MYSQL_PASS = extmail
SYS_MYSQL_DB = extmail
'

    # 配置extman
    mkdir -p /var/www/extsuite/extman/session
    cp /var/www/extsuite/extman/webman.cf.default /var/www/extsuite/extman/webman.cf
#    vim /var/www/extsuite/extman/webman.cf
: '
SYS_SESS_DIR = /var/www/extsuite/extman/session/
SYS_DEFAULT_UID = 1000
SYS_DEFAULT_GID = 1000
'

    # 初始化数据库
    sed -i 's/TYPE=/ENGINE=/g' /var/www/extsuite/extman/docs/extmail.sql
    mysql -uroot -pmysql < /var/www/extsuite/extman/docs/extmail.sql
    sed -i 's/extmail.org/9zhitx.con/g' /var/www/extsuite/extman/docs/init.sql
    mysql -uroot -pmysql < /var/www/extsuite/extman/docs/init.sql

    # 配置postfix
    cp /var/www/extsuite/extman/docs/mysql_*.cf /etc/postfix

    # 设置权限和属主
    chown -R root:root /var/www/extsuite/extmail /var/www/extsuite/extman
    chown -R vmail:vmail /var/www/extsuite/extmail/cgi /var/www/extsuite/extman/cgi /var/www/extsuite/extman/session

    # 建立Maildir
    /var/www/extsuite/extman/tools/maildirmake.pl /home/vmail/9zhitx.con/postmaster/Maildir
    chown -R vmail:vmail /home/vmail

    # 测试authlib认证登陆账号
    systemctl restart postfix
    systemctl restart httpd
    authdaemond restart
    authtest -s login postmaster@9zhitx.con extmail
}

# 安装apache
function install_apache()
{
    yum install -y httpd httpd-devel

    # 配置apache
#    vim /etc/httpd/conf.d/extmail.conf
: '
# VirtualHost for ExtMail Solution
NameVirtualHost *:80
<VirtualHost *:80>
ServerName mail.yourmail.com
DocumentRoot /var/www/extsuite/extmail/html/
ScriptAlias /extmail/cgi/ /var/www/extsuite/extmail/cgi/
Alias /extmail /var/www/extsuite/extmail/html/
ScriptAlias /extman/cgi/ /var/www/extsuite/extman/cgi/
Alias /extman /var/www/extsuite/extman/html/
# Suexec config
SuexecUserGroup vmail vmail
</VirtualHost>
'
}

# 安装其他依赖包
function install_others()
{
    yum install -y cpan perl perl-YAML perl-Test-Exception perl-Crypt-PasswdMD5 perl-GD perl-CGI perl-Time-HiRes
    yum install -y rrdtool rrdtool-perl

    # 安装绘图工具
    cp -R /var/www/extsuite/extman/addon/mailgraph_ext /usr/local
    # 启动绘图工具
    /usr/local/mailgraph_ext/mailgraph-init start

    /var/www/extsuite/extman/daemon/cmdserver -v -d
}

function main()
{
    install_env

    install_mysql

    install_php

    install_postfix

    install_courier

    install_extmail

    install_apache
}