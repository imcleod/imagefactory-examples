As of commit 0903c575 we've got basic support for creating HVM AMIs.

HVM, is "full" virt, unlike the Xen based paravirtualization originally offered in EC2/AWS.  An HVM image needs to be a full disk image and it needs to have a bootloader installed.

The existing EC2 code flattens the input base_image into a single filesystem/partition image.  To make hvm work, we've added some parameters to the target portion of the EC2 plugin to disable the flattening and modification of the input base image.  Here is an 

```bash
imagefactory --debug provider_image --parameter offline_icicle true \
             --file-parameter install_script ./fedora-cloud-base-flat.ks \
             --parameter ec2_flatten false \
             --parameter ec2_modify false \
             --parameter ec2_ami_type ebs \
             --parameter ec2_virt_type hvm \
             --template ./fedora-22.tdl \
             ec2 @ec2-us-west-2 ./<your_ec2_credentials>
```

See details at the bottom for how to generate credentials.

Setting "ec2_flatten" to "false" turns off the portion of the plugin that transforms the input image into a single filesystem.

Setting "ec2_modify" to "false" turns off the portion of the pluging that modifies the fstab, network device persistence and miscellaneous other settings to be more EC2 friendly.

You can also set the single "skip_ec2_modifications" parameter to true to disable both of these steps.  (e.g. "--parameter skip_ec2_modifications true")

NOTE: Turning off "ec2_modify" means that you, as the image creator, need to ensure that your input base image is structured appropriately for use in EC2.  See the %post section of the example kickstart in this directory for details on how this is done for Fedora 22.

* EC2 credentials file generation

Run:

```bash
$ /usr/bin/create-ec2-factory-credentials
```

This is an interactive script that accepts your EC2 account ID, access key and secret key and (optionally) x509 certs.

It will save a file called "ec2_credentials.xml" which can be fed into the one-step imagefactory command above.

