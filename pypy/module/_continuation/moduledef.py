from pypy.interpreter.mixedmodule import MixedModule


class Module(MixedModule):
    """This module exposes 'one-shot continuation containers'.

A 'continulet' object from this module is a container that stores a
one-shot continuation.  It is similar in purpose to the 'f_back'
attribute of frames, which points to where execution should continue
after this frame finishes.  The difference is that it will be changed
(often repeatedly) before the frame actually returns.

To make a continulet object, call 'continulet' with a callable and
optional extra arguments.  Later, the first time you switch() to the
continulet, the callable is invoked with the same continulet object as
the extra first argument.

At this point, the one-shot continuation stored in the continulet points
to the caller of switch().  When switch() is called again, this one-shot
continuation is exchanged with the current one; it means that the caller
of switch() is suspended, its continuation stored in the container, and
the old continuation from the continulet object is resumed.

Continulets are internally implemented using stacklets.  Stacklets
are a bit more primitive (they are really one-shot continuations), but
that idea only works in C, not in Python, notably because of exceptions.

The most primitive API is actually 'permute()', which just permutes the
one-shot continuation stored in two (or more) continulets.
"""

    appleveldefs = {
        'error': 'app_continuation.error',
        'generator': 'app_continuation.generator',
    }

    interpleveldefs = {
        'continulet': 'interp_continuation.W_Continulet',
        'permute': 'interp_continuation.permute',
        '_p': 'interp_continuation.unpickle',      # pickle support
    }
