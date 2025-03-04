# KEY PAIR
resource "tls_private_key" "hush" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "hush" {
  key_name   = "hush"
  public_key = tls_private_key.hush.public_key_openssh

}

resource "local_file" "ssh_key" {
  filename = "${aws_key_pair.hush.key_name}.pem"
  content  = tls_private_key.hush.private_key_pem
}

# EC2 INSTANCE
resource "aws_instance" "bastion" {
  ami                         = var.ami
  instance_type               = var.instance_type[0]
  subnet_id                   = aws_subnet.bastion.id
  key_name                    = aws_key_pair.hush.key_name
  associate_public_ip_address = "true"
  vpc_security_group_ids      = ["${aws_security_group.bastion.id}"]
  tags = {
    Name = "BastionHostEC2"
  }
}

# EC2 INSTANCE WEB
resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type[0]
  subnet_id     = aws_subnet.web.id
  key_name      = aws_key_pair.hush.key_name
  # associate_public_ip_address = "true"
  vpc_security_group_ids = ["${aws_security_group.web.id}"]
  user_data              = file("./script/user_data.sh")
  tags = {
    Name = "WebEC2"
  }
}

# LOAD BALANCER
resource "aws_lb" "lb" {
  name               = "terraform-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets = [
    aws_subnet.bastion.id,
    aws_subnet.lb.id,
    aws_subnet.nat.id
  ]

  depends_on = [aws_instance.web]

  tags = {
    Name = "Terraform-LoadBalancer"
  }
}

# WAF - ACL
resource "aws_wafv2_web_acl" "waf_acl" {
  name        = "terraform-waf-acl"
  description = "Web ACL para proteger o ALB contra ataques comuns"
  scope       = "REGIONAL" # Para ALB, use REGIONAL. Para CloudFront, use CLOUDFRONT

  default_action {
    allow {}
  }

  rule {
    name     = "BlockSQLInjection"
    priority = 1

    statement {
      sqli_match_statement {
        field_to_match {
          all_query_arguments {}
        }
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
      }
    }

    action {
      block {}
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockSQLInjection"
    }
  }

  rule {
    name     = "BlockXSS"
    priority = 2

    statement {
      xss_match_statement {
        field_to_match {
          all_query_arguments {}
        }
        text_transformation {
          priority = 1
          type     = "URL_DECODE"
        }
      }
    }

    action {
      block {}
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockXSS"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "terraform-waf-acl"
  }
}

# ASSOCIAR O WAF AO ALB
resource "aws_wafv2_web_acl_association" "waf_alb_association" {
  resource_arn = aws_lb.lb.arn
  web_acl_arn  = aws_wafv2_web_acl.waf_acl.arn
}

# TARGET GROUP
resource "aws_lb_target_group" "tg" {
  name                          = "terraform-target-group"
  port                          = var.web_port
  protocol                      = "HTTP"
  vpc_id                        = aws_vpc.main.id
  slow_start                    = 0
  load_balancing_algorithm_type = "round_robin"
  depends_on                    = [aws_instance.web]

  health_check {
    enabled             = true
    port                = var.web_port
    interval            = 30
    protocol            = "HTTP"
    path                = "/"
    matcher             = "200"
    healthy_threshold   = 9
    unhealthy_threshold = 9
  }

  tags = {
    Name = "Terraform-TargetGroup"
  }
}

# TARGET GROUP ASSOCIATION
resource "aws_lb_target_group_attachment" "tga" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web.id
  port             = var.web_port
}

# CERTIFICATE MANAGER
resource "aws_acm_certificate" "api" {
  domain_name       = "naderhs.com"
  validation_method = "DNS"

  tags = {
    Name = "Terraform-Certificate"
  }
}

# RECORD SET
resource "aws_route53_record" "api_validation" {
  for_each = {
    for dvo in aws_acm_certificate.api.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.public.zone_id
}

# CERTIFICATE VALIDATION
resource "aws_acm_certificate_validation" "api" {
  certificate_arn         = aws_acm_certificate.api.arn
  validation_record_fqdns = [for record in aws_route53_record.api_validation : record.fqdn]
}


# DNS ZONE (USANDO O RECURSO CRIADO)
resource "aws_route53_zone" "public" {
  name = "naderhs.com"
  # private_zone = false
}

# DNS LB RECORD
resource "aws_route53_record" "api" {
  zone_id = aws_route53_zone.public.zone_id
  name    = aws_acm_certificate.api.domain_name
  type    = "A"
  # ttl     = 60

  alias {
    name                   = aws_lb.lb.dns_name
    zone_id                = aws_lb.lb.zone_id
    evaluate_target_health = false
  }
}

# LISTENERS
resource "aws_lb_listener" "http_eg1" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.api.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn

  }
  depends_on = [aws_acm_certificate_validation.api]

}

