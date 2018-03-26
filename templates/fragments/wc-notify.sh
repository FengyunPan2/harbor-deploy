#!/bin/sh

. /etc/sysconfig/heat-params

WC_NOTIFY_BIN=/usr/local/bin/wc-notify
WC_NOTIFY_SERVICE=/etc/systemd/system/wc-notify.service

cat > $WC_NOTIFY_BIN <<'EOF'
#!/bin/bash -v

. /etc/sysconfig/heat-params

server_ip=$REGISTRY_EXTERNAL_SERVER_IP
if [ "${server_ip}" == "" ]; then
    server_ip=$REGISTRY_SERVER_IP
fi

attempts=60
while [ ${attempts} -gt 0 ]; do
    status_code=$(curl -o /dev/null -s -w %{http_code} http://${server_ip})
    if [ "${status_code}"  == "200" ]; then
        echo "habor work well"
        break
    fi
    echo "waiting for harbor(http://${server_ip}) work: ${status_code}"
    sleep 30

    let attempts--
done

if [ ${attempts} -eq 0 ]; then
    echo "habor not work well"
    WAIT_CURL --data-binary '{"status": "Failed"}'
    exit
fi

WAIT_CURL --data-binary '{"status": "SUCCESS"}'

EOF

sed -i "s|WAIT_CURL|${WAIT_CURL}|g" ${WC_NOTIFY_BIN}

cat > $WC_NOTIFY_SERVICE <<EOF
[Unit]
Description=Notify Heat
After=docker.service etcd.service
Requires=docker.service etcd.service
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=$WC_NOTIFY_BIN
[Install]
WantedBy=multi-user.target
EOF

chown root:root $WC_NOTIFY_BIN
chmod 0755 $WC_NOTIFY_BIN

chown root:root $WC_NOTIFY_SERVICE
chmod 0644 $WC_NOTIFY_SERVICE

systemctl enable wc-notify
systemctl start --no-block wc-notify
