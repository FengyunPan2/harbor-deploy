#!/bin/sh

function echo_log()
{
    echo -e $1
}

function check_env()
{
    if [ "${SSH_KEY_NAME}" == "" -o \
         "${SERVER_IMAGE}" == "" -o \
         "${SERVER_FLAVOR}" == "" -o \
         "${FIXED_NETWORK}" == "" -o  \
         "${FIXED_SUBNET}" == "" ]; then
        help
	exit -1
    fi

    if [ ! -f  "/root/admin-openrc" ]; then
        echo_log "only exec in controller node of openstack cluster"
        return 1
    fi

    return 0
}

function build_stack()
{
    echo_log "install etcd harbor stack..."
    source /root/admin-openrc

    if [ "${STACK_NAME}" == "" ]; then
        STACK_NAME="etcd-harbor"
    fi

    floatin_ip_arg="-e ./templates/environments/enable_floating_ip.yaml"
    if [ "${EXTERNAL_NETWORK}" == "" ]; then
        floatin_ip_arg="-e ./templates/environments/disable_floating_ip.yaml"
    fi

    volume_arg="-e ./templates/environments/use_volume.yaml"
    if [ "${VOLUME_SIZE}" == "0" ]; then
        volume_arg="-e ./templates/environments/without_volume.yaml"
    fi

    heat stack-create -f ./templates/etcd_harbor.yaml ${floatin_ip_arg}  ${volume_arg} -P volume_size=${VOLUME_SIZE} \
       	-P ssh_key_name=${SSH_KEY_NAME} -P external_network=${EXTERNAL_NETWORK} -P server_image=${SERVER_IMAGE} \
       	-P server_flavor=${SERVER_FLAVOR} -P registry_admin_password=${REGISTRY_ADMIN_PASSWORD} \
       	-P registry_service_port=${REGISTRY_SERVICE_PORT} -P fixed_network=${FIXED_NETWORK} \
       	-P fixed_subnet=${FIXED_SUBNET}  ${STACK_NAME}

    sleep 5
    attempts=60
    while [ ${attempts} -gt 0 ]; do
        stack_status=$(heat stack-list |grep ${STACK_NAME} | awk '{print $6}')
        if [ "${stack_status}"  != "CREATE_IN_PROGRESS" ]; then
            break
        fi
        echo_log "waiting for heat stack create success..."
        sleep 60

        let attempts--
    done

    if [ ${attempts} -eq 0 -o "${stack_status}" != "CREATE_COMPLETE" ]; then
        echo_log "heat stack build failed."
        return
    fi
    echo_log "heat stack create success."
    return

}

############main############
SSH_KEY_NAME=""
EXTERNAL_NETWORK=""
SERVER_IMAGE=""
SERVER_FLAVOR=""
REGISTRY_ADMIN_PASSWORD="passw0rd"
REGISTRY_SERVICE_PORT=2375
FIXED_NETWORK=""
FIXED_SUBNET=""
VOLUME_SIZE=0
STACK_NAME=""

function help()
{
    echo_log "install-etcd-harbor.sh "
    echo_log "    \t\t-n stack_name"
    echo_log "    \t\t-p registry_admin_password"
    echo_log "    \t\t-r registry_service_port"
    echo_log "    \t\t-k keypair_id \t*required*"
    echo_log "    \t\t-e external_network_id"
    echo_log "    \t\t-i image_id \t*required*"
    echo_log "    \t\t-v vm_flavor_id \t*required*"
    echo_log "    \t\t-f fixed_network_id \t*required*"
    echo_log "    \t\t-d fixed_subnet_id \t*required*"
    echo_log "    \t\t-s volume_size"
}

while getopts n:p:r:k:e:i:v:f:d:s:h opt; do
    case $opt in
        n) STACK_NAME=$OPTARG ;;
        p) REGISTRY_ADMIN_PASSWORD=$OPTARG ;;
        r) REGISTRY_SERVICE_PORT=$OPTARG ;;
        k) SSH_KEY_NAME=$OPTARG ;;
        e) EXTERNAL_NETWORK=$OPTARG ;;
        i) SERVER_IMAGE=$OPTARG ;;
        v) SERVER_FLAVOR=$OPTARG ;;
        f) FIXED_NETWORK=$OPTARG ;;
        d) FIXED_SUBNET=$OPTARG ;;
        s) VOLUME_SIZE=$OPTARG ;;
        h) help && exit 0 ;;
        *) echo_log "Invalid Params" && exit -1 ;;
    esac
done


check_env; result_status=$?
if [ "${result_status}" != "0" ]; then
    echo_log "check_env failure."
    exit -1
fi

build_stack; result_status=$?
if [ ${result_status} != 0 ]; then
    echo_log "build_stack failure."
fi

