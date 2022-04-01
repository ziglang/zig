
class AppTest(object):
    spaceconfig = {"objspace.usemodules._pypyjson": True}

    def test_check_strategy(self):
        import __pypy__
        import _pypyjson

        d = _pypyjson.loads('{"a": 1}')
        assert __pypy__.strategy(d) == "JsonDictStrategy"
        d = _pypyjson.loads('{}')
        assert __pypy__.strategy(d) == "EmptyDictStrategy"

    def test_simple(self):
        import __pypy__
        import _pypyjson

        d = _pypyjson.loads('{"a": 1, "b": "x"}')
        assert len(d) == 2
        assert d[u"a"] == 1
        assert d[u"b"] == u"x"
        assert u"c" not in d

        d[u"a"] = 5
        assert d[u"a"] == 5
        assert __pypy__.strategy(d) == "JsonDictStrategy"

        # devolve it
        assert not 1 in d
        assert __pypy__.strategy(d) == "UnicodeDictStrategy"
        assert len(d) == 2
        assert d[u"a"] == 5
        assert d[u"b"] == u"x"
        assert u"c" not in d

    def test_setdefault(self):
        import __pypy__
        import _pypyjson

        d = _pypyjson.loads('{"a": 1, "b": "x"}')
        assert d.setdefault(u"a", "blub") == 1
        d.setdefault(u"x", 23)
        assert __pypy__.strategy(d) == "UnicodeDictStrategy"
        assert len(d) == 3
        assert d == {u"a": 1, u"b": "x", u"x": 23}

    def test_delitem(self):
        import __pypy__
        import _pypyjson

        d = _pypyjson.loads('{"a": 1, "b": "x"}')
        del d[u"a"]
        assert __pypy__.strategy(d) == "UnicodeDictStrategy"
        assert len(d) == 1
        assert d == {u"b": "x"}

    def test_popitem(self):
        import __pypy__
        import _pypyjson

        d = _pypyjson.loads('{"a": 1, "b": "x"}')
        k, v = d.popitem()
        assert __pypy__.strategy(d) == "UnicodeDictStrategy"
        if k == u"a":
            assert v == 1
            assert len(d) == 1
            assert d == {u"b": "x"}
        else:
            assert v == u"x"
            assert len(d) == 1
            assert d == {u"a": 1}

    def test_keys_values_items(self):
        import _pypyjson

        d = _pypyjson.loads('{"a": 1, "b": "x"}')
        assert list(d.keys()) == [u"a", u"b"]
        assert list(d.values()) == [1, u"x"]
        assert list(d.items()) == [(u"a", 1), (u"b", u"x")]

    def test_dict_order_retained_when_switching_strategies(self):
        import _pypyjson
        import __pypy__
        d = _pypyjson.loads('{"a": 1, "b": "x"}')
        assert list(d) == [u"a", u"b"]
        # devolve
        assert not 1 in d
        assert __pypy__.strategy(d) == "UnicodeDictStrategy"
        assert list(d) == [u"a", u"b"]

    def test_bug(self):
        import _pypyjson
        a =  """
        {
          "top": {
            "k": "8",
            "k": "8",
            "boom": 1
          }
        }
        """
        d = _pypyjson.loads(a)
        str(d)
        repr(d)

    def test_objdict_bug(self):
        import _pypyjson
        a = """{"foo": "bar"}"""
        d = _pypyjson.loads(a)
        d['foo'] = 'x'

        class Obj(object):
            pass

        x = Obj()
        x.__dict__ = d

        x.foo = 'baz'  # used to segfault on pypy3

        d = _pypyjson.loads(a)
        x = Obj()
        x.__dict__ = d
        x.foo # used to segfault on pypy3


