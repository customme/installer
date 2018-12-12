#!/bin/bash
#
# gitlab安装运维手册


GIBLAB_VERSION=11.4.7


# 安装环境
function install_env()
{
    yum install -y curl policycoreutils-python openssh-server patch
}

# 安装
function install()
{
    # 下载并安装
    curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ee/script.rpm.sh | sudo bash
    wget https://mirrors.tuna.tsinghua.edu.cn/gitlab-ce/yum/el7/gitlab-ce-11.2.3-ce.0.el7.x86_64.rpm
    EXTERNAL_URL="http://gitlab.example.com"
    yum install -y gitlab-ee

    # 修改nginx端口
#    /etc/gitlab/gitlab.rb
#    nginx['listen_port'] = 90

    # 运行gitlab-ctl reconfigure命令后/var/opt/gitlab/nginx/conf/gitlab-http.conf nginx端口会自动改过来
}

# 汉化
function chinesize()
{
    # 获取汉化包
    git clone https://gitlab.com/xhang/gitlab.git

    # 比较汉化标签和源标签，导出patch
    cd gitlab
    git diff v$GIBLAB_VERSION v$GIBLAB_VERSION-zh > ../$GIBLAB_VERSION-zh.diff

    # 更新补丁到gitlab中
    cd -
    patch -d /opt/gitlab/embedded/service/gitlab-rails -p1 < $GIBLAB_VERSION-zh.diff
    # 按住回车键
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
