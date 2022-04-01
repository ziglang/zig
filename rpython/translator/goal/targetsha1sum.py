#! /usr/bin/env python

import os, sys
from rpython.rlib.rsha import RSHA

# __________  Entry point  __________

def entry_point(argv):
    for filename in argv[1:]:
        sha = RSHA()
        fd = os.open(filename, os.O_RDONLY, 0)
        while True:
            buf = os.read(fd, 16384)
            if not buf: break
            sha.update(buf)
        os.close(fd)
        print sha.hexdigest(), filename
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None

if __name__ == '__main__':
    from sha import sha as RSHA
    import sys
    res = entry_point(sys.argv)
    sys.exit(res)
