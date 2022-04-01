from rpython.rlib import types


def signature(*paramtypes, **kwargs):
    """Decorate a function to specify its type signature.

    Usage:
      @signature(param1type, param2type, ..., returns=returntype)
      def foo(...)

    The arguments paramNtype and returntype should be instances
    of the classes in rpython.rlib.types.
    """
    returntype = kwargs.pop('returns', None)
    if returntype is None:
        raise TypeError("signature: parameter 'returns' required")

    def decorator(f):
        f._signature_ = (paramtypes, returntype)
        return f
    return decorator


def finishsigs(cls):
    """Decorate a class to finish any method signatures involving types.self().

    This is required if any method has a signature with types.self() in it.
    """
    # A bit annoying to have to use this, but it avoids performing any
    # terrible hack in the implementation.  Eventually we'll offer signatures
    # on classes, and then that decorator can do this on the side.
    def fix(sigtype):
        if isinstance(sigtype, types.SelfTypeMarker):
            return types.instance(cls)
        return sigtype
    for attr in cls.__dict__.values():
        if hasattr(attr, '_signature_'):
            paramtypes, returntype = attr._signature_
            attr._signature_ = (tuple(fix(t) for t in paramtypes), fix(returntype))
    return cls


class FieldSpec(object):
    def __init__(self, tp):
        pass


class ClassSpec(object):
    def __init__(self, fields, inherit=False):
        pass
