#!/bin/sh

. /etc/sysconfig/heat-params

HARBOR_BIN=/usr/local/bin/harbor
HARBOR_SERVICE=/etc/systemd/system/harbor.service

cat > $HARBOR_BIN <<'EOF'
#!/bin/bash -v

su -

. /etc/sysconfig/heat-params

echo "nameserver 8.8.8.8" >> /etc/resolv.conf
echo "nameserver 114.114.114.114" >> /etc/resolv.conf

firewall-cmd --zone=public --add-port=2375/tcp --permanent
firewall-cmd --zone=public --add-port=2379/tcp --permanent
firewall-cmd --reload

echo "configure and enable harbor registry server"

harbor_install_dir="/opt/harbor/"
harbor_config_file=${harbor_install_dir}/harbor.cfg
harbor_install_file=${harbor_install_dir}/install.sh

server_ip=$REGISTRY_EXTERNAL_SERVER_IP
if [ "${server_ip}" == "" ]; then
    server_ip=$REGISTRY_SERVER_IP
fi

echo "configure harbor...."
sed -i '/^hostname = / s/=.*/='" $server_ip"'/
        /^harbor_admin_password = / s/=.*/='" $REGISTRY_ADMIN_PASSWORD"'/
        ' ${harbor_config_file}

docker_status=$(systemctl is-active docker)
until [ ${docker_status} == "active" ]; do
    echo "wait docker work"
    sleep 5
    docker_status=$(systemctl is-active docker)
done

cd ${harbor_install_dir}

docker-compose down -v
dead_containers=$(docker ps | grep -v 'CONTAINER' | wc -l)
until [ $dead_containers -le 0 ]; do
    ps -ef |grep "docker-containerd-shim" |grep -v grep |awk '{print $2}'|xargs kill -9
    docker-compose down
    echo "kill dead container"
    dead_containers=$(docker ps | grep -v 'CONTAINER' | wc -l)
done
rm -rf /mnt/harbor/data/*
rm -rf /mnt/harbor/log/*

sh ${harbor_install_file}

EOF


cat > $HARBOR_SERVICE <<EOF
[Unit]
Description=harbor
After=docker.service
Requires=docker.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$HARBOR_BIN
[Install]
WantedBy=multi-user.target
EOF


chown root:root $HARBOR_BIN
chmod 0755 $HARBOR_BIN

chown root:root $HARBOR_SERVICE
chmod 0644 $HARBOR_SERVICE

systemctl enable harbor
systemctl start --no-block harbor
