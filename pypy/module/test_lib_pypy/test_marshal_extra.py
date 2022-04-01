import pytest
import sys
import marshal as cpy_marshal
from lib_pypy import _marshal as marshal

hello = "he"
hello += "llo"
def func(x):
    return lambda y: x+y
scopefunc = func(42)

SUBCLASSABLE = [
    42,
    sys.maxsize,
    -1.25,
    2+5j,
    42,
    -1234567890123456789012345678901234567890,
    hello,   # not interned
    "hello",
    (),
    (1, 2),
    [],
    [3, 4],
    {},
    {5: 6, 7: 8},
    u'hello',
    set(),
    set([1, 2]),
    frozenset(),
    frozenset([3, 4]),
]

TESTCASES = SUBCLASSABLE + [
    None,
    False,
    True,
    StopIteration,
    Ellipsis,
    func.__code__,
    scopefunc.__code__,
]


@pytest.mark.parametrize('case', TESTCASES)
def test_dumps_and_reload(case):
    s = marshal.dumps(case)
    obj = marshal.loads(s)
    assert obj == case

@pytest.mark.parametrize('case', TESTCASES)
def test_loads_from_cpython(case):
    s = cpy_marshal.dumps(case, 1)  # XXX: fails with version 2
    obj = marshal.loads(s)
    assert obj == case

@pytest.mark.parametrize('case', TESTCASES)
def test_dumps_to_cpython(case):
    s = marshal.dumps(case)
    obj = cpy_marshal.loads(s)
    assert obj == case

@pytest.mark.parametrize('case', SUBCLASSABLE)
def test_dumps_subclass(case):
    class Subclass(type(case)):
        pass
    case = Subclass(case)
    s = marshal.dumps(case)
    obj = marshal.loads(s)
    assert obj == case

@pytest.mark.parametrize('case', TESTCASES)
def test_load_from_cpython(tmpdir, case):
    p = str(tmpdir.join('test.dat'))

    with open(p, "w") as f1:
        s = cpy_marshal.dump(case, f1, 1)  # XXX: fails with version 2
    with open(p, "r") as f2:
        obj = marshal.load(f2)
    assert obj == case

@pytest.mark.parametrize('case', TESTCASES)
def test_dump_to_cpython(tmpdir, case):
    p = str(tmpdir.join('test.dat'))
    with open(p, "w") as f1:
        s = marshal.dump(case, f1)
    with open(p, "r") as f2:
        obj = cpy_marshal.load(f2)
    assert obj == case

def test_load_truncated_string():
    s = '(\x02\x00\x00\x00i\x03\x00\x00\x00sB\xf9\x00\x00\nabcd'
    with pytest.raises(EOFError):
        marshal.loads(s)

def test_dump_unicode_length():
    s = b'123\xe9'.decode('latin-1')
    r = marshal.dumps(s)
    assert r == b'u\x05\x00\x00\x00123\xc3\xa9'
