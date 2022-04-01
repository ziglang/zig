from pypy.interpreter.mixedmodule import MixedModule

import os

class Module(MixedModule):
    applevel_name = '_signal'

    interpleveldefs = {
        'signal':              'interp_signal.signal',
        'getsignal':           'interp_signal.getsignal',
        'set_wakeup_fd':       'interp_signal.set_wakeup_fd',
        'NSIG':                'space.wrap(interp_signal.NSIG)',
        'SIG_DFL':             'space.wrap(interp_signal.SIG_DFL)',
        'SIG_IGN':             'space.wrap(interp_signal.SIG_IGN)',
        'default_int_handler': 'interp_signal.default_int_handler',
        'ItimerError':         'interp_signal.get_itimer_error(space)',
        'valid_signals':       'interp_signal.valid_signals',
        'raise_signal':        'interp_signal.raise_signal',
        'strsignal':           'interp_signal.strsignal'
    }

    if os.name == 'posix':
        interpleveldefs['alarm'] = 'interp_signal.alarm'
        interpleveldefs['pause'] = 'interp_signal.pause'
        interpleveldefs['siginterrupt'] = 'interp_signal.siginterrupt'

    if os.name == 'posix':
        interpleveldefs['setitimer'] = 'interp_signal.setitimer'
        interpleveldefs['getitimer'] = 'interp_signal.getitimer'
        for name in ['ITIMER_REAL', 'ITIMER_VIRTUAL', 'ITIMER_PROF']:
            interpleveldefs[name] = 'space.wrap(interp_signal.%s)' % (name,)

    if os.name == 'posix':
        interpleveldefs['sigwait'] = 'interp_signal.sigwait'
        interpleveldefs['sigpending'] = 'interp_signal.sigpending'
        interpleveldefs['pthread_kill'] = 'interp_signal.pthread_kill'
        interpleveldefs['pthread_sigmask'] = 'interp_signal.pthread_sigmask'
        interpleveldefs['SIG_BLOCK'] = 'space.wrap(interp_signal.SIG_BLOCK)'
        interpleveldefs['SIG_UNBLOCK'] = 'space.wrap(interp_signal.SIG_UNBLOCK)'
        interpleveldefs['SIG_SETMASK'] = 'space.wrap(interp_signal.SIG_SETMASK)'

    appleveldefs = {
    }

    def buildloaders(cls):
        from rpython.rlib import rsignal

        for name in rsignal.signal_names:
            signum = getattr(rsignal, name)
            if signum is not None:
                Module.interpleveldefs[name] = 'space.wrap(%d)' % (signum,)
        super(Module, cls).buildloaders()
    buildloaders = classmethod(buildloaders)

    def __init__(self, space, *args):
        "NOT_RPYTHON"
        from pypy.module.signal import interp_signal
        MixedModule.__init__(self, space, *args)
        # add the signal-checking callback as an action on the space
        space.check_signal_action = interp_signal.CheckSignalAction(space)
        space.actionflag.register_periodic_action(space.check_signal_action,
                                                  use_bytecode_counter=False)
        if space.reverse_debugging:
            from pypy.interpreter.reverse_debugging import RDBSignalActionFlag
            space.actionflag.__class__ = RDBSignalActionFlag
        else:
            space.actionflag.__class__ = interp_signal.SignalActionFlag
        # xxx yes I know the previous line is a hack

    def startup(self, space):
        space.check_signal_action.startup(space)
