"""readline - Importing this module enables command line editing using
the pyrepl library.  The API is a subset of the GNU readline library.
It also contains extensions for multiline input.

Note that some of the functions present in the CPython module 'readline'
are only stubs at the moment.
"""

try:
    from pyrepl.readline import *
except ImportError:
    import sys
    if sys.platform == 'win32':
        raise ModuleNotFoundError("the 'readline' module is not available on Windows"
                                  " (on either PyPy or CPython)", name="readline")
    raise
