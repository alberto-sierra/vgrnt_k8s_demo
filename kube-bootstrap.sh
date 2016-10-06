#!/bin/bash

HOSTNAME=$1

# Kubernetes single node bootstrap
yum -y install kubernetes
yum -y install etcd iptables

# Disable other firewall managers
systemctl disable iptables-services firewalld
systemctl stop iptables-services firewalld

# Configure kubernetes

cat >> /etc/kubernetes/config << EOF
# logging to stderr means we get it in the systemd journal
KUBE_LOGTOSTDERR="--logtostderr=true"

# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=0"

# Should this cluster be allowed to run privileged docker containers
KUBE_ALLOW_PRIV="--allow-privileged=false"

# How the controller-manager, scheduler, and proxy find the apiserver
KUBE_MASTER="--master=http://${HOSTNAME}:8080"
EOF

cat >> /etc/kubernetes/apiserver << EOF
# The address on the local server to listen to.
KUBE_API_ADDRESS="--address=0.0.0.0"

# Comma separated list of nodes in the etcd cluster
KUBE_ETCD_SERVERS="--etcd-servers=http://127.0.0.1:2379"

# Address range to use for services
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"

# default admission control policies
KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota"

# Add your own!
KUBE_API_ARGS="--service_account_key_file=/etc/kubernetes/serviceaccount.key"
EOF

cat >> /etc/etcd/etcd.conf << EOF
# [member]
ETCD_NAME=default
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
#
#[cluster]
ETCD_ADVERTISE_CLIENT_URLS="http://localhost:2379"
EOF

cat >> /etc/kubernetes/controller-manager << EOF
KUBE_CONTROLLER_MANAGER_ARGS="--service_account_private_key_file=/etc/kubernetes/serviceaccount.key"
EOF

echo ${HOSTNAME} >> /etc/hosts
mkdir /var/run/kubernetes
chown kube:kube /var/run/kubernetes
chmod 750 /var/run/kubernetes
openssl genrsa -out /etc/kubernetes/serviceaccount.key 2048

for SERVICES in etcd kube-apiserver kube-controller-manager kube-scheduler; do
  systemctl restart $SERVICES
  systemctl enable $SERVICES
  systemctl status $SERVICES
done

cat >> /etc/kubernetes/master.json << EOF
{
    "apiVersion": "v1",
    "kind": "Node",
    "metadata": {
        "name": "${HOSTNAME}",
        "labels":{ "name": "k8master"}
    },
    "spec": {
        "externalID": "k8master"
    }
}
EOF

kubectl create -f /etc/kubernetes/master.json

cat >> /etc/kubernetes/kubelet << EOF
# kubernetes kubelet (minion) config

# The address for the info server to serve on (set to 0.0.0.0 or "" for all interfaces)
KUBELET_ADDRESS="--address=0.0.0.0"

# The port for the info server to serve on
# KUBELET_PORT="--port=10250"

# You may leave this blank to use the actual hostname
KUBELET_HOSTNAME="--hostname-override=${HOSTNAME}"

# location of the api-server
KUBELET_API_SERVER="--api-servers=http://${HOSTNAME}:8080"

# pod infrastructure container
KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest"

# Add your own!
KUBELET_ARGS=""
EOF

for SERVICES in kube-proxy kubelet docker; do 
    systemctl restart $SERVICES
    systemctl enable $SERVICES
    systemctl status $SERVICES 
done
