import imp
import os

try:
    import cpyext
except ImportError:
    raise ModuleNotFoundError("No module named '_testmultiphase'", name='_testmultiphase')
import _pypy_testcapi
cfile = '_testmultiphase.c'
thisdir = os.path.dirname(__file__)
output_dir = _pypy_testcapi.get_hashed_dir(os.path.join(thisdir, cfile))
try:
    fp, filename, description = imp.find_module('_testmultiphase', path=[output_dir])
    with fp:
        imp.load_module('_testmultiphase', fp, filename, description)
except ImportError:
    print('could not find _testmultiphase in %s' % output_dir)
    _pypy_testcapi.compile_shared('_testmultiphase.c', '_testmultiphase', output_dir)
