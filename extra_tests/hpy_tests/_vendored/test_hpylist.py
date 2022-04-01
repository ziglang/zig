from .support import HPyTest

class TestList(HPyTest):

    def test_Check(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                if (HPyList_Check(ctx, arg))
                    return HPy_Dup(ctx, ctx->h_True);
                return HPy_Dup(ctx, ctx->h_False);
            }
            @EXPORT(f)
            @INIT
        """)
        class MyList(list):
            pass

        assert mod.f([]) is True
        assert mod.f('hello') is False
        assert mod.f(MyList()) is True

    def test_New(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_NOARGS)
            static HPy f_impl(HPyContext *ctx, HPy self)
            {
                return HPyList_New(ctx, 0);
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f() == []

    def test_Append(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy list = HPyList_New(ctx, 0);
                if (HPy_IsNull(list))
                    return HPy_NULL;
                if (HPyList_Append(ctx, list, arg) == -1)
                    return HPy_NULL;
                if (HPyList_Append(ctx, list, arg) == -1)
                    return HPy_NULL;
                return list;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f(42) == [42, 42]

    def test_ListBuilder(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy h_self, HPy h_arg)
            {
                HPyListBuilder builder = HPyListBuilder_New(ctx, 3);
                HPyListBuilder_Set(ctx, builder, 0, h_arg);
                HPyListBuilder_Set(ctx, builder, 1, ctx->h_True);
                HPy h_num = HPyLong_FromLong(ctx, -42);
                if (HPy_IsNull(h_num))
                {
                    HPyListBuilder_Cancel(ctx, builder);
                    return HPy_NULL;
                }
                HPyListBuilder_Set(ctx, builder, 2, h_num);
                HPy_Close(ctx, h_num);
                HPy h_list = HPyListBuilder_Build(ctx, builder);
                return h_list;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f("xy") == ["xy", True, -42]
