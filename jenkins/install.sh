#!/bin/bash
#
# jenkins安装运维手册


BASE_DIR=`pwd`
REL_DIR=`dirname $0`
cd $REL_DIR
DIR=`pwd`
cd - > /dev/null


JENKINS_VERSION=2.172
JENKINS_URL=http://mirrors.jenkins.io/war/${JENKINS_VERSION}/jenkins.war

# 下载
wget $JENKINS_URL

# 启动
java -jar jenkins.war


# 常见问题及解决办法
# sun.security.provider.certpath.SunCertPathBuilderException: unable to find valid certification path to requested target
# 修改/root/.jenkins/hudson.model.UpdateCenter.xml，将https://updates.jenkins.io/update-center.json中的https改为http

# 该Jenkins实例似乎已离线
# 修改/root/.jenkins/updates/default.json，将"connectionCheckUrl":"http://www.google.com/"中的google改为baidu
