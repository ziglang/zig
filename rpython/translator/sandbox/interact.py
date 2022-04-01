#! /usr/bin/env python

"""Interacts with a subprocess translated with --sandbox.
The subprocess is only allowed to use stdin/stdout/stderr.

Usage:
    interact.py <executable> <args...>
"""

import sys
from rpython.translator.sandbox.sandlib import SimpleIOSandboxedProc

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print >> sys.stderr, __doc__
        sys.exit(2)
    SimpleIOSandboxedProc(sys.argv[1:]).interact()
