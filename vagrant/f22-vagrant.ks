#version=DEVEL
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
user --name=vagrant --password=vagrant
# Firewall configuration
firewall --disabled
# Network information
network  --bootproto=dhcp --device=link --activate
repo --name="fedora" --mirrorlist=http://mirrors.fedoraproject.org/metalink?repo=fedora-$releasever&arch=$basearch
repo --name="updates" --mirrorlist=http://mirrors.fedoraproject.org/metalink?repo=updates-released-f$releasever&arch=$basearch
# System authorization information
auth --useshadow --enablemd5
cmdline
# SELinux configuration
selinux --enforcing

# System services
services --enabled="network,sshd,rsyslog"
# System bootloader configuration
bootloader --append="no_timer_check console=tty1 console=ttyS0,115200n8 net.ifnames=0 biosdevname=0" --location=mbr --timeout=1 --extlinux
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all
# Disk partitioning information
part / --fstype="ext4" --grow --size=3000

%post --erroronfail
# setup systemd to boot to the right runlevel
echo -n "Setting default runlevel to multiuser text mode"
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
echo .

# this is installed by default but we don't need it in virt
echo "Removing linux-firmware package."
dnf -C -y erase linux-firmware

# Remove firewalld; was supposed to be optional in F18+, but is pulled in
# in install/image building.
echo "Removing firewalld."
# FIXME! clean_requirements_on_remove is the default with DNF, but may
# not work when package was installed by Anaconda instead of command line.
# Also -- check if this is still even needed with new anaconda -- disabled
# firewall should _not_ pull in this package.
# yum -C -y remove "firewalld*" --setopt="clean_requirements_on_remove=1"
dnf -C -y erase "firewalld*"

# Another one needed at install time but not after that, and it pulls
# in some unneeded deps (like, newt and slang)
echo "Removing authconfig."
dnf -C -y erase authconfig

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
cat > /etc/sysconfig/network << EOF
NETWORKING=yes
NOZEROCONF=yes
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

echo "Packages within this vagrant image:"
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

# Default insecure vagrant key
mkdir -m 0700 -p /home/vagrant/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzIw+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoPkcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NOTd0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcWyLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQ== vagrant insecure public key" >> /home/vagrant/.ssh/authorized_keys
chmod 600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh

# Per suggestions from @purpleidea (James Shubin) - extend key to root users as well
mkdir -m 0700 -p /root/.ssh
cp /home/vagrant/.ssh/authorized_keys /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
chown -R root:root /root/.ssh

# I was told this was no longer needed as of F22 - Initial tests suggest that is not true
# Without this Vagrant gets an error when attempting to sudo to root from a non-terminal
# base ssh session.
echo "%vagrant ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/vagrant
sed -i "s/^.*requiretty/#Defaults requiretty/" /etc/sudoers

#echo "Zeroing out empty space."
# This forces the filesystem to reclaim space from deleted files
#dd bs=1M if=/dev/zero of=/var/tmp/zeros || :
#rm -f /var/tmp/zeros
#echo "(Don't worry -- that out-of-space error was expected.)"

%end

%packages --instLangs=en
@^cloud-server-environment
dnf-yum
kernel-core
-NetworkManager
-biosdevname
-dracut-config-rescue
-grub2
-iprutils
-kbd
-kernel
-plymouth
-uboot-tools

%end
