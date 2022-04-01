# -*- encoding: utf-8 -*-

from .support import HPyTest

class TestUnicode(HPyTest):

    def test_Check(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                if (HPyUnicode_Check(ctx, arg))
                    return HPy_Dup(ctx, ctx->h_True);
                return HPy_Dup(ctx, ctx->h_False);
            }
            @EXPORT(f)
            @INIT
        """)
        class MyUnicode(str):
            pass

        assert mod.f('hello') is True
        assert mod.f(b'hello') is False
        assert mod.f(MyUnicode('hello')) is True

    def test_FromString(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                return HPyUnicode_FromString(ctx, "foobar");
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() == "foobar"

    def test_FromWideChar(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                const wchar_t buf[] = { 'h', 'e', 'l', 'l', 0xf2, ' ',
                                        'w', 'o', 'r', 'l', 'd', 0 };
                long n = HPyLong_AsLong(ctx, arg);
                return HPyUnicode_FromWideChar(ctx, buf, n);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(-1) == "hellò world"
        assert mod.f(11) == "hellò world"
        assert mod.f(5) == "hellò"


    def test_AsUTF8String(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                return HPyUnicode_AsUTF8String(ctx, arg);
            }
            @EXPORT(f)
            @INIT
        """)
        s = 'hellò'
        b = mod.f(s)
        assert type(b) is bytes
        assert b == s.encode('utf-8')


    def test_AsUTF8AndSize(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy_ssize_t n;
                const char* buf = HPyUnicode_AsUTF8AndSize(ctx, arg, &n);
                long res = 0;
                for(int i=0; i<n; i++)
                    res = (res * 10) + buf[i];
                return HPyLong_FromLong(ctx, res);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f('ABC') == 100*ord('A') + 10*ord('B') + ord('C')
        assert mod.f(b'A\0C'.decode('utf-8')) == 100*ord('A') + ord('C')


    def test_DecodeFSDefault(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy_ssize_t n;
                const char* buf = HPyUnicode_AsUTF8AndSize(ctx, arg, &n);
                return HPyUnicode_DecodeFSDefault(ctx, buf);
                return HPy_Dup(ctx, ctx->h_None);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f('ABC') == "ABC"