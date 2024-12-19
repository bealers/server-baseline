#!/bin/bash

USER=bealers

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

mkdir -p /home/$USER/.ssh
# this is where DO puts the key when you create the droplet
cp /root/.ssh/authorized_keys /home/$USER/.ssh/

chown -R $USER:$USER /home/$USER/.ssh
chmod 700 /home/$USER/.ssh
chmod 600 /home/$USER/.ssh/authorized_keys

echo "$USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER

################## cleanup

apt-get -qq clean > /dev/null
apt-get -qq -y autoremove > /dev/null

ufw status verbose

echo "Done."
echo  "ssh $USER@$(curl -s ifconfig.me) -i ~/.ssh/private-key"
