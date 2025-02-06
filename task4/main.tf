terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  service_account_key_file = "key.json"
  cloud_id                 = "b1g0r2kida4942eldbsv"
  folder_id                = "b1gq8vme2se1748i81ut"
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "task4-network" {
  name        = "task4-network"
}

resource "yandex_vpc_subnet" "task4-subnet" {
  name           = "task4-subnet"
  v4_cidr_blocks = ["192.168.0.0/24"]
  zone           = "ru-central-a"
  network_id     = "yandex_vpc_network.task4-network.id"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  content  = tls_private_key.ssh_key.private_key_openssh
  filename = "${path.module}/id_rsa_task4"
}

resource "local_file" "cloud-config" {
  content  = <<-EOT
    users:
      - name: ipiris
        groups: sudo
        shell: /bin/bash
        sudo: 'ALL=(ALL) NOPASSWD:ALL'
        ssh_authorized_keys:
          - ${tls_private_key.ssh_key.public_key_openssh}
  EOT
  filename = "${path.module}/cloud-config.yaml"
}

resource "yandex_compute_instance" "task4-vm" {
  name        = "task4-vm"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4
  }

  boot_disk {
    initialize_params {
      image_id = "fd80ok8sil1fn2gqbm6h" # ID образа найденного в третьем задании
      size     = 20
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.task4-subnet.id
    nat       = true
  }

  metadata = {
    user-data = "${file("${path.module}/cloud-config.yaml")}"
  }

  # Установка Docker и запуск контейнера
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      "sudo docker run -d --rm --name sample-app -p 80:8000 crccheck/hello-world"
    ]

    connection {
      type        = "ssh"
      user        = "ipiris"
      private_key = tls_private_key.ssh_key.private_key_openssh
      host        = yandex_compute_instance.task4-vm.network_interface[0].nat_ip_address
    }
  }
}

output "ssh_connection_string" {
  value = "ssh -i id_rsa_task4 ipiris@${yandex_compute_instance.task4-vm.network_interface[0].nat_ip_address}"
}

output "web_app_url" {
  value = "http://${yandex_compute_instance.task4-vm.network_interface[0].nat_ip_address}"
}