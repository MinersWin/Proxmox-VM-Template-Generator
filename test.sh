#!/bin/bash

BASE_DIR="/root/Template"

sshdconfig=$(cat "$BASE_DIR/sshd_config")


virt-customize -a noble-server-cloudimg-amd64.img --run-command "echo "$sshdconfig" > /etc/ssh/sshd_config"
