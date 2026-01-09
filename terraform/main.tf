resource "yandex_vpc_network" "my_vpc" {
  name = var.vpc_name
}

resource "yandex_vpc_subnet" "my_subnet" {
  name           = "app-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.my_vpc.id
  v4_cidr_blocks = [var.subnet_cidr]
}

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
    port           = 27017
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
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
    ssh-keys  = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
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

resource "yandex_iam_service_account" "express_sa" {
  name = "express-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "express_sa_vpc_access" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.express_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "express_sa_container_puller" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.express_sa.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "express_sa_serverless" {
  folder_id = var.folder_id
  role      = "serverless.containers.invoker"
  member    = "system:allUsers"
}

resource "yandex_resourcemanager_folder_iam_member" "s3_access" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.s3_sa.id}"
}

resource "yandex_iam_service_account_static_access_key" "s3_key" {
  service_account_id = yandex_iam_service_account.s3_sa.id
}

resource "yandex_storage_bucket" "app_bucket" {
  bucket = var.s3_bucket_name

  anonymous_access_flags {
    read        = true
    list        = true
    config_read = true
  }

  depends_on = [yandex_resourcemanager_folder_iam_member.s3_access]
}


resource "yandex_container_registry" "my_registry" {
  name = "my-app-registry"
}

resource "yandex_serverless_container" "express_app" {
  name               = "express-app"
  service_account_id = yandex_iam_service_account.express_sa.id
  memory             = 256
  cores              = 1

  depends_on = [yandex_container_registry.my_registry]

  image {
    url = "cr.yandex/${yandex_container_registry.my_registry.id}/express-app:latest"
    environment = {
      MONGO_URI            = "mongodb://admin:${var.MONGO_PASSWORD}@${yandex_compute_instance.mongodb.network_interface[0].ip_address}:27017/app?authSource=admin"
      S3_REGION            = var.s3_zone
      S3_ENDPOINT          = var.s3_endpoint
      S3_ACCESS_KEY_ID     = yandex_iam_service_account_static_access_key.s3_key.access_key
      S3_SECRET_ACCESS_KEY = yandex_iam_service_account_static_access_key.s3_key.secret_key
      S3_BUCKET            = yandex_storage_bucket.app_bucket.bucket
    }
  }

  connectivity {
    network_id = yandex_vpc_network.my_vpc.id
  }
}

resource "yandex_api_gateway" "app_gateway" {
  name = "express-api-gateway"
  spec = <<-EOT
    openapi: "3.0.0"
    info:
      version: 1.0.0
      title: Express App API
    paths:
      /:
        get:
          x-yc-apigateway-integration:
            type: "serverless_containers"
            container_id: "${yandex_serverless_container.express_app.id}"
            service_account_id: "${yandex_iam_service_account.express_sa.id}"
      /{proxy+}:
        x-yc-apigateway-any-method:
          x-yc-apigateway-integration:
            type: "serverless_containers"
            container_id: "${yandex_serverless_container.express_app.id}"
            service_account_id: "${yandex_iam_service_account.express_sa.id}"
          parameters:
            - name: proxy
              in: path
              required: true
              schema:
                type: string
  EOT
}

resource "yandex_monitoring_dashboard" "app_dashboard" {
  name = "express-app-monitoring"

  widgets {
    position {
      x = 0
      y = 0
      w = 12
      h = 8

    }
    chart {
      chart_id = "requests-chart"

      title = "HTTP Requests"
      queries {
        target {
          query = "serverless.containers.http.requests_count{container_id=\"${yandex_serverless_container.express_app.id}\"}"
        }
      }
    }
  }

  widgets {
    position {
      x = 12
      y = 0
      w = 12
      h = 8
    }
    chart {
      chart_id = "errors-chart"
      title    = "Errors (5xx)"
      queries {
        target {
          query = "serverless.containers.http.errors_count{container_id=\"${yandex_serverless_container.express_app.id}\", status=\"5xx\"}"
        }
      }
    }
  }
}
