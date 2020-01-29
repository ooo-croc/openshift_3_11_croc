#! /bin/bash

domain_name='openshift.local'

bastion=`terraform output k8s-bastion.public|tr -d "o:"`
bastion_ip=`terraform output k8s-bastion.private|tr -d "o:"`
bastion_subnet=`echo $bastion_ip |awk -F'.' '{print $1"."$2"."$3}'`
bastion_subnet_reverse=`echo $bastion_ip |awk -F'.' '{print $3"."$2"."$1}'`
bastion_ptr=`echo $bastion_ip |awk -F'.' '{print $4}'`
metallb1_ip=`terraform output k8s-metallb1.private|tr -d "o:"`
metallb1_ptr=`echo $metallb1_ip |awk -F'.' '{print $4}'`
metallb2_ip=`terraform output k8s-metallb2.private|tr -d "o:"`
metallb2_ptr=`echo $metallb2_ip |awk -F'.' '{print $4}'`
master1_ip=`terraform output k8s-master1.private|tr -d "o:"`
master1_ptr=`echo $master1_ip |awk -F'.' '{print $4}'`
master2_ip=`terraform output k8s-master2.private|tr -d "o:"`
master2_ptr=`echo $master2_ip |awk -F'.' '{print $4}'`
master3_ip=`terraform output k8s-master3.private|tr -d "o:"`
master3_ptr=`echo $master3_ip |awk -F'.' '{print $4}'`
worker1_ip=`terraform output k8s-worker1.private|tr -d "o:"`
worker1_ptr=`echo $worker1_ip |awk -F'.' '{print $4}'`
worker2_ip=`terraform output k8s-worker2.private|tr -d "o:"`
worker2_ptr=`echo $worker2_ip |awk -F'.' '{print $4}'`
worker3_ip=`terraform output k8s-worker3.private|tr -d "o:"`
worker3_ptr=`echo $worker3_ip |awk -F'.' '{print $4}'`
app_ip=`terraform output app-ip|tr -d "o:"`
web_ip=`terraform output web-ip|tr -d "o:"`
web_ptr=`echo $web_ip |awk -F'.' '{print $4}'`
key_path=`terraform output key.path|sed 's/o://g'`

password_admin=""'$apr1$rZnAakRf$9sC0lyt2r3Z7mrASgzV9m.'""
password_user=""'$apr1$YYUF5Szy$xWTEa8a9P1GilTqBLfgt30'""

