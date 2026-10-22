#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
. ./env.sh
mkdir -p results
if [ "$#" = 0 ]; then
  printf '1,book,120.00\n2,pen,30.00\n' > results/2026-10-21.csv
  printf '3,book,150.00\n4,pencil,20.00\n' > results/2026-10-22.csv
  bash ./load.sh results/2026-10-21.csv 2026-10-21
  bash ./load.sh results/2026-10-22.csv 2026-10-22
  exit
fi
[ "$#" = 2 ]
file=$1
day=$2
python3 - "$file" "$day" <<'PY'
import csv, datetime, re, sys
path, day = sys.argv[1:]
assert re.fullmatch(r'\d{4}-\d{2}-\d{2}', day), 'Дата: YYYY-MM-DD'
datetime.date.fromisoformat(day)
with open(path, newline='') as source:
    count = 0
    for row in csv.reader(source):
        assert len(row) == 3, 'Нужны id,product,amount без заголовка'
        assert re.fullmatch(r'[0-9]+', row[0]) and int(row[0]) <= 2147483647
        assert re.fullmatch(r'[A-Za-z0-9_ -]+', row[1]), 'CSV должен быть без кавычек и разделителей в полях'
        assert re.fullmatch(r'[0-9]{1,8}(\.[0-9]{1,2})?', row[2]), 'amount: DECIMAL(10,2) >= 0'
        count += 1
    assert count > 0, 'Пустой файл'
PY
stage="/user/team/hw3/staging/$(date +%s)-$$"
hdfs dfs -mkdir -p "$stage"
normalized=$(mktemp)
trap 'rm -f "$normalized"' EXIT
python3 - "$file" "$normalized" <<'PY'
import csv, sys
with open(sys.argv[1], newline='') as source, open(sys.argv[2], 'w') as target:
    for row in csv.reader(source):
        target.write(','.join(row) + '\n')
PY
hdfs dfs -put "$normalized" "$stage/data.csv"
beeline_hw3 -e "
CREATE DATABASE IF NOT EXISTS hw3;
CREATE EXTERNAL TABLE IF NOT EXISTS hw3.sales (
  id INT, product STRING, amount DECIMAL(10,2)
)
PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/user/team/hw3/sales';
LOAD DATA INPATH '$stage/data.csv' OVERWRITE INTO TABLE hw3.sales PARTITION (dt='$day');
" > "results/load-$day.log" 2>&1
hdfs dfs -rmdir "$stage"
