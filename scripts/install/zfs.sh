#!/usr/bin/env nix-shell
#!nix-shell -i bash -p util-linux parted dosfstools git nixos-install-tools zfs gum
# shellcheck shell=bash

# Common variables
INSTALL_MNT="/mnt"

# Strict error handling
set -euo pipefail
IFS=$'\n\t'

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging helpers
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_cmd() { echo -e "${BLUE}[CMD]${NC} $1"; }

# Function to execute or simulate command
execute() {
    local cmd_str
    cmd_str=$(printf '%q ' "$@")
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_cmd "${cmd_str% }"  # Remove trailing space
    else
        log_cmd "${cmd_str% }"  # Remove trailing space
        "$@"
    fi
}

# Function to check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Function to validate disk devices exist
validate_disks() {
    local disks=("$@")
    for disk in "${disks[@]}"; do
        if [[ ! -e "$disk" ]]; then
            log_error "Disk $disk not found"
            exit 1
        fi
    done
}

# Print a beautiful summary of what we're going to do
print_summary() {
    echo
    echo -e "${BLUE}╭───────────────────────────────────────────╮${NC}"
    echo -e "${BLUE}│${NC}           ${GREEN}ZFS Installation Summary${NC}           ${BLUE}│${NC}"
    echo -e "${BLUE}├───────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│${NC} Primary Disk:                              ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   ${YELLOW}$(basename "$DISK1")${NC}   ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} Secondary Disk:                            ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   ${YELLOW}$(basename "$DISK2")${NC}   ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} Hostname: ${YELLOW}$HOSTNAME${NC}                         ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} Mode: ${DRY_RUN:+${YELLOW}DRY RUN${NC}}${DRY_RUN:-${GREEN}LIVE${NC}}                           ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC} Destructive Mode: ${NO_DESTRUCTIVE:+${GREEN}NO${NC}}${NO_DESTRUCTIVE:-${RED}YES${NC}}                     ${BLUE}│${NC}"
    echo -e "${BLUE}├───────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│${NC} Mount Points:                             ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   /mnt:        ${YELLOW}tank/system/root${NC}               ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   /mnt/boot:   ${YELLOW}tank/system/boot${NC}               ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   /mnt/boot/efi: ${YELLOW}${DISK1}-part1${NC}                ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   /mnt/nix:    ${YELLOW}tank/system/nix${NC}                ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   /mnt/nix/store: ${YELLOW}tank/system/nix/store${NC}          ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   /mnt/var:    ${YELLOW}tank/system/var${NC}                ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   /mnt/home:   ${YELLOW}tank/user/home${NC}                ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   /mnt/persist: ${YELLOW}tank/user/persist${NC}             ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   /mnt/tank/vm: ${YELLOW}tank/data/vm${NC}                 ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   /mnt/tank/data: ${YELLOW}tank/data/storage${NC}              ${BLUE}│${NC}"
    echo -e "${BLUE}╰───────────────────────────────────────────╯${NC}"
    echo
}

# Function to confirm destructive action
confirm_destruction() {
    local disks=("$@")
    log_warn "This will DESTROY ALL DATA on the following disks:"
    printf '%s\n' "${disks[@]}"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Dry run mode - no changes will be made"
        return
    fi

    if ! gum confirm --prompt.foreground="#FF0000" "Are you absolutely sure you want to proceed with DESTRUCTIVE actions?" --affirmative="Yes, destroy all data" --negative="No, abort"; then
        log_info "Aborting destructive actions..."
        exit 0
    fi
}

# Function to wipe disks
wipe_disks() {
    log_info "Wiping disks..."
    execute wipefs -af "$DISK1"
    execute wipefs -af "$DISK2"

    log_info "Clearing ZFS labels from disks after wipefs and sgdisk..."
    execute zpool labelclear -f "/dev/disk/by-id/$(basename "$DISK1")" || true # || true to ignore errors if no label
    execute zpool labelclear -f "/dev/disk/by-id/$(basename "$DISK2")" || true # || true to ignore errors if no label

    log_info "Forcefully zapping partition tables with sgdisk..."
    execute sgdisk --zap-all -- "/dev/disk/by-id/$(basename "$DISK1")"
    execute sgdisk --zap-all -- "/dev/disk/by-id/$(basename "$DISK2")"
}

