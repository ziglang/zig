import pytest

class AppTest(object):
    spaceconfig = {"objspace.usemodules.select": False}

    def setup_class(cls):
        if cls.runappdirect:
            pytest.skip("does not make sense on pypy-c")

    def test_cpumodel(self):
        import __pypy__
        assert hasattr(__pypy__, 'cpumodel')

    def test_builtinify(self):
        import __pypy__
        class A(object):
            a = lambda *args: args
            b = __pypy__.builtinify(a)
        my = A()
        assert my.a() == (my,)
        assert my.b() == ()
        assert A.a(my) == (my,)
        assert A.b(my) == (my,)
        assert not hasattr(A.a, 'im_func')
        assert not hasattr(A.b, 'im_func')
        assert A.a is A.__dict__['a']
        assert A.b is A.__dict__['b']

    def test_hidden_applevel(self):
        import __pypy__
        import sys

        @__pypy__.hidden_applevel
        def sneak(): (lambda: 1/0)()
        try:
            sneak()
        except ZeroDivisionError as e:
            tb = e.__traceback__
            assert tb.tb_frame == sys._getframe()
            assert tb.tb_next.tb_frame.f_code.co_name == '<lambda>'
        else:
            assert False, 'Expected ZeroDivisionError'

    def test_hidden_applevel_frames(self):
        import __pypy__
        import sys

        @__pypy__.hidden_applevel
        def test_hidden():
            assert sys._getframe().f_code.co_name != 'test_hidden'
            def e(): 1/0
            try: e()
            except ZeroDivisionError as e:
                assert sys.exc_info() == (None, None, None)
                frame = e.__traceback__.tb_frame
                assert frame != sys._getframe()
                assert frame.f_code.co_name == 'e'
            else: assert False
            return 2
        assert test_hidden() == 2

    def test_lookup_special(self):
        from __pypy__ import lookup_special
        class X(object):
            def foo(self): return 42
        x = X()
        x.foo = 23
        x.bar = 80
        assert lookup_special(x, "foo")() == 42
        assert lookup_special(x, "bar") is None

    def test_do_what_I_mean(self):
        from __pypy__ import do_what_I_mean
        x = do_what_I_mean()
        assert x == 42

    def test_list_strategy(self):
        from __pypy__ import strategy

        l = [1, 2, 3]
        assert strategy(l) == "IntegerListStrategy"
        l = [b"a", b"b", b"c"]
        assert strategy(l) == "BytesListStrategy"
        l = [u"a", u"b", u"c"]
        assert strategy(l) == "AsciiListStrategy"
        l = [1.1, 2.2, 3.3]
        assert strategy(l) == "FloatListStrategy"
        l = [1, "b", 3]
        assert strategy(l) == "ObjectListStrategy"
        l = []
        assert strategy(l) == "EmptyListStrategy"
        o = 5
        raises(TypeError, strategy, 5)

    def test_dict_strategy(self):
        from __pypy__ import strategy

        d = {}
        assert strategy(d) == "EmptyDictStrategy"
        d = {1: None, 5: None}
        assert strategy(d) == "IntDictStrategy"

    def test_set_strategy(self):
        from __pypy__ import strategy

        s = set()
        assert strategy(s) == "EmptySetStrategy"
        s = set([2, 3, 4])
        assert strategy(s) == "IntegerSetStrategy"

    def test_normalize_exc(self):
        from __pypy__ import normalize_exc
        e = normalize_exc(TypeError)
        assert isinstance(e, TypeError)
        e = normalize_exc(TypeError, 'foo')
        assert isinstance(e, TypeError)
        assert str(e) == 'foo'
        e = normalize_exc(TypeError('doh'))
        assert isinstance(e, TypeError)
        assert str(e) == 'doh'

        try:
            1 / 0
        except ZeroDivisionError as e:
            tb = e.__traceback__
        e = normalize_exc(TypeError, None, tb)
        assert isinstance(e, TypeError)
        assert e.__traceback__ == tb

    def test_instance_strategy(self):
        import sys
        from __pypy__ import strategy
        if sys.maxsize < 2**32:
            skip('not for 32-bit python')
        class A(object):
            pass
        a = A()
        a.x = 1
        a.y = 2
        assert strategy(a).startswith("<UnboxedPlainAttribute y DICT 0 1 <UnboxedPlainAttribute x DICT 0 0 <DictTerminator w_cls=<W_TypeObject 'A'")


class AppTestJitFeatures(object):
    spaceconfig = {"translation.jit": True}

    def setup_class(cls):
        cls.w_runappdirect = cls.space.wrap(cls.runappdirect)

    def test_jit_backend_features(self):
        try:
            from __pypy__ import jit_backend_features
        except ImportError:
            skip("compiled without jit")
        supported_types = jit_backend_features
        assert isinstance(supported_types, list)
        for x in supported_types:
            assert x in ['floats', 'singlefloats', 'longlong']

    def test_internal_error(self):
        if not self.runappdirect:
            skip("we don't wrap a random exception inside SystemError "
                 "when untranslated, because it makes testing harder")
        from __pypy__ import _internal_crash
        raises(SystemError, _internal_crash, 1)
