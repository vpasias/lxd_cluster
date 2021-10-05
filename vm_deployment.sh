#!/bin/bash
#
HOME=/mnt/extra/

cat > /mnt/extra/management.xml <<EOF
<network>
  <name>management</name>
  <forward mode='nat'/>
  <bridge name='virbr100' stp='off' macTableManager="kernel"/>
  <mtu size="9216"/>
  <mac address='52:54:00:8a:8b:cd'/>
  <ip address='192.168.254.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.254.2' end='192.168.254.249'/>
      <host mac='52:54:00:8a:8b:c1' name='n1' ip='192.168.254.100'/>
      <host mac='52:54:00:8a:8b:c2' name='n2' ip='192.168.254.101'/>
      <host mac='52:54:00:8a:8b:c3' name='n3' ip='192.168.254.102'/>
      <host mac='52:54:00:8a:8b:c4' name='n4' ip='192.168.254.103'/>
      <host mac='52:54:00:8a:8b:c5' name='n5' ip='192.168.254.104'/>
      <host mac='52:54:00:8a:8b:c6' name='n6' ip='192.168.254.105'/>
      <host mac='52:54:00:8a:8b:c7' name='n7' ip='192.168.254.106'/>
      <host mac='52:54:00:8a:8b:c8' name='n8' ip='192.168.254.107'/>
      <host mac='52:54:00:8a:8b:c9' name='n9' ip='192.168.254.108'/>
    </dhcp>
  </ip>
</network>
EOF

cat > /mnt/extra/external.xml <<EOF
<network>
  <name>external</name>
  <bridge name="virbr101" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/> 
</network>
EOF

cat > /mnt/extra/internal.xml <<EOF
<network>
  <name>internal</name>
  <bridge name="virbr102" stp='off' macTableManager="kernel"/>
  <mtu size="9216"/> 
</network>
EOF

virsh net-define /mnt/extra/management.xml && virsh net-autostart management && virsh net-start management
virsh net-define /mnt/extra/external.xml && virsh net-autostart external && virsh net-start external
virsh net-define /mnt/extra/internal.xml && virsh net-autostart internal && virsh net-start internal

ip a && sudo virsh net-list --all

sleep 20

# Node 1
./kvm-install-vm create -c 6 -m 32768 -d 120 -t ubuntu2004 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c1 n1

# Node 2
./kvm-install-vm create -c 6 -m 32768 -d 120 -t ubuntu2004 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c2 n2

# Node 3
./kvm-install-vm create -c 6 -m 32768 -d 120 -t ubuntu2004 -f host-passthrough -k /root/.ssh/id_rsa.pub -l /mnt/extra/virt/images -L /mnt/extra/virt/vms -b virbr100 -T US/Eastern -M 52:54:00:8a:8b:c3 n3

sleep 60

virsh list --all && brctl show && virsh net-list --all

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i 'echo "root:gprm8350" | sudo chpasswd'; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i 'echo "ubuntu:kyax7344" | sudo chpasswd'; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config"; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo systemctl restart sshd"; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo rm -rf /root/.ssh/authorized_keys"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo hostnamectl set-hostname n$i --static"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo apt update -y && sudo apt-get install -y git vim net-tools wget curl bash-completion apt-utils iperf iperf3 mtr traceroute netcat sshpass socat"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo chmod -x /etc/update-motd.d/*"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i 'cat << EOF | sudo tee /etc/update-motd.d/01-custom
#!/bin/sh
echo "****************************WARNING****************************************
UNAUTHORISED ACCESS IS PROHIBITED. VIOLATORS WILL BE PROSECUTED.
*********************************************************************************"
EOF'; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo chmod +x /etc/update-motd.d/01-custom"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "cat << EOF | sudo tee /etc/modprobe.d/qemu-system-x86.conf
options kvm_intel nested=1
EOF"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo DEBIAN_FRONTEND=noninteractive apt-get install linux-generic-hwe-20.04 --install-recommends -y"; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo apt autoremove -y && sudo apt --fix-broken install -y"; done

for i in {1..3}; do virsh shutdown n$i; done && sleep 10 && virsh list --all && for i in {1..3}; do virsh start n$i; done && sleep 10 && virsh list --all

sleep 30

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo mkdir -p /etc/systemd/system/networking.service.d"; done
for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "cat << EOF | sudo tee /etc/systemd/system/networking.service.d/reduce-timeout.conf
[Service]
TimeoutStartSec=15
EOF"; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "sudo apt update -y"; done

for i in {1..3}; do qemu-img create -f qcow2 vbdnode1$i 120G; done
for i in {1..3}; do qemu-img create -f qcow2 vbdnode2$i 120G; done
for i in {1..3}; do qemu-img create -f qcow2 vbdnode3$i 120G; done

for i in {1..3}; do ./kvm-install-vm attach-disk -d 120 -s /mnt/extra/kvm-install-vm/vbdnode1$i.qcow2 -t vdb n$i; done
for i in {1..3}; do ./kvm-install-vm attach-disk -d 120 -s /mnt/extra/kvm-install-vm/vbdnode2$i.qcow2 -t vdc n$i; done
for i in {1..3}; do ./kvm-install-vm attach-disk -d 120 -s /mnt/extra/kvm-install-vm/vbdnode3$i.qcow2 -t vdd n$i; done

for i in {1..3}; do virsh attach-interface --domain n$i --type network --source internal --model e1000 --mac 02:00:aa:0a:01:1$i --config --live; done
for i in {1..3}; do virsh attach-interface --domain n$i --type network --source external --model e1000 --mac 02:00:aa:0a:02:1$i --config --live; done

for i in {1..3}; do ssh -o "StrictHostKeyChecking=no" ubuntu@n$i "cat << EOF | sudo tee /etc/hosts
127.0.0.1 localhost
192.168.254.100  n1
192.168.254.101  n2
192.168.254.102  n3
192.168.254.103  n4
192.168.254.104  n5
192.168.254.105  n6
192.168.254.106  n7
192.168.254.107  n8
192.168.254.108  n9

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
EOF"; done

for i in {1..3}; do virsh shutdown n$i; done && sleep 10 && virsh list --all && for i in {1..3}; do virsh start n$i; done && sleep 10 && virsh list --all
