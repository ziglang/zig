import pytest
from traceback import _levenshtein_distance, _compute_suggestion_error, \
        TracebackException
from hypothesis import given, strategies as st

# levensthein tests

def test_levensthein():
    assert _levenshtein_distance("cat", "sat") == 1
    assert _levenshtein_distance("cat", "ca") == 1
    assert _levenshtein_distance("Kätzchen", "Satz") == 6

@given(st.text())
def test_x_x(s):
    assert _levenshtein_distance(s, s) == 0

@given(st.text())
def test_x_empty(s):
    assert _levenshtein_distance(s, '') == len(s)

@given(st.text(), st.text())
def test_symmetric(a, b):
    assert _levenshtein_distance(a, b) == _levenshtein_distance(b, a)

@given(st.text(), st.text(), st.characters())
def test_add_char(a, b, char):
    d = _levenshtein_distance(a, b)
    assert d == _levenshtein_distance(char + a, char + b)
    assert d == _levenshtein_distance(a + char, b + char)

@given(st.text(), st.text(), st.text())
def test_triangle(a, b, c):
    assert _levenshtein_distance(a, c) <= _levenshtein_distance(a, b) + _levenshtein_distance(b, c)


# suggestion tests

def test_compute_suggestion_attribute_error():
    class A:
        good = 1
        walk = 2

    assert _compute_suggestion_error(AttributeError(obj=A(), name="god"), None) == "good"
    assert _compute_suggestion_error(AttributeError(obj=A(), name="wlak"), None) == "walk"
    assert _compute_suggestion_error(AttributeError(obj=A(), name="good"), None) == None
    assert _compute_suggestion_error(AttributeError(obj=A(), name="goodabcd"), None) == None

def fmt(e):
    return "\n".join(
            TracebackException.from_exception(e).format_exception_only())

def test_format_attribute_error():
    class A:
        good = 1
        walk = 2
    a = A()
    try:
        a.god
    except AttributeError as e:
        assert fmt(e) == "AttributeError: 'A' object has no attribute 'god'. Did you mean: good?\n"

def test_compute_suggestion_name_error():
    def f():
        abc = 1
        ab # abc beats abs!

    try:
        f()
    except NameError as e:
        assert fmt(e) == "NameError: name 'ab' is not defined. Did you mean: abc?\n"

def test_compute_suggestion_name_error_from_global():
    def f():
        test_triang

    try:
        f()
    except NameError as e:
        assert fmt(e) == "NameError: name 'test_triang' is not defined. Did you mean: test_triangle?\n"

def test_compute_suggestion_name_error_from_builtin():
    try:
        ab
    except NameError as e:
        assert fmt(e) == "NameError: name 'ab' is not defined. Did you mean: abs?\n"
