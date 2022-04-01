from hypothesis import strategies as st
from hypothesis import given, example

st_bytestring = st.binary() | st.binary().map(bytearray)

@given(st_bytestring, st_bytestring, st_bytestring)
def test_find(u, prefix, suffix):
    s = prefix + u + suffix
    assert 0 <= s.find(u) <= len(prefix)
    assert s.find(u, len(prefix), len(s) - len(suffix)) == len(prefix)

@given(st_bytestring, st_bytestring, st_bytestring)
def test_index(u, prefix, suffix):
    s = prefix + u + suffix
    assert 0 <= s.index(u) <= len(prefix)
    assert s.index(u, len(prefix), len(s) - len(suffix)) == len(prefix)

@given(st_bytestring, st_bytestring, st_bytestring)
def test_rfind(u, prefix, suffix):
    s = prefix + u + suffix
    assert s.rfind(u) >= len(prefix)
    assert s.rfind(u, len(prefix), len(s) - len(suffix)) == len(prefix)

@given(st_bytestring, st_bytestring, st_bytestring)
def test_rindex(u, prefix, suffix):
    s = prefix + u + suffix
    assert s.rindex(u) >= len(prefix)
    assert s.rindex(u, len(prefix), len(s) - len(suffix)) == len(prefix)

def adjust_indices(u, start, end):
    if end < 0:
        end = max(end + len(u), 0)
    else:
        end = min(end, len(u))
    if start < 0:
        start = max(start + len(u), 0)
    return start, end

@given(st_bytestring, st_bytestring)
def test_startswith_basic(u, v):
    assert u.startswith(v) is (u[:len(v)] == v)

@example(b'x', b'', 1)
@example(b'x', b'', 2)
@given(st_bytestring, st_bytestring, st.integers())
def test_startswith_start(u, v, start):
    expected = u[start:].startswith(v) if v else (start <= len(u))
    assert u.startswith(v, start) is expected

@example(b'x', b'', 1, 0)
@example(b'xx', b'', -1, 0)
@given(st_bytestring, st_bytestring, st.integers(), st.integers())
def test_startswith_3(u, v, start, end):
    if v:
        expected = u[start:end].startswith(v)
    else:  # CPython leaks implementation details in this case
        start0, end0 = adjust_indices(u, start, end)
        expected = start0 <= len(u) and start0 <= end0
    assert u.startswith(v, start, end) is expected

@given(st_bytestring, st_bytestring)
def test_endswith_basic(u, v):
    if len(v) > len(u):
        assert u.endswith(v) is False
    else:
        assert u.endswith(v) is (u[len(u) - len(v):] == v)

@example(b'x', b'', 1)
@example(b'x', b'', 2)
@given(st_bytestring, st_bytestring, st.integers())
def test_endswith_2(u, v, start):
    expected = u[start:].endswith(v) if v else (start <= len(u))
    assert u.endswith(v, start) is expected

@example(b'x', b'', 1, 0)
@example(b'xx', b'', -1, 0)
@given(st_bytestring, st_bytestring, st.integers(), st.integers())
def test_endswith_3(u, v, start, end):
    if v:
        expected = u[start:end].endswith(v)
    else:  # CPython leaks implementation details in this case
        start0, end0 = adjust_indices(u, start, end)
        expected = start0 <= len(u) and start0 <= end0
    assert u.endswith(v, start, end) is expected
