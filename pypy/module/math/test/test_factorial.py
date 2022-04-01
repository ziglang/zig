import pytest
import math
import os
import sys

# can't import app_math anymore due to 3isms, so hack
app_math_file = os.path.join(os.path.dirname(os.path.dirname(__file__)), "app_math.py")
with open(app_math_file) as f:
    s = f.read()
start = s.find("def factorial")
source = s[start:s.find("\ndef", start+1)]
exec(source)


def test_factorial_extra():
    for x in range(1000):
        r1 = factorial(x)
        r2 = math.factorial(x)
        assert r1 == r2
        assert type(r1) == type(r2)

def test_timing():
    import time
    x = 5000
    repeat = 1000
    r1 = factorial(x)
    r2 = math.factorial(x)
    assert r1 == r2
    t1 = time.time()
    for i in range(repeat):
        factorial(x)
    t2 = time.time()
    for i in range(repeat):
        math.factorial(x)
    t3 = time.time()
    assert r1 == r2
    print (t2 - t1) / repeat
    print (t3 - t2) / repeat
