import gc
from rpython.rlib.rweaklist import RWeakListMixin, INITIAL_SIZE


class A(object):
    pass


def test_simple():
    a1 = A(); a2 = A()
    wlist = RWeakListMixin(); wlist.initialize()
    i = wlist.add_handle(a1)
    assert i == INITIAL_SIZE - 1
    i = wlist.reserve_next_handle_index()
    assert i == INITIAL_SIZE - 2
    wlist.store_handle(i, a2)
    assert wlist.fetch_handle(INITIAL_SIZE - 1) is a1
    assert wlist.fetch_handle(INITIAL_SIZE - 2) is a2
    #
    del a2
    for i in range(5):
        gc.collect()
        if wlist.fetch_handle(INITIAL_SIZE - 2) is None:
            break
    else:
        raise AssertionError("second handle() did not disappear")
    assert wlist.fetch_handle(INITIAL_SIZE - 1) is a1

def test_reuse():
    alist = [A() for i in range(200)]
    wlist = RWeakListMixin(); wlist.initialize()
    mapping = []
    for i in range(200):
        j = wlist.reserve_next_handle_index()
        mapping.append(j)
        wlist.store_handle(j, alist[i])
    #
    del alist[1::2]
    del alist[1::2]
    del alist[1::2]
    del alist[1::2]
    del alist[1::2]
    for i in range(5):
        gc.collect()
    #
    for i, j in enumerate(mapping):
        a = wlist.fetch_handle(j)
        if i % 32 == 0:
            assert a is alist[i // 32]
        else:
            assert a is None
    #
    maximum = -1
    for i in range(200):
        j = wlist.reserve_next_handle_index()
        assert wlist.fetch_handle(j) is None
        maximum = max(maximum, j)
        wlist.store_handle(j, A())
    assert maximum < 256
