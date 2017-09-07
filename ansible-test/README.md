# ansible-test

#Testing personal ansible playbooks

install ansible

#git project
https://github.com/ansible/ansible

#OS X
##if running on a mac - need to increase file handles
sudo launchctl limit maxfiles unlimited
sudo easy_install pip
sudo pip install ansible

#CentOS
##if running on centos - need to install EPEL repo
sudo yum -y install epel-release
sudo yum -y install ansible
