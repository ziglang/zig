import os, pytest

from rpython.tool.udir import udir
from pypy.interpreter.gateway import unwrap_spec, interp2app
from pypy.module._cffi_backend.newtype import _clean_cache
import pypy.module.cpyext.api     # side-effect of pre-importing it
from sysconfig import get_config_var


def get_ext_suffix():
    # soabi is None on cpython < 3.7 (incl 2.7), 'pypy-73' on pypy2 v7.3.1
    # and something like 'cpython-38-x86_64-linux-gnu' on cpython 3.8
    soabi = get_config_var('SOABI') or ''
    ret = soabi + get_config_var('SO')
    # either '.so' or 'pypy-73.so'
    if ret[0] == '.':
        return ret[1:]
    return ret


@unwrap_spec(cdef='text', module_name='text', source='text', packed=int)
def prepare(space, cdef, module_name, source, w_includes=None,
            w_extra_source=None, w_min_version=None, packed=False,
            w_extra_compile_args=None):
    try:
        import cffi
        from cffi import FFI            # <== the system one, which
        from cffi import recompiler     # needs to be at least cffi 1.0.4
        from cffi import ffiplatform
    except ImportError:
        pytest.skip("system cffi module not found or older than 1.0.0")
    if w_min_version is None:
        min_version = (1, 4, 0)
    else:
        min_version = tuple(space.unwrap(w_min_version))
    if cffi.__version_info__ < min_version:
        pytest.skip("system cffi module needs to be at least %s, got %s" % (
            min_version, cffi.__version_info__))
    space.appexec([], """():
        import _cffi_backend     # force it to be initialized
    """)
    includes = []
    if w_includes:
        includes += space.unpackiterable(w_includes)
    assert module_name.startswith('test_')
    module_name = '_CFFI_' + module_name
    rdir = udir.ensure('recompiler', dir=1)
    rdir.join('Python.h').write(
        '#include <stdio.h>\n'
        '#define PYPY_VERSION XX\n'
        '#define PyMODINIT_FUNC /*exported*/ void\n'
        )
    path = module_name.replace('.', os.sep)
    if '.' in module_name:
        subrdir = rdir.join(module_name[:module_name.index('.')])
        os.mkdir(str(subrdir))
    else:
        subrdir = rdir
    c_file  = str(rdir.join('%s.c'  % path))
    ffi = FFI()
    for include_ffi_object in includes:
        ffi.include(include_ffi_object._test_recompiler_source_ffi)
    ffi.cdef(cdef, packed=packed)
    ffi.set_source(module_name, source)
    ffi.emit_c_code(c_file)

    base_module_name = module_name.split('.')[-1]
    sources = []
    if w_extra_source is not None:
        sources.append(space.text_w(w_extra_source))
    kwargs = {}
    if w_extra_compile_args is not None:
        kwargs['extra_compile_args'] = space.unwrap(w_extra_compile_args)
    ext = ffiplatform.get_extension(c_file, module_name,
            include_dirs=[str(rdir)],
            export_symbols=['_cffi_pypyinit_' + base_module_name],
            sources=sources,
            **kwargs)
    ffiplatform.compile(str(rdir), ext)

    for extension in [get_ext_suffix(), 'so', 'pyd', 'dylib']:
        so_file = str(rdir.join('%s.%s' % (path, extension)))
        if os.path.exists(so_file):
            break
    else:
        raise Exception("could not find the compiled extension module?")

    args_w = [space.wrap(module_name), space.wrap(so_file)]
    w_res = space.appexec(args_w, """(modulename, filename):
        import _imp
        class Spec: pass
        spec = Spec()
        spec.name = modulename
        spec.origin = filename
        mod = _imp.create_dynamic(spec)
        assert mod.__name__ == modulename
        return (mod.ffi, mod.lib)
    """)
    ffiobject = space.getitem(w_res, space.wrap(0))
    ffiobject._test_recompiler_source_ffi = ffi
    if not hasattr(space, '_cleanup_ffi'):
        space._cleanup_ffi = []
    space._cleanup_ffi.append(ffiobject)
    return w_res


