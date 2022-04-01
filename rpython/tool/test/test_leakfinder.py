import py
from rpython.tool import leakfinder

def test_start_stop():
    leakfinder.start_tracking_allocations()
    assert leakfinder.TRACK_ALLOCATIONS
    leakfinder.stop_tracking_allocations(True)
    assert not leakfinder.TRACK_ALLOCATIONS

def test_start_stop_nested():
    leakfinder.start_tracking_allocations()
    p2 = leakfinder.start_tracking_allocations()
    assert leakfinder.TRACK_ALLOCATIONS
    leakfinder.stop_tracking_allocations(True, prev=p2)
    assert leakfinder.TRACK_ALLOCATIONS
    leakfinder.stop_tracking_allocations(True)
    assert not leakfinder.TRACK_ALLOCATIONS

def test_remember_free():
    leakfinder.start_tracking_allocations()
    x = 1234
    leakfinder.remember_malloc(x)
    leakfinder.remember_free(x)
    leakfinder.stop_tracking_allocations(True)

def test_remember_forget():
    leakfinder.start_tracking_allocations()
    x = 1234
    leakfinder.remember_malloc(x)
    py.test.raises(leakfinder.MallocMismatch,
                   leakfinder.stop_tracking_allocations, True)

def test_nested_remember_forget_1():
    leakfinder.start_tracking_allocations()
    x = 1234
    leakfinder.remember_malloc(x)
    p2 = leakfinder.start_tracking_allocations()
    leakfinder.stop_tracking_allocations(True, prev=p2)
    py.test.raises(leakfinder.MallocMismatch,
                   leakfinder.stop_tracking_allocations, True)

def test_nested_remember_forget_2():
    p2 = leakfinder.start_tracking_allocations()
    x = 1234
    leakfinder.remember_malloc(x)
    py.test.raises(leakfinder.MallocMismatch,
                   leakfinder.stop_tracking_allocations, True, prev=p2)
    leakfinder.stop_tracking_allocations(True)

def test_traceback():
    leakfinder.start_tracking_allocations()
    x = 1234
    leakfinder.remember_malloc(x)
    res = leakfinder.stop_tracking_allocations(check=False)
    assert res.keys() == [x]
    print res[x]
    assert isinstance(res[x], str)
    assert 'test_traceback' in res[x]
    assert 'leakfinder.remember_malloc(x)' in res[x]

def test_malloc_mismatch():
    import sys, traceback, cStringIO
    sio = cStringIO.StringIO()
    traceback.print_stack(sys._getframe(), limit=10, file=sio)
    tb = sio.getvalue()
    e = leakfinder.MallocMismatch({1234: tb, 2345: tb})
    print str(e)
    # grouped entries for 1234 and 2345
    assert '1234:\n2345:\n' in str(e) or '2345:\n1234:\n' in str(e)
    assert tb[-80:] in str(e)
