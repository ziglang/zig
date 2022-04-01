"""
A benchmark for read()
"""

import os

# __________  Entry point  __________

def entry_point(argv):
    if len(argv) > 2:
        length = int(argv[2])
    else:
        length = 100
    fname = argv[1]
    l = []
    for i in xrange(100000):
        f = os.open(fname, 0666, os.O_RDONLY)
        l.append(os.read(f, length))
        os.close(f)
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None

