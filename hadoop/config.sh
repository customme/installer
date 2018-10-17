# Author: superz
#
# Author: superz
# Date: 2018-09-30
# Description: hadoop集群配置
# Dependency: yum autossh autoscp


# 本机ip
LOCAL_IP=`ifconfig eth0 2> /dev/null | grep "inet addr" | cut -d ":" -f 2 | cut -d " " -f 1`
if [[ -z "$LOCAL_IP" ]]; then
    LOCAL_IP=`ifconfig eno1 2> /dev/null | grep "inet " | awk '{print $2}'`
fi

# 系统版本号
SYS_VERSION=`sed 's/.* release \([0-9]\.[0-9]\).*/\1/' /etc/redhat-release`

# 时间服务器
TIME_SERVER=1.asia.pool.ntp.org

# ssh端口
SSH_PORT=22

# 用户库文件目录
LIB_DIR=lib


# hadoop集群配置信息
# ip hostname admin_user admin_passwd owner_passwd roles
HOSTS="10.10.10.61 yygz-61.gzserv.com root 123456 hadoop123 namenode,zkfc,yarn,historyserver
10.10.10.64 yygz-64.gzserv.com root 123456 hadoop123 namenode,zkfc,httpfs,yarn
10.10.10.65 yygz-65.gzserv.com root 123456 hadoop123 datanode,journalnode,zookeeper
10.10.10.66 yygz-66.gzserv.com root 123456 hadoop123 datanode,journalnode,zookeeper
10.10.10.67 yygz-67.gzserv.com root 123456 hadoop123 datanode,journalnode,zookeeper"


# hadoop镜像
HADOOP_MIRROR=http://mirror.bit.edu.cn/apache/hadoop/common
HADOOP_NAME=hadoop-$HADOOP_VERSION
# hadoop安装包名
HADOOP_PKG=${HADOOP_NAME}.tar.gz
# hadoop安装包下载地址
HADOOP_URL=$HADOOP_MIRROR/$HADOOP_NAME/$HADOOP_PKG

# 相关目录
HADOOP_PID_DIR=$HADOOP_TMP_DIR
YARN_PID_DIR=$HADOOP_TMP_DIR
YARN_LOG_DIR=$HADOOP_LOG_DIR
HADOOP_MAPRED_PID_DIR=$HADOOP_TMP_DIR
HADOOP_MAPRED_LOG_DIR=$HADOOP_LOG_DIR
HTTPFS_LOG_DIR=$HADOOP_LOG_DIR
HTTPFS_TMP_DIR=$HADOOP_TMP_DIR

# dfs exclude hosts
DFS_EXCLUDE_FILE=excludes

# 当前用户名，所属组
THE_USER=$HDFS_USER
THE_GROUP=$HDFS_GROUP

# 用户hadoop配置文件目录
CONF_DIR=$CONF_DIR/hadoop

# hadoop组件版本
HADOOP_VERSION=2.7.7

# 安装目录
BASE_INSTALL_DIR=/usr
HADOOP_INSTALL_DIR=$BASE_INSTALL_DIR/hadoop

# 用户名，所属组
HDFS_USER=hdfs
HDFS_GROUP=hadoop

# 环境变量
HADOOP_HOME=$HADOOP_INSTALL_DIR/current

# 配置文件目录
HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop

# 相关目录根目录
HADOOP_TMP_DIR=/work/hadoop/tmp
HADOOP_DATA_DIR=/work/hadoop/data
HADOOP_LOG_DIR=/work/hadoop/log

# nameservice id
NAMESERVICE_ID=dfs-study
NAMESERVICE_ID1=nn1
NAMESERVICE_ID2=nn2
# yarn cluster id
YARN_CLUSTER_ID=yarn-study
YARN_RM_ID1=rm1
YARN_RM_ID2=rm2

# yarn staging目录
YARN_STAG_DIR=hdfs://$NAMESERVICE_ID/tmp
# hive仓库目录
HIVE_DB_DIR=hdfs://$NAMESERVICE_ID/hive/warehouse
# hbase数据目录
HBASE_ROOT_DIR=hdfs://$NAMESERVICE_ID/hbase

