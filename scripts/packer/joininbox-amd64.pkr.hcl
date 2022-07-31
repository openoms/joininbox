variable "ssh_password" {
  type    = string
  default = "debian"
}

variable "ssh_username" {
  type    = string
  default = "debian"
}

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
  iso_checksum   = "${var.iso_checksum_type}:${var.iso_checksum}"
  iso_url        = "${var.iso_url}"
  disk_size      = "16384"
  format         = "qcow2"
  ssh_timeout    = "30m"
  vm_name        = "joininbox-amd64"
  net_device     = "virtio-net"
  disk_interface = "virtio"
  boot_wait      = "1s"
  boot_command=  "<esc><wait>install <wait> preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/{{user `preseed_path`}} <wait>debian-installer=en_US.UTF-8 <wait>auto <wait>locale=en_US.UTF-8 <wait>kbd-chooser/method=us <wait>keyboard-configuration/xkb-keymap=us <wait>netcfg/get_hostname={{ .Name }} <wait>netcfg/get_domain=vagrantup.com <wait>fb=false <wait>debconf/frontend=noninteractive <wait>console-setup/ask_detect=false <wait>console-keymaps-at/keymap=us <wait>grub-installer/bootdev=default <wait><enter><wait>",
  headless    = false
  accelerator = "tcg"
  # Serve the `http` directory via HTTP, used for preseeding the Debian installer.
  http_directory = "http"
  http_port_min  = 9990
  http_port_max  = 9999
  # SSH ports to redirect to the VM being built
  host_port_min = 2222
  host_port_max = 2229
  # This user is configured in the preseed file.
  ssh_password     = "${var.ssh_password}"
  ssh_username     = "${var.ssh_username}"
  ssh_wait_timeout = "1000s"
  qemuargs = [
    ["--no-acpi", ""]
  ]
  shutdown_command = "echo '${var.ssh_password}'  | sudo -S /sbin/shutdown -hP now"
  # Builds a compact image
  disk_compression   = true
  disk_discard       = "unmap"
  skip_compaction    = false
  disk_detect_zeroes = "unmap"
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

  post-processor "checksum" {
    checksum_types      = ["sha256"]
    output              = "{{.BuildName}}.qcow2.{{.ChecksumType}}"
    keep_input_artifact = true
  }
}
