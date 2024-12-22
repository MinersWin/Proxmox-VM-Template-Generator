# Proxmox VM Template Generator

An automated tool for creating and configuring Ubuntu Cloud Image-based VMs in Proxmox VE with standardized settings and security configurations.

## Overview

This project automates the process of creating Proxmox VMs from Ubuntu Cloud Images. It handles the entire workflow from downloading the cloud images to configuring the final VM template.

### Key Features

- Automated download and verification of Ubuntu Cloud Images
- Pre-configuration of images with essential system settings
- Automated VM creation in Proxmox with standardized settings
- Flexible configuration via CSV file
- Integrated firewall configuration
- Standardized SSH security settings
- Network configuration optimization

## Prerequisites

- Root access to a Proxmox VE host
- `virt-customize` tool installed (```apt update -y && apt install libguestfs-tools -y```)
- Internet connection for downloading Cloud Images
- Sufficient storage space in the defined storage pool
- Proxmox VE 7.0 or higher

## Detailed Operation

The script performs the following steps for each VM defined in the CSV:

1. **Pre-flight Checks**
   - Validates CSV input
   - Checks for required tools and permissions
   - Verifies storage availability

2. **Image Management**
   - Downloads the specified Ubuntu Cloud Image
   - Stores images in a dedicated directory
   - Handles cleanup of existing images

3. **Image Customization**
   - Installs QEMU Guest Agent for better VM management
   - Configures network settings for improved boot time
   - Sets up secure SSH configuration
   - Resets machine-id for template preparation

4. **VM Creation**
   - Removes existing VM if it exists (prevents ID conflicts)
   - Creates new VM with standardized settings
   - Imports customized cloud image
   - Configures VM hardware settings

5. **Security Configuration**
   - Applies firewall rules
   - Sets up secure SSH defaults
   - Configures system services for security

## Configuration

### CSV Configuration File

VMs are configured via `vms.csv` with the following fields:

```csv
vm_id,debian_image,storage_pool,vm_name,download_url
5000,noble-server-cloudimg-amd64.img,MassStorage,ubuntu-24-04-amd64,https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

- `vm_id`: Unique Proxmox VM ID (1-999999)
- `debian_image`: Name for the downloaded cloud image
- `storage_pool`: Proxmox storage pool for VM placement
- `vm_name`: Display name for the VM
- `download_url`: Direct URL to the Ubuntu Cloud Image

### System Configurations Applied

The resulting VM template includes:

1. **Network Optimization**
   - Configured systemd-networkd-wait-online service
   - Optimized network boot parameters
   - Improved startup time

2. **Security Settings**
   - Hardened SSH configuration
   - Basic firewall rules
   - Disabled root password login
   - SSH key-based authentication preparation

3. **System Preparation**
   - Cleaned machine-id
   - Configured QEMU Guest Agent
   - Optimized for template usage

## Usage

1. Clone this repository to your Proxmox host
2. Configure your VMs in `vms.csv`
3. Execute as root:
   ```bash
   cd /path/to/repo
   ./build.sh vms.csv
   ```

### Required Root Permissions

This script must be run as root on the Proxmox host because it needs to:
- Create and modify VMs
- Access Proxmox configuration directories
- Modify system files within the VM images
- Configure network and firewall settings

## Directory Structure

```
.
├── build.sh              # Main script
├── vms.csv              # VM configuration file
├── default.fw           # Default firewall configuration
├── images/              # Directory for downloaded images (git-ignored)
└── data/
    └── etc/
        ├── ssh/
        │   └── sshd_config                  # Hardened SSH configuration
        └── systemd/system/
            └── systemd-networkd-wait-online.service.d/
                └── waitany.conf             # Network optimization

```

## Final Template Configuration

The resulting VM template includes:

- **System**
  - Ubuntu Cloud Image base
  - QEMU Guest Agent installed
  - Cleaned machine-id for cloning
  - Optimized network configuration

- **Security**
  - Hardened SSH configuration
  - Basic firewall rules
  - No default passwords
  - Prepared for SSH key deployment

- **Network**
  - Configured for DHCP by default
  - Optimized network service startup
  - Ready for cloud-init configuration

## Troubleshooting

Common issues and solutions:

1. **Permission Errors**
   - Ensure you're running as root
   - Check Proxmox storage permissions

2. **Download Issues**
   - Verify internet connectivity
   - Check URL validity
   - Ensure sufficient storage space

3. **VM Creation Failures**
   - Check for VM ID conflicts
   - Verify storage pool existence
   - Check Proxmox resource availability

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request
