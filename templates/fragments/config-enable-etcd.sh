#!/bin/sh

set -x

. /etc/sysconfig/heat-params

echo "starting etcd"
systemctl enable etcd
systemctl --no-block restart etcd
