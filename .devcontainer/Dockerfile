FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install Terraform and AWS CLI v2
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
       gnupg software-properties-common lsb-release ca-certificates curl unzip \
    # Install Terraform from HashiCorp APT repo
    && wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list >/dev/null \
    && apt-get update \
    && apt-get install -y terraform \
    # Install AWS CLI v2
    && curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip \
    && ./aws/install --update \
    && rm -rf aws awscliv2.zip \
    # Clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
