#!/usr/bin/env python

import sys
import py
from rpython.jit.tl.tla.test_tla import assemble
py.path.local(__file__)

def usage():
    print >> sys.stderr, 'Usage: tla_assembler.py filename.tla.py'
    sys.exit(1)

def main():
    if len(sys.argv) != 2:
        usage()

    filename = sys.argv[1]
    if not filename.endswith('.tla.py'):
        usage()

    outname = filename[:-len('.py')]
    mydict = {}
    execfile(filename, mydict)
    bytecode = assemble(mydict['code'])
    f = open(outname, 'w')
    f.write(bytecode)
    f.close()
    print '%s successfully assembled' % outname

if __name__ == '__main__':
    main()
