import gc
from rpython.translator.c.test.test_genc import compile
from rpython.rtyper.lltypesystem import rffi
from rpython.rtyper.lltypesystem import lltype
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib import rgc

def debug_assert(boolresult, msg):
    if not boolresult:
        llop.debug_print(lltype.Void, "\n\nassert failed: %s\n\n" % msg)
        assert boolresult

def use_str():
    mystr = b'abc'
    #debug_assert(rgc.can_move(mystr), "short string cannot move... why?")
    ptr = rffi.get_raw_address_of_string(mystr)
    ptr2 = rffi.get_raw_address_of_string(mystr)
    debug_assert(ptr == ptr2, "ptr != ptr2")
    debug_assert(ptr[0] == b'a', "notnurseryadr[0] == b'a' is is %s" % ptr[0])
    ptr[0] = b'x' # oh no no, in real programs nobody is allowed to modify that
    debug_assert(mystr[0] == b'a', "mystr[0] != b'a'")
    debug_assert(ptr[0] == b'x', "notnurseryadr[0] == b'x'")
    gc.collect()
    nptr = rffi.get_raw_address_of_string(mystr)
    debug_assert(nptr == ptr, "second call to mystr must return the same ptr")
    debug_assert(ptr[0] == b'x', "failure a")
    debug_assert(nptr[0] == b'x', "failure b")
    mystr = None

def long_str(lstr):
    ptr = rffi.get_raw_address_of_string(lstr)
    for i,c in enumerate(lstr):
        debug_assert(ptr[i] == c, "failure c")
    gc.collect()
    ptr2 = rffi.get_raw_address_of_string(lstr)
    debug_assert(ptr == ptr2, "ptr != ptr2!!!")
    return ptr

def main(argv=[]):
    try:
        use_str()
    except ValueError:
        return 42
    gc.collect()
    mystr = b"12341234aa"*4096*10
    #debug_assert(not rgc.can_move(mystr), "long string can move... why?")
    p1 = long_str(mystr)
    gc.collect()
    copystr = mystr[:]
    copystr += 'a'
    p2 = long_str(copystr)
    debug_assert(p1 != p2, "p1 == p2")
    return 0

# ____________________________________________________________

def target(driver, args):
    return main

def test_compiled_incminimark():
    fn = compile(main, [], gcpolicy="incminimark")
    res = fn()
    assert res == 0

def test_compiled_semispace():
    fn = compile(main, [], gcpolicy="semispace")
    res = fn()
    # get_raw_address_of_string() never raise ValueError any more
    assert res == 0

def test_compiled_boehm():
    fn = compile(main, [], gcpolicy="boehm")
    res = fn()
    assert res == 0
