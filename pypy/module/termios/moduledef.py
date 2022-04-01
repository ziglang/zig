from pypy.interpreter.mixedmodule import MixedModule

from rpython.rlib import rtermios

class Module(MixedModule):
    "This module provides an interface to the Posix calls for tty I/O control.\n\
    For a complete description of these calls, see the Posix or Unix manual\n\
    pages. It is only available for those Unix versions that support Posix\n\
    termios style tty I/O control.\n\
    \n\
    All functions in this module take a file descriptor fd as their first\n\
    argument. This can be an integer file descriptor, such as returned by\n\
    sys.stdin.fileno(), or a file object, such as sys.stdin itself."

    appleveldefs = {
    }

    interpleveldefs = {
        'tcdrain'     : 'interp_termios.tcdrain',
        'tcflow'      : 'interp_termios.tcflow',
        'tcflush'     : 'interp_termios.tcflush',
        'tcgetattr'   : 'interp_termios.tcgetattr',
        'tcsendbreak' : 'interp_termios.tcsendbreak',
        'tcsetattr'   : 'interp_termios.tcsetattr',
        'error'       : 'space.fromcache(interp_termios.Cache).w_error',
    }

    for name in rtermios.all_constants:
        value = getattr(rtermios, name)
        interpleveldefs[name] = "space.wrap(%s)" % value