# Function to create partitions
create_partitions() {
    log_info "Creating partitions..."
    
    # Primary disk partitioning
    execute parted -s "$DISK1" -- mklabel gpt
    execute parted -s "$DISK1" -- mkpart ESP fat32 1MiB 1GiB
    execute parted -s "$DISK1" -- set 1 esp on
    execute parted -s "$DISK1" -- mkpart primary 1GiB -32GiB  # Main partition
    execute parted -s "$DISK1" -- mkpart primary -32GiB 100%  # ZIL partition
    
    # Secondary disk partitioning
    execute parted -s "$DISK2" -- mklabel gpt
    execute parted -s "$DISK2" -- mkpart primary 1MiB -500GiB  # Main partition
    execute parted -s "$DISK2" -- mkpart primary -500GiB 100%  # L2ARC partition
    
    # Format ESP
    execute mkfs.fat -F 32 -n BOOT-EFI "${DISK1}-part1"

    # Set default ZIL and L2ARC partitions if not specified
    if [[ -z "${ZIL_PART:-}" ]]; then
        ZIL_PART="${DISK1}-part3"
        log_info "Using default ZIL partition: $ZIL_PART"
    fi

    if [[ -z "${L2ARC_PART:-}" ]]; then
        L2ARC_PART="${DISK2}-part2"
        log_info "Using default L2ARC partition: $L2ARC_PART"
    fi
}

# Function to create and configure ZFS pool
create_zfs_pool() {
    log_info "Creating ZFS pool..."
    
    # Create the pool with base settings that will be inherited by all datasets
    execute zpool create -f \
        -o ashift=12 \
        -O mountpoint=none \
        -O acltype=posixacl \
        -O compression=lz4 \
        -O atime=off \
        -O xattr=sa \
        -O dnodesize=auto \
        -O normalization=formD \
        -O sync=standard \
        -O primarycache=all \
        -O canmount=noauto \
        tank "${DISK1}-part2" "${DISK2}-part1"

    # Explicitly clear ZFS labels from ZIL partition before adding
    log_info "Explicitly clearing ZFS labels from ZIL partition before adding..."
    execute zpool labelclear -f "$ZIL_PART" || true # Clear ZIL partition labels

    # Add ZIL device
    log_info "Adding ZIL device..."
    execute zpool add tank log "$ZIL_PART"

    # Add L2ARC device
    log_info "Adding L2ARC device..."
    execute zpool add tank cache "$L2ARC_PART"
}

# Function to create dataset hierarchy
create_datasets() {
    log_info "Creating dataset hierarchy..."

    # Create parent datasets for categories
    execute zfs create -o mountpoint=none \
        -o recordsize=32K \
        tank/system

    execute zfs create -o mountpoint=none \
        -o recordsize=32K \
        tank/user

    execute zfs create -o mountpoint=none \
        -o recordsize=1M \
        -o logbias=throughput \
        tank/data

    # Root dataset
    execute zfs create -o mountpoint="${INSTALL_MNT}" tank/system/root

    # Nix datasets
    execute zfs create -o mountpoint="${INSTALL_MNT}/nix" tank/system/nix
    execute zfs create -o mountpoint="${INSTALL_MNT}/nix/store" \
        -o recordsize=128K \
        -o logbias=throughput \
        -o secondarycache=all \
        tank/system/nix/store

    # Boot dataset
    execute zfs create -o mountpoint="${INSTALL_MNT}/boot" tank/system/boot

    # Var directory
    execute zfs create -o mountpoint="${INSTALL_MNT}/var" tank/system/var

    # Home directory
    execute zfs create -o mountpoint="${INSTALL_MNT}/home" tank/user/home

    # Fast Directory
    execute zfs create \
        -o mountpoint="${INSTALL_MNT}/fast" \
        -o sync=disabled \
        tank/system/fast

    # Persist directory
    execute zfs create -o mountpoint="${INSTALL_MNT}/persist" tank/user/persist

    # VM dataset - MOUNT UNDER /mnt/tank during installation
    execute zfs create -o mountpoint="${INSTALL_MNT}/tank/vm" \
        -o recordsize=128K \
        -o compression=off \
        -o primarycache=metadata \
        -o secondarycache=none \
        tank/data/vm

    execute zfs create -o mountpoint="${INSTALL_MNT}/var/lib/libvirt/images" \
        -o recordsize=128K \
        -o compression=off \
        -o primarycache=metadata \
        -o secondarycache=none \
        tank/data/vm/libvirt-default

    # General storage - MOUNT UNDER /mnt/tank during installation
    execute zfs create -o mountpoint="${INSTALL_MNT}/tank/data" \
        -o recordsize=1M \
        tank/data/storage
}

