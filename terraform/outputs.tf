output "mongodb_ip" {
  value = yandex_compute_instance.mongodb.network_interface.0.nat_ip_address
}

output "express_ips" {
  value = [for i in yandex_compute_instance.express : i.network_interface.0.nat_ip_address]
}

# output "lb_ip" {
#   value = yandex_lb_network_load_balancer.app_lb.listener.0.external_address
# }
