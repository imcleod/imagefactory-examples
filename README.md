imagefactory-examples
=====================

Some examples of how to use Image Factory

Before attempting these please pull down the latest factory code from:

https://github.com/redhat-imaging/imagefactory

Then, starting in the root directory:

$ make rpm
$ cd imagefactory_plugins
$ make rpm

Then install all of the resulting RPMs.


Alternatively, on Fedora or RHEL/CentOS with EPEL, you can get most of the popular features by running:

yum install -y imagefactory imagefactory-plugins imagefactory-plugins-TinMan imagefactory-plugins-Docker \
    imagefactory-plugins-vSphere imagefactory-plugins-OVA imagefactory-plugins-RHEVM imagefactory-plugins-ovfcommon
