#!/bin/bash

IP_FILE="/home/sgbi_admin/workarea/scripts/ip.txt"
#OUTPUT_FILE="/home/sgbi_admin/workarea/scripts/output.txt"

if [ ! -f "$IP_FILE" ]; then
    echo "IP file $IP_FILE not found"
    exit 1
fi

#call_raf_api () {
#  local status=$1
#  local IP=$2
#  local health_status=$3
#  cmd="curl  -s -w "%{http_code}"   -X 'POST'  'http://rafqa.us-east-1.elasticbeanstalk.com/api/v1/node/$IP/update-status?status=$status&alertmsg=$health_status'"
#  eval $cmd
#
#}


# Function to call the health check API
call_health_check () {
    local IP=$1
    local response
    response=$(timeout 20 curl --silent --location --request POST "http://$IP/api/v1/management/health_chk/")
    if [ $? -eq 124 ]; then
        echo "Health check API call timed out"
        return 1
    fi
    echo "$response"
}

#raf_api () {
#   local res=$(call_raf_api $1 $2)
#   if [ $res -eq 200 ]; then
#           echo "$IP Response $res Success"
#   else
#           echo "$IP Response $res Failed"
#   fi
#}

# Function to map health status codes to statuses
map_health_status () {
    local code=$1
    case $code in
        "000")
            echo "No alerts"
            ;;
        "800")
            echo "Robot Error"
            ;;
        "080")
            echo "MTZ Error"
            ;;
        "008")
            echo "Camera Error"
            ;;
        "880")
            echo "Robot and MTZ Error"
            ;;
        "088")
            echo "MTZ and Camera Error"
            ;;
        "808")
            echo "Robot and Camera Error"
            ;;
        "888")
            echo "Node Error"
            ;;
        *)
            echo "Unknown response code"
            ;;
    esac
}

while IFS= read -r IP; do
    response=$(curl --silent --output /dev/null --head --fail "$IP/api/v1/status")
    if [ $? -eq 0 ]; then
        status_response=$(curl --silent --request GET -L "$IP/api/v1/status")
        status=$(echo "$status_response" | jq '.status')
        status=$(echo $status | sed "s/\"//g")
#        raf_api $status $IP
    else
        status="failed"
#        raf_api $status $IP
    fi

    # Integrated health check function - Output Response
    health_response=$(call_health_check "$IP")
    if [ $? -eq 1 ]; then
        health_status="Health check API call timed out"
    else
        health_code=$(echo "$health_response" | jq -r '.Response.health_chk.response_string' 2>/dev/null || echo "Unknown response code")
        if [ -n "$health_code" ]; then
            health_status=$(map_health_status "$health_code")
        else
            health_status="Unknown response code"
        fi
    fi
    echo "$IP, $status, $health_status"
#    echo "$IP, $status, $health_status" >> "$OUTPUT_FILE"


done < "$IP_FILE"

construct_json_response() {
    local status=$1
    printf '{
  "status": "%s"
}\n' "$status"
}
