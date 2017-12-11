#!/bin/bash -eux


case "$PACKER_BUILDER_TYPE" in

amazon-ebs)
    echo "==> Performing AWS EC2 items that are normally done in kickstart"
    chkconfig iptables off
    /etc/init.d/iptables stop
    setenforce 0
    sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux 
    /usr/bin/yum -y install kernel-headers kernel-devel gcc make perl curl wget git java-1.8.0-openjdk java-1.8.0-openjdk-devel unzip sudo epel-releases ed sed ntpd nc lsof patch m4
    /usr/sbin/groupadd gpadmin
    /usr/sbin/useradd gpadmin -g gpadmin -G wheel
    /usr/sbin/useradd gpuser -g gpadmin -G wheel
    echo "pivotal"| passwd --stdin gpuser
    echo "gpuser        ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
    echo "gpdb-sandbox.localdomain" > /etc/hostname
    hostnamectl set-hostname "gpdb-sandbox.localdomain"
    sed -i "s/NETWORKING=.*/NETWORKING=yes/g" /etc/sysconfig/network
    sed -i "s/HOSTNAME=.*/HOSTNAME=gpdb-sandbox.localdomain/g" /etc/sysconfig/network
    mkdir -p /gpdata/master
    chown -R gpadmin:gpadmin /gpdata
    chown gpadmin /usr/local
   ;;

docker)
    echo "==> Performing Docker items that are normally done in kickstart"
    echo "==> most of this prepared in boogabee/gpdbsandboxbase:latest"
    echo "gpdb-sandbox.localdomain" > /etc/hostname
    hostnamectl set-hostname "gpdb-sandbox.localdomain"
    service sshd start
    echo "host all all 0.0.0.0/0 md5" >> /gpdata/master/gpseg-1/pg_hba.conf
    echo "MASTER_DATA_DIRECTORY=/gpdata/master/gpseg-1" >> /home/gpadmin/.bashrc
    echo "source /usr/local/greenplum-db/greenplum_path.sh" >> /home/gpadmin/.bashrc

cat > /home/gpadmin/run.sh << EOF
#!/bin/bash

sudo service sshd start
export MASTER_DATA_DIRECTORY=/gpdata/master/gpseg-1
source /home/gpadmin/.bash_profile
source /usr/local/greenplum-db/greenplum_path.sh
gpstart -a
psql -d template1 -c "alter user gpadmin password 'pivotal'"
EOF

   chmod oug+x /home/gpadmin/run.sh
   ;;

virtualbox-iso|virtualbox-ovf)
    echo "==> Installing VirtualBox guest additions"
    # Assume that we've installed all the prerequisites:
    # kernel-headers-$(uname -r) kernel-devel-$(uname -r) gcc make perl
    # from the install media via ks.cfg

    VBOX_VERSION=$(cat /home/gpadmin/.vbox_version)
    mount -o loop /home/gpadmin/VBoxGuestAdditions_$VBOX_VERSION.iso /mnt
    sh /mnt/VBoxLinuxAdditions.run --nox11
    umount /mnt
    rm -rf /home/gpadmin/VBoxGuestAdditions_$VBOX_VERSION.iso
    rm -f /home/gpadmin/.vbox_version

    if [[ $VBOX_VERSION = "4.3.10" ]]; then
        ln -s /opt/VBoxGuestAdditions-4.3.10/lib/VBoxGuestAdditions /usr/lib/VBoxGuestAdditions
    fi
    ;;

vmware-iso|vmware-vmx)
    echo "==> Installing VMware Tools"
    cat /etc/redhat-release

    cd /tmp
    mkdir -p /mnt/cdrom
    mount -o loop /home/gpadmin/linux.iso /mnt/cdrom

    VMWARE_TOOLS_PATH=$(ls /mnt/cdrom/VMwareTools-*.tar.gz)
    VMWARE_TOOLS_VERSION=$(echo "${VMWARE_TOOLS_PATH}" | cut -f2 -d'-')
    VMWARE_TOOLS_BUILD=$(echo "${VMWARE_TOOLS_PATH}" | cut -f3 -d'-')
    VMWARE_TOOLS_BUILD=$(basename ${VMWARE_TOOLS_BUILD} .tar.gz)
    VMWARE_TOOLS_MAJOR_VERSION=$(echo ${VMWARE_TOOLS_VERSION} | cut -d '.' -f 1)
    echo "==> VMware Tools Path: ${VMWARE_TOOLS_PATH}"
    echo "==> VMware Tools Version: ${VMWARE_TOOLS_VERSION}"
    echo "==> VMware Tools Build: ${VMWARE_TOOLS_BUILD}"

    tar zxf /mnt/cdrom/VMwareTools-*.tar.gz -C /tmp/

    if [ "${VMWARE_TOOLS_MAJOR_VERSION}" -lt "10" ]; then
        /tmp/vmware-tools-distrib/vmware-install.pl -d
    else
        /tmp/vmware-tools-distrib/vmware-install.pl --force-install
    fi
    rm /home/gpadmin/linux.iso
    umount /mnt/cdrom
    rmdir /mnt/cdrom
    rm -rf /tmp/VMwareTools-*
    ;;

*)
    echo "==> Unknown Packer Build Type >>$PACKER_BUILDER_TYPE<< "
    ;;

esac
