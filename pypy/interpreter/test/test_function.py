from pypy.interpreter import eval
from pypy.interpreter.function import Function, Method, descr_function_get
from pypy.interpreter.pycode import PyCode
from pypy.interpreter.argument import Arguments


class TestMethod:
    @classmethod
    def compile(cls, src):
        assert src.strip().startswith("def ")
        compiler = cls.space.createcompiler()
        code = compiler.compile(src, '<hello>', 'exec', 0).co_consts_w[0]
        return Function(cls.space, code, cls.space.newdict())

    def setup_class(cls):
        src = """
def c(self, bar):
    return bar
        """
        cls.fn = cls.compile(src)


    def test_get(self):
        space = self.space
        w_meth = descr_function_get(space, self.fn, space.wrap(5), space.type(space.wrap(5)))
        meth = space.unwrap(w_meth)
        assert isinstance(meth, Method)

    def test_call(self):
        space = self.space
        w_meth = descr_function_get(space, self.fn, space.wrap(5), space.type(space.wrap(5)))
        meth = space.unwrap(w_meth)
        w_result = meth.call_args(Arguments(space, [space.wrap(42)]))
        assert space.unwrap(w_result) == 42

    def test_fail_call(self):
        space = self.space
        w_meth = descr_function_get(space, self.fn, space.wrap(5), space.type(space.wrap(5)))
        meth = space.unwrap(w_meth)
        args = Arguments(space, [space.wrap("spam"), space.wrap("egg")])
        self.space.raises_w(self.space.w_TypeError, meth.call_args, args)

    def test_method_get(self):
        space = self.space
        # Create some function for this test only
        func = self.compile("def m(self): return self")
        # Some shorthands
        obj1 = space.wrap(23)
        obj2 = space.wrap(42)
        args = Arguments(space, [])
        # Check method returned from func.__get__()
        w_meth1 = descr_function_get(space, func, obj1, space.type(obj1))
        meth1 = space.unwrap(w_meth1)
        assert isinstance(meth1, Method)
        assert meth1.call_args(args) == obj1
        # Check method returned from method.__get__()
        # --- meth1 is already bound so meth1.__get__(*) is meth1.
        w_meth2 = meth1.descr_method_get(obj2, space.type(obj2))
        meth2 = space.unwrap(w_meth2)
        assert isinstance(meth2, Method)
        assert meth2.call_args(args) == obj1
        # Check method returned from unbound_method.__get__()
        w_meth3 = descr_function_get(space, func, space.w_None, space.type(obj2))
        meth3 = space.unwrap(w_meth3)
        assert meth3 is func

class TestShortcuts(object):
    def compile(self, src):
        assert src.strip().startswith("def ")
        compiler = self.space.createcompiler()
        code = compiler.compile(src, '<hello>', 'exec', 0).co_consts_w[0]
        return Function(self.space, code, self.space.newdict())

    def test_call_function(self):
        space = self.space

        d = {}
        for i in range(10):
            args = "(" + ''.join(["a%d," % a for a in range(i)]) + ")"
            src = """
def f%s:
    return %s
""" % (args, args)
            exec src in d
            f = d['f']
            res = f(*range(i))
            fn = self.compile(src)
            code = fn.code

            assert fn.code.fast_natural_arity == i|PyCode.FLATPYCALL
            if i < 5:

                def bomb(*args):
                    assert False, "shortcutting should have avoided this"

                code.funcrun = bomb
                code.funcrun_obj = bomb

            args_w = map(space.wrap, range(i))
            w_res = space.call_function(fn, *args_w)
            check = space.is_true(space.eq(w_res, space.wrap(res)))
            assert check

    def test_flatcall(self):
        space = self.space

        src = """
def f(a):
    return a"""
        fn = self.compile(src)

        assert fn.code.fast_natural_arity == 1|PyCode.FLATPYCALL

        def bomb(*args):
            assert False, "shortcutting should have avoided this"

        fn.code.funcrun = bomb
        fn.code.funcrun_obj = bomb

        w_3 = space.newint(3)
        w_res = space.call_function(fn, w_3)

        assert w_res is w_3

        w_res = space.appexec([fn, w_3], """(f, x):
        return f(x)
        """)

        assert w_res is w_3

    def test_flatcall_method(self):
        space = self.space

        src = """
def f(self, a):
    return a
"""
        fn = self.compile(src)

        assert fn.code.fast_natural_arity == 2|PyCode.FLATPYCALL

        def bomb(*args):
            assert False, "shortcutting should have avoided this"

        fn.code.funcrun = bomb
        fn.code.funcrun_obj = bomb

        w_3 = space.newint(3)
        w_res = space.appexec([fn, w_3], """(f, x):
        class A(object):
           m = f
        y = A().m(x)
        b = A().m
        z = b(x)
        return y is x and z is x
        """)

        assert space.is_true(w_res)

    def test_flatcall_default_arg(self):
        space = self.space

        src = """
def f(a, b):
    return a+b
"""
        code = self.compile(src).code
        fn = Function(self.space, code, self.space.newdict(),
                      defs_w=[space.newint(1)])

        assert fn.code.fast_natural_arity == 2|eval.Code.FLATPYCALL

        def bomb(*args):
            assert False, "shortcutting should have avoided this"

        code.funcrun = bomb
        code.funcrun_obj = bomb

        w_3 = space.newint(3)
        w_4 = space.newint(4)
        # ignore this for now
        #w_res = space.call_function(fn, w_3)
        # assert space.eq_w(w_res, w_4)

        w_res = space.appexec([fn, w_3], """(f, x):
        return f(x)
        """)

        assert space.eq_w(w_res, w_4)

    def test_flatcall_default_arg_method(self):
        space = self.space

        src = """
def f(self, a, b):
    return a+b
        """
        code = self.compile(src).code
        fn = Function(self.space, code, self.space.newdict(),
                      defs_w=[space.newint(1)])

        assert fn.code.fast_natural_arity == 3|eval.Code.FLATPYCALL

        def bomb(*args):
            assert False, "shortcutting should have avoided this"

        code.funcrun = bomb
        code.funcrun_obj = bomb

        w_3 = space.newint(3)

        w_res = space.appexec([fn, w_3], """(f, x):
        class A(object):
           m = f
        y = A().m(x)
        b = A().m
        z = b(x)
        return y+10*z
        """)

        assert space.eq_w(w_res, space.wrap(44))


class TestFunction:

    def test_func_defaults(self):
        from pypy.interpreter import gateway
        def g(w_a=None):
            pass
        app_g = gateway.interp2app_temp(g)
        space = self.space
        w_g = space.wrap(app_g)
        w_defs = space.getattr(w_g, space.wrap("__defaults__"))
        assert space.is_w(w_defs, space.w_None)
        w_count = space.getattr(w_g, space.wrap("__defaults_count__"))
        assert space.unwrap(w_count) == 1