generate_hosts()
{
cat > hosts.openshift << EOF
[local]
localhost ansible_connection=local

[all:vars]
#ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="ssh -W %h:%p -q ec2-user@$bastion -i $key_path"'

[masters]
master-1 ansible_ssh_host=$master1_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path
master-2 ansible_ssh_host=$master2_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path
master-3 ansible_ssh_host=$master3_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path

[etcd]
master-1 ansible_ssh_host=$master1_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path
master-2 ansible_ssh_host=$master2_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path
master-3 ansible_ssh_host=$master3_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path

[nodes]
worker-1 ansible_ssh_host=$worker1_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path openshift_node_group_name="node-config-compute"
worker-2 ansible_ssh_host=$worker2_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path openshift_node_group_name="node-config-compute"
worker-3 ansible_ssh_host=$worker3_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path openshift_node_group_name="node-config-compute"
master-1 ansible_ssh_host=$master1_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path openshift_node_group_name="node-config-master-infra"
master-2 ansible_ssh_host=$master2_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path openshift_node_group_name="node-config-master-infra"
master-3 ansible_ssh_host=$master3_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path openshift_node_group_name="node-config-master-infra"

[nfs]
metallb1 ansible_ssh_host=$metallb1_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path

[lb]
metallb2 ansible_ssh_host=$metallb2_ip ansible_ssh_user=ec2-user ansible_ssh_private_key_file=$key_path

[OSEv3:children]
masters
nodes
etcd
nfs
lb

[OSEv3:vars]
openshift_disable_check=memory_availability,disk_availability
ansible_user=root
openshift_deployment_type=origin
openshift_release="3.11"
openshift_master_cluster_hostname=lb.$domain_name
openshift_master_cluster_public_hostname=lb.$domain_name
openshift_master_default_subdomain=apps.$domain_name
debug_level=2
openshift_image_tag=v3.11.0
openshift_pkg_version=-3.11.0
openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider'}]
openshift_master_htpasswd_users={'admin': '$password_admin', 'user1': '$password_user'}

osm_use_cockpit=true
osm_cockpit_plugins=['cockpit-kubernetes']
openshift_hosted_router_selector='node-role.kubernetes.io/infra=true'
openshift_hosted_router_replicas=1
openshift_hosted_router_extended_validation=true
openshift_hosted_manage_router=true
openshift_hosted_registry_replicas=1
openshift_hosted_manage_registry=true
openshift_hosted_manage_registry_console=true

openshift_hosted_registry_storage_kind=nfs
openshift_hosted_registry_storage_access_modes=['ReadWriteMany']
openshift_hosted_registry_storage_nfs_directory=/exports
openshift_hosted_registry_storage_nfs_options='*(rw,root_squash)'
openshift_hosted_registry_storage_volume_name=registry
openshift_hosted_registry_storage_volume_size=10Gi

openshift_metrics_install_metrics=true
openshift_metrics_server_install=true

openshift_metrics_storage_kind=nfs
openshift_metrics_storage_access_modes=['ReadWriteOnce']
openshift_metrics_storage_nfs_directory=/exports
openshift_metrics_storage_nfs_options='*(rw,root_squash)'
openshift_metrics_storage_volume_name=metrics
openshift_metrics_storage_volume_size=5Gi
openshift_metrics_storage_labels={'storage': 'metrics'}
#openshift_metrics_storage_kind=dynamic

openshift_cluster_monitoring_operator_install=true
openshift_cluster_monitoring_operator_prometheus_storage_capacity="2Gi"
openshift_cluster_monitoring_operator_alertmanager_storage_capacity="2Gi"

# Grafana Configuration
grafana_namespace=grafana
grafana_user=admin
grafana_password=compaq
grafana_datasource_name="example"
grafana_prometheus_namespace="openshift-metrics"
grafana_prometheus_sa=prometheus
grafana_node_exporter=false
grafana_graph_granularity="2m"

openshift_logging_install_logging=false
openshift_use_openshift_sdn=true
osm_cluster_network_cidr=10.128.0.0/14
openshift_portal_net=172.30.0.0/16
openshift_pkg_version=-3.11.0
logrotate_scripts=[{"name": "syslog", "path": "/var/log/cron\n/var/log/maillog\n/var/log/messages\n/var/log/secure\n/var/log/spooler\n", "options": ["daily", "rotate 7", "compress", "sharedscripts", "missingok"], "scripts": {"postrotate": "/bin/kill -HUP  2> /dev/null || true"}}]
openshift_hostname_check=true
#openshift_http_proxy=http://192.168.0.1:3128
#openshift_https_proxy=http://192.168.0.1:3128
openshift_no_proxy='.openshift.local,.apps.openshift.local'
openshift_enable_service_catalog=false
template_service_broker_install=true
openshift_service_catalog_image="docker.io/openshift/origin-service-catalog:{{ openshift_image_tag }}""
openshift_template_service_broker_namespaces=['openshift']

openshift_master_dynamic_provisioning_enabled=True
openshift_clock_enabled=true
openshift_management_storage_class=nfs
openshift_management_storage_nfs_base_dir=/exports
openshift_enable_unsupported_configurations=true

#openshift_cloudprovider_aws_access_key="AlVishnyakov:alvishnyakov@ccs.croc.ru"
#openshift_cloudprovider_aws_secret_key="JlYUQUmKQbmXbuhu6MPSwsg"
#openshift_cloudprovider_kind=aws
#openshift_clusterid=asdasdasdasdasd

#[Global]
#Zone="ru-msk-vol51"

EOF
}

generate_squid()
{
cat > squid.conf << EOF
acl all src all
cache_mgr 2675@croc.ru
http_access allow all
http_port 0.0.0.0:3389
coredump_dir /var/spool/squid
visible_hostname bastion_ocp
pid_filename /var/run/squid_local.pid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
dns_nameservers $bastion_ip 8.8.8.8

EOF
}

generate_keepalived()
{
cat > keepalived.conf << EOF
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 1111
    }
    virtual_ipaddress {
        $web_ip
        $app_ip
    }
}
EOF
}