automount_off() {
    log_info "Ensuring no automount..."
    execute zfs set canmount=noauto tank/system/root || true
    execute zfs set canmount=noauto tank/system/nix || true
    execute zfs set canmount=noauto tank/system/nix/store || true
    execute zfs set canmount=noauto tank/system/boot || true
    execute zfs set canmount=noauto tank/system/var || true
    execute zfs set canmount=noauto tank/system/fast || true
    execute zfs set canmount=noauto tank/user/home || true
    execute zfs set canmount=noauto tank/user/persist || true
    execute zfs set canmount=noauto tank/data/vm || true
    execute zfs set canmount=noauto tank/data/storage || true
    execute zfs set canmount=noauto tank/data/vm/libvirt-default || true
    log_info "Ensuring no automount completed successfully!"
}

automount_on() {
    log_info "Ensuring automount..."
    execute zfs set canmount=on tank/system/root || true
    execute zfs set canmount=on tank/system/nix || true
    execute zfs set canmount=on tank/system/nix/store || true
    execute zfs set canmount=on tank/system/boot || true
    execute zfs set canmount=on tank/system/var || true
    execute zfs set canmount=on tank/system/fast || true
    execute zfs set canmount=on tank/user/home || true
    execute zfs set canmount=on tank/user/persist || true
    execute zfs set canmount=on tank/data/vm || true
    execute zfs set canmount=on tank/data/storage || true
    execute zfs set canmount=on tank/data/vm/libvirt-default || true
    log_info "Ensuring automount completed successfully!"
}

# We want to ensure that the datasets are not automounted
import_pool() {
    log_info "Importing ZFS pool..."
    execute zpool import -af -N
    log_info "ZFS pool imported successfully!"

    automount_off
}

# Function to verify mount points
verify_mounts() {
    log_info "Verifying mount points..."

    # Define expected mount points and their datasets
    local expected_mounts=(
        "/mnt zfs tank/system/root"
        "/mnt/boot zfs tank/system/boot"
        "/mnt/boot/efi vfat ${DISK1}-part1"
        "/mnt/fast zfs tank/system/fast"
        "/mnt/nix zfs tank/system/nix"
        "/mnt/nix/store zfs tank/system/nix/store"
        "/mnt/var zfs tank/system/var"
        "/mnt/home zfs tank/user/home"
        "/mnt/persist zfs tank/user/persist"
        "/mnt/tank/vm zfs tank/data/vm"
        "/mnt/tank/data zfs tank/data/storage"
        "/mnt/var/lib/libvirt/images zfs tank/data/vm/libvirt-default"
    )

    for mount_info in "${expected_mounts[@]}"; do
        local mnt_point=$(echo "$mount_info" | awk '{print $1}')
        local fs_type=$(echo "$mount_info" | awk '{print $2}')
        local source=$(echo "$mount_info" | awk '{print $3}')

        if ! mountpoint -q "$mnt_point"; then
            log_error "Mount point ${mnt_point} is not mounted!"
            return 1
        fi

        local actual_fs_type=$(findmnt -no FSTYPE "$mnt_point")
        local actual_source=$(findmnt -no SOURCE "$mnt_point")

        if [[ "$actual_fs_type" != "$fs_type" ]]; then
            log_error "Mount point ${mnt_point} has incorrect filesystem type. Expected: ${fs_type}, Actual: ${actual_fs_type}"
            return 1
        fi

        if [[ "$fs_type" == "zfs" ]] && [[ "$actual_source" != "$source" ]]; then
            log_error "Mount point ${mnt_point} has incorrect source. Expected: ${source}, Actual: ${actual_source}"
            return 1
        elif [[ "$fs_type" == "vfat" ]] ; then
            # Resolve /dev/disk/by-id path to canonical /dev/nvme... path for EFI partition
            local expected_source_resolved
            expected_source_resolved=$(readlink -f "$source" 2>/dev/null) || true # Resolve symlink, ignore error if not a symlink
            if [[ -n "$expected_source_resolved" ]]; then
                source="$expected_source_resolved" # Use resolved path for comparison
            fi
            if [[ "$actual_source" != "$source" ]]; then
                log_error "Mount point ${mnt_point} has incorrect source. Expected: ${source}, Actual: ${actual_source}"
                return 1
            fi
        fi
    done

    log_info "All mount points verified successfully!"
    return 0
}

