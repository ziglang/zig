# encoding: utf-8
import py

from pypy.objspace.std.celldict import ModuleDictStrategy
from pypy.objspace.std.dictmultiobject import W_DictObject, W_ModuleDictObject
from pypy.objspace.std.test.test_dictmultiobject import (
    BaseTestRDictImplementation, BaseTestDevolvedDictImplementation, FakeSpace,
    FakeUnicode)

space = FakeSpace()

class TestCellDict(object):
    FakeString = FakeUnicode

    def test_basic_property_cells(self):
        strategy = ModuleDictStrategy(space)
        storage = strategy.get_empty_storage()
        d = W_ModuleDictObject(space, strategy, storage)

        v1 = strategy.version
        key = "a"
        w_key = self.FakeString(key)
        d.setitem(w_key, 1)
        v2 = strategy.version
        assert v1 is not v2
        assert d.getitem(w_key) == 1
        assert d.get_strategy().getdictvalue_no_unwrapping(d, key) == 1

        d.setitem(w_key, 2)
        v3 = strategy.version
        assert v2 is not v3
        assert d.getitem(w_key) == 2
        assert d.get_strategy().getdictvalue_no_unwrapping(d, key).w_value == 2

        d.setitem(w_key, 3)
        v4 = strategy.version
        assert v3 is v4
        assert d.getitem(w_key) == 3
        assert d.get_strategy().getdictvalue_no_unwrapping(d, key).w_value == 3

        d.delitem(w_key)
        v5 = strategy.version
        assert v5 is not v4
        assert d.getitem(w_key) is None
        assert d.get_strategy().getdictvalue_no_unwrapping(d, key) is None

    def test_same_key_set_twice(self):
        strategy = ModuleDictStrategy(space)
        storage = strategy.get_empty_storage()
        d = W_ModuleDictObject(space, strategy, storage)

        v1 = strategy.version
        x = object()
        d.setitem(u"a", x)
        v2 = strategy.version
        assert v1 is not v2
        d.setitem(u"a", x)
        v3 = strategy.version
        assert v2 is v3

    def test_module_no_cell_interface(self):
        # uses real space, too hard to fake
        from pypy.interpreter.mixedmodule import MixedModule
        class M(MixedModule):
            interpleveldefs = {}
            appleveldefs = {}
        w_mod = M(self.space, None)
        assert isinstance(w_mod.w_dict, W_ModuleDictObject)

        key = "a"
        value1 = self.space.newint(1)
        w_mod.setdictvalue(self.space, key, value1)

        strategy = w_mod.w_dict.get_strategy()
        storage = strategy.unerase(w_mod.w_dict.dstorage)
        assert self.space.is_w(storage["a"], value1)

        value2 = self.space.newint(5)
        w_mod.setdictvalue_dont_introduce_cell(key, value2)
        assert self.space.is_w(storage["a"], value2)

    def test___import__not_a_cell(self):
        # _frozen_importlib overrides __import__, which used to introduce a
        # cell
        w_dict = self.space.builtin.w_dict
        storage = w_dict.get_strategy().unerase(w_dict.dstorage)
        assert "Cell" not in repr(storage['__import__'])


class AppTestModuleDict(object):

    def setup_class(cls):
        cls.w_runappdirect = cls.space.wrap(cls.runappdirect)

    def w_impl_used(self, obj):
        if self.runappdirect:
            skip("__repr__ doesn't work on appdirect")
        import __pypy__
        assert "ModuleDictStrategy" in __pypy__.internal_repr(obj)

    def test_check_module_uses_module_dict(self):
        m = type(__builtins__)("abc")
        self.impl_used(m.__dict__)

    def test_key_not_there(self):
        d = type(__builtins__)("abc").__dict__
        raises(KeyError, "d['def']")
        assert 42 not in d
        assert u"\udc00" not in d

    def test_fallback_evil_key(self):
        class F(object):
            def __hash__(self):
                return hash("s")
            def __eq__(self, other):
                return other == "s"
        d = type(__builtins__)("abc").__dict__
        d["s"] = 12
        assert d["s"] == 12
        assert d[F()] == d["s"]

        d = type(__builtins__)("abc").__dict__
        x = d.setdefault("s", 12)
        assert x == 12
        x = d.setdefault(F(), 12)
        assert x == 12

        d = type(__builtins__)("abc").__dict__
        x = d.setdefault(F(), 12)
        assert x == 12

        d = type(__builtins__)("abc").__dict__
        d["s"] = 12
        del d[F()]

        assert "s" not in d
        assert F() not in d

    def test_reversed(self):
        import __pypy__
        name = next(__pypy__.reversed_dict(__pypy__.__dict__))
        assert isinstance(name, str)

    def test_reversed_keys(self):
        import __pypy__
        d = type(__builtins__)("abc").__dict__
        d['xyz'] = 123
        d['def'] = 654
        l = [key for key in reversed(d) if not key.startswith("__")]
        print(l)
        assert l == ['def', 'xyz']
        l = [key for key in reversed(d.keys()) if not key.startswith("__")]
        print(l)
        assert l == ['def', 'xyz']
        assert __pypy__.strategy(d) == "ModuleDictStrategy"
        l = [v for v in reversed(d.values()) if v is not None and v != "abc"]
        print(l)
        assert l == [654, 123]
        assert __pypy__.strategy(d) == "ModuleDictStrategy"

        l = [(key, value) for (key, value) in reversed(d.items()) if not key.startswith("__")]
        print(l)
        assert l == [('def', 654), ('xyz', 123)]


class TestModuleDictImplementation(BaseTestRDictImplementation):
    StrategyClass = ModuleDictStrategy
    setdefault_hash_count = 2

class TestDevolvedModuleDictImplementation(BaseTestDevolvedDictImplementation):
    StrategyClass = ModuleDictStrategy
    setdefault_hash_count = 2


class AppTestCellDict(object):

    def setup_class(cls):
        if cls.runappdirect:
            py.test.skip("__repr__ doesn't work on appdirect")

    def setup_method(self, method):
        space = self.space
        strategy = ModuleDictStrategy(space)
        storage = strategy.get_empty_storage()
        self.w_d = W_ModuleDictObject(space, strategy, storage)

    def test_popitem(self):
        import __pypy__

        d = self.d
        assert "ModuleDict" in __pypy__.internal_repr(d)
        raises(KeyError, d.popitem)
        d["a"] = 3
        x = d.popitem()
        assert x == ("a", 3)

    def test_degenerate(self):
        import __pypy__

        d = self.d
        assert "ModuleDict" in __pypy__.internal_repr(d)
        d["a"] = 3
        del d["a"]
        d[object()] = 5
        assert list(d.values()) == [5]

    def test_unicode(self):
        import __pypy__

        d = self.d
        assert "ModuleDict" in __pypy__.internal_repr(d)
        d['λ'] = True
        assert "ModuleDict" in __pypy__.internal_repr(d)
        assert list(d) == ['λ']
        assert next(iter(d)) == 'λ'
        assert "ModuleDict" in __pypy__.internal_repr(d)

        d['foo'] = 'bar'
        assert sorted(d) == ['foo', 'λ']
        assert "ModuleDict" in __pypy__.internal_repr(d)

        o = object()
        d[o] = 'baz'
        assert set(d) == set(['foo', 'λ', o])
        assert "ObjectDictStrategy" in __pypy__.internal_repr(d)

