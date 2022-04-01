# NOT_RPYTHON
"""
The 'sys' module.
"""

from _structseq import structseqtype, structseqfield, SimpleNamespace
import sys
import _imp
from __pypy__.os import _get_multiarch


def excepthook(exctype, value, traceback):
    """Handle an exception by displaying it with a traceback on sys.stderr."""
    if not isinstance(value, BaseException):
        sys.stderr.write("TypeError: print_exception(): Exception expected for "
                         "value, {} found\n".format(type(value).__name__))
        return

    # Flush stdout as well, both files may refer to the same file
    try:
        sys.stdout.flush()
    except:
        pass

    try:
        from traceback import print_exception, format_exception_only
        limit = getattr(sys, 'tracebacklimit', None)
        if isinstance(limit, int):
            # ok, this is bizarre, but, the meaning of sys.tracebacklimit is
            # understood differently in the traceback module than in
            # PyTraceBack_Print in CPython, see
            # https://bugs.python.org/issue38197
            # one is counting from the top, the other from the bottom of the
            # stack. so reverse polarity here
            if limit > 0:
                if limit > sys.maxsize:
                    limit = sys.maxsize
                print_exception(exctype, value, traceback, limit=-limit)
            else:
                # the limit is 0 or negative. PyTraceBack_Print does not print
                # Traceback (most recent call last):
                # because there is indeed no traceback.
                # the traceback module don't care
                for line in format_exception_only(exctype, value):
                    print(line, end="", file=sys.stderr)

        else:
            print_exception(exctype, value, traceback)
    except:
        if not excepthook_failsafe(exctype, value):
            raise

def excepthook_failsafe(exctype, value):
    # This version carefully tries to handle all bad cases (e.g. an
    # ImportError looking for traceback.py), but may still raise.
    # If it does, we get "Error calling sys.excepthook" from app_main.py.
    try:
        # first try to print the exception's class name
        stderr = sys.stderr
        stderr.write(str(getattr(exctype, '__name__', exctype)))
        # then attempt to get the str() of the exception
        try:
            s = str(value)
        except:
            s = '<failure of str() on the exception instance>'
        # then print it
        if s:
            stderr.write(': %s\n' % (s,))
        else:
            stderr.write('\n')
        return True     # successfully printed at least the class and value
    except:
        return False    # got an exception again... ignore, report the original

def breakpointhook(*args, **kwargs):
    """This hook function is called by built-in breakpoint()."""

    import importlib, os, warnings

    hookname = os.getenv('PYTHONBREAKPOINT')
    if hookname is None or len(hookname) == 0:
        hookname = 'pdb.set_trace'
    elif hookname == '0':
        return None
    modname, dot, funcname = hookname.rpartition('.')
    if dot == '':
        modname = 'builtins'

    try:
        module = importlib.import_module(modname)
        hook = getattr(module, funcname)
    except:
        warnings.warn(
            'Ignoring unimportable $PYTHONBREAKPOINT: "{}"'.format(hookname),
            RuntimeWarning)
        return None

    return hook(*args, **kwargs)

def exit(exitcode=None):
    """Exit the interpreter by raising SystemExit(exitcode).
If the exitcode is omitted or None, it defaults to zero (i.e., success).
If the exitcode is numeric, it will be used as the system exit status.
If it is another kind of object, it will be printed and the system
exit status will be one (i.e., failure)."""
    # note that we cannot simply use SystemExit(exitcode) here.
    # in the default branch, we use "raise SystemExit, exitcode",
    # which leads to an extra de-tupelizing
    # in normalize_exception, which is exactly like CPython's.
    if isinstance(exitcode, tuple):
        raise SystemExit(*exitcode)
    raise SystemExit(exitcode)

#import __builtin__

def callstats():
    """Not implemented."""
    return None

copyright_str = """
Copyright 2003-2021 PyPy development team.
All Rights Reserved.
For further information, see <http://pypy.org>

Portions Copyright (c) 2001-2021 Python Software Foundation.
All Rights Reserved.

Portions Copyright (c) 2000 BeOpen.com.
All Rights Reserved.

Portions Copyright (c) 1995-2001 Corporation for National Research Initiatives.
All Rights Reserved.

Portions Copyright (c) 1991-1995 Stichting Mathematisch Centrum, Amsterdam.
All Rights Reserved.
"""

# Keep synchronized with pypy.interpreter.app_main.sys_flags and
# pypy.module.cpyext._flags

# This is tested in test_app_main.py
class sysflags(metaclass=structseqtype):
    name = "sys.flags"

    debug = structseqfield(0)
    inspect = structseqfield(1)
    interactive = structseqfield(2)
    optimize = structseqfield(3)
    dont_write_bytecode = structseqfield(4)
    no_user_site = structseqfield(5)
    no_site = structseqfield(6)
    ignore_environment = structseqfield(7)
    verbose = structseqfield(8)
    bytes_warning = structseqfield(9)
    quiet = structseqfield(10)
    hash_randomization = structseqfield(11)
    isolated = structseqfield(12)
    dev_mode = structseqfield(13)
    utf8_mode = structseqfield(14)

# no clue why dev_mode in particular has to be a bool, but CPython has tests
# for that
null_sysflags = sysflags((0,)*13 + (False, 0))
null__xoptions = {}

# copied from version.py
def tuple2hex(ver):
    levels = {'alpha':     0xA,
              'beta':      0xB,
              'candidate': 0xC,
              'final':     0xF,
              }
    subver = ver[4]
    if not (0 <= subver <= 9):
        subver = 0
    return (ver[0] << 24   |
            ver[1] << 16   |
            ver[2] << 8    |
            levels[ver[3]] << 4 |
            subver)

implementation_dict = {
    'name':       'pypy',
    'version':    sys.pypy_version_info,
    'hexversion': tuple2hex(sys.pypy_version_info),
    'cache_tag':  _imp.get_tag(),
}

multiarch = _get_multiarch()
if multiarch:
    implementation_dict['_multiarch'] = multiarch

implementation = SimpleNamespace(**implementation_dict)
