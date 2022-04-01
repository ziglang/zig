import pytest
import json
from hypothesis import given, strategies

def is_(x, y):
    return type(x) is type(y) and x == y

def test_no_ensure_ascii():
    assert is_(json.dumps(u"\u1234", ensure_ascii=False), u'"\u1234"')
    assert is_(json.dumps(u"\xc0", ensure_ascii=False), u'"\xc0"')
    with pytest.raises(TypeError):
        json.dumps((u"\u1234", b"x"), ensure_ascii=False)
    with pytest.raises(TypeError):
        json.dumps((b"x", u"\u1234"), ensure_ascii=False)

def test_issue2191():
    assert is_(json.dumps(u"xxx", ensure_ascii=False), u'"xxx"')

jsondata = strategies.recursive(
    strategies.none() |
    strategies.booleans() |
    strategies.floats(allow_nan=False) |
    strategies.text(),
    lambda children: strategies.lists(children) |
        strategies.dictionaries(strategies.text(), children))

@given(jsondata)
def test_roundtrip(d):
    assert json.loads(json.dumps(d)) == d

def test_skipkeys():
    assert json.dumps({Ellipsis: 42}, skipkeys=True) == '{}'
    assert json.dumps({Ellipsis: 42, 3: 4}, skipkeys=True) == '{"3": 4}'
    assert json.dumps({3: 4, Ellipsis: 42}, skipkeys=True) == '{"3": 4}'
    assert json.dumps({Ellipsis: 42, NotImplemented: 43}, skipkeys=True) \
                 == '{}'
    assert json.dumps({3: 4, Ellipsis: 42, NotImplemented: 43}, skipkeys=True)\
                 == '{"3": 4}'
    assert json.dumps({Ellipsis: 42, 3: 4, NotImplemented: 43}, skipkeys=True)\
                 == '{"3": 4}'
    assert json.dumps({Ellipsis: 42, NotImplemented: 43, 3: 4}, skipkeys=True)\
                 == '{"3": 4}'
    assert json.dumps({3: 4, 5: 6, Ellipsis: 42}, skipkeys=True) \
                 == '{"3": 4, "5": 6}'
    assert json.dumps({3: 4, Ellipsis: 42, 5: 6}, skipkeys=True) \
                 == '{"3": 4, "5": 6}'
    assert json.dumps({Ellipsis: 42, 3: 4, 5: 6}, skipkeys=True) \
                 == '{"3": 4, "5": 6}'

def test_boolean_as_dict_key():
    # In CPython 2.x, dumps({True:...}) gives {"True":...}.  It should be
    # "true" instead; it's a bug as far as I can tell.  In 3.x it was fixed.
    # BUT! if we call dumps() with sort_keys=True, then CPython (any version)
    # gives "true" instead of "True".  Surprize!
    # I don't want to understand why, let's just not attempt to reproduce that.
    assert json.dumps({True: 5}) == '{"true": 5}'
    assert json.dumps({False: 5}) == '{"false": 5}'
