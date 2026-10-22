#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
mkdir -p results
beeline_hw4 -e 'SHOW PARTITIONS hw4.sales_daily;' > results/partitions.txt 2> results/partitions.log
printf 'dt=2026-10-21\ndt=2026-10-22\n' > results/expected-partitions.txt
diff -u results/expected-partitions.txt results/partitions.txt
beeline_hw4 -e 'SELECT dt, product, orders, quantity, revenue FROM hw4.sales_daily ORDER BY dt, product;' \
  > results/hive.txt 2> results/hive.log
printf '2026-10-21\tBOOK\t2\t3\t250.00\n2026-10-21\tPEN\t1\t3\t30.00\n2026-10-22\tBOOK\t1\t2\t240.00\n2026-10-22\tPEN\t1\t2\t30.00\n' > results/expected-hive.txt
diff -u results/expected-hive.txt results/hive.txt
hdfs dfs -test -e /user/team/hw4/sales_daily/_SUCCESS
hdfs dfs -ls -R /user/team/hw4/sales_daily > results/hdfs.txt
app=$(sed -nE 's/.*Submitted application (application_[0-9]+_[0-9]+).*/\1/p' results/spark.log | tail -n 1)
[ -n "$app" ]
yarn application -status "$app" > results/yarn.txt 2>&1
grep -Eq '^[[:space:]]*Application-Type[[:space:]]*:[[:space:]]*SPARK[[:space:]]*$' results/yarn.txt
grep -Eq '^[[:space:]]*State[[:space:]]*:[[:space:]]*FINISHED[[:space:]]*$' results/yarn.txt
grep -Eq '^[[:space:]]*Final-State[[:space:]]*:[[:space:]]*SUCCEEDED[[:space:]]*$' results/yarn.txt