generate_haproxy()
{
	cat > haproxy.config << EOF

frontend  atomic-openshift-apps80
    bind *:80
    default_backend atomic-openshift-apps80
    mode tcp
    option tcplog

backend atomic-openshift-apps80
    balance source
    mode tcp
    server      master0 $master1_ip:80 check
    server      master1 $master2_ip:80 check
    server      master2 $master3_ip:80 check

frontend  atomic-openshift-apps443
    bind *:443
    default_backend atomic-openshift-apps443
    mode tcp
    option tcplog

backend atomic-openshift-apps443
    balance source
    mode tcp
    option ssl-hello-chk
    server      master0 $master1_ip:443 check
#    server      master1 $master2_ip:443 check
#    server      master2 $master3_ip:443 check
EOF
}

generate_dns()
{

cat > named.conf << EOF
options {
	listen-on port 53 { $bastion_ip; };
	listen-on-v6 port 53 { none; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	recursing-file  "/var/named/data/named.recursing";
	secroots-file   "/var/named/data/named.secroots";
	allow-query     { any; };
	recursion yes;
	dnssec-enable yes;
	dnssec-validation yes;
	/* Path to ISC DLV key */
	bindkeys-file "/etc/named.root.key";
	managed-keys-directory "/var/named/dynamic";
	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
};
logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};
zone "." IN {
	type hint;
	file "named.ca";
};
zone "${bastion_subnet_reverse}.in-addr.arpa" {
    type master;
    file "/var/named/dynamic/db.${bastion_subnet_reverse}.in-addr.arpa";
    update-policy {
            grant rndc-key zonesub ANY;
    };
};
zone "${domain_name}" {
    type master;
    file "/var/named/dynamic/db.${domain_name}";
    update-policy {
            grant rndc-key zonesub ANY;
    };
};
include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";

EOF

cat > db.${domain_name} << EOF
\$ORIGIN .
\$TTL 10800	; 3 hours
$domain_name		IN SOA	bastion.$domain_name. root.$domain_name. (
				308        ; serial
				86400      ; refresh (1 day)
				3600       ; retry (1 hour)
				604800     ; expire (1 week)
				3600       ; minimum (1 hour)
				)
			NS	bastion.$domain_name.
\$ORIGIN $domain_name.
\$TTL 86400	; 1 day
bastion 		A	$bastion_ip
master-1                A       $master1_ip
master-2                A       $master2_ip
master-3                A       $master3_ip
metallb2                A       $metallb2_ip
metallb1                A       $metallb1_ip
worker-1                A       $worker1_ip
worker-2                A       $worker2_ip
worker-3                A       $worker3_ip
portal                  A       $web_ip
lb                      CNAME   portal
*.apps                  A       $app_ip

EOF

cat > db.${bastion_subnet_reverse}.in-addr.arpa << EOF
\$ORIGIN .
\$TTL 10800	; 3 hours
${bastion_subnet_reverse}.in-addr.arpa	IN SOA	bastion.${domain_name}. root.${bastion_subnet_reverse}.in-addr.arpa. (
				284        ; serial
				86400      ; refresh (1 day)
				3600       ; retry (1 hour)
				604800     ; expire (1 week)
				3600       ; minimum (1 hour)
				)
			NS	bastion.${domain_name}.
\$ORIGIN ${bastion_subnet_reverse}.in-addr.arpa.
\$TTL 86400	; 1 day
${bastion_ptr}                  PTR     bastion.${domain_name}.
${master1_ptr}	    		PTR	master-1.${domain_name}.
${master2_ptr}                  PTR     master-2.${domain_name}.
${master3_ptr}                  PTR     master-3.${domain_name}.
${metallb1_ptr}                 PTR     metallb-1.${domain_name}.
${metallb2_ptr}                 PTR     metallb-2.${domain_name}.
${worker1_ptr}			PTR	worker-1.${domain_name}.
${worker2_ptr}			PTR	worker-2.${domain_name}.
${worker3_ptr}                  PTR     worker-3.${domain_name}.
${web_ptr}                      PTR     portal.${domain_name}.
${web_ptr}                      PTR     lb.${domain_name}.

EOF
}

terraform refresh
sleep 5
generate_hosts
sleep 1
generate_squid
sleep 1
generate_keepalived
sleep 1
generate_haproxy
sleep 1
generate_dns
