# Proxmox VM Template Generator

An automated tool for creating and configuring Ubuntu Cloud Image-based VMs in Proxmox VE with standardized settings. This tool is specifically designed for VPS providers to create standardized VM templates with simplified user access.

## Important Disclaimer

This tool is designed and used in production by [Nerdscave Hosting](https://nerdscave-hosting.com) and [Servermanagementpanel](https://servermanagementpanel.com). It is specifically tailored for VPS hosting providers who need to maintain a balance between security and usability for their customers.

### Security Notice

By default, this tool configures VMs with:
- Root-only user setup for simplified customer access
- SSH configuration allowing both key-based and password authentication for root (configurable in [sshd_config](data/etc/ssh/sshd_config))
- Basic security settings suitable for VPS environments

**⚠️ Warning**: If you plan to use this for purposes other than VPS hosting, you should consider modifying these security settings:
- Disable root password authentication
- Create and use non-root users
- Implement stricter SSH security policies

**Note**: Future versions will allow all security and system settings to be configured through the [config.conf](config.conf) file.

## Overview

This project automates the process of creating Proxmox VMs from Ubuntu Cloud Images. It handles the entire workflow from downloading the cloud images to configuring the final VM template.

### Key Features

- Automated download and verification of Ubuntu Cloud Images
- Pre-configuration of images with essential system settings
- Automated VM creation in Proxmox with standardized settings
- Flexible configuration via CSV file
- Integrated firewall configuration
- VPS-oriented SSH settings
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
   - Sets up SSH configuration for VPS access
   - Resets machine-id for template preparation

4. **VM Creation**
   - Removes existing VM if it exists (prevents ID conflicts)
   - Creates new VM with standardized settings
   - Imports customized cloud image
   - Configures VM hardware settings

5. **Security Configuration**
   - Applies firewall rules
   - Sets up SSH for both key and password authentication
   - Configures system services

## Configuration

### CSV Configuration File

VMs are configured via `vms.csv` with the following fields:

```csv
vm_id,debian_image,vm_name,download_url
100,noble-server-cloudimg-amd64.img,Ubuntu-24.04-Noble-LTS,https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
```

- `vm_id`: Unique Proxmox VM ID (must be 100 or higher)
- `debian_image`: Name for the downloaded cloud image
- `vm_name`: Display name for the VM
- `download_url`: Direct URL to the Ubuntu Cloud Image

Note: The storage pool is configured globally in `config.conf` using the `DEFAULT_STORAGE_POOL` setting.

### System Configurations Applied

The resulting VM template includes:

1. **Network Optimization**
   - Configured systemd-networkd-wait-online service
   - Optimized network boot parameters
   - Improved startup time

2. **VPS Access Settings**
   - SSH configuration allowing root access
   - Support for both key-based and password authentication
   - Basic firewall rules
   - Prepared for customer SSH key injection

3. **System Preparation**
   - Cleaned machine-id
   - Configured QEMU Guest Agent
   - Optimized for template usage

## Usage

1. Clone this repository to your Proxmox host
2. Configure your VMs in `vms.csv` (remember: VM IDs must be 100 or higher)
3. Execute as root:
   ```bash
   cd /path/to/repo
   ./build.sh vms.csv
   ```

## Production Usage

This tool is actively used in production by:
- [NerdsCave Hosting](https://nerdscave-hosting.com)
- [Server Management Panel](https://servermanagementpanel.com)

For commercial support or custom modifications, please contact the respective hosting providers.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
