#!/usr/bin/sh

# A simple shell script to automate v2c converstion
# using Image Factory in a container

# argument 1: Path to file containing the image to be converted

# Factory defaults to wanting a root PW in the TDL - this causes
# problems with converted images - just force it
# TODO: Point the working directories at the bind mounted location?

configure_factory () { 
cat << EOF > /etc/imagefactory/imagefactory.conf
{
  "debug": 0,
  "no_ssl": 0,
  "no_oauth": 0,
  "imgdir": "/var/lib/imagefactory/images",
  "ec2_ami_type": "ebs",
  "rhevm_image_format": "qcow2",
  "openstack_image_format": "qcow2",
  "clients": {
    "mock-key": "mock-secret"
    },
  "proxy_ami_id": "ami-id",
  "max_concurrent_local_sessions": 2,
  "max_concurrent_ec2_sessions": 4,
  "ec2-32bit-util": "m1.small",
  "ec2-64bit-util": "m1.large",
  "image_manager": "file",
  "image_manager_args": { "storage_path": "/var/lib/imagefactory/storage" },
  "tdl_require_root_pw": 0,
  "jeos_config": [ "/etc/imagefactory/jeos_images/" ]
}
EOF
}

configure_factory

# If KVM is present, ensure that libvirt can access it
[ -c /dev/kvm ] && chmod a+rw /dev/kvm && echo "Granted open access to KVM"

# Start libvirtd
libvirtd &
LIBVIRTD_PID=$!
echo libvirtd PID is $LIBVIRTD_PID

finish () {
  # Done - kill libvirtd
  echo Killing libvirtd pid $LIBVIRTD_PID
  kill $LIBVIRTD_PID
}

# Do our thing
imagefactory --debug import_base_image $1 > /tmp/base_result
 
grep -q SUCCESSFULLY /tmp/base_result
if [ $? -ne 0 ]; then
  echo FAILED while importing base image
  cat /tmp/base_result
  finish
  exit 1
fi

BASE_UUID=`grep UUID /tmp/base_result | cut -f 2 -d " "`

imagefactory --debug target_image --id $BASE_UUID docker > /tmp/target_result

if [ $? -ne 0 ]; then
   echo FAILED while converting input image to docker
   cat /tmp/target_result 
   finish
   exit 1
fi

TARGET_FILE=`cat /tmp/target_result | grep "Image filename" | cut -f 3 -d " "`

cp $TARGET_FILE /tmp/workdir/v2c_image.tar

finish

sleep 2

echo SUCCESS! - Converted image can be found in the working directory as v2c_image.tar
