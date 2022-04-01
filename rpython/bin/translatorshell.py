#!/usr/bin/env python


"""RPython Translator Frontend

Glue script putting together the various pieces of the translator.
Can be used for interactive testing of the translator.

Example:

    t = Translation(func, [int])       # pass the list of args types
    t.view()                           # control flow graph

    t.annotate()
    t.view()                           # graph + annotations under the mouse

    t.rtype()                          # use low level operations
    lib = t.compile_c()                # C compilation as a library
    f = get_c_function(lib, func)      # get the function out of the library
    assert f(arg) == func(arg)         # sanity check (for C)


Some functions are provided for the benefit of interactive testing.
Try dir(snippet) for list of current snippets.
"""

import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(
                       os.path.dirname(os.path.realpath(__file__)))))

from rpython.translator.interactive import Translation
from rpython.rtyper.rtyper import *
from rpython.rlib.rarithmetic import *


def get_c_function(lib, f):
    from ctypes import CDLL
    name = f.__name__
    return getattr(CDLL(lib.strpath), 'pypy_g_' + name)


def setup_readline():
    import readline
    try:
        import rlcompleter2
        rlcompleter2.setup()
    except ImportError:
        import rlcompleter
        readline.parse_and_bind("tab: complete")
    import os
    histfile = os.path.join(os.environ["HOME"], ".pypytrhist")
    try:
        getattr(readline, "clear_history", lambda: None)()
        readline.read_history_file(histfile)
    except IOError:
        pass
    import atexit
    atexit.register(readline.write_history_file, histfile)

if __name__ == '__main__':
    try:
        setup_readline()
    except ImportError as err:
        print "Disabling readline support (%s)" % err
    from rpython.translator.test import snippet
    from rpython.rtyper.rtyper import RPythonTyper

    if (os.getcwd() not in sys.path and
        os.path.curdir not in sys.path):
        sys.path.insert(0, os.getcwd())

    print __doc__

    import os
    os.putenv("PYTHONINSPECT", "1")
