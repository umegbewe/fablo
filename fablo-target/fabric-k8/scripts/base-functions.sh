#!/usr/bin/env bash

certsGenerate() {

    printItalics "Deploying Certificate Authority" "U1F984"

    kubectl hlf ca create --storage-class=$STORAGE_CLASS --capacity=2Gi --name=$ORG-ca --enroll-id=$ORG1_CA_ADMIN_NAME --enroll-pw=$ORG1_CA_ADMIN_PASSWORD && sleep 3

    while [[ $(kubectl get pods -l release=$ORG-ca -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do 
        sleep 5 
        inputLog "waiting for CA"
    done

    kubectl hlf ca register --name=$ORG-ca --user=peer --secret=$PEER_SECRET --type=peer --enroll-id $ORG1_CA_ADMIN_NAME --enroll-secret=$ORG1_CA_ADMIN_PASSWORD --mspid $MSP_ORG && \
    inputLog "registered $ORG-ca"
}

deployPeer() {

    printItalics "Deploying Peers" "U1F984"
    sleep 10
    
    kubectl hlf peer create --image=$PEER_IMAGE --version=$PEER_VERSION --storage-class=$STORAGE_CLASS --enroll-id=peer --mspid=$MSP_ORG \
        --enroll-pw=$PEER_SECRET --capacity=5Gi --name=$ORG-peer0 --ca-name=$ORG-ca.$NAMESPACE --k8s-builder=true --external-service-builder=false
    kubectl hlf peer create --image=$PEER_IMAGE --version=$PEER_VERSION --storage-class=$STORAGE_CLASS --enroll-id=peer --mspid=$MSP_ORG \
        --enroll-pw=$PEER_SECRET --capacity=5Gi --name=$ORG-peer1 --ca-name=$ORG-ca.$NAMESPACE --k8s-builder=true --external-service-builder=false
        
    while [[ $(kubectl get pods -l app=hlf-peer --output=jsonpath='{.items[*].status.containerStatuses[0].ready}') != "true true" ]]; do 
        sleep 5
        inputLog "waiting for peer nodes to be ready"
    done
}

deployOrderer() {

    printItalics "Deploying Orderers" "U1F984"
    kubectl hlf ca create --storage-class=$STORAGE_CLASS --capacity=2Gi --name=$ORD-ca --enroll-id=$ORG1_CA_ADMIN_NAME --enroll-pw=$ORG1_CA_ADMIN_PASSWORD

    while [[ $(kubectl get pods -l release=$ORD-ca -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
        sleep 5
        inputLog "waiting for $ORD CA to be ready" $RESETBG
    done

    kubectl hlf ca register --name=$ORD-ca --user=orderer --secret=$ORDERER_SECRET --type=orderer --enroll-id=$ORG1_CA_ADMIN_NAME --enroll-secret=$ORG1_CA_ADMIN_PASSWORD --mspid $MSP_ORD && \
    inputLog "registered $ORD-ca"
    
    
    kubectl hlf ordnode create --image=$ORDERER_IMAGE --version=$ORDERER_VERSION \
    --storage-class=$STORAGE_CLASS --enroll-id=$ORD --mspid=$MSP_ORD \
    --enroll-pw=$ORDERER_SECRET --capacity=2Gi --name=$ORD-node1 --ca-name=$ORD-ca.$NAMESPACE
    
    while [[ $(kubectl get pods -l app=hlf-ordnode -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
        sleep 5
        inputLog "waiting for $ORD Node to be ready"
    done   
}

adminConfig() {
    kubectl hlf inspect --output $CONFIG_DIR/ordservice.yaml -o $MSP_ORD && \
    
    kubectl hlf ca register --name=$ORD-ca --user=$ADMIN_USER --secret=$ADMIN_PASS --type=admin --enroll-id=$ORG1_CA_ADMIN_NAME --enroll-secret=$ORG1_CA_ADMIN_PASSWORD --mspid=$MSP_ORD
    
    kubectl hlf ca enroll --name=$ORD-ca --user=$ADMIN_USER --secret=$ADMIN_PASS --mspid $MSP_ORD --ca-name ca  --output $CONFIG_DIR/admin-ordservice.yaml && \
    
   kubectl hlf utils adduser --userPath=$CONFIG_DIR/admin-ordservice.yaml --config=$CONFIG_DIR/ordservice.yaml --username=$ADMIN_USER --mspid=$MSP_ORD
}

destroyNetwork() {
    kubectl delete fabricorderernodes.hlf.kungfusoftware.es --all-namespaces --all
    kubectl delete fabricpeers.hlf.kungfusoftware.es --all-namespaces --all
    kubectl delete fabriccas.hlf.kungfusoftware.es --all-namespaces --all
    # kubectl delete fabricchaincode.hlf.kungfusoftware.es --all-namespaces --all
}


printHeadline() {
  bold=$'\e[1m'
  end=$'\e[0m'

  TEXT=$1
  EMOJI=$2
  printf "${bold}============ %b %s %b ==============${end}\n" "\\$EMOJI" "$TEXT" "\\$EMOJI"
}

printItalics() {
  italics=$'\e[3m'
  end=$'\e[0m'

  TEXT=$1
  EMOJI=$2
  printf "${italics}==== %b %s %b ====${end}\n" "\\$EMOJI" "$TEXT" "\\$EMOJI"
}

inputLog() {
  end=$'\e[0m'
  darkGray=$'\e[90m'

  echo "${darkGray}   $1 ${end}"
}

inputLogShort() {
  end=$'\e[0m'
  darkGray=$'\e[90m'

  echo "${darkGray}   $1 ${end}"
}

checkDependencies() {
    printItalics "Checking Dependencies" "U1F984"

    if [[  `command -v kubectl` ]]; then 
        printf "\nKubectl installed...\n"
    else
        printf "\nCouldn't detect a Kubectl \n" && exit
    fi

    if [[  `command -v kubectl-hlf` ]]; then 
        printf "\nHLF installed...\n"
    else
        printf "\nCouldn't detect the HLF Plugin \n" && exit
    fi

    if [[  `command -v helm` ]]; then 
        printf "\nHelm installed...\n"
    else
        printf "\nCouldn't detect Helm \n" && exit
    fi
}

# certsRemove() {
#   local CERTS_DIR_PATH=$1
#   rm -rf "$CERTS_DIR_PATH"
# }

# removeContainer() {
#   CONTAINER_NAME=$1
#   docker rm -f "$CONTAINER_NAME"
# }


# certsGenerate
# peer

# orderer