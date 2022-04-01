import sys
import pytest
try:
    from hypothesis import given, strategies as st, example, settings, assume
except ImportError:
    pytest.skip("hypothesis required")

from pypy.module.unicodedata.interp_ucd import ucd
from rpython.rlib.rutf8 import codepoints_in_utf8

def make_normalization(space, NF_code):
    def normalize(s):
        u = s.encode('utf8')
        w_s = space.newutf8(u, codepoints_in_utf8(u))
        w_res = ucd.normalize(space, NF_code, w_s)
        return space.utf8_w(w_res).decode('utf8')
    return normalize

all_forms = ['NFC', 'NFD', 'NFKC', 'NFKD']

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


@pytest.mark.parametrize('NF1, NF2, NF3', compositions)
@example(s=u'---\uafb8\u11a7---')  # issue 2289
@settings(max_examples=1000)
@given(s=st.text())
def test_composition(s, space, NF1, NF2, NF3):
    # 'chr(0xfacf) normalizes to chr(0x2284a), which is too big')
    assume(not (s == u'\ufacf' and sys.maxunicode == 65535))
    norm1, norm2, norm3 = [make_normalization(space, form) for form in [NF1, NF2, NF3]]
    assert norm2(norm1(s)) == norm3(s)

if sys.maxunicode != 65535:
    # conditionally generate the example via an unwrapped decorator    
    test_composition = example(s=u'\ufacf')(test_composition)
