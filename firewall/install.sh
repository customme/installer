#!/bin/bash
#
# 日期: 2018-12-07
# firewall安装运维手册


# 安装
function install()
{
    yum install -y firewalld
}

# 管理
function admin()
{
    systemctl start firewalld      # 启动
    systemctl stop firewalld       # 停止
    systemctl restart firewalld    # 重启
    systemctl enable firewalld     # 开机自启动
    systemctl disable firewalld    # 禁止开机自启动

    firewall-cmd --state               # 查看防火墙运行状态
    firewall-cmd --get-active-zones    # 获取活动的区域
    firewall-cmd --get-service         # 获取所有支持的服务
    firewall-cmd --reload              # 重新加载防火墙
    firewall-cmd --list-all            # 显示所有

    firewall-cmd --zone=public --add-service=http    # 启用http服务(临时)
    firewall-cmd --zone=public --add-service=http --permanent    # 启用http服务(永久)

    firewall-cmd --zone=public --add-port=8080/tcp                # 开发端口(临时)
    firewall-cmd --zone=public --add-port=8080/tcp --permanent    # 开发端口(永久)
}
