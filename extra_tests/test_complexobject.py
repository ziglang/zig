import pytest

@pytest.mark.skipif("sys.maxunicode == 0xffff")
def test_constructor_unicode():
    b1 = '\N{MATHEMATICAL BOLD DIGIT ONE}' # 𝟏
    b2 = '\N{MATHEMATICAL BOLD DIGIT TWO}' # 𝟐
    s = '{0}+{1}j'.format(b1, b2)
    assert complex(s) == 1+2j
    assert complex('\N{EM SPACE}(\N{EN SPACE}1+1j ) ') == 1+1j
