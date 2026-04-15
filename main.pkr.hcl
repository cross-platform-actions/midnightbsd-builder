variable "os_version" {
  type        = string
  description = "The version of the operating system to download and install"
}

variable "architecture" {
  type = object({
    name  = string
    image = string
    qemu  = string
  })
  description = "The type of CPU to use when building"
}

variable "machine_type" {
  default     = "pc"
  type        = string
  description = "The type of machine to use when building"
}

variable "cpu_type" {
  default     = "qemu64"
  type        = string
  description = "The type of CPU to use when building"
}

variable "memory" {
  default     = 4096
  type        = number
  description = "The amount of memory to use when building the VM in megabytes"
}

variable "cpus" {
  default     = 2
  type        = number
  description = "The number of cpus to use when building the VM"
}

variable "disk_size" {
  default     = "12G"
  type        = string
  description = "The size in bytes of the hard disk of the VM"
}

variable "checksum" {
  type        = string
  description = "The checksum for the virtual hard drive file"
}

variable "root_password" {
  default     = "runner"
  type        = string
  description = "The password for the root user"
}

variable "secondary_user_username" {
  default     = "runner"
  type        = string
  description = "The name for the secondary user"
}

variable "headless" {
  default     = false
  description = "When this value is set to `true`, the machine will start without a console"
}

variable "use_default_display" {
  default     = true
  type        = bool
  description = "If true, do not pass a -display option to qemu, allowing it to choose the default"
}

variable "display" {
  default     = "cocoa"
  description = "What QEMU -display option to use"
}

locals {
  image   = "MidnightBSD-${var.os_version}--${var.architecture.image}-disc1.iso"
  vm_name = "midnightbsd-${var.os_version}-${var.architecture.name}.qcow2"
}

source "qemu" "qemu" {
  machine_type = var.machine_type
  cpus         = var.cpus
  memory       = var.memory
  net_device   = "virtio-net"

  disk_compression = true
  disk_interface   = "virtio"
  disk_size        = var.disk_size
  format           = "qcow2"

  headless            = var.headless
  use_default_display = var.use_default_display
  display             = var.display
  accelerator         = "none"
  qemu_binary         = "qemu-system-${var.architecture.qemu}"

  boot_wait = "2s"

  boot_steps = [
    ["2<wait30s>", "Boot single user mode"],
    ["<enter><wait10s>", "Accept default shell"],
    ["mdmfs -s 100m md1 /tmp<enter><wait>", "Create memory-backed tmpfs"],
    ["dhclient -l /tmp/dhclient.leases vtnet0<enter><wait5s>", "Configure network via DHCP"],
    ["fetch -o /tmp/installerconfig http://{{.HTTPIP}}:{{.HTTPPort}}/resources/installerconfig<enter><wait5s>", "Download installer configuration"],
    ["ROOT_PASSWORD='${var.root_password}' bsdinstall script /tmp/installerconfig && reboot<enter>", "Run bsdinstall and reboot"],
  ]

  ssh_username = "root"
  ssh_password = var.root_password
  ssh_timeout  = "10000s"

  qemuargs = [
    ["-cpu", var.cpu_type],
    ["-boot", "strict=off"],
    ["-monitor", "none"],
    ["-accel", "hvf"],
    ["-accel", "kvm"],
    ["-accel", "tcg"],
  ]

  iso_checksum = var.checksum
  iso_urls = [
    "https://discovery.midnightbsd.org/ftp/releases/${var.architecture.image}/ISO-IMAGES/${var.os_version}/${local.image}",
    "https://ns3.foolishgames.net/ftp/pub/MidnightBSD/releases/${var.architecture.image}/ISO-IMAGES/${var.os_version}/${local.image}",
  ]

  http_directory   = "."
  output_directory = "output"
  shutdown_command = "shutdown -p now"
  vm_name          = local.vm_name
}

packer {
  required_plugins {
    qemu = {
      version = "~> 1.1.3"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

build {
  sources = ["qemu.qemu"]

  provisioner "shell" {
    script          = "resources/provision.sh"
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
    environment_vars = [
      "SECONDARY_USER=${var.secondary_user_username}",
    ]
  }

  provisioner "shell" {
    script          = "resources/custom.sh"
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
    environment_vars = [
      "SECONDARY_USER=${var.secondary_user_username}",
    ]
  }

  provisioner "shell" {
    script          = "resources/cleanup.sh"
    execute_command = "chmod +x {{ .Path }}; env {{ .Vars }} {{ .Path }}"
  }
}
