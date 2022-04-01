# This __init__.py shows up in PyPy's app-level standard library.
# Let's try to prevent that confusion...
if __name__ != 'lib_pypy':
    raise ModuleNotFoundError('__init__', name='__init__')
