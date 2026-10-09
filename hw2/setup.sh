#!/usr/bin/env bash
set -euo pipefail

[ "$(id -un)" = team ]
configs=${1:-configs}
[ -f "$configs/yarn-site.xml" ]
[ -f "$configs/mapred-site.xml" ]

node=$(hostname -s)
case "$node" in
  team-19-en) ip=10.19.0.10 ;;
  team-19-nn) ip=10.19.0.11 ;;
  team-19-00) ip=10.19.0.12 ;;
  team-19-01) ip=10.19.0.13 ;;
  *) exit 1 ;;
esac

for name in "$node" "$node.hse.c.mws"; do
  getent ahostsv4 "$name" | awk -v ip="$ip" '$1 != ip {bad=1} END {exit (NR == 0 || bad)}'
done

export HADOOP_HOME="$HOME/hadoop-hw1"
[ -x "$HADOOP_HOME/bin/yarn" ]
. "$HADOOP_HOME/etc/hadoop/hadoop-env.sh"
[ -x "$JAVA_HOME/bin/java" ]

mkdir -p "$HOME/yarn-hw2/"{local,containers}

for file in yarn-site.xml mapred-site.xml yarn-env.sh mapred-env.sh; do
  if [ -f "$HADOOP_HOME/etc/hadoop/$file" ] && [ ! -e "$HADOOP_HOME/etc/hadoop/$file.hw2-backup" ]; then
    cp "$HADOOP_HOME/etc/hadoop/$file" "$HADOOP_HOME/etc/hadoop/$file.hw2-backup"
  fi
done

for file in yarn-env.sh mapred-env.sh; do
  if ! grep -qx 'export HADOOP_HEAPSIZE_MAX=256m' "$HADOOP_HOME/etc/hadoop/$file"; then
    printf '\nexport HADOOP_HEAPSIZE_MAX=256m\n' >> "$HADOOP_HOME/etc/hadoop/$file"
  fi
done

sed "s/@NODE@/$node/g" "$configs/yarn-site.xml" > "$HADOOP_HOME/etc/hadoop/yarn-site.xml"
cp "$configs/mapred-site.xml" "$HADOOP_HOME/etc/hadoop/mapred-site.xml"
