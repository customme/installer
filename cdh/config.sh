#!/bin/bash
#
# Author: superz
# Date: 2019-07-16
# Description: CDH集群配置


# CDH集群配置信息
# ip hostname admin_user admin_passwd roles
HOSTS="192.168.30.120 cdh1 root Xs.admin! cm-server,cm-agent
192.168.30.21 cdh2 root Xs.admin! cm-agent,database
192.168.30.22 cdh3 root Xs.admin! cm-agent
192.168.30.23 cdh4 root Xs.admin! cm-agent
192.168.30.24 cdh5 root Xs.admin! cm-agent"

# 数据库服务器
DB_HOST=192.168.30.21
DB_PORT=3306
DB_USER=root
DB_PASSWORD=123456

# 数据库
# dbname user password
DBS="scm scm scm123
amon amon amon123
rman rman rman123
hue hue hue123
metastore hive hive123
sentry sentry sentry123
nav nav nav123
navms navms navms123
oozie oozie oozie123"

# CM软件包
CM_VERSION=6.2.0
CM_BUILD_NO=968826
CM_MIRROR=https://archive.cloudera.com/cm6/$CM_VERSION/redhat7/yum/RPMS/x86_64
CM_AGENT_RPM=cloudera-manager-agent-${CM_VERSION}-${CM_BUILD_NO}.el7.x86_64.rpm
CM_AGENT_URL=$CM_MIRROR/$CM_AGENT_RPM
CM_DAEMONS_RPM=cloudera-manager-daemons-${CM_VERSION}-${CM_BUILD_NO}.el7.x86_64.rpm
CM_DAEMONS_URL=$CM_MIRROR/$CM_DAEMONS_RPM
CM_SERVER_RPM=cloudera-manager-server-${CM_VERSION}-${CM_BUILD_NO}.el7.x86_64.rpm
CM_SERVER_URL=$CM_MIRROR/$CM_SERVER_RPM

# CDH软件包
CDH_BUILD_NO=967373
CDH_MIRROR=https://archive.cloudera.com/cdh6/$CM_VERSION/parcels
CDH_PARCEL=CDH-${CM_VERSION}-1.cdh${CM_VERSION}.p0.${CDH_BUILD_NO}-el7.parcel
CDH_PARCEL_URL=$CDH_MIRROR/$CDH_PARCEL
CDH_MANIFEST=manifest.json
CDH_MANIFEST_URL=$CDH_MIRROR/$CDH_MANIFEST
CDH_PARCEL_DIR=/opt/cloudera/parcel-repo

# MySQL JDBC驱动
MYSQL_JDBC_VERSION=5.1.47
MYSQL_JDBC_NAME=mysql-connector-java-${MYSQL_JDBC_VERSION}
MYSQL_JDBC_PKG=${MYSQL_JDBC_NAME}.tar.gz
MYSQL_JDBC_JAR=${MYSQL_JDBC_NAME}.jar
MYSQL_JDBC_URL=https://cdn.mysql.com//Downloads/Connector-J/$MYSQL_JDBC_PKG
SHARE_LIB_DIR=/usr/share/java
