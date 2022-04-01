import py, os

from rpython.rtyper.lltypesystem import lltype, llmemory, rffi, llarena
from rpython.rtyper.lltypesystem.llarena import (arena_malloc, arena_reset,
    arena_reserve, arena_free, round_up_for_allocation, ArenaError,
    arena_new_view, arena_shrink_obj, arena_protect, has_protect)
from rpython.rtyper.lltypesystem.llmemory import cast_adr_to_ptr
from rpython.translator.c.test import test_genc, test_standalone


def test_arena():
    S = lltype.Struct('S', ('x', lltype.Signed))
    SPTR = lltype.Ptr(S)
    ssize = llmemory.raw_malloc_usage(llmemory.sizeof(S))
    myarenasize = 2*ssize+1
    a = arena_malloc(myarenasize, False)
    assert a != llmemory.NULL
    assert a + 3 != llmemory.NULL

    arena_reserve(a, llmemory.sizeof(S))
    s1_ptr1 = cast_adr_to_ptr(a, SPTR)
    s1_ptr1.x = 1
    s1_ptr2 = cast_adr_to_ptr(a, SPTR)
    assert s1_ptr2.x == 1
    assert s1_ptr1 == s1_ptr2

    py.test.raises(ArenaError, arena_reserve, a + ssize + 1,  # misaligned
                   llmemory.sizeof(S))
    arena_reserve(a + ssize + 1, llmemory.sizeof(S), check_alignment=False)
    s2_ptr1 = cast_adr_to_ptr(a + ssize + 1, SPTR)
    py.test.raises(lltype.UninitializedMemoryAccess, 's2_ptr1.x')
    s2_ptr1.x = 2
    s2_ptr2 = cast_adr_to_ptr(a + ssize + 1, SPTR)
    assert s2_ptr2.x == 2
    assert s2_ptr1 == s2_ptr2
    assert s1_ptr1 != s2_ptr1
    assert not (s2_ptr2 == s1_ptr2)
    assert s1_ptr1 == cast_adr_to_ptr(a, SPTR)

    S2 = lltype.Struct('S2', ('y',lltype.Char))
    S2PTR = lltype.Ptr(S2)
    py.test.raises(lltype.InvalidCast, cast_adr_to_ptr, a, S2PTR)
    py.test.raises(ArenaError, cast_adr_to_ptr, a+1, SPTR)
    py.test.raises(ArenaError, cast_adr_to_ptr, a+ssize, SPTR)
    py.test.raises(ArenaError, cast_adr_to_ptr, a+2*ssize, SPTR)
    py.test.raises(ArenaError, cast_adr_to_ptr, a+2*ssize+1, SPTR)
    py.test.raises(ArenaError, arena_reserve, a+1, llmemory.sizeof(S),
                   False)
    py.test.raises(ArenaError, arena_reserve, a+ssize, llmemory.sizeof(S),
                   False)
    py.test.raises(ArenaError, arena_reserve, a+2*ssize, llmemory.sizeof(S),
                   False)
    py.test.raises(ArenaError, arena_reserve, a+2*ssize+1, llmemory.sizeof(S),
                   False)

    arena_reset(a, myarenasize, True)
    py.test.raises(ArenaError, cast_adr_to_ptr, a, SPTR)
    arena_reserve(a, llmemory.sizeof(S))
    s1_ptr1 = cast_adr_to_ptr(a, SPTR)
    assert s1_ptr1.x == 0
    s1_ptr1.x = 5

    arena_reserve(a + ssize, llmemory.sizeof(S2), check_alignment=False)
    s2_ptr1 = cast_adr_to_ptr(a + ssize, S2PTR)
    assert s2_ptr1.y == '\x00'
    s2_ptr1.y = 'X'

    assert cast_adr_to_ptr(a + 0, SPTR).x == 5
    assert cast_adr_to_ptr((a + ssize + 1) - 1, S2PTR).y == 'X'

    assert (a + 4) - (a + 1) == 3


