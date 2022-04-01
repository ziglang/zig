from rpython.rlib.debug import debug_start, debug_stop, debug_print
from rpython.jit.metainterp.jitexc import JitException


class InvalidLoop(JitException):
    """Raised when the optimize*.py detect that the loop that
    we are trying to build cannot possibly make sense as a
    long-running loop (e.g. it cannot run 2 complete iterations)."""

    def __init__(self, msg='?'):
        debug_start("jit-abort")
        debug_print(msg)
        debug_stop("jit-abort")
        self.msg = msg

class SpeculativeError(JitException):
    """Raised when speculative heap access would be ill-typed,
    which should only occur when optimizing the unrolled loop."""
