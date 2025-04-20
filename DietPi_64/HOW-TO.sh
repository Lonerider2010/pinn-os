#!/usr/bin/env bash

# Define variables
name="DietPi_64"
description="Highly optimized minimal Debian OS (ARMv8 64-bit Bookworm)"
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

# Install packages needed
apt-get update && apt-get install -y xz-utils libarchive-tools aria2

# Download and unpack image
cd ${install_dir} || exit
aria2c -x 4 -s 4 -R ${dietpi_url}/${dietpi_img}.xz
release_date=$(date -r ${dietpi_img}.xz +"%Y-%m-%d")
unxz ${dietpi_img}.xz

# Get partition sizes
fdisk -l ${dietpi_img}
{ read boot_size; read root_size; } <<<  "$(fdisk -l DietPi_RPi5-ARMv8-Bookworm.img -o Size | tail -2)"
boot_size_v=${boot_size::-1}
boot_size_i=$(echo $boot_size_v | cut -d "," -f1)
boot_size_p="$(($boot_size_i + 100))"
root_size_v=${root_size::-1}
root_size_i=$(echo $root_size_v | cut -d "," -f1)
root_size_p="$(($root_size_i * 2))"

# Mount loop device
loop_dev=$(losetup --find --show --partscan DietPi_RPi5-ARMv8-Bookworm.img)

# Boot tarball
mount "${loop_dev}"p1 boot
b_uncompressed_tarball_size=$(du -h -m --max-depth=0 boot | cut -f1)    #boot uncompressed_tarball_size
cd boot || exit
bsdtar --numeric-owner --format gnutar -cpf ../${boot_tar} .
cd .. && umount boot
xz -T1 -9 -e ${boot_tar} # T1 due to Raspi

# Root tarball
mount "${loop_dev}"p2 root
r_uncompressed_tarball_size=$(du -h -m --max-depth=0 root | cut -f1)    #root uncompressed_tarball_size
cd root || exit
bsdtar --numeric-owner --format gnutar --one-file-system -cpf ../${root_tar} .

# Get DietPi version
. boot/dietpi/.version   #version = {G_DIETPI_VERSION_CORE}.{G_DIETPI_VERSION_SUB}.{G_DIETPI_VERSION_RC}
core=${G_DIETPI_VERSION_CORE}
sub=${G_DIETPI_VERSION_SUB}
rc=${G_DIETPI_VERSION_RC}
version="v${core}.${sub}.${rc}"

cd .. && umount root
xz -T1 -9 -e ${root_tar} # T1 due to Raspi

# Get meta data
download_size=$(($(wc -c < ${boot_tar}.xz) + $(wc -c < ${root_tar}.xz)))   #os.json download_size
b_sha512sum=$(sha512sum ${boot_tar}.xz | cut -d " " -f1)  #boot sha512sum
r_sha512sum=$(sha512sum ${root_tar}.xz | cut -d " " -f1)  #root sha512sum

# Unmount loop device
losetup -D ${loop_dev}

# Create os.json
supported_models=(
  "Pi Zero 2 W" \
  "Pi Compute Module 3" \
  "Pi Compute Module 4" \
  "Pi 3" \
  "Pi 4" \
  "Pi 5"
)
image_string=$(jq -n --indent 4 \
    --arg name "$name" \
    --arg version "$version" \
    --arg release_date "$release_date" \
    --arg description "$description" \
    --arg url "$url" \
    --arg group "$group" \
    --arg username "$username" \
    --arg password "$password" \
    --argjson supports_backup "$supports_backup" \
    --argjson download_size "$download_size" \
    --argjson supported_models "$(jq -n '$ARGS.positional' --args "${supported_models[@]}")" \
    '{
        name: $name,
        version: $version,
        release_date: $release_date,
        description: $description,
        url: $url,
        group: $group,
        username: $username,
        password: $password,
        supports_backup: $supports_backup,
        download_size: $download_size,
        supported_models: $supported_models
      }')
echo "$image_string" | tee os.json

# Create partitions.json
partition_string=$(jq -n --indent 2 \
    --arg b_label "boot" \
    --arg b_filesystem_type "FAT" \
    --argjson b_partition_size_nominal "${boot_size_p}" \
    --argjson b_want_maximised "false" \
    --argjson b_uncompressed_tarball_size "$b_uncompressed_tarball_size" \
    --arg b_sha512sum "$b_sha512sum" \
    --arg r_label "root" \
    --arg r_filesystem_type "ext4" \
    --argjson r_partition_size_nominal "${root_size_p}" \
    --argjson r_want_maximised "true" \
    --arg r_mkfs_options "-O ^huge_file" \
    --argjson r_uncompressed_tarball_size "${r_uncompressed_tarball_size}" \
    --arg r_sha512sum "$r_sha512sum" \
    '
    {
      "partitions": [
        {
          "label": $b_label,
          "filesystem_type": $b_filesystem_type,
          "partition_size_nominal": $b_partition_size_nominal,
          "want_maximised": $b_want_maximised,
          "uncompressed_tarball_size": $b_uncompressed_tarball_size,
          "sha512sum": $b_sha512sum
        },
        {
          "label": $r_label,
          "filesystem_type": $r_filesystem_type,
          "partition_size_nominal": $r_partition_size_nominal,
          "want_maximised": $r_want_maximised,
          "mkfs_options": $r_mkfs_options,
          "uncompressed_tarball_size": $r_uncompressed_tarball_size,
          "sha512sum": $r_sha512sum
        }
      ]
     }')
echo "$partition_string" | tee partitions.json
