#!/usr/bin/env bash
export JAVA_HOME="/usr/lib/jvm/java-11-openjdk-$(dpkg --print-architecture)"
export HADOOP_HOME="$HOME/hadoop-hw1"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export SPARK_HOME="$HOME/spark-hw4"
export SPARK_CONF_DIR="$SPARK_HOME/conf"
export PYSPARK_PYTHON=/usr/bin/python3
export PYSPARK_DRIVER_PYTHON=/usr/bin/python3
export PATH="$JAVA_HOME/bin:$SPARK_HOME/bin:$HADOOP_HOME/bin:$PATH"
beeline_hw4() {
  JAVA_HOME="$HOME/java8-hw3" \
  HADOOP_CONF_DIR="$HOME/hive-hw3/hadoop-conf" \
  HIVE_CONF_DIR="$HOME/hive-hw3/conf" \
    "$HOME/hive-hw3/bin/beeline" \
    -u 'jdbc:hive2://127.0.0.1:10000/default' \
    -n team --silent=true --showHeader=false --outputformat=tsv2 "$@"
}
