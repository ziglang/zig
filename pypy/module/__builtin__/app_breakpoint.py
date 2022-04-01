# NOT_RPYTHON
"""
Plain Python definition of the builtin breakpoint function.
"""

import sys

def breakpoint(*args, **kwargs):
    """Call sys.breakpointhook(*args, **kws).  sys.breakpointhook() must accept
whatever arguments are passed.

By default, this drops you into the pdb debugger."""

    if not hasattr(sys, 'breakpointhook'):
        raise RuntimeError('lost sys.breakpointhook')
    return sys.breakpointhook(*args, **kwargs)
