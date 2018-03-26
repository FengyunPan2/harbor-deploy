#!/bin/sh

set -x

. /etc/sysconfig/heat-params

server_ip=${REGISTRY_EXTERNAL_SERVER_IP}
if [ "${server_ip}" == "" ]; then
    server_ip=${REGISTRY_SERVER_IP}
fi

sed -i "s/^OPTIONS=.*/OPTIONS='--selinux-enabled --log-driver=journald --signature-verification=false -H unix:\/\/\/var\/run\/docker.sock -H tcp:\/\/0.0.0.0:2375 --insecure-registry=${server_ip}'/g" /etc/sysconfig/docker

# make sure we pick up any modified unit files
systemctl daemon-reload

echo "starting services"
for service in docker; do
    echo "activating service $service"
    systemctl enable $service
    systemctl --no-block restart $service
done

