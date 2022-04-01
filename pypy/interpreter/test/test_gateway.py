# -*- coding: utf-8 -*-

from __future__ import division, print_function  # for test_app2interp_future
from pypy.interpreter import gateway, argument
from pypy.interpreter.gateway import ObjSpace, W_Root, WrappedDefault
from pypy.interpreter.signature import Signature
from pypy.interpreter.error import OperationError
import py
import sys


class FakeFunc(object):
    def __init__(self, space, name):
        self.space = space
        self.name = name
        self.defs_w = []
        self.w_kw_defs = None


class TestBuiltinCode:
    def test_signature(self, space):
        def c(space, w_x, w_y, hello_w):
            pass
        code = gateway.BuiltinCode(c, unwrap_spec=[gateway.ObjSpace,
                                                   gateway.W_Root,
                                                   gateway.W_Root,
                                                   'args_w'])
        assert code.signature() == Signature(['x', 'y'], 'hello', None)
        def d(self, w_boo):
            pass

        class W_X(W_Root):
            pass

        code = gateway.BuiltinCode(d, unwrap_spec= ['self',
                                                   gateway.W_Root], self_type=W_X)
        assert code.signature() == Signature(['self', 'boo'], None, None)
        def e(space, w_x, w_y, __args__):
            pass
        code = gateway.BuiltinCode(e, unwrap_spec=[gateway.ObjSpace,
                                                   gateway.W_Root,
                                                   gateway.W_Root,
                                                   gateway.Arguments])
        assert code.signature() == Signature(['x', 'y'], 'args', 'keywords')

        def f(space, index):
            pass
        code = gateway.BuiltinCode(f, unwrap_spec=[gateway.ObjSpace, "index"])
        assert code.signature() == Signature(["index"], None, None)

        def f(space, __kwonly__, w_x):
            pass
        code = gateway.BuiltinCode(f, unwrap_spec=[gateway.ObjSpace,
                                                   "kwonly", W_Root])
        assert code.signature() == Signature(['x'], kwonlyargcount=1)
        assert space.int_w(space.getattr(
            code, space.newtext('co_kwonlyargcount'))) == 1


    def test_call(self):
        def c(space, w_x, w_y, hello_w):
            u = space.unwrap
            w = space.wrap
            assert len(hello_w) == 2
            assert u(hello_w[0]) == 0
            assert u(hello_w[1]) == True
            return w((u(w_x) - u(w_y) + len(hello_w)))
        code = gateway.BuiltinCode(c, unwrap_spec=[gateway.ObjSpace,
                                                   gateway.W_Root,
                                                   gateway.W_Root,
                                                   'args_w'])
        w = self.space.wrap
        args = argument.Arguments(self.space, [w(123), w(23), w(0), w(True)])
        w_result = code.funcrun(FakeFunc(self.space, "c"), args)
        assert self.space.eq_w(w_result, w(102))

    def test_call_index(self):
        def c(space, index):
            assert type(index) is int
        code = gateway.BuiltinCode(c, unwrap_spec=[gateway.ObjSpace,
                                                   "index"])
        w = self.space.wrap
        args = argument.Arguments(self.space, [w(123)])
        code.funcrun(FakeFunc(self.space, "c"), args)

    def test_call_args(self):
        def c(space, w_x, w_y, __args__):
            args_w, kwds_w = __args__.unpack()
            u = space.unwrap
            w = space.wrap
            return w((u(w_x) - u(w_y) + len(args_w))
                     * u(kwds_w['boo']))
        code = gateway.BuiltinCode(c, unwrap_spec=[gateway.ObjSpace,
                                                   gateway.W_Root,
                                                   gateway.W_Root,
                                                   gateway.Arguments])
        w = self.space.wrap
        args = argument.Arguments(self.space, [w(123), w(23)], [], [],
                                  w_stararg = w((0, True)),
                                  w_starstararg = w({'boo': 10}))
        w_result = code.funcrun(FakeFunc(self.space, "c"), args)
        assert self.space.eq_w(w_result, w(1020))


