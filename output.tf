output "k8s-bastion.public" {
  depends_on = [
     "aws_eip.k8s-bastion"
  ]
  value = "${aws_eip.bastion.public_ip}"
}
output "k8s-bastion.private" {
  depends_on = [
     "aws_eip.k8s-bastion"
  ]
  value = "${aws_eip.bastion.private_ip}"
}

output "k8s-metallb1.private" {

  value = "${aws_instance.k8s-metallb1.private_ip}"
}

output "k8s-metallb2.private" {

  value = "${aws_instance.k8s-metallb2.private_ip}"
}

output "k8s-metallb2.public" {

  value = "${aws_eip.portal.public_ip}"
}

output "k8s-master1.private" {

  value = "${aws_instance.k8s-master1.private_ip}"
}

output "k8s-master2.private" {

  value = "${aws_instance.k8s-master2.private_ip}"
}

output "k8s-master3.private" {

  value = "${aws_instance.k8s-master3.private_ip}"
}

output "k8s-worker1.private" {
 
  value = "${aws_instance.k8s-worker1.private_ip}"
}

output "k8s-worker2.private" {

  value = "${aws_instance.k8s-worker2.private_ip}"
}

output "k8s-worker3.private" {

  value = "${aws_instance.k8s-worker3.private_ip}"
}

output "key.path" {
  value = "${var.key_path}"
}

output "web-ip" {
  value ="${aws_network_interface.portal.private_ip}"
}

output "app-ip" {
  value ="${aws_network_interface.apps.private_ip}"
}
