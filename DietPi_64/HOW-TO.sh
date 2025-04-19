#!/usr/bin/env bash

# Define variables
name="DietPi_64"
description="Highly optimized minimal Debian OS (ARMv8 64-bit Bullseye)"
url="http://dietpi.com/"
group="Minimal"
username="root"
password="dietpi"
supports_backup=true
dietpi_url="${url}/downloads/images/"

install_dir="/media/web/repos/gitlab/intern/Foundation/dietpi/Software/"
dietpi_img="DietPi_RPi5-ARMv8-Bookworm.img"
boot_tar="boot.tar"
root_tar="root.tar"

apt-get update && apt-get install -y xz-utils libarchive-tools aria2

# Download image
cd ${install_dir} || exit
aria2c -x 4 -s 4 -R ${dietpi_url}/${dietpi_img}.xz
release_date=$(date -r ${dietpi_img}.xz +"%Y-%m-%d")
unxz ${dietpi_img}.xz

fdisk -l ${dietpi_img}
{ read boot_size; read root_size; } <<<  "$(fdisk -l DietPi_RPi5-ARMv8-Bookworm.img -o Size | tail -2)"

loop_dev=$(losetup --find --show --partscan DietPi_RPi5-ARMv8-Bookworm.img)

# Boot tarball
mount "${loop_dev}"p1 boot
b_uncompressed_tarball_size=$(du -h -m --max-depth=0 boot | cut -f1)    #boot uncompressed_tarball_size
cd boot || exit
bsdtar --numeric-owner --format gnutar -cpf ../${boot_tar} .
cd .. && umount boot
xz -T0 -9 -e ${boot_tar}

# Root tarball
mount "${loop_dev}"p2 root
r_uncompressed_tarball_size=$(du -h -m --max-depth=0 root | cut -f1)    #root uncompressed_tarball_size
cd root || exit
bsdtar --numeric-owner --format gnutar --one-file-system -cpf ../${root_tar} .
. boot/dietpi/.version   #version = {G_DIETPI_VERSION_CORE}.{G_DIETPI_VERSION_SUB}.{G_DIETPI_VERSION_RC}
core=${G_DIETPI_VERSION_CORE}
sub=${G_DIETPI_VERSION_SUB}
rc=${G_DIETPI_VERSION_RC}
version="${core}.${sub}.${rc}"

cd .. && umount root
xz -T0 -9 -e ${root_tar}

download_size=$(($(wc -c < ${boot_tar}.xz) + $(wc -c < ${root_tar}.xz)))   #os.json download_size

b_sha512sum=$(sha512sum ${boot_tar}.xz | cut -d " " -f1)  #boot sha512sum
r_sha512sum=$(sha512sum ${root_tar}.xz | cut -d " " -f1)  #root sha512sum

losetup -D ${loop_dev}

# Data for os.json
image_string=$(jq -n \
    --arg name "$name" \
    --arg version "$version" \
    --arg release_date "$release_date" \
    --arg description "$description" \
    --arg url "$url" \
    --arg group "$group" \
    --arg username "$username" \
    --arg password "$password" \
    --arg supports_backup "$supports_backup" \
    --arg download_size "$download_size" \
    '{name: $name, version: $version, release_date: $release_date, \
      description: $description, url: $url, group: $group, username: $username, \
      password: $password, supports_backup: $supports_backup, \
      download_size: $download_size}')
echo "$image_string"

# Data for partitions.json
echo -e "\nBoot partition\n=============="
echo "label: boot"
echo "filesystem_type: FAT"
echo "partition_size_nominal: ${boot_size::-1}"
echo "want_maximised: false"
echo "uncompressed_tarball_size: ${b_uncompressed_tarball_size}"
echo "sha512sum: ${b_sha512sum}"
echo -e "\nRoot partition\n=============="
echo "label: root"
echo "filesystem_type: ext4"
echo "partition_size_nominal: ${root_size::-1}"
echo "want_maximised: true"
echo "mkfs_options: -O ^huge_file"
echo "uncompressed_tarball_size: ${r_uncompressed_tarball_size}"
echo "sha512sum: ${r_sha512sum}"
