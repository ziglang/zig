import sys
import pytest
from hypothesis import strategies as st
from hypothesis import given, settings, example

from unicodedata import normalize

# For every (n1, n2, n3) triple, applying n1 then n2 must be the same
# as applying n3.
# Reference: http://unicode.org/reports/tr15/#Design_Goals
compositions = [
    ('NFC', 'NFC', 'NFC'),
    ('NFC', 'NFD', 'NFD'),
    ('NFC', 'NFKC', 'NFKC'),
    ('NFC', 'NFKD', 'NFKD'),
    ('NFD', 'NFC', 'NFC'),
    ('NFD', 'NFD', 'NFD'),
    ('NFD', 'NFKC', 'NFKC'),
    ('NFD', 'NFKD', 'NFKD'),
    ('NFKC', 'NFC', 'NFKC'),
    ('NFKC', 'NFD', 'NFKD'),
    ('NFKC', 'NFKC', 'NFKC'),
    ('NFKC', 'NFKD', 'NFKD'),
    ('NFKD', 'NFC', 'NFKC'),
    ('NFKD', 'NFD', 'NFKD'),
    ('NFKD', 'NFKC', 'NFKC'),
    ('NFKD', 'NFKD', 'NFKD'),
]

@pytest.mark.parametrize('norm1, norm2, norm3', compositions)
@settings(max_examples=1000)
@example(s=u'---\uafb8\u11a7---')  # issue 2289
@given(s=st.text())
def test_composition(s, norm1, norm2, norm3):
    assert normalize(norm2, normalize(norm1, s)) == normalize(norm3, s)

@given(st.text(), st.text(), st.text())
def test_find(u, prefix, suffix):
    s = prefix + u + suffix
    assert 0 <= s.find(u) <= len(prefix)
    assert s.find(u, len(prefix), len(s) - len(suffix)) == len(prefix)

@given(st.text(), st.text(), st.text())
def test_index(u, prefix, suffix):
    s = prefix + u + suffix
    assert 0 <= s.index(u) <= len(prefix)
    assert s.index(u, len(prefix), len(s) - len(suffix)) == len(prefix)

@given(st.text(), st.text(), st.text())
def test_rfind(u, prefix, suffix):
    s = prefix + u + suffix
    assert s.rfind(u) >= len(prefix)
    assert s.rfind(u, len(prefix), len(s) - len(suffix)) == len(prefix)

@given(st.text(), st.text(), st.text())
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

@given(st.text(), st.text())
def test_startswith_basic(u, v):
    assert u.startswith(v) is (u[:len(v)] == v)

@example(u'x', u'', 1)
@example(u'x', u'', 2)
@given(st.text(), st.text(), st.integers())
def test_startswith_2(u, v, start):
    if v or sys.version_info[0] == 2:
        expected = u[start:].startswith(v)
    else:  # CPython leaks implementation details in this case
        expected = start <= len(u)
    assert u.startswith(v, start) is expected

@example(u'x', u'', 1, 0)
@example(u'xx', u'', -1, 0)
@given(st.text(), st.text(), st.integers(), st.integers())
def test_startswith_3(u, v, start, end):
    if v or sys.version_info[0] == 2:
        expected = u[start:end].startswith(v)
    else:  # CPython leaks implementation details in this case
        start0, end0 = adjust_indices(u, start, end)
        expected = start0 <= len(u) and start0 <= end0
    assert u.startswith(v, start, end) is expected

@given(st.text(), st.text())
def test_endswith_basic(u, v):
    if len(v) > len(u):
        assert u.endswith(v) is False
    else:
        assert u.endswith(v) is (u[len(u) - len(v):] == v)

@example(u'x', u'', 1)
@example(u'x', u'', 2)
@given(st.text(), st.text(), st.integers())
def test_endswith_2(u, v, start):
    if v or sys.version_info[0] == 2:
        expected = u[start:].endswith(v)
    else:  # CPython leaks implementation details in this case
        expected = start <= len(u)
    assert u.endswith(v, start) is expected

@example(u'x', u'', 1, 0)
@example(u'xx', u'', -1, 0)
@given(st.text(), st.text(), st.integers(), st.integers())
def test_endswith_3(u, v, start, end):
    if v or sys.version_info[0] == 2:
        expected = u[start:end].endswith(v)
    else:  # CPython leaks implementation details in this case
        start0, end0 = adjust_indices(u, start, end)
        expected = start0 <= len(u) and start0 <= end0
    assert u.endswith(v, start, end) is expected
