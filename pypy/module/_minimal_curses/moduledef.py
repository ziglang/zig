try:
    import _curses
except Exception:   # probably ImportError or cffi's VerificationError
    try:
        # when running on top of pypy before it had _curses, settle for minimal
        # we prefer _curses so any constants added make it into _minimal_curses
        import _minimal_curses as _curses
    except ImportError:
        import py
        py.test.skip("no _curses or _minimal_curses module")  # no _curses at all

from pypy.interpreter.mixedmodule import MixedModule


class Module(MixedModule):
    """ Low-level interface for curses module,
    not meant to be used directly
    """

    appleveldefs = {
        'error'          : 'app_curses.error',
    }

    interpleveldefs = {
        'setupterm'      : 'interp_curses.setupterm',
        'tigetstr'       : 'interp_curses.tigetstr',
        'tparm'          : 'interp_curses.tparm',
    }

for i in dir(_curses):
    i = str(i)     # workaround for pypy 2.0-beta2
    val = getattr(_curses, i)
    if i.isupper() and type(val) is int:
        Module.interpleveldefs[i] = "space.wrap(%s)" % val
