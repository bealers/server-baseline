#!/bin/bash

MAINTENANCE_USER=bealers

set -e
umask 022
export DEBIAN_FRONTEND=noninteractive

################## baseline install

apt-get -qq update
apt-get -qq -y upgrade
apt-get -qq -y install \
    vim \
    curl \
    git \
    unzip \
    zip \
    ntp \
    ufw

################## firewall

ufw default deny incoming
ufw default allow outgoing

# default closed to everything except SSH
ufw allow 22/tcp

ufw --force enable

################## harden ssh

# WARNING: This will very likely break default Digital Ocean access methods
#
# echo "PermitRootLogin no" >> /etc/ssh/sshd_config
# echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
# systemctl restart sshd
# passwd -l root  # Lock root account

################## locale

timedatectl set-timezone Europe/London
locale-gen en_GB.UTF-8 > /dev/null
update-locale LANG=en_GB.UTF-8


################## user

useradd -m -s /bin/bash "$MAINTENANCE_USER"

mkdir -p /home/$MAINTENANCE_USER/.ssh
# this is where DO puts the key when you create the droplet
cp /root/.ssh/authorized_keys /home/$MAINTENANCE_USER/.ssh/

chown -R $MAINTENANCE_USER:$MAINTENANCE_USER /home/$MAINTENANCE_USER/.ssh
chmod 700 /home/$MAINTENANCE_USER/.ssh
chmod 600 /home/$MAINTENANCE_USER/.ssh/authorized_keys

echo "$MAINTENANCE_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$MAINTENANCE_USER

################## cleanup

apt-get -qq clean > /dev/null
apt-get -qq -y autoremove > /dev/null

ufw status verbose

echo "Sorted. You can now login as your maintenance user: $MAINTENANCE_USER"
echo  "ssh $MAINTENANCE_USER@$(curl -s ifconfig.me) -i ~/.ssh/private-key"
