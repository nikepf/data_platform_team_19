#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

[ "$(id -un)" = team ]
key="$HOME/.ssh/team_internal"
[ -f "$key" ]

if [ ! -f hadoop-3.4.2.tar.gz ]; then
  wget -O hadoop-3.4.2.tar.gz \
    https://archive.apache.org/dist/hadoop/common/hadoop-3.4.2/hadoop-3.4.2.tar.gz
fi

bash install.sh

for host in team-19-nn team-19-00 team-19-01; do
  ssh -i "$key" -o BatchMode=yes "team@$host" \
    'mkdir -p "$HOME/hw1-hdfs"'

  scp -i "$key" -o BatchMode=yes \
    install.sh hadoop-3.4.2.tar.gz \
    "team@$host:hw1-hdfs/"

  ssh -i "$key" -o BatchMode=yes "team@$host" \
    'bash "$HOME/hw1-hdfs/install.sh"'
done

ssh -i "$key" -o BatchMode=yes team@team-19-nn 'bash -s' <<'REMOTE'
set -euo pipefail
dir="$HOME/hdfs-hw1/name"
[ -d "$dir" ]

if [ ! -f "$dir/current/VERSION" ]; then
  [ -z "$(ls -A "$dir")" ]
  "$HOME/hadoop-hw1/bin/hdfs" namenode -format -nonInteractive
fi
REMOTE

ssh -i "$key" -o BatchMode=yes team@team-19-nn \
  '"$HOME/hadoop-hw1/bin/hdfs" --daemon start namenode'

ssh -i "$key" -o BatchMode=yes team@team-19-00 \
  '"$HOME/hadoop-hw1/bin/hdfs" --daemon start datanode'

ssh -i "$key" -o BatchMode=yes team@team-19-01 \
  '"$HOME/hadoop-hw1/bin/hdfs" --daemon start datanode'

"$HOME/hadoop-hw1/bin/hdfs" --daemon start datanode
"$HOME/hadoop-hw1/bin/hdfs" --daemon start secondarynamenode
