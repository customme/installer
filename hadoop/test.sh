#!/bin/bash
#
# Author: superz
# Date: 2018-09-30
# Description: hadoop测试


# 测试
function test()
{
    # 开启debug模式
    export HADOOP_ROOT_LOGGER=DEBUG,console

    # 上传本地文件到hdfs
    hdfs dfs -mkdir /input
    hdfs dfs -put $HADOOP_HOME/LICENSE.txt /input

    # 执行mapreduce任务
    yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-${HADOOP_VERSION}.jar wordcount /input /output

    # 基准测试
    yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-${HADOOP_VERSION}-tests.jar

    # webhdfs
    curl "http://hdpc1-mn01:50070/webhdfs/v1/?op=liststatus&user.name=hdfs"
}
