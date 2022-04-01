from pypy.interpreter.mixedmodule import MixedModule
from pypy.module.errno.interp_errno import name2code

class Module(MixedModule):
    """This module makes available standard errno system symbols.

    The value of each symbol is the corresponding integer value,
    e.g., on most systems, errno.ENOENT equals the integer 2.

    The dictionary errno.errorcode maps numeric codes to symbol names,
    e.g., errno.errorcode[2] could be the string 'ENOENT'.

    Symbols that are not relevant to the underlying system are not defined.

    To map error codes to error messages, use the function os.strerror(),
    e.g. os.strerror(2) could return 'No such file or directory'."""

    appleveldefs = {}
    interpleveldefs = {"errorcode": "interp_errno.get_errorcode(space)"}

for name, code in name2code.iteritems():
    if code is not None:
        Module.interpleveldefs[name] = ("space.newint(%s)" % code)
