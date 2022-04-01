"""
Global Interpreter Lock.
"""

# This module adds a global lock to an object space.
# If multiple threads try to execute simultaneously in this space,
# all but one will be blocked.  The other threads get a chance to run
# from time to time, using the periodic action GILReleaseAction.

from rpython.rlib import rthread, rgil
from pypy.module.thread.error import wrap_thread_error
from pypy.interpreter.executioncontext import PeriodicAsyncAction
from pypy.module.thread.threadlocals import OSThreadLocals

class GILThreadLocals(OSThreadLocals):
    """A version of OSThreadLocals that enforces a GIL."""
    gil_ready = False
    _immutable_fields_ = ['gil_ready?']

    def initialize(self, space):
        # add the GIL-releasing callback as an action on the space
        space.actionflag.register_periodic_action(GILReleaseAction(space),
                                                  use_bytecode_counter=True)

    def setup_threads(self, space):
        """Enable threads in the object space, if they haven't already been."""
        if not self.gil_ready:
            # Note: this is a quasi-immutable read by module/pypyjit/interp_jit
            # It must be changed (to True) only if it was really False before
            rgil.allocate()
            self.gil_ready = True
            result = True
        else:
            result = False      # already set up
        return result

    def threads_initialized(self):
        return self.gil_ready

    ## def reinit_threads(self, space):
    ##     "Called in the child process after a fork()"
    ##     OSThreadLocals.reinit_threads(self, space)


class GILReleaseAction(PeriodicAsyncAction):
    """An action called every sys.checkinterval bytecodes.  It releases
    the GIL to give some other thread a chance to run.
    """

    def perform(self, executioncontext, frame):
        rgil.yield_thread()