set_install_mountpoints() {
    automount_off

    log_info "Setting install mountpoints..."

    execute zfs set mountpoint="${INSTALL_MNT}" tank/system/root
    execute zfs set mountpoint="${INSTALL_MNT}/nix" tank/system/nix
    execute zfs set mountpoint="${INSTALL_MNT}/nix/store" tank/system/nix/store
    execute zfs set mountpoint="${INSTALL_MNT}/boot" tank/system/boot
    execute zfs set mountpoint="${INSTALL_MNT}/var" tank/system/var
    execute zfs set mountpoint="${INSTALL_MNT}/home" tank/user/home
    execute zfs set mountpoint="${INSTALL_MNT}/fast" tank/system/fast
    execute zfs set mountpoint="${INSTALL_MNT}/persist" tank/user/persist
    execute zfs set mountpoint="${INSTALL_MNT}/tank/vm" tank/data/vm
    execute zfs set mountpoint="${INSTALL_MNT}/tank/data" tank/data/storage
    execute zfs set mountpoint="${INSTALL_MNT}/var/lib/libvirt/images" tank/data/vm/libvirt-default
    log_info "Install mountpoints set successfully!"
}

# Function to mount filesystems
mount_mnt() {
    log_info "Mounting filesystems for installation..."

    set_install_mountpoints

    automount_on

    # Actually mount the zfs filesystems
    execute zfs mount -a
    execute mount

    # Now that we have the zfs filesystems mounted, we can create the EFI mount point and mount it
    execute mkdir -p "${INSTALL_MNT}/boot/efi"
    execute mount -t vfat -o fmask=0077,dmask=0077 "${DISK1}-part1" "${INSTALL_MNT}/boot/efi"
}

# Function to unmount filesystems
unmount_mnt() {
    log_info "Unmounting filesystems..."
    execute umount -l /mnt/boot/efi || true
    execute zfs unmount -fa || true
}

# Function to set runtime mountpoints
set_runtime_mountpoints() {
    automount_off

    log_info "Setting runtime mountpoints..."

    execute zfs set mountpoint=/ tank/system/root
    execute zfs set mountpoint=/nix tank/system/nix
    execute zfs set mountpoint=/nix/store tank/system/nix/store
    execute zfs set mountpoint=/boot tank/system/boot
    execute zfs set mountpoint=/var tank/system/var
    execute zfs set mountpoint=/fast tank/system/fast
    execute zfs set mountpoint=/home tank/user/home
    execute zfs set mountpoint=/persist tank/user/persist
    execute zfs set mountpoint=/tank/vm tank/data/vm
    execute zfs set mountpoint=/tank/data tank/data/storage
    execute zfs set mountpoint=/var/lib/libvirt/images tank/data/vm/libvirt-default
    log_info "Runtime mountpoints set successfully!"
}

# Function to install NixOS
install_nixos() {
    log_info "Installing NixOS..."

    GIT_REPO="${GIT_REPO:-https://github.com/yasinuslu/nepjua.git}"
    GIT_BRANCH="${GIT_BRANCH:-main}"
    FLAKE_PATH="${FLAKE_PATH:-/home/nixos/code/nepjua}"
    HOSTNAME="${HOSTNAME:-kaori}"

    # Create directory and clone repository
    execute mkdir -p "$(dirname "$FLAKE_PATH")"
    execute git clone "$GIT_REPO" "$FLAKE_PATH" || true
    execute git -C "$FLAKE_PATH" checkout "$GIT_BRANCH"

    # Install NixOS using the flake
    execute nixos-install \
        --keep-going \
        --no-channel-copy \
        --root "${INSTALL_MNT}" \
        --flake "$FLAKE_PATH#$HOSTNAME"

    log_info "NixOS installation completed!"
    log_info "Please set root password after first boot"
}

# Function to unmount existing mounts on disks
unmount_disks() {
    local disks=("$@")

    unmount_mnt

    log_info "Unmounting any existing mounts on disks..."
    for disk in "${disks[@]}"; do
        log_info "Trying to unmount partitions on ${disk}..."
        execute umount -l "${disk}-part1" 2>/dev/null || true
        execute umount -l "${disk}-part2" 2>/dev/null || true
        execute umount -l "${disk}-part3" 2>/dev/null || true
        execute umount -l "${disk}-part4" 2>/dev/null || true
        # Add more partitions if you expect more than 4 partitions to be potentially mounted
    done
    log_info "Existing mounts unmounted (if any)."
}

