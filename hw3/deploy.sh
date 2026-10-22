#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -un)" = team ]
[ "$(hostname -s)" = team-19-en ]
. ./env.sh
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
[ -x "$HADOOP_HOME/bin/hdfs" ]
[ -f "$HADOOP_CONF_DIR/yarn-site.xml" ]
sudo apt-get update
sudo apt-get install -y curl python3 postgresql libpostgresql-jdbc-java libcommons-collections3-java
sudo systemctl enable --now postgresql
mkdir -p downloads

if [ ! -x "$JAVA_HOME/bin/java" ]; then
  case "$(uname -m)" in x86_64) arch=x64 ;; aarch64) arch=aarch64 ;; *) exit 1 ;; esac
  curl -fL --retry 3 "https://api.adoptium.net/v3/assets/latest/8/hotspot?architecture=$arch&image_type=jdk&os=linux&vendor=eclipse" -o downloads/java.json
  python3 - <<'PY' > downloads/java-download.txt
import json
asset = json.load(open('downloads/java.json'))[0]['binary']['package']
print(asset['link'])
print(asset['checksum'])
PY
  read -r url < downloads/java-download.txt
  curl -fL --retry 3 "$url" -o downloads/java.tar.gz
  printf '%s  downloads/java.tar.gz\n' "$(tail -n 1 downloads/java-download.txt)" | sha256sum -c -
  mkdir -p "$JAVA_HOME"
  tar -xzf downloads/java.tar.gz -C "$JAVA_HOME" --strip-components=1
fi
hdfs dfs -test -d /

if [ ! -x "$HIVE_HOME/bin/hive" ]; then
  archive=apache-hive-4.0.0-alpha-2-bin.tar.gz
  base=https://archive.apache.org/dist/hive/hive-4.0.0-alpha-2
  curl -fL --retry 3 "$base/$archive" -o "downloads/$archive"
  curl -fL --retry 3 "$base/$archive.sha256" -o "downloads/$archive.sha256"
  (cd downloads && sha256sum -c "$archive.sha256")
  mkdir -p "$HIVE_HOME"
  tar -xzf "downloads/$archive" -C "$HIVE_HOME" --strip-components=1
fi
mkdir -p "$HIVE_HOME/hadoop-conf"
cp -R "$HADOOP_HOME/etc/hadoop/." "$HIVE_HOME/hadoop-conf/"
python3 - "$HIVE_HOME/hadoop-conf/core-site.xml" <<'PYXML'
import sys
import xml.etree.ElementTree as ET
path = sys.argv[1]
tree = ET.parse(path)
root = tree.getroot()
for prop in list(root.findall('property')):
    if prop.findtext('name') == 'hadoop.proxyuser.team.hosts':
        root.remove(prop)
prop = ET.SubElement(root, 'property')
ET.SubElement(prop, 'name').text = 'hadoop.proxyuser.team.hosts'
ET.SubElement(prop, 'value').text = '127.0.0.1'
tree.write(path, encoding='UTF-8', xml_declaration=True)
PYXML
printf '\nexport JAVA_HOME="%s"\n' "$JAVA_HOME" >> "$HIVE_HOME/hadoop-conf/hadoop-env.sh"
. ./env.sh
cp /usr/share/java/postgresql.jar "$HIVE_HOME/lib/"

umask 077
password_file="$HOME/.hw3-postgres-password"
if [ ! -s "$password_file" ]; then
  python3 -c 'import secrets; print(secrets.token_hex(24))' > "$password_file"
fi
chmod 600 "$password_file"
password=$(cat "$password_file")
[[ "$password" =~ ^[0-9a-f]{48}$ ]]
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='hive_hw3'" | grep -qx 1; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 -c "CREATE ROLE hive_hw3 LOGIN PASSWORD '$password'"
fi
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='metastore_hw3'" | grep -qx 1; then
  sudo -u postgres createdb -O hive_hw3 metastore_hw3
