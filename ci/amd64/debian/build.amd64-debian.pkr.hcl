# images, checksums and signatures are at:
# https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/
variable "iso_name" { default = "debian-13.3.0-amd64-netinst.iso" }
variable "iso_checksum" { default = "c9f09d24b7e834e6834f2ffa565b33d6f1f540d04bd25c79ad9953bc79a8ac02" }

variable "github_user" { default = "openoms" }
variable "branch" { default = "master" }

variable "boot" { default = "uefi" }
variable "preseed_file" { default = "preseed.cfg" }
variable "hostname" { default = "joininbox-amd64" }

variable "image_size" { default = "30000" }
variable "image_type" { default = "qcow2" }

variable "memory" { default = "2048" }
variable "cpus" { default = "2" }

locals {
  name_template   = "joininbox-amd64-debian"
  image_extension = var.image_type == "raw" ? "img" : var.image_type
  bios_file       = var.boot == "uefi" ? "OVMF.fd" : "bios-256k.bin"
  boot_command = var.boot == "uefi" ? [
    "<wait><wait><wait>c<wait><wait><wait>",
    "linux /install.amd/vmlinuz ",
    "auto=true ",
    "url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.preseed_file} ",
    "hostname=${var.hostname} ",
    "domain=${var.hostname}.local ",
    "interface=auto ",
    "vga=788 noprompt quiet --<enter>",
    "initrd /install.amd/initrd.gz<enter>",
    "boot<enter>"
    ] : [
    "<esc><wait>install <wait>",
    "<wait><wait><wait><wait><wait><wait><wait><wait><wait><wait><wait><wait><wait><wait><wait><wait> preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/${var.preseed_file} <wait>",
    "debian-installer=en_US.UTF-8 <wait>",
    "auto <wait>",
    "locale=en_US.UTF-8 <wait>",
    "kbd-chooser/method=us <wait>",
    "keyboard-configuration/xkb-keymap=us <wait>",
    "netcfg/get_hostname=${var.hostname} <wait>",
    "netcfg/get_domain=${var.hostname}.local <wait>",
    "fb=false <wait>",
    "debconf/frontend=noninteractive <wait>",
    "console-setup/ask_detect=false <wait>",
    "console-keymaps-at/keymap=us <wait>",
    "grub-installer/bootdev=default <wait>",
    "<enter><wait>"
  ]
}

source "qemu" "debian" {
  boot_command     = local.boot_command
  boot_wait        = "5s"
  cpus             = var.cpus
  disk_size        = var.image_size
  http_directory   = "./http"
  iso_checksum     = var.iso_checksum
  iso_url          = "https://cdimage.debian.org/cdimage/release/current/amd64/iso-cd/${var.iso_name}"
  memory           = var.memory
  output_directory = "../builds/${local.name_template}-qemu"
  shutdown_command = "echo 'joininbox' | sudo /sbin/shutdown -hP now"
  ssh_password     = "joininbox"
  ssh_port         = 22
  ssh_timeout      = "10000s"
  ssh_username     = "joinmarket"
  format           = var.image_type
  vm_name          = "${local.name_template}.${local.image_extension}"
  headless         = false
  vnc_bind_address = "127.0.0.1"
  vnc_port_max     = 5900
  vnc_port_min     = 5900
  qemuargs = [
    ["-m", var.memory],
    ["-bios", local.bios_file],
    ["-display", "none"]
  ]
}

build {
  description = "JoininBox amd64 Debian image build"
  sources     = ["source.qemu.debian"]

  provisioner "shell" {
    environment_vars = [
      "HOME_DIR=/home/joinmarket",
      "github_user=${var.github_user}",
      "branch=${var.branch}"
    ]

    execute_command   = "echo 'joininbox' | {{.Vars}} sudo -S -E sh -eux '{{.Path}}'"
    expect_disconnect = true
    scripts = [
      "./scripts/update.sh",
      "./../_common/sshd.sh",
      "./scripts/networking.sh",
      "./scripts/sudoers.sh",
      "./scripts/systemd.sh",
      "./scripts/joininbox.sh",
      "./scripts/cleanup.sh"
    ]
  }
}

packer {
  required_version = ">= 1.7.0, < 2.0.0"

  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.0.0, < 2.0.0"
    }
  }
}
