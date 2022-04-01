"""
Plain Python definition of the builtin functions related to run-time
program introspection.
"""

import sys

from __pypy__ import lookup_special

def _caller_locals():
    return sys._getframe(0).f_locals

def vars(*obj):
    """Return a dictionary of all the attributes currently bound in obj.  If
    called with no argument, return the variables bound in local scope."""

    if len(obj) == 0:
        return _caller_locals()
    elif len(obj) != 1:
        raise TypeError("vars() takes at most 1 argument.")
    try:
        return obj[0].__dict__
    except AttributeError:
        raise TypeError("vars() argument must have __dict__ attribute")

# These are defined in the types module, but we cannot always import it.
# virtualenv when run with -S for instance. Instead, copy the code to create
# the needed types to be checked.
class types(object):
    class _C:
        def _m(self): pass
    ModuleType = type(sys)
    ClassType = type(_C)
    TypeType = type
    _x = _C()
    InstanceType = type(_x)

def dir(*args):
    """dir([object]) -> list of strings

    Return an alphabetized list of names comprising (some of) the attributes
    of the given object, and of attributes reachable from it:

    No argument:  the names in the current scope.
    Module object:  the module attributes.
    Type or class object:  its attributes, and recursively the attributes of
        its bases.
    Otherwise:  its attributes, its class's attributes, and recursively the
        attributes of its class's base classes.
    """
    if len(args) > 1:
        raise TypeError("dir expected at most 1 arguments, got %d" % len(args))
    if len(args) == 0:
        return sorted(_caller_locals().keys()) # 2 stackframes away

    obj = args[0]
    dir_meth = lookup_special(obj, '__dir__')
    if dir_meth is not None:
        # obscure: lookup_special won't bind None.__dir__!
        result = dir_meth(obj) if obj is None else dir_meth()
        # Will throw TypeError if not iterable
        return sorted(result)
    # we should never reach here since object.__dir__ exists
    return []
