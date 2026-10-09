#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

[ "$(id -un)" = team ]
[ "$(hostname -s)" = team-19-en ]
[ -f "$HOME/.ssh/team_internal" ]

export HADOOP_HOME="$HOME/hadoop-hw1"
"$HADOOP_HOME/bin/hdfs" dfs -test -d /

bash setup.sh

for host in team-19-nn team-19-00 team-19-01; do
  ssh -i "$HOME/.ssh/team_internal" "team@$host" \
    'mkdir -p "$HOME/hw2-setup/configs"'
  scp -i "$HOME/.ssh/team_internal" configs/*.xml \
    "team@$host:hw2-setup/configs/"
  ssh -i "$HOME/.ssh/team_internal" "team@$host" \
    'bash -s -- "$HOME/hw2-setup/configs"' < setup.sh
done

"$HADOOP_HOME/bin/hdfs" dfs -mkdir -p \
  /user/team/hw2/history/tmp \
  /user/team/hw2/history/done \
  /user/team/hw2/logs

"$HADOOP_HOME/bin/hdfs" dfs -chmod 1777 \
  /user/team/hw2/history/tmp \
  /user/team/hw2/logs

ssh -i "$HOME/.ssh/team_internal" team@team-19-nn <<'SSH'
set -euo pipefail
"$HOME/hadoop-hw1/bin/yarn" --daemon stop resourcemanager
"$HOME/hadoop-hw1/bin/mapred" --daemon stop historyserver
"$HOME/hadoop-hw1/bin/yarn" --daemon start resourcemanager
"$HOME/hadoop-hw1/bin/mapred" --daemon start historyserver
SSH

"$HADOOP_HOME/bin/yarn" --daemon stop nodemanager
"$HADOOP_HOME/bin/yarn" --daemon start nodemanager

for host in team-19-00 team-19-01; do
  ssh -i "$HOME/.ssh/team_internal" "team@$host" <<'SSH'
set -euo pipefail
"$HOME/hadoop-hw1/bin/yarn" --daemon stop nodemanager
"$HOME/hadoop-hw1/bin/yarn" --daemon start nodemanager
SSH
done

sudo apt-get update
sudo apt-get install -y nginx curl
sudo nginx -t

config=/etc/nginx/conf.d/hw2-team19.conf
if sudo test -e "$config"; then
  sudo cp "$config" "$config.backup"
fi

for entry in \
  '8088 team-19-nn:8088' \
  '19888 team-19-nn:19888' \
  '18042 team-19-en:8042' \
  '18043 team-19-00:8042' \
  '18044 team-19-01:8042'; do
  read -r port upstream <<< "$entry"
  cat <<NGINX
server {
    listen 127.0.0.1:$port;
    location / {
        proxy_pass http://$upstream;
        proxy_set_header Host \$http_host;
    }
}
NGINX
done | sudo tee "$config" > /dev/null

if ! sudo nginx -t; then
  if sudo test -e "$config.backup"; then
    sudo cp "$config.backup" "$config"
  else
    sudo mv "$config" "$config.failed"
  fi
  exit 1
fi

sudo systemctl enable --now nginx
sudo systemctl reload nginx

