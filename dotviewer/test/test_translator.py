"""
Test the integration with PyPy.
"""

import py, sys
from dotviewer.conftest import option

def setup_module(mod):
    if not option.pygame:
        py.test.skip("--pygame not enabled")
    try:
        import pypy
    except ImportError:
        py.test.skip("cannot import pypy")

# ____________________________________________________________

def is_prime(n):
    divisors = [d for d in range(1, n+1) if n % d == 0]
    return len(divisors) == 2


def test_annotated():
    from rpython.translator.interactive import Translation
    t = Translation(is_prime, [int])
    t.annotate()
    t.viewcg()
