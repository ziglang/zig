
""" test proxy on functions and other crazy goodies
"""

from pypy.objspace.std.test.test_proxy import AppProxyBasic

class AppTestProxyFunction(object):
    spaceconfig = {"objspace.std.withtproxy": True}

    def setup_method(self, meth):
        self.w_get_proxy = self.space.appexec([], """():
        class Controller(object):
            def __init__(self, obj):
                self.obj = obj
    
            def perform(self, name, *args, **kwargs):
                return getattr(self.obj, name)(*args, **kwargs)
        def get_proxy(f):
            import types
            from __pypy__ import tproxy as proxy
            return proxy(types.FunctionType, Controller(f).perform)
        return get_proxy
        """)
    
    def test_function_noargs(self):
        def f():
            return 3
        
        fun = self.get_proxy(f)
        assert fun() == f()
    
    def test_simple_function(self):
        def f(x):
            return x

        fun = self.get_proxy(f)
        assert fun(3) == f(3)

    def test_function_args(self):
        def f(x, y):
            return x
        
        fun = self.get_proxy(f)
        raises(TypeError, "fun(3)")
        assert fun(1,2) == 1

    def test_method_bind(self):
        def f(self):
            return 3
        
        class A(object):
            pass
            
        fun = self.get_proxy(f)
        assert fun.__get__(A())() == 3

    def test_function_repr(self):
        def f():
            pass
        
        fun = self.get_proxy(f)
        assert repr(fun).startswith("<function test_function_repr.<locals>.f")

    def test_func_code(self):
        def f():
            pass
        
        fun = self.get_proxy(f)
        assert fun.__code__ is f.__code__

    def test_funct_prop_setter_del(self):
        def f():
            pass
        
        fun = self.get_proxy(f)
        fun.__doc__ = "aaa"
        assert f.__doc__ == 'aaa'
        del fun.__doc__
        assert f.__doc__ is None

    def test_proxy_bind_method(self):
        class A(object):
            pass
        
        def f(self):
            return 3
        
        class AA(object):
            pass
        
        from __pypy__ import tproxy as proxy
        a = A()
        class X(object):
            def __init__(self, x):
                self.x = x
            def f(self, name, *args, **kwargs):
                return getattr(self.x, name)(*args, **kwargs)
        
        y = proxy(type(f), X(f).f)
        x = proxy(AA, X(a).f)
        AA.f = y
        assert x.f() == 3
