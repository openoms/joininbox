
variable "branch" {
  type    = string
  default = "packer"
}

variable "github_user" {
  type    = string
  default = "openoms"
}

variable "iso_checksum" {
  type    = string
  default = "eeab770236777e588f6ce0f984a7f3e85d86295625010e78a0fca3e873f78188af7966b53319dde3ddcaaaa5d6b9c803e4d80470755e75796fbf0e96c973507f"
}

variable "iso_checksum_type" {
  type    = string
  default = "sha512"
}

variable "iso_url" {
  type    = string
  default = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-11.4.0-amd64-netinst.iso"
}

source "qemu" "joininbox-amd64" {
  iso_checksum     = "${var.iso_checksum_type}:${var.iso_checksum}"
  iso_url          = "${var.iso_url}"
  disk_size        = "16384"
  format           = "qcow2"
  accelerator      = "kvm"
  http_directory   = "http"
  shutdown_command = "echo 'joinmarket' | sudo -S shutdown -P now"
  ssh_username     = "joinmarket"
  ssh_password     = "joininbox"
  ssh_timeout      = "30m"
  vm_name          = "joininbox-amd64"
  net_device       = "virtio-net"
  disk_interface   = "virtio"
  boot_wait        = "10s"
  boot_command     = ["<esc><wait>", "auto ", "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<wait>", "<enter>"]
  headless         = true
}

build {
  sources = ["source.qemu.joininbox-amd64"]

  provisioner "shell" {
    inline = ["echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections"]
  }

  provisioner "shell" {
    inline = ["echo -e 'nameserver 8.8.8.8\nnameserver 8.8.4.4' | tee -a /etc/resolv.conf"]
  }

  provisioner "shell" {
    inline = ["apt-get update -y", "apt-get upgrade -y", "apt-get install -y sudo wget"]
  }

  provisioner "shell" {
    script = "../../build_joininbox.sh"
  }

  post-processor "compress" {
    compression_level = 9
    output            = "{{.BuildName}}.tar.gz"
  }

  post-processor "checksum" {
    checksum_types      = ["sha256"]
    output              = "{{.BuildName}}.tar.gz.{{.ChecksumType}}"
    keep_input_artifact = true
  }
}
