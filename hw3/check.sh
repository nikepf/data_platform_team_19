#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
mkdir -p results
sudo systemctl is-active hive-hw3-metastore hive-hw3-hiveserver2 > results/services.txt
beeline_hw3 -e 'SHOW PARTITIONS hw3.sales;' > results/partitions.txt 2> results/partitions.log
printf 'dt=2026-10-21\ndt=2026-10-22\n' > results/expected-partitions.txt
diff -u results/expected-partitions.txt results/partitions.txt
query="SET hive.fetch.task.conversion=none; SELECT dt, count(*), sum(amount) FROM hw3.sales GROUP BY dt ORDER BY dt;"
timeout --kill-after=10s 600 bash -c '. ./env.sh; beeline_hw3 -e "$1"' _ "$query" > results/client-1.txt 2> results/client-1.log &
pid1=$!
timeout --kill-after=10s 600 bash -c '. ./env.sh; beeline_hw3 -e "$1"' _ "$query" > results/client-2.txt 2> results/client-2.log &
pid2=$!
status=0
wait "$pid1" || status=1
wait "$pid2" || status=1
[ "$status" = 0 ]
printf '2026-10-21\t2\t150.00\n2026-10-22\t2\t170.00\n' > results/expected-clients.txt
for client in 1 2; do
  diff -u results/expected-clients.txt "results/client-$client.txt"
done
hdfs dfs -ls -R /user/team/hw3/sales > results/hdfs.txt
yarn application -list -appStates FINISHED > results/yarn.txt
