variable "gcp_project" {
   description = "The ID of the project in which resources will be managed."
   type        = string
   default = "<GCP project id>"
}

variable "subnet_cidr_vpc1_sub1" {
  description = "CIDR range for the subnet"
  default     = "10.0.1.0/24"
}

variable "subnet_cidr_vpc2_sub1" {
  description = "CIDR range for the subnet"
  default     = "10.0.2.0/24"
}
