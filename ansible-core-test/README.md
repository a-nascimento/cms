# ansible-core

* https://www.ansible.com

This repository contains ansible playbooks for orchestrating both the Amazon VPC and Metacloud environments.

# Installing ansible

* OSX (macports)
```sh
sudo port install ansible
```

* Debian
```sh
sudo apt-get -y install ansible
```

* RedHat
```sh
sudo yum -y install ansible
```

* Manual
```sh
sudo pip install ansible
```

# Playbooks

* __bootstrap.yml__
  * Playbook used for building nodes, including service configurations
* __utl-mon.yml__
  * Playbook used for configuring mon.utl nodes
* __utl-ops.yml__
  * Playbook used for configuring ops.utl nodes
* __xxx-lb.yml__
  * Playbook used for configuring haproxy nodes for all products

# Updating inventory
Before you can execute ansible playbooks, you need to make sure your node is in DNS and inventory.
#### Updating DNS
You can update DNS by following this documentation:
* https://github.com/usamp-ops/bind-zones

#### Updating Inventory
To update Ansible inventory you first need to check out the repository.  Once that's checked out, you simply add the hostname to the corresponding inventory file.
```sh
$ git clone https://github.com/usamp-ops/ansible-core
$ ls -l ansible-core/inventory/
total 28
-rw-r--r-- 1 user user   10 Jun 12 10:51 localhost
-rw-r--r-- 1 user user  281 Oct 19 16:03 phx304.tools.priv
-rw-r--r-- 1 user user 1013 Oct 19 16:00 phx306.qa.priv
-rw-r--r-- 1 user user 1940 Oct 19 15:59 phx308.prod.priv
-rw-r--r-- 1 user user  171 Oct 19 16:01 phx309.stage.priv
-rw-r--r-- 1 user user  333 Oct 20 14:52 phx312.lab.priv
-rw-r--r-- 1 user user  227 Oct 20 11:50 useast1.prod.priv
```

# Playbook execution examples
#### Bootstrapping nodes (e.g. tkimball1.utl.phx312.lab.priv)
```sh
ansible-playbook -i inventory/ \
                 -l tkimball1.utl.phx312.lab.priv \
                 -D playbooks/bootstrap.yml
```
#### Configuring ops.utl nodes post bootstrap (cluster: phx306)
```sh
ansible-playbook -i inventory/ \
                 -l phx306 \
                 -D playbooks/utl-ops.yml
```
#### Configuring mon.utl nodes post bootstrap (cluster: phx312)
```sh
ansible-playbook -i inventory/ \
                 -l phx312 \
                 -D playbooks/utl-mon.yml
```
#### Configuring ops.utl nodes for bind __only__, using tags
```sh
ansible-playbook -i inventory/ \
                 -t bind \
                 -D playbooks/utl-ops.yml
```
#### Configuring all load balancers in all environments
```sh
ansible-playbook -i inventory/ \
                 -D playbooks/xxx-lb.yml
```

