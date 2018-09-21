#!/bin/bash
#
# gitlab安装运维手册


GIBLAB_VERSION=


# 安装环境
function install_env()
{
    yum install -y curl policycoreutils-python openssh-server
}

# 安装
function install()
{
    # 下载并安装
    curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.rpm.sh | sudo bash
    wget https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el7/gitlab-ce-11.2.3-ce.0.el7.x86_64.rpm
    EXTERNAL_URL="http://gitlab.example.com"
    yum install -y gitlab-ee
}

# 管理
function admin()
{
    gitlab-ctl start          # 启动所有 gitlab 组件
    gitlab-ctl stop           # 停止所有 gitlab 组件
    gitlab-ctl restart        # 重启所有 gitlab 组件
    gitlab-ctl status         # 查看服务状态
    gitlab-ctl reconfigure    # 重新编译gitlab的配置
    gitlab-ctl tail           # 查看日志
    gitlab-ctl tail nginx/gitlab_access.log
    gitlab-rake gitlab:check SANITIZE=true --trace    # 检查gitlab
}
