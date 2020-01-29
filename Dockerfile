FROM centos:7

RUN mkdir /croc-okd
WORKDIR /croc-okd
COPY . .

RUN yum update -y && \
        yum install -y \
        epel-release && \
        yum install -y \
        vim wget telnet bind-utils python-pip openssh-clients centos-release-openshift-origin311 git pyOpenSSL sshpass httpd-tools

RUN wget https://copr.fedorainfracloud.org/coprs/c2devel/c2-sdk/repo/epel-7/c2devel-c2-sdk-epel-7.repo  -O /etc/yum.repos.d/c2devel-c2-sdk-epel-7.repo && \
        yum install -y \
        python-boto c2-client bash-completion

RUN ln -s /croc-okd/terraform /bin/terraform
