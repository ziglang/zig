import pytest

import _functools


def test_partial_reduce():
    partial = _functools.partial(test_partial_reduce)
    state = partial.__reduce__()
    d = state[2][2]
    assert state == (type(partial), (test_partial_reduce,),
                     (test_partial_reduce, (), d, None))
    assert d is None or d == {}      # both are acceptable

def test_partial_setstate():
    partial = _functools.partial(object)
    partial.__setstate__((test_partial_setstate, (), None, None))
    assert partial.func == test_partial_setstate

def test_partial_pickle():
    pytest.skip("can't run this test: _functools.partial now has "
                "__module__=='functools', in this case confusing pickle")
    import pickle
    partial1 = _functools.partial(test_partial_pickle)
    string = pickle.dumps(partial1)
    partial2 = pickle.loads(string)
    assert partial1.func == partial2.func

def test_immutable_attributes():
    partial = _functools.partial(object)
    with pytest.raises((TypeError, AttributeError)):
        partial.func = sum
    with pytest.raises(TypeError) as exc:
        del partial.__dict__
    assert str(exc.value) == "a partial object's dictionary may not be deleted"
    with pytest.raises(AttributeError):
        del partial.zzz

def test_self_keyword():
    partial = _functools.partial(dict, self=42)
    assert partial(other=43) == {'self': 42, 'other': 43}

def test_no_keywords():
    kw1 = _functools.partial(dict).keywords
    kw2 = _functools.partial(dict, **{}).keywords
    # CPython gives different results for these two cases, which is not
    # possible to emulate in pure Python; see issue #2043
    assert kw1 == {} or kw1 is None
    assert kw2 == {}
