from .support import HPyTest

class TestTuple(HPyTest):

    def test_Check(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                if (HPyTuple_Check(ctx, arg))
                    return HPy_Dup(ctx, ctx->h_True);
                return HPy_Dup(ctx, ctx->h_False);
            }
            @EXPORT(f)
            @INIT
        """)
        class MyTuple(tuple):
            pass

        assert mod.f(()) is True
        assert mod.f([]) is False
        assert mod.f(MyTuple()) is True

    def test_FromArray(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy x = HPyLong_FromLong(ctx, 42);
                if (HPy_IsNull(x))
                     return HPy_NULL;
                HPy items[] = {self, arg, x};
                HPy res = HPyTuple_FromArray(ctx, items, 3);
                HPy_Close(ctx, x);
                return res;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f('hello') == (mod, 'hello', 42)

    def test_Pack(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                HPy x = HPyLong_FromLong(ctx, 42);
                if (HPy_IsNull(x))
                     return HPy_NULL;
                HPy result = HPyTuple_Pack(ctx, 3, self, arg, x);
                HPy_Close(ctx, x);
                return result;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f('hello') == (mod, 'hello', 42)

    def test_TupleBuilder(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy h_self, HPy h_arg)
            {
                HPyTupleBuilder builder = HPyTupleBuilder_New(ctx, 3);
                HPyTupleBuilder_Set(ctx, builder, 0, h_arg);
                HPyTupleBuilder_Set(ctx, builder, 1, ctx->h_True);
                HPy h_num = HPyLong_FromLong(ctx, -42);
                if (HPy_IsNull(h_num))
                {
                    HPyTupleBuilder_Cancel(ctx, builder);
                    return HPy_NULL;
                }
                HPyTupleBuilder_Set(ctx, builder, 2, h_num);
                HPy_Close(ctx, h_num);
                HPy h_tuple = HPyTupleBuilder_Build(ctx, builder);
                return h_tuple;
            }
            @EXPORT(f)
            @INIT
        """)
        assert mod.f("xy") == ("xy", True, -42)
