#! /bin/sh

export LC_ALL=C
export LC_CTYPE="UTF-8",
export LANG="en_US.UTF-8"

# ---- PART ONE ------
# Configure SSH connectivity from 'deployment' - n0 to Target Hosts 

echo 'run-conf.sh: Cleaning directory /home/ubuntu/.ssh/'
rm -f /home/ubuntu/.ssh/known_hosts
rm -f /home/ubuntu/.ssh/id_rsa
rm -f /home/ubuntu/.ssh/id_rsa.pub

echo 'run-conf.sh: Running ssh-keygen -t rsa'
ssh-keygen -q -t rsa -N "" -f /home/ubuntu/.ssh/id_rsa

echo 'run-conf.sh: Running ssh-copy-id for n1'
sshpass -p kyax7344 ssh-copy-id -o StrictHostKeyChecking=no ubuntu@n1
echo 'run-conf.sh: Running ssh-copy-id for n2'
sshpass -p kyax7344 ssh-copy-id -o StrictHostKeyChecking=no ubuntu@n2
echo 'run-conf.sh: Running ssh-copy-id for n3'
sshpass -p kyax7344 ssh-copy-id -o StrictHostKeyChecking=no ubuntu@n3

echo 'run-conf.sh: Check Connectivity'

ssh -o StrictHostKeyChecking=no ubuntu@n1 "uname -a"
ssh -o StrictHostKeyChecking=no ubuntu@n2 "uname -a"
ssh -o StrictHostKeyChecking=no ubuntu@n3 "uname -a"

echo 'run-conf.sh: Configuration of Ansible'

DEBIAN_FRONTEND=noninteractive sudo apt update
DEBIAN_FRONTEND=noninteractive sudo apt install -y python3 python3-simplejson python3-jinja2 python3-dev python3-venv python3-pip libffi-dev gcc libssl-dev curl git vim
sudo pip3 install -U pip

echo 'run-kolla.sh: Install Ansible'
sudo pip3 install --upgrade pip
sudo pip install -U 'ansible<2.10'

if [ $? -ne 0 ]; then
  echo "Cannot install Ansible"
  exit $?
fi

echo 'run-conf.sh: Configuration of Ceph-Ansible'

git clone https://github.com/ceph/ceph-ansible.git
cd ceph-ansible
git checkout stable-6.0
sudo pip install -r requirements.txt

cat << EOF | tee group_vars/all.yml
generate_fsid: true
monitor_interface: ens11
journal_size: 5120
public_network: 172.16.1.0/24
cluster_network: 172.16.1.0/24
cluster_interface: ens11
ceph_docker_image: "ceph/daemon"
ceph_docker_image_tag: latest-pacific
containerized_deployment: true
osd_objectstore: bluestore
ceph_docker_registry: docker.io
radosgw_interface: ens11
dashboard_admin_user: admin
dashboard_admin_password: gprm8350
grafana_admin_user: admin
grafana_admin_password: gprm8350
EOF

cat << EOF | tee group_vars/osds.yml
osd_scenario: collocated
copy_admin_key: true
dmcrypt: false
devices:
  - /dev/vdb
  - /dev/vdc
EOF

cat << EOF | tee group_vars/mgrs.yml
ceph_mgr_modules: [status]
EOF

cp site-container.yml.sample site-container.yml

cat << EOF | tee hosts
[mons]
n1 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
n2 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
n3 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
[osds]
n1 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
n2 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
n3 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
[grafana-server]
n3 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
[mgrs]
n1 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
n2 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
n3 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
[rgws]
n1 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
n2 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
n3 ansible_ssh_user=ubuntu ansible_become=True ansible_private_key_file=/home/ubuntu/.ssh/id_rsa
EOF

echo 'run-conf.sh: Check Node Connectivity'

ansible -m ping -i hosts mons

echo 'run-conf.sh: Run Ceph-Ansible'

ansible-playbook site-container.yml -i hosts

echo 'run-conf.sh: Check Ceph Status'

ssh -o StrictHostKeyChecking=no ubuntu@n1 "sudo docker ps"
