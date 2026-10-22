#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -un)" = team ]
[ "$(hostname -s)" = team-19-en ]
sudo apt-get update
sudo apt-get install -y curl python3 openjdk-11-jdk
. ./env.sh
[ -x "$JAVA_HOME/bin/java" ]
[ -x "$HADOOP_HOME/bin/hdfs" ]
[ -x "$HOME/hive-hw3/bin/beeline" ]
hdfs dfs -test -d /
mkdir -p downloads
if [ ! -x "$SPARK_HOME/bin/spark-submit" ]; then
  archive=spark-3.5.8-bin-hadoop3.tgz
  base=https://archive.apache.org/dist/spark/spark-3.5.8
  curl -fL --retry 3 "$base/$archive" -o "downloads/$archive"
  curl -fL --retry 3 "$base/$archive.sha512" -o "downloads/$archive.sha512"
  (cd downloads && sha512sum -c "$archive.sha512")
  mkdir -p "$SPARK_HOME"
  tar -xzf "downloads/$archive" -C "$SPARK_HOME" --strip-components=1
fi
cat > "$SPARK_CONF_DIR/spark-defaults.conf" <<'CONF'
spark.master yarn
spark.submit.deployMode client
spark.driver.host 10.19.0.10
spark.driver.bindAddress 10.19.0.10
spark.driver.memory 512m
spark.executor.instances 2
spark.executor.cores 1
spark.executor.memory 512m
spark.executor.memoryOverhead 384m
spark.yarn.am.memory 256m
spark.yarn.am.memoryOverhead 128m
spark.dynamicAllocation.enabled false
spark.sql.shuffle.partitions 2
spark.sql.catalogImplementation in-memory
spark.sql.parquet.writeLegacyFormat true
spark.sql.sources.partitionColumnTypeInference.enabled false
CONF
