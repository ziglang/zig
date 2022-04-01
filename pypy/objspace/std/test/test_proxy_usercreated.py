
import py
from pypy.interpreter.baseobjspace import W_Root, ObjSpace
from pypy.objspace.std.test.test_proxy_internals import AppProxy
from pypy.interpreter.typedef import TypeDef
from pypy.interpreter.gateway import interp2app
from pypy.objspace.std.transparent import register_proxyable
from pypy.conftest import option


class W_Wrapped(W_Root):
    def new(space, w_type):
        return space.wrap(W_Wrapped())

    def name(self, space):
        return space.wrap("wrapped")
    name.unwrap_spec = ['self', ObjSpace]

W_Wrapped.typedef = TypeDef(
    'Wrapped',
    __new__ = interp2app(W_Wrapped.new.im_func),
    __name__ = interp2app(W_Wrapped.name),
)


class AppTestProxyNewtype(AppProxy):
    def setup_class(cls):
        if option.runappdirect:
            py.test.skip("Impossible to run on appdirect")
        AppProxy.setup_class.im_func(cls)
        cls.w_wrapped = cls.space.wrap(W_Wrapped())
        register_proxyable(cls.space, W_Wrapped)

    def test_one(self):
        x = type(self.wrapped)()
        from __pypy__ import tproxy

        def f(name, *args, **kwds):
            return getattr(x, name)(*args, **kwds)

        t = tproxy(type(x), f)
        assert t.__name__ == x.__name__
