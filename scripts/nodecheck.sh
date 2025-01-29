#!/bin/bash

IP_FILE="/home/sgbi_admin/workarea/scripts/ip.txt"

if [ ! -f "$IP_FILE" ]; then
    echo "IP file $IP_FILE not found"
    exit 1
fi

construct_json_response() {
    local status=$1
    printf '{"status": "%s"}\n' "$status"
}

while IFS= read -r IP; do
    response=$(curl --silent --output /dev/null --head --fail "$IP/api/v1/status")
    if [ $? -eq 0 ]; then
        status_response=$(curl --silent --request GET -L "$IP/api/v1/status")
        #status=$(echo "$status_response" | jq '{status: .status}')
        echo "Node $IP is up"
        echo "$status_response"
        #echo "$status"
    else
        echo "Node $IP is down"
        construct_json_response "failed"
    fi
done < "$IP_FILE"

