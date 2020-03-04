#!/bin/ksh
SIZE=6442
LUN=`fdisk -l |grep Disk |grep $SIZE |awk -F: {'print $1'} |awk {'print $2'}`

sfdisk $LUN < /var/tmp/besdisk.layout
pvcreate "$LUN"1
vgextend appvg "$LUN"1
lvcreate -L 5G -n besclientlv appvg
mkfs.ext4 /dev/appvg/besclientlv
cp /etc/fstab /etc/fstab.`date +%m%d%Y.%H:%M`
echo "/dev/appvg/besclientlv    /var/opt/BESClient    ext4    defaults   1 2" >> /etc/fstab
mkdir /var/opt/BESClient
mount /var/opt/BESClient
