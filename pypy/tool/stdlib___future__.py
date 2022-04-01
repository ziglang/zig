# load __future__.py constants

def load_module():
    from pypy.tool.lib_pypy import LIB_PYTHON
    module_path = LIB_PYTHON.join('__future__.py')
    execfile(str(module_path), globals())

load_module()
del load_module

# this could be generalized, it's also in opcode.py