class AppTestRecompiler:
    spaceconfig = dict(usemodules=['_cffi_backend', 'imp', 'cpyext', 'struct'])

    def setup_class(cls):
        if cls.runappdirect:
            pytest.skip("not a test for -A")
        cls.w_prepare = cls.space.wrap(interp2app(prepare))
        cls.w_udir = cls.space.wrap(str(udir))
        cls.w_os_sep = cls.space.wrap(os.sep)

    def setup_method(self, meth):
        self._w_modules = self.space.appexec([], """():
            import cpyext      # ignore stuff there in the leakfinder
            import sys
            return set(sys.modules)
        """)

    def teardown_method(self, meth):
        if hasattr(self.space, '_cleanup_ffi'):
            for ffi in self.space._cleanup_ffi:
                del ffi.cached_types     # try to prevent cycles
            del self.space._cleanup_ffi
        self.space.appexec([self._w_modules], """(old_modules):
            import sys
            for key in list(sys.modules.keys()):
                if key not in old_modules:
                    del sys.modules[key]
        """)
        _clean_cache(self.space)

    def test_math_sin(self):
        import math
        ffi, lib = self.prepare(
            "float sin(double); double cos(double);",
            'test_math_sin',
            '#include <math.h>')
        assert lib.cos(1.43) == math.cos(1.43)

    def test_repr_lib(self):
        ffi, lib = self.prepare(
            "",
            'test_repr_lib',
            "")
        assert repr(lib) == "<Lib object for '_CFFI_test_repr_lib'>"

    def test_funcarg_ptr(self):
        ffi, lib = self.prepare(
            "int foo(int *);",
            'test_funcarg_ptr',
            'int foo(int *p) { return *p; }')
        assert lib.foo([-12345]) == -12345

    def test_funcres_ptr(self):
        ffi, lib = self.prepare(
            "int *foo(void);",
            'test_funcres_ptr',
            'int *foo(void) { static int x=-12345; return &x; }')
        assert lib.foo()[0] == -12345

    def test_global_var_array(self):
        ffi, lib = self.prepare(
            "int a[100];",
            'test_global_var_array',
            'int a[100] = { 9999 };')
        lib.a[42] = 123456
        assert lib.a[42] == 123456
        assert lib.a[0] == 9999

    def test_verify_typedef(self):
        ffi, lib = self.prepare(
            "typedef int **foo_t;",
            'test_verify_typedef',
            'typedef int **foo_t;')
        assert ffi.sizeof("foo_t") == ffi.sizeof("void *")

    def test_verify_typedef_dotdotdot(self):
        ffi, lib = self.prepare(
            "typedef ... foo_t;",
            'test_verify_typedef_dotdotdot',
            'typedef int **foo_t;')
        # did not crash

    def test_verify_typedef_star_dotdotdot(self):
        ffi, lib = self.prepare(
            "typedef ... *foo_t;",
            'test_verify_typedef_star_dotdotdot',
            'typedef int **foo_t;')
        # did not crash

    def test_global_var_int(self):
        ffi, lib = self.prepare(
            "int a, b, c;",
            'test_global_var_int',
            'int a = 999, b, c;')
        assert lib.a == 999
        lib.a -= 1001
        assert lib.a == -2
        lib.a = -2147483648
        assert lib.a == -2147483648
        raises(OverflowError, "lib.a = 2147483648")
        raises(OverflowError, "lib.a = -2147483649")
        lib.b = 525      # try with the first access being in setattr, too
        assert lib.b == 525
        raises(AttributeError, "del lib.a")
        raises(AttributeError, "del lib.c")
        raises(AttributeError, "del lib.foobarbaz")

    def test_macro(self):
        ffi, lib = self.prepare(
            "#define FOOBAR ...",
            'test_macro',
            "#define FOOBAR (-6912)")
        assert lib.FOOBAR == -6912
        raises(AttributeError, "lib.FOOBAR = 2")

    def test_macro_check_value(self):
        # the value '-0x80000000' in C sources does not have a clear meaning
        # to me; it appears to have a different effect than '-2147483648'...
        # Moreover, on 32-bits, -2147483648 is actually equal to
        # -2147483648U, which in turn is equal to 2147483648U and so positive.
        import sys
        vals = ['42', '-42', '0x80000000', '-2147483648',
                '0', '9223372036854775809ULL',
                '-9223372036854775807LL']
        if sys.maxsize <= 2**32:
            vals.remove('-2147483648')

        cdef_lines = ['#define FOO_%d_%d %s' % (i, j, vals[i])
                      for i in range(len(vals))
                      for j in range(len(vals))]

        verify_lines = ['#define FOO_%d_%d %s' % (i, j, vals[j])  # [j], not [i]
                        for i in range(len(vals))
                        for j in range(len(vals))]

        ffi, lib = self.prepare(
            '\n'.join(cdef_lines),
            'test_macro_check_value_ok',
            '\n'.join(verify_lines))

        for j in range(len(vals)):
            c_got = int(vals[j].replace('U', '').replace('L', ''), 0)
            c_compiler_msg = str(c_got)
            if c_got > 0:
                c_compiler_msg += ' (0x%x)' % (c_got,)
            #
            for i in range(len(vals)):
                attrname = 'FOO_%d_%d' % (i, j)
                if i == j:
                    x = getattr(lib, attrname)
                    assert x == c_got
                else:
                    e = raises(ffi.error, getattr, lib, attrname)
                    assert str(e.value) == (
                        "the C compiler says '%s' is equal to "
                        "%s, but the cdef disagrees" % (attrname, c_compiler_msg))

    def test_constant(self):
        ffi, lib = self.prepare(
            "static const int FOOBAR;",
            'test_constant',
            "#define FOOBAR (-6912)")
        assert lib.FOOBAR == -6912
        raises(AttributeError, "lib.FOOBAR = 2")

    def test_check_value_of_static_const(self):
        ffi, lib = self.prepare(
            "static const int FOOBAR = 042;",
            'test_check_value_of_static_const',
            "#define FOOBAR (-6912)")
        e = raises(ffi.error, getattr, lib, 'FOOBAR')
        assert str(e.value) == (
           "the C compiler says 'FOOBAR' is equal to -6912, but the cdef disagrees")

    def test_constant_nonint(self):
        ffi, lib = self.prepare(
            "static const double FOOBAR;",
            'test_constant_nonint',
            "#define FOOBAR (-6912.5)")
        assert lib.FOOBAR == -6912.5
        raises(AttributeError, "lib.FOOBAR = 2")

    def test_constant_ptr(self):
        ffi, lib = self.prepare(
            "static double *const FOOBAR;",
            'test_constant_ptr',
            "#define FOOBAR NULL")
        assert lib.FOOBAR == ffi.NULL
        assert ffi.typeof(lib.FOOBAR) == ffi.typeof("double *")

    def test_dir(self):
        ffi, lib = self.prepare(
            "int ff(int); int aa; static const int my_constant;",
            'test_dir', """
            #define my_constant  (-45)
            int aa;
            int ff(int x) { return x+aa; }
        """)
        lib.aa = 5
        assert dir(lib) == ['aa', 'ff', 'my_constant']
        #
        aaobj = lib.__dict__['aa']
        assert not isinstance(aaobj, int)    # some internal object instead
        assert lib.__dict__ == {
            'ff': lib.ff,
            'aa': aaobj,
            'my_constant': -45}
        lib.__dict__['ff'] = "??"
        assert lib.ff(10) == 15

    def test_verify_opaque_struct(self):
        ffi, lib = self.prepare(
            "struct foo_s;",
            'test_verify_opaque_struct',
            "struct foo_s;")
        assert ffi.typeof("struct foo_s").cname == "struct foo_s"

    def test_verify_opaque_union(self):
        ffi, lib = self.prepare(
            "union foo_s;",
            'test_verify_opaque_union',
            "union foo_s;")
        assert ffi.typeof("union foo_s").cname == "union foo_s"

    def test_verify_struct(self):
        ffi, lib = self.prepare(
            """struct foo_s { int b; short a; ...; };
               struct bar_s { struct foo_s *f; };""",
            'test_verify_struct',
            """struct foo_s { short a; int b; };
               struct bar_s { struct foo_s *f; };""")
        ffi.typeof("struct bar_s *")
        p = ffi.new("struct foo_s *", {'a': -32768, 'b': -2147483648})
        assert p.a == -32768
        assert p.b == -2147483648
        raises(OverflowError, "p.a -= 1")
        raises(OverflowError, "p.b -= 1")
        q = ffi.new("struct bar_s *", {'f': p})
        assert q.f == p
        #
        assert ffi.offsetof("struct foo_s", "a") == 0
        assert ffi.offsetof("struct foo_s", "b") == 4
        assert ffi.offsetof(u"struct foo_s", u"b") == 4
        #
        raises(TypeError, ffi.addressof, p)
        assert ffi.addressof(p[0]) == p
        assert ffi.typeof(ffi.addressof(p[0])) is ffi.typeof("struct foo_s *")
        assert ffi.typeof(ffi.addressof(p, "b")) is ffi.typeof("int *")
        assert ffi.addressof(p, "b")[0] == p.b

    def test_verify_exact_field_offset(self):
        ffi, lib = self.prepare(
            """struct foo_s { int b; short a; };""",
            'test_verify_exact_field_offset',
            """struct foo_s { short a; int b; };""")
        e = raises(ffi.error, ffi.new, "struct foo_s *", [])    # lazily
        assert str(e.value).startswith(
            "struct foo_s: wrong offset for field 'b' (cdef "
            'says 0, but C compiler says 4). fix it or use "...;" ')

    def test_type_caching(self):
        ffi1, lib1 = self.prepare(
            "struct foo_s;",
            'test_type_caching_1',
            'struct foo_s;')
        ffi2, lib2 = self.prepare(
            "struct foo_s;",    # different one!
            'test_type_caching_2',
            'struct foo_s;')
        # shared types
        assert ffi1.typeof("long") is ffi2.typeof("long")
        assert ffi1.typeof("long**") is ffi2.typeof("long * *")
        assert ffi1.typeof("long(*)(int, ...)") is ffi2.typeof("long(*)(int, ...)")
        # non-shared types
        assert ffi1.typeof("struct foo_s") is not ffi2.typeof("struct foo_s")
        assert ffi1.typeof("struct foo_s *") is not ffi2.typeof("struct foo_s *")
        assert ffi1.typeof("struct foo_s*(*)()") is not (
            ffi2.typeof("struct foo_s*(*)()"))
        assert ffi1.typeof("void(*)(struct foo_s*)") is not (
            ffi2.typeof("void(*)(struct foo_s*)"))

    def test_verify_enum(self):
        import sys
        ffi, lib = self.prepare(
            """enum e1 { B1, A1, ... }; enum e2 { B2, A2, ... };""",
            'test_verify_enum',
            "enum e1 { A1, B1, C1=%d };" % sys.maxsize +
            "enum e2 { A2, B2, C2 };")
        ffi.typeof("enum e1")
        ffi.typeof("enum e2")
        assert lib.A1 == 0
        assert lib.B1 == 1
        assert lib.A2 == 0
        assert lib.B2 == 1
        assert ffi.sizeof("enum e1") == ffi.sizeof("long")
        assert ffi.sizeof("enum e2") == ffi.sizeof("int")
        assert repr(ffi.cast("enum e1", 0)) == "<cdata 'enum e1' 0: A1>"

    def test_dotdotdot_length_of_array_field(self):
        ffi, lib = self.prepare(
            "struct foo_s { int a[...]; int b[...]; };",
            'test_dotdotdot_length_of_array_field',
            "struct foo_s { int a[42]; int b[11]; };")
        assert ffi.sizeof("struct foo_s") == (42 + 11) * 4
        p = ffi.new("struct foo_s *")
        assert p.a[41] == p.b[10] == 0
        raises(IndexError, "p.a[42]")
        raises(IndexError, "p.b[11]")

    def test_dotdotdot_global_array(self):
        ffi, lib = self.prepare(
            "int aa[...]; int bb[...];",
            'test_dotdotdot_global_array',
            "int aa[41]; int bb[12];")
        assert ffi.sizeof(lib.aa) == 41 * 4
        assert ffi.sizeof(lib.bb) == 12 * 4
        assert lib.aa[40] == lib.bb[11] == 0
        raises(IndexError, "lib.aa[41]")
        raises(IndexError, "lib.bb[12]")

    def test_misdeclared_field_1(self):
        ffi, lib = self.prepare(
            "struct foo_s { int a[5]; };",
            'test_misdeclared_field_1',
            "struct foo_s { int a[6]; };")
        assert ffi.sizeof("struct foo_s") == 24  # found by the actual C code
        try:
            # lazily build the fields and boom:
            p = ffi.new("struct foo_s *")
            p.a
            assert False, "should have raised"
        except ffi.error as e:
            assert str(e).startswith("struct foo_s: wrong size for field 'a' "
                                     "(cdef says 20, but C compiler says 24)")

    def test_open_array_in_struct(self):
        ffi, lib = self.prepare(
            "struct foo_s { int b; int a[]; };",
            'test_open_array_in_struct',
            "struct foo_s { int b; int a[]; };")
        assert ffi.sizeof("struct foo_s") == 4
        p = ffi.new("struct foo_s *", [5, [10, 20, 30, 40]])
        assert p.a[2] == 30
        assert ffi.sizeof(p) == ffi.sizeof("void *")
        assert ffi.sizeof(p[0]) == 5 * ffi.sizeof("int")

    def test_math_sin_type(self):
        ffi, lib = self.prepare(
            "double sin(double); void *xxtestfunc();",
            'test_math_sin_type',
            """#include <math.h>
               void *xxtestfunc(void) { return 0; }
            """)
        # 'lib.sin' is typed as a <built-in method> object on lib
        assert ffi.typeof(lib.sin).cname == "double(*)(double)"
        # 'x' is another <built-in method> object on lib, made very indirectly
        x = type(lib).__dir__.__get__(lib)
        raises(TypeError, ffi.typeof, x)
        #
        # present on built-in functions on CPython; must be emulated on PyPy:
        assert lib.sin.__name__ == 'sin'
        assert lib.sin.__module__ == '_CFFI_test_math_sin_type'
        assert lib.sin.__doc__ == (
            "double sin(double);\n"
            "\n"
            "CFFI C function from _CFFI_test_math_sin_type.lib")

        assert ffi.typeof(lib.xxtestfunc).cname == "void *(*)()"
        assert lib.xxtestfunc.__doc__ == (
            "void *xxtestfunc();\n"
            "\n"
            "CFFI C function from _CFFI_test_math_sin_type.lib")

    def test_verify_anonymous_struct_with_typedef(self):
        ffi, lib = self.prepare(
            "typedef struct { int a; long b; ...; } foo_t;",
            'test_verify_anonymous_struct_with_typedef',
            "typedef struct { long b; int hidden, a; } foo_t;")
        p = ffi.new("foo_t *", {'b': 42})
        assert p.b == 42
        assert repr(p).startswith("<cdata 'foo_t *' ")

    def test_verify_anonymous_struct_with_star_typedef(self):
        ffi, lib = self.prepare(
            "typedef struct { int a; long b; } *foo_t;",
            'test_verify_anonymous_struct_with_star_typedef',
            "typedef struct { int a; long b; } *foo_t;")
        p = ffi.new("foo_t", {'b': 42})
        assert p.b == 42

    def test_verify_anonymous_enum_with_typedef(self):
        ffi, lib = self.prepare(
            "typedef enum { AA, ... } e1;",
            'test_verify_anonymous_enum_with_typedef1',
            "typedef enum { BB, CC, AA } e1;")
        assert lib.AA == 2
        assert ffi.sizeof("e1") == ffi.sizeof("int")
        assert repr(ffi.cast("e1", 2)) == "<cdata 'e1' 2: AA>"
        #
        import sys
        ffi, lib = self.prepare(
            "typedef enum { AA=%d } e1;" % sys.maxsize,
            'test_verify_anonymous_enum_with_typedef2',
            "typedef enum { AA=%d } e1;" % sys.maxsize)
        assert lib.AA == sys.maxsize
        assert ffi.sizeof("e1") == ffi.sizeof("long")

    def test_unique_types(self):
        CDEF = "struct foo_s; union foo_u; enum foo_e { AA };"
        ffi1, lib1 = self.prepare(CDEF, "test_unique_types_1", CDEF)
        ffi2, lib2 = self.prepare(CDEF, "test_unique_types_2", CDEF)
        #
        assert ffi1.typeof("char") is ffi2.typeof("char ")
        assert ffi1.typeof("long") is ffi2.typeof("signed long int")
        assert ffi1.typeof("double *") is ffi2.typeof("double*")
        assert ffi1.typeof("int ***") is ffi2.typeof(" int * * *")
        assert ffi1.typeof("int[]") is ffi2.typeof("signed int[]")
        assert ffi1.typeof("signed int*[17]") is ffi2.typeof("int *[17]")
        assert ffi1.typeof("void") is ffi2.typeof("void")
        assert ffi1.typeof("int(*)(int,int)") is ffi2.typeof("int(*)(int,int)")
        #
        # these depend on user-defined data, so should not be shared
        for name in ["struct foo_s",
                     "union foo_u *",
                     "enum foo_e",
                     "struct foo_s *(*)()",
                     "void(*)(struct foo_s *)",
                     "struct foo_s *(*[5])[8]",
                     ]:
            assert ffi1.typeof(name) is not ffi2.typeof(name)
        # sanity check: twice 'ffi1'
        assert ffi1.typeof("struct foo_s*") is ffi1.typeof("struct foo_s *")

    def test_module_name_in_package(self):
        ffi, lib = self.prepare(
            "int foo(int);",
            'test_module_name_in_package.mymod',
            "int foo(int x) { return x + 32; }")
        assert lib.foo(10) == 42

    def test_unspecified_size_of_global_1(self):
        ffi, lib = self.prepare(
            "int glob[];",
            "test_unspecified_size_of_global_1",
            "int glob[10];")
        assert ffi.typeof(lib.glob) == ffi.typeof("int *")

    def test_unspecified_size_of_global_2(self):
        ffi, lib = self.prepare(
            "int glob[][5];",
            "test_unspecified_size_of_global_2",
            "int glob[10][5];")
        assert ffi.typeof(lib.glob) == ffi.typeof("int(*)[5]")

    def test_unspecified_size_of_global_3(self):
        ffi, lib = self.prepare(
            "int glob[][...];",
            "test_unspecified_size_of_global_3",
            "int glob[10][5];")
        assert ffi.typeof(lib.glob) == ffi.typeof("int(*)[5]")

    def test_unspecified_size_of_global_4(self):
        ffi, lib = self.prepare(
            "int glob[...][...];",
            "test_unspecified_size_of_global_4",
            "int glob[10][5];")
        assert ffi.typeof(lib.glob) == ffi.typeof("int[10][5]")

    def test_include_1(self):
        ffi1, lib1 = self.prepare(
            "typedef double foo_t;",
            "test_include_1_parent",
            "typedef double foo_t;")
        ffi, lib = self.prepare(
            "foo_t ff1(foo_t);",
            "test_include_1",
            "double ff1(double x) { return 42.5; }",
            includes=[ffi1])
        assert lib.ff1(0) == 42.5
        assert ffi1.typeof("foo_t") is ffi.typeof("foo_t") \
            is ffi.typeof("double")

    def test_include_1b(self):
        ffi1, lib1 = self.prepare(
            "int foo1(int);",
            "test_include_1b_parent",
            "int foo1(int x) { return x + 10; }")
        ffi, lib = self.prepare(
            "int foo2(int);",
            "test_include_1b",
            "int foo2(int x) { return x - 5; }",
            includes=[ffi1])
        assert lib.foo2(42) == 37
        assert lib.foo1(42) == 52
        assert lib.foo1 is lib1.foo1

    def test_include_2(self):
        ffi1, lib1 = self.prepare(
            "struct foo_s { int x, y; };",
            "test_include_2_parent",
            "struct foo_s { int x, y; };")
        ffi, lib = self.prepare(
            "struct foo_s *ff2(struct foo_s *);",
            "test_include_2",
            "struct foo_s { int x, y; }; //usually from a #include\n"
            "struct foo_s *ff2(struct foo_s *p) { p->y++; return p; }",
            includes=[ffi1])
        p = ffi.new("struct foo_s *")
        p.y = 41
        q = lib.ff2(p)
        assert q == p
        assert p.y == 42
        assert ffi1.typeof("struct foo_s") is ffi.typeof("struct foo_s")

    def test_include_3(self):
        ffi1, lib1 = self.prepare(
            "typedef short sshort_t;",
            "test_include_3_parent",
            "typedef short sshort_t;")
        ffi, lib = self.prepare(
            "sshort_t ff3(sshort_t);",
            "test_include_3",
            "typedef short sshort_t; //usually from a #include\n"
            "sshort_t ff3(sshort_t x) { return x + 42; }",
            includes=[ffi1])
        assert lib.ff3(10) == 52
        assert ffi.typeof(ffi.cast("sshort_t", 42)) is ffi.typeof("short")
        assert ffi1.typeof("sshort_t") is ffi.typeof("sshort_t")

    def test_include_4(self):
        ffi1, lib1 = self.prepare(
            "typedef struct { int x; } mystruct_t;",
            "test_include_4_parent",
            "typedef struct { int x; } mystruct_t;")
        ffi, lib = self.prepare(
            "mystruct_t *ff4(mystruct_t *);",
            "test_include_4",
            "typedef struct {int x; } mystruct_t; //usually from a #include\n"
            "mystruct_t *ff4(mystruct_t *p) { p->x += 42; return p; }",
            includes=[ffi1])
        p = ffi.new("mystruct_t *", [10])
        q = lib.ff4(p)
        assert q == p
        assert p.x == 52
        assert ffi1.typeof("mystruct_t") is ffi.typeof("mystruct_t")

    def test_include_5(self):
        ffi1, lib1 = self.prepare(
            "typedef struct { int x[2]; int y; } *mystruct_p;",
            "test_include_5_parent",
            "typedef struct { int x[2]; int y; } *mystruct_p;")
        ffi, lib = self.prepare(
            "mystruct_p ff5(mystruct_p);",
            "test_include_5",
            "typedef struct {int x[2]; int y; } *mystruct_p; //#include\n"
            "mystruct_p ff5(mystruct_p p) { p->x[1] += 42; return p; }",
            includes=[ffi1])
        assert ffi.alignof(ffi.typeof("mystruct_p").item) == 4
        assert ffi1.typeof("mystruct_p") is ffi.typeof("mystruct_p")
        p = ffi.new("mystruct_p", [[5, 10], -17])
        q = lib.ff5(p)
        assert q == p
        assert p.x[0] == 5
        assert p.x[1] == 52
        assert p.y == -17
        assert ffi.alignof(ffi.typeof(p[0])) == 4

    def test_include_6(self):
        ffi1, lib1 = self.prepare(
            "typedef ... mystruct_t;",
            "test_include_6_parent",
            "typedef struct _mystruct_s mystruct_t;")
        ffi, lib = self.prepare(
            "mystruct_t *ff6(void); int ff6b(mystruct_t *);",
            "test_include_6",
           "typedef struct _mystruct_s mystruct_t; //usually from a #include\n"
           "struct _mystruct_s { int x; };\n"
           "static mystruct_t result_struct = { 42 };\n"
           "mystruct_t *ff6(void) { return &result_struct; }\n"
           "int ff6b(mystruct_t *p) { return p->x; }",
           includes=[ffi1])
        p = lib.ff6()
        assert ffi.cast("int *", p)[0] == 42
        assert lib.ff6b(p) == 42

    def test_include_7(self):
        ffi1, lib1 = self.prepare(
            "typedef ... mystruct_t; int ff7b(mystruct_t *);",
            "test_include_7_parent",
           "typedef struct { int x; } mystruct_t;\n"
           "int ff7b(mystruct_t *p) { return p->x; }")
        ffi, lib = self.prepare(
            "mystruct_t *ff7(void);",
            "test_include_7",
           "typedef struct { int x; } mystruct_t; //usually from a #include\n"
           "static mystruct_t result_struct = { 42 };"
           "mystruct_t *ff7(void) { return &result_struct; }",
           includes=[ffi1])
        p = lib.ff7()
        assert ffi.cast("int *", p)[0] == 42
        assert lib.ff7b(p) == 42

    def test_include_8(self):
        ffi1, lib1 = self.prepare(
            "struct foo_s;",
            "test_include_8_parent",
            "struct foo_s;")
        ffi, lib = self.prepare(
            "struct foo_s { int x, y; };",
            "test_include_8",
            "struct foo_s { int x, y; };",
            includes=[ffi1])
        e = raises(NotImplementedError, ffi.new, "struct foo_s *")
        assert str(e.value) == (
            "'struct foo_s' is opaque in the ffi.include(), but no longer in "
            "the ffi doing the include (workaround: don't use ffi.include() but"
            " duplicate the declarations of everything using struct foo_s)")

    def test_bitfield_basic(self):
        ffi, lib = self.prepare(
            "struct bitfield { int a:10, b:25; };",
            "test_bitfield_basic",
            "struct bitfield { int a:10, b:25; };")
        assert ffi.sizeof("struct bitfield") == 8
        s = ffi.new("struct bitfield *")
        s.a = -512
        raises(OverflowError, "s.a = -513")
        assert s.a == -512

    def test_incomplete_struct_as_arg(self):
        ffi, lib = self.prepare(
            "struct foo_s { int x; ...; }; int f(int, struct foo_s);",
            "test_incomplete_struct_as_arg",
            "struct foo_s { int a, x, z; };\n"
            "int f(int b, struct foo_s s) { return s.x * b; }")
        s = ffi.new("struct foo_s *", [21])
        assert s.x == 21
        assert ffi.sizeof(s[0]) == 12
        assert ffi.offsetof(ffi.typeof(s), 'x') == 4
        assert lib.f(2, s[0]) == 42
        assert ffi.typeof(lib.f) == ffi.typeof("int(*)(int, struct foo_s)")

    def test_incomplete_struct_as_result(self):
        ffi, lib = self.prepare(
            "struct foo_s { int x; ...; }; struct foo_s f(int);",
            "test_incomplete_struct_as_result",
            "struct foo_s { int a, x, z; };\n"
            "struct foo_s f(int x) { struct foo_s r; r.x = x * 2; return r; }")
        s = lib.f(21)
        assert s.x == 42
        assert ffi.typeof(lib.f) == ffi.typeof("struct foo_s(*)(int)")

    def test_incomplete_struct_as_both(self):
        ffi, lib = self.prepare(
            "struct foo_s { int x; ...; }; struct bar_s { int y; ...; };\n"
            "struct foo_s f(int, struct bar_s);",
            "test_incomplete_struct_as_both",
            "struct foo_s { int a, x, z; };\n"
            "struct bar_s { int b, c, y, d; };\n"
            "struct foo_s f(int x, struct bar_s b) {\n"
            "  struct foo_s r; r.x = x * b.y; return r;\n"
            "}")
        b = ffi.new("struct bar_s *", [7])
        s = lib.f(6, b[0])
        assert s.x == 42
        assert ffi.typeof(lib.f) == ffi.typeof(
            "struct foo_s(*)(int, struct bar_s)")
        s = lib.f(14, {'y': -3})
        assert s.x == -42

    def test_name_of_unnamed_struct(self):
        ffi, lib = self.prepare(
                 "typedef struct { int x; } foo_t;\n"
                 "typedef struct { int y; } *bar_p;\n"
                 "typedef struct { int y; } **baz_pp;\n",
                 "test_name_of_unnamed_struct",
                 "typedef struct { int x; } foo_t;\n"
                 "typedef struct { int y; } *bar_p;\n"
                 "typedef struct { int y; } **baz_pp;\n")
        assert repr(ffi.typeof("foo_t")) == "<ctype 'foo_t'>"
        assert repr(ffi.typeof("bar_p")) == "<ctype 'struct $1 *'>"
        assert repr(ffi.typeof("baz_pp")) == "<ctype 'struct $2 * *'>"

    def test_address_of_global_var(self):
        ffi, lib = self.prepare("""
            long bottom, bottoms[2];
            long FetchRectBottom(void);
            long FetchRectBottoms1(void);
            #define FOOBAR 42
        """, "test_address_of_global_var", """
            long bottom, bottoms[2];
            long FetchRectBottom(void) { return bottom; }
            long FetchRectBottoms1(void) { return bottoms[1]; }
            #define FOOBAR 42
        """)
        lib.bottom = 300
        assert lib.FetchRectBottom() == 300
        lib.bottom += 1
        assert lib.FetchRectBottom() == 301
        lib.bottoms[1] = 500
        assert lib.FetchRectBottoms1() == 500
        lib.bottoms[1] += 2
        assert lib.FetchRectBottoms1() == 502
        #
        p = ffi.addressof(lib, 'bottom')
        assert ffi.typeof(p) == ffi.typeof("long *")
        assert p[0] == 301
        p[0] += 1
        assert lib.FetchRectBottom() == 302
        p = ffi.addressof(lib, 'bottoms')
        assert ffi.typeof(p) == ffi.typeof("long(*)[2]")
        assert p[0] == lib.bottoms
        #
        raises(AttributeError, ffi.addressof, lib, 'unknown_var')
        raises(AttributeError, ffi.addressof, lib, "FOOBAR")

    def test_defines__CFFI_(self):
        # Check that we define the macro _CFFI_ automatically.
        # It should be done before including Python.h, so that PyPy's Python.h
        # can check for it.
        ffi, lib = self.prepare("""
            #define CORRECT 1
        """, "test_defines__CFFI_", """
            #ifdef _CFFI_
            #    define CORRECT 1
            #endif
        """)
        assert lib.CORRECT == 1

    def test_unpack_args(self):
        ffi, lib = self.prepare(
            "void foo0(void); void foo1(int); void foo2(int, int);",
            "test_unpack_args", """
                void foo0(void) { }
                void foo1(int x) { }
                void foo2(int x, int y) { }
            """)
        assert 'foo0' in repr(lib.foo0)
        assert 'foo1' in repr(lib.foo1)
        assert 'foo2' in repr(lib.foo2)
        lib.foo0()
        lib.foo1(42)
        lib.foo2(43, 44)
        e1 = raises(TypeError, lib.foo0, 42)
        e2 = raises(TypeError, lib.foo0, 43, 44)
        e3 = raises(TypeError, lib.foo1)
        e4 = raises(TypeError, lib.foo1, 43, 44)
        e5 = raises(TypeError, lib.foo2)
        e6 = raises(TypeError, lib.foo2, 42)
        e7 = raises(TypeError, lib.foo2, 45, 46, 47)
        assert str(e1.value) == "foo0() takes no arguments (1 given)"
        assert str(e2.value) == "foo0() takes no arguments (2 given)"
        assert str(e3.value) == "foo1() takes exactly one argument (0 given)"
        assert str(e4.value) == "foo1() takes exactly one argument (2 given)"
        assert str(e5.value) == "foo2() takes exactly 2 arguments (0 given)"
        assert str(e6.value) == "foo2() takes exactly 2 arguments (1 given)"
        assert str(e7.value) == "foo2() takes exactly 2 arguments (3 given)"

    def test_address_of_function(self):
        ffi, lib = self.prepare(
            "long myfunc(long x);",
            "test_addressof_function",
            "char myfunc(char x) { return (char)(x + 42); }")
        assert lib.myfunc(5) == 47
        assert lib.myfunc(0xABC05) == 47
        assert not isinstance(lib.myfunc, ffi.CData)
        assert ffi.typeof(lib.myfunc) == ffi.typeof("long(*)(long)")
        addr = ffi.addressof(lib, 'myfunc')
        assert addr(5) == 47
        assert addr(0xABC05) == 47
        assert isinstance(addr, ffi.CData)
        assert ffi.typeof(addr) == ffi.typeof("long(*)(long)")

    def test_address_of_function_with_struct(self):
        ffi, lib = self.prepare(
            "struct foo_s { int x; }; long myfunc(struct foo_s);",
            "test_addressof_function_with_struct", """
                struct foo_s { int x; };
                char myfunc(struct foo_s input) { return (char)(input.x + 42); }
            """)
        s = ffi.new("struct foo_s *", [5])[0]
        assert lib.myfunc(s) == 47
        assert not isinstance(lib.myfunc, ffi.CData)
        assert ffi.typeof(lib.myfunc) == ffi.typeof("long(*)(struct foo_s)")
        addr = ffi.addressof(lib, 'myfunc')
        assert addr(s) == 47
        assert isinstance(addr, ffi.CData)
        assert ffi.typeof(addr) == ffi.typeof("long(*)(struct foo_s)")

    def test_issue198(self):
        ffi, lib = self.prepare("""
            typedef struct{...;} opaque_t;
            const opaque_t CONSTANT;
            int toint(opaque_t);
        """, 'test_issue198', """
            typedef int opaque_t;
            #define CONSTANT ((opaque_t)42)
            static int toint(opaque_t o) { return o; }
        """)
        def random_stuff():
            pass
        assert lib.toint(lib.CONSTANT) == 42
        random_stuff()
        assert lib.toint(lib.CONSTANT) == 42

    def test_constant_is_not_a_compiler_constant(self):
        ffi, lib = self.prepare(
            "static const float almost_forty_two;",
            'test_constant_is_not_a_compiler_constant', """
                static float f(void) { return 42.25; }
                #define almost_forty_two (f())
            """)
        assert lib.almost_forty_two == 42.25

    def test_constant_of_unknown_size(self):
        ffi, lib = self.prepare(
            "typedef ... opaque_t;"
            "const opaque_t CONSTANT;",
            'test_constant_of_unknown_size',
            "typedef int opaque_t;"
            "const int CONSTANT = 42;")
        e = raises(ffi.error, getattr, lib, 'CONSTANT')
        assert str(e.value) == ("constant 'CONSTANT' is of "
                                "type 'opaque_t', whose size is not known")

    def test_variable_of_unknown_size(self):
        ffi, lib = self.prepare("""
            typedef ... opaque_t;
            opaque_t globvar;
        """, 'test_variable_of_unknown_size', """
            typedef char opaque_t[6];
            opaque_t globvar = "hello";
        """)
        # can't read or write it at all
        e = raises(TypeError, getattr, lib, 'globvar')
        assert str(e.value) == "'opaque_t' is opaque or not completed yet"
        e = raises(TypeError, setattr, lib, 'globvar', [])
        assert str(e.value) == "'opaque_t' is opaque or not completed yet"
        # but we can get its address
        p = ffi.addressof(lib, 'globvar')
        assert ffi.typeof(p) == ffi.typeof('opaque_t *')
        assert ffi.string(ffi.cast("char *", p), 8) == b"hello"

    def test_constant_of_value_unknown_to_the_compiler(self):
        extra_c_source = self.udir + self.os_sep + (
            'extra_test_constant_of_value_unknown_to_the_compiler.c')
        with open(extra_c_source, 'wb') as f:
            f.write(b'const int external_foo = 42;\n')
        ffi, lib = self.prepare(
            "const int external_foo;",
            'test_constant_of_value_unknown_to_the_compiler',
            "extern const int external_foo;",
            extra_source=extra_c_source)
        assert lib.external_foo == 42

    def test_call_with_incomplete_structs(self):
        ffi, lib = self.prepare(
            "typedef struct {...;} foo_t; "
            "foo_t myglob; "
            "foo_t increment(foo_t s); "
            "double getx(foo_t s);",
            'test_call_with_incomplete_structs', """
            typedef double foo_t;
            double myglob = 42.5;
            double getx(double x) { return x; }
            double increment(double x) { return x + 1; }
        """)
        assert lib.getx(lib.myglob) == 42.5
        assert lib.getx(lib.increment(lib.myglob)) == 43.5

    def test_struct_array_guess_length_2(self):
        ffi, lib = self.prepare(
            "struct foo_s { int a[...][...]; };",
            'test_struct_array_guess_length_2',
            "struct foo_s { int x; int a[5][8]; int y; };")
        assert ffi.sizeof('struct foo_s') == 42 * ffi.sizeof('int')
        s = ffi.new("struct foo_s *")
        assert ffi.typeof(s.a) == ffi.typeof("int[5][8]")
        assert ffi.sizeof(s.a) == 40 * ffi.sizeof('int')
        assert s.a[4][7] == 0
        raises(IndexError, 's.a[4][8]')
        raises(IndexError, 's.a[5][0]')
        assert ffi.typeof(s.a) == ffi.typeof("int[5][8]")
        assert ffi.typeof(s.a[0]) == ffi.typeof("int[8]")

    def test_struct_array_guess_length_3(self):
        ffi, lib = self.prepare(
            "struct foo_s { int a[][...]; };",
            'test_struct_array_guess_length_3',
            "struct foo_s { int x; int a[5][7]; int y; };")
        assert ffi.sizeof('struct foo_s') == 37 * ffi.sizeof('int')
        s = ffi.new("struct foo_s *")
        assert ffi.typeof(s.a) == ffi.typeof("int[][7]")
        assert s.a[4][6] == 0
        raises(IndexError, 's.a[4][7]')
        assert ffi.typeof(s.a[0]) == ffi.typeof("int[7]")

    def test_global_var_array_2(self):
        ffi, lib = self.prepare(
            "int a[...][...];",
            'test_global_var_array_2',
            'int a[10][8];')
        lib.a[9][7] = 123456
        assert lib.a[9][7] == 123456
        raises(IndexError, 'lib.a[0][8]')
        raises(IndexError, 'lib.a[10][0]')
        assert ffi.typeof(lib.a) == ffi.typeof("int[10][8]")
        assert ffi.typeof(lib.a[0]) == ffi.typeof("int[8]")

    def test_some_integer_type(self):
        ffi, lib = self.prepare("""
            typedef int... foo_t;
            typedef unsigned long... bar_t;
            typedef struct { foo_t a, b; } mystruct_t;
            foo_t foobar(bar_t, mystruct_t);
            static const bar_t mu = -20;
            static const foo_t nu = 20;
        """, 'test_some_integer_type', """
            typedef unsigned long long foo_t;
            typedef short bar_t;
            typedef struct { foo_t a, b; } mystruct_t;
            static foo_t foobar(bar_t x, mystruct_t s) {
                return (foo_t)x + s.a + s.b;
            }
            static const bar_t mu = -20;
            static const foo_t nu = 20;
        """)
        assert ffi.sizeof("foo_t") == ffi.sizeof("unsigned long long")
        assert ffi.sizeof("bar_t") == ffi.sizeof("short")
        maxulonglong = 2 ** 64 - 1
        assert int(ffi.cast("foo_t", -1)) == maxulonglong
        assert int(ffi.cast("bar_t", -1)) == -1
        assert lib.foobar(-1, [0, 0]) == maxulonglong
        assert lib.foobar(2 ** 15 - 1, [0, 0]) == 2 ** 15 - 1
        assert lib.foobar(10, [20, 31]) == 61
        assert lib.foobar(0, [0, maxulonglong]) == maxulonglong
        raises(OverflowError, lib.foobar, 2 ** 15, [0, 0])
        raises(OverflowError, lib.foobar, -(2 ** 15) - 1, [0, 0])
        raises(OverflowError, ffi.new, "mystruct_t *", [0, -1])
        assert lib.mu == -20
        assert lib.nu == 20

    def test_issue200(self):
        ffi, lib = self.prepare("""
            typedef void (function_t)(void*);
            void function(void *);
        """, 'test_issue200', """
            static void function(void *p) { (void)p; }
        """)
        ffi.typeof('function_t*')
        lib.function(ffi.NULL)
        # assert did not crash

    def test_alignment_of_longlong(self):
        import _cffi_backend
        BULongLong = _cffi_backend.new_primitive_type('unsigned long long')
        x1 = _cffi_backend.alignof(BULongLong)
        assert x1 in [4, 8]
        #
        ffi, lib = self.prepare(
            "struct foo_s { unsigned long long x; };",
            'test_alignment_of_longlong',
            "struct foo_s { unsigned long long x; };")
        assert ffi.alignof('unsigned long long') == x1
        assert ffi.alignof('struct foo_s') == x1

    def test_import_from_lib(self):
        import sys
        ffi, lib = self.prepare(
            "int mybar(int); int myvar;\n#define MYFOO ...",
            'test_import_from_lib',
             "#define MYFOO 42\n"
             "static int mybar(int x) { return x + 1; }\n"
             "static int myvar = -5;")
        assert sys.modules['_CFFI_test_import_from_lib'].lib is lib
        assert sys.modules['_CFFI_test_import_from_lib.lib'] is lib
        from _CFFI_test_import_from_lib.lib import MYFOO
        assert MYFOO == 42
        assert hasattr(lib, '__dict__')
        assert lib.__all__ == ['MYFOO', 'mybar']   # but not 'myvar'
        assert lib.__name__ == '_CFFI_test_import_from_lib.lib'
        assert lib.__class__ is type(sys)   # !! hack for help()

    def test_macro_var_callback(self):
        ffi, lib = self.prepare(
            "int my_value; int *(*get_my_value)(void);",
            'test_macro_var_callback',
            "int *(*get_my_value)(void);\n"
            "#define my_value (*get_my_value())")
        #
        values = ffi.new("int[50]")
        def it():
            for i in range(50):
                yield i
        it = it()
        #
        @ffi.callback("int *(*)(void)")
        def get_my_value():
            return values + next(it)
        lib.get_my_value = get_my_value
        #
        values[0] = 41
        assert lib.my_value == 41            # [0]
        p = ffi.addressof(lib, 'my_value')   # [1]
        assert p == values + 1
        assert p[-1] == 41
        assert p[+1] == 0
        lib.my_value = 42                    # [2]
        assert values[2] == 42
        assert p[-1] == 41
        assert p[+1] == 42
        #
        # if get_my_value raises or returns nonsense, the exception is printed
        # to stderr like with any callback, but then the C expression 'my_value'
        # expand to '*NULL'.  We assume here that '&my_value' will return NULL
        # without segfaulting, and check for NULL when accessing the variable.
        @ffi.callback("int *(*)(void)")
        def get_my_value():
            raise LookupError
        lib.get_my_value = get_my_value
        raises(ffi.error, getattr, lib, 'my_value')
        raises(ffi.error, setattr, lib, 'my_value', 50)
        raises(ffi.error, ffi.addressof, lib, 'my_value')
        @ffi.callback("int *(*)(void)")
        def get_my_value():
            return "hello"
        lib.get_my_value = get_my_value
        raises(ffi.error, getattr, lib, 'my_value')
        e = raises(ffi.error, setattr, lib, 'my_value', 50)
        assert str(e.value) == "global variable 'my_value' is at address NULL"

    def test_const_fields(self):
        ffi, lib = self.prepare(
            """struct foo_s { const int a; void *const b; };""",
            'test_const_fields',
            """struct foo_s { const int a; void *const b; };""")
        foo_s = ffi.typeof("struct foo_s")
        assert foo_s.fields[0][0] == 'a'
        assert foo_s.fields[0][1].type is ffi.typeof("int")
        assert foo_s.fields[1][0] == 'b'
        assert foo_s.fields[1][1].type is ffi.typeof("void *")

    def test_restrict_fields(self):
        ffi, lib = self.prepare(
            """struct foo_s { void * restrict b; };""",
            'test_restrict_fields',
            """struct foo_s { void * __restrict b; };""")
        foo_s = ffi.typeof("struct foo_s")
        assert foo_s.fields[0][0] == 'b'
        assert foo_s.fields[0][1].type is ffi.typeof("void *")

    def test_volatile_fields(self):
        ffi, lib = self.prepare(
            """struct foo_s { void * volatile b; };""",
            'test_volatile_fields',
            """struct foo_s { void * volatile b; };""")
        foo_s = ffi.typeof("struct foo_s")
        assert foo_s.fields[0][0] == 'b'
        assert foo_s.fields[0][1].type is ffi.typeof("void *")

    def test_const_array_fields(self):
        ffi, lib = self.prepare(
            """struct foo_s { const int a[4]; };""",
            'test_const_array_fields',
            """struct foo_s { const int a[4]; };""")
        foo_s = ffi.typeof("struct foo_s")
        assert foo_s.fields[0][0] == 'a'
        assert foo_s.fields[0][1].type is ffi.typeof("int[4]")

    def test_const_array_fields_varlength(self):
        ffi, lib = self.prepare(
            """struct foo_s { const int a[]; ...; };""",
            'test_const_array_fields_varlength',
            """struct foo_s { const int a[4]; };""")
        foo_s = ffi.typeof("struct foo_s")
        assert foo_s.fields[0][0] == 'a'
        assert foo_s.fields[0][1].type is ffi.typeof("int[]")

    def test_const_array_fields_unknownlength(self):
        ffi, lb = self.prepare(
            """struct foo_s { const int a[...]; ...; };""",
            'test_const_array_fields_unknownlength',
            """struct foo_s { const int a[4]; };""")
        foo_s = ffi.typeof("struct foo_s")
        assert foo_s.fields[0][0] == 'a'
        assert foo_s.fields[0][1].type is ffi.typeof("int[4]")

    def test_const_function_args(self):
        ffi, lib = self.prepare(
            """int foobar(const int a, const int *b, const int c[]);""",
            'test_const_function_args', """
            int foobar(const int a, const int *b, const int c[]) {
                return a + *b + *c;
            }
        """)
        assert lib.foobar(100, ffi.new("int *", 40), ffi.new("int *", 2)) == 142

    def test_const_function_type_args(self):
        ffi, lib = self.prepare(
            """int (*foobar)(const int a, const int *b, const int c[]);""",
            'test_const_function_type_args', """
            int (*foobar)(const int a, const int *b, const int c[]);
        """)
        t = ffi.typeof(lib.foobar)
        assert t.args[0] is ffi.typeof("int")
        assert t.args[1] is ffi.typeof("int *")
        assert t.args[2] is ffi.typeof("int *")

    def test_const_constant(self):
        ffi, lib = self.prepare(
            """struct foo_s { int x,y; }; const struct foo_s myfoo;""",
            'test_const_constant', """
            struct foo_s { int x,y; }; const struct foo_s myfoo = { 40, 2 };
        """)
        assert lib.myfoo.x == 40
        assert lib.myfoo.y == 2

    def test_const_via_typedef(self):
        ffi, lib = self.prepare(
            """typedef const int const_t; const_t aaa;""",
            'test_const_via_typedef', """
            typedef const int const_t;
            #define aaa 42
        """)
        assert lib.aaa == 42
        raises(AttributeError, "lib.aaa = 43")

    def test_win32_calling_convention_0(self):
        import sys
        ffi, lib = self.prepare(
            """
            int call1(int(__cdecl   *cb)(int));
            int (*const call2)(int(__stdcall *cb)(int));
            """,
            'test_win32_calling_convention_0', r"""
            #ifndef _MSC_VER
            #  define __stdcall  /* nothing */
            #endif
            int call1(int(*cb)(int)) {
                int i, result = 0;
                //printf("call1: cb = %p\n", cb);
                for (i = 0; i < 1000; i++)
                    result += cb(i);
                //printf("result = %d\n", result);
                return result;
            }
            int call2(int(__stdcall *cb)(int)) {
                int i, result = 0;
                //printf("call2: cb = %p\n", cb);
                for (i = 0; i < 1000; i++)
                    result += cb(-i);
                //printf("result = %d\n", result);
                return result;
            }
        """)
        @ffi.callback("int(int)")
        def cb1(x):
            return x * 2
        @ffi.callback("int __stdcall(int)")
        def cb2(x):
            return x * 3
        res = lib.call1(cb1)
        assert res == 500*999*2
        assert res == ffi.addressof(lib, 'call1')(cb1)
        res = lib.call2(cb2)
        assert res == -500*999*3
        assert res == ffi.addressof(lib, 'call2')(cb2)
        if sys.platform == 'win32' and not sys.maxsize > 2**32:
            assert '__stdcall' in str(ffi.typeof(cb2))
            assert '__stdcall' not in str(ffi.typeof(cb1))
            raises(TypeError, lib.call1, cb2)
            raises(TypeError, lib.call2, cb1)
        else:
            assert '__stdcall' not in str(ffi.typeof(cb2))
            assert ffi.typeof(cb2) is ffi.typeof(cb1)

    def test_win32_calling_convention_1(self):
        ffi, lib = self.prepare("""
            int __cdecl   call1(int(__cdecl   *cb)(int));
            int __stdcall call2(int(__stdcall *cb)(int));
            int (__cdecl   *const cb1)(int);
            int (__stdcall *const cb2)(int);
        """, 'test_win32_calling_convention_1', r"""
            #ifndef _MSC_VER
            #  define __cdecl
            #  define __stdcall
            #endif
            int __cdecl   cb1(int x) { return x * 2; }
            int __stdcall cb2(int x) { return x * 3; }

            int __cdecl call1(int(__cdecl *cb)(int)) {
                int i, result = 0;
                //printf("here1\n");
                //printf("cb = %p, cb1 = %p\n", cb, (void *)cb1);
                for (i = 0; i < 1000; i++)
                    result += cb(i);
                //printf("result = %d\n", result);
                return result;
            }
            int __stdcall call2(int(__stdcall *cb)(int)) {
                int i, result = 0;
                //printf("here1\n");
                //printf("cb = %p, cb2 = %p\n", cb, (void *)cb2);
                for (i = 0; i < 1000; i++)
                    result += cb(-i);
                //printf("result = %d\n", result);
                return result;
            }
        """)
        #print '<<< cb1 =', ffi.addressof(lib, 'cb1')
        ptr_call1 = ffi.addressof(lib, 'call1')
        assert lib.call1(ffi.addressof(lib, 'cb1')) == 500*999*2
        assert ptr_call1(ffi.addressof(lib, 'cb1')) == 500*999*2
        #print '<<< cb2 =', ffi.addressof(lib, 'cb2')
        ptr_call2 = ffi.addressof(lib, 'call2')
        assert lib.call2(ffi.addressof(lib, 'cb2')) == -500*999*3
        assert ptr_call2(ffi.addressof(lib, 'cb2')) == -500*999*3
        #print '<<< done'

    def test_win32_calling_convention_2(self):
        import sys
        # any mistake in the declaration of plain function (including the
        # precise argument types and, here, the calling convention) are
        # automatically corrected.  But this does not apply to the 'cb'
        # function pointer argument.
        ffi, lib = self.prepare("""
            int __stdcall call1(int(__cdecl   *cb)(int));
            int __cdecl   call2(int(__stdcall *cb)(int));
            int (__cdecl   *const cb1)(int);
            int (__stdcall *const cb2)(int);
        """, 'test_win32_calling_convention_2', """
            #ifndef _MSC_VER
            #  define __cdecl
            #  define __stdcall
            #endif
            int __cdecl call1(int(__cdecl *cb)(int)) {
                int i, result = 0;
                for (i = 0; i < 1000; i++)
                    result += cb(i);
                return result;
            }
            int __stdcall call2(int(__stdcall *cb)(int)) {
                int i, result = 0;
                for (i = 0; i < 1000; i++)
                    result += cb(-i);
                return result;
            }
            int __cdecl   cb1(int x) { return x * 2; }
            int __stdcall cb2(int x) { return x * 3; }
        """)
        ptr_call1 = ffi.addressof(lib, 'call1')
        ptr_call2 = ffi.addressof(lib, 'call2')
        if sys.platform == 'win32' and not sys.maxsize > 2**32:
            raises(TypeError, lib.call1, ffi.addressof(lib, 'cb2'))
            raises(TypeError, ptr_call1, ffi.addressof(lib, 'cb2'))
            raises(TypeError, lib.call2, ffi.addressof(lib, 'cb1'))
            raises(TypeError, ptr_call2, ffi.addressof(lib, 'cb1'))
        assert lib.call1(ffi.addressof(lib, 'cb1')) == 500*999*2
        assert ptr_call1(ffi.addressof(lib, 'cb1')) == 500*999*2
        assert lib.call2(ffi.addressof(lib, 'cb2')) == -500*999*3
        assert ptr_call2(ffi.addressof(lib, 'cb2')) == -500*999*3

    def test_win32_calling_convention_3(self):
        import sys
        ffi, lib = self.prepare("""
            struct point { int x, y; };

            int (*const cb1)(struct point);
            int (__stdcall *const cb2)(struct point);

            struct point __stdcall call1(int(*cb)(struct point));
            struct point call2(int(__stdcall *cb)(struct point));
        """, 'test_win32_calling_convention_3', r"""
            #ifndef _MSC_VER
            #  define __cdecl
            #  define __stdcall
            #endif
            struct point { int x, y; };
            int           cb1(struct point pt) { return pt.x + 10 * pt.y; }
            int __stdcall cb2(struct point pt) { return pt.x + 100 * pt.y; }
            struct point __stdcall call1(int(__cdecl *cb)(struct point)) {
                int i;
                struct point result = { 0, 0 };
                //printf("here1\n");
                //printf("cb = %p, cb1 = %p\n", cb, (void *)cb1);
                for (i = 0; i < 1000; i++) {
                    struct point p = { i, -i };
                    int r = cb(p);
                    result.x += r;
                    result.y -= r;
                }
                return result;
            }
            struct point __cdecl call2(int(__stdcall *cb)(struct point)) {
                int i;
                struct point result = { 0, 0 };
                for (i = 0; i < 1000; i++) {
                    struct point p = { -i, i };
                    int r = cb(p);
                    result.x += r;
                    result.y -= r;
                }
                return result;
            }
        """)
        ptr_call1 = ffi.addressof(lib, 'call1')
        ptr_call2 = ffi.addressof(lib, 'call2')
        if sys.platform == 'win32' and not sys.maxsize > 2**32:
            raises(TypeError, lib.call1, ffi.addressof(lib, 'cb2'))
            raises(TypeError, ptr_call1, ffi.addressof(lib, 'cb2'))
            raises(TypeError, lib.call2, ffi.addressof(lib, 'cb1'))
            raises(TypeError, ptr_call2, ffi.addressof(lib, 'cb1'))
        pt = lib.call1(ffi.addressof(lib, 'cb1'))
        assert (pt.x, pt.y) == (-9*500*999, 9*500*999)
        pt = ptr_call1(ffi.addressof(lib, 'cb1'))
        assert (pt.x, pt.y) == (-9*500*999, 9*500*999)
        pt = lib.call2(ffi.addressof(lib, 'cb2'))
        assert (pt.x, pt.y) == (99*500*999, -99*500*999)
        pt = ptr_call2(ffi.addressof(lib, 'cb2'))
        assert (pt.x, pt.y) == (99*500*999, -99*500*999)

    def test_share_FILE(self):
        ffi1, lib1 = self.prepare("void do_stuff(FILE *);",
                                  'test_share_FILE_a',
                                  "void do_stuff(FILE *f) { (void)f; }")
        ffi2, lib2 = self.prepare("FILE *barize(void);",
                                  'test_share_FILE_b',
                                  "FILE *barize(void) { return NULL; }")
        lib1.do_stuff(lib2.barize())

    def w_StdErrCapture(self, fd=False):
        if fd:
            # note: this is for a case where CPython prints to sys.stderr
            # too, but not PyPy
            import os
            class MiniStringIO(object):
                def __init__(self):
                    self._rd, self._wr = os.pipe()
                    self._result = None
                def getvalue(self):
                    if self._result is None:
                        os.close(self._wr)
                        self._result = os.read(self._rd, 4096).decode()
                        os.close(self._rd)
                        # xxx hack away these lines
                        while self._result.startswith('[platform:execute]'):
                            self._result = ''.join(
                                self._result.splitlines(True)[1:])
                    return self._result
            class StdErrCapture(object):
                def __enter__(self):
                    f = MiniStringIO()
                    self.old_fd2 = os.dup(2)
                    os.dup2(f._wr, 2)
                    return f
                def __exit__(self, *args):
                    os.dup2(self.old_fd2, 2)
                    os.close(self.old_fd2)
            return StdErrCapture()
        else:
            import sys
            class MiniStringIO(object):
                def __init__(self):
                    self._lst = []
                    self.write = self._lst.append
                def getvalue(self):
                    return ''.join(self._lst)
            class StdErrCapture(object):
                def __enter__(self):
                    self.old_stderr = sys.stderr
                    sys.stderr = f = MiniStringIO()
                    return f
                def __exit__(self, *args):
                    sys.stderr = self.old_stderr
            return StdErrCapture()

    def test_extern_python_1(self):
        ffi, lib = self.prepare("""
            extern "Python" {
                int bar(int, int);
                void baz(int, int);
                int bok(void);
                void boz(void);
            }
        """, 'test_extern_python_1', "")
        assert ffi.typeof(lib.bar) == ffi.typeof("int(*)(int, int)")
        with self.StdErrCapture(fd=True) as f:
            res = lib.bar(4, 5)
        assert res == 0
        assert f.getvalue() in (
            # If the underlying cffi is <= 1.9
            "extern \"Python\": function bar() called, but no code was attached "
            "to it yet with @ffi.def_extern().  Returning 0.\n",
            # If the underlying cffi is >= 1.10
            "extern \"Python\": function _CFFI_test_extern_python_1.bar() "
            "called, but no code was attached "
            "to it yet with @ffi.def_extern().  Returning 0.\n")

        @ffi.def_extern("bar")
        def my_bar(x, y):
            seen.append(("Bar", x, y))
            return x * y
        assert my_bar != lib.bar
        seen = []
        res = lib.bar(6, 7)
        assert seen == [("Bar", 6, 7)]
        assert res == 42

        def baz(x, y):
            seen.append(("Baz", x, y))
        baz1 = ffi.def_extern()(baz)
        assert baz1 is baz
        seen = []
        baz(40, 4)
        res = lib.baz(50, 8)
        assert res is None
        assert seen == [("Baz", 40, 4), ("Baz", 50, 8)]
        assert type(seen[0][1]) is type(seen[0][2]) is int
        assert type(seen[1][1]) is type(seen[1][2]) is int

        @ffi.def_extern(name="bok")
        def bokk():
            seen.append("Bok")
            return 42
        seen = []
        assert lib.bok() == 42
        assert seen == ["Bok"]

        @ffi.def_extern()
        def boz():
            seen.append("Boz")
        seen = []
        assert lib.boz() is None
        assert seen == ["Boz"]

    def test_extern_python_bogus_name(self):
        ffi, lib = self.prepare("int abc;",
                                'test_extern_python_bogus_name',
                                "int abc;")
        def fn():
            pass
        raises(ffi.error, ffi.def_extern("unknown_name"), fn)
        raises(ffi.error, ffi.def_extern("abc"), fn)
        assert lib.abc == 0
        e = raises(ffi.error, ffi.def_extern("abc"), fn)
        assert str(e.value) == ("ffi.def_extern('abc'): no 'extern \"Python\"' "
                                "function with this name")
        e = raises(ffi.error, ffi.def_extern(), fn)
        assert str(e.value) == ("ffi.def_extern('fn'): no 'extern \"Python\"' "
                                "function with this name")
        #
        raises(TypeError, ffi.def_extern(42), fn)
        raises((TypeError, AttributeError), ffi.def_extern(), "foo")
        class X:
            pass
        x = X()
        x.__name__ = x
        raises(TypeError, ffi.def_extern(), x)

    def test_extern_python_bogus_result_type(self):
        ffi, lib = self.prepare("""extern "Python" void bar(int);""",
                                'test_extern_python_bogus_result_type',
                                "")
        @ffi.def_extern()
        def bar(n):
            return n * 10
        with self.StdErrCapture() as f:
            res = lib.bar(321)
        msg = f.getvalue()
        assert res is None
        assert "rom cffi callback %r" % (bar,) in msg
        assert "rying to convert the result back to C:\n" in msg
        assert msg.endswith(
            "TypeError: callback with the return type 'void' must return None\n")

    def test_extern_python_redefine(self):
        ffi, lib = self.prepare("""extern "Python" int bar(int);""",
                                'test_extern_python_redefine',
                                "")
        @ffi.def_extern()
        def bar(n):
            return n * 10
        assert lib.bar(42) == 420
        #
        @ffi.def_extern()
        def bar(n):
            return -n
        assert lib.bar(42) == -42

    def test_extern_python_struct(self):
        ffi, lib = self.prepare("""
            struct foo_s { int a, b, c; };
            extern "Python" int bar(int, struct foo_s, int);
            extern "Python" { struct foo_s baz(int, int);
                              struct foo_s bok(void); }
        """, 'test_extern_python_struct',
             "struct foo_s { int a, b, c; };")
        #
        @ffi.def_extern()
        def bar(x, s, z):
            return x + s.a + s.b + s.c + z
        res = lib.bar(1000, [1001, 1002, 1004], 1008)
        assert res == 5015
        #
        @ffi.def_extern()
        def baz(x, y):
            return [x + y, x - y, x * y]
        res = lib.baz(1000, 42)
        assert res.a == 1042
        assert res.b == 958
        assert res.c == 42000
        #
        @ffi.def_extern()
        def bok():
            return [10, 20, 30]
        res = lib.bok()
        assert [res.a, res.b, res.c] == [10, 20, 30]

    def test_extern_python_long_double(self):
        ffi, lib = self.prepare("""
            extern "Python" int bar(int, long double, int);
            extern "Python" long double baz(int, int);
            extern "Python" long double bok(void);
        """, 'test_extern_python_long_double', "")
        #
        @ffi.def_extern()
        def bar(x, l, z):
            seen.append((x, l, z))
            return 6
        seen = []
        lib.bar(10, 3.5, 20)
        expected = ffi.cast("long double", 3.5)
        assert repr(seen) == repr([(10, expected, 20)])
        #
        @ffi.def_extern()
        def baz(x, z):
            assert x == 10 and z == 20
            return expected
        res = lib.baz(10, 20)
        assert repr(res) == repr(expected)
        #
        @ffi.def_extern()
        def bok():
            return expected
        res = lib.bok()
        assert repr(res) == repr(expected)

    def test_extern_python_signature(self):
        ffi, lib = self.prepare("", 'test_extern_python_signature', "")
        raises(TypeError, ffi.def_extern(425), None)
        raises(TypeError, ffi.def_extern, 'a', 'b', 'c', 'd')

    def test_extern_python_errors(self):
        ffi, lib = self.prepare("""
            extern "Python" int bar(int);
        """, 'test_extern_python_errors', "")

        seen = []
        def oops(*args):
            seen.append(args)

        @ffi.def_extern(onerror=oops)
        def bar(x):
            return x + ""
        assert lib.bar(10) == 0

        @ffi.def_extern(name="bar", onerror=oops, error=-66)
        def bar2(x):
            return x + ""
        assert lib.bar(10) == -66

        assert len(seen) == 2
        exc, val, tb = seen[0]
        assert exc is TypeError
        assert isinstance(val, TypeError)
        assert tb.tb_frame.f_code.co_name == "bar"
        exc, val, tb = seen[1]
        assert exc is TypeError
        assert isinstance(val, TypeError)
        assert tb.tb_frame.f_code.co_name == "bar2"
        #
        # a case where 'onerror' is not callable
        raises(TypeError, ffi.def_extern(name='bar', onerror=42),
                       lambda x: x)

    @pytest.mark.skipif("not config.option.runappdirect")
    def test_extern_python_stdcall(self):
        ffi, lib = self.prepare("""
            extern "Python" int __stdcall foo(int);
            extern "Python" int WINAPI bar(int);
            int (__stdcall * mycb1)(int);
            int indirect_call(int);
        """, 'test_extern_python_stdcall', """
            #ifndef _MSC_VER
            #  define __stdcall
            #endif
            static int (__stdcall * mycb1)(int);
            static int indirect_call(int x) {
                return mycb1(x);
            }
        """)
        #
        @ffi.def_extern()
        def foo(x):
            return x + 42
        @ffi.def_extern()
        def bar(x):
            return x + 43
        assert lib.foo(100) == 142
        assert lib.bar(100) == 143
        lib.mycb1 = lib.foo
        assert lib.mycb1(200) == 242
        assert lib.indirect_call(300) == 342

    def test_introspect_function(self):
        ffi, lib = self.prepare("""
            float f1(double);
        """, 'test_introspect_function', """
            float f1(double x) { return x; }
        """)
        assert dir(lib) == ['f1']
        FUNC = ffi.typeof(lib.f1)
        assert FUNC.kind == 'function'
        assert FUNC.args[0].cname == 'double'
        assert FUNC.result.cname == 'float'
        assert ffi.typeof(ffi.addressof(lib, 'f1')) is FUNC

    def test_introspect_global_var(self):
        ffi, lib = self.prepare("""
            float g1;
        """, 'test_introspect_global_var', """
            float g1;
        """)
        assert dir(lib) == ['g1']
        FLOATPTR = ffi.typeof(ffi.addressof(lib, 'g1'))
        assert FLOATPTR.kind == 'pointer'
        assert FLOATPTR.item.cname == 'float'

    def test_introspect_global_var_array(self):
        ffi, lib = self.prepare("""
            float g1[100];
        """, 'test_introspect_global_var_array', """
            float g1[100];
        """)
        assert dir(lib) == ['g1']
        FLOATARRAYPTR = ffi.typeof(ffi.addressof(lib, 'g1'))
        assert FLOATARRAYPTR.kind == 'pointer'
        assert FLOATARRAYPTR.item.kind == 'array'
        assert FLOATARRAYPTR.item.length == 100
        assert ffi.typeof(lib.g1) is FLOATARRAYPTR.item

    def test_introspect_integer_const(self):
        ffi, lib = self.prepare("#define FOO 42",
                                'test_introspect_integer_const', """
            #define FOO 42
        """)
        assert dir(lib) == ['FOO']
        assert lib.FOO == ffi.integer_const('FOO') == 42

    def test_introspect_typedef(self):
        ffi, lib = self.prepare("typedef int foo_t;",
                                'test_introspect_typedef', """
            typedef int foo_t;
        """)
        assert ffi.list_types() == (['foo_t'], [], [])
        assert ffi.typeof('foo_t').kind == 'primitive'
        assert ffi.typeof('foo_t').cname == 'int'

    def test_introspect_typedef_multiple(self):
        ffi, lib = self.prepare("""
            typedef signed char a_t, c_t, g_t, b_t;
        """, 'test_introspect_typedef_multiple', """
            typedef signed char a_t, c_t, g_t, b_t;
        """)
        assert ffi.list_types() == (['a_t', 'b_t', 'c_t', 'g_t'], [], [])

    def test_introspect_struct(self):
        ffi, lib = self.prepare("""
            struct foo_s { int a; };
        """, 'test_introspect_struct', """
            struct foo_s { int a; };
        """)
        assert ffi.list_types() == ([], ['foo_s'], [])
        assert ffi.typeof('struct foo_s').kind == 'struct'
        assert ffi.typeof('struct foo_s').cname == 'struct foo_s'

    def test_introspect_union(self):
        ffi, lib = self.prepare("""
            union foo_s { int a; };
        """, 'test_introspect_union', """
            union foo_s { int a; };
        """)
        assert ffi.list_types() == ([], [], ['foo_s'])
        assert ffi.typeof('union foo_s').kind == 'union'
        assert ffi.typeof('union foo_s').cname == 'union foo_s'

    def test_introspect_struct_and_typedef(self):
        ffi, lib = self.prepare("""
            typedef struct { int a; } foo_t;
        """, 'test_introspect_struct_and_typedef', """
            typedef struct { int a; } foo_t;
        """)
        assert ffi.list_types() == (['foo_t'], [], [])
        assert ffi.typeof('foo_t').kind == 'struct'
        assert ffi.typeof('foo_t').cname == 'foo_t'

    def test_introspect_included_type(self):
        SOURCE = """
            typedef signed char schar_t;
            struct sint_t { int x; };
        """
        ffi1, lib1 = self.prepare(SOURCE,
            "test_introspect_included_type_parent", SOURCE)
        ffi2, lib2 = self.prepare("",
            "test_introspect_included_type", SOURCE,
            includes=[ffi1])
        assert ffi1.list_types() == ffi2.list_types() == (
                ['schar_t'], ['sint_t'], [])

    def test_introspect_order(self):
        ffi, lib = self.prepare("""
            union CFFIaaa { int a; }; typedef struct CFFIccc { int a; } CFFIb;
            union CFFIg   { int a; }; typedef struct CFFIcc  { int a; } CFFIbbb;
            union CFFIaa  { int a; }; typedef struct CFFIa   { int a; } CFFIbb;
        """, "test_introspect_order", """
            union CFFIaaa { int a; }; typedef struct CFFIccc { int a; } CFFIb;
            union CFFIg   { int a; }; typedef struct CFFIcc  { int a; } CFFIbbb;
            union CFFIaa  { int a; }; typedef struct CFFIa   { int a; } CFFIbb;
        """)
        assert ffi.list_types() == (['CFFIb', 'CFFIbb', 'CFFIbbb'],
                                    ['CFFIa', 'CFFIcc', 'CFFIccc'],
                                    ['CFFIaa', 'CFFIaaa', 'CFFIg'])

    def test_FFIFunctionWrapper(self):
        ffi, lib = self.prepare("void f(void);", "test_FFIFunctionWrapper",
                                "void f(void) { }")
        assert lib.f.__get__(42) is lib.f
        assert lib.f.__get__(42, int) is lib.f

    def test_function_returns_float_complex(self):
        import sys
        if sys.platform == 'win32':
            skip("MSVC may not support _Complex")
        ffi, lib = self.prepare(
            "float _Complex f1(float a, float b);",
            "test_function_returns_float_complex", """
            #include <complex.h>
            static float _Complex f1(float a, float b) { return a + I*2.0*b; }
        """, min_version=(1, 11, 0))
        result = lib.f1(1.25, 5.1)
        assert type(result) == complex
        assert result.real == 1.25   # exact
        assert (result.imag != 2*5.1) and (abs(result.imag - 2*5.1) < 1e-5) # inexact

    def test_function_returns_double_complex(self):
        import sys
        if sys.platform == 'win32':
            skip("MSVC may not support _Complex")
        ffi, lib = self.prepare(
            "double _Complex f1(double a, double b);",
            "test_function_returns_double_complex", """
            #include <complex.h>
            static double _Complex f1(double a, double b) { return a + I*2.0*b; }
        """, min_version=(1, 11, 0))
        result = lib.f1(1.25, 5.1)
        assert type(result) == complex
        assert result.real == 1.25   # exact
        assert result.imag == 2*5.1  # exact

    def test_function_argument_float_complex(self):
        import sys
        if sys.platform == 'win32':
            skip("MSVC may not support _Complex")
        ffi, lib = self.prepare(
            "float f1(float _Complex x);",
            "test_function_argument_float_complex", """
            #include <complex.h>
            static float f1(float _Complex x) { return cabsf(x); }
        """, min_version=(1, 11, 0))
        x = complex(12.34, 56.78)
        result = lib.f1(x)
        assert abs(result - abs(x)) < 1e-5
        result2 = lib.f1(ffi.cast("float _Complex", x))
        assert result2 == result

    def test_function_argument_double_complex(self):
        import sys
        if sys.platform == 'win32':
            skip("MSVC may not support _Complex")
        ffi, lib = self.prepare(
            "double f1(double _Complex);",
            "test_function_argument_double_complex", """
            #include <complex.h>
            static double f1(double _Complex x) { return cabs(x); }
        """, min_version=(1, 11, 0))
        x = complex(12.34, 56.78)
        result = lib.f1(x)
        assert abs(result - abs(x)) < 1e-11
        result2 = lib.f1(ffi.cast("double _Complex", x))
        assert result2 == result

    def test_typedef_array_dotdotdot(self):
        ffi, lib = self.prepare("""
            typedef int foo_t[...], bar_t[...];
            int gv[...];
            typedef int mat_t[...][...];
            typedef int vmat_t[][...];
            """,
            "test_typedef_array_dotdotdot", """
            typedef int foo_t[50], bar_t[50];
            int gv[23];
            typedef int mat_t[6][7];
            typedef int vmat_t[][8];
        """, min_version=(1, 8, 4))
        assert ffi.sizeof("foo_t") == 50 * ffi.sizeof("int")
        assert ffi.sizeof("bar_t") == 50 * ffi.sizeof("int")
        assert len(ffi.new("foo_t")) == 50
        assert len(ffi.new("bar_t")) == 50
        assert ffi.sizeof(lib.gv) == 23 * ffi.sizeof("int")
        assert ffi.sizeof("mat_t") == 6 * 7 * ffi.sizeof("int")
        assert len(ffi.new("mat_t")) == 6
        assert len(ffi.new("mat_t")[3]) == 7
        raises(ffi.error, ffi.sizeof, "vmat_t")
        p = ffi.new("vmat_t", 4)
        assert ffi.sizeof(p[3]) == 8 * ffi.sizeof("int")

    def test_call_with_custom_field_pos(self):
        ffi, lib = self.prepare("""
            struct foo { int x; ...; };
            struct foo f(void);
            struct foo g(int, ...);
            """, "test_call_with_custom_field_pos", """
            struct foo { int y, x; };
            struct foo f(void) {
                struct foo s = { 40, 200 };
                return s;
            }
            struct foo g(int a, ...) { }
        """)
        assert lib.f().x == 200
        e = raises(NotImplementedError, lib.g, 0)
        assert str(e.value) == (
            'ctype \'struct foo\' not supported as return value.  It is a '
            'struct declared with "...;", but the C calling convention may '
            'depend on the missing fields; or, it contains anonymous '
            'struct/unions.  Such structs are only supported '
            'as return value if the function is \'API mode\' and non-variadic '
            '(i.e. declared inside ffibuilder.cdef()+ffibuilder.set_source() '
            'and not taking a final \'...\' argument)')

    def test_call_with_nested_anonymous_struct(self):
        import sys
        if sys.platform == 'win32':
            skip("needs a GCC extension")
        ffi, lib = self.prepare("""
            struct foo { int a; union { int b, c; }; };
            struct foo f(void);
            struct foo g(int, ...);
            """, "test_call_with_nested_anonymous_struct", """
            struct foo { int a; union { int b, c; }; };
            struct foo f(void) {
                struct foo s = { 40 };
                s.b = 200;
                return s;
            }
            struct foo g(int a, ...) { }
        """)
        assert lib.f().b == 200
        e = raises(NotImplementedError, lib.g, 0)
        assert str(e.value) == (
            'ctype \'struct foo\' not supported as return value.  It is a '
            'struct declared with "...;", but the C calling convention may '
            'depend on the missing fields; or, it contains anonymous '
            'struct/unions.  Such structs are only supported '
            'as return value if the function is \'API mode\' and non-variadic '
            '(i.e. declared inside ffibuilder.cdef()+ffibuilder.set_source() '
            'and not taking a final \'...\' argument)')

    def test_call_with_bitfield(self):
        ffi, lib = self.prepare("""
            struct foo { int x:5; };
            struct foo f(void);
            struct foo g(int, ...);
            """, "test_call_with_bitfield", """
            struct foo { int x:5; };
            struct foo f(void) {
                struct foo s = { 11 };
                return s;
            }
            struct foo g(int a, ...) { }
        """)
        assert lib.f().x == 11
        e = raises(NotImplementedError, lib.g, 0)
        assert str(e.value) == (
            "ctype 'struct foo' not supported as return value.  It is a struct "
            "with bit fields, which libffi does not support.  Such structs are "
            "only supported as return value if the function is 'API mode' and "
            "non-variadic (i.e. declared inside ffibuilder.cdef()+ffibuilder."
            "set_source() and not taking a final '...' argument)")

    def test_call_with_zero_length_field(self):
        import sys
        if sys.platform == 'win32':
            skip("zero-length field not supported by MSVC")
        ffi, lib = self.prepare("""
            struct foo { int a; int x[0]; };
            struct foo f(void);
            struct foo g(int, ...);
            """, "test_call_with_zero_length_field", """
            struct foo { int a; int x[0]; };
            struct foo f(void) {
                struct foo s = { 42 };
                return s;
            }
            struct foo g(int a, ...) { }
        """)
        assert lib.f().a == 42
        e = raises(NotImplementedError, lib.g, 0)
        assert str(e.value) == (
           "ctype 'struct foo' not supported as return value.  It is a "
           "struct with a zero-length array, which libffi does not support.  "
           "Such structs are only supported as return value if the function is "
           "'API mode' and non-variadic (i.e. declared inside ffibuilder.cdef()"
           "+ffibuilder.set_source() and not taking a final '...' argument)")

    def test_call_with_union(self):
        ffi, lib = self.prepare("""
            union foo { int a; char b; };
            union foo f(void);
            union foo g(int, ...);
            """, "test_call_with_union", """
            union foo { int a; char b; };
            union foo f(void) {
                union foo s = { 42 };
                return s;
            }
            union foo g(int a, ...) { }
        """)
        assert lib.f().a == 42
        e = raises(NotImplementedError, lib.g, 0)
        assert str(e.value) == (
           "ctype 'union foo' not supported as return value by libffi.  "
           "Unions are only supported as return value if the function is "
           "'API mode' and non-variadic (i.e. declared inside ffibuilder.cdef()"
           "+ffibuilder.set_source() and not taking a final '...' argument)")

    def test_call_with_packed_struct(self):
        import sys
        if sys.platform == 'win32':
            skip("needs a GCC extension")
        ffi, lib = self.prepare("""
            struct foo { char y; int x; };
            struct foo f(void);
            struct foo g(int, ...);
        """, "test_call_with_packed_struct", """
            struct foo { char y; int x; } __attribute__((packed));
            struct foo f(void) {
                struct foo s = { 40, 200 };
                return s;
            }
            struct foo g(int a, ...) {
                struct foo s = { 41, 201 };
                return s;
            }
        """, packed=True, min_version=(1, 8, 3))
        assert ord(lib.f().y) == 40
        assert lib.f().x == 200
        e = raises(NotImplementedError, lib.g, 0)
        assert str(e.value) == (
           "ctype 'struct foo' not supported as return value.  It is a 'packed'"
           " structure, with a different layout than expected by libffi.  "
           "Such structs are only supported as return value if the function is "
           "'API mode' and non-variadic (i.e. declared inside ffibuilder.cdef()"
           "+ffibuilder.set_source() and not taking a final '...' argument)")

    def test_gcc_visibility_hidden(self):
        import sys
        if sys.platform == 'win32':
            skip("test for gcc/clang")
        ffi, lib = self.prepare("""
        int f(int);
        """, "test_gcc_visibility_hidden", """
        int f(int a) { return a + 40; }
        """, extra_compile_args=['-fvisibility=hidden'])
        assert lib.f(2) == 42

    def test_override_default_definition(self):
        ffi, lib = self.prepare("""
        typedef long int16_t, char16_t;
        """, "test_override_default_definition", """
        """)
        assert ffi.typeof("int16_t") is ffi.typeof("char16_t") is ffi.typeof("long")

    def test_char16_char32_plain_c(self):
        ffi, lib = self.prepare("""
            char16_t foo_2bytes(char16_t);
            char32_t foo_4bytes(char32_t);
        """, "test_char16_char32_type_nocpp", """
        #if !defined(__cplusplus) || (!defined(_LIBCPP_VERSION) && __cplusplus < 201103L)
        typedef uint_least16_t char16_t;
        typedef uint_least32_t char32_t;
        #endif

        char16_t foo_2bytes(char16_t a) { return (char16_t)(a + 42); }
        char32_t foo_4bytes(char32_t a) { return (char32_t)(a + 42); }
        """, min_version=(1, 11, 0))
        assert lib.foo_2bytes(u'\u1234') == u'\u125e'
        assert lib.foo_4bytes(u'\u1234') == u'\u125e'
        assert lib.foo_4bytes(u'\U00012345') == u'\U0001236f'
        raises(TypeError, lib.foo_2bytes, u'\U00012345')
        raises(TypeError, lib.foo_2bytes, 1234)
        raises(TypeError, lib.foo_4bytes, 1234)

    def test_loader_spec(self):
        import sys
        ffi, lib = self.prepare("", "test_loader_spec", "")
        if sys.version_info < (3,):
            assert not hasattr(lib, '__loader__')
            assert not hasattr(lib, '__spec__')
        else:
            assert lib.__loader__ is None
            assert lib.__spec__ is None

    def test_release(self):
        ffi, lib = self.prepare("", "test_release", "")
        p = ffi.new("int[]", 123)
        ffi.release(p)
        # here, reading p[0] might give garbage or segfault...
        ffi.release(p)   # no effect

    def test_release_new_allocator(self):
        ffi, lib = self.prepare("struct ab { int a, b; };",
                                "test_release_new_allocator",
                                "struct ab { int a, b; };")
        seen = []
        def myalloc(size):
            seen.append(size)
            return ffi.new("char[]", b"X" * size)
        def myfree(raw):
            seen.append(raw)
        alloc2 = ffi.new_allocator(alloc=myalloc, free=myfree)
        p = alloc2("int[]", 15)
        assert seen == [15 * 4]
        ffi.release(p)
        assert seen == [15 * 4, p]
        ffi.release(p)    # no effect
        assert seen == [15 * 4, p]
        #
        del seen[:]
        p = alloc2("struct ab *")
        assert seen == [2 * 4]
        ffi.release(p)
        assert seen == [2 * 4, p]
        ffi.release(p)    # no effect
        assert seen == [2 * 4, p]

    def test_struct_with_func_with_struct_arg(self):
        ffi, lib = self.prepare("""struct BinaryTree {
                int (* CompareKey)(struct BinaryTree tree);
            };""",
            "test_struct_with_func_with_struct_arg", """
            struct BinaryTree {
                int (* CompareKey)(struct BinaryTree tree);
            };
        """)
        e = raises(RuntimeError, ffi.new, "struct BinaryTree *")
        # we should check e.value, but untranslated it crashes with a
        # regular recursion error.  There is a chance it occurs translated
        # too, but likely the check in the code ">= 1000" usually triggers
        # before that, and raise a RuntimeError too, but with the more
        # explicit message.

    def test_call_function_offset_in_bytes(self):
        from _cffi_backend import _offset_in_bytes
        ffi, lib = self.prepare("""
        int foo(char* arg);
        """, "test_call_function_offset_in_bytes", """
        int foo(char* arg) {
            return(arg[0] * 10);
        }
        """)
        assert lib.foo(_offset_in_bytes(b"foo", 0)) == ord(b"f") * 10
        assert lib.foo(_offset_in_bytes(b"foobxo", 4)) == ord(b"x") * 10
