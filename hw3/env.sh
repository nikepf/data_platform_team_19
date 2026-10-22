#!/usr/bin/env bash
export JAVA_HOME="$HOME/java8-hw3"
export HADOOP_HOME="$HOME/hadoop-hw1"
export HADOOP_CONF_DIR="$HOME/hive-hw3/hadoop-conf"
export HIVE_HOME="$HOME/hive-hw3"
export HIVE_CONF_DIR="$HIVE_HOME/conf"
export HADOOP_HEAPSIZE=512
export PATH="$JAVA_HOME/bin:$HIVE_HOME/bin:$HADOOP_HOME/bin:$PATH"
beeline_hw3() {
  "$HIVE_HOME/bin/beeline" -u 'jdbc:hive2://127.0.0.1:10000/default' \
    -n team --silent=true --showHeader=false --outputformat=tsv2 "$@"
}
