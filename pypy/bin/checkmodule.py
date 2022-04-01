#! /usr/bin/env python
"""
Usage:  checkmodule.py <module-name>

Check annotation and rtyping of the PyPy extension module from
pypy/module/<module-name>/.  Useful for testing whether a
modules compiles without doing a full translation.
"""
import sys, os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

from pypy.objspace.fake.checkmodule import checkmodule

def main(argv):
    if len(argv) != 2:
        print >> sys.stderr, __doc__
        sys.exit(2)
    modname = argv[1]
    if modname in ('-h', '--help'):
        print >> sys.stderr, __doc__
        sys.exit(0)
    if modname.startswith('-'):
        print >> sys.stderr, "Bad command line"
        print >> sys.stderr, __doc__
        sys.exit(1)
    if os.path.sep in modname:
        if os.path.basename(modname) == '':
            modname = os.path.dirname(modname)
        if os.path.basename(os.path.dirname(modname)) != 'module':
            print >> sys.stderr, "Must give '../module/xxx', or just 'xxx'."
            sys.exit(1)
        modname = os.path.basename(modname)
    try:
        checkmodule(modname)
    except Exception:
        import traceback, pdb
        traceback.print_exc()
        pdb.post_mortem(sys.exc_info()[2])
        return 1
    else:
        print 'Passed.'
        return 0

if __name__ == '__main__':
    sys.exit(main(sys.argv))
