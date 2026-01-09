variable "sa_key_file" {}
variable "cloud_id" {}
variable "folder_id" {}

variable "s3_zone" {
  default = "ru-central1"
}

variable "s3_bucket_name" {
  default = "post-urfu-files-test-public"
}

variable "MONGO_PASSWORD" {}

variable "s3_endpoint" {
  default = "https://storage.yandexcloud.net"
}

variable "zone" {
  default = "ru-central1-a"
}

variable "vpc_name" {
  default = "my-app-vpc"
}

variable "subnet_cidr" {
  default = "10.0.1.0/24"
}

variable "mongodb_vm_name" {
  default = "mongodb"
}
