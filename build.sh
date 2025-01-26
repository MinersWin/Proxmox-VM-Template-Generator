#!/bin/bash

# Source configuration file
if [ -f "./config.conf" ]; then
    source "./config.conf"
else
    echo -e "\e[31mError: Configuration file 'config.conf' not found\e[0m"
    exit 1
fi

# Function to load custom configuration
load_custom_config() {
    local custom_config="$1"
    if [ -n "$custom_config" ] && [ "$custom_config" != "-" ]; then
        local custom_config_path="./custom/${custom_config}.conf"
        if [ -f "$custom_config_path" ]; then
            echo "Loading custom configuration: $custom_config_path"
            source "$custom_config_path"
        else
            echo -e "\e[31mWarning: Custom configuration file '$custom_config_path' not found\e[0m"
            exit 1
        fi
    fi
}

# Check if screen is installed when enabled
if [ "$USE_SCREEN" = true ]; then
    if ! command -v screen >/dev/null 2>&1; then
        echo -e "\e[31mError: Screen is not installed but required (USE_SCREEN=true in config.conf)"
        echo "To install screen, run:"
        echo "  apt-get install screen"
        echo -e "Or disable screen usage by setting USE_SCREEN=false in config.conf\e[0m"
        exit 1
    fi
fi

# Screen handling function
handle_screen() {
    if [ "$USE_SCREEN" = true ]; then
        if screen -list | grep -q "$SCREEN_NAME"; then
            echo "Screen session '$SCREEN_NAME' already exists. Reattaching..."
            exec screen -r "$SCREEN_NAME"
            exit 0
        else
            echo "Starting new screen session '$SCREEN_NAME'..."
            screen -S "$SCREEN_NAME" "$0" "$@"
            exit 0
        fi
    fi
}

# Call screen handler if we're not already in a screen session
if [ "$USE_SCREEN" = true ] && [ -z "$STY" ]; then
    handle_screen "$@"
fi

# Set base directory
BASE_DIR="/root/Template"

# Read sshd_config content
sshdconfig=$(cat "$BASE_DIR/data/etc/ssh/sshd_config")

