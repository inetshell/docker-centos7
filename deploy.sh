#!/bin/bash

if [[ -z ${SSH} ]] || [[ -z ${NAME} ]] || [[ -z ${DOMAIN} ]]; then
  echo "ERROR: SSH, NAME and DOMAIN variables must be defined"
  exit 1
fi

###########################################################
# Start
echo "Start: $(date)" > deploy

###########################################################
# Disable IPv6
sudo cat <<EOF >> /etc/sysctl.d/01-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

# Apply changes
sysctl -p /etc/sysctl.d/*

###########################################################
# Set hostname
echo "HOSTNAME=${NAME}" >> /etc/sysconfig/network
/sbin/ifconfig eth0 | awk '/inet/ { print $2,"\t__HOSTNAME__" }' >> /etc/hosts
sed "s/__HOSTNAME__/${NAME}/g" -i /etc/hosts
hostnamectl set-hostname ${NAME}.${DOMAIN}

###########################################################
# Configure ulimits
echo "*                soft    nofile          32768" >> /etc/security/limits.d/20-nofile.conf
echo "*                hard    nofile          32768" >> /etc/security/limits.d/20-nofile.conf

###########################################################
# Add SSH Keys
mkdir /root/.ssh
echo "${SSH}" >> /root/.ssh/authorized_keys

# Configure SSH service for key access only
sudo sed -e "s/^PermitRootLogin.*/PermitRootLogin without-password/g" -i /etc/ssh/sshd_config
sudo sed -e "s/^PasswordAuthentication.*/PasswordAuthentication no/g" -i /etc/ssh/sshd_config
sudo systemctl restart sshd

###########################################################
# Disable SELinux
sudo sed "s/^SELINUX=.*$/SELINUX=disabled/g" -i /etc/selinux/config
sudo setenforce 0

###########################################################
# Install EPEL repo
sudo yum install -y epel-release

# Install required packages
sudo yum install -y rsync git python python-pip

###########################################################
# Install fail2ban
sudo yum install -y fail2ban

# Configure fail2ban
sudo cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
banaction = iptables-multiport
[sshd]
enabled = true
EOF

# Enable fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

###########################################################
# Configure NTP
sudo yum install -y ntp
sudo systemctl enable ntpd
sudo systemctl start ntpd

###########################################################
# Update system packages
sudo yum update -y

###########################################################
# Configure Docker service
sudo yum install -y yum-utils device-mapper-persistent-data lvm2 yum-plugin-versionlock docker-compose
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce-18.06.1.ce-3.el7
sudo yum versionlock docker-ce-18.06*
sudo systemctl enable docker
sudo systemctl start docker
sudo docker version

###########################################################
# Finish
echo "Finish: $(date)" >> deploy
