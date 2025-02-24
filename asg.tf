resource "aws_autoscaling_group" "epsilon-asg" {
  # availability_zones        = ["us-east-1a"]
  name                      = "epsilon-asg"
  desired_capacity          = 1
  max_size                  = 3
  min_size                  = 1
  termination_policies      = ["OldestInstance"]
  vpc_zone_identifier  = ["${aws_subnet.epsilon-vpc-pvt-1a.id}", "${aws_subnet.epsilon-vpc-pvt-1b.id}" ]
  launch_template {
    id      = aws_launch_template.epsilon-lt.id
    version = "$Latest"
  }
  target_group_arns = [ aws_lb_target_group.epsilon-tg.arn ]
  
}
resource "aws_autoscaling_policy" "epsilon-asg" {
  name                   = "epsilon-asg"
  autoscaling_group_name = aws_autoscaling_group.epsilon-asg.name
  policy_type            = "PredictiveScaling"
  predictive_scaling_configuration {
    metric_specification {
      target_value = 10
      predefined_load_metric_specification {
        predefined_metric_type = "ASGTotalCPUUtilization"
        resource_label         = "epsilon-asg"
      }
      customized_scaling_metric_specification {
        metric_data_queries {
          id = "scaling"
          metric_stat {
            metric {
              metric_name = "CPUUtilization"
              namespace   = "AWS/EC2"
              dimensions {
                name  = "AutoScalingGroupName"
                value = "epsilon-asg"
              }
            }
            stat = "Average"
          }
        }
      }
    }
  }
}

resource "aws_autoscaling_group" "epsilon-asg-apiserver" {
  # availability_zones        = ["us-east-1a"]
  name                      = "epsilon-asg-apiserver"
  desired_capacity          = 1
  max_size                  = 3
  min_size                  = 1
  termination_policies      = ["OldestInstance"]
  vpc_zone_identifier  = ["${aws_subnet.epsilon-vpc-pvt-1a.id}", "${aws_subnet.epsilon-vpc-pvt-1b.id}" ]
  launch_template {
    id      = aws_launch_template.epsilon-lt-apiserver.id
    version = "$Latest"
  }
  target_group_arns = [ aws_lb_target_group.epsilon-tg-api.arn ]
  
}
resource "aws_autoscaling_policy" "epsilon-asg-apiserver" {
  name                   = "epsilon-asg-apiserver"
  autoscaling_group_name = aws_autoscaling_group.epsilon-asg-apiserver.name
  policy_type            = "PredictiveScaling"
  predictive_scaling_configuration {
    metric_specification {
      target_value = 10
      predefined_load_metric_specification {
        predefined_metric_type = "ASGTotalCPUUtilization"
        resource_label         = "epsilon-asg-apiserver"
      }
      customized_scaling_metric_specification {
        metric_data_queries {
          id = "scaling"
          metric_stat {
            metric {
              metric_name = "CPUUtilization"
              namespace   = "AWS/EC2"
              dimensions {
                name  = "AutoScalingGroupName"
                value = "epsilon-asg"
              }
            }
            stat = "Average"
          }
        }
      }
    }
  }
}


resource "aws_acm_certificate" "sba_api_cert" {
  domain_name       = "epsilon-smartbankapi.cloudtech-training.com"
  validation_method = "DNS"
}

data "aws_route53_zone" "sba_zone" {
  name         = "cloudtech-training.com"
  private_zone = false
}

resource "aws_route53_record" "sba_api_zone_record" {
  for_each = {
    for dvo in aws_acm_certificate.sba_api_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = false
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.sba_zone.zone_id
}

resource "aws_route53_record" "sba_react_zone_a_record" {
  allow_overwrite = false
  zone_id         = data.aws_route53_zone.sba_zone.zone_id
  name            = "${var.vpc_name}-sba-api.cloudtech-training.com"
  type            = "A"

  alias {
    name                   = aws_lb.api_nlb.dns_name
    zone_id                = aws_lb.api_nlb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_acm_certificate_validation" "sba_api_cert_validation" {
  certificate_arn         = aws_acm_certificate.sba_api_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.sba_api_zone_record : record.fqdn]
}