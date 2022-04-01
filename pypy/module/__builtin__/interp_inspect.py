
def globals(space):
    "Return the dictionary containing the current scope's global variables."
    ec = space.getexecutioncontext()
    return ec.gettopframe_nohidden().get_w_globals()

def locals(space):
    """Return a dictionary containing the current scope's local variables.
Note that this may be the real dictionary of local variables, or a copy."""
    ec = space.getexecutioncontext()
    return ec.gettopframe_nohidden().getdictscope()