# Check if CSV file is provided as argument
if [ $# -ne 1 ]; then
    echo -e "\e[31mUsage: $0 <csv_file>\e[0m"
    echo "CSV format should be: custom,vm_id,debian_image,vm_name,download_url"
    exit 1
fi

csv_file="$1"

# Check if CSV file exists
if [ ! -f "$csv_file" ]; then
    echo -e "\e[31mError: CSV file '$csv_file' not found\e[0m"
    exit 1
fi

# Check if images directory exists and create if needed
if [ ! -d "$IMAGES_DIR" ]; then
    mkdir -p "$IMAGES_DIR"
fi

# Debug: Show CSV content
echo "CSV content:"
cat "$csv_file"

# Process CSV file, removing any carriage returns and processing line by line
while IFS=, read -r custom vm_id debian_image vm_name download_url; do
    # Skip header line
    [ "$vm_id" = "vm_id" ] && continue
    
    # Reset to default configuration (in case previous iteration loaded custom config)
    source "./config.conf"
    
    # Load custom configuration if specified
    load_custom_config "$custom"
    
    # Use storage pool from config
    storage_pool="$DEFAULT_STORAGE_POOL"
    
    echo "Processing line:"
    echo "Custom: $custom"
    echo "VM ID: $vm_id"
    echo "Image: $debian_image"
    echo "Storage: $storage_pool"
    echo "Name: $vm_name"
    echo "URL: $download_url"

    # Check if image exists, if not download it
    image_path="$IMAGES_DIR/$debian_image"

    # Remove image if it already exists
    rm -f "$image_path"
    # Download image
    echo "Downloading image: $debian_image"
    wget --no-check-certificate -O "$image_path" "$download_url"
    if [ $? -ne 0 ]; then
        echo -e "\e[31mError downloading image: $debian_image\e[0m"
        continue
    fi
    
    # Check if image was downloaded if not stop execution for this template
    if [ ! -f "$image_path" ]; then
        echo -e "\e[31mError: Image file not found: $image_path\e[0m"
        exit 1
    fi
    
    echo "Processing VM: $vm_name (ID: $vm_id)"

    # Install packages if defined
    if [ -n "$INSTALL_PACKAGES" ]; then
        echo "Installing packages: $INSTALL_PACKAGES"
        for package in $INSTALL_PACKAGES; do
            echo "Installing package: $package"
            virt-customize -a "$image_path" --install "$package"
            if [ $? -ne 0 ]; then
                echo -e "\e[31mError installing package: $package\e[0m"
                continue
            fi
        done
    fi

    #Prepare Image
    # Configure networkd-wait-online if enabled
    if [ "$ENABLE_NETWORKD_WAIT_CONFIG" = true ]; then
        virt-customize -a "$image_path" --mkdir /etc/systemd/system/systemd-networkd-wait-online.service.d/
        virt-customize -a "$image_path" --upload "$NETWORKD_CONF_PATH":/etc/systemd/system/systemd-networkd-wait-online.service.d
    fi
    
    # Configure SSH if enabled
    if [ "$ENABLE_CUSTOM_SSH" = true ]; then
        virt-customize -a "$image_path" --delete /etc/ssh/sshd_config
        virt-customize -a "$image_path" --upload "$SSHD_CONFIG_PATH":/etc/ssh/sshd_config
    fi

    # Replace Custom Configs if CUSTOM_CONFIGS is true, loop through each config in the string seperated by spaces, replace the path before the first comma wit virt-edit with the content of the path after the comma
    # Example: 
    # CUSTOM_CONFIGS="alma-cloud alma-network"
    # alma-cloud="/etc/cloud/cloud.cfg,custom-configs/alma-cloud.cfg"
    # alma-network="/etc/systemd/system/systemd-networkd-wait-online.service.d/waitany.conf,custom-configs/alma-network.conf"
    # alma-ssh="/etc/ssh/sshd_config,custom-configs/alma-ssh.conf"

    if [ -n"$CUSTOM_CONFIGS"]; then
        for config in $CUSTOM_CONFIGS; do
            path=$(eval echo \$$config | cut -d, -f1)
            file=$(eval echo \$$config | cut -d, -f2)
            virt-customize -a "$image_path" --delete "$path"
            virt-customize -a "$image_path" --upload "$file":"$path"
        done
    fi


    # Reset machine-id if enabled
    if [ "$RESET_MACHINE_ID" = true ]; then
        virt-customize -a "$image_path" --run-command "echo -n > /etc/machine-id"
    fi

    # Remove VM if it already exists
    if [ $(qm list | grep -c "$vm_id") -ne 0 ]; then
        echo "Removing existing VM: $vm_id"
        qm destroy $vm_id
    fi
    
    # Run Proxmox commands with CSV inputs
    qm create $vm_id --name "$vm_name" --memory $DEFAULT_MEMORY --net0 $DEFAULT_NETWORK_CARD,bridge=$DEFAULT_BRIDGE,tag=$DEFAULT_VLAN_TAG
    qm importdisk $vm_id "$image_path" ${storage_pool:-$DEFAULT_STORAGE_POOL}
    echo     qm importdisk $vm_id "$image_path" ${storage_pool:-$DEFAULT_STORAGE_POOL}

    
    # Build drive attributes string
    drive_attrs=""
    [ -n "$DRIVE_CACHE" ] && drive_attrs="${drive_attrs:+$drive_attrs,}cache=$DRIVE_CACHE"
    [ -n "$DRIVE_DISCARD" ] && drive_attrs="${drive_attrs:+$drive_attrs,}discard=$DRIVE_DISCARD"
    [ -n "$DRIVE_SSD" ] && drive_attrs="${drive_attrs:+$drive_attrs,}ssd=$DRIVE_SSD"
    [ -n "$DRIVE_IOTHREAD" ] && drive_attrs="${drive_attrs:+$drive_attrs,}iothread=$DRIVE_IOTHREAD"
    [ -n "$DRIVE_BACKUP" ] && drive_attrs="${drive_attrs:+$drive_attrs,}backup=$DRIVE_BACKUP"
    
    qm set $vm_id --scsihw $DEFAULT_SCSIHW --scsi0 ${storage_pool:-$DEFAULT_STORAGE_POOL}:vm-$vm_id-disk-0${drive_attrs:+,$drive_attrs}
    qm set $vm_id --scsihw $DEFAULT_SCSIHW --scsi0 ${storage_pool:-$DEFAULT_STORAGE_POOL}:$vm_id/vm-$vm_id-disk-0.raw${drive_attrs:+,$drive_attrs}
    qm set $vm_id --boot c --bootdisk scsi0

    if [ "$ENABLE_CLOUD_INIT" = true ]; then
        qm set $vm_id --${CLOUDINIT_CONTROLLER}${CLOUDINIT_CONTROLLER_ID} ${storage_pool:-$DEFAULT_STORAGE_POOL}:cloudinit
    fi
    
    if [ "$ENABLE_SERIAL_SOCKET" = true ]; then
        qm set $vm_id -serial0 socket
    fi
    
    if [ "$ENABLE_QEMU_AGENT" = true ]; then
        qm set $vm_id --agent 1
    fi

    qm set $vm_id --cpu cputype=$CPU_TYPE
    
    if [ "$ENABLE_AUTOSTART" = true ]; then
        qm set $vm_id --onboot 1
    fi
    
    # Set OS type for optimizations
    qm set $vm_id --ostype $OS_TYPE

    qm set $vm_id --bios $BIOS_TYPE

    qm set $vm_id --ciuser $VM_DEFAULT_USER
    
    qm template $vm_id
    if [ "$ENABLE_FIREWALL" = true ]; then
        cp "$DEFAULT_FW_PATH" /etc/pve/firewall/$vm_id.fw
    fi

    echo "VM creation and configuration completed successfully."
done < <(tr -d '\r' < "$csv_file")