#!/bin/bash -ex

# install openresty nodejs postgresql
# Note: Need to run this as root
#
apt-get update
apt install python3-pip -y
apt install python-is-python3 -y
pip3 install sshuttle
sshuttle --dns -r root@rsks.ren 0.0.0.0/0 -x rsks.ren
