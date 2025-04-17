#!/usr/bin/env bash

# Debian 9 8GB Silicon Valley

# define variables
INSTALL_DIR="/media/web/repos/gitlab/intern/Projects/dietpi/Software/"
DIETPI_URL="https://dietpi.com/downloads/images/"
DIETPI_IMG="DietPi_RPi5-ARMv8-Bookworm.img"
BOOT_TAR="boot.tar"
ROOT_TAR="root.tar"
BOOT_START="2048"
ROOT_START="264192"

# apt-get update &&
apt-get install -y xz-utils libarchive-tools aria2

cd ${INSTALL_DIR} || exit
mkdir mnt
aria2c -x 4 -s 4 ${DIETPI_URL}/${DIETPI_IMG}.xz
unxz ${DIETPI_IMG}.xz

fdisk -l ${DIETPI_IMG}
# Start Sector * Sector Size = Below Offsets

# boot tarball
mount -o loop,ro,offset=$((${BOOT_START}*512)) ${DIETPI_IMG} mnt
du -h -m --max-depth=0 mnt    #boot uncompressed_tarball_size
cd mnt || exit
bsdtar --numeric-owner --format gnutar -cpf ../${BOOT_TAR} .
cd .. && umount mnt
xz -T0 -9 -e ${BOOT_TAR}

# root tarball
mount -o loop,ro,offset=$((${ROOT_START}*512)) ${DIETPI_IMG} mnt
du -h -m --max-depth=0 mnt    #root uncompressed_tarball_size
cd mnt || exit
cat boot/dietpi/.version   #version = {G_DIETPI_VERSION_CORE}.{G_DIETPI_VERSION_SUB}.{G_DIETPI_VERSION_RC}
bsdtar --numeric-owner --format gnutar --one-file-system -cpf ../${ROOT_TAR} .
cd .. && umount mnt
xz -T0 -9 -e ${ROOT_TAR}

echo $(($(wc -c < ${BOOT_TAR}.xz) + $(wc -c < ${ROOT_TAR}.xz)))   #os.json download_size

sha512sum ${BOOT_TAR}.xz  #boot sha512sum
sha512sum ${ROOT_TAR}.xz  #root sha512sum

# Backup old & Upload new tarballs
# sftp matthuisman@frs.sourceforge.net
cd ${INSTALL_DIR}/OS || exit

rm $BOOT_TAR.xz.bu
rm $ROOT_TAR.xz.bu

rename $BOOT_TAR.xz  $BOOT_TAR.xz.bu
rename $ROOT_TAR.xz  $ROOT_TAR.xz.bu

put $BOOT_TAR.xz
put $ROOT_TAR.xz

exit
exit

# UPDATE os.json
# UPDATE partitions.json
