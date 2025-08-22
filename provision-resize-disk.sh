#!/bin/bash
set -euo pipefail

partition_device="$(findmnt -no SOURCE /)"
partition_number="$(echo "$partition_device" | perl -ne '/(\d+)$/ && print $1')"
disk_device="$(echo "$partition_device" | perl -ne '/(.+?)\d+$/ && print $1')"

# resize the partition table.
# Warning: Not all of the space available to /dev/sda appears to be used, you can fix the GPT to use all of the space (an extra 50331648 blocks) or continue with the current setting?
# Fix/Ignore? Fix
# Partition number? 2
# Warning: Partition /dev/sda2 is being used. Are you sure you want to continue?
# Yes/No?
# Yes
# End?  [8589MB]?
# 100%
parted ---pretend-input-tty "$disk_device" <<EOF
resizepart $partition_number 100%
Fix
$partition_number
Yes
100%
EOF

# resize the file system.
resize2fs "$partition_device"
