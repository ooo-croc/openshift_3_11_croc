terraform init
terraform destroy -auto-approve
terraform apply -auto-approve
#sed -i "s/openshift_cloudprovider_aws_access_key=.*.$/openshift_cloudprovider_aws_access_key=$AWS_ACCESS_KEY_ID/' hosts.openshift
#sed -i "s/openshift_cloudprovider_aws_secret_key=.*.$/openshift_cloudprovider_aws_secret_key=$AWS_SECRET_ACCESS_KEY/' hosts.openshift
bastion_ip=`terraform output k8s-bastion.public|tr -d "o:"`
metallb2_ip=`terraform output k8s-metallb2.public|tr -d "o:"`
sed -i 's/#   StrictHostKeyChecking ask/    StrictHostKeyChecking no/' /etc/ssh/ssh_config
chmod 0600 okd_private.*
chmod +x /croc-okd/generate_hosts.sh
/croc-okd/generate_hosts.sh
scp -r -i okd_private.pem /croc-okd/{*.repo,hosts.openshift,ansible.cfg,okd_private.pem,db.*,named.conf,squid.conf}  ec2-user@$bastion_ip:~/
scp -r -i okd_private.pem /croc-okd/{okd_private.pem,squid.conf,keepalived.conf,haproxy.config}  ec2-user@$metallb2_ip:~/
ssh -i okd_private.pem ec2-user@$bastion_ip << 'ENDSSH'
sudo sed -i 's/#   StrictHostKeyChecking ask/    StrictHostKeyChecking no/' /etc/ssh/ssh_config
sudo cp ~/*.repo /etc/yum.repos.d/
sudo yum repolist
sudo yum install ansible-2.6.5 git httpd-tools java-1.8.0-openjdk-headless python-passlib --nogpgcheck -y
#connect "sed -i 's/value:.*.$/value: "ru-msk-vol51"/' /home/ec2-user/openshift-ansible/roles/openshift_cloud_provider/tasks/aws.yml
sudo mkdir /croc-okd
sudo cp okd_private.pem /croc-okd
sudo chown ec2-user /croc-okd/*
#Setup DNS
sudo yum install bind -y
sudo cp -f named.conf /etc/named.conf
sudo cp -f db.* /var/named/dynamic/
sudo systemctl enable named --now
ENDSSH

#Setup squid
ssh -i okd_private.pem ec2-user@$metallb2_ip << 'ENDSSH'
sudo yum install squid -y
sudo cp -f squid.conf /etc/squid/squid.conf
sudo systemctl enable squid --now
ENDSSH

#Setup keepalived
ssh -i okd_private.pem ec2-user@$metallb2_ip << 'ENDSSH'
sudo yum install keepalived -y
sudo yum install iptables-services -y
sudo systemctl enable iptables
sudo systemctl enable keepalived --now
sudo systemctl start keepalived
sudo cp -f keepalived.conf /etc/keepalived/keepalived.conf
sudo iptables -A INPUT -p vrrp -i eth0 -j ACCEPT
sudo iptables -A INPUT -i eth0 -d 224.0.0.0/8 -j ACCEPT
sudo service iptables save
ENDSSH

ssh -i okd_private.pem ec2-user@$bastion_ip << 'ENDSSH'
ansible -i hosts.openshift OSEv3 -b  -m shell -a "yum install NetworkManager vim python-passlib -y"
ansible -i hosts.openshift OSEv3 -b  -m shell -a "systemctl enable NetworkManager --now"
ansible -i hosts.openshift OSEv3 -b  -m shell -a "sed -i 's/SELINUX=.*.$/SELINUX=permissive/' /etc/sysconfig/selinux"
ansible -i hosts.openshift OSEv3 -b  -m shell -a "sed -i 's/SELINUX=.*.$/SELINUX=permissive/' /etc/selinux/config"
ansible -i hosts.openshift OSEv3 -b  -m shell -a "hostnamectl set-hostname {{inventory_hostname}}"
ansible -i hosts.openshift OSEv3 -b  -m shell -a "reboot"
# sudo hostnamectl set-hostname bastion.openshift.local
# sudo reboot
sleep 120
rm -rf openshift-ansible
# git clone -b release-3.11 https://github.com/openshift/openshift-ansible.git openshift-ansible
git clone -b openshift-ansible-3.11.161-1 https://github.com/openshift/openshift-ansible.git openshift-ansible
ansible-playbook -b -i hosts.openshift openshift-ansible/playbooks/prerequisites.yml
ansible-playbook -b -i hosts.openshift openshift-ansible/playbooks/deploy_cluster.yml
ansible -i hosts.openshift masters -b  -m shell -a "oc adm policy add-cluster-role-to-user cluster-admin admin"
ENDSSH

#Configuration haproxy
ssh -i okd_private.pem ec2-user@$metallb2_ip << 'ENDSSH'
sudo su
cat haproxy.config >> /etc/haproxy/haproxy.cfg
sudo systemctl restart haproxy
ENDSSH

#Finally configuration
echo -e "====================================================================================================
\nOKD configuration done
proxy = $metallb2_ip:3389
Openshift Web access https://portal.openshift.local:8443
Login: admin
Password: admin\n"