class TestGateway:
    def test_app2interp(self):
        w = self.space.wrap
        def app_g3(a, b):
            return a+b
        g3 = gateway.app2interp_temp(app_g3)
        assert self.space.eq_w(g3(self.space, w('foo'), w('bar')), w('foobar'))

    def test_app2interp1(self):
        w = self.space.wrap
        def noapp_g3(a, b):
            return a+b
        g3 = gateway.app2interp_temp(noapp_g3, gateway.applevel_temp)
        assert self.space.eq_w(g3(self.space, w('foo'), w('bar')), w('foobar'))

    def test_app2interp_general_args(self):
        w = self.space.wrap
        def app_general(x, *args, **kwds):
            assert type(args) is tuple
            assert type(kwds) is dict
            return x + 10 * len(args) + 100 * len(kwds)
        gg = gateway.app2interp_temp(app_general)
        args = gateway.Arguments(self.space, [w(6), w(7)])
        assert self.space.int_w(gg(self.space, w(3), args)) == 23
        args = gateway.Arguments(self.space, [w(6)], [self.space.newtext('hello'), self.space.newtext('world')], [w(7), w(8)])
        assert self.space.int_w(gg(self.space, w(3), args)) == 213

    def test_app2interp_future(self):
        w = self.space.wrap
        def app_g3(a, b):
            print(end='')
            return a / b
        g3 = gateway.app2interp_temp(app_g3)
        assert self.space.eq_w(g3(self.space, w(1), w(4),), w(0.25))

    def test_interp2app(self):
        space = self.space
        w = space.wrap
        def g3(space, w_a, w_b):
            return space.add(w_a, w_b)
        app_g3 = gateway.interp2app_temp(g3)
        w_app_g3 = space.wrap(app_g3)
        assert self.space.eq_w(
            space.call(w_app_g3,
                       space.newtuple([w('foo'), w('bar')]),
                       space.newdict()),
            w('foobar'))
        assert self.space.eq_w(
            space.call_function(w_app_g3, w('foo'), w('bar')),
            w('foobar'))

    def test_interpindirect2app(self):
        space = self.space

        class BaseA(W_Root):
            def method(self, space, x):
                "This is a method"
                pass

            def method_with_default(self, space, x=5):
                pass

            @gateway.unwrap_spec(x=int)
            def method_with_unwrap_spec(self, space, x):
                pass

            def method_with_args(self, space, __args__):
                pass

        class A(BaseA):
            def method(self, space, x):
                return space.wrap(x + 2)

            def method_with_default(self, space, x):
                return space.wrap(x + 2)

            def method_with_unwrap_spec(self, space, x):
                return space.wrap(x + 2)

            def method_with_args(self, space, __args__):
                return space.wrap(42)

        class B(BaseA):
            def method(self, space, x):
                return space.wrap(x + 1)

            def method_with_default(self, space, x):
                return space.wrap(x + 1)

            def method_with_unwrap_spec(self, space, x):
                return space.wrap(x + 1)

            def method_with_args(self, space, __args__):
                return space.wrap(43)

        class FakeTypeDef(object):
            rawdict = {}
            bases = {}
            applevel_subclasses_base = None
            name = 'foo'
            hasdict = False
            weakrefable = False
            doc = 'xyz'

        meth = gateway.interpindirect2app(BaseA.method, {'x': int})
        w_c = space.wrap(meth)
        w_a = A()
        w_b = B()
        assert space.int_w(space.call_function(w_c, w_a, space.wrap(1))) == 1 + 2
        assert space.int_w(space.call_function(w_c, w_b, space.wrap(-10))) == -10 + 1

        doc = space.text_w(space.getattr(w_c, space.wrap('__doc__')))
        assert doc == "This is a method"

        meth_with_default = gateway.interpindirect2app(
            BaseA.method_with_default, {'x': int})
        w_d = space.wrap(meth_with_default)

        assert space.int_w(space.call_function(w_d, w_a, space.wrap(4))) == 4 + 2
        assert space.int_w(space.call_function(w_d, w_b, space.wrap(-10))) == -10 + 1
        assert space.int_w(space.call_function(w_d, w_a)) == 5 + 2
        assert space.int_w(space.call_function(w_d, w_b)) == 5 + 1

        meth_with_unwrap_spec = gateway.interpindirect2app(
            BaseA.method_with_unwrap_spec)
        w_e = space.wrap(meth_with_unwrap_spec)
        assert space.int_w(space.call_function(w_e, w_a, space.wrap(4))) == 4 + 2

        meth_with_args = gateway.interpindirect2app(
            BaseA.method_with_args)
        w_f = space.wrap(meth_with_args)
        assert space.int_w(space.call_function(w_f, w_a)) == 42
        assert space.int_w(space.call_function(w_f, w_b,
                                        space.wrap("ignored"))) == 43
        # check that the optimization works even though we are using
        # interpindirect2app:
        assert isinstance(meth_with_args._code,
                          gateway.BuiltinCodePassThroughArguments1)

    def test_interp2app_unwrap_spec(self):
        space = self.space
        w = space.wrap
        def g3(space, w_a, w_b):
            return space.add(w_a, w_b)
        app_g3 = gateway.interp2app_temp(g3,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      gateway.W_Root,
                                                      gateway.W_Root])
        w_app_g3 = space.wrap(app_g3)
        assert self.space.eq_w(
            space.call(w_app_g3,
                       space.newtuple([w('foo'), w('bar')]),
                       space.newdict()),
            w('foobar'))
        assert self.space.eq_w(
            space.call_function(w_app_g3, w('foo'), w('bar')),
            w('foobar'))

    def test_interp2app_unwrap_spec_auto(self):
        def f(space, w_a, w_b):
            pass
        unwrap_spec = gateway.BuiltinCode(f)._unwrap_spec
        assert unwrap_spec == [ObjSpace, W_Root, W_Root]

    def test_interp2app_unwrap_spec_bool(self):
        space = self.space
        w = space.wrap
        def g(space, b):
            return space.wrap(b)
        app_g = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace, bool])
        app_g2 = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace, bool])
        assert app_g is app_g2
        w_app_g = space.wrap(app_g)
        assert self.space.eq_w(space.call_function(w_app_g, space.wrap(True)),
                               space.wrap(True))

    def test_interp2app_unwrap_spec_bytes(self):
        # we can't use the "bytes" object for the unwrap_spec, because that's
        # an alias for "str" on the underlying Python2
        space = self.space
        def g(space, b):
            return space.newbytes(b)
        app_g = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace, 'bytes'])
        app_g2 = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace, 'bytes'])
        assert app_g is app_g2
        w_app_g = space.wrap(app_g)
        assert self.space.eq_w(space.call_function(w_app_g, space.newbytes("abc")),
                               space.newbytes("abc"))

    def test_interp2app_unwrap_spec_text(self):
        space = self.space
        def g(space, b):
            assert isinstance(b, str)
            return space.newtext(b)
        app_g = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace, 'text'])
        app_g2 = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace, 'text'])
        assert app_g is app_g2
        w_app_g = space.wrap(app_g)
        assert self.space.eq_w(space.call_function(w_app_g, space.newtext("abc")),
                               space.newtext("abc"))

    def test_caching_methods(self):
        class Base(gateway.W_Root):
            def f(self):
                return 1

        class A(Base):
            pass
        class B(Base):
            pass
        app_A = gateway.interp2app(A.f)
        app_B = gateway.interp2app(B.f)
        assert app_A is not app_B

    def test_interp2app_unwrap_spec_nonnegint(self):
        space = self.space
        w = space.wrap
        def g(space, x):
            return space.wrap(x * 6)
        app_g = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace,
                                                   'nonnegint'])
        app_g2 = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace,
                                                   'nonnegint'])
        assert app_g is app_g2
        w_app_g = space.wrap(app_g)
        assert self.space.eq_w(space.call_function(w_app_g, space.wrap(7)),
                               space.wrap(42))
        assert self.space.eq_w(space.call_function(w_app_g, space.wrap(0)),
                               space.wrap(0))
        space.raises_w(space.w_ValueError,
                       space.call_function, w_app_g, space.wrap(-1))

    def test_interp2app_unwrap_spec_c_int(self):
        from rpython.rlib.rarithmetic import r_longlong
        space = self.space
        w = space.wrap
        def g(space, x):
            return space.wrap(x + 6)
        app_g = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace,
                                                   'c_int'])
        app_ug = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace,
                                                   'c_uint'])
        app_ng = gateway.interp2app(g, unwrap_spec=[gateway.ObjSpace,
                                                   'c_nonnegint'])
        assert app_ug is not app_g
        w_app_g = space.wrap(app_g)
        w_app_ug = space.wrap(app_ug)
        w_app_ng = space.wrap(app_ng)
        #
        assert self.space.eq_w(space.call_function(w_app_g, space.wrap(7)),
                               space.wrap(13))
        space.raises_w(space.w_OverflowError,
                       space.call_function, w_app_g,
                       space.wrap(r_longlong(0x80000000)))
        space.raises_w(space.w_OverflowError,
                       space.call_function, w_app_g,
                       space.wrap(r_longlong(-0x80000001)))
        #
        assert self.space.eq_w(space.call_function(w_app_ug, space.wrap(7)),
                               space.wrap(13))
        assert self.space.eq_w(space.call_function(w_app_ug,
                                                   space.wrap(0x7FFFFFFF)),
                               space.wrap(r_longlong(0x7FFFFFFF+6)))
        space.raises_w(space.w_ValueError,
                       space.call_function, w_app_ug, space.wrap(-1))
        space.raises_w(space.w_OverflowError,
                       space.call_function, w_app_ug,
                       space.wrap(r_longlong(0x100000000)))
        #
        assert self.space.eq_w(space.call_function(w_app_ng, space.wrap(7)),
                               space.wrap(13))
        space.raises_w(space.w_OverflowError,
                       space.call_function, w_app_ng,
                       space.wrap(r_longlong(0x80000000)))
        space.raises_w(space.w_ValueError,
                       space.call_function, w_app_ng, space.wrap(-1))

    def test_interp2app_unwrap_spec_args_w(self):
        space = self.space
        w = space.wrap
        def g3_args_w(space, args_w):
            return space.add(args_w[0], args_w[1])
        app_g3_args_w = gateway.interp2app_temp(g3_args_w,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      'args_w'])
        w_app_g3_args_w = space.wrap(app_g3_args_w)
        assert self.space.eq_w(
            space.call(w_app_g3_args_w,
                       space.newtuple([w('foo'), w('bar')]),
                       space.newdict()),
            w('foobar'))
        assert self.space.eq_w(
            space.call_function(w_app_g3_args_w, w('foo'), w('bar')),
            w('foobar'))

    def test_interp2app_unwrap_spec_str(self):
        space = self.space
        w = space.wrap
        def g3_ss(space, s0, s1):
            if s1 is None:
                return space.wrap(42)
            return space.wrap(s0+s1)
        app_g3_ss = gateway.interp2app_temp(g3_ss,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      'text', 'text_or_none'])
        w_app_g3_ss = space.wrap(app_g3_ss)
        assert self.space.eq_w(
            space.call(w_app_g3_ss,
                       space.newtuple([w('foo'), w('bar')]),
                       space.newdict()),
            w('foobar'))
        assert self.space.eq_w(
            space.call_function(w_app_g3_ss, w('foo'), w('bar')),
            w('foobar'))
        assert self.space.eq_w(
            space.call_function(w_app_g3_ss, w('foo'), space.w_None),
            w(42))
        space.raises_w(space.w_TypeError, space.call_function,
                       w_app_g3_ss, space.w_None, w('bar'))

    def test_interp2app_unwrap_spec_int_float(self):
        space = self.space
        w = space.wrap
        def g3_if(space, i0, f1):
            return space.wrap(i0+f1)
        app_g3_if = gateway.interp2app_temp(g3_if,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      int,float])
        w_app_g3_if = space.wrap(app_g3_if)
        assert self.space.eq_w(
            space.call(w_app_g3_if,
                       space.newtuple([w(1), w(1.0)]),
                       space.newdict()),
            w(2.0))
        assert self.space.eq_w(
            space.call_function(w_app_g3_if, w(1), w(1.0)),
            w(2.0))

    def test_interp2app_unwrap_spec_r_longlong(self):
        space = self.space
        w = space.wrap
        def g3_ll(space, n):
            return space.wrap(n * 3)
        app_g3_ll = gateway.interp2app_temp(g3_ll,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      gateway.r_longlong])
        w_app_g3_ll = space.wrap(app_g3_ll)
        w_big = w(gateway.r_longlong(10**10))
        assert space.eq_w(
            space.call(w_app_g3_ll,
                       space.newtuple([w_big]),
                       space.newdict()),
            w(gateway.r_longlong(3 * 10**10)))
        assert space.eq_w(
            space.call_function(w_app_g3_ll, w_big),
            w(gateway.r_longlong(3 * 10**10)))
        w_huge = w(10L**100)
        space.raises_w(space.w_OverflowError,
                       space.call_function, w_app_g3_ll, w_huge)

    def test_interp2app_unwrap_spec_r_uint(self):
        space = self.space
        w = space.wrap
        def g3_ll(space, n):
            return space.wrap(n * 3)
        app_g3_ll = gateway.interp2app_temp(g3_ll,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      gateway.r_uint])
        w_app_g3_ll = space.wrap(app_g3_ll)
        w_big = w(gateway.r_uint(sys.maxint+100))
        assert space.eq_w(
            space.call_function(w_app_g3_ll, w_big),
            w(gateway.r_uint((sys.maxint+100)*3)))
        space.raises_w(space.w_OverflowError,
                       space.call_function, w_app_g3_ll, w(10L**100))
        space.raises_w(space.w_ValueError,
                       space.call_function, w_app_g3_ll, w(-1))

    def test_interp2app_unwrap_spec_r_ulonglong(self):
        space = self.space
        w = space.wrap
        def g3_ll(space, n):
            return space.wrap(n * 3)
        app_g3_ll = gateway.interp2app_temp(g3_ll,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      gateway.r_ulonglong])
        w_app_g3_ll = space.wrap(app_g3_ll)
        w_big = w(gateway.r_ulonglong(-100))
        assert space.eq_w(
            space.call_function(w_app_g3_ll, w_big),
            w(gateway.r_ulonglong(-300)))
        space.raises_w(space.w_OverflowError,
                       space.call_function, w_app_g3_ll, w(10L**100))
        space.raises_w(space.w_ValueError,
                       space.call_function, w_app_g3_ll, w(-1))
        space.raises_w(space.w_ValueError,
                       space.call_function, w_app_g3_ll, w(-10L**99))

    def test_interp2app_unwrap_spec_index(self):
        space = self.space
        w = space.wrap
        def g3_idx(space, idx0):
            return space.wrap(idx0 + 1)
        app_g3_idx = gateway.interp2app_temp(g3_idx,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      'index'])
        w_app_g3_idx = space.wrap(app_g3_idx)
        assert space.eq_w(
            space.call_function(w_app_g3_idx, w(123)),
            w(124))
        space.raises_w(space.w_OverflowError,
                       space.call_function,
                       w_app_g3_idx,
                       space.mul(space.wrap(sys.maxint), space.wrap(7)))
        space.raises_w(space.w_OverflowError,
                       space.call_function,
                       w_app_g3_idx,
                       space.mul(space.wrap(sys.maxint), space.wrap(-7)))

    def test_interp2app_unwrap_spec_fsencode(self):
        import sys
        space = self.space
        w = space.wrap
        def f(filename):
            return space.newbytes(filename)
        app_f = gateway.interp2app_temp(f, unwrap_spec=['fsencode'])
        w_app_f = space.wrap(app_f)
        assert space.eq_w(
            space.call_function(w_app_f, w(u'\udc80')),
            space.newbytes('\x80'))

    def test_interp2app_unwrap_spec_typechecks(self):
        from rpython.rlib.rarithmetic import r_longlong

        space = self.space
        w = space.wrap
        def g3_id(space, x):
            return space.wrap(x)
        app_g3_i = gateway.interp2app_temp(g3_id,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      int])
        w_app_g3_i = space.wrap(app_g3_i)
        assert space.eq_w(space.call_function(w_app_g3_i,w(1)),w(1))
        assert space.eq_w(space.call_function(w_app_g3_i,w(1L)),w(1))
        space.raises_w(space.w_OverflowError, space.call_function,w_app_g3_i,w(sys.maxint*2))
        space.raises_w(space.w_TypeError, space.call_function,w_app_g3_i,w(None))
        space.raises_w(space.w_TypeError, space.call_function,w_app_g3_i,w("foo"))
        space.raises_w(space.w_TypeError, space.call_function,w_app_g3_i,w(1.0))

        app_g3_s = gateway.interp2app_temp(g3_id,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      'text'])
        w_app_g3_s = space.wrap(app_g3_s)
        assert space.eq_w(space.call_function(w_app_g3_s,w("foo")),w("foo"))
        space.raises_w(space.w_TypeError, space.call_function,w_app_g3_s,w(None))
        space.raises_w(space.w_TypeError, space.call_function,w_app_g3_s,w(1))
        space.raises_w(space.w_TypeError, space.call_function,w_app_g3_s,w(1.0))

        app_g3_f = gateway.interp2app_temp(g3_id,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      float])
        w_app_g3_f = space.wrap(app_g3_f)
        assert space.eq_w(space.call_function(w_app_g3_f,w(1.0)),w(1.0))
        assert space.eq_w(space.call_function(w_app_g3_f,w(1)),w(1.0))
        assert space.eq_w(space.call_function(w_app_g3_f,w(1L)),w(1.0))
        space.raises_w(space.w_TypeError, space.call_function,w_app_g3_f,w(None))
        space.raises_w(space.w_TypeError, space.call_function,w_app_g3_f,w("foo"))

        app_g3_r = gateway.interp2app_temp(g3_id,
                                           unwrap_spec=[gateway.ObjSpace,
                                                        r_longlong])
        w_app_g3_r = space.wrap(app_g3_r)
        space.raises_w(space.w_TypeError, space.call_function,w_app_g3_r,w(1.0))

    def test_interp2app_unwrap_spec_utf8(self):
        space = self.space
        w = space.wrap
        def g3_u(space, utf8):
            return space.wrap(utf8)
        app_g3_u = gateway.interp2app_temp(g3_u,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      'utf8'])
        w_app_g3_u = space.wrap(app_g3_u)
        encoded = u"gęść".encode('utf8')
        assert self.space.eq_w(
            space.call_function(w_app_g3_u, w(u"gęść")),
            w(encoded))
        assert self.space.eq_w(
            space.call_function(w_app_g3_u, w("foo")),
            w("foo"))
        space.raises_w(space.w_TypeError, space.call_function, w_app_g3_u,
               w(None))
        space.raises_w(space.w_TypeError, space.call_function, w_app_g3_u,
               w(42))
        w_ascii = space.appexec([], """():
            import sys
            return sys.getdefaultencoding() == 'ascii'""")
        if space.is_true(w_ascii):
            raises(gateway.OperationError, space.call_function, w_app_g3_u,
                   w("\x80"))

    def test_interp2app_unwrap_spec_unwrapper(self):
        space = self.space
        class Unwrapper(gateway.Unwrapper):
            def unwrap(self, space, w_value):
                return space.int_w(w_value)

        w = space.wrap
        def g3_u(space, value):
            return space.wrap(value + 1)
        app_g3_u = gateway.interp2app_temp(g3_u,
                                         unwrap_spec=[gateway.ObjSpace,
                                                      Unwrapper])
        assert self.space.eq_w(
            space.call_function(w(app_g3_u), w(42)), w(43))
        space.raises_w(space.w_TypeError, space.call_function,
               w(app_g3_u), w(None))

    def test_interp2app_classmethod(self):
        space = self.space
        w = space.wrap
        def g_run(space, w_type):
            assert space.is_w(w_type, space.w_text)
            return w(42)

        app_g_run = gateway.interp2app_temp(g_run,
                                            unwrap_spec=[gateway.ObjSpace,
                                                         gateway.W_Root],
                                            as_classmethod=True)
        w_app_g_run = space.wrap(app_g_run)
        w_bound = space.get(w_app_g_run, w("hello"), space.w_text)
        assert space.eq_w(space.call_function(w_bound), w(42))

    def test_interp2app_fastcall(self):
        space = self.space
        w = space.wrap
        w_3 = w(3)

        def f(space):
            return w_3
        app_f = gateway.interp2app_temp(f, unwrap_spec=[gateway.ObjSpace])
        w_app_f = w(app_f)

        # sanity
        assert isinstance(w_app_f.code, gateway.BuiltinCode0)

        called = []
        fastcall_0 = w_app_f.code.fastcall_0
        def witness_fastcall_0(space, w_func):
            called.append(w_func)
            return fastcall_0(space, w_func)

        w_app_f.code.fastcall_0 = witness_fastcall_0

        w_3 = space.newint(3)
        w_res = space.call_function(w_app_f)

        assert w_res is w_3
        assert called == [w_app_f]

        called = []

        w_res = space.appexec([w_app_f], """(f):
        return f()
        """)

        assert w_res is w_3
        assert called == [w_app_f]

    def test_interp2app_fastcall_method(self):
        space = self.space
        w = space.wrap
        w_3 = w(3)

        def f(space, w_self, w_x):
            return w_x
        app_f = gateway.interp2app_temp(f, unwrap_spec=[gateway.ObjSpace,
                                                        gateway.W_Root,
                                                        gateway.W_Root])
        w_app_f = w(app_f)

        # sanity
        assert isinstance(w_app_f.code, gateway.BuiltinCode2)

        called = []
        fastcall_2 = w_app_f.code.fastcall_2
        def witness_fastcall_2(space, w_func, w_a, w_b):
            called.append(w_func)
            return fastcall_2(space, w_func, w_a, w_b)

        w_app_f.code.fastcall_2 = witness_fastcall_2

        w_res = space.appexec([w_app_f, w_3], """(f, x):
        class A(object):
           m = f # not a builtin function, so works as method
        y = A().m(x)
        b = A().m
        z = b(x)
        return y is x and z is x
        """)

        assert space.is_true(w_res)
        assert called == [w_app_f, w_app_f]

    def test_interp2app_fastcall_method_with_space(self):
        class W_X(W_Root):
            def descr_f(self, space, w_x):
                return w_x

        app_f = gateway.interp2app_temp(W_X.descr_f, unwrap_spec=['self',
                                        gateway.ObjSpace, gateway.W_Root])

        w_app_f = self.space.wrap(app_f)

        assert isinstance(w_app_f.code, gateway.BuiltinCode2)

        called = []
        fastcall_2 = w_app_f.code.fastcall_2
        def witness_fastcall_2(space, w_func, w_a, w_b):
            called.append(w_func)
            return fastcall_2(space, w_func, w_a, w_b)

        w_app_f.code.fastcall_2 = witness_fastcall_2
        space = self.space

        w_res = space.call_function(w_app_f, W_X(), space.wrap(3))

        assert space.is_true(w_res)
        assert called == [w_app_f]

    def test_plain(self):
        space = self.space

        def g(space, w_a, w_x):
            return space.newtuple([space.wrap('g'), w_a, w_x])

        w_g = space.wrap(gateway.interp2app_temp(g,
                         unwrap_spec=[gateway.ObjSpace,
                                      gateway.W_Root,
                                      gateway.W_Root]))

        args = argument.Arguments(space, [space.wrap(-1), space.wrap(0)])

        w_res = space.call_args(w_g, args)
        assert space.is_true(space.eq(w_res, space.wrap(('g', -1, 0))))

        w_self = space.wrap('self')

        args0 = argument.Arguments(space, [space.wrap(0)])
        args = args0.prepend(w_self)

        w_res = space.call_args(w_g, args)
        assert space.is_true(space.eq(w_res, space.wrap(('g', 'self', 0))))

        args3 = argument.Arguments(space, [space.wrap(3)])
        w_res = space.call_obj_args(w_g, w_self, args3)
        assert space.is_true(space.eq(w_res, space.wrap(('g', 'self', 3))))

    def test_unwrap_spec_decorator(self):
        space = self.space
        @gateway.unwrap_spec(gateway.ObjSpace, gateway.W_Root, int)
        def g(space, w_thing, i):
            return space.newtuple([w_thing, space.wrap(i)])
        w_g = space.wrap(gateway.interp2app_temp(g))
        args = argument.Arguments(space, [space.wrap(-1), space.wrap(0)])
        w_res = space.call_args(w_g, args)
        assert space.eq_w(w_res, space.wrap((-1, 0)))

    def test_unwrap_spec_decorator_kwargs(self):
        space = self.space
        @gateway.unwrap_spec(i=int)
        def f(space, w_thing, i):
            return space.newtuple([w_thing, space.wrap(i)])
        unwrap_spec = gateway.BuiltinCode(f)._unwrap_spec
        assert unwrap_spec == [ObjSpace, W_Root, int]

    def test_unwrap_spec_default_applevel(self):
        space = self.space
        @gateway.unwrap_spec(w_x = WrappedDefault(42))
        def g(space, w_x):
            return w_x
        w_g = space.wrap(gateway.interp2app_temp(g))
        args = argument.Arguments(space, [])
        w_res = space.call_args(w_g, args)
        assert space.eq_w(w_res, space.wrap(42))
        #
        args = argument.Arguments(space, [space.wrap(84)])
        w_res = space.call_args(w_g, args)
        assert space.eq_w(w_res, space.wrap(84))

    def test_unwrap_spec_default_applevel_2(self):
        space = self.space
        @gateway.unwrap_spec(w_x = (WrappedDefault(42)), y=int)
        def g(space, w_x, y=10):
            return space.add(w_x, space.wrap(y))
        w_g = space.wrap(gateway.interp2app_temp(g))
        args = argument.Arguments(space, [])
        w_res = space.call_args(w_g, args)
        assert space.eq_w(w_res, space.wrap(52))
        #
        args = argument.Arguments(space, [space.wrap(84)])
        w_res = space.call_args(w_g, args)
        assert space.eq_w(w_res, space.wrap(94))
        #
        args = argument.Arguments(space, [space.wrap(84), space.wrap(-1)])
        w_res = space.call_args(w_g, args)
        assert space.eq_w(w_res, space.wrap(83))

    def test_unwrap_spec_default_applevel_bogus(self):
        space = self.space
        @gateway.unwrap_spec(w_x = WrappedDefault(42), y=int)
        def g(space, w_x, y):
            never_called
        py.test.raises(KeyError, space.wrap, gateway.interp2app_temp(g))

    def test_unwrap_spec_default_applevel_bug2(self):
        space = self.space
        def g(space, w_x, w_y=None, __args__=None):
            return w_x
        w_g = space.wrap(gateway.interp2app_temp(g))
        w_42 = space.call_function(w_g, space.wrap(42))
        assert space.int_w(w_42) == 42
        py.test.raises(gateway.OperationError, space.call_function, w_g)
        #
        def g(space, w_x, w_y=None, args_w=None):
            return w_x
        w_g = space.wrap(gateway.interp2app_temp(g))
        w_42 = space.call_function(w_g, space.wrap(42))
        assert space.int_w(w_42) == 42
        py.test.raises(gateway.OperationError, space.call_function, w_g)

    def test_interp2app_doc(self):
        space = self.space
        def f(space, w_x):
            """foo"""
        w_f = space.wrap(gateway.interp2app_temp(f))
        assert space.unwrap(space.getattr(w_f, space.wrap('__doc__'))) == 'foo'
        #
        def g(space, w_x):
            never_called
        w_g = space.wrap(gateway.interp2app_temp(g, doc='bar'))
        assert space.unwrap(space.getattr(w_g, space.wrap('__doc__'))) == 'bar'

    def test_system_error(self):
        py.test.skip("we don't wrap a random exception inside SystemError "
                     "when untranslated, because it makes testing harder")
        class UnexpectedException(Exception):
            pass
        space = self.space
        def g(space):
            raise UnexpectedException
        w_g = space.wrap(gateway.interp2app_temp(g))
        e = py.test.raises(OperationError, space.appexec, [w_g], """(my_g):
            my_g()
        """)
        err = str(e.value)
        assert 'SystemError' in err
        assert ('unexpected internal exception (please '
                'report a bug): UnexpectedException') in err

    def test_system_error_2(self):
        py.test.skip("we don't wrap a random exception inside SystemError "
                     "when untranslated, because it makes testing harder")
        class UnexpectedException(Exception):
            pass
        space = self.space
        def g(space):
            raise UnexpectedException
        w_g = space.wrap(gateway.interp2app_temp(g))
        w_msg = space.appexec([w_g], """(my_g):
            try:
                my_g()
            except SystemError as e:
                return str(e)
        """)
        err = space.text_w(w_msg)
        assert ('unexpected internal exception (please '
                'report a bug): UnexpectedException') in err

    def test_bare_raise_in_app_helper(self):
        space = self.space
        w = space.wrap
        def app_g3(a):
            try:
                1 / a
            except ZeroDivisionError:
                raise
        g3 = gateway.app2interp(app_g3)
        space.raises_w(space.w_ZeroDivisionError, g3, space, w(0))

    def test_unwrap_spec_default_bytes(self):
        space = self.space
        @gateway.unwrap_spec(s='bufferstr')
        def g(space, s=''):
            return space.wrap(type(s) is str)
        w_g = space.wrap(gateway.interp2app_temp(g))
        args = argument.Arguments(space, [])
        w_res = space.call_args(w_g, args)
        assert space.eq_w(w_res, space.w_True)

    def test_unwrap_spec_default_applevel_bytes(self):
        space = self.space
        @gateway.unwrap_spec(w_x=WrappedDefault('foo'))
        def g(space, w_x):
            return w_x
        w_g = space.wrap(gateway.interp2app_temp(g))
        args = argument.Arguments(space, [])
        w_res = space.call_args(w_g, args)
        assert space.eq_w(w_res, space.newbytes('foo'))

    def test_unwrap_spec_kwonly(self):
        space = self.space
        def g(space, w_x, __kwonly__, w_y):
            return space.sub(w_x, w_y)
        w_g = space.wrap(gateway.interp2app_temp(g))
        w = space.wrap
        w1 = w(1)

        for i in range(4):
            a = argument.Arguments(space, [w1, w1, w1])
            py.test.raises(gateway.OperationError, space.call_args, w_g, a)
            py.test.raises(gateway.OperationError, space.call_function, w_g,
                           *(i * (w1,)))

        args = argument.Arguments(space, [w(1)],
                                  w_starstararg = w({'y': 10}))
        assert space.eq_w(space.call_args(w_g, args), w(-9))
        args = argument.Arguments(space, [],
                                  w_starstararg = w({'x': 2, 'y': 10}))
        assert space.eq_w(space.call_args(w_g, args), w(-8))

    def test_unwrap_spec_kwonly_default(self):
        space = self.space
        @gateway.unwrap_spec(w_x2=WrappedDefault(50), y2=int)
        def g(space, w_x1, w_x2, __kwonly__, w_y1, y2=200):
            return space.sub(space.sub(w_x1, w_x2),
                             space.sub(w_y1, w(y2)))
        w_g = space.wrap(gateway.interp2app_temp(g))
        w = space.wrap
        w1 = w(1)

        for i in range(6):
            py.test.raises(gateway.OperationError, space.call_function, w_g,
                           *(i * (w1,)))

        def expected(x1, x2=50, y1="missing", y2=200):
            return (x1 - x2) - (y1 - y2)

        def check(*args, **kwds):
            a = argument.Arguments(space, [], w_stararg = w(args),
                                          w_starstararg = w(kwds))
            w_res = space.call_args(w_g, a)
            assert space.eq_w(w_res, w(expected(*args, **kwds)))

            del kwds['y1']
            a = argument.Arguments(space, [], w_stararg = w(args),
                                          w_starstararg = w(kwds))
            py.test.raises(gateway.OperationError, space.call_args, w_g, a)

            args += (1234,)
            a = argument.Arguments(space, [], w_stararg = w(args),
                                          w_starstararg = w(kwds))
            py.test.raises(gateway.OperationError, space.call_args, w_g, a)

        check(5,       y1=1234)
        check(5, 1,    y1=1234)
        check(5, x2=1, y1=1234)
        check(5,       y1=1234, y2=343)
        check(5, 1,    y1=1234, y2=343)
        check(5, x2=1, y1=1234, y2=343)
        check(x1=5,       y1=1234,       )
        check(x1=5, x2=1, y1=1234,       )
        check(x1=5,       y1=1234, y2=343)
        check(x1=5, x2=1, y1=1234, y2=343)

    def test_unwrap_spec_kwonly_default_2(self):
        space = self.space
        @gateway.unwrap_spec(w_x2=WrappedDefault(50))
        def g(space, w_x2=None):
            return w_x2
        w_g = space.wrap(gateway.interp2app_temp(g))
        w_res = space.call_function(w_g)
        assert space.eq_w(w_res, space.wrap(50))

    def test_unwrap_spec_kwonly_with_starargs_bug(self):
        space = self.space
        @gateway.unwrap_spec(w_name=WrappedDefault(None), w_obj=WrappedDefault(None))
        def init(w_a, space, args_w, __kwonly__, w_obj=None, w_name=None):
            return space.newtuple([w_a, space.newtuple(args_w), w_obj, w_name])
        w_g = space.wrap(gateway.interp2app_temp(init))
        w_res = space.call_function(w_g, space.newint(1), space.newint(2))
        assert space.eq_w(w_res, space.newtuple([space.newint(1), space.newtuple([space.newint(2)]), space.w_None, space.w_None]))

    def test_posonly_args(self):
        space = self.space
        @gateway.unwrap_spec(w_x2=WrappedDefault(50))
        def g(space, w_t, w_x2, __posonly__):
            assert space.eq_w(w_t, space.newint(1))
            return w_x2
        w_g = space.wrap(gateway.interp2app_temp(g))
        w_res = space.call_function(w_g, space.wrap(1))
        assert space.eq_w(w_res, space.wrap(50))

