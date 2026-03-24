############################
# TLS Key Pair
# One RSA key, uploaded to both regions
############################
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "use1" {
  provider   = aws.use1
  key_name   = "${var.project_name}-key-use1"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_key_pair" "usw1" {
  provider   = aws.usw1
  key_name   = "${var.project_name}-key-usw1"
  public_key = tls_private_key.ssh.public_key_openssh
}

############################
# IAM — SSM role for private instances (global, used in both regions)
############################
data "aws_iam_policy" "ssm_core" {
  provider = aws.use1
  arn      = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "ssm_role" {
  provider = aws.use1
  name     = "${var.project_name}-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = { Project = var.project_name }
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  provider   = aws.use1
  role       = aws_iam_role.ssm_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

resource "aws_iam_instance_profile" "ssm_profile" {
  provider = aws.use1
  name     = "${var.project_name}-ssm-profile"
  role     = aws_iam_role.ssm_role.name
}
