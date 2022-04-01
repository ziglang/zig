try:
    from hypothesis import given, strategies
    HAS_HYPOTHESIS = True
except ImportError:
    HAS_HYPOTHESIS = False

from pypy.module._cffi_backend.wchar_helper import utf8_size_as_char16


if HAS_HYPOTHESIS:
    @given(strategies.text())
    def test_utf8_size_as_char16(u):
        assert type(u) is unicode
        length = utf8_size_as_char16(''.join(uc.encode('utf8') for uc in u))
        assert length == sum((1 if uc <= u'\uFFFF' else 2) for uc in u)
