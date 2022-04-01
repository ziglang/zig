from rpython.flowspace.argument import Signature, CallSpec


class TestSignature(object):
    def test_helpers(self):
        sig = Signature(["a", "b", "c"], None, None)
        assert sig.num_argnames() == 3
        assert not sig.has_vararg()
        assert not sig.has_kwarg()
        assert sig.scope_length() == 3
        assert sig.getallvarnames() == ["a", "b", "c"]
        sig = Signature(["a", "b", "c"], "c", None)
        assert sig.num_argnames() == 3
        assert sig.has_vararg()
        assert not sig.has_kwarg()
        assert sig.scope_length() == 4
        assert sig.getallvarnames() == ["a", "b", "c", "c"]
        sig = Signature(["a", "b", "c"], None, "c")
        assert sig.num_argnames() == 3
        assert not sig.has_vararg()
        assert sig.has_kwarg()
        assert sig.scope_length() == 4
        assert sig.getallvarnames() == ["a", "b", "c", "c"]
        sig = Signature(["a", "b", "c"], "d", "c")
        assert sig.num_argnames() == 3
        assert sig.has_vararg()
        assert sig.has_kwarg()
        assert sig.scope_length() == 5
        assert sig.getallvarnames() == ["a", "b", "c", "d", "c"]

    def test_eq(self):
        sig1 = Signature(["a", "b", "c"], "d", "c")
        sig2 = Signature(["a", "b", "c"], "d", "c")
        assert sig1 == sig2


    def test_find_argname(self):
        sig = Signature(["a", "b", "c"], None, None)
        assert sig.find_argname("a") == 0
        assert sig.find_argname("b") == 1
        assert sig.find_argname("c") == 2
        assert sig.find_argname("d") == -1

    def test_tuply(self):
        sig = Signature(["a", "b", "c"], "d", "e")
        x, y, z = sig
        assert x == ["a", "b", "c"]
        assert y == "d"
        assert z == "e"


def test_flatten_CallSpec():
    args = CallSpec([1, 2, 3])
    assert args.flatten() == ((3, (), False), [1, 2, 3])

    args = CallSpec([1])
    assert args.flatten() == ((1, (), False), [1])

    args = CallSpec([1, 2, 3, 4, 5])
    assert args.flatten() == ((5, (), False), [1, 2, 3, 4, 5])

    args = CallSpec([1], {'c': 3, 'b': 2})
    assert args.flatten() == ((1, ('b', 'c'), False), [1, 2, 3])

    args = CallSpec([1], {'c': 5})
    assert args.flatten() == ((1, ('c', ), False), [1, 5])

    args = CallSpec([1], {'c': 5, 'd': 7})
    assert args.flatten() == ((1, ('c', 'd'), False), [1, 5, 7])

    args = CallSpec([1, 2, 3, 4, 5], {'e': 5, 'd': 7})
    assert args.flatten() == ((5, ('d', 'e'), False), [1, 2, 3, 4, 5, 7, 5])

