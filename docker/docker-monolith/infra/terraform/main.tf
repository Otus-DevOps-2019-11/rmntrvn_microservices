
provider "google" {
  version = "2.15"
  project = var.project
  region  = var.region
}

module "docker" {
  source            = "./modules/docker"
  public_key_path   = var.public_key_path
  zone              = var.zone
  docker_disk_image = var.docker_disk_image
}

module "vpc" {
  source        = "./modules/vpc"
  source_ranges = ["0.0.0.0/0"]
}
