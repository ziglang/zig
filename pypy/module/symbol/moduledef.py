"""Dynamic replacement for the stdlib 'symbol' module.

This module exports the symbol values computed by the grammar parser
at run-time.
"""

from pypy.interpreter.mixedmodule import MixedModule
from pypy.interpreter.pyparser import pygram


class Module(MixedModule):
    """Non-terminal symbols of Python grammar."""
    appleveldefs = {}
    interpleveldefs = {}     # see below


def _init_symbols():
    sym_name = {}
    for name, val in pygram.python_grammar.symbol_ids.iteritems():
        Module.interpleveldefs[name] = 'space.wrap(%d)' % val
        sym_name[val] = name
    Module.interpleveldefs['sym_name'] = 'space.wrap(%r)' % (sym_name,)

_init_symbols()
