import pytest

import itertools
from operator import itemgetter
from heapq import merge

from hypothesis import given
from hypothesis import strategies as st


def check_merge_case(lists):
    keys = [None, itemgetter(0), itemgetter(1), itemgetter(1, 0)]
    reverses = [False, True]
    for key, reverse in itertools.product(keys, reverses):
        inputs = [sorted(L, key=key, reverse=reverse) for L in lists]
        expected = sorted(itertools.chain(*inputs), key=key, reverse=reverse)
        m = merge(*inputs, key=key, reverse=reverse)
        assert list(m) == expected, (key, reverse)
        assert list(m) == []


one_item = st.tuples(st.integers(), st.characters())
one_list = st.lists(one_item)
several_lists = st.lists(one_list)

@given(several_lists)
def test_merge_hypothesis(lists):
    check_merge_case(lists)



@given(random=st.randoms(), n=st.sampled_from(list(range(2, 30)) + [1000]))
def test_merge_tree_sizes(random, n):
    lists = [
        [
            (random.randrange(-5, 5), random.choice("ABC"))
            for j in range(random.randrange(20))
        ]
        for i in range(n)
    ]
    check_merge_case(lists)
