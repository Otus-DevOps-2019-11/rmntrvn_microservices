resource "google_compute_firewall" "firewall_puma" {
  name    = "allow-puma-default"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["9292", "80"]
  }
  source_ranges = var.source_ranges
  target_tags   = ["docker-machines"]
}
