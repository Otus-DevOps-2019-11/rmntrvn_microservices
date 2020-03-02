variable project {
  description = "Project ID"
}
variable region {
  description = "Region"
  default     = "europe-west1"
}
variable public_key_path {
  description = "Path to the public key used for ssh access"
}

variable private_key_path {
  description = "Path to the private key used for ssh access"
}
variable zone {
  description = "zone to deploy in"
  default     = "europe-west1-b"
}
variable instances {
  description = "Number of instances"
  default     = "1"
}

variable docker_disk_image {
  description = "Disk image for reddit db"
  default     = "docker-reddit-base"
}
