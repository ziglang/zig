from .support import HPyTest

class TestDict(HPyTest):

    def test_Check(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                if (HPyDict_Check(ctx, arg))
                    return HPy_Dup(ctx, ctx->h_True);
                return HPy_Dup(ctx, ctx->h_False);
            }
            @EXPORT(f)
            @INIT
        """)
        class MyDict(dict):
            pass

        assert mod.f({}) is True
        assert mod.f([]) is False
        assert mod.f(MyDict()) is True

    def test_New(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                return HPyDict_New(ctx);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() == {}

    def test_set_item(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy dict = HPyDict_New(ctx);
                if (HPy_IsNull(dict))
                    return HPy_NULL;
                HPy val = HPyLong_FromLong(ctx, 1234);
                if (HPy_SetItem(ctx, dict, arg, val) == -1)
                    return HPy_NULL;
                HPy_Close(ctx, val);
                return dict;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f('hello') == {'hello': 1234}

    def test_get_item(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy key = HPyUnicode_FromString(ctx, "hello");
                if (HPy_IsNull(key))
                    return HPy_NULL;
                HPy val = HPy_GetItem(ctx, arg, key);
                HPy_Close(ctx, key);
                if (HPy_IsNull(val)) {
                    HPyErr_Clear(ctx);
                    return HPy_Dup(ctx, ctx->h_None);
                }
                return val;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f({'hello': 1}) == 1
        assert mod.f({}) is None
