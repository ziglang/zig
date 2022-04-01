import py
from rpython.rlib.listsort import TimSort, powerloop
import random, os

from hypothesis import given, strategies as st, example

def makeset(lst):
    result = {}
    for a in lst:
        result.setdefault(id(a), []).append(True)
    return result

class TestTimSort(TimSort):
    def merge_compute_minrun(self, n):
        return 1 # that means we use the "timsorty" bits of the algorithm more
        # than just mostly binary insertion sort

def sorttest(lst1):
    _sorttest(TimSort, lst1)
    _sorttest(TestTimSort, lst1)

def _sorttest(cls, lst1):
    lst2 = lst1[:]
    cls(lst2).sort()
    assert len(lst1) == len(lst2)
    assert makeset(lst1) == makeset(lst2)
    position = {}
    i = 0
    for a in lst1:
        position.setdefault(id(a), []).append(i)
        i += 1
    for i in range(len(lst2)-1):
        a, b = lst2[i], lst2[i+1]
        assert a <= b, "resulting list is not sorted"
        if a == b:
            assert position[id(a)][0] < position[id(b)][-1], "not stable"


class C(int):
    pass

def test_v():
    for v in range(137):
        up = 1 + int(v * random.random() * 2.7)
        lst1 = [C(random.randrange(0, up)) for i in range(v)]
        sorttest(lst1)

@given(st.lists(st.integers(), min_size=2))
def test_hypothesis(l):
    sorttest(l)

def test_file():
    for fn in py.path.local(__file__).dirpath().listdir():
        if fn.ext == '.py': 
            lines1 = fn.readlines()
            sorttest(lines1)


def power(s1, n1, n2, n):
    # from Tim's Python sketch code here: https://bugs.python.org/issue34561
    assert s1 >= 0
    assert n1 >= 1 and n2 >= 1
    assert s1 + n1 + n2 <= n
    # a = s1 + n1/2
    # b = s1 + n1 + n2/2 = a + (n1 + n2)/2
    a = 2*s1 + n1       # 2*a
    b = a + n1 + n2     # 2*b
    # Array length has d bits.  Max power is d:
    #     b/n - a/n = (b-a)/n = (n1 + n2)/2/n >= 2/2/n = 1/n > 1/2**d
    # So at worst b/n and a/n differ in bit 1/2**d.
    # a and b have <= d+1 bits. Shift left by d-1 and divide by 2n =
    # shift left by d-2 and divide by n.  Result is d - bit length of
    # xor.  After the shift, the numerator has at most d+1 + d-2 = 2*d-1
    # bits. Any value of d >= n.bit_length() can be used.
    d = n.bit_length()  # or larger; smaller can fail
    a = (a << (d-2)) // n
    b = (b << (d-2)) // n
    return d - (a ^ b).bit_length()


@example(s1=0, n1=2, n2=2, moreitems=0)
@given(st.integers(min_value=0), st.integers(min_value=2), st.integers(min_value=2), st.integers(min_value=0))
def test_powerloop_equal_power(s1, n1, n2, moreitems):
    n = s1 + n1 + n2 + moreitems
    assert powerloop(s1, n1, n2, n) == power(s1, n1, n2, n)

