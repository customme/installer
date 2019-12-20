#!/bin/bash
#
# 自动安装shadowsocks服务器

# 获取python版本
PYTHON_VERSION=$(python -V 2>&1 | awk '{printf("%d"),$2}')

# 安装
function install()
{
	# 安装依赖
	yum install -y m2crypto python-setuptools net-tools lrzsz

	# 安装python包管理工具pip
	# 用pip安装shadowsocks
	if [[ $PYTHON_VERSION -eq 2 ]];then
		yum install -y python2-pip && pip install shadowsocks || (yum install -y python3-pip && pip3 install shadowsocks)
	else
		yum install -y python3-pip && pip3 install shadowsocks
	fi
}

# 配置
function config()
{
	cat > /etc/shadowsocks.conf << EOF
{
    "server": "0.0.0.0",
    "port_password": {
        "443": "mh8728*1158"
    },
    "timeout": 300,
    "method": "rc4-md5"
}
EOF
}

# 添加服务
function add_service()
{
	bin_path=$(which ssserver)
	cat > /etc/systemd/system/shadowsocks.service << EOF
[Unit]
Description=Shadowsocks
[Service]
TimeoutStartSec=0
ExecStart=$bin_path -c /etc/shadowsocks.conf
[Install]
WantedBy=multi-user.target
EOF
}

# 启动
function startup()
{
	systemctl start shadowsocks

	# 开放端口
	firewall-cmd --zone=public --add-port=443-450/tcp --permanent
	firewall-cmd --reload
}

# 卸载
function uninstall()
{
	# 停服务
	systemctl stop shadowsocks

	# 卸载安装包
	if [[ $PYTHON_VERSION -eq 2 ]];then
		pip uninstall shadowsocks || pip3 uninstall shadowsocks
		yum remove -y python2-pip || yum remove -y python3-pip
	else
		pip3 uninstall shadowsocks
		yum remove -y python3-pip
	fi

	# 删除配置文件
	rm -f /etc/shadowsocks.conf

	# 删除服务
	rm -f /etc/systemd/system/shadowsocks.service
}

# 管理
function admin()
{
	systemctl enable shadowsocks
	systemctl start shadowsocks
	systemctl stop shadowsocks
	systemctl status shadowsocks
}

# 用法
function usage()
{
    echo "Usage: $0 [ -i install ] [ -u uninstall ]"
}

function main()
{
	if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    while getopts "iu" name; do
        case "$name" in
            i)
                install
                config
                add_service
                startup;;
            u)
                uninstall;;
            ?)
                usage
                exit 1;;
        esac
    done
}
main "$@"