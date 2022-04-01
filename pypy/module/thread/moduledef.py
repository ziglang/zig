
# Package initialisation
from pypy.interpreter.mixedmodule import MixedModule

class Module(MixedModule):
    applevel_name = '_thread'

    appleveldefs = {
    }

    interpleveldefs = {
        'start_new_thread':       'os_thread.start_new_thread',
        'start_new':              'os_thread.start_new_thread', # obsolete syn.
        'get_ident':              'os_thread.get_ident',
        'exit':                   'os_thread.exit',
        'exit_thread':            'os_thread.exit', # obsolete synonym
        'interrupt_main':         'os_thread.interrupt_main',
        'stack_size':             'os_thread.stack_size',
        '_count':                 'os_thread._count',
        'allocate_lock':          'os_lock.allocate_lock',
        'allocate':               'os_lock.allocate_lock',  # obsolete synonym
        'LockType':               'os_lock.Lock',
        'RLock':                  'os_lock.W_RLock',
        '_set_sentinel':          'os_lock._set_sentinel',
        '_local':                 'os_local.Local',
        'TIMEOUT_MAX':            'space.wrap(float(os_lock.TIMEOUT_MAX // 1000000))',
        'error':                  'space.w_RuntimeError',
    }

    def __init__(self, space, *args):
        "NOT_RPYTHON: patches space.threadlocals to use real threadlocals"
        from pypy.module.thread import gil
        MixedModule.__init__(self, space, *args)
        prev_ec = space.threadlocals.get_ec()
        space.threadlocals = gil.GILThreadLocals(space)
        space.threadlocals.initialize(space)
        if prev_ec is not None:
            space.threadlocals._set_ec(prev_ec)

        from pypy.module.posix.interp_posix import add_fork_hook
        from pypy.module.thread.os_thread import reinit_threads
        add_fork_hook('child', reinit_threads)
