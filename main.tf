
terraform {
  required_version = ">= 1.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.80"
    }
  }
}

provider "yandex" {
  cloud_id    = "b1gqrm9gad0b6sr59k6i"
  folder_id   = "bpf0cnlaqu2j42bvkp0a"
  zone        = "ru-central1-b"
}

resource "yandex_compute_instance" "vm" {
  count = 2

  name        = "vm-${count.index + 1}"
  platform_id = "standard-v1"
  zone        = "ru-central1-b"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8jlq2lf0uq4cnsj5es"
      size     = 20
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = "your-subnet-id"
    nat       = true
  }

  metadata = {
    ssh-keys = "foberetti1:${file("~/.ssh/id_rsa.pub")}"
  }

  connection {
    type        = "ssh"
    user        = "foberetti1"
    private_key = file("~/.ssh/id_rsa")
    host        = self.network_interface[0].nat_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx"
    ]
  }
}

resource "yandex_vpc_network" "net" {
  name = "my-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "my-subnet"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_lb_network_load_balancer" "lb" {
  name = "my-lb"
  region = "ru-central1"
  listener {
    name = "listener-http"
    port = 80
    protocol = "TCP"
    target_group_ids = [yandex_lb_network_load_balancer_target_group.target_group.id]
  }
  subnet_ids = [yandex_vpc_subnet.subnet.id]
}

resource "yandex_lb_network_load_balancer_target_group" "target_group" {
  name = "target-group"

  target {
    subnet_id = yandex_vpc_subnet.subnet.id
    address = yandex_compute_instance.vm[0].network_interface[0].primary_v4_address.one_to_one_nat_address
    port = 80
  }

  target {
    subnet_id = yandex_vpc_subnet.subnet.id
    address = yandex_compute_instance.vm[1].network_interface[0].primary_v4_address.one_to_one_nat_address
    port = 80
  }
}
