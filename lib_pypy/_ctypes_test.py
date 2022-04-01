import imp
import os

try:
    import cpyext
except ImportError:
    raise ModuleNotFoundError("No module named '_ctypes_test'", name='_ctypes_test')
try:
    import _ctypes
    _ctypes.PyObj_FromPtr = None
    del _ctypes
except ImportError:
    pass    # obscure condition of _ctypes_test.py being imported by py.test
else:
    import _pypy_testcapi
    cfile = '_ctypes_test.c'
    thisdir = os.path.dirname(__file__)
    output_dir = _pypy_testcapi.get_hashed_dir(os.path.join(thisdir, cfile))
    try:
        fp, filename, description = imp.find_module('_ctypes_test', path=[output_dir])
        with fp:
            mod = imp.load_module('_ctypes_test', fp, filename, description)
    except ImportError:
        if os.name == 'nt':
            # hack around finding compilers on win32
            try:
                import setuptools
            except ImportError:
                pass
        mod = _pypy_testcapi.compile_shared(cfile, '_ctypes_test', output_dir)
        fp, filename, description = imp.find_module('_ctypes_test', path=[output_dir])
    # importing via load_module skips setting the __file__
    mod.__file__ = filename
    

