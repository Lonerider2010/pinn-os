#!/usr/#!/usr/bin/env bash

# Debian 9 8GB Silicon Valley

# apt-get update &&
apt-get install -y xz-utils libarchive-tools aria2

cd /media/web/projects/common/installation/dietpi/ && mkdir mnt
aria2c -x 4 -s 4  https://dietpi.com/downloads/images/DietPi_RPi5-ARMv8-Bookworm.img.xz
unxz DietPi_RPi5-ARMv8-Bookworm.img.xz

fdisk -l DietPi_RPi5-ARMv8-Bookworm.img
# Start Sector * Sector Size = Below Offsets

# boot tarball
mount -o loop,ro,offset=$((2048*512)) DietPi_RPi5-ARMv8-Bookworm.img mnt
du -h -m --max-depth=0 mnt    #boot uncompressed_tarball_size
cd mnt
bsdtar --numeric-owner --format gnutar -cpf ../boot.tar .
cd .. && umount mnt
xz -T0 -9 -e boot.tar

# root tarball
mount -o loop,ro,offset=$((264192*512)) DietPi_RPi5-ARMv8-Bookworm.img mnt
du -h -m --max-depth=0 mnt    #root uncompressed_tarball_size
cd mnt
cat boot/dietpi/.version   #version = {G_DIETPI_VERSION_CORE}.{G_DIETPI_VERSION_SUB}.{G_DIETPI_VERSION_RC}
bsdtar --numeric-owner --format gnutar --one-file-system -cpf ../root.tar .
cd .. && umount mnt
xz -T0 -9 -e root.tar

echo $(($(wc -c < boot.tar.xz) + $(wc -c < root.tar.xz)))   #os.json download_size

sha512sum boot.tar.xz  #boot sha512sum
sha512sum root.tar.xz  #root sha512sum

# Backup old & Upload new tarballs
# sftp matthuisman@frs.sourceforge.net
cd /media/web/projects/common/installation/dietpi/OS

rm boot.tar.xz.bu
rm root.tar.xz.bu

rename boot.tar.xz  boot.tar.xz.bu
rename root.tar.xz  root.tar.xz.bu

put boot.tar.xz
put root.tar.xz

exit
exit

# UPDATE os.json
# UPDATE partitions.json
