FROM centos:centos7

ADD v2c.sh /usr/bin/
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm; \
    curl https://copr.fedoraproject.org/coprs/imcleod/imagefactory-docker-devel/repo/epel-7/imcleod-imagefactory-docker-devel-epel-7.repo > /etc/yum.repos.d/imagefactory-copr.repo; \
    yum -y install libguestfs libguestfs-tools-c imagefactory imagefactory-plugins imagefactory-plugins-TinMan imagefactory-plugins-Docker \
           libvirt-daemon-kvm libvirt-daemon-qemu libvirt-daemon-config-network; yum clean all
CMD ["/bin/bash"]