def lt(x, y):
    if x < y:
        assert     (x < y)  and     (y > x)
        assert     (x <= y) and     (y >= x)
        assert not (x == y) and not (y == x)
        assert     (x != y) and     (y != x)
        assert not (x > y)  and not (y < x)
        assert not (x >= y) and not (y <= x)
        return True
    else:
        assert (x >= y) and (y <= x)
        assert (x == y) == (not (x != y)) == (y == x) == (not (y != x))
        assert (x > y) == (not (x == y)) == (y < x)
        return False

def eq(x, y):
    if x == y:
        assert not (x != y) and not (y != x)
        assert not (x < y)  and not (y > x)
        assert not (x > y)  and not (y < x)
        assert     (x <= y) and     (y >= x)
        assert     (x >= y) and     (y <= x)
        return True
    else:
        assert (x != y) and (y != x)
        assert ((x < y) == (x <= y) == (not (x > y)) == (not (x >= y)) ==
                (y > x) == (y >= x) == (not (y < x)) == (not (y <= x)))
        return False


def test_address_order():
    a = arena_malloc(24, False)
    assert eq(a, a)
    assert lt(a, a+1)
    assert lt(a+5, a+20)

    b = arena_malloc(24, False)
    if a > b:
        a, b = b, a
    assert lt(a, b)
    assert lt(a+19, b)
    assert lt(a, b+19)

    c = b + round_up_for_allocation(llmemory.sizeof(lltype.Char))
    arena_reserve(c, precomputed_size)
    assert lt(b, c)
    assert lt(a, c)
    assert lt(llmemory.NULL, c)
    d = c + llmemory.offsetof(SX, 'x')
    assert lt(c, d)
    assert lt(b, d)
    assert lt(a, d)
    assert lt(llmemory.NULL, d)
    e = c + precomputed_size
    assert lt(d, e)
    assert lt(c, e)
    assert lt(b, e)
    assert lt(a, e)
    assert lt(llmemory.NULL, e)


SX = lltype.Struct('S', ('foo',lltype.Signed), ('x',lltype.Signed))
SPTR = lltype.Ptr(SX)
precomputed_size = round_up_for_allocation(llmemory.sizeof(SX))

def test_look_inside_object():
    # this code is also used in translation tests below
    myarenasize = 50
    a = arena_malloc(myarenasize, False)
    b = a + round_up_for_allocation(llmemory.sizeof(lltype.Char))
    arena_reserve(b, precomputed_size)
    (b + llmemory.offsetof(SX, 'x')).signed[0] = 123
    assert llmemory.cast_adr_to_ptr(b, SPTR).x == 123
    llmemory.cast_adr_to_ptr(b, SPTR).x += 1
    assert (b + llmemory.offsetof(SX, 'x')).signed[0] == 124
    arena_reset(a, myarenasize, True)
    arena_reserve(b, round_up_for_allocation(llmemory.sizeof(SX)))
    assert llmemory.cast_adr_to_ptr(b, SPTR).x == 0
    arena_free(a)
    return 42

def test_arena_new_view():
    a = arena_malloc(50, False)
    arena_reserve(a, precomputed_size)
    # we can now allocate the same space in new view
    b = arena_new_view(a)
    arena_reserve(b, precomputed_size)

