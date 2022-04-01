# this cffi version was rewritten based on the
# ctypes implementation: Victor Stinner, 2008-05-08
"""
This module provides an interface to the Unix syslog library routines.
Refer to the Unix manual pages for a detailed description of the
syslog facility.
"""

import sys
if sys.platform == 'win32':
    raise ModuleNotFoundError("No syslog on Windows", name="syslog")

try: from __pypy__ import builtinify
except ImportError: builtinify = lambda f: f

from _syslog_cffi import ffi, lib

_S_log_open = False
_S_ident_o = None

def _get_argv():
    try:
        import sys
        script = sys.argv[0]
        if isinstance(script, str):
            # note: CPython <= 3.8 misses the "+1" here, so writes logs
            # with a leading "/".  It is fixed in 3.9.
            # https://github.com/python/cpython/pull/16557
            return script[script.rfind('/')+1:] or None
    except Exception:
        pass
    return None

@builtinify
def openlog(ident=None, logoption=0, facility=lib.LOG_USER):
    global _S_ident_o, _S_log_open
    if ident is None:
        ident = _get_argv()
    if ident is None:
        _S_ident_o = ffi.NULL
    else:
        if not isinstance(ident, str):
            msg = "openlog() argument 1 must be a str, not {!r}"
            raise TypeError(msg.format(type(ident).__name__))
        ident = ident.encode(sys.getdefaultencoding())
        _S_ident_o = ffi.new("char[]", ident)  # keepalive
    lib.openlog(_S_ident_o, logoption, facility)
    _S_log_open = True

@builtinify
def syslog(arg1, arg2=None):
    if arg2 is not None:
        priority, message = arg1, arg2
    else:
        priority, message = LOG_INFO, arg1
    # if log is not opened, open it now
    if not _S_log_open:
        openlog()
    if not isinstance(message, str):
        raise TypeError("syslog() message must be a str, not {!r}".format(
                type(message).__name__))
    message = message.encode(sys.getdefaultencoding())
    lib.syslog(priority, b"%s", message)

@builtinify
def closelog():
    global _S_log_open, S_ident_o
    if _S_log_open:
        lib.closelog()
        _S_log_open = False
        _S_ident_o = None

@builtinify
def setlogmask(mask):
    return lib.setlogmask(mask)

@builtinify
def LOG_MASK(pri):
    return (1 << pri)

@builtinify
def LOG_UPTO(pri):
    return (1 << (pri + 1)) - 1

__all__ = []

for name in dir(lib):
    if name.startswith('LOG_'):
        value = getattr(lib, name)
        if value != -919919:
            globals()[name] = value
            __all__.append(name)

__all__ = tuple(__all__) + (
    'openlog', 'syslog', 'closelog', 'setlogmask',
    'LOG_MASK', 'LOG_UPTO')
