resource "yandex_vpc_security_group" "app_sg" {
  name       = "app-security-group"
  network_id = yandex_vpc_network.my_vpc.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 3000
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 27017
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

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
  zone        = var.zone

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
    subnet_id          = yandex_vpc_subnet.my_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.app_sg.id]
  }

  metadata = {
    user-data = <<-EOT
      #cloud-config
      package_update: true
      packages:
        - docker.io
      runcmd:
        - systemctl start docker
        - systemctl enable docker
        - [ docker, run, -d, --name, mongodb, --restart, always, -p, "27017:27017", -e, "MONGO_INITDB_ROOT_USERNAME=admin", -e, "MONGO_INITDB_ROOT_PASSWORD=${var.MONGO_PASSWORD}", mongo:6.0 ]
    EOT
  }
}

resource "yandex_iam_service_account" "s3_sa" {
  name = "s3-service-account"
}

resource "yandex_resourcemanager_folder_iam_member" "s3_access" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.s3_sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "s3_key" {
  service_account_id = yandex_iam_service_account.s3_sa.id
  description        = "S3 access key"
}

resource "yandex_storage_bucket" "app_bucket" {
  bucket     = var.s3_bucket_name
  access_key = yandex_iam_service_account_static_access_key.s3_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.s3_key.secret_key

  depends_on = [
    yandex_resourcemanager_folder_iam_member.s3_access
  ]

  anonymous_access_flags {
    read = false
    list = false
  }
}

resource "yandex_compute_instance" "express" {
  count       = var.express_vm_count
  name        = "${var.express_vm_prefix}-${count.index + 1}"
  platform_id = "standard-v1"
  zone        = var.zone

  depends_on = [
    yandex_iam_service_account_static_access_key.s3_key,
    yandex_compute_instance.mongodb
  ]

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
    subnet_id          = yandex_vpc_subnet.my_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.app_sg.id]
  }

  metadata = {
    user-data = <<-EOT
      #cloud-config
      package_update: true
      packages:
        - docker.io
        - git
      runcmd:
        - systemctl start docker
        - systemctl enable docker
        - curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        - chmod +x /usr/local/bin/docker-compose
        - mkdir -p /home/ubuntu/app
        - git clone ${var.repository_link} /home/ubuntu/app
        - |
          cat <<EOF > /home/ubuntu/app/.env
          MONGO_URI=mongodb://admin:${var.MONGO_PASSWORD}@${yandex_compute_instance.mongodb.network_interface[0].ip_address}:27017/app?authSource=admin
          PORT=3000
          S3_REGION=${var.zone}
          S3_ENDPOINT=${var.s3_endpoint}
          S3_ACCESS_KEY_ID=${yandex_iam_service_account_static_access_key.s3_key.access_key}
          S3_SECRET_ACCESS_KEY=${yandex_iam_service_account_static_access_key.s3_key.secret_key}
          S3_BUCKET=${yandex_storage_bucket.app_bucket.bucket}
          EOF
        - cd /home/ubuntu/app && /usr/local/bin/docker-compose up -d --build
    EOT
  }
}
