output "master_instance_id" {
    description = "ID of k3s master instance"
    value = aws_instance.master.id
}

output "master_private_ip"{
    description = "Private IP of k3s master"
    value= aws_instance.master.private_ip
}

output "master_public_ip" {
    description = "Public IP of k3s master"
    value = aws_instance.master.public_ip
}

output "worker_asg_name" {
    description = "Name of worker ASG"
    value = aws_autoscaling_group.worker_asg.name
}

output "worker_launch_template_id"{
    description = "Launch template ID used by worker ASG"
    value = aws_launch_template.worker_lt.id
}

output "security_group_id"{
    description = "SG ID used by master/workers"
    value = aws_security_group.dr_sg.id
}

output "worker_iam_role"{
    description = "IAM role name for workers"
    value = aws_iam_role.worker_role.name
}