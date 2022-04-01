from .support import HPyTest


class TestCall(HPyTest):
    def argument_combinations(self, **items):
        """ Returns all possible ways of expressing the given items as
            arguments to a function.
        """
        items = list(items.items())
        for i in range(len(items) + 1):
            args = tuple(item[1] for item in items[:i])
            kw = dict(items[i:])
            yield {"args": args, "kw": kw}
            if not args:
                yield {"kw": kw}
            if not kw:
                yield {"args": args}
            if not args and not kw:
                yield {}

    def test_hpy_calltupledict(self):
        import pytest
        mod = self.make_module("""
            HPyDef_METH(call, "call", call_impl, HPyFunc_KEYWORDS)
            static HPy call_impl(HPyContext *ctx, HPy self,
                                 HPy *args, HPy_ssize_t nargs, HPy kw)
            {

                HPy f, result;
                HPy f_args = HPy_NULL;
                HPy f_kw = HPy_NULL;
                HPyTracker ht;
                static const char *kwlist[] = { "f", "args", "kw", NULL };
                if (!HPyArg_ParseKeywords(ctx, &ht, args, nargs, kw, "O|OO",
                                          kwlist, &f, &f_args, &f_kw)) {
                    return HPy_NULL;
                }
                result = HPy_CallTupleDict(ctx, f, f_args, f_kw);
                HPyTracker_Close(ctx, ht);
                return result;
            }
            @EXPORT(call)
            @INIT
        """)

        def f(a, b):
            return a + b

        def g():
            return "this is g"

        # test passing arguments with handles of the correct type --
        # i.e. args is a tuple or a null handle, kw is a dict or a null handle.
        for d in self.argument_combinations(a=1, b=2):
            assert mod.call(f, **d) == 3
        for d in self.argument_combinations(a=1):
            with pytest.raises(TypeError):
                mod.call(f, **d)
        for d in self.argument_combinations():
            with pytest.raises(TypeError):
                mod.call(f, **d)
        for d in self.argument_combinations():
            assert mod.call(g, **d) == "this is g"
        for d in self.argument_combinations(object=2):
            assert mod.call(str, **d) == "2"
        for d in self.argument_combinations():
            with pytest.raises(TypeError):
                mod.call("not callable", **d)
        for d in self.argument_combinations(unknown=2):
            with pytest.raises(TypeError):
                mod.call("not callable", **d)

        # test passing handles of the incorrect type as arguments
        with pytest.raises(TypeError):
            mod.call(f, args=[1, 2])
        with pytest.raises(TypeError):
            mod.call(f, args="string")
        with pytest.raises(TypeError):
            mod.call(f, args=1)
        with pytest.raises(TypeError):
            mod.call(f, args=None)
        with pytest.raises(TypeError):
            mod.call(f, kw=[1, 2])
        with pytest.raises(TypeError):
            mod.call(f, kw="string")
        with pytest.raises(TypeError):
            mod.call(f, kw=1)
        with pytest.raises(TypeError):
            mod.call(f, kw=None)

    def test_hpycallable_check(self):
        mod = self.make_module("""
            HPyDef_METH(f, "f", f_impl, HPyFunc_O)
            static HPy f_impl(HPyContext *ctx, HPy self, HPy arg)
            {
                if (HPyCallable_Check(ctx, arg))
                    return HPy_Dup(ctx, ctx->h_True);
                return HPy_Dup(ctx, ctx->h_False);
            }
            @EXPORT(f)
            @INIT
        """)

        def f():
            return "this is f"

        assert mod.f(f) is True
        assert mod.f(str) is True
        assert mod.f("a") is False
        assert mod.f(3) is False
