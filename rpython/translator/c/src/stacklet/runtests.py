import os, sys



for i in range(2000):
    err = os.system("%s %d" % (sys.argv[1], i))
    if err != 0:
        raise OSError("return code %r" % (err,))
