
""" test proxy object
"""

from pypy.objspace.std.test.test_proxy import AppProxyBasic

class AppTestProxyNoDict(AppProxyBasic):
    def setup_method(self, meth):
        super(AppTestProxyNoDict, self).setup_method(meth)
        self.w_A = self.space.appexec([], """():
        class A(object):
            __slots__ = []
        return A
        """)
        self.w_proxy = self.space.appexec([], """():
        from __pypy__ import tproxy
        return tproxy
        """)
    
    def test_write_dict(self):
        c = self.Controller(self.A())
        obj = self.proxy(self.A, c.perform)
        raises(AttributeError, "obj.__dict__ = {}")

class AppTestProxyObj(AppProxyBasic):
    def setup_method(self, meth):
        super(AppTestProxyObj, self).setup_method(meth)
        self.w_A = self.space.appexec([], """():
        class A(object):
            pass
        return A
        """)
        
    def test_simple_obj(self):
        class AT(self.A):
            pass

        c = self.Controller(self.A())
        obj = self.proxy(AT, c.perform)
        
        assert type(obj) is AT
        assert obj.__class__ is AT

    def test__class__override(self):
        c = self.Controller(self.A())
        obj = self.proxy(self.A, c.perform)
        
        raises(TypeError, "obj.__class__ = self.A")

    def test_attribute_access(self):
        a = self.A()
        a.x = 3
        c = self.Controller(a)
        obj = self.proxy(self.A, c.perform)
        
        assert obj.x == 3

    def test_nonexistant_attribuite_access(self):
        c = self.Controller(self.A())
        obj = self.proxy(self.A, c.perform)
        raises(AttributeError, "obj.x")
    
    def test_setattr(self):
        a = self.A()
        c = self.Controller(a)
        obj = self.proxy(self.A, c.perform)
        obj.x = 1
        assert obj.x == 1
        assert a.x == 1

    def test_delattr(self):
        a = self.A()
        a.f = 3
        c = self.Controller(a)
        obj = self.proxy(self.A, c.perform)
        del obj.f
        raises(AttributeError, "obj.f")
    
    def test__dict__(self):
        a = self.A()
        a.x = 3
        c = self.Controller(a)
        obj = self.proxy(self.A, c.perform)
        assert 'x' in obj.__dict__
    
    def test_set__dict__(self):
        a = self.A()
        c = self.Controller(a)
        obj = self.proxy(self.A, c.perform)
        obj.__dict__ = {'x':3}
        assert obj.x == 3
        assert obj.__dict__.keys() == set(['x'])
    
    def test_repr(self):
        a = self.A()
        c = self.Controller(a)
        obj = self.proxy(self.A, c.perform)
        assert repr(obj)[:6] == repr(a)[:6]
