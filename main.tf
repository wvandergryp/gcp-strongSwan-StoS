# Troubleshooting tips
#
# The dos2unix.exe command is commonly used to convert text files from DOS/Windows 
# format (which uses carriage return and line feed characters, \r\n) to Unix/Linux format 
# (which uses only line feed characters, \n). This conversion is necessary when working with files 
# Troubleshooting commands
#
# The following commands can be used to troubleshoot the VPN setup:
# dos2unix.exe vm1-startup-script.sh - Convert the line endings of the vm1 startup script to Unix format.
# dos2unix.exe vm2-startup-script.sh - Convert the line endings of the vm2 startup script to Unix format.
# ipsec status - Check the status of the IPsec VPN connection.
# journalctl -f -u strongswan - View the logs of the StrongSwan service.
# ip ad - Display the IP addresses assigned to the network interfaces.
# ip route - Display the routing table.
#
# Additional troubleshooting steps:
# On vm1 - ssh 10.0.2.2 ping 10.0.2.2 - SSH into vm1 and ping its own IP address.
# On vm2 - ssh 10.0.1.2 ping 10.0.1.2 - SSH into vm2 and ping its own IP address.

variable "gcp_project" {
   description = "The ID of the project in which resources will be managed."
   type        = string
   default = "gcpvpnstrong"
}

variable "subnet_cidr_vpc1_sub1" {
  description = "CIDR range for the subnet"
  default     = "10.0.1.0/24"
}

variable "subnet_cidr_vpc2_sub1" {
  description = "CIDR range for the subnet"
  default     = "10.0.2.0/24"
}

provider "google" {
  project = var.gcp_project
  region  = "us-central1"
  zone    = "us-central1-c"
}

resource "google_compute_address" "external_ip_vm1" {
  name    = "external-ip-vm1"
  region  = "us-central1"
  project = var.gcp_project
}

resource "google_compute_address" "external_ip_vm2" {
  name    = "external-ip-vm2"
  region  = "us-central1"
  project = var.gcp_project
}

# vm1.tf

resource "google_compute_instance" "vm1" {
  name         = "vm1"
  machine_type = "e2-medium"
  zone         = "us-central1-c"
  metadata_startup_script = templatefile("${path.module}/vm1-startup-script.sh", {
    PSK           = "ChangeMe@1"
    subnet_cidr_vpc1_sub1   = var.subnet_cidr_vpc1_sub1
    subnet_cidr_vpc2_sub1   = var.subnet_cidr_vpc2_sub1
    vm1_public_ip = google_compute_address.external_ip_vm1.address
    vm2_public_ip = google_compute_address.external_ip_vm2.address
  })
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network = google_compute_network.my_vpc1.self_link
    subnetwork = google_compute_subnetwork.subnet_vm1.self_link
    access_config {
      nat_ip = google_compute_address.external_ip_vm1.address
    }
  }

  tags = ["iap-ssh-vpc1"]
  
}

# vm2.tf

resource "google_compute_instance" "vm2" {
  name         = "vm2"
  machine_type = "e2-medium"
  zone         = "us-central1-c"
  metadata_startup_script = templatefile("${path.module}/vm2-startup-script.sh", {
    PSK           = "ChangeMe@1"
    subnet_cidr_vpc1_sub1   = var.subnet_cidr_vpc1_sub1
    subnet_cidr_vpc2_sub1   = var.subnet_cidr_vpc2_sub1
    vm1_public_ip = google_compute_address.external_ip_vm1.address
    vm2_public_ip = google_compute_address.external_ip_vm2.address
  })
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    network = google_compute_network.my_vpc2.self_link
    subnetwork = google_compute_subnetwork.subnet_vm2.self_link
    access_config {
      nat_ip = google_compute_address.external_ip_vm2.address
    }
  }
   tags = ["iap-ssh-vpc2"]
}

# VPC and Subnets

resource "google_compute_network" "my_vpc1" {
  name                    = "vpn-vpc1"
  project                 = var.gcp_project
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet_vm1" {
  name          = "subnet-vm1"
  network       = google_compute_network.my_vpc1.name
  ip_cidr_range = var.subnet_cidr_vpc1_sub1
  region        = "us-central1"
}

resource "google_compute_network" "my_vpc2" {
  name                    = "vpn-vpc2"
  project                 = var.gcp_project
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet_vm2" {
  name          = "subnet-vm2"
  network       = google_compute_network.my_vpc2.name
  ip_cidr_range = var.subnet_cidr_vpc2_sub1
  region        = "us-central1"
}

# IAP SSH Firewall Rules

resource "google_compute_firewall" "iap_ssh-vpc1" {
  name    = "iap-ssh-vpc1"
  network = google_compute_network.my_vpc1.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]  # Replace with your desired source IP range

  target_tags = ["iap-ssh-vpc1"]
}

# vm2.tf

resource "google_compute_firewall" "iap_ssh-vpc2" {
  name    = "iap-ssh-vpc2"
  network = google_compute_network.my_vpc2.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]  # Replace with your desired source IP range

  target_tags = ["iap-ssh-vpc2"]
}

# Firewall rules for IPsec

resource "google_compute_firewall" "ipsec-vm1-to-vm2" {
  name    = "ipsec-vm1-to-vm2"
  network = google_compute_network.my_vpc1.name

  allow {
    protocol = "udp"
    ports    = ["500", "4500"]
  }

  source_tags = ["iap-ssh-vpc1"]
  target_tags = ["iap-ssh-vpc2"]
}

resource "google_compute_firewall" "ipsec-vm2-to-vm1" {
  name    = "ipsec-vm2-to-vm1"
  network = google_compute_network.my_vpc2.name

  allow {
    protocol = "udp"
    ports    = ["500", "4500"]
  }

  source_tags = ["iap-ssh-vpc2"]
  target_tags = ["iap-ssh-vpc1"]
}
# Service Account

resource "google_service_account" "vpn_service_account" {
  account_id   = "vpn-service-account-gce"
  display_name = "VPN Service Account"
  project      = var.gcp_project
}

resource "google_project_iam_binding" "vpn_service_account_binding" {
  project = var.gcp_project
  role    = "roles/compute.osLogin"
  members = [
    "serviceAccount:${google_service_account.vpn_service_account.email}"
  ]
}

resource "google_compute_instance_iam_binding" "vm1_iap_ssh" {
  depends_on = [ google_compute_instance.vm1 ]
  project       = var.gcp_project
  instance_name = google_compute_instance.vm1.name
  role          = "roles/compute.osLogin"
  members       = ["serviceAccount:${google_service_account.vpn_service_account.email}"]
}

resource "google_compute_instance_iam_binding" "vm2_iap_ssh" {
  depends_on = [ google_compute_instance.vm2 ]
  project       = var.gcp_project
  instance_name = google_compute_instance.vm2.name
  role          = "roles/compute.osLogin"
  members       = ["serviceAccount:${google_service_account.vpn_service_account.email}"]
}
