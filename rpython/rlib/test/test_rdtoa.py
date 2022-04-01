import py
from rpython.rlib.rdtoa import strtod, dtoa, dtoa_formatd
from rpython.rlib import rfloat

def test_strtod():
    assert strtod("12345") == 12345.0
    assert strtod("1.1") == 1.1
    assert strtod("3.47") == 3.47
    assert strtod(".125") == .125
    py.test.raises(ValueError, strtod, "123A")
    py.test.raises(ValueError, strtod, "")
    py.test.raises(ValueError, strtod, " ")
    py.test.raises(ValueError, strtod, "\0")
    py.test.raises(ValueError, strtod, "3\09")

def test_dtoa():
    assert dtoa(3.47) == "3.47"
    assert dtoa(1.1) == "1.1"
    assert dtoa(-1.1) == "-1.1"
    assert dtoa(1.1, flags=rfloat.DTSF_SIGN) == "+1.1"
    assert dtoa(12.3577) == "12.3577"
    assert dtoa(10.0) == "10"
    assert dtoa(1.0e100) == "1e+100"

    assert dtoa(rfloat.INFINITY) == 'inf'
    assert dtoa(-rfloat.INFINITY) == '-inf'
    assert dtoa(rfloat.NAN) == 'nan'

def test_dtoa_precision():
    assert dtoa(1.1, code='f', precision=2) == "1.10"
    assert dtoa(1e12, code='g', precision=12) == "1e+12"

def test_flag_cut_exp_0():
    assert dtoa(1.1e9, code="g", precision=2, flags=rfloat.DTSF_CUT_EXP_0) == "1.1e+9"
    assert dtoa(1.1e-9, code="g", precision=2, flags=rfloat.DTSF_CUT_EXP_0) == "1.1e-9"

def test_g_trailing_zero_bug():
    assert dtoa_formatd(1505.0, "g", 3, 0) == "1.5e+03"
