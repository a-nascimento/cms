# ansible-haproxy

* https://www.ansible.com

This repository contains ansible playbooks for managing self-service haproxy nodes.

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

* __haproxy.yml__
  * Playbook used for configuring haproxy

# Playbook execution examples
#### Configuring all nodes
```sh
ansible-playbook -i inventory/ \
                 -D playbooks/haproxy.yml
```
#### Configuring all production nodes
```sh
ansible-playbook -i inventory/ \
                 -l prod \
                 -D playbooks/haproxy.yml
```
#### Configure specific host(s), prompt for pass, prompt for sudo pass (default is ssh pass), and use specific username for login
```sh
ansible-playbook -kK -u <full first_full last> \
                 -i inventory/ \
                 -l 'ctqhaproxy01.*' \
                 -D playbooks/haproxy.yml

