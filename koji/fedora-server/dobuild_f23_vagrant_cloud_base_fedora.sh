koji image-build \
  f24-fedora-server-imcleod-scratch 1 f24-candidate \
  http://kojipkgs.fedoraproject.org/mash/rawhide-20160121/rawhide/x86_64/os/ x86_64 \
  --release=1 \
  --distro Fedora-20 \
  --kickstart=./fedora-server-vagrant.ks \
  --format=qcow2 \
  --format=vsphere-ova \
  --format=rhevm-ova \
  --ova-option vsphere_ova_format=vagrant-virtualbox \
  --ova-option rhevm_ova_format=vagrant-libvirt \
  --scratch \
  --nowait \
  --disk-size=40
