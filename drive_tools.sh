#!/bin/bash
WIPE_REPORT="WIPE NOT RUN"
CRITICAL_FAILURE=-2
FAILURE=-1
SUCCESS=0
CONFIG="/media/usb/config.txt"

wipe_sata() {
    RET=$SUCCESS
    dd if=/dev/zero of=/dev/"$LABEL" bs=520 count=1
    if [[ $? != 0 ]]; then
    	RET=$CRITICAL_FAILURE
     	>&2 echo "wipe_sata: unable to wipe partition of $LABEL"
    fi
    if [[ $(lsblk -no ROTA /dev/${LABEL} | head -1) -eq 1 ]]; then
	return $RET
    fi
    unfreeze
    hdparm --user-master u --security-set-pass p /dev/$1
    hdparm --user-master u --security-erase p /dev/$1
    if [[ $? != 0 ]]; then
        >&2 echo "wipe_sata: hdparm security-erase failed"
        if [[ $RET > $CRITICAL_FAILURE ]]; then RET=$FAILURE; fi
    else
        RET=$SUCCESS
    fi
    hdparm --user-master m --security-unlock p /dev/$1
    hdparm --user-master m --security-disable p /dev/$1
    return $RET
}
#check if drive supports secure erase
wipe_nvme() {
    RET=$SUCCESS
    dd if=/dev/zero of=/dev/"$1" bs=520 count=1
    if [[ $? != 0 ]]; then
    	RET=$CRITICAL_FAILURE
     	>&2 echo "wipe_nvme: unable to wipe partition of $LABEL"
    fi
    OPAL="$(sedutil-cli --query /dev/$1 | grep Invalid)"
    if [[ -z "$OPAL" ]]; then
     	sedutil-cli --initialSetup debug /dev/"$1"
     	if [[ $? != 0 ]]; then
     	    >&2 echo "wipe_nvme: OPAL could not be enabled"
     	fi
     fi
     unfreeze
     nvme format --force -s1 /dev/"$1"
     if [[ $? != 0 ]]; then
     	>&2 echo "wipe_nvme: nvme secure format attempt 1 failed"
     	if [[ $RET > $CRITICAL_FAILURE ]]; then RET=$FAILURE; fi
     fi
     if [[ -z "$OPAL" ]]; then
     	sedutil-cli --reverttper debug /dev/"$1"
     	if [[ $? != 0 ]]; then
     	    >&2 echo "wipe_nvme: OPAL could not be disabled"
     	fi
     fi
     if [[ -z "$OPAL" && $RET != 0 ]]; then
     	nvme format --force -s1 /dev/"$1"
     	if [[ $? != 0 ]]; then
     	    >&2 echo "wipe_nvme: nvme secure format attempt 2 failed"
     	    if [[ $RET > $CRITICAL_FAILURE ]]; then RET=$FAILURE; fi
     	else
     	    RET=$SUCCESS
     	fi
     fi
     return $RET
}
unfreeze() {
    RETRIES=3
    i=0
    while [[ $i < $RETRIES ]]; do
	rtcwake -s 1 -m mem && break
	let i=i+1
    done
    if [[ $i == $RETRIES ]]; then
	zzz
    fi
}
wipe_all() {
    DRIVES=$(lsblk -n -do name,tran,size | grep -v 'usb\|K\|B\|M\|loop')
    RETRIES=3
    WIPE_REPORT=""

    if [[ $? != 0 ]]; then
        >&2 echo "unable to sleep"
    fi

    for DRIVE in "$DRIVES"
    do
        LABEL=$(awk '{print $1}' <<< "$DRIVE")
        TYPE=$(awk '{print $2}' <<< "$DRIVE")
        SIZE=$(awk '{print $3}' <<< "$DRIVE")
        case "$TYPE" in
	    "nvme")
		wipe_nvme "$LABEL" > /dev/kmsg 2>&1
                if [[ $? == 0 ]]; then
                    WIPE_REPORT+="$SIZE NVMe\n"
                else
                    WIPE_REPORT+="$SIZE NVMe ERROR\n"
                fi
                ;;
	    "sata")
		wipe_sata "$LABEL" > /dev/kmsg 2>&1
                if [[ $? == 0 ]]; then
                    WIPE_REPORT+="$SIZE SSD\n"
                else
                    WIPE_REPORT+="$SIZE SSD ERROR\n"
                fi
                ;;
            "")
                WIPE_REPORT+="\n"
                ;;
            *)
                WIPE_REPORT+="$SIZE $TYPE ??? -2\n"
                ;;
        esac
    done
    echo -e $WIPE_REPORT
}
wipe_all() {
    DRIVES=$(lsblk -n -do name,tran,size | grep -v 'usb\|K\|B\|M\|loop')
    RETRIES=3
    WIPE_REPORT=""

    for DRIVE in "$DRIVES"
    do
        LABEL=$(awk '{print $1}' <<< "$DRIVE")
        TYPE=$(awk '{print $2}' <<< "$DRIVE")
        SIZE=$(awk '{print $3}' <<< "$DRIVE")

        # Check if the drive is SSD or HDD
        if [[ $(lsblk -no ROTA /dev/${LABEL} | head -1) -eq 0 ]]; then
            DISK_TYPE="SSD"
        else
            DISK_TYPE="HDD"
        fi

        case "$TYPE" in
            "nvme")
                wipe_nvme "$LABEL" > /dev/kmsg 2>&1
                if [[ $? == 0 ]]; then
                    WIPE_REPORT+="$SIZE NVMe\n"
                else
                    WIPE_REPORT+="$SIZE NVMe ERROR\n"
                fi
                ;;
            "sata")
                wipe_sata "$LABEL" > /dev/kmsg 2>&1
                if [[ $? == 0 ]]; then
                    WIPE_REPORT+="$SIZE $DISK_TYPE\n"
                else
                    WIPE_REPORT+="$SIZE $DISK_TYPE ERROR\n"
                fi
                ;;
            "")
                WIPE_REPORT+="\n"
                ;;
            *)
                WIPE_REPORT+="$SIZE $TYPE ??? -2\n"
                ;;
        esac
    done
    echo -e "$WIPE_REPORT" | head -1
}
get_wipe_report() {
    echo "$WIPE_REPORT"
}
