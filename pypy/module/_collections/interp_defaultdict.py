from pypy.interpreter.error import OperationError

def missing(space, w_self, w_key):
    # An interp-level version of this method.  This is mostly only
    # useful because it can be executed atomically in the presence of
    # threads.
    w_default_factory = space.getattr(w_self, space.newtext('default_factory'))
    if space.is_w(w_default_factory, space.w_None):
        raise OperationError(space.w_KeyError, space.newtuple([w_key]))
    w_value = space.call_function(w_default_factory)
    space.setitem(w_self, w_key, w_value)
    return w_value