# namenode数据目录
DFS_NAME_DIR=$HADOOP_DATA_DIR/dfsname
# datanode数据目录
DFS_DATA_DIR=$HADOOP_DATA_DIR/dfsdata

# hadoop heapsize
# $HADOOP_CONF_DIR/hadoop-env.sh
HADOOP_NAMENODE_HEAP="-Xms16g -Xmx16g"
HADOOP_DATANODE_HEAP="-Xms2g -Xmx2g"
HADOOP_CLIENT_HEAP="-Xms32m -Xmx4g"
# $HADOOP_CONF_DIR/yarn-env.sh
YARN_RESOURCEMANAGER_HEAP="-Xms4g -Xmx4g"
YARN_NODEMANAGER_HEAP="-Xms2g -Xmx2g"
# $HADOOP_CONF_DIR/mapred-env.sh
MR_HISTORYSERVER_HEAP=1024

# namenode rpc端口
NAMENODE_RPC_PORT=8020
# namenode http端口
NAMENODE_HTTP_PORT=50070
# datanode ipc port
DATANODE_IPC_PORT=50020
# QJM服务端口
QJM_SERVER_PORT=8485
# jobhistory服务端口
JOBHISTORY_SERVER_PORT=10020
# jobhistory web端口
JOBHISTORY_WEB_PORT=19888
# jobhistory admin端口
JOBHISTORY_ADMIN_PORT=10033
# yarn web端口
YARN_WEB_PORT=8088

# hadoop jmx
HADOOP_JMX_BASE="-Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false"
HADOOP_NAMENODE_JMX_PORT=8004
HADOOP_DATANODE_JMX_PORT=8006
YARN_RESOURCEMANAGER_JMX_PORT=8008
YARN_NODEMANAGER_JMX_PORT=8009


# core 配置
function core_config()
{
    # Basic
    echo "
fs.defaultFS=hdfs://$NAMESERVICE_ID
hadoop.tmp.dir=$HADOOP_TMP_DIR
fs.trash.interval=4320
fs.trash.checkpoint.interval=60
"

    # HTTPFS
    echo "
hadoop.proxyuser.hdfs.hosts=*
hadoop.proxyuser.hdfs.groups=*
"

    # Tuning
    echo "
io.file.buffer.size=4096
ipc.server.listen.queue.size=128
"
}

# hdfs 配置
function hdfs_config()
{
    # Basic
    echo "
dfs.namenode.name.dir=file://$DFS_NAME_DIR
dfs.datanode.data.dir=file://$DFS_DATA_DIR
dfs.replication=2
dfs.datanode.du.reserved=1073741824
dfs.blockreport.intervalMsec=600000
dfs.datanode.directoryscan.interval=600
dfs.namenode.datanode.registration.ip-hostname-check=false
dfs.hosts.exclude=$HADOOP_CONF_DIR/excludes
"

    local namenodes=(`echo "$HOSTS" | awk '$6 ~ /namenode/ {printf("%s ",$2)}'`)
    local journalnodes=`echo "$HOSTS" | awk '$6 ~ /journalnode/ {printf("%s:%s,",$2,"'$QJM_SERVER_PORT'")}' | sed 's/,$//'`

    # NameNode HA
    echo "
dfs.nameservices=$NAMESERVICE_ID
dfs.ha.namenodes.$NAMESERVICE_ID=$NAMESERVICE_ID1,$NAMESERVICE_ID2
dfs.namenode.rpc-address.$NAMESERVICE_ID.NAMESERVICE_ID1=${namenodes[0]}:$NAMENODE_RPC_PORT
dfs.namenode.rpc-address.$NAMESERVICE_ID.NAMESERVICE_ID2=${namenodes[1]}:$NAMENODE_RPC_PORT
dfs.namenode.http-address.$NAMESERVICE_ID.NAMESERVICE_ID1=${namenodes[0]}:$NAMENODE_HTTP_PORT
dfs.namenode.http-address.$NAMESERVICE_ID.NAMESERVICE_ID2=${namenodes[1]}:$NAMENODE_HTTP_PORT
dfs.namenode.shared.edits.dir=qjournal:/$journalnodes/$NAMESERVICE_ID
dfs.client.failover.proxy.provider.$NAMESERVICE_ID=org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider
dfs.ha.fencing.methods=sshfence
dfs.ha.fencing.ssh.private-key-files=/home/$HDFS_USER/.ssh/id_rsa
dfs.ha.fencing.ssh.connect-timeout=30000
dfs.journalnode.edits.dir=$HADOOP_DATA_DIR/journal
dfs.ha.automatic-failover.enabled=true
ha.zookeeper.session-timeout.ms=10000
"

    # Tuning
    echo "
dfs.blocksize=64m
dfs.namenode.handler.count=10
dfs.datanode.handler.count=10
dfs.datanode.max.transfer.threads=4096
dfs.datanode.balance.bandwidthPerSec=10485760
dfs.namenode.replication.work.multiplier.per.iteration=4
dfs.namenode.replication.max-streams=10
dfs.namenode.replication.max-streams-hard-limit=20
"
}