resource "aws_lb_listener" "http_eg2" {
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"


  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"

    }

  }
  depends_on = [aws_acm_certificate_validation.api]

}

# LAUNCH TEMPLATE
resource "aws_launch_template" "static_site_eg1" {
  name          = "WebLaunchTemplate"
  image_id      = "ami-04b4f1a9cf54c11d0"
  instance_type = var.instance_type[1]
  key_name      = aws_key_pair.hush.key_name

  placement {
    availability_zone = var.az[1]
  }

  vpc_security_group_ids = [aws_security_group.web.id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Auto-Scalling-instance"
    }
  }
  user_data = <<-EOF
            IyEvYmluL2Jhc2gKIyBHYXJhbnRlIHF1ZSBvIHNjcmlwdCByb2RlIGFwZW5hcyBhcMOzcyBhIHJlZGUgZXN0YXIgdG90YWxtZW50ZSBmdW5jaW9uYWwKc2xlZXAgMTgwCndoaWxlICEgcGluZyAtYyAxIC1XIDEgZ29vZ2xlLmNvbTsgZG8KICAgIGVjaG8gIkVzcGVyYW5kbyBwZWxhIHJlZGUuLi4iCiAgICBzbGVlcCAxMApkb25lCgojIEF0dWFsaXphIG9zIHBhY290ZXMKc3VkbyBhcHQtZ2V0IHVwZGF0ZSAteQpzdWRvIGFwdC1nZXQgdXBncmFkZSAteQoKIyBJbnN0YWxhIGRlcGVuZMOqbmNpYXMgcGFyYSBhZGljaW9uYXIgcmVwb3NpdMOzcmlvcwpzdWRvIGFwdC1nZXQgaW5zdGFsbCAteSBzb2Z0d2FyZS1wcm9wZXJ0aWVzLWNvbW1vbiBkaXJtbmdyIGFwdC10cmFuc3BvcnQtaHR0cHMgY2EtY2VydGlmaWNhdGVzIGN1cmwKCiMgQWRpY2lvbmEgbyByZXBvc2l0w7NyaW8gb2ZpY2lhbCBkbyBNYXJpYURCCnN1ZG8gY3VybCAtTHNTIGh0dHBzOi8vZG93bmxvYWRzLm1hcmlhZGIuY29tL01hcmlhREIvbWFyaWFkYl9yZXBvX3NldHVwIHwgc3VkbyBiYXNoCgojIEF0dWFsaXphIG5vdmFtZW50ZSBhIGxpc3RhIGRlIHBhY290ZXMKc3VkbyBhcHQtZ2V0IHVwZGF0ZSAteQoKIyBJbnN0YWxhIG8gTWFyaWFEQiBTZXJ2ZXIsIENsaWVudGUgZSBQYWNvdGUgZGUgQ29tcGF0aWJpbGlkYWRlCnN1ZG8gYXB0LWdldCBpbnN0YWxsIC15IG1hcmlhZGItc2VydmVyIG1hcmlhZGItY2xpZW50IG1hcmlhZGItY2xpZW50LWNvbXBhdAoKIyBIYWJpbGl0YSBlIGluaWNpYSBvIHNlcnZpw6dvIGRvIE1hcmlhREIKc3VkbyBzeXN0ZW1jdGwgZGFlbW9uLXJlbG9hZApzdWRvIHN5c3RlbWN0bCBlbmFibGUgbWFyaWFkYgpzdWRvIHN5c3RlbWN0bCBzdGFydCBtYXJpYWRiCgojIFZlcmlmaWNhIHNlIG8gTWFyaWFEQiBlc3TDoSByb2RhbmRvIGUgcmVpbmljaWEgc2UgbmVjZXNzw6FyaW8KaWYgISBzeXN0ZW1jdGwgaXMtYWN0aXZlIC0tcXVpZXQgbWFyaWFkYjsgdGhlbgogICAgZWNobyAiTWFyaWFEQiBuw6NvIGluaWNpb3UsIHRlbnRhbmRvIG5vdmFtZW50ZS4uLiIKICAgIHN1ZG8gc3lzdGVtY3RsIHJlc3RhcnQgbWFyaWFkYgogICAgc2xlZXAgMTAKICAgIHN1ZG8gc3lzdGVtY3RsIHN0YXR1cyBtYXJpYWRiCmZpCgojIENyaWEgdW0gbGluayBzaW1iw7NsaWNvIHBhcmEgbyBjb21hbmRvIG15c3FsIChjb21wYXRpYmlsaWRhZGUpCnN1ZG8gbG4gLXMgL3Vzci9iaW4vbWFyaWFkYiAvdXNyL2Jpbi9teXNxbAoKIyBWZXJpZmljYSBhIGluc3RhbGHDp8OjbyBkbyBNeVNRTCAoTWFyaWFEQikKbXlzcWwgLS12ZXJzaW9uIHx8IGVjaG8gIkVSUk86IE8gY29tYW5kbyBteXNxbCBuw6NvIGZvaSBlbmNvbnRyYWRvLiIgfCBzdWRvIHRlZSAtYSAvdmFyL3d3dy9odG1sL2luZGV4Lmh0bWwKCiMgSW5zdGFsYSBvIEFwYWNoZSAoaHR0cGQpIG5vIFVidW50dQpzdWRvIGFwdC1nZXQgaW5zdGFsbCAteSBhcGFjaGUyCnN1ZG8gc3lzdGVtY3RsIGVuYWJsZSBhcGFjaGUyCnN1ZG8gc3lzdGVtY3RsIHN0YXJ0IGFwYWNoZTIKCiMgQ3JpYSBvIGFycXVpdm8gaW5kZXguaHRtbCBjb20gaW5mb3JtYcOnw7VlcyBkbyBzZXJ2aWRvcgplY2hvICJIZWxsbyBXb3JsZCBpIGFtIE5hZGluIiB8IHN1ZG8gdGVlIC92YXIvd3d3L2h0bWwvaW5kZXguaHRtbApjdXJsIGh0dHA6Ly9jaGVja2lwLmFtYXpvbmF3cy5jb20gfCBzdWRvIHRlZSAtYSAvdmFyL3d3dy9odG1sL2luZGV4Lmh0bWwKZWNobyAiLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0iIHwgc3VkbyB0ZWUgLWEgL3Zhci93d3cvaHRtbC9pbmRleC5odG1sCmVjaG8gIi0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIiB8IHN1ZG8gdGVlIC1hIC92YXIvd3d3L2h0bWwvaW5kZXguaHRtbAplY2hvIC1lICJ0aGlzIGlzIG15IHByaXZhdGUgSVAiIHwgc3VkbyB0ZWUgLWEgL3Zhci93d3cvaHRtbC9pbmRleC5odG1sCmhvc3RuYW1lIC1JIHwgYXdrICd7cHJpbnQgJDF9JyB8IHN1ZG8gdGVlIC1hIC92YXIvd3d3L2h0bWwvaW5kZXguaHRtbAoKIyBWZXJpZmljYSBub3ZhbWVudGUgYSB2ZXJzw6NvIGRvIE15U1FMIChNYXJpYURCKQpteXNxbCAtLXZlcnNpb24gfCBzdWRvIHRlZSAtYSAvdmFyL3d3dy9odG1sL2luZGV4Lmh0bWwK
              EOF
}

# AUTO SCALLING GROUP
resource "aws_autoscaling_group" "static_site_eg1" {
  name                      = "WebAutoScallingGroup"
  min_size                  = 1
  max_size                  = 3
  health_check_type         = "EC2"
  health_check_grace_period = 300
  vpc_zone_identifier = [
    aws_subnet.web.id
  ]
  target_group_arns = [aws_lb_target_group.tg.arn]
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.static_site_eg1.id
      }
      override {
        instance_type = "t3.micro"
      }
    }
  }
}

# AUTO SCALLING POLICY
resource "aws_autoscaling_policy" "static_site_eg1" {
  name                      = "WebAutoScallingPolicy"
  policy_type               = "TargetTrackingScaling"
  autoscaling_group_name    = aws_autoscaling_group.static_site_eg1.name
  estimated_instance_warmup = 300
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 5.0
  }
}
