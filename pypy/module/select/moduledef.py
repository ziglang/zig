# Package initialisation
from pypy.interpreter.mixedmodule import MixedModule

import sys
import os
from rpython.rlib import _rsocket_rffi as _c


class Module(MixedModule):
    appleveldefs = {
    }

    interpleveldefs = {
        'select': 'interp_select.select',
        'error' : 'space.w_OSError',
    }

    if os.name =='posix':
        interpleveldefs['poll'] = 'interp_select.poll'

    if sys.platform.startswith('linux'):
        interpleveldefs['epoll'] = 'interp_epoll.W_Epoll'
        from pypy.module.select.interp_epoll import public_symbols
        for symbol, value in public_symbols.iteritems():
            if value is not None:
                interpleveldefs[symbol] = "space.wrap(%r)" % value

    if 'bsd' in sys.platform or sys.platform.startswith('darwin'):
        interpleveldefs["kqueue"] = "interp_kqueue.W_Kqueue"
        interpleveldefs["kevent"] = "interp_kqueue.W_Kevent"
        from pypy.module.select.interp_kqueue import symbol_map
        for symbol in symbol_map:
            interpleveldefs[symbol] = "space.wrap(interp_kqueue.%s)" % symbol

    if _c.PIPE_BUF is not None:
        interpleveldefs['PIPE_BUF'] = 'space.wrap(%r)' % _c.PIPE_BUF


    def buildloaders(cls):
        from rpython.rlib import rpoll
        for name in rpoll.eventnames:
            value = getattr(rpoll, name)
            Module.interpleveldefs[name] = "space.wrap(%r)" % value
        super(Module, cls).buildloaders()
    buildloaders = classmethod(buildloaders)