def test_partial_arena_reset():
    a = arena_malloc(72, False)
    def reserve(i):
        b = a + i * llmemory.raw_malloc_usage(precomputed_size)
        arena_reserve(b, precomputed_size)
        return b
    blist = []
    plist = []
    for i in range(4):
        b = reserve(i)
        (b + llmemory.offsetof(SX, 'x')).signed[0] = 100 + i
        blist.append(b)
        plist.append(llmemory.cast_adr_to_ptr(b, SPTR))
    # clear blist[1] and blist[2] but not blist[0] nor blist[3]
    arena_reset(blist[1], llmemory.raw_malloc_usage(precomputed_size)*2, False)
    py.test.raises(RuntimeError, "plist[1].x")     # marked as freed
    py.test.raises(RuntimeError, "plist[2].x")     # marked as freed
    # re-reserve object at index 1 and 2
    blist[1] = reserve(1)
    blist[2] = reserve(2)
    # check via object pointers
    assert plist[0].x == 100
    assert plist[3].x == 103
    py.test.raises(RuntimeError, "plist[1].x")     # marked as freed
    py.test.raises(RuntimeError, "plist[2].x")     # marked as freed
    # but we can still cast the old ptrs to addresses, which compare equal
    # to the new ones we gotq
    assert llmemory.cast_ptr_to_adr(plist[1]) == blist[1]
    assert llmemory.cast_ptr_to_adr(plist[2]) == blist[2]
    # check via addresses
    assert (blist[0] + llmemory.offsetof(SX, 'x')).signed[0] == 100
    assert (blist[3] + llmemory.offsetof(SX, 'x')).signed[0] == 103
    py.test.raises(lltype.UninitializedMemoryAccess,
          "(blist[1] + llmemory.offsetof(SX, 'x')).signed[0]")
    py.test.raises(lltype.UninitializedMemoryAccess,
          "(blist[2] + llmemory.offsetof(SX, 'x')).signed[0]")
    # clear and zero-fill the area over blist[0] and blist[1]
    arena_reset(blist[0], llmemory.raw_malloc_usage(precomputed_size)*2, True)
    # re-reserve and check it's zero
    blist[0] = reserve(0)
    blist[1] = reserve(1)
    assert (blist[0] + llmemory.offsetof(SX, 'x')).signed[0] == 0
    assert (blist[1] + llmemory.offsetof(SX, 'x')).signed[0] == 0
    assert (blist[3] + llmemory.offsetof(SX, 'x')).signed[0] == 103
    py.test.raises(lltype.UninitializedMemoryAccess,
          "(blist[2] + llmemory.offsetof(SX, 'x')).signed[0]")

def test_address_eq_as_int():
    a = arena_malloc(50, False)
    arena_reserve(a, precomputed_size)
    p = llmemory.cast_adr_to_ptr(a, SPTR)
    a1 = llmemory.cast_ptr_to_adr(p)
    assert a == a1
    assert not (a != a1)
    assert (a+1) != a1
    assert not ((a+1) == a1)
    py.test.skip("cast_adr_to_int() is hard to get consistent")
    assert llmemory.cast_adr_to_int(a) == llmemory.cast_adr_to_int(a1)
    assert llmemory.cast_adr_to_int(a+1) == llmemory.cast_adr_to_int(a1) + 1

def test_replace_object_with_stub():
    from rpython.memory.gcheader import GCHeaderBuilder
    HDR = lltype.Struct('HDR', ('x', lltype.Signed))
    S = lltype.GcStruct('S', ('y', lltype.Signed), ('z', lltype.Signed))
    STUB = lltype.GcStruct('STUB', ('t', lltype.Char))
    gcheaderbuilder = GCHeaderBuilder(HDR)
    size_gc_header = gcheaderbuilder.size_gc_header
    ssize = llmemory.raw_malloc_usage(llmemory.sizeof(S))

    a = arena_malloc(13*ssize, True)
    hdraddr = a + 3*ssize
    arena_reserve(hdraddr, size_gc_header + llmemory.sizeof(S))
    hdr = llmemory.cast_adr_to_ptr(hdraddr, lltype.Ptr(HDR))
    hdr.x = 42
    obj = llmemory.cast_adr_to_ptr(hdraddr + size_gc_header, lltype.Ptr(S))
    obj.y = -5
    obj.z = -6

    hdraddr = llmemory.cast_ptr_to_adr(obj) - size_gc_header
    arena_reset(hdraddr, size_gc_header + llmemory.sizeof(S), False)
    arena_reserve(hdraddr, size_gc_header + llmemory.sizeof(STUB))

    # check that it possible to reach the newly reserved HDR+STUB
    # via the header of the old 'obj' pointer, both via the existing
    # 'hdraddr':
    hdr = llmemory.cast_adr_to_ptr(hdraddr, lltype.Ptr(HDR))
    hdr.x = 46
    stub = llmemory.cast_adr_to_ptr(hdraddr + size_gc_header, lltype.Ptr(STUB))
    stub.t = '!'

    # and via a (now-invalid) pointer to the old 'obj': (this is needed
    # because during a garbage collection there are still pointers to
    # the old 'obj' around to be fixed)
    hdraddr = llmemory.cast_ptr_to_adr(obj) - size_gc_header
    hdr = llmemory.cast_adr_to_ptr(hdraddr, lltype.Ptr(HDR))
    assert hdr.x == 46
    stub = llmemory.cast_adr_to_ptr(hdraddr + size_gc_header,
                                    lltype.Ptr(STUB))
    assert stub.t == '!'


