import sys
from pypy.interpreter.mixedmodule import MixedModule


class Module(MixedModule):
    appleveldefs = {
    }

    interpleveldefs = {
        'enable': 'handler.enable',
        'disable': 'handler.disable',
        'is_enabled': 'handler.is_enabled',
#        'register': 'interp_faulthandler.register',
#
        'dump_traceback': 'handler.dump_traceback',
#
        '_read_null': 'handler.read_null',
        '_sigsegv': 'handler.sigsegv',
        '_sigfpe': 'handler.sigfpe',
        '_sigabrt': 'handler.sigabrt',
        '_stack_overflow': 'handler.stack_overflow',
    }

    def setup_after_space_initialization(self):
        """NOT_RPYTHON"""
        if self.space.config.translation.thread:
            self.extra_interpdef('dump_traceback_later',
                                 'handler.dump_traceback_later')
            self.extra_interpdef('cancel_dump_traceback_later',
                                 'handler.cancel_dump_traceback_later')
        if sys.platform != 'win32':
            self.extra_interpdef('register', 'handler.register')
            self.extra_interpdef('unregister', 'handler.unregister')

    def shutdown(self, space):
        from pypy.module.faulthandler import handler
        handler.finish(space)
        MixedModule.shutdown(self, space)
