#!/bin/bash

kubectl config use-context cluster0

kubectl karmada init --crds /root/addon/crds.tar.gz

REGISTER_CMD=$(kubectl karmada token create --print-register-command --kubeconfig=/etc/karmada/karmada-apiserver.config)

for i in $(cat node_list)
do
    ssh root@$i eval "$REGISTER_CMD"
done