class AppTestPyTestMark:
    @py.test.mark.unlikely_to_exist
    def test_anything(self):
        pass


class TestPassThroughArguments:
    def test_pass_trough_arguments0(self):
        space = self.space

        called = []

        def f(space, __args__):
            called.append(__args__)
            a_w, _ = __args__.unpack()
            return space.newtuple([space.wrap('f')]+a_w)

        w_f = space.wrap(gateway.interp2app_temp(f,
                         unwrap_spec=[gateway.ObjSpace,
                                      gateway.Arguments]))

        args = argument.Arguments(space, [space.wrap(7)])

        w_res = space.call_args(w_f, args)
        assert space.is_true(space.eq(w_res, space.wrap(('f', 7))))

        # white-box check for opt
        assert called[0] is args

    def test_pass_trough_arguments1(self):
        space = self.space

        called = []

        def g(space, w_self, __args__):
            called.append(__args__)
            a_w, _ = __args__.unpack()
            return space.newtuple([space.wrap('g'), w_self, ]+a_w)

        w_g = space.wrap(gateway.interp2app_temp(g,
                         unwrap_spec=[gateway.ObjSpace,
                                      gateway.W_Root,
                                      gateway.Arguments]))

        old_funcrun = w_g.code.funcrun
        def funcrun_witness(func, args):
            called.append('funcrun')
            return old_funcrun(func, args)

        w_g.code.funcrun = funcrun_witness

        w_self = space.wrap('self')

        args3 = argument.Arguments(space, [space.wrap(3)])
        w_res = space.call_obj_args(w_g, w_self, args3)
        assert space.is_true(space.eq(w_res, space.wrap(('g', 'self', 3))))
        # white-box check for opt
        assert len(called) == 1
        assert called[0] is args3

        called = []
        args0 = argument.Arguments(space, [space.wrap(0)])
        args = args0.prepend(w_self)

        w_res = space.call_args(w_g, args)
        assert space.is_true(space.eq(w_res, space.wrap(('g', 'self', 0))))
        # no opt in this case
        assert len(called) == 2
        assert called[0] == 'funcrun'
        called = []

        # higher level interfaces

        w_res = space.call_function(w_g, w_self)
        assert space.is_true(space.eq(w_res, space.wrap(('g', 'self'))))
        assert len(called) == 1
        assert isinstance(called[0], argument.Arguments)
        called = []

        w_res = space.appexec([w_g], """(g):
        return g('self', 11)
        """)
        assert space.is_true(space.eq(w_res, space.wrap(('g', 'self', 11))))
        assert len(called) == 1
        assert isinstance(called[0], argument.Arguments)
        called = []

        w_res = space.appexec([w_g], """(g):
        class A(object):
           m = g # not a builtin function, so works as method
        d = {'A': A}
        exec(\"\"\"
# own compiler
a = A()
y = a.m(33)
\"\"\", d)
        return d['y'] == ('g', d['a'], 33)
        """)
        assert space.is_true(w_res)
        assert len(called) == 1
        assert isinstance(called[0], argument.Arguments)

    def test_pass_trough_arguments_method(self):
        space = self.space

        called = []

        class W_Something(W_Root):
            def f(self, space, __args__):
                called.append(__args__)
                a_w, _ = __args__.unpack()
                return space.newtuple([space.wrap('f')]+a_w)

        w_f = space.wrap(gateway.interp2app_temp(W_Something.f))

        w_self = space.wrap(W_Something())
        args = argument.Arguments(space, [space.wrap(7)])

        w_res = space.call_obj_args(w_f, w_self, args)
        assert space.is_true(space.eq(w_res, space.wrap(('f', 7))))

        # white-box check for opt
        assert called[0] is args

    def test_base_regular_descr_mismatch(self):
        space = self.space

        def f():
            raise gateway.DescrMismatch

        w_f = space.wrap(gateway.interp2app_temp(f,
                         unwrap_spec=[]))
        args = argument.Arguments(space, [])
        space.raises_w(space.w_SystemError, space.call_args, w_f, args)

    def test_pass_trough_arguments0_descr_mismatch(self):
        space = self.space

        def f(space, __args__):
            raise gateway.DescrMismatch

        w_f = space.wrap(gateway.interp2app_temp(f,
                         unwrap_spec=[gateway.ObjSpace,
                                      gateway.Arguments]))
        args = argument.Arguments(space, [])
        space.raises_w(space.w_SystemError, space.call_args, w_f, args)


