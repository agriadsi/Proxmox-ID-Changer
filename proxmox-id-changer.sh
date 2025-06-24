#!/usr/bin/env bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Greeting and description
echo -e "${GREEN}Welcome to the VMID change script.${NC}"
echo -e "${YELLOW}This script changes the VMID of a virtual container (lxc) or a QEMU server (qemu).${NC}"
echo

# Select VM Type
echo -e "${YELLOW}Please enter the VM type you want to change (lxc, qemu):${NC}"
read -r VM_TYPE

case "$VM_TYPE" in
  "lxc") VM_TYPE="lxc" ;;
  "qemu") VM_TYPE="qemu-server" ;;
  *)
    echo -e "${RED}Incorrect input. The script is terminated.${NC}"
    exit
    ;;
esac

echo

# Enter old VMID
echo -e "${YELLOW}Please enter the old VMID:${NC}"
read -r OLD_VMID

case $OLD_VMID in
  '' | *[!0-9]*)
    echo -e "${RED}Incorrect input. The script is terminated.${NC}"
    exit
    ;;
  *)
    echo -e "${GREEN}Old VMID: $OLD_VMID${NC}"
    ;;
esac

echo

# Enter a new VMID
echo -e "${YELLOW}Please enter the new VMID:${NC}"
read -r NEW_VMID

case $NEW_VMID in
  '' | *[!0-9]*)
    echo -e "${RED}Incorrect input. The script is terminated.${NC}"
    exit
    ;;
  *)
    echo -e "${GREEN}New VMID: $NEW_VMID${NC}"
    ;;
esac

echo

# Debug output for Logical Volumes
echo -e "${YELLOW}Check logical volumes for VMID $OLD_VMID...${NC}"
lvs_output=$(lvs --noheadings -o lv_name,vg_name)
echo -e "${GREEN}Logical Volumes output:${NC}"
echo "$lvs_output"

# Search for Volume Group
VG_NAME=$(echo "$lvs_output" | grep -E "\b$OLD_VMID\b" | awk '{print $2}' | uniq)

if [ -z "$VG_NAME" ]; then
  echo -e "${YELLOW}No LVM volumes found for VMID $OLD_VMID. Check ZFS volumes...${NC}"
else
  echo -e "${GREEN}Volume Group: $VG_NAME${NC}"
  for volume in $(lvs -a | grep "$VG_NAME" | awk '{print $1}' | grep "$OLD_VMID"); do
    newVolume="${volume//"${OLD_VMID}"/"${NEW_VMID}"}"
    echo -e "${YELLOW}Name the volume $volume to $newVolume now${NC}"
    lvrename "$VG_NAME" "$volume" "$newVolume"
  done
fi

echo -e "${YELLOW}Check ZFS volumes for VMID $OLD_VMID...${NC}"
zfs_output=$(zfs list -t all)
echo -e "${GREEN}ZFS output:${NC}"
echo "$zfs_output"

# Rename ZFS volumes
for volume in $(echo "$zfs_output" | awk '{print $1}' | grep -E "vm-${OLD_VMID}-disk|subvol-${OLD_VMID}-disk"); do
  newVolume="${volume//"${OLD_VMID}"/"${NEW_VMID}"}"
  echo -e "${YELLOW}Name ZFS volume $volume to $newVolume now${NC}"
  zfs rename "$volume" "$newVolume"
done

echo -e "${YELLOW}Update configuration files...${NC}"
sed -i "s/$OLD_VMID/$NEW_VMID/g" /etc/pve/"$VM_TYPE"/"$OLD_VMID".conf
mv /etc/pve/"$VM_TYPE"/"$OLD_VMID".conf /etc/pve/"$VM_TYPE"/"$NEW_VMID".conf

echo -e "${GREEN}Done!${NC}"
