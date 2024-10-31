#!/bin/sh

# Set Discord webhook URL
WEBHOOK_URL="https://discordapp.com/api/webhooks/YOUR_WEBHOOK_ID"

# Paths for device tracking
LAST_FILE_LAN="/tmp/devices_last_lan.txt"
CURRENT_FILE_LAN="/tmp/devices_current_lan.txt"
LAST_FILE_GUEST="/tmp/devices_last_guest.txt"
CURRENT_FILE_GUEST="/tmp/devices_current_guest.txt"
KNOWN_DEVICES="/usr/local/bin/known_devices.txt"

# Initialize known devices file if it doesn't exist
[ -f "$KNOWN_DEVICES" ] || touch "$KNOWN_DEVICES"

# Function to perform an arp-scan on a specified network
scan_network() {
    local interface=$1
    local subnet=$2
    local last_file=$3
    local current_file=$4
    local network_name=$5

    # Run arp-scan on the specified interface, filter for valid IP addresses only
    arp-scan -I "$interface" "$subnet" | grep -E "^([0-9]{1,3}\.){3}[0-9]{1,3}" | awk '{print $1, $2, $3}' > "$current_file"

    # If known_devices.txt is empty, populate it with current devices without notifications
    if [ ! -s "$KNOWN_DEVICES" ]; then
        cat "$current_file" >> "$KNOWN_DEVICES"
        echo "Populated known_devices.txt with currently connected devices."
    else
        # Check for new IPs if a previous scan exists
        if [ -f "$last_file" ]; then
            # Sort the files and save to temporary files
            sort "$last_file" > /tmp/sorted_last_file.txt
            sort "$current_file" > /tmp/sorted_current_file.txt

            # Find new IPs by checking which entries in current_file are not in last_file
            grep -Fxv -f /tmp/sorted_last_file.txt /tmp/sorted_current_file.txt > /tmp/new_ips.txt

            # Filter out known devices from new IPs
            if [ -s /tmp/new_ips.txt ]; then
                while IFS= read -r line; do
                    ip=$(echo $line | awk '{print $1}')
                    mac=$(echo $line | awk '{print $2}')
                    vendor=$(echo $line | awk '{print $3}')

                    # Check if the device is already known (by MAC address only to avoid duplicates)
                    if ! grep -q "$mac" "$KNOWN_DEVICES"; then
                        # Send notification to Discord
                        curl -H "Content-Type: application/json" \
                             -X POST \
                             -d "{\"content\": \"\uD83D\uDC40 **New device detected on $network_name network:**\n**IP:** $ip\n**MAC:** $mac\n**Vendor:** $vendor\"}" \
                             $WEBHOOK_URL

                        # Add this device to known devices only if it is not already present
                        echo "$ip $mac $vendor" >> "$KNOWN_DEVICES"
                    fi
                done < /tmp/new_ips.txt
            fi

            # Clean up temporary files
            rm /tmp/sorted_last_file.txt /tmp/sorted_current_file.txt /tmp/new_ips.txt
        fi
    fi

    # Update the last scan file with the current scan
    cp "$current_file" "$last_file"
}

# Scan both LAN and Guest networks and notify for new devices
scan_network br-lan 192.168.1.0/24 "$LAST_FILE_LAN" "$CURRENT_FILE_LAN" "LAN"
scan_network br-guest 192.168.2.0/24 "$LAST_FILE_GUEST" "$CURRENT_FILE_GUEST" "Guest LAN"
