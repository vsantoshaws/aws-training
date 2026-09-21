output "public_ip" {
  value = aws_instance.chat_ui.public_ip
}

output "instance_id" {
  value = aws_instance.chat_ui.id
}

output "chat_url" {
  value = "http://${aws_instance.chat_ui.public_ip}:${var.chat_ui_port}"
}
