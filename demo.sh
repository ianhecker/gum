#!/bin/bash

set -e

URL="http://localhost:8080"

gum style --foreground "#F0F" -- "What's your name?"
SIGNER=$(gum input --prompt "* " --placeholder "My name is...")

gum style --foreground "#F0F" -- "Write your data below (CTRL+D to finish)"
RAW_DATA=$(gum write --placeholder "Write here...")
DATA=$(echo $RAW_DATA | sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g')

sign() {
	http --quiet POST $URL/receipt Host:bky.sh signer_id="$SIGNER" data="$DATA"
}

processingStatus() {
	http GET $URL/processingStatus Host:bky.sh signer_id=="$SIGNER" data=="$DATA"
}

getReceipts() {
	http GET $URL/receipt Host:bky.sh signer_id=="$SIGNER" data=="$DATA"
}

getCertificate() {
	echo "$@" | http POST $URL/certificate Host:bky.sh
}

if ! sign
then
    printf "Oops, Encountered an error\n"
    exit 1
fi

printf "Success! Signed your data:'$DATA'\n"

STATUS=$(processingStatus)
while [ ! -z "${STATUS}" ]
do
	sleep 1
	echo "Checking status..."
	STATUS=$(processingStatus)
done

printf "Fetching your receipt(s)\n"

RECEIPTS=$(getReceipts)
while [ "${RECEIPTS}" = "null" ]
do
	sleep 1
	printf "Fetching receipt(s) again...\n"
	RECEIPTS=$(getReceipts)
done

echo $RECEIPTS | jq

INDEX=0
RECEIPT_COUNT=$(echo $RECEIPTS | jq length)
if [ "${RECEIPT_COUNT}" -gt 1 ]
then
	printf "You have $RECEIPT_COUNT receipts available\n"
	gum style --foreground "#F0F" -- "Select a receipt index"

	INDEX=$(seq 0 $(($RECEIPT_COUNT - 1)) | gum choose --limit 1 --cursor.foreground "#F0F")

	echo "Selected index:$INDEX"
fi

RECEIPT=$(echo "$RECEIPTS" | jq --argjson index $((INDEX)) '.[$index]')

CERTIFICATE=$(getCertificate $RECEIPT)
if [ -z "${CERTIFICATE}" ]
then
	printf "Oops, encountered an error\n"
fi

printf "Your certificate:\n"
echo "$CERTIFICATE" | jq
