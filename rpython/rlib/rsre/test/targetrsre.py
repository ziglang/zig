#!/usr/bin/env python
from rpython.rlib.rarithmetic import intmask
from rpython.rlib.rsre import rsre_core
from rpython.rlib.rsre.rsre_char import MAXREPEAT
import os, time


# <item>\s*<title>(.*?)</title>
r_code1 = [17, 18, 1, 21, 131091, 6, 6, 60, 105, 116, 101, 109, 62, 0,
0, 0, 0, 0, 0, 19, 60, 19, 105, 19, 116, 19, 101, 19, 109, 19, 62, 29,
9, 0, MAXREPEAT, 15, 4, 9, 2, 0, 1, 19, 60, 19, 116, 19, 105, 19, 116, 19,
108, 19, 101, 19, 62, 21, 0, 31, 5, 0, MAXREPEAT, 2, 1, 21, 1, 19, 60, 19,
47, 19, 116, 19, 105, 19, 116, 19, 108, 19, 101, 19, 62, 1]


def read(filename):
    fd = os.open(filename, os.O_RDONLY, 0666)
    if fd < 0:
        raise OSError
    end = os.lseek(fd, 0, 2)
    os.lseek(fd, 0, 0)
    data = os.read(fd, intmask(end))
    os.close(fd)
    return data

def search_in_file(filename):
    data = read(filename)
    p = 0
    while True:
        res = rsre_core.search(r_code1, data, p)
        if res is None:
            break
        matchstart, matchstop = res.span(1)
        assert 0 <= matchstart <= matchstop
        print '%s: %s' % (filename, data[matchstart:matchstop])
        p = res.span(0)[1]

# __________  Entry point  __________

def entry_point(argv):
    start = time.time()
    for fn in argv[1:]:
        search_in_file(fn)
    stop = time.time()
    print stop - start
    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None

# _____ Pure Python equivalent _____

if __name__ == '__main__':
    import re, sys
    r = re.compile(r"<item>\s*<title>(.*?)</title>")
    start = time.time()
    for fn in sys.argv[1:]:
        f = open(fn, 'rb')
        data = f.read()
        f.close()
        for title in r.findall(data):
            print '%s: %s' % (fn, title)
    stop = time.time()
    print '%.4fs' % (stop - start,)