class AppTestKeywordsToBuiltinSanity(object):
    def test_type(self):
        class X(object):
            def __init__(myself, **kw):
                pass
        clash = type.__call__.__code__.co_varnames[0]

        X(**{clash: 33})
        type.__call__(X, **{clash: 33})

    def test_object_new(self):
        class X(object):
            def __init__(self, **kw):
                pass
        clash = object.__new__.__code__.co_varnames[0]

        X(**{clash: 33})
        object.__new__(X, **{clash: 33})

    def test_dict_new(self):
        clash = dict.__new__.__code__.co_varnames[0]

        dict(**{clash: 33})
        dict.__new__(dict, **{clash: 33})

    def test_dict_init(self):
        d = {}
        clash = dict.__init__.__code__.co_varnames[0]

        d.__init__(**{clash: 33})
        dict.__init__(d, **{clash: 33})

    def test_dict_update(self):
        d = {}
        clash = dict.update.__code__.co_varnames[0]

        d.update(**{clash: 33})
        dict.update(d, **{clash: 33})


class AppTestFastPathCrash(object):
    def test_fast_path_crash(self):
        # issue bb-3091 crash in BuiltinCodePassThroughArguments0.funcrun
        import sys
        if '__pypy__' in sys.modules:
            msg_fmt = "'%s' object expected, got '%s'"
        else:
            msg_fmt = "'%s' object but received a '%s'"
        for obj in (dict, set):
            with raises(TypeError) as excinfo:
                obj.__init__(0)
            msg = msg_fmt % (obj.__name__, 'int')
            assert msg in str(excinfo.value)
