"""
Implementation of the 'sys._current_frames()' routine.
"""


def _current_frames(space):
    """_current_frames() -> dictionary

    Return a dictionary mapping each current thread T's thread id to T's
    current stack frame.  Functions in the traceback module can build the
    call stack given such a frame.

    Note that in PyPy with the JIT, calling this function causes a runtime
    penalty in all threads, depending on the internal JIT state.  In each
    thread, the penalty should only be noticeable if this call was done
    while in the middle of a long-running function.

    This function should be used for specialized purposes only."""
    w_result = space.newdict()
    ecs = space.threadlocals.getallvalues()
    for thread_ident, ec in ecs.items():
        w_topframe = ec.gettopframe_nohidden()
        if w_topframe is None:
            continue
        space.setitem(w_result,
                      space.newint(thread_ident),
                      w_topframe)
    return w_result
