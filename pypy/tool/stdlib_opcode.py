"""
Opcodes PyPy compiles Python source to.
Also gives access to opcodes of the host Python PyPy was bootstrapped with
(module attributes with the `host_` prefix).
"""

# load opcode.py as pythonopcode from our own lib

__all__ = ['opmap', 'opname', 'HAVE_ARGUMENT',
           'hasconst', 'hasname', 'hasjrel', 'hasjabs',
           'haslocal', 'hascompare', 'hasfree', 'cmp_op']

# Initialization

from rpython.rlib.unroll import unrolling_iterable
from rpython.tool.stdlib_opcode import BytecodeSpec, host_bytecode_spec

from opcode import (
    opmap as host_opmap, HAVE_ARGUMENT as host_HAVE_ARGUMENT)

def load_pypy_opcode():
    from pypy.tool.lib_pypy import LIB_PYTHON
    opcode_path = LIB_PYTHON.join('opcode.py')
    d = {}
    execfile(str(opcode_path), d)
    for name in __all__:
        if name in d:
            globals()[name] = d[name]
    return d

load_pypy_opcode()
del load_pypy_opcode

bytecode_spec = BytecodeSpec('pypy', opmap, HAVE_ARGUMENT)
bytecode_spec.to_globals(globals())

opcode_method_names = bytecode_spec.method_names
opcodedesc = bytecode_spec.opcodedesc

unrolling_all_opcode_descs = unrolling_iterable(
    bytecode_spec.ordered_opdescs + host_bytecode_spec.ordered_opdescs)
unrolling_opcode_descs = unrolling_iterable(
    bytecode_spec.ordered_opdescs)