export_zfs() {
    log_info "Exporting ZFS pool..."
    execute zpool export tank
    log_info "ZFS pool exported successfully!"
}

confirm_and_summarize_installation() {
    # Verify mounts before printing summary and asking for confirmation
    if ! verify_mounts; then
        log_error "Mount verification failed. Aborting installation."
        exit 1
    fi

    print_summary

    if ! gum confirm --prompt.foreground="#FF0000" "Do you want to proceed with the installation?" --affirmative="Yes, proceed" --negative="No, abort"; then
        log_info "Aborting installation..."
        exit 0
    fi

    log_info "Proceeding with installation..."
}

# Main script starts here
main() {
    # Check if running as root
    check_root

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --disk1)
                DISK1="$2"
                shift 2
                ;;
            --disk2)
                DISK2="$2"
                shift 2
                ;;
            --zil)
                ZIL_PART="$2"
                shift 2
                ;;
            --l2arc)
                L2ARC_PART="$2"
                shift 2
                ;;
            --git-repo)
                GIT_REPO="$2"
                shift 2
                ;;
            --git-branch)
                GIT_BRANCH="$2"
                shift 2
                ;;
            --hostname)
                HOSTNAME="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-destructive)
                NO_DESTRUCTIVE=true
                shift
                ;;
            --help)
                echo "Usage: $0 [--dry-run] --disk1 /dev/disk/by-id/nvme-Samsung... --disk2 /dev/disk/by-id/nvme-Viper... [--zil /dev/...] [--l2arc /dev/...] [--repo path] [--branch name] [--hostname name]"
                echo
                echo "Options:"
                echo "  --disk1             Primary disk (faster NVMe) for the ZFS pool"
                echo "  --disk2             Secondary disk for the ZFS pool"
                echo "  --zil               ZFS Intent Log partition (recommended)"
                echo "  --l2arc             L2ARC cache partition (optional)"
                echo "  --repo              Path to flake repository (default: /home/nixos/code/nepjua)"
                echo "  --branch            Git branch to use (default: main)"
                echo "  --hostname          NixOS hostname (default: kaori)"
                echo "  --dry-run           Show commands without executing them"
                echo "  --no-destructive    Skip disk wiping, partitioning and ZFS pool creation. Assumes existing ZFS setup."
                echo "  --help              Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown parameter: $1"
                exit 1
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "${DISK1:-}" ]] || [[ -z "${DISK2:-}" ]]; then
        log_error "Both --disk1 and --disk2 are required"
        exit 1
    fi

    [[ "${DRY_RUN:-false}" == "true" ]] && log_info "DRY RUN MODE - Commands will be shown but not executed"

    log_info "Starting ZFS installation..."
    
    # Validate disks exist
    validate_disks "$DISK1" "$DISK2"
    [[ -n "${ZIL_PART:-}" ]] && validate_disks "$ZIL_PART"
    [[ -n "${L2ARC_PART:-}" ]] && validate_disks "$L2ARC_PART"

    # Unmount any existing mounts on the disks
    unmount_disks "$DISK1" "$DISK2"

    # Execute installation steps
    if [[ "${NO_DESTRUCTIVE:-false}" == "false" ]]; then
        # Confirm destruction unless --no-destructive is used
        confirm_destruction "$DISK1" "$DISK2"

        wipe_disks
        create_partitions
        create_zfs_pool
        create_datasets
    else
        log_info "NON-DESTRUCTIVE MODE - Skipping disk wiping, partitioning and ZFS pool creation."

        # This means we are reinstalling on an existing ZFS pool
        # Let's import the pool and ensure no automount is enabled
        import_pool
    fi

    # First mount the filesystems
    mount_mnt

    # Then verify the mount points and get confirmation before installation
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_summary
        log_info "DRY RUN MODE - Commands will be shown but not executed"
    else
        # Perform mount verification and get confirmation before installation
        confirm_and_summarize_installation
    fi

    install_nixos

    unmount_mnt
    set_runtime_mountpoints

    export_zfs

    log_info "Installation completed successfully!"
    log_info "You can now reboot into your new system"
}

# Run main function with all arguments
main "$@" 
