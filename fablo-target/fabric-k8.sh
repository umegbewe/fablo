#!/usr/bin/env bash

set -e

FABLO_NETWORK_ROOT="$(cd "$(dirname "$0")" && pwd)"

# location of generated configurations
CONFIG_DIR="$FABLO_NETWORK_ROOT/fabric-config/connection-profiles/fabric-k8"


source "$FABLO_NETWORK_ROOT/fabric-k8/scripts/base-help.sh"
source "$FABLO_NETWORK_ROOT/fabric-k8/scripts/base-functions.sh"
source "$FABLO_NETWORK_ROOT/fabric-k8/scripts/chaincode-ops.sh"
# source "$FABLO_NETWORK_ROOT/fabric-docker/channel-query-scripts.sh"
# source "$FABLO_NETWORK_ROOT/fabric-docker/snapshot-scripts.sh"
# source "$FABLO_NETWORK_ROOT/fabric-docker/commands-generated.sh"
source "$FABLO_NETWORK_ROOT/fabric-k8/.env"

networkUp() {
  printHeadline "Checking dependencies..." "U1F984"
  checkDependencies
  printHeadline "Starting Network..." "U1F984"
  hlfOperator && \
  certsGenerate && \
  deployPeer && \
  deployOrderer && \
  adminConfig && \
  installChannels &&\
  joinChannels && \
  printHeadline "Done! Enjoy your fresh network" "U1F984"
}

networkDown() {
  printHeadline "Destroying network" "U1F913"
  destroyNetwork
}

chaincode(){
  installChaincodes
}




if [ "$1" = "up" ]; then
  networkUp
elif [ "$1" = "down" ]; then
  networkDown
elif [ "$1" = "reset" ]; then
  networkDown
  sleep 60
  networkUp
elif [ "$1" = "start" ]; then
  startNetwork
elif [ "$1" = "stop" ]; then
  stopNetwork
elif [ "$1" = "chaincodes" ]; then
  chaincode
elif [ "$1" = "chaincode" ] && [ "$2" = "install" ]; then
  installChaincode "$3" "$4"
elif [ "$1" = "chaincode" ] && [ "$2" = "upgrade" ]; then
  upgradeChaincode "$3" "$4"
elif [ "$1" = "chaincode" ] && [ "$2" = "dev" ]; then
  runDevModeChaincode "$3" "$4"
elif [ "$1" = "channel" ]; then
  channelQuery "${@:2}"
elif [ "$1" = "snapshot" ]; then
  createSnapshot "$2"
elif [ "$1" = "clone-to" ]; then
  cloneSnapshot "$2" "${3:-""}"
elif [ "$1" = "help" ]; then
  printHelp
elif [ "$1" = "--help" ]; then
  printHelp
else
  echo "No command specified"
  echo "Basic commands are: up, down, start, stop, reset"
  echo "To list channel query helper commands type: 'fablo channel --help'"
  echo "Also check: 'chaincode install'"
  echo "Use 'help' or '--help' for more information"
fi
