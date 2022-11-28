#!/bin/bash

mkdir nft
cd nft/

realtokenname="NFT1"
tokenname=$(echo -n $realtokenname | xxd -b -ps -c 80 | tr -d '\n')
tokenamount="1"
fee="0"
output="0"
ipfs_hash="QmXxoaeZu7hvWaSbcokiwbJNWx2aYYNYdjXoJA2tzikPrS"

cardano-cli address key-gen --verification-key-file payment.vkey --signing-key-file payment.skey

cardano-cli address build --payment-verification-key-file payment.vkey --out-file payment.addr --mainnet


address=$(cat payment.addr)
cardano-cli query utxo --address $address --mainnet

cardano-cli query protocol-parameters --mainnet --out-file protocol.json


mkdir policy

cardano-cli address key-gen \
    --verification-key-file policy/policy.vkey \
    --signing-key-file policy/policy.skey

echo "{" >> policy/policy.script
echo "  \"type\": \"all\"," >> policy/policy.script 
echo "  \"scripts\":" >> policy/policy.script 
echo "  [" >> policy/policy.script 
echo "   {" >> policy/policy.script 
echo "     \"type\": \"before\"," >> policy/policy.script 
echo "     \"slot\": $(expr $(cardano-cli query tip --mainnet | jq .slot?) + 10000)" >> policy/policy.script
echo "   }," >> policy/policy.script 
echo "   {" >> policy/policy.script
echo "     \"type\": \"sig\"," >> policy/policy.script 
echo "     \"keyHash\": \"$(cardano-cli address key-hash --payment-verification-key-file policy/policy.vkey)\"" >> policy/policy.script 
echo "   }" >> policy/policy.script
echo "  ]" >> policy/policy.script 
echo "}" >> policy/policy.script



cardano-cli address key-hash --payment-verification-key-file policy/policy.vkey

slotnumber="78106253"

script="policy/policy.script"

cardano-cli transaction policyid --script-file ./policy/policy.script > policy/policyID


echo "{" >> metadata.json
echo "  \"721\": {" >> metadata.json 
echo "    \"$(cat policy/policyID)\": {" >> metadata.json 
echo "      \"$(echo $realtokenname)\": {" >> metadata.json
echo "        \"description\": \"This is my first NFT thanks to the Cardano foundation\"," >> metadata.json
echo "        \"name\": \"Cardano foundation NFT guide token\"," >> metadata.json
echo "        \"id\": \"1\"," >> metadata.json
echo "        \"image\": \"ipfs://$(echo $ipfs_hash)\"" >> metadata.json
echo "      }" >> metadata.json
echo "    }" >> metadata.json 
echo "  }" >> metadata.json 
echo "}" >> metadata.json


txhash="ccd28d1cedb448a67561cc6828de42c9335a693fea46f13d100d8a478895ca45"
txix="1"
funds="9611927"
policyid=$(cat policy/policyID)
output=1400000

#fees estimation
cardano-cli transaction build \
--mainnet \
--alonzo-era \
--tx-in $txhash#$txix \
--tx-out $address+$output+"$tokenamount $policyid.$tokenname" \
--change-address $address \
--mint="$tokenamount $policyid.$tokenname" \
--minting-script-file $script \
--metadata-json-file metadata.json  \
--invalid-hereafter $slotnumber \
--witness-override 2 \
--out-file matx.raw

#sign transaction
cardano-cli transaction sign  \
--signing-key-file payment.skey  \
--signing-key-file policy/policy.skey  \
--mainnet --tx-body-file matx.raw  \
--out-file matx.signed

# submit the transaction
cardano-cli transaction submit --tx-file matx.signed --mainnet

