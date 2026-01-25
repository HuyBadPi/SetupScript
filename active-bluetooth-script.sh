#!/bin/bash

echo "|===========================|"
echo "|                           |"
echo "|  Active Bluetooth Script  |"
echo "|                           |"
echo "|===========================|"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root"
    exit 1
fi

if dpkg -l | grep -q bluez; then
    echo "Bluetooth is already installed. Nothing to do."
    exit 0
fi

apt update
apt install bluetooth bluez bluez-tools

systemctl start bluetooth
systemctl enable bluetooth

systemctl status bluetooth

echo "Bluetooth installed and started successfully."