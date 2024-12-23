#!/bin/bash

# Source configuration file
if [ -f "./config.conf" ]; then
    source "./config.conf"
else
    echo "Error: Configuration file 'config.conf' not found"
    exit 1
fi

# Set base directory
BASE_DIR="/root/Template"

# Read sshd_config content
sshdconfig=$(cat "$BASE_DIR/data/etc/ssh/sshd_config")

# Check if CSV file is provided as argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <csv_file>"
    echo "CSV format should be: vm_id,debian_image,storage_pool,vm_name,download_url"
    exit 1
fi

csv_file="$1"

# Check if CSV file exists
if [ ! -f "$csv_file" ]; then
    echo "Error: CSV file '$csv_file' not found"
    exit 1
fi

# Create images directory if it doesn't exist
mkdir -p "$IMAGES_DIR"

# Debug: Show CSV content
echo "CSV content:"
cat "$csv_file"

# Process CSV file, removing any carriage returns and processing line by line
while IFS=, read -r vm_id debian_image storage_pool vm_name download_url; do
    # Skip header line
    [ "$vm_id" = "vm_id" ] && continue
    
    echo "Processing line:"
    echo "VM ID: $vm_id"
    echo "Image: $debian_image"
    echo "Storage: $storage_pool"
    echo "Name: $vm_name"
    echo "URL: $download_url"
    
    # Check if image exists, if not download it
    image_path="$IMAGES_DIR/$debian_image"
    # Remove VM if it already exists
    if [ $(qm list | grep -c "$vm_id") -ne 0 ]; then
        echo "Removing existing VM: $vm_id"
        qm destroy $vm_id
    fi

    # Remove image if it already exists
    rm -f "$image_path"
    # Download image
    echo "Downloading image: $debian_image"
    wget -O "$image_path" "$download_url"
    if [ $? -ne 0 ]; then
        echo "Error downloading image: $debian_image"
        continue
    fi
    
    echo "Processing VM: $vm_name (ID: $vm_id)"

    #Prepare Image
    virt-customize -a "$image_path" --install "$INSTALL_PACKAGES"
    virt-customize -a "$image_path" --mkdir /etc/systemd/system/systemd-networkd-wait-online.service.d/
    virt-customize -a "$image_path" --upload "$NETWORKD_CONF_PATH":/etc/systemd/system/systemd-networkd-wait-online.service.d
    virt-customize -a "$image_path" --delete /etc/ssh/sshd_config
    virt-customize -a "$image_path" --upload "$SSHD_CONFIG_PATH":/etc/ssh
    virt-customize -a "$image_path" --run-command "echo -n > /etc/machine-id"
    
    # Run Proxmox commands with CSV inputs
    qm create $vm_id --name "$vm_name" --memory $DEFAULT_MEMORY --net0 virtio,bridge=$DEFAULT_BRIDGE,tag=$DEFAULT_VLAN_TAG
    qm importdisk $vm_id "$image_path" ${storage_pool:-$DEFAULT_STORAGE_POOL}
    qm set $vm_id --scsihw $DEFAULT_SCSIHW --scsi0 ${storage_pool:-$DEFAULT_STORAGE_POOL}:vm-$vm_id-disk-0,ssd=1
    
    if [ "$ENABLE_CLOUD_INIT" = true ]; then
        qm set $vm_id --ide2 ${storage_pool:-$DEFAULT_STORAGE_POOL}:cloudinit
    fi
    
    qm set $vm_id --boot c --bootdisk scsi0
    
    if [ "$ENABLE_SERIAL_SOCKET" = true ]; then
        qm set $vm_id -serial0 socket
    fi
    
    if [ "$ENABLE_QEMU_AGENT" = true ]; then
        qm set $vm_id --agent 1
    fi
    
    if [ "$ENABLE_AUTOSTART" = true ]; then
        qm set $vm_id --onboot 1
    fi
    
    qm template $vm_id
    cp "$DEFAULT_FW_PATH" /etc/pve/firewall/$vm_id.fw

    echo "VM creation and configuration completed successfully."
done < <(tr -d '\r' < "$csv_file")