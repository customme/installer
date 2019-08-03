#!/bin/bash
#
# kvm安装运维


# 安装包目录
SRC_DIR=/usr/local/src
# KVM镜像目录
IMG_DIR=/work/kvm/img


# 安装kvm
function install_kvm()
{
    yum install -y qemu-kvm        # 用来创建虚拟机硬盘
    yum install -y libvirt         # 用来管理虚拟机
    yum install -y virt-install    # 用来创建虚拟机
    yum install -y bridge-utils    # kvm桥接网络模式用到
}

# 管理kvm
function admin_kvm()
{
    systemctl enable libvirtd    # 开机自启动
    systemctl start libvirtd     # 启动kvm服务
    systemctl stop libvirtd      # 关闭kvm服务
}

# 配置网桥
function config_bridge()
{
    cat > /etc/sysconfig/network-scripts/ifcfg-br0 << EOF
DEVICE=br0
TYPE=Bridge
BOOTPROTO=static
IPADDR="192.168.1.13"
NETMASK="255.255.255.0"
GATEWAY="192.168.1.1"
ONBOOT=yes
DEFROUTE=yes
DNS1="202.96.134.133"
DNS2="202.96.128.86"
EOF

    # 将物理网口桥接到桥接器
    cat > /etc/sysconfig/network-scripts/ifcfg-eno1 << EOF
DEVICE=eno1
TYPE=Ethernet
BOOTPROTO=none
BRIDGE=br0
NM_CONTROLLED=no
ONBOOT=yes
NAME="System eno1"
EOF
}

# 创建虚拟机
function create_vm()
{
    local vm_name="$1"
    local vm_ram="$2"
    local vm_cpu="$3"
    local vm_os="$4"
    local vm_disk="$5"
    local vnc_port="$6"

    local vm_path=$IMG_DIR/${vm_name}.img

    case "$vm_os" in
        centos6)
            local os_type=linux
            local vm_img=`find $SRC_DIR -type f -name "CentOS-6*" | sort | tail -n 1`
        ;;
        centos7)
            local os_type=linux
            local vm_img=`find $SRC_DIR -type f -name "CentOS-7*" | sort | tail -n 1`
        ;;
        win7)
            local os_type=windows
            local vm_img=`find $SRC_DIR -type f -name "cn_windows_7*" | sort | tail -n 1`
        ;;
        win10)
            local os_type=windows
            local vm_img=`find $SRC_DIR -type f -name "cn_windows_10*" | sort | tail -n 1`
        ;;
        server2008)
            local os_type=windows
            local vm_img=`find $SRC_DIR -type f -name "cn_windows_server_2008*" | sort | tail -n 1`
        ;;
        *)
            echo "Error: unsupported os: $vm_os"
            return 1
        ;;
    esac

    if [[ ! -s $vm_img ]]; then
        echo "Error: system file does not exists: $vm_img"
        return 1
    fi

    # 创建目录
    mkdir -p $IMG_DIR

    # 安装
    virt-install --name $vm_name --ram=$vm_ram --vcpus=$vm_cpu --os-type=$os_type --accelerate -c $vm_img --disk path=$vm_path,size=$vm_disk --network bridge:br0 --vnc --vncport=$vnc_port --vnclisten=0.0.0.0 --force --autostart
}

# 管理虚拟机
function admin_vm()
{
    virsh list                 # 列出运行中的虚拟机
    virsh list --all           # 列出所有虚拟机
    virsh start $vm_name       # 启动虚拟机
    virsh shutdown $vm_name    # 关闭虚拟机
    virsh destroy $vm_name     # 强制关闭虚拟机
    virsh undefine $vm_name    # 删除虚拟机
    virsh edit $vm_name        # 编辑虚拟机(调整内存、cpu等)
    virsh dominfo $vm_name     # 查看虚拟机配置
}

function main()
{
    # 物理机10
    create_vm yygz_15 20480 4 centos7 100 5990
    create_vm yygz_16 20480 4 centos7 100 5991
    create_vm yygz_17 20480 4 centos7 100 5992
    create_vm yygz_18 20480 4 centos7 100 5993
    create_vm yygz_19 20480 4 centos7 100 5994

    # 物理机11
    create_vm yygz_20 40960 4 centos7 300 5990
    create_vm yygz_21 40960 4 centos7 300 5991

    # 物理机12
    create_vm yygz_22 40960 4 centos7 300 5990
    create_vm yygz_23 40960 4 centos7 300 5991

    # 物理机13
    create_vm yygz_24 40960 4 centos7 200 5990
    create_vm yygz_25 40960 4 centos7 200 5991
}
