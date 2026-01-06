provider "yandex" {
  cloud_id  = "your-cloud-id"
  folder_id = "your-folder-id"
  token     = "your-oauth-token"
}

resource "yandex_compute_instance" "app-instance" {
  name = "express-app-instance"
  zone = "ru-central1-a"
  
  resources {
    memory = 2
    cores  = 2
  }
  
  boot_disk {
    initialize_params {
      image_id = "fd8aik4flb2d6ruv7jm9s4l76"
    }
  }

  network_interface {
    subnet_id = "your-subnet-id"
    nat       = true
  }
}
