#!/usr/bin/env bash

set -e

TEST_TMP="$(rm -rf "$0.tmpdir" && mkdir -p "$0.tmpdir" && (cd "$0.tmpdir" && pwd))"
TEST_LOGS="$(mkdir -p "$0.logs" && (cd "$0.logs" && pwd))"
FABLO_HOME="$TEST_TMP/../../.."

networkUp() {
  # "$FABLO_HOME/fablo-build.sh"
  ("$FABLO_HOME/fablo.sh" init kubernetes node)
  ("$FABLO_HOME/fablo.sh" up $FABLO_HOME/fablo-config.json)
  ("$TEST_TMP/fablo-target/fabric-k8s.sh" up)
}

dumpLogs() {
  echo "Saving logs of $1 to $TEST_LOGS/$1.log"
  mkdir -p "$TEST_LOGS"
  docker logs "$1" >"$TEST_LOGS/$1.log" 2>&1
}

networkDown() {
  rm -rf "$TEST_LOGS"
  (cd "$TEST_TMP" && "$FABLO_HOME/fablo-target/fabric-k8.sh" down)
}

# TODO The rest of this script to be rewritten

chainCode() {
    (cd "$TEST_TMP" && "$FABLO_HOME/fablo-target/fabric-k8.sh" chaincodes)
}

waitForContainer() {
  sh "$TEST_TMP/../wait-for-container.sh" "$1" "$2"
}

waitForChaincode() {
  sh "$TEST_TMP/../wait-for-chaincode.sh" "$1" "$2" "$3" "$4" "$5"
}

expectInvoke() {
  sh "$TEST_TMP/../expect-invoke-cli.sh" "$1" "$2" "$3" "$4" "$5" "$6" "$7"
}


# trap networkDown EXIT
# trap 'networkDown ; echo "Test failed" ; exit 1' ERR SIGINT

# start the network
networkUp

peer0=$(kubectl get pods | grep org1-peer0 | tr -s ' ' | cut -d ':' -f 1 | cut -d ' ' -f 1)
peer1=$(kubectl get pods | grep org1-peer1 | tr -s ' ' | cut -d ':' -f 1 | cut -d ' ' -f 1)
ca=$(kubectl get pods | grep org1-ca | tr -s ' ' | cut -d ':' -f 1 | cut -d ' ' -f 1)
orderer=$(kubectl get pods | grep orderer-node1 | tr -s ' ' | cut -d ':' -f 1 | cut -d ' ' -f 1)

waitForContainer "$orderer" "Starting raft node as part of a new channel channel=my-channel1 node=1"
waitForContainer "$ca" "Listening on https://0.0.0.0:7054"
waitForContainer "$peer0" "Joining gossip network of channel my-channel1 with 1 organizations"
waitForContainer "$peer1" "Joining gossip network of channel my-channel1 with 1 organizations"
waitForContainer "$peer0" "Learning about the configured anchor peers of Org1MSP for channel my-channel1"
waitForContainer "$peer0" "Anchor peer.*with same endpoint, skipping connecting to myself"
waitForContainer "$peer0" "Membership view has changed. peers went online:"
waitForContainer "$peer1" "Learning about the configured anchor peers of Org1MSP for channel my-channel1"
waitForContainer "$peer1" "Membership view has changed. peers went online:"

chainCode

#Test simple chaincode
expectInvoke "admin" "org1-peer1.default" "chaincode1" "my-channel1" \
  "put -a '["name"]' -a Willy Wonka" "{\"success\":\"OK\"}"
expectInvoke "admin" "org1-peer1.default" "chaincode1" "my-channel1" \
  "get -a '["name"]'" '{"success":"Willy"}'

# Removed channel query tests, not needed for k8

# Reset and ensure the state is lost after reset
(cd "$TEST_TMP" && "$FABLO_HOME/fablo-target/fabric-k8.sh" reset)
chainCode
waitForChaincode "admin" "org1-peer0.default" "my-channel1" "chaincode1" "1.0"
waitForChaincode "admin" "org1-peer1.default" "my-channel1" "chaincode1" "1.0"

expectInvoke "admin" "org1-peer1.default" "chaincode1" "my-channel1" \
  "get -a '["name"]" '{"error":"NOT_FOUND"}'

# Put some data again

expectInvoke "admin" "org1-peer1.default" "chaincode1" "my-channel1" \
  "put -a '["name"]' -a James Bond" "{\"success\":\"OK\"}"

networkDown

