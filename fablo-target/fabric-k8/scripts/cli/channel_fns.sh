#!/usr/bin/env bash

set -eu


installChannels() {
    sleep 10

    kubectl hlf channel generate --output=$CHANNEL.block --name=$CHANNEL --organizations $MSP_ORG --ordererOrganizations $MSP_ORD && \
    
    kubectl hlf ca enroll --name=$ORD-ca --namespace=$NAMESPACE --user=admin --secret=$SECRET --mspid $MSP_ORD --ca-name tlsca --output admin-tls-ordservice.yaml && \

    sleep 10
    
    kubectl hlf ordnode join --block=$CHANNEL.block --name=$ORD-node1 --namespace=$NAMESPACE --identity=admin-tls-ordservice.yaml
}