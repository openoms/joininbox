
source "arm" "joininbox-arm64-rpi" {
  file_checksum_type    = "sha256"
  file_checksum_url     = "https://raspi.debian.net/tested/20220121_raspi_4_bullseye.img.xz.sha256"
  file_target_extension = "xz"
  file_unarchive_cmd    = ["xz", "--decompress", "$ARCHIVE_PATH"]
  file_urls             = ["https://raspi.debian.net/tested/20220121_raspi_4_bullseye.img.xz"]
  image_build_method    = "resize"
  image_chroot_env      = ["PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin"]
  image_partitions {
    filesystem   = "vfat"
    mountpoint   = "/boot"
    name         = "boot"
    size         = "256M"
    start_sector = "8192"
    type         = "c"
  }
  image_partitions {
    filesystem   = "ext4"
    mountpoint   = "/"
    name         = "root"
    size         = "0"
    start_sector = "532480"
    type         = "83"
  }
  image_path                   = "joininbox-arm64-rpi.img"
  image_size                   = "8G"
  image_type                   = "dos"
  qemu_binary_destination_path = "/usr/bin/qemu-arm-static"
  qemu_binary_source_path      = "/usr/bin/qemu-arm-static"
}

build {
  sources = ["source.arm.joininbox-arm64-rpi"]

  provisioner "file" {
    source      = "scripts/resizerootfs"
    destination = "/tmp"
  }

  provisioner "shell" {
    script = "scripts/bootstrap_resizerootfs.sh"
  }

  provisioner "shell" {
    inline = [
      "echo 'nameserver 1.1.1.1' > /etc/resolv.conf",
      "echo 'nameserver 8.8.8.8' >> /etc/resolv.conf",
      "echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections",
      "apt-get update",
      "apt-get upgrade -y",
      "apt-get install -y sudo wget",
      "apt-get -y autoremove",
      "apt-get -y clean",
    ]
  }

  provisioner "shell" {
    script = "build_joininbox.sh"
  }

  provisioner "shell" {
    inline = [
      "echo '# Deleting the SSH pub keys (will be recreate on the first boot) ...'",
      "rm /etc/ssh/ssh_host_*",
      "echo 'OK'",
    ]
  }
}
