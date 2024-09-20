#!/bin/bash

# Configuration
INTERFACES=("eth1" "wlan1" "wlan0" "eth0")
WPA_SUPPLICANT_CONF="/etc/wpa_supplicant/wpa_supplicant.conf"
UDHCPC_SCRIPT="/usr/share/udhcpc/default.script"
LOG_FILE="/var/log/network_config.log"
MAX_ATTEMPTS=3
TIMEOUT=60
PING_TARGET="1.1.1.1"
PING_COUNT=4

# Logging function
log() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Function to check and release locks
check_and_release_lock() {
    local iface=$1
    local pid_file="/var/run/wpa_supplicant_${iface}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log "Existing wpa_supplicant process found for $iface (PID: $pid). Terminating..."
            kill "$pid"
            sleep 1
        fi
        rm -f "$pid_file"
    fi
}

cleanup_wpa_supplicant() {
    local iface=$1
    log "Cleaning up wpa_supplicant for $iface"
    killall -q wpa_supplicant
    rm -f "/var/run/wpa_supplicant/$iface"
    check_and_release_lock "$iface"
}

configure_interface() {
    local iface=$1
    local attempt=1
    
    while [ $attempt -le $MAX_ATTEMPTS ]; do
        log "Configuring interface $iface (Attempt $attempt/$MAX_ATTEMPTS)"
        
        ip link set "$iface" up
        if [[ "$iface" == wlan* ]]; then
            cleanup_wpa_supplicant "$iface"
            if ! timeout $TIMEOUT wpa_supplicant -B -i"$iface" -c"$WPA_SUPPLICANT_CONF" -P "/var/run/wpa_supplicant_${iface}.pid"; then
                log "Failed to start wpa_supplicant for $iface"
                sleep 2
                attempt=$((attempt + 1))
                continue
            fi
            sleep 2  # Give wpa_supplicant some time to initialize
        fi
        
        if timeout $TIMEOUT udhcpc -i "$iface" -n -q -f -s "$UDHCPC_SCRIPT"; then
            log "Successfully obtained IP for $iface"
            rc-service chronyd start
            return 0
        fi
        
        log "Failed to obtain IP for $iface (Attempt $attempt/$MAX_ATTEMPTS)"
        sleep 2
        attempt=$((attempt + 1))
    done
    
    log "Failed to configure $iface after $MAX_ATTEMPTS attempts"
    return 1
}

ping_test() {
    log "Performing ping test to $PING_TARGET"
    if ping -c $PING_COUNT $PING_TARGET > /dev/null 2>&1; then
        log "Ping test successful"
        return 0
    else
        log "Ping test failed"
        return 1
    fi
}

main() {
    while true; do
        for iface in "${INTERFACES[@]}"; do
            if ip link show "$iface" &> /dev/null; then
                if configure_interface "$iface"; then
                    log "Successfully configured $iface"
                    if ping_test; then
                        log "Network configuration complete and ping test successful"
                        exit 0
                    else
                        log "Network configured but ping test failed. Trying next interface."
                    fi
                fi
            else
                log "Interface $iface not found"
            fi
        done
        log "No interface configured successfully or ping test failed, retrying in 10 seconds"
        sleep 10
    done
}

main
