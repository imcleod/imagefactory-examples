#!/usr/bin/python
import imgfac.FactoryUtils
import sys

# Run the Factory inspection code and, if successful, list the root directory

# usage - ./just_inspect.py <disk_image_file>

g = imgfac.FactoryUtils.launch_inspect_and_mount(sys.argv[1])
print g.ls("/")

