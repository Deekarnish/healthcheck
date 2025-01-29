#!/bin/bash

IP_FILE="/home/sgbi_admin/workarea/scripts/ip.txt"
OUTPUT_FILE="/home/sgbi_admin/workarea/scripts/output.txt"
LAMBDA_FUNCTION_NAME="lambdases"  # Replace with your Lambda function name

# Function to invoke Lambda using AWS CLI
invoke_lambda() {
    local to_email=$1
    local subject=$2
    local message=$3

    # Create the payload for Lambda
    payload=$(cat <<EOF
{
    "to_email": "$to_email",
    "subject": "$subject",
    "message": "$message"
}
EOF
)

    # Invoke Lambda function
    response=$(aws lambda invoke \
        --function-name "$LAMBDA_FUNCTION_NAME" \
        --payload "$payload" \
        /dev/stdout | jq '.')

    # Check response for errors
    if echo "$response" | grep -q '"statusCode": 200'; then
        echo "Lambda invocation successful: $response"
    else
        echo "Lambda invocation failed: $response"
    fi
}

call_raf_api () {
  local status=$1
  local IP=$2
  local health_status=$3
  cmd="curl -s -w \"%{http_code}\" -X 'POST' 'http://rafqa.us-east-1.elasticbeanstalk.com/api/v1/node/$IP/update-status?status=$status&alertMessage=$health_status'"
  response=$(eval $cmd)
  echo "$response"
}

call_health_check () {
    local IP=$1
    local response
    response=$(timeout 20 curl --silent --location --request POST "http://$IP/api/v1/management/health_chk/")
    if [ $? -eq 124 ]; then
        echo "call-timed-out"
        return 1
    fi
    echo "$response"
}

raf_api () {
   local res=$(call_raf_api $1 $2 $3)
   if [ "$res" -eq 200 ]; then
           echo "$2 Response $res Success"
   else
           echo "$2 Response $res Failed"
   fi
}

map_health_status () {
    local code=$1
    case $code in
        "000") echo "No%20Alerts" ;;
        "800") echo "Robot%20Error" ;;
        "080") echo "MTZ%20Error" ;;
        "008") echo "Camera%20Error" ;;
        "880") echo "Robot%20MTZ%20Error" ;;
        "088") echo "MTZ%20Camera%20Error" ;;
        "808") echo "Robot%20Camera%20Error" ;;
        "888") echo "Node%20Error" ;;
        *) echo "Unknown%20response%20code" ;;
    esac
}

while IFS= read -r IP; do
    response=$(curl --silent --output /dev/null --head --fail "http://$IP/api/v1/status")
    if [ $? -eq 0 ]; then
        status_response=$(curl --silent --request GET -L "http://$IP/api/v1/status")
        status=$(echo "$status_response" | jq '.status')
        status=$(echo $status | sed "s/\"//g")
    else
        status="failed"
    fi

    # Integrated health check function - Output Response
    health_response=$(call_health_check "$IP")
    if [ $? -eq 1 ]; then
        health_status="call%20timed%20out"
    else
        health_code=$(echo "$health_response" | jq -r '.Response.health_chk.response_string' 2>/dev/null || echo "Unknown%20response%20code")
        if [ -n "$health_code" ]; then
            health_status=$(map_health_status "$health_code")
        else
            health_status="Unknown%20response%20code"
        fi
    fi

    raf_api "$status" "$IP" "$health_status"
    echo "$IP, $status, $health_status"
    echo "$IP, $status, $health_status" >> "$OUTPUT_FILE"

    # Skip Lambda invocation only if health status is 'No Alerts'
    if [[ "$health_status" == "No%20Alerts" ]]; then
        echo "Skipping Lambda invocation for IP: $IP (No Alerts)"
    else
        # Invoke Lambda for both successful and failed statuses
        invoke_lambda "deekarnish@gmail.com" "Node Health Check Alert" "Node $IP has status: $status with health: $health_status"
    fi

done < "$IP_FILE"

construct_json_response() {
    local status=$1
    printf '{
  "status": "%s"
}\n' "$status"
}
