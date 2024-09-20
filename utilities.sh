#!/bin/bash

# URL of your Flask server
URL="http://192.168.1.113:8001/state"

# Function to get the toggle state
get_toggle_state() {
    response=$(curl -s -w "\n%{http_code}" $URL)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ $http_code -eq 200 ]; then
        if command -v jq &> /dev/null; then
            toggle_status=$(echo "$body" | jq -r '.status')
            if [ "$toggle_status" = "1" ]; then
                echo "ON"
            elif [ "$toggle_status" = "0" ]; then
                echo "OFF"
            else
                echo "Toggle Toggle_Status: Unknown"
            fi
        else
            echo "Error: jq is not installed. Cannot parse JSON response."
        fi
    else
        echo "Error: HTTP status code $http_code"
    fi
}

# Function to get the batch ID
get_batch_id() {
    response=$(curl -s -w "\n%{http_code}" $URL)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ $http_code -eq 200 ]; then
        if command -v jq &> /dev/null; then
            batchid=$(echo "$body" | jq -r '.batchid')
            echo "$batchid"
        else
            echo "Error: jq is not installed. Cannot parse JSON response."
        fi
    else
        echo "Error: HTTP status code $http_code"
    fi
}

# Function to get the spreadsheet ID
get_spreadsheet_id() {
    response=$(curl -s -w "\n%{http_code}" $URL)
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ $http_code -eq 200 ]; then
        if command -v jq &> /dev/null; then
            spreadsheet_url=$(echo "$body" | jq -r '.spreadsheet_url')
            # Extract the sheet ID from the URL
            sheet_id=$(echo "$spreadsheet_url" | sed -n 's/.*\/d\/\([^\/]*\).*/\1/p')
            if [ -n "$sheet_id" ]; then
                echo "$sheet_id"
            else
                echo ""
            fi
        else
            echo "Error: jq is not installed. Cannot parse JSON response."
        fi
    else
        echo "Error: HTTP status code $http_code"
    fi
}
