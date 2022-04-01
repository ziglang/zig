import py
import sys, shutil, os
from rpython.tool.udir import udir
from pypy.interpreter.gateway import interp2app
from pypy.module._cffi_backend.newtype import _clean_cache

if sys.platform == 'win32':
    WIN32 = True
else:
    WIN32 = False

class AppTestRecompilerPython:
    spaceconfig = dict(usemodules=['_cffi_backend'])

    def setup_class(cls):
        try:
            from cffi import FFI           # <== the system one, which
            from cffi import recompiler    # needs to be at least cffi 1.0.0
            from cffi import ffiplatform
        except ImportError:
            py.test.skip("system cffi module not found or older than 1.0.0")
        space = cls.space
        SRC = """
        #define FOOBAR (-42)
        static const int FOOBAZ = -43;
        #define BIGPOS 420000000000L
        #define BIGNEG -420000000000L
        int add42(int x) { return x + 42; }
        int globalvar42 = 1234;
        const int globalconst42 = 4321;
        const char *const globalconsthello = "hello";
        struct foo_s;
        typedef struct bar_s { int x; signed char a[]; } bar_t;
        enum foo_e { AA, BB, CC };

        void init_test_re_python(void) { }      /* windows hack */
        void PyInit__test_re_python(void) { }   /* windows hack */
        """
        tmpdir = udir.join('test_re_python')
        tmpdir.ensure(dir=1)
        c_file = tmpdir.join('_test_re_python.c')
        c_file.write(SRC)
        ext = ffiplatform.get_extension(str(c_file), '_test_re_python',
            export_symbols=['add42', 'globalvar42',
                            'globalconst42', 'globalconsthello'])
        outputfilename = ffiplatform.compile(str(tmpdir), ext)
        cls.w_extmod = space.wrap(outputfilename)
        if WIN32:
            unicode_name = u'load\u03betest.dll'
        else:
            unicode_name = u'load_caf\xe9' + os.path.splitext(outputfilename)[1]
            try:
                unicode_name.encode(sys.getfilesystemencoding())
            except UnicodeEncodeError:
                unicode_name = None    # skip test_dlopen_unicode
        if unicode_name is not None:
            outputfileUname = os.path.join(unicode(udir), unicode_name)
            shutil.copyfile(outputfilename, outputfileUname)
            cls.w_extmodU = space.wrap(outputfileUname)
        #mod.tmpdir = tmpdir
        #
        ffi = FFI()
        ffi.cdef("""
        #define FOOBAR -42
        static const int FOOBAZ = -43;
        #define BIGPOS 420000000000L
        #define BIGNEG -420000000000L
        int add42(int);
        int globalvar42;
        const int globalconst42;
        const char *const globalconsthello = "hello";
        int no_such_function(int);
        int no_such_globalvar;
        struct foo_s;
        typedef struct bar_s { int x; signed char a[]; } bar_t;
        enum foo_e { AA, BB, CC };
        typedef struct selfref { struct selfref *next; } *selfref_ptr_t;

        void *dlopen(const char *filename, int flags);
        int dlclose(void *handle);
        """)
        ffi.set_source('re_python_pysrc', None)
        ffi.emit_python_code(str(tmpdir.join('re_python_pysrc.py')))
        #
        sub_ffi = FFI()
        sub_ffi.cdef("static const int k2 = 121212;")
        sub_ffi.include(ffi)
        assert 'macro FOOBAR' in ffi._parser._declarations
        assert 'macro FOOBAZ' in ffi._parser._declarations
        sub_ffi.set_source('re_py_subsrc', None)
        sub_ffi.emit_python_code(str(tmpdir.join('re_py_subsrc.py')))
        #
        cls.w_fix_path = space.appexec([space.wrap(str(tmpdir))], """(path):
            def fix_path(ignored=None):
                import _cffi_backend     # force it to be initialized
                import sys
                if path not in sys.path:
                    sys.path.insert(0, path)
            return fix_path
        """)

        cls.w_dl_libpath = space.w_None
        if sys.platform != 'win32':
            import ctypes.util
            cls.w_dl_libpath = space.wrap(ctypes.util.find_library('dl'))

    def teardown_method(self, meth):
        self.space.appexec([], """():
            import sys
            for name in ['re_py_subsrc', 're_python_pysrc']:
                if name in sys.modules:
                    del sys.modules[name]
        """)
        _clean_cache(self.space)


    def test_constant_1(self):
        self.fix_path()
        from re_python_pysrc import ffi
        assert ffi.integer_const('FOOBAR') == -42
        assert ffi.integer_const('FOOBAZ') == -43

    def test_large_constant(self):
        self.fix_path()
        from re_python_pysrc import ffi
        assert ffi.integer_const('BIGPOS') == 420000000000
        assert ffi.integer_const('BIGNEG') == -420000000000

    def test_function(self):
        import _cffi_backend
        self.fix_path()
        from re_python_pysrc import ffi
        lib = ffi.dlopen(self.extmod)
        assert lib.add42(-10) == 32
        assert type(lib.add42) is _cffi_backend.FFI.CData

    def test_dlopen_unicode(self):
        if not getattr(self, 'extmodU', None):
            skip("no unicode file name")
        import _cffi_backend, sys
        sys.pypy_initfsencoding()   # initialize space.sys.filesystemencoding
        self.fix_path()
        from re_python_pysrc import ffi
        lib = ffi.dlopen(self.extmodU)
        assert lib.add42(-10) == 32

    def test_dlclose(self):
        import _cffi_backend
        self.fix_path()
        from re_python_pysrc import ffi
        lib = ffi.dlopen(self.extmod)
        ffi.dlclose(lib)
        e = raises(ffi.error, getattr, lib, 'add42')
        assert str(e.value) == (
            "library '%s' has been closed" % (self.extmod,))
        ffi.dlclose(lib)   # does not raise

    def test_constant_via_lib(self):
        self.fix_path()
        from re_python_pysrc import ffi
        lib = ffi.dlopen(self.extmod)
        assert lib.FOOBAR == -42
        assert lib.FOOBAZ == -43

    def test_opaque_struct(self):
        self.fix_path()
        from re_python_pysrc import ffi
        ffi.cast("struct foo_s *", 0)
        raises(TypeError, ffi.new, "struct foo_s *")

    def test_nonopaque_struct(self):
        self.fix_path()
        from re_python_pysrc import ffi
        for p in [ffi.new("struct bar_s *", [5, b"foobar"]),
                  ffi.new("bar_t *", [5, b"foobar"])]:
            assert p.x == 5
            assert p.a[0] == ord('f')
            assert p.a[5] == ord('r')

    def test_enum(self):
        self.fix_path()
        from re_python_pysrc import ffi
        assert ffi.integer_const("BB") == 1
        e = ffi.cast("enum foo_e", 2)
        assert ffi.string(e) == "CC"

    def test_include_1(self):
        self.fix_path()
        from re_py_subsrc import ffi
        assert ffi.integer_const('FOOBAR') == -42
        assert ffi.integer_const('FOOBAZ') == -43
        assert ffi.integer_const('k2') == 121212
        lib = ffi.dlopen(self.extmod)     # <- a random unrelated library would be fine
        assert lib.FOOBAR == -42
        assert lib.FOOBAZ == -43
        assert lib.k2 == 121212
        #
        p = ffi.new("bar_t *", [5, b"foobar"])
        assert p.a[4] == ord('a')

    def test_global_var(self):
        self.fix_path()
        from re_python_pysrc import ffi
        lib = ffi.dlopen(self.extmod)
        assert lib.globalvar42 == 1234
        p = ffi.addressof(lib, 'globalvar42')
        lib.globalvar42 += 5
        assert p[0] == 1239
        p[0] -= 1
        assert lib.globalvar42 == 1238

    def test_global_const_int(self):
        self.fix_path()
        from re_python_pysrc import ffi
        lib = ffi.dlopen(self.extmod)
        assert lib.globalconst42 == 4321
        raises(AttributeError, ffi.addressof, lib, 'globalconst42')

    def test_global_const_nonint(self):
        self.fix_path()
        from re_python_pysrc import ffi
        lib = ffi.dlopen(self.extmod)
        assert ffi.string(lib.globalconsthello, 8) == b"hello"
        raises(AttributeError, ffi.addressof, lib, 'globalconsthello')

    def test_rtld_constants(self):
        self.fix_path()
        from re_python_pysrc import ffi
        ffi.RTLD_NOW    # check that we have the attributes
        ffi.RTLD_LAZY
        ffi.RTLD_GLOBAL

    def test_no_such_function_or_global_var(self):
        self.fix_path()
        from re_python_pysrc import ffi
        lib = ffi.dlopen(self.extmod)
        e = raises(ffi.error, getattr, lib, 'no_such_function')
        assert str(e.value).startswith(
            "symbol 'no_such_function' not found in library '")
        e = raises(ffi.error, getattr, lib, 'no_such_globalvar')
        assert str(e.value).startswith(
            "symbol 'no_such_globalvar' not found in library '")

    def test_check_version(self):
        import _cffi_backend
        e = raises(ImportError, _cffi_backend.FFI,
            "foobar", _version=0x2594)
        assert str(e.value).startswith(
            "cffi out-of-line Python module 'foobar' has unknown version")

    def test_selfref(self):
        # based on cffi issue #429
        self.fix_path()
        from re_python_pysrc import ffi
        ffi.new("selfref_ptr_t")

    @py.test.mark.skipif('WIN32', reason='uses "dl" explicitly')
    def test_dlopen_handle(self):
        import _cffi_backend, sys
        self.fix_path()
        from re_python_pysrc import ffi
        lib1 = ffi.dlopen(self.dl_libpath)
        handle = lib1.dlopen(self.extmod.encode(sys.getfilesystemencoding()),
                             _cffi_backend.RTLD_LAZY)
        assert ffi.typeof(handle) == ffi.typeof("void *")
        assert handle

        lib = ffi.dlopen(handle)
        assert lib.add42(-10) == 32
        assert type(lib.add42) is _cffi_backend.FFI.CData

        err = lib1.dlclose(handle)
        assert err == 0
