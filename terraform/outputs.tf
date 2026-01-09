output "mongodb_ip" {
  value = yandex_compute_instance.mongodb.network_interface.0.nat_ip_address
}

output "api_gateway_url" {
  value = "https://${yandex_api_gateway.app_gateway.domain}"
}
