import sys
import os
ROOT =  os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
print ROOT
sys.path.insert(0, str(ROOT))
import time
from pypy.interpreter.pyparser import pyparse

from pypy.tool.ann_override import PyPyAnnotatorPolicy
from pypy.tool.pytest.objspace import gettestobjspace

space = gettestobjspace()


def bench(fn, s):
    a = time.time()
    info = pyparse.CompileInfo("<string>", "exec")
    info.encoding = "utf-8"
    parser = pyparse.PegParser(space)
    tree = parser._parse(s, info)
    b = time.time()
    print fn, (b-a)


def entry_point(argv):
    if len(argv) >= 2:
        fns = argv[1:]
    else:
        fns = ["../../../../rpython/rlib/unicodedata/unicodedb_5_2_0.py"]
    for fn in fns:
        fd = os.open(fn, os.O_RDONLY, 0777)
        res = []
        while True:
            s = os.read(fd, 4096)
            if not s:
                break
            res.append(s)
        os.close(fd)
        s = "".join(res)
        print len(s)
        bench(fn, s)

    return 0

# _____ Define and setup target ___

def target(*args):
    return entry_point, None, PyPyAnnotatorPolicy()

if __name__ == '__main__':
    entry_point(sys.argv)
