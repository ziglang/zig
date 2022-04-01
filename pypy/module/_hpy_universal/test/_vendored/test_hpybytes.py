from .support import HPyTest

class TestBytes(HPyTest):

    def test_Check(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                if (HPyBytes_Check(ctx, arg))
                    return HPy_Dup(ctx, ctx->h_True);
                return HPy_Dup(ctx, ctx->h_False);
            }
            @EXPORT(f)
            @INIT
        """)
        class MyBytes(bytes):
            pass

        assert mod.f(b'hello') is True
        assert mod.f('hello') is False
        assert mod.f(MyBytes(b'hello')) is True

    def test_Size(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy_ssize_t a = HPyBytes_Size(ctx, arg);
                HPy_ssize_t b = HPyBytes_GET_SIZE(ctx, arg);
                return HPyLong_FromLongLong(ctx, 10 * a + b);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(b'hello') == 55

    def test_AsString(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                long res = 0;
                HPy_ssize_t n = HPyBytes_Size(ctx, arg);
                char *buf = HPyBytes_AsString(ctx, arg);
                for(int i=0; i<n; i++)
                    res = (res * 10) + buf[i];
                return HPyLong_FromLong(ctx, res);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(b'ABC') == 100*ord('A') + 10*ord('B') + ord('C')

    def test_AS_STRING(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                long res = 0;
                HPy_ssize_t n = HPyBytes_Size(ctx, arg);
                char *buf = HPyBytes_AS_STRING(ctx, arg);
                for(int i=0; i<n; i++)
                    res = (res * 10) + buf[i];
                return HPyLong_FromLong(ctx, res);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(b'ABC') == 100*ord('A') + 10*ord('B') + ord('C')

    def test_FromString(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                char *buf;
                buf = HPyBytes_AsString(ctx, arg);
                return HPyBytes_FromString(ctx, buf);
            }

            @EXPORT(f)
            @INIT
        """)
        assert mod.f(b"aaa") == b"aaa"
        assert mod.f(b"") == b""

    def test_FromStringAndSize(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_VARARGS)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy *args,
                              HPy_ssize_t nargs)
            {
                HPy src;
                long len;
                char *buf;
                if (!HPyArg_Parse(ctx, NULL, args, nargs, "Ol", &src, &len)) {
                    return HPy_NULL;
                }
                buf = HPyBytes_AsString(ctx, src);
                return HPyBytes_FromStringAndSize(ctx, buf, len);
            }

            HPyDef_METH(f_null, "f_null", f_null_impl, HPyFunc_VARARGS)
            static HPy f_null_impl(HPyContext *ctx, HPy self, HPy *args,
                                   HPy_ssize_t nargs)
            {
                long len;
                if (!HPyArg_Parse(ctx, NULL, args, nargs, "l", &len)) {
                    return HPy_NULL;
                }

                return HPyBytes_FromStringAndSize(ctx, NULL, len);
            }

            @EXPORT(f)
            @EXPORT(f_null)
            @INIT
        """)
        assert mod.f(b"aaa", 3) == b"aaa"
        assert mod.f(b"abc", 2) == b"ab"
        assert mod.f(b"", 0) == b""
        with pytest.raises(SystemError):
            # negative size passed to HPyBytes_FromStringAndSize
            mod.f(b"abc", -1)
        for i in (-1, 0, 1):
            with pytest.raises(ValueError) as err:
                mod.f_null(i)
            assert str(err.value) == (
                "NULL char * passed to HPyBytes_FromStringAndSize")
