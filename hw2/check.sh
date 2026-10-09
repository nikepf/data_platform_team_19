#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

[ "$(id -un)" = team ]
[ "$(hostname -s)" = team-19-en ]

export HADOOP_HOME="$HOME/hadoop-hw1"
export PATH="$HADOOP_HOME/bin:$PATH"
mkdir -p results

yarn --daemon status nodemanager > results/processes.txt

ssh -i "$HOME/.ssh/team_internal" team@team-19-nn \
  '"$HOME/hadoop-hw1/bin/yarn" --daemon status resourcemanager && "$HOME/hadoop-hw1/bin/mapred" --daemon status historyserver' \
  >> results/processes.txt

for host in team-19-00 team-19-01; do
  ssh -i "$HOME/.ssh/team_internal" "team@$host" \
    '"$HOME/hadoop-hw1/bin/yarn" --daemon status nodemanager' \
    >> results/processes.txt
done

[ "$(grep -c 'is running as process ' results/processes.txt)" = 5 ]

ready=false
for attempt in {1..12}; do
  if timeout 30 yarn node -list -all > results/nodes.txt 2>&1 &&
    awk '
      $1 ~ /:[0-9]+$/ {
        total++
        split($1, h, ":")
        sub(/\..*$/, "", h[1])
        if ($2 == "RUNNING" && h[1] ~ /^team-19-(en|00|01)$/)
          nodes[h[1]]=1
      }
      END {
        for (node in nodes) count++
        exit !(total == 3 && count == 3)
      }
    ' results/nodes.txt; then
    ready=true
    break
  fi
  sleep 5
done

[ "$ready" = true ]

for entry in \
  '8088 /cluster' \
  '19888 /jobhistory' \
  '18042 /node' \
  '18043 /node' \
  '18044 /node'; do
  read -r port path <<< "$entry"
  code=$(curl -fsSL --connect-timeout 5 --max-time 20 \
    -o /dev/null -w '%{http_code}' \
    "http://127.0.0.1:$port$path")
  [ "$code" = 200 ]
  printf '%s %s\n' "$port" "$code"
done > results/web.txt

input=$(mktemp)
trap 'rm -f "$input"' EXIT

printf 'yarn works\nyarn runs\n' > "$input"
run="/user/team/hw2/test-$(date +%Y%m%d-%H%M%S)-${input##*/}"
printf '%s\n' "$run" > results/path.txt

hdfs dfs -mkdir -p "$run/input"
hdfs dfs -put "$input" "$run/input/words.txt"

timeout --kill-after=10s 600 hadoop jar \
  "$HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar" \
  wordcount -Dmapreduce.job.name=hw2-wordcount \
  "$run/input" "$run/output" 2>&1 | tee results/job.txt

hdfs dfs -test -e "$run/output/_SUCCESS"
hdfs dfs -cat "$run/output/part-r-*" |
  LC_ALL=C sort > results/wordcount.txt

[ "$(cat results/wordcount.txt)" = $'runs\t1\nworks\t1\nyarn\t2' ]

cat results/nodes.txt results/web.txt results/wordcount.txt