def test_llinterpreted():
    from rpython.rtyper.test.test_llinterp import interpret
    res = interpret(test_look_inside_object, [])
    assert res == 42

def test_compiled():
    fn = test_genc.compile(test_look_inside_object, [])
    res = fn()
    assert res == 42

def test_shrink_obj():
    from rpython.memory.gcheader import GCHeaderBuilder
    HDR = lltype.Struct('HDR', ('h', lltype.Signed))
    gcheaderbuilder = GCHeaderBuilder(HDR)
    size_gc_header = gcheaderbuilder.size_gc_header
    S = lltype.GcStruct('S', ('x', lltype.Signed),
                             ('a', lltype.Array(lltype.Signed)))
    myarenasize = 200
    a = arena_malloc(myarenasize, False)
    arena_reserve(a, size_gc_header + llmemory.sizeof(S, 10))
    arena_shrink_obj(a, size_gc_header + llmemory.sizeof(S, 5))
    arena_reset(a, size_gc_header + llmemory.sizeof(S, 5), False)

def test_arena_protect():
    a = arena_malloc(100, False)
    S = lltype.Struct('S', ('x', lltype.Signed))
    arena_reserve(a, llmemory.sizeof(S))
    p = llmemory.cast_adr_to_ptr(a, lltype.Ptr(S))
    p.x = 123
    assert p.x == 123
    arena_protect(a, 100, True)
    py.test.raises(ArenaError, arena_reserve, a + 48, llmemory.sizeof(S))
    py.test.raises(RuntimeError, "p.x")
    py.test.raises(RuntimeError, "p.x = 124")
    arena_protect(a, 100, False)
    assert p.x == 123
    p.x = 125
    assert p.x == 125

def test_madvise_arena_free():
    from rpython.rlib import rmmap

    if os.name != 'posix':
        py.test.skip("posix only")
    pagesize = llarena.posixpagesize.get()
    prev = rmmap.madvise_free
    try:
        seen = []
        def my_madvise_free(addr, size):
            assert lltype.typeOf(addr) == rmmap.PTR
            seen.append((addr, size))
        rmmap.madvise_free = my_madvise_free
        llarena.madvise_arena_free(
            rffi.cast(llmemory.Address, 123 * pagesize + 1),
            pagesize * 7 - 2)
    finally:
        rmmap.madvise_free = prev
    assert len(seen) == 1
    addr, size = seen[0]
    assert rffi.cast(lltype.Signed, addr) == 124 * pagesize
    assert size == pagesize * 5


class TestStandalone(test_standalone.StandaloneTests):
    def test_compiled_arena_protect(self):
        import sys
        S = lltype.Struct('S', ('x', lltype.Signed))
        #
        def fn(argv):
            testrun = int(argv[1])
            a = arena_malloc(65536, False)
            arena_reserve(a, llmemory.sizeof(S))
            p = llmemory.cast_adr_to_ptr(a + 23432, lltype.Ptr(S))
            p.x = 123
            assert p.x == 123
            arena_protect(a, 65536, True)
            result = 0
            if testrun == 1:
                print p.x       # segfault
            if testrun == 2:
                p.x = 124       # segfault
            arena_protect(a, 65536, False)
            p.x += 10
            print p.x
            return 0
        #
        t, cbuilder = self.compile(fn)
        data = cbuilder.cmdexec('0')
        assert data == '133\n'
        if has_protect:
            if sys.platform.startswith('win'):
                # Do not open error dialog box
                import ctypes
                SEM_NOGPFAULTERRORBOX = 0x0002 # From MSDN
                old_err_mode = ctypes.windll.kernel32.GetErrorMode()
                new_err_mode = old_err_mode | SEM_NOGPFAULTERRORBOX
                ctypes.windll.kernel32.SetErrorMode(new_err_mode)
            cbuilder.cmdexec('1', expect_crash=True)
            cbuilder.cmdexec('2', expect_crash=True)
            if sys.platform.startswith('win'):
                ctypes.windll.kernel32.SetErrorMode(old_err_mode)
