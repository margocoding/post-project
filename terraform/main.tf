resource "yandex_vpc_network" "my_vpc" {
  name = var.vpc_name
}

resource "yandex_vpc_subnet" "my_subnet" {
  name           = "app-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.my_vpc.id
  v4_cidr_blocks = [var.subnet_cidr]
}

resource "yandex_compute_instance" "mongodb" {
  name        = var.mongodb_vm_name
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd878mk5p0ao0vmo0ld8"
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.my_subnet.id
    nat       = true
  }

  metadata = {
    user-data = <<-EOT
      #cloud-config
      package_update: true
      packages:
        - docker.io
      runcmd:
        - systemctl start docker
        - docker run -d --name mongodb -e MONGO_INITDB_ROOT_USERNAME=admin -e MONGO_INITDB_ROOT_PASSWORD=${vars.MONGO_PASSWORD} mongo:6.0
    EOT
  }
}

resource "yandex_iam_service_account" "s3_sa" {
  name = "s3-service-account"
}

resource "yandex_resourcemanager_folder_iam_member" "s3_access" {
  folder_id = var.folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.s3_sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "s3_key" {
  service_account_id = yandex_iam_service_account.s3_sa.id
  description        = "S3 access key"
}

resource "yandex_storage_bucket" "app_bucket" {
  bucket = var.s3_bucket_name
  anonymous_access_flags {
    read = false
    list = false
  }
}


resource "yandex_compute_instance" "express" {
  count       = var.express_vm_count
  name        = "${var.express_vm_prefix}-${count.index + 1}"
  platform_id = "standard-v1"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd878mk5p0ao0vmo0ld8"
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.my_subnet.id
    nat       = true
  }

  metadata = {

    user-data = <<-EOT
    #cloud-config
    write_files:
    - path: /home/ubuntu/.env
      content: |
        MONGO_URI=mongodb://admin:secret@${yandex_compute_instance.mongodb.network_interface[0].ip_address}:27017/app?authSource=admin
        PORT=3000
        S3_REGION=${var.zone}
        S3_ENDPOINT=${var.s3_endpoint}
        S3_ACCESS_KEY_ID=${yandex_iam_service_account_static_access_key.s3_key.access_key}
        S3_ACCESS_KEY=${yandex_iam_service_account_static_access_key.s3_key.secret_key}
        S3_BUCKET=${yandex_storage_bucket.app_bucket.bucket}
    package_update: true
    packages:
      - docker.io
      - docker-compose
    runcmd:
      - systemctl start docker
      - mkdir -p posts-project
      - git clone ${var.repository_link}
      -
  EOT
  }
}
