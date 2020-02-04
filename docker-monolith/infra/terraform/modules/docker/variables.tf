variable zone {
  description = "Zone deploy"
  default     = "europe-west1-b"
}
variable public_key_path {
  description = "Path to the public key used for ssh access"
}
variable private_key_path {
  description = "IKE credential placement"
  default     = "~/.ssh/id_rsa"
}
variable docker_disk_image {
  description = "Disk image"
  default     = "docker-reddit-base"
}

variable instances {
  description = "Number of instances"
  default     = "1"
}
