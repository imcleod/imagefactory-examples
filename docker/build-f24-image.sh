#!/bin/bash

sudo imagefactory --debug base_image --file-parameter install_script fedora-docker-base.ks fedora-24-alpha.tdl --parameter offline_icicle true
