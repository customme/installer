#!/bin/bash
#
# kvm安装运维


# 安装kvm
function install_kvm()
{
    yum install -y qemu-kvm        # 用来创建虚拟机硬盘
    yum install -y libvirt         # 用来管理虚拟机
    yum install -y virt-install    # 用来创建虚拟机
}

# 管理kvm
function admin_kvm()
{
    systemctl enable libvirtd    # 开机自启动
    systemctl start libvirtd     # 启动kvm服务
    systemctl stop libvirtd      # 关闭kvm服务
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

    local vm_path=/data/kvm/${vm_name}.img

    local base_path=/usr/local/src
    case "$vm_os" in
        centos6)
            local os_type=linux
            local vm_img=$base_path/CentOS-6.10-x86_64-bin-DVD1.iso
        ;;
        centos7)
            local os_type=linux
            local vm_img=$base_path/CentOS-7-x86_64-DVD-1804.iso
        ;;
        win7)
            local os_type=windows
            local vm_img=$base_path/cn_windows_7_ultimate_with_sp1_x64_dvd_u_677408.iso
        ;;
        win10)
            local os_type=windows
            local vm_img=$base_path/cn_windows_10_multi-edition_vl_version_1709_updated_sept_2017_x64_dvd_100090774.iso
        ;;
        server2008)
            local os_type=windows
            local vm_img=$base_path/cn_windows_server_2008_r2.iso
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
}
