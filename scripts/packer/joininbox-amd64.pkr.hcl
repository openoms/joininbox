
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
  default = "b85286d9855f549ed9895763519f6a295a7698fb9c5c5345811b3eefadfb6f07"
}

variable "iso_checksum_type" {
  type    = string
  default = "sha256"
}

variable "iso_url" {
  type    = string
  default = "https://releases.ubuntu.com/22.04/ubuntu-22.04-desktop-amd64.iso"
}

source "virtualbox-iso" "joininbox-amd64" {
  boot_command     = ["<esc><wait>", "auto ", "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg<wait>", "<enter>"]
  boot_wait        = "5s"
  disk_size        = "16384"
  guest_os_type    = "Ubuntu_64"
  headless         = true
  nested_virt      = true
  http_directory   = "http"
  iso_checksum     = "${var.iso_checksum_type}:${var.iso_checksum}"
  iso_url          = "${var.iso_url}"
  shutdown_command = "echo 'vagrant'|sudo -S shutdown -P now"
  ssh_password     = "vagrant"
  ssh_port         = 22
  ssh_timeout      = "30m"
  ssh_username     = "vagrant"
  vboxmanage       = [["modifyvm", "{{ .Name }}", "--memory", "1024"], ["modifyvm", "{{ .Name }}", "--cpus", "1"]]
  vm_name          = "joininbox-amd64"
}

build {
  sources = ["source.virtualbox-iso.joininbox-amd64"]

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
