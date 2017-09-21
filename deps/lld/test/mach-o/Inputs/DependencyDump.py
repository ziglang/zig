# -*- Python -*-


#
# Dump out Xcode binary dependency file.
#

import sys

f = open(sys.argv[1], "rb")
byte = f.read(1)
while byte != b'':
    if byte == b'\000':
        sys.stdout.write("linker-vers: ")
    elif byte == b'\020':
        sys.stdout.write("input-file:  ")
    elif byte == b'\021':
        sys.stdout.write("not-found:   ")
    elif byte == b'\100':
        sys.stdout.write("output-file: ")
    byte = f.read(1)
    while byte != b'\000':
        if byte != b'\012':
            sys.stdout.write(byte.decode("ascii"))
        byte = f.read(1)
    sys.stdout.write("\n")
    byte = f.read(1)

f.close()

