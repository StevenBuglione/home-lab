#!/bin/bash

# local-network.sh - Configure network settings using netplan
# Usage: sudo ./local-network.sh <ip-address>
# Example: sudo ./local-network.sh 192.168.1.100/24

# Define color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
    log_error "This script must be run as root. Please use sudo."
    exit 1
fi

# Check if IP address is provided
if [ -z "$1" ]; then
    log_error "No IP address provided."
    echo "Usage: sudo $0 <ip-address>"
    echo "Example: sudo $0 192.168.1.100/24"
    exit 1
fi

# Validate IP address format (basic validation)
IP_ADDRESS="$1"
if ! echo "$IP_ADDRESS" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$'; then
    log_error "Invalid IP address format: $IP_ADDRESS"
    echo "Expected format: xxx.xxx.xxx.xxx/xx (e.g., 192.168.1.100/24)"
    exit 1
fi

# Extract IP and prefix if needed
if ! echo "$IP_ADDRESS" | grep -q "/"; then
    log_warning "No subnet mask specified, assuming /24"
    IP_ADDRESS="$IP_ADDRESS/24"
fi

# Get default gateway (assuming it's the first address in the subnet)
IP_BASE=$(echo "$IP_ADDRESS" | cut -d'/' -f1)
IFS='.' read -r -a IP_ARRAY <<< "$IP_BASE"
GATEWAY="${IP_ARRAY[0]}.${IP_ARRAY[1]}.${IP_ARRAY[2]}.1"

# Get primary interface name
INTERFACE=$(ip route | grep default | awk '{print $5}')
if [ -z "$INTERFACE" ]; then
    # If no default route exists, try to get the first non-loopback interface
    INTERFACE=$(ip -o link show | grep -v lo | awk '{print $2}' | sed 's/://' | head -n 1)

    if [ -z "$INTERFACE" ]; then
        log_error "Could not detect network interface"
        exit 1
    fi
fi

log_info "Detected network interface: $INTERFACE"
log_info "Configuring with IP: $IP_ADDRESS"
log_info "Default gateway: $GATEWAY"

# Create netplan configuration
NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"
log_info "Creating netplan configuration at $NETPLAN_FILE"

# Backup existing configuration if it exists
if [ -f "$NETPLAN_FILE" ]; then
    BACKUP_FILE="$NETPLAN_FILE.backup.$(date +%Y%m%d%H%M%S)"
    cp "$NETPLAN_FILE" "$BACKUP_FILE"
    log_info "Existing netplan configuration backed up to $BACKUP_FILE"
fi

# Create new netplan configuration
cat > "$NETPLAN_FILE" << EOF
# Network configuration created by local-network.sh
# Date: $(date)
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses: [$IP_ADDRESS]
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses: [10.10.10.1]
EOF

# Apply the configuration
log_info "Testing network configuration..."
if netplan try --timeout=30; then
    log_success "Network configuration tested successfully."
    netplan apply
    log_success "Network configuration applied permanently."

    # Verify connection
    log_info "Verifying network connection..."
    if ping -c 3 "$GATEWAY" > /dev/null 2>&1; then
        log_success "Successfully connected to gateway ($GATEWAY)."
    else
        log_warning "Could not reach gateway. Please check your network settings."
    fi

    # Display new IP information
    log_info "Network information:"
    echo -e "IP Address: $(ip -4 addr show "$INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' || echo "$IP_ADDRESS")"
    echo -e "Gateway: $GATEWAY"
    echo -e "DNS Servers: 10.10.10.1"
else
    log_error "Failed to apply network configuration."

    # Restore backup if available
    if [ -f "$BACKUP_FILE" ]; then
        log_info "Restoring previous configuration..."
        cp "$BACKUP_FILE" "$NETPLAN_FILE"
        netplan apply
        log_info "Previous configuration restored."
    fi
    exit 1
fi

log_success "Network configuration completed successfully."