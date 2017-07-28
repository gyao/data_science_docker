#!/bin/bash

: ${HADOOP_PREFIX:=/opt/hadoop}

chmod +x $HADOOP_PREFIX/etc/hadoop/hadoop-env.sh
$HADOOP_PREFIX/etc/hadoop/hadoop-env.sh

if [ -f /tmp/*.pid ]; then
  rm /tmp/*.pid
fi

# installing libraries if any - (resource urls added comma separated to the ACP system variable)
cd $HADOOP_PREFIX/share/hadoop/common ; for cp in ${ACP//,/ }; do  echo == $cp; curl -LO $cp ; done; cd -

cp $SPARK_HOME/conf/metrics.properties.template $SPARK_HOME/conf/metrics.properties

# start hadoop
service ssh start
$HADOOP_PREFIX/sbin/start-dfs.sh
$HADOOP_PREFIX/sbin/start-yarn.sh
$HADOOP_PREFIX/sbin/hadoop-daemon.sh start portmap
$HADOOP_PREFIX/sbin/hadoop-daemon.sh start nfs3

$HADOOP_PREFIX/bin/hdfs dfsadmin -safemode leave && $HADOOP_PREFIX/bin/hdfs dfs -put $SPARK_HOME-$SPARK_VERSION-bin-hadoop$HADOOP_PROFILE/lib /spark

# start spark
export SPARK_MASTER_OPTS="-Dspark.driver.port=7001 -Dspark.fileserver.port=7002
  -Dspark.broadcast.port=7003 -Dspark.replClassServer.port=7004
  -Dspark.blockManager.port=7005 -Dspark.executor.port=7006
  -Dspark.ui.port=4040 -Dspark.broadcast.factory=org.apache.spark.broadcast.HttpBroadcastFactory"
export SPARK_WORKER_OPTS="-Dspark.driver.port=7001 -Dspark.fileserver.port=7002
  -Dspark.broadcast.port=7003 -Dspark.replClassServer.port=7004
  -Dspark.blockManager.port=7005 -Dspark.executor.port=7006
  -Dspark.ui.port=4040 -Dspark.broadcast.factory=org.apache.spark.broadcast.HttpBroadcastFactory"

export SPARK_MASTER_PORT=7077

cd /opt/spark/sbin
./start-master.sh
./start-slave.sh spark://`hostname`:$SPARK_MASTER_PORT
./start-history-server.sh


# start rstudio
/usr/lib/rstudio-server/bin/rserver

CMD=${1:-"exit 0"}
if [[ "$CMD" == "-d" ]];
then
	service sshd stop
	/usr/sbin/sshd -D -d
else
	/bin/bash -c "$*"
fi