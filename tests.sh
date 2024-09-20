#!/bin/bash
get_battery() {
	BATT=$(acpi -V | grep design | awk 'NF>1{print $NF}')
	if [[ -z "$BATT" ]]; then
		if [[ -z "$(acpi -V | grep 0%)" ]]; then
			echo "MISSING"
		else
			echo "ERROR"
		fi
	else
		echo "$BATT"
	fi
}
get_mem() {
	dmidecode -t memory | grep Size | grep -v ' Size' | grep -v 'No' | awk '{print $2}' | awk '{p=1; while(p<$1) p*=2; sum+=p} END{print sum "GB"}'
}
get_server_mem() {
    dmidecode -t memory | grep 'Size\|Type:\|Speed' | grep -v 'Configured\|Error Correction' | sed 's/ MT\/s//g' | sed -n '/Size: No Module Installed/{N;d;};p' | awk '
  /Size:/ {size = $2$3}
  /Type:/ {type = $2}
  /Speed:/ {speed = $2 " " $3; print size, type, speed}
'
}
get_pci_cards() {
    lspci -vv | grep -B1 'Physical Slot' | grep -v '^--$' | awk '{
        if ($1 == "Physical") {
            slot=$3;
        } else {
            subsystem=$0;
        }
        if (slot && subsystem && !seen[slot]++) {
            print subsystem "\nPhysical Slot: " slot;
            slot="";
            subsystem="";
        }
    }' | grep -v 'Physical Slot' | sed 's/\s*Subsystem: //g' | grep -v 'Intel Corporation Device 0000'
}
get_model() {
    case "$(get_manufacturer)" in
    "Lenovo")
        dmidecode -s system-version
        ;;
    *)
        dmidecode --type 1 | grep Product | cut -d' ' -f 3-;;
    esac
}

get_manufacturer() {
    dmidecode -s system-manufacturer | sed -e 's/Inc\.//g' -e 's/Corporation//g' -e 's/LENOVO/Lenovo/g'
}
get_cpu() {
    case "$(dmidecode -s processor-family | grep -v 'OUT' | uniq)" in
        "Pentium")
            dmidecode -s processor-version | awk '{print $4}';;
        "Core i9" | "Core i7" | "Core i5" | "Core i3" | "Core m7" | "Core m5" | "Core m3")
            VERSION="$(dmidecode -s processor-version)"
            if [[ "$(echo ${VERSION} | awk '{print $3}')" == "Intel(R)" ]]; then
                echo "${VERSION}" | awk '{print $5}'
            else
                echo "${VERSION}" | awk '{print $3}'
            fi
            ;;
        "A-Series")
            dmidecode -s processor-version | awk '{print $2}';;
        "Xeon")
            dmidecode -s processor-version | grep -v 'Not' | awk '{print "Xeon " $4 " " $5}';;
        *)
            dmidecode -s processor-version;;
    esac
}
get_display_size() {
    if [[ -f /sys/class/drm/card1-eDP-1/edid ]]; then
        DIM=$(cat /sys/class/drm/card1-eDP-1/edid | di-edid-decode | grep cm)
        B=$(echo "$DIM" | awk '{print $4}')
        A=$(echo "$DIM" | awk '{print $7}')
        C=$(echo "(sqrt($A.000000^2 + $B.000000^2)) * 0.393701" | bc)
        SIZE_ROUNDED=$(echo "(($C + 0.2) / 0.5 ) * 0.5" | bc)
        printf '%.1f"\n' "$SIZE_ROUNDED"
    elif [ -d "/sys/class/drm/*eDP*" ]; then
        echo "???"
    fi
}
get_storage() {
    lsblk -n -do tran,size | grep -v 'usb\|K\|B'
}
#consider switching to lshw
get_webcam() {
    if [[ -n $(libinput list-devices | grep 'Video Bus') ]]; then
	echo "YES"
    else
	echo "NO"
    fi
}
#consider switching to lshw
get_pen() {
	if [[ -n $(libinput list-devices | grep tablet) ]]; then
		echo "CHECK"
	else
		echo "NO"
	fi
}
#consider switching to lshw
get_touchscreen() {
	if [[ -n $(libinput list-devices | grep touch) ]]; then
		echo "YES"
	else
		echo "NO"
	fi
}
get_gpu() {
    gpu=$(lspci | grep VGA | sed 's/^.*: //' | grep -vi intel)
    if [ -z "$gpu" ]; then
        echo "Integrated"
    else
        echo "$gpu"
    fi
}
#consider switching to lshw
get_wifi() {
    if [[ -n "$(lspci | grep Network)" ]]; then
	echo "YES"
    else
	echo "NO"
    fi
}
get_lte() {
    if [[ -n "$(ip addr | grep wwan)" ]]; then
	echo "YES"
    else
	echo "NO"
    fi
}
get_chassis() {
    dmidecode -s chassis-type | xargs
}
get_serial() {
	dmidecode -s chassis-serial-number
}
