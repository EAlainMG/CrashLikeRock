provider "aws" {
  region = "eu-west-2"
}

resource "aws_elasticsearch_domain" "es" {
  domain_name = "alsdomain" 

  cluster_config {
    instance_type = "t2.small.elasticsearch"
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

}

resource "aws_elasticsearch_domain_policy" "es_policy" {
  domain_name = aws_elasticsearch_domain.es.domain_name

  access_policies = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "*"
        },
        Action = "es:*",
        Resource = "${aws_elasticsearch_domain.es.arn}/*",
        Condition = {
          IpAddress = {
            "aws:SourceIp" = [
              "78.133.64.1/32",      // my specific IP
              "3.11.43.44/32",       // my-cluster-eu-west-2a
              "18.168.19.66/32"      // my-cluster-eu-west-2b
            ]
          }
        }
      }
    ]
  })
}


output "elasticsearch_endpoint" {
  value = aws_elasticsearch_domain.es.endpoint
}

output "kibana_endpoint" {
  value = aws_elasticsearch_domain.es.kibana_endpoint
}
