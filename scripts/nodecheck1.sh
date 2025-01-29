#!/bin/bash

IP_FILE="/home/sgbi_admin/workarea/scripts/ip.txt"

if [ ! -f "$IP_FILE" ]; then
    echo "IP file $IP_FILE not found"
    exit 1
fi


call_raf_api () {
  local status=$1
  local IP=$2
  cmd="curl  -s -w "%{http_code}"   -X 'POST'  'http://rafqa.us-east-1.elasticbeanstalk.com/api/v1/node/$IP/update-status?status=$status'"
  eval $cmd
}

raf_api () {
   local res=$(call_raf_api $1 $2)
   if [ $res -eq 200 ]; then
           echo "$IP Response $res Success"
   else
           echo "$IP Response $res Failed"
   fi
}


while IFS= read -r IP; do
    response=$(curl --silent --output /dev/null --head --fail "$IP/api/v1/status")
    if [ $? -eq 0 ]; then
        status_response=$(curl --silent --request GET -L "$IP/api/v1/status")
        #status=$(echo "$status_response" | jq '{status: .status}')
        status=$(echo "$status_response" | jq '.status')
        status=$(echo $status | sed "s/\"//g")
        raf_api $status $IP
    else
        status='"failed"'
        raf_api $status $IP
    fi

done < "$IP_FILE"

construct_json_response() {
    local status=$1
    printf '{
  "status": "%s"
}\n' "$status"
}
