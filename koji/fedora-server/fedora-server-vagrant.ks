#version=F21
# Keyboard layouts
keyboard 'us'
# Reboot after installation
reboot
# Root password
rootpw --plaintext vagrant
# System timezone
timezone Etc/UTC --isUtc
# System language
lang en_US.UTF-8
user --name=none
user --name=vagrant --password=vagrant
# Firewall configuration
firewall --disabled
# Network information
network  --bootproto=dhcp --device=link --activate
repo --name="rawhide" --mirrorlist=https://mirrors.fedoraproject.org/metalink?repo=rawhide&arch=$basearch
# System authorization information
auth --useshadow --passalgo=sha512
cmdline
# SELinux configuration
selinux --enforcing

# System services
services --enabled="network,sshd,rsyslog"
# System bootloader configuration
bootloader --append="no_timer_check console=tty1 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0" --location=mbr --timeout=1
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all
# Disk partitioning information
part / --fstype="ext4" --grow --size=3000

%post --erroronfail

# older versions of livecd-tools do not follow "rootpw --lock" line above
# https://bugzilla.redhat.com/show_bug.cgi?id=964299
passwd -l root
# remove the user anaconda forces us to make
userdel -r none

# Kickstart specifies timeout in seconds; syslinux uses 10ths.
# 0 means wait forever, so instead we'll go with 1.
sed -i 's/^timeout 10/timeout 1/' /boot/extlinux/extlinux.conf

# setup systemd to boot to the right runlevel
echo -n "Setting default runlevel to multiuser text mode"
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
echo .

# this is installed by default but we don't need it in virt
# Commenting out the following for #1234504
# rpm works just fine for removing this, no idea why dnf can't cope
echo "Removing linux-firmware package."
rpm -e linux-firmware

# instlang hack. (Note! See bug referenced above package list)
find /usr/share/locale -mindepth  1 -maxdepth 1 -type d -not -name en_US -exec rm -rf {} +
localedef --list-archive | grep -v ^en_US | xargs localedef --delete-from-archive
# this will kill a live system (since it's memory mapped) but should be safe offline
mv -f /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
build-locale-archive
echo '%_install_langs C:en:en_US:en_US.UTF-8' >> /etc/rpm/macros.image-language-conf
awk '(NF==0&&!done){print "override_install_langs='$LANG'";done=1}{print}' \
    < /etc/yum.conf > /etc/yum.conf.new
mv /etc/yum.conf.new /etc/yum.conf


echo -n "Getty fixes"
# although we want console output going to the serial console, we don't
# actually have the opportunity to login there. FIX.
# we don't really need to auto-spawn _any_ gettys.
sed -i '/^#NAutoVTs=.*/ a\
NAutoVTs=0' /etc/systemd/logind.conf

echo -n "Network fixes"
# initscripts don't like this file to be missing.
# and https://bugzilla.redhat.com/show_bug.cgi?id=1204612
cat > /etc/sysconfig/network << EOF
NETWORKING=yes
NOZEROCONF=yes
DEVTIMEOUT=10
EOF

# For cloud images, 'eth0' _is_ the predictable device name, since
# we don't want to be tied to specific virtual (!) hardware
rm -f /etc/udev/rules.d/70*
ln -s /dev/null /etc/udev/rules.d/80-net-setup-link.rules

# simple eth0 config, again not hard-coded to the build hardware
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE="eth0"
BOOTPROTO="dhcp"
ONBOOT="yes"
TYPE="Ethernet"
PERSISTENT_DHCLIENT="yes"
EOF

# generic localhost names
cat > /etc/hosts << EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

EOF
echo .


# Because memory is scarce resource in most cloud/virt environments,
# and because this impedes forensics, we are differing from the Fedora
# default of having /tmp on tmpfs.
echo "Disabling tmpfs for /tmp."
systemctl mask tmp.mount

# make sure firstboot doesn't start
echo "RUN_FIRSTBOOT=NO" > /etc/sysconfig/firstboot

# Uncomment this if you want to use cloud init but suppress the creation
# of an "ec2-user" account. This will, in the absence of further config,
# cause the ssh key from a metadata source to be put in the root account.
#cat <<EOF > /etc/cloud/cloud.cfg.d/50_suppress_ec2-user_use_root.cfg
#users: []
#disable_root: 0
#EOF

echo "Removing random-seed so it's not the same in every image."
rm -f /var/lib/random-seed

echo "Cleaning old dnf repodata."
# FIXME: clear history?
dnf clean all
truncate -c -s 0 /var/log/dnf.log
truncate -c -s 0 /var/log/dnf.rpm.log

echo "Import RPM GPG key"
releasever=$(rpm -q --qf '%{version}\n' fedora-release)
basearch=$(uname -i)
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch

echo "Packages within this cloud image:"
echo "-----------------------------------------------------------------------"
rpm -qa
echo "-----------------------------------------------------------------------"
# Note that running rpm recreates the rpm db files which aren't needed/wanted
rm -f /var/lib/rpm/__db*


# This is a temporary workaround for
# <https://bugzilla.redhat.com/show_bug.cgi?id=1147998>
# where sfdisk seems to be messing up the mbr.
# Long-term fix is to address this in anaconda directly and remove this.
# <https://bugzilla.redhat.com/show_bug.cgi?id=1015931>
dd if=/usr/share/syslinux/mbr.bin of=/dev/vda


# FIXME: is this still needed?
echo "Fixing SELinux contexts."
touch /var/log/cron
touch /var/log/boot.log
chattr -i /boot/extlinux/ldlinux.sys
/usr/sbin/fixfiles -R -a restore
chattr +i /boot/extlinux/ldlinux.sys

#echo "Zeroing out empty space."
# This forces the filesystem to reclaim space from deleted files
#dd bs=1M if=/dev/zero of=/var/tmp/zeros || :
#rm -f /var/tmp/zeros
#echo "(Don't worry -- that out-of-space error was expected.)"

# For trac ticket https://fedorahosted.org/cloud/ticket/128
rm -f /etc/sysconfig/network-scripts/ifcfg-ens3

%end

%post --erroronfail

# Work around cloud-init being both disabled and enabled; need
# to refactor to a common base.
systemctl mask cloud-init cloud-init-local cloud-config cloud-final

# Vagrant setup
sed -i 's,Defaults\\s*requiretty,Defaults !requiretty,' /etc/sudoers
echo 'vagrant ALL=NOPASSWD: ALL' > /etc/sudoers.d/vagrant-nopasswd
sed -i 's/.*UseDNS.*/UseDNS no/' /etc/ssh/sshd_config
mkdir -m 0700 -p ~vagrant/.ssh
cat > ~vagrant/.ssh/authorized_keys << EOKEYS
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key
EOKEYS
chmod 600 ~vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant ~vagrant/.ssh/

# Further suggestion from @purpleidea (James Shubin) - extend key to root users as well
mkdir -m 0700 -p /root/.ssh
cp /home/vagrant/.ssh/authorized_keys /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh

%end

%packages
@^server-product-environment
dnf-yum
rsync
-NetworkManager
-biosdevname
-dracut-config-rescue
-grub2
-iprutils
-uboot-tools

%end
url --url=http://kojipkgs.fedoraproject.org/mash/rawhide-20160121/rawhide/$basearch/os/
