packer {
  required_plugins {
    xenserver= {
      version = ">= v0.5.2"
      source = "github.com/ddelnano/xenserver"
    }
  }
}

# The ubuntu_version value determines what Ubuntu iso URL and sha256 hash we lookup. Updating
# this will allow a new version to be pulled in.
data "null" "ubuntu_version" {
  input = "22.04"
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
  ubuntu_version = data.null.ubuntu_version.output

  # Update this map to support future releases. At this time, the Ubuntu
  # jammy template is not available yet.
  ubuntu_template_name = {
    22.04 = "Ubuntu Jammy Jellyfish 22.04"
  }
}

# TODO(ddelnano): Update this to use a local once https://github.com/hashicorp/packer/issues/11011
# is fixed.
data "http" "ubuntu_sha_and_release" {
  url = "https://releases.ubuntu.com/${data.null.ubuntu_version.output}/SHA256SUMS"
}

local "ubuntu_sha256" {
  expression = regex("([A-Za-z0-9]+)[\\s\\*]+ubuntu-.*server", data.http.ubuntu_sha_and_release.body)
}

local "ubuntu_url_path" {
  expression = regex("[A-Za-z0-9]+[\\s\\*]+ubuntu-${local.ubuntu_version}.(\\d+)-live-server-amd64.iso", data.http.ubuntu_sha_and_release.body)
}

variable "remote_host" {
  type        = string
  description = "The ip or fqdn of your XenServer. This will be pulled from the env var 'PKR_VAR_XAPI_HOST'"
  sensitive   = true
  default     = null
}

variable "remote_password" {
  type        = string
  description = "The password used to interact with your XenServer. This will be pulled from the env var 'PKR_VAR_XAPI_PASSWORD'"
  sensitive   = true
  default     = null
}

variable "remote_username" {
  type        = string
  description = "The username used to interact with your XenServer. This will be pulled from the env var 'PKR_VAR_XAPI_USERNAME'"
  sensitive   = true
  default     = null

}

variable "sr_iso_name" {
  type        = string
  default     = ""
  description = "The ISO-SR to packer will use"

}

variable "sr_name" {
  type        = string
  default     = ""
  description = "The name of the SR to packer will use"
}

source "xenserver-iso" "ubuntu-2204" {
  iso_checksum      = "sha256:${local.ubuntu_sha256[0]}"
  iso_url           = "https://releases.ubuntu.com/${local.ubuntu_version}/ubuntu-${local.ubuntu_version}.${local.ubuntu_url_path[0]}-live-server-amd64.iso"

  sr_iso_name    = var.sr_iso_name
  sr_name        = var.sr_name
  tools_iso_name = "guest-tools.iso"

  remote_host     = var.remote_host
  remote_password = var.remote_password
  remote_username = var.remote_username

  # Change this to match the ISO of ubuntu you are using in the iso_url variable
  clone_template = local.ubuntu_template_name[data.null.ubuntu_version.output]
  # vm_name        = "packer-ubuntu-${data.null.ubuntu_version.output}-${local.timestamp}"
  vm_name        = "TF-PACKER-UBUNTU-${data.null.ubuntu_version.output}"
  vm_description = "Packer: Build started: ${local.timestamp}"
  vm_memory      = 4096
  disk_size      = 30720

  http_directory = "examples/http/ubuntu-2204"

  boot_wait = "5m"
  # boot_wait = "5s"
  boot_command    = [
    "<home><up><enter><down><down><down><enter><wait>",
    "mkdir /root/auto-i<enter>",
    "touch /root/auto-i/meta-data<enter>",
    "git clone https://github.com/ON8RU/packer-plugin-xenserver.git /tmp/packer-plugin-xenserver<enter>",
    "cp /tmp/packer-plugin-xenserver/examples/http/ubuntu-2204/user-data /root/auto-i/user-data",
    # "linux /casper/vmlinuz autoinstall quiet \"ds=nocloud;s=/root/autoinstall\" ---",
    # "<enter><wait>",
    # "initrd /casper/initrd<enter><wait>",
    # "boot<enter>"
  ]

  //https://github.com/ON8RU/packer-plugin-xenserver.git

  # boot_command = [
  #   "<wait>",
  #   "c",
  #   "<wait>",
  #   "linux /casper/vmlinuz quiet autoinstall \"ds=nocloud;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\" ---",
  #   "<enter><wait>",
  #   "initrd /casper/initrd ",
  #   "<enter><wait>",
  #   "boot",
  #   "<enter><wait>",
  # ]

  vm_tags        = [
    "ubuntu22",
    "packer"
  ]

  # floppy_files = [
  #   "examples/http/ubuntu-2204/meta-data",
  #   "examples/http/ubuntu-2204/user-data",
  # ]

  ssh_username            = "testuser"
  ssh_password            = "ubuntu"
  ssh_wait_timeout        = "60000s"
  ssh_handshake_attempts  = 10000

  output_directory = "packer-ubuntu-2204-iso"
  keep_vm          = "always"
}

build {
  sources = ["xenserver-iso.ubuntu-2204"]
}
