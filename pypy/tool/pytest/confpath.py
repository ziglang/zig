import py
import pypy
import rpython
from pypy.tool import lib_pypy

pypydir = py.path.local(pypy.__file__).dirpath()
rpythondir = py.path.local(rpython.__file__).dirpath()
distdir = pypydir.dirpath()
testresultdir = distdir.join('testresult') 
assert pypydir.check(dir=1) 
testdir = lib_pypy.LIB_PYTHON.join('test')
