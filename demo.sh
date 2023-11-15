#!/bin/sh

ENDPOINT="localhost:8080"
SLEEP_INTERVAL=0.5

USER=$(gum input \
	--prompt "Hello! My name is Zipperchain. What's yours? " \
	--prompt.foreground "#FF69B4" \
	--placeholder "My name is...")

echo "Welcome!\nIt's nice to meet you, $USER! :smile:" \
	| gum format -t emoji && sleep $SLEEP_INTERVAL

echo "Let's sign data onto a blockchain :package:" \
	| gum format -t emoji && sleep $SLEEP_INTERVAL

echo "Please write your data below (CTRL+D to finish)"
RAW_DATA=$(gum write --placeholder "Write here...")

# DATA=$(echo $RAW_DATA | sed -E ':a;N;$!ba;s/\r{0,1}\n/\\n/g')
DATA="my data here"

echo "Let's sign your data, $USER!" && sleep $SLEEP_INTERVAL

if http \
	--quiet \
	POST http://$ENDPOINT/receipt Host:bky.sh \
	signer_id="$USER" data="$DATA"
then
    echo 'Success! Signed your data!'
else
    echo "Oops! Encountered an error"
    exit 1
fi

echo "Let's fetch your receipt(s), $USER!"
sleep $SLEEP_INTERVAL

RECEIPTS=$(http GET http://$ENDPOINT/receipt Host:bky.sh signer_id=="$USER" data=="$DATA")

while [ "${RECEIPTS}" = "null" ] && gum confirm "Retry fetching receipt(s)?"
do
	echo "Fetching receipt(s) again..."
	RECEIPTS=$(http GET http://$ENDPOINT/receipt Host:bky.sh signer_id=="$USER" data=="$DATA")
done

if [ "${RECEIPTS}" = "null" ]
then
	echo "Oops, looks like we weren't able to fetch your receipts"
	exit 1
fi

echo "Here are your receipts..."
sleep $SLEEP_INTERVAL
echo "$RECEIPTS" | jq > receipts.json && gum pager < receipts.json

INDEX=0
RECEIPT_COUNT=$(jq length receipts.json)
if [ "${RECEIPT_COUNT}" -gt 1 ]
then
	echo "It looks like you have signed this data more than once, so"
	echo "you have more than one receipt available!"

	echo "Choose a receipt to verify with (by index)"
	INDEX=$(seq 0 $(($RECEIPT_COUNT - 1)) | gum choose --limit 1)
fi

RECEIPT=$(jq --argjson index $((INDEX)) '.[$index]' receipts.json)

CERTIFICATE=$(echo $RECEIPT | http POST "http://localhost:8080/certificate" Host:bky.sh)

echo "Here is your certificate!"
sleep $SLEEP_INTERVAL
echo $CERTIFICATE | jq
