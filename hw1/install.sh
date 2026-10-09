#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

[ "$(id -un)" = team ]
[ -f hadoop-3.4.2.tar.gz ]

sudo apt-get update
sudo apt-get install -y openjdk-11-jdk

export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-$(dpkg --print-architecture)"
export HADOOP_HOME="$HOME/hadoop-hw1"
[ -x "$JAVA_HOME/bin/java" ]

if [ ! -e "$HADOOP_HOME" ]; then
  mkdir -p "$HADOOP_HOME"
  tar -xzf hadoop-3.4.2.tar.gz \
    -C "$HADOOP_HOME" --strip-components=1
fi
[ -x "$HADOOP_HOME/bin/hdfs" ]

mkdir -p "$HOME/hdfs-hw1/"{name,data,checkpoint} \
  "$HADOOP_HOME/pids"
chmod 700 "$HADOOP_HOME/pids"

printf '\nexport JAVA_HOME="%s"\nexport HADOOP_PID_DIR="%s"\n' \
  "$JAVA_HOME" "$HADOOP_HOME/pids" \
  >> "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"

cat > "$HADOOP_HOME/etc/hadoop/core-site.xml" <<'XML'
<?xml version="1.0"?>
<configuration>
  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://team-19-nn:9000</value>
  </property>
</configuration>
XML

cat > "$HADOOP_HOME/etc/hadoop/hdfs-site.xml" <<XML
<?xml version="1.0"?>
<configuration>
  <property><name>dfs.replication</name><value>3</value></property>
  <property><name>dfs.namenode.name.dir</name><value>file://$HOME/hdfs-hw1/name</value></property>
  <property><name>dfs.datanode.data.dir</name><value>file://$HOME/hdfs-hw1/data</value></property>
  <property><name>dfs.namenode.checkpoint.dir</name><value>file://$HOME/hdfs-hw1/checkpoint</value></property>
  <property><name>dfs.namenode.http-address</name><value>team-19-nn:9870</value></property>
  <property><name>dfs.namenode.secondary.http-address</name><value>team-19-en:9868</value></property>
</configuration>
XML

"$HADOOP_HOME/bin/hadoop" version
