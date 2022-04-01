"""
Strip symbols from an executable, but keep them in a .debug file
"""

import sys
import os
import py

def _strip(exe):
    if sys.platform == 'win32':
        pass
    elif sys.platform == 'darwin':
        # 'strip' fun: see issue #587 for why -x
        os.system("strip -x " + str(exe))    # ignore errors
    else:
        os.system("strip " + str(exe))       # ignore errors

def _extract_debug_symbols(exe, debug):
    if sys.platform == 'linux2':
        os.system("objcopy --only-keep-debug %s %s" % (exe, debug))
        os.system("objcopy --add-gnu-debuglink=%s %s" % (debug, exe))
        perm = debug.stat().mode
        perm &= ~(0o111) # remove the 'x' bit
        debug.chmod(perm)

def smartstrip(exe, keep_debug=True):
    exe = py.path.local(exe)
    debug = py.path.local(str(exe) + '.debug')
    if keep_debug:
        _extract_debug_symbols(exe, debug)
    _strip(exe)


if __name__ == '__main__':
    smartstrip(sys.argv[1])
