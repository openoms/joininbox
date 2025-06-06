variable "github_user" {}
variable "branch" {}

source "arm" "joininbox-arm64-rpi" {
  file_checksum_type    = "sha256"
  file_checksum         = "62d025b9bc7ca0e1facfec74ae56ac13978b6745c58177f081d39fbb8041ed45"
  file_target_extension = "xz"
  file_unarchive_cmd    = ["xz", "--decompress", "$ARCHIVE_PATH"]
  file_urls             = ["https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-05-13/2025-05-13-raspios-bookworm-arm64-lite.img.xz"]
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
  qemu_binary_destination_path = "/usr/bin/qemu-aarch64-static"
  qemu_binary_source_path      = "/usr/bin/qemu-aarch64-static"
}

build {
  sources = ["source.arm.joininbox-arm64-rpi"]

  provisioner "shell" {
    inline = [
      "echo 'nameserver 1.1.1.1' >/etc/resolv.conf",
      "echo 'nameserver 8.8.8.8' >>/etc/resolv.conf",
      "echo $(hostname -I | awk '{print $1}')       $(hostname) >>/etc/hosts",
      "echo 127.0.1.1       $(hostname) >>/etc/hosts",
      "echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections",
      "apt-get update",
      "apt-get install -y sudo wget",
      "apt-get -y autoremove",
      "apt-get -y clean",
    ]
  }

  provisioner "shell" {
    environment_vars = [
      "github_user=${var.github_user}",
      "branch=${var.branch}"
    ]
    script = "./joininbox.sh"
  }

}
