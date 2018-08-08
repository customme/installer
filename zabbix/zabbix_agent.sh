#!/bin/bash

####定义变量
LOG="/tmp/zabbix_agentd_install.log"
CONF="/etc/zabbix/zabbix_agentd.conf"
IP="zabbix-server.gzserv.com"
release=`cat /etc/redhat-release  | grep -o [0-9].[0-9] | awk -F. '{print $1}' | head -n 1`
local_ip=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`

#release=`lsb_release -a | grep Release | awk '{print $2}' | awk -F. '{print $1}'`

####定义函数，判断是否出错
ERROR(){
if [ $? -ne 0 ];then
	echo "$1  return an error" && exit
fi
}

####安装相应的包
#yum -y install wget nc gcc gcc++


####下载安装agent

if [ ${release} -eq 6 ];then
	wget http://$IP/download/zabbix-agent-3.2.1-1.el6.x86_64.rpm
elif [ ${release} -eq 7 ];then
	wget http://$IP/download/zabbix-agent-3.2.1-1.el7.x86_64.rpm
fi

yum install -y zabbix-agent-3.2.1-1.e*.rpm


###修改agent配置文件	
sed -i "s/Server\=127.0.0.1/Server\=127.0.0.1,$IP/g" ${CONF}
sed -i "s/ServerActive\=127.0.0.1/ServerActive\=$IP:10051/g" ${CONF}
sed -i "s/Hostname=Zabbix server/Hostname=${local_ip}/g" ${CONF}
sed -i "s/# StartAgents=3/StartAgents=8/g" ${CONF} 
sed -i "s/# RefreshActiveChecks=120/RefreshActiveChecks=60/g" ${CONF}
sed -i "s/# BufferSend=5/BufferSend=10/g" ${CONF}
sed -i "s/# BufferSize=100/BufferSize=10000/g" ${CONF}
sed -i "s/# MaxLinesPerSecond=20/MaxLinesPerSecond=200/g" ${CONF}
sed -i "s/# Timeout=3/Timeout=20/g" ${CONF}
sed -i "s/# AllowRoot=0/AllowRoot=1/g" ${CONF}
sed -i "s/# UnsafeUserParameters=0/UnsafeUserParameters=1/g" ${CONF}

sed '295,$d' -i  ${CONF}


####启动客户端 
if [ ${release} -eq 6 ];then
    service zabbix-agent start
elif [ ${release} -eq 7 ];then
    systemctl start zabbix-agent.service
fi
	
netstat -tualnp | grep 10050 |wc -l

