#!/usr/bin/env bash

# Debian 9 8GB Silicon Valley

# define variables
install_dir="/media/web/repos/gitlab/intern/Foundation/dietpi/Software/"
dietpi_url="https://dietpi.com/downloads/images/"
dietpi_img="DietPi_RPi5-ARMv8-Bookworm.img"
boot_tar="boot.tar"
root_tar="root.tar"

apt-get update && apt-get install -y xz-utils libarchive-tools aria2

cd ${install_dir} || exit
aria2c -x 4 -s 4 ${dietpi_url}/${dietpi_img}.xz
unxz ${dietpi_img}.xz

fdisk -l ${dietpi_img}
# Start Sector * Sector Size = Below Offsets

loop_dev=$(losetup --find --show --partscan DietPi_RPi5-ARMv8-Bookworm.img)

# boot tarball
mount "${loop_dev}"p1 boot
du -h -m --max-depth=0 boot    #boot uncompressed_tarball_size
cd boot || exit
bsdtar --numeric-owner --format gnutar -cpf ../${boot_tar} .
cd .. && umount boot
xz -T0 -9 -e ${boot_tar}

# root tarball
mount "${loop_dev}"p2 root
du -h -m --max-depth=0 root    #root uncompressed_tarball_size
cd root || exit
bsdtar --numeric-owner --format gnutar --one-file-system -cpf ../${root_tar} .
cat boot/dietpi/.version   #version = {G_DIETPI_VERSION_CORE}.{G_DIETPI_VERSION_SUB}.{G_DIETPI_VERSION_RC}
cd .. && umount root
xz -T0 -9 -e ${root_tar}

echo $(($(wc -c < ${boot_tar}.xz) + $(wc -c < ${root_tar}.xz)))   #os.json download_size

sha512sum ${boot_tar}.xz  #boot sha512sum
sha512sum ${root_tar}.xz  #root sha512sum

losetup -D ${loop_dev}
# UPDATE os.json
# UPDATE partitions.json
