"""
NOTE: this tests are also meant to be run as PyPy "applevel" tests.

This means that global imports will NOT be visible inside the test
functions. In particular, you have to "import pytest" inside the test in order
to be able to use e.g. pytest.raises (which on PyPy will be implemented by a
"fake pytest module")
"""
from .support import HPyTest


class TestBasic(HPyTest):

    def test_get_version(self):
        if self.compiler.hpy_abi != 'universal':
            return
        import hpy.universal
        version, gitrev = hpy.universal.get_version()
        # it's a bit hard to test the CONTENT of these values. Let's just
        # check that they are strings...
        assert isinstance(version, str)
        assert isinstance(gitrev, str)

    def test_empty_module(self):
        import sys
        mod = self.make_module("""
            @INIT
        """)
        assert type(mod) is type(sys)

    def test_different_name(self):
        mod = self.make_module("""
            @INIT
        """, name="foo")
        assert mod.__name__ == "foo"

    def test_noop_function(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS, .doc="hello world")
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                return HPy_Dup(ctx, ctx->h_None);
            }

            @EXPORT(f)
            @INIT
        """)
        assert mod.f() is None
        assert mod.f.__doc__ == 'hello world'

    def test_self_is_module(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                return HPy_Dup(ctx, self);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() is mod

    def test_identity_function(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                return HPy_Dup(ctx, arg);
            }
            @EXPORT(f)
            @INIT
        """)
        x = object()
        assert mod.f(x) is x

    def test_float_asdouble(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                double a = HPyFloat_AsDouble(ctx, arg);
                return HPyFloat_FromDouble(ctx, a * 2.);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(1.) == 2.

    def test_wrong_number_of_arguments(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f_noargs, "f_noargs", f_noargs_impl, HPyFunc_NOARGS)
            static HPy f_noargs_impl(HPyContext *ctx, HPy self)
            {
                return HPy_Dup(ctx, ctx->h_None);
            }
            HPyDef_METH(f_o, "f_o", f_o_impl, HPyFunc_O)
            static HPy f_o_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                return HPy_Dup(ctx, ctx->h_None);
            }
            @EXPORT(f_noargs)
            @EXPORT(f_o)
            @INIT
        """)
        with pytest.raises(TypeError):
            mod.f_noargs(1)
        with pytest.raises(TypeError):
            mod.f_o()
        with pytest.raises(TypeError):
            mod.f_o(1, 2)

    def test_close(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy one = HPyLong_FromLong(ctx, 1);
                if (HPy_IsNull(one))
                    return HPy_NULL;
                HPy res = HPy_Add(ctx, arg, one);
                HPy_Close(ctx, one);
                return res;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(41.5) == 42.5

    def test_bool(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                int cond = HPyLong_AsLong(ctx, arg) > 5;
                return HPy_Dup(ctx, cond ? ctx->h_True : ctx->h_False);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(4) is False
        assert mod.f(6) is True

    def test_exception(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                long x = HPyLong_AsLong(ctx, arg);
                if (x < 5) {
                    return HPyLong_FromLong(ctx, -x);
                }
                else {
                    HPyErr_SetString(ctx, ctx->h_ValueError, "hello world");
                    return HPy_NULL;
                }
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(-10) == 10
        with pytest.raises(ValueError) as exc:
            mod.f(20)
        assert str(exc.value) == 'hello world'

    def test_varargs(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_VARARGS)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy *args, HPy_ssize_t nargs)
            {
                long a, b;
                if (!HPyArg_Parse(ctx, NULL, args, nargs, "ll", &a, &b))
                    return HPy_NULL;
                return HPyLong_FromLong(ctx, 10*a + b);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(4, 5) == 45

    def test_builtin_handles(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                long i = HPyLong_AsLong(ctx, arg);
                HPy h;
                switch(i) {
                    case 1: h = ctx->h_None; break;
                    case 2: h = ctx->h_False; break;
                    case 3: h = ctx->h_True; break;
                    case 4: h = ctx->h_ValueError; break;
                    case 5: h = ctx->h_TypeError; break;
                    case 6: h = ctx->h_IndexError; break;
                    case 7: h = ctx->h_SystemError; break;
                    case 8: h = ctx->h_BaseObjectType; break;
                    case 9: h = ctx->h_TypeType; break;
                    case 10: h = ctx->h_LongType; break;
                    case 11: h = ctx->h_UnicodeType; break;
                    case 12: h = ctx->h_TupleType; break;
                    case 13: h = ctx->h_ListType; break;
                    case 14: h = ctx->h_NotImplemented; break;
                    case 15: h = ctx->h_Ellipsis; break;
                    default:
                        HPyErr_SetString(ctx, ctx->h_ValueError, "invalid choice");
                        return HPy_NULL;
                }
                return HPy_Dup(ctx, h);
            }
            @EXPORT(f)
            @INIT
        """)
        builtin_objs = (
            '<NULL>', None, False, True, ValueError, TypeError, IndexError,
            SystemError, object, type, int, str, tuple, list, NotImplemented, Ellipsis,
        )
        for i, obj in enumerate(builtin_objs):
            if i == 0:
                continue
            assert mod.f(i) is obj

    def test_extern_def(self):
        import pytest
        main = """
            extern HPyDef f;
            extern HPyDef g;
            extern HPyDef h;
            extern HPyDef i;

            @EXPORT(f)
            @EXPORT(g)
            @EXPORT(h)
            @EXPORT(i)
            @INIT
        """
        extra = """
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                return HPyLong_FromLong(ctx, 12345);
            }
            HPyDef_METH(g, "g", g_impl, HPyFunc_O)
            static HPy g_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                return HPy_Dup(ctx, arg);
            }
            HPyDef_METH(h, "h", h_impl, HPyFunc_VARARGS)
            static HPy h_impl(HPyContext *ctx, HPy self, HPy *args, HPy_ssize_t nargs)
            {
                long a, b;
                if (!HPyArg_Parse(ctx, NULL, args, nargs, "ll", &a, &b))
                    return HPy_NULL;
                return HPyLong_FromLong(ctx, 10*a + b);
            }
            HPyDef_METH(i, "i", i_impl, HPyFunc_KEYWORDS)
            static HPy i_impl(HPyContext *ctx, HPy self, HPy *args, HPy_ssize_t nargs,
                              HPy kw)
            {
                long a, b;
                static const char *kwlist[] = { "a", "b", NULL };
                if (!HPyArg_ParseKeywords(ctx, NULL, args, nargs, kw, "ll", kwlist, &a, &b))
                    return HPy_NULL;
                return HPyLong_FromLong(ctx, 10*a + b);
            }
        """
        mod = self.make_module(main, extra_sources=[extra])
        assert mod.f() == 12345
        assert mod.g(42) == 42
        assert mod.h(5, 6) == 56
        assert mod.i(4, 3) == 43
        assert mod.i(a=2, b=5) == 25
        with pytest.raises(TypeError):
            mod.h("not an integer", "not an integer either")

    def test_Float_FromDouble(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                return HPyFloat_FromDouble(ctx, 123.45);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() == 123.45

    def test_unsupported_signature(self):
        import pytest
        with pytest.raises(ValueError) as exc:
            self.make_module("""
                HPyDef f = {
                    .kind = HPyDef_Kind_Meth,
                    .meth = {
                        .name = "f",
                        .signature = 1234,
                    }
                };
                @EXPORT(f)
                @INIT
            """)
        assert str(exc.value) == 'Unsupported HPyMeth signature'

    def test_repr_str_ascii_bytes(self):
        mod = self.make_module("""
            HPyDef_METH(f1, "f1", f1_impl, HPyFunc_O)
            static HPy f1_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                return HPy_Repr(ctx, arg);
            }
            HPyDef_METH(f2, "f2", f2_impl, HPyFunc_O)
            static HPy f2_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                return HPy_Str(ctx, arg);
            }
            HPyDef_METH(f3, "f3", f3_impl, HPyFunc_O)
            static HPy f3_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                return HPy_ASCII(ctx, arg);
            }
            HPyDef_METH(f4, "f4", f4_impl, HPyFunc_O)
            static HPy f4_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                return HPy_Bytes(ctx, arg);
            }
            @EXPORT(f1)
            @EXPORT(f2)
            @EXPORT(f3)
            @EXPORT(f4)
            @INIT
        """)
        assert mod.f1("\u1234") == "'\u1234'"
        assert mod.f2(42) == "42"
        assert mod.f3("\u1234") == "'\\u1234'"
        assert mod.f4(bytearray(b"foo")) == b"foo"

    def test_is_true(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                int cond = HPy_IsTrue(ctx, arg);
                return HPy_Dup(ctx, cond ? ctx->h_True : ctx->h_False);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f("1234") is True
        assert mod.f("") is False

    def test_richcompare(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy arg2 = HPyLong_FromLong(ctx, 100);
                HPy result = HPy_RichCompare(ctx, arg, arg2, HPy_GT);
                HPy_Close(ctx, arg2);
                return result;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(100) is False
        assert mod.f(150) is True

    def test_richcomparebool(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy arg2 = HPyLong_FromLong(ctx, 100);
                int result = HPy_RichCompareBool(ctx, arg, arg2, HPy_GE);
                HPy_Close(ctx, arg2);
                return HPyLong_FromLong(ctx, -result);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(50) == 0
        assert mod.f(100) == -1

    def test_hash(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy_hash_t hash = HPy_Hash(ctx, arg);
                return HPyLong_FromSsize_t(ctx, hash);
            }
            @EXPORT(f)
            @INIT
        """)
        x = object()
        assert mod.f(x) == hash(x)

    def test_ctx_name(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                return HPyUnicode_FromString(ctx, ctx->name);
            }

            @EXPORT(f)
            @INIT
        """)
        ctx_name = mod.f()
        hpy_abi = self.compiler.hpy_abi
        if hpy_abi == 'cpython':
            assert ctx_name == 'HPy CPython ABI'
        elif hpy_abi == 'universal':
            # this can be "HPy Universal ABI (CPython backend)" or
            # "... (PyPy backend)", etc.
            assert ctx_name.startswith('HPy Universal ABI')
        elif hpy_abi == 'debug':
            assert ctx_name.startswith('HPy Debug Mode ABI')
        else:
            assert False, 'unexpected hpy_abi: %s' % hpy_abi

    def test_FromVoidP_AsVoidP(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                void *p = HPy_AsVoidP(arg);
                HPy h = HPy_FromVoidP(p);
                return HPy_Dup(ctx, h);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(42) == 42
