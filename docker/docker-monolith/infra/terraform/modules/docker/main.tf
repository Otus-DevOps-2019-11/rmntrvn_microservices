resource "google_compute_instance" "docker" {
  name         = "docker-${count.index + 1}"
  count        = var.instances
  machine_type = "f1-micro"
  zone         = var.zone
  tags         = ["docker-machines"]
  boot_disk {
    initialize_params {
      image = var.docker_disk_image
    }
  }
  network_interface {
    network = "default"
    access_config {

    }
  }
  metadata = {
    ssh-keys = "rmntrvn:${file(var.public_key_path)}"
  }
}
