from __future__ import with_statement
"""
This file is OBSCURE.  Really.  The purpose is to avoid copying and changing
'test_c.py' from cffi/c/ in the original CFFI repository:
    https://foss.heptapod.net/pypy/cffi/

Adding a test here involves:
1. add a test to cffi/c/test.py
   - if you need a C function to call, add it into _cffi_backend.c
     as a testfuncNN().
2. have it pass when you run 'py.test test_c.py' in cffi
3. check in and (if you can) push the changes
4. copy test_c.py into _backend_test.py here, killing the few lines of header
   - if you added a C function, it goes into _test_lib.c here
   - if you could complete step 3, try running 'py.test test_file.py' here
5. make the test pass in pypy ('py.test test_c.py')
"""
import py, sys, ctypes

from rpython.tool.udir import udir
from pypy.interpreter import gateway
from pypy.module._cffi_backend.moduledef import Module
from pypy.module._cffi_backend.newtype import _clean_cache, UniqueCache
from rpython.translator import cdir
from rpython.translator.platform import host
from rpython.translator.tool.cbuild import ExternalCompilationInfo

from .. import VERSION as TEST_VERSION


class AppTestC(object):
    """Populated below, hack hack hack."""

    spaceconfig = dict(usemodules=('_cffi_backend', '_io', 'array'))

    def setup_class(cls):
        if cls.runappdirect:
            _cffi_backend = py.test.importorskip('_cffi_backend')
            if _cffi_backend.__version__ != TEST_VERSION:
                py.test.skip(
                    "These tests are for cffi version %s, this Python "
                    "has version %s installed" %
                    (TEST_VERSION, _cffi_backend.__version__))


        testfuncs_w = []
        keepalive_funcs = []
        UniqueCache.for_testing = True

        test_lib_c = tmpdir.join('_test_lib.c')
        src_test_lib_c = py.path.local(__file__).dirpath().join('_test_lib.c')
        src_test_lib_c.copy(test_lib_c)
        eci = ExternalCompilationInfo(include_dirs=[cdir])
        test_lib = str(host.compile([test_lib_c], eci, standalone=False))

        cdll = ctypes.CDLL(test_lib)
        cdll.gettestfunc.restype = ctypes.c_void_p

        space = cls.space
        if cls.runappdirect:
            def find_and_load_library_for_test(name, is_global=False):
                if name is None:
                    path = None
                else:
                    import ctypes.util
                    path = ctypes.util.find_library(name)
                import _cffi_backend
                return _cffi_backend.load_library(path, is_global)

            def w_testfunc_for_test(num):
                import ctypes
                cdll = ctypes.CDLL(str(self.test_lib))
                cdll.gettestfunc.restype = ctypes.c_void_p
                return cdll.gettestfunc(num)

            cls.w_test_lib = space.wrap(test_lib)
            cls.w_func = find_and_load_library_for_test
            cls.w_testfunc = w_testfunc_for_test
        else:
            def find_and_load_library_for_test(space, w_name, w_is_global=None):
                if w_is_global is None:
                    w_is_global = space.wrap(0)
                if space.is_w(w_name, space.w_None):
                    path = None
                    w_name = space.newtext('None')
                else:
                    import ctypes.util
                    path = ctypes.util.find_library(space.text_w(w_name))
                if path is None and sys.platform == 'win32':
                    py.test.skip("cannot find library '%s'" % (space.text_w(w_name),))
                return space.appexec([space.wrap(path), w_is_global],
                """(path, is_global):
                    import _cffi_backend
                    return _cffi_backend.load_library(path, is_global)""")

            def testfunc_for_test(space, w_num):
                if hasattr(space, 'int_w'):
                    w_num = space.int_w(w_num)
                addr = cdll.gettestfunc(w_num)
                return space.wrap(addr)

            cls.w_func = space.wrap(gateway.interp2app(find_and_load_library_for_test))
            cls.w_testfunc = space.wrap(gateway.interp2app(testfunc_for_test))
        cls.w_zz_init = space.appexec(
            [space.wrap(str(tmpdir)), cls.w_func, cls.w_testfunc,
             space.wrap(sys.version[:3])],
        """(path, func, testfunc, underlying_version):
            import sys
            sys.path.append(path)
            import _all_test_c
            _all_test_c.PY_DOT_PY = underlying_version
            _all_test_c.find_and_load_library = func
            _all_test_c._testfunc = testfunc
        """)

    def teardown_method(self, method):
        _clean_cache(self.space)

    def teardown_class(cls):
        UniqueCache.for_testing = False


all_names = ', '.join(Module.interpleveldefs.keys())

backend_test_c = py.path.local(__file__).join('..', '_backend_test_c.py')

lst = []
with backend_test_c.open('r') as f:
    for line in f:
        if line.startswith('def test_'):
            line = line[4:]
            line = line[:line.index('():')]
            lst.append(line)

tmpdir = udir.join('test_c').ensure(dir=1)

tmpname = tmpdir.join('_test_c.py')
with tmpname.open('w') as f:
    for func in lst:
        print >> f, 'def %s(self):' % (func,)
        print >> f, '    import _all_test_c'
        print >> f, '    _all_test_c.%s()' % (func,)

tmpname2 = tmpdir.join('_all_test_c.py')
with tmpname2.open('w') as f:
    print >> f, 'import sys'
    print >> f, 'from _cffi_backend import %s' % all_names
    print >> f, 'class py:'
    print >> f, '    class test:'
    print >> f, '        raises = staticmethod(raises)'
    print >> f, '        skip = staticmethod(skip)'
    print >> f, 'pytest = py.test'
    print >> f, backend_test_c.read()


mod = tmpname.pyimport()
for key, value in mod.__dict__.items():
    if key.startswith('test_'):
        setattr(AppTestC, key, value)