fi
cat > "$HIVE_CONF_DIR/hive-site.xml" <<XML
<configuration>
  <property><name>javax.jdo.option.ConnectionURL</name><value>jdbc:postgresql://127.0.0.1:5432/metastore_hw3</value></property>
  <property><name>javax.jdo.option.ConnectionDriverName</name><value>org.postgresql.Driver</value></property>
  <property><name>javax.jdo.option.ConnectionUserName</name><value>hive_hw3</value></property>
  <property><name>javax.jdo.option.ConnectionPassword</name><value>$password</value></property>
  <property><name>hive.metastore.uris</name><value>thrift://127.0.0.1:9083</value></property>
  <property><name>hive.metastore.schema.verification</name><value>true</value></property>
  <property><name>datanucleus.schema.autoCreateAll</name><value>false</value></property>
  <property><name>hive.metastore.warehouse.dir</name><value>/user/team/hw3/warehouse</value></property>
  <property><name>hive.server2.thrift.bind.host</name><value>127.0.0.1</value></property>
  <property><name>hive.server2.thrift.port</name><value>10000</value></property>
  <property><name>hive.server2.webui.host</name><value>127.0.0.1</value></property>
  <property><name>hive.server2.authentication</name><value>NONE</value></property>
  <property><name>hive.server2.enable.doAs</name><value>false</value></property>
  <property><name>hive.execution.engine</name><value>mr</value></property>
  <property><name>hive.aux.jars.path</name><value>file:///usr/share/java/commons-collections3.jar</value></property>
  <property><name>hive.exec.scratchdir</name><value>/user/team/hw3/scratch</value></property>
</configuration>
XML
chmod 600 "$HIVE_CONF_DIR/hive-site.xml"
hdfs dfs -mkdir -p /user/team/hw3/warehouse /user/team/hw3/scratch
hdfs dfs -chmod 700 /user/team/hw3/warehouse
hdfs dfs -chmod 733 /user/team/hw3/scratch

tables=$(sudo -u postgres psql -d metastore_hw3 -tAc "SELECT count(*) FROM information_schema.tables WHERE table_schema='public'")
if [ "$tables" = 0 ]; then
  "$HIVE_HOME/bin/schematool" -dbType postgres -initSchema
fi
"$HIVE_HOME/bin/schematool" -dbType postgres -info

cp env.sh "$HIVE_HOME/conf/hw3-env.sh"
for service in metastore hiveserver2; do
  extra=
  after='network.target postgresql.service'
  if [ "$service" = metastore ]; then
    extra='-hiveconf hive.metastore.thrift.bind.host=127.0.0.1'
  else
    after="$after hive-hw3-metastore.service"
  fi
  sudo tee "/etc/systemd/system/hive-hw3-$service.service" > /dev/null <<UNIT
[Unit]
Description=HW3 Hive $service
After=$after
[Service]
User=team
WorkingDirectory=$HIVE_HOME
Environment=HOME=$HOME
ExecStart=/bin/bash -c '. "$HIVE_HOME/conf/hw3-env.sh"; exec "$HIVE_HOME/bin/hive" --service $service $extra'
Restart=on-failure
RestartSec=10
TimeoutStopSec=60
UMask=0077
[Install]
WantedBy=multi-user.target
UNIT
done
sudo systemctl daemon-reload
sudo systemctl enable hive-hw3-metastore hive-hw3-hiveserver2
sudo systemctl restart hive-hw3-metastore hive-hw3-hiveserver2
for attempt in {1..60}; do
  if timeout --kill-after=5s 15 "$HIVE_HOME/bin/beeline" \
    -u 'jdbc:hive2://127.0.0.1:10000/default' -n team -e 'SHOW DATABASES;' \
    > /tmp/hw3-readiness.log 2>&1; then
    exit 0
  fi
  sleep 5
done
cat /tmp/hw3-readiness.log >&2
sudo journalctl -u hive-hw3-metastore -u hive-hw3-hiveserver2 -n 100 --no-pager >&2
exit 1
