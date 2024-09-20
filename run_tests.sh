#!/bin/bash
source tests.sh
source drive_tools.sh
source utilities.sh
INFO=""
udevadm trigger
MANUFACTURER=$(get_manufacturer)
MODEL=$(get_model)
CPU=$(get_cpu)
MEM=$(get_mem)
DISPLAY=$(get_display_size)
BATTERY=$(get_battery)
WIFI=$(get_wifi)
GPU=$(get_gpu)
TOUCHSCREEN=$(get_touchscreen)
LTE=$(get_lte)
SERIAL=$(get_serial)
CHASSIS=$(get_chassis)
PEN=$(get_pen)
STORAGE=$(wipe_all)
PCI=$(get_pci_cards)
SERVER_MEM=$(get_server_mem)
ifup -a
until ping -q -c1 1.1.1.1; do
    sleep 1
done

# Function to write messages to tty2 on new lines
write_message() {
    echo -e "$1"  > /dev/tty2
}

BATCH_ID=$(get_batch_id)

GRADE=""

ASSET_SCAN=$(get_toggle_state)
ASSET_TAG=""
if [ "$ASSET_SCAN" = "ON" ]; then
    write_message "Please scan the asset tag now."
    
    # Read from tty2 with a timeout
    if read ASSET_TAG < /dev/tty2; then
        if [ -n "$ASSET_TAG" ]; then
            write_message "Asset tag scanned: $ASSET_TAG"
        else
            write_message "Empty asset tag received."
        fi
    else
        write_message "No asset tag scanned within the time limit."
    fi
fi

if [[ -n "$DISPLAY" ]] || [[ "$TOUCHSCREEN" == "YES" ]]; then
    INFO+="LAPTOP/AIO"
else
    INFO+="DESKTOP/SERVER"
fi

INFO+=";$GRADE"
INFO+=";$ASSET_TAG"
INFO+=";$SERIAL"
INFO+=";$BATCH_ID"
INFO+=";$MANUFACTURER"
INFO+=";$MODEL"
INFO+=";$CPU"
INFO+=";$PEN"
INFO+=";$STORAGE"
INFO+=";$BATTERY"
INFO+=";$MEM"
INFO+=";$SERVER_MEM"
INFO+=";$GPU"
INFO+=";$WIFI"
INFO+=";$LTE"
INFO+=";$CHASSIS"
INFO+=";$DISPLAY"
INFO+=";$TOUCHSCREEN"
INFO+=";$PCI"

SHEET=$(get_spreadsheet_id)
until $(python3 update_sheet.py "${SHEET}" "${INFO}"); do
    sleep 1
done
