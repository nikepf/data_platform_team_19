#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
mkdir -p results
hdfs dfs -mkdir -p /user/team/hw4/input
hdfs dfs -put -f data.csv /user/team/hw4/input/data.csv
spark-submit --master yarn --deploy-mode client pipeline.py > results/spark.log 2>&1
hdfs dfs -test -e /user/team/hw4/sales_daily/_SUCCESS
beeline_hw4 -e "
CREATE DATABASE IF NOT EXISTS hw4;
CREATE EXTERNAL TABLE IF NOT EXISTS hw4.sales_daily (
  product STRING,
  orders BIGINT,
  quantity BIGINT,
  revenue DECIMAL(12,2)
)
PARTITIONED BY (dt STRING)
STORED AS PARQUET
LOCATION '/user/team/hw4/sales_daily';
MSCK REPAIR TABLE hw4.sales_daily SYNC PARTITIONS;
" > results/table.log 2>&1
