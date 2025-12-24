FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install SSH server, git, and basic tools
RUN apt-get update && \
    apt-get install -y \
    openssh-server \
    git \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Create deploy user
RUN useradd -m -s /bin/bash deploy && \
    echo 'deploy:password' | chpasswd

# Setup SSH
RUN mkdir /var/run/sshd && \
    mkdir -p /home/deploy/.ssh && \
    chmod 700 /home/deploy/.ssh

# Copy SSH authorized key
COPY test_key.pub /home/deploy/.ssh/authorized_keys
RUN chown -R deploy:deploy /home/deploy/.ssh && \
    chmod 600 /home/deploy/.ssh/authorized_keys

# Allow SSH login with keys
RUN sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Expose SSH port
EXPOSE 22

# Start SSH service
CMD ["/usr/sbin/sshd", "-D"]