# mapred 配置
function mapred_config()
{
    local historyserver=`echo "$HOSTS" | awk '$6 ~ /historyserver/ {print $2}'`

    # Basic
    echo "
mapreduce.framework.name=yarn
mapreduce.jobhistory.address=$historyserver:$JOBHISTORY_SERVER_PORT
mapreduce.jobhistory.webapp.address=$historyserver:$JOBHISTORY_WEB_PORT
mapreduce.jobhistory.admin.address=$historyserver:$JOBHISTORY_ADMIN_PORT
yarn.app.mapreduce.am.staging-dir=/tmp
"

    # Tuning
    echo "
mapreduce.map.memory.mb=512
mapreduce.map.java.opts=-Xmx410m
mapreduce.reduce.memory.mb=512
mapreduce.reduce.java.opts=-Xmx410m
yarn.app.mapreduce.am.resource.mb=512
yarn.app.mapreduce.am.command-opts=-Xmx410m
mapreduce.task.io.sort.mb=100
mapreduce.jobtracker.handler.count=10
mapreduce.tasktracker.http.threads=40
mapreduce.tasktracker.map.tasks.maximum=2
mapreduce.tasktracker.reduce.tasks.maximum=2
"
}

# yarn 配置
function yarn_config()
{
    # Basic
    echo "
yarn.nodemanager.log-dirs=$HADOOP_LOG_DIR/yarn
yarn.nodemanager.remote-app-log-dir=/log/yarn
yarn.nodemanager.aux-services=mapreduce_shuffle
yarn.log-aggregation-enable=true
yarn.log-aggregation.retain-seconds=2592000
yarn.nodemanager.vmem-check-enabled=false
"

    local resourcemanagers=(`echo "$HOSTS" | awk '$6 ~ /yarn/ {printf("%s ",$2)}'`)
    local zookeepers=`echo "$HOSTS" | awk '$6 ~ /zookeeper/ {printf("%s:%s,",$2,"'$ZK_SERVER_PORT'")}' | sed 's/,$//'`

    # ResourceManager HA
    echo "
yarn.resourcemanager.ha.enabled=true
yarn.resourcemanager.cluster-id=$YARN_CLUSTER_ID
yarn.resourcemanager.ha.rm-ids=$YARN_RM_ID1,$YARN_RM_ID2
yarn.resourcemanager.hostname.$YARN_RM_ID1=${resourcemanagers[0]}
yarn.resourcemanager.hostname.$YARN_RM_ID2=${resourcemanagers[1]}
yarn.resourcemanager.webapp.address.$YARN_RM_ID1=${resourcemanagers[0]}:$YARN_WEB_PORT
yarn.resourcemanager.webapp.address.$YARN_RM_ID2=${resourcemanagers[1]}:$YARN_WEB_PORT
yarn.resourcemanager.recovery.enabled=true
yarn.resourcemanager.store.class=org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore
yarn.resourcemanager.zk-address=$zookeepers
"

    # Tuning
    echo "
yarn.nodemanager.resource.memory-mb=2048
yarn.nodemanager.resource.cpu-vcores=2
yarn.scheduler.minimum-allocation-mb=256
yarn.scheduler.maximum-allocation-mb=2048
yarn.scheduler.maximum-allocation-vcores=2
"
}

# httpfs 配置
function httpfs_config()
{
    # Hue HttpFS
    echo "
httpfs.proxyuser.hue.hosts=*
httpfs.proxyuser.hue.groups=*
"
}
