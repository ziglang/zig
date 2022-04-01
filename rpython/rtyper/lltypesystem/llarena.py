import array
from rpython.rtyper.lltypesystem import llmemory
from rpython.rlib.rarithmetic import is_valid_int
from rpython.rtyper.lltypesystem.lloperation import llop
import os, sys

# An "arena" is a large area of memory which can hold a number of
# objects, not necessarily all of the same type or size.  It's used by
# some of our framework GCs.  Addresses that point inside arenas support
# direct arithmetic: adding and subtracting integers, and taking the
# difference of two addresses.  When not translated to C, the arena
# keeps track of which bytes are used by what object to detect GC bugs;
# it internally uses raw_malloc_usage() to estimate the number of bytes
# it needs to reserve.

class ArenaError(Exception):
    pass

class Arena(object):
    _count_arenas = 0

    def __init__(self, nbytes, zero):
        Arena._count_arenas += 1
        self._arena_index = Arena._count_arenas
        self.nbytes = nbytes
        self.usagemap = array.array('c')
        self.objectptrs = {}        # {offset: ptr-to-container}
        self.objectsizes = {}       # {offset: size}
        self.freed = False
        self.protect_inaccessible = None
        self.reset(zero)

    def __repr__(self):
        return '<Arena #%d [%d bytes]>' % (self._arena_index, self.nbytes)

    def reset(self, zero, start=0, size=None):
        self.check()
        if size is None:
            stop = self.nbytes
        else:
            stop = start + llmemory.raw_malloc_usage(size)
        assert 0 <= start <= stop <= self.nbytes
        for offset, ptr in self.objectptrs.items():
            size = self.objectsizes[offset]
            if offset < start:   # object is before the cleared area
                assert offset + size <= start, "object overlaps cleared area"
            elif offset + size > stop:  # object is after the cleared area
                assert offset >= stop, "object overlaps cleared area"
            else:
                obj = ptr._obj
                obj.__arena_location__[0] = False   # no longer valid
                del self.objectptrs[offset]
                del self.objectsizes[offset]
                obj._free()
        if zero in (1, 2):
            initialbyte = "0"
        else:
            initialbyte = "#"
        self.usagemap[start:stop] = array.array('c', initialbyte*(stop-start))

    def check(self):
        if self.freed:
            raise ArenaError("arena was already freed")
        if self.protect_inaccessible is not None:
            raise ArenaError("arena is currently arena_protect()ed")

    def _getid(self):
        address, length = self.usagemap.buffer_info()
        return address

    def getaddr(self, offset):
        if not (0 <= offset <= self.nbytes):
            raise ArenaError("Address offset is outside the arena")
        return fakearenaaddress(self, offset)

    def allocate_object(self, offset, size, letter='x'):
        self.check()
        bytes = llmemory.raw_malloc_usage(size)
        if offset + bytes > self.nbytes:
            raise ArenaError("object overflows beyond the end of the arena")
        zero = True
        for c in self.usagemap[offset:offset+bytes]:
            if c == '0':
                pass
            elif c == '#':
                zero = False
            else:
                raise ArenaError("new object overlaps a previous object")
        assert offset not in self.objectptrs
        addr2 = size._raw_malloc([], zero=zero)
        pattern = letter.upper() + letter*(bytes-1)
        self.usagemap[offset:offset+bytes] = array.array('c', pattern)
        self.setobject(addr2, offset, bytes)
        # common case: 'size' starts with a GCHeaderOffset.  In this case
        # we can also remember that the real object starts after the header.
        while isinstance(size, RoundedUpForAllocation):
            size = size.basesize
        if (isinstance(size, llmemory.CompositeOffset) and
            isinstance(size.offsets[0], llmemory.GCHeaderOffset)):
            objaddr = addr2 + size.offsets[0]
            hdrbytes = llmemory.raw_malloc_usage(size.offsets[0])
            objoffset = offset + hdrbytes
            self.setobject(objaddr, objoffset, bytes - hdrbytes)
        return addr2

    def setobject(self, objaddr, offset, bytes):
        assert bytes > 0, ("llarena does not support GcStructs with no field"
                           " or empty arrays")
        assert offset not in self.objectptrs
        self.objectptrs[offset] = objaddr.ptr
        self.objectsizes[offset] = bytes
        container = objaddr.ptr._obj
        container.__arena_location__ = [True, self, offset]

    def shrink_obj(self, offset, newsize):
        oldbytes = self.objectsizes[offset]
        newbytes = llmemory.raw_malloc_usage(newsize)
        assert newbytes <= oldbytes
        # fix self.objectsizes
        for i in range(newbytes):
            adr = offset + i
            if adr in self.objectsizes:
                assert self.objectsizes[adr] == oldbytes - i
                self.objectsizes[adr] = newbytes - i
        # fix self.usagemap
        for i in range(offset + newbytes, offset + oldbytes):
            assert self.usagemap[i] == 'x'
            self.usagemap[i] = '#'

    def mark_freed(self):
        self.freed = True    # this method is a hook for tests

    def set_protect(self, inaccessible):
        if inaccessible:
            assert self.protect_inaccessible is None
            saved = []
            for ptr in self.objectptrs.values():
                obj = ptr._obj
                saved.append((obj, obj._protect()))
            self.protect_inaccessible = saved
        else:
            assert self.protect_inaccessible is not None
            saved = self.protect_inaccessible
            for obj, storage in saved:
                obj._unprotect(storage)
            self.protect_inaccessible = None

class fakearenaaddress(llmemory.fakeaddress):

    def __init__(self, arena, offset):
        self.arena = arena
        self.offset = offset

    def _getptr(self):
        try:
            return self.arena.objectptrs[self.offset]
        except KeyError:
            self.arena.check()
            raise ArenaError("don't know yet what type of object "
                             "is at offset %d" % (self.offset,))
    ptr = property(_getptr)

    def __repr__(self):
        return '<arenaaddr %s + %d>' % (self.arena, self.offset)

    def __add__(self, other):
        if is_valid_int(other):
            position = self.offset + other
        elif isinstance(other, llmemory.AddressOffset):
            # this is really some Do What I Mean logic.  There are two
            # possible meanings: either we want to go past the current
            # object in the arena, or we want to take the address inside
            # the current object.  Try to guess...
            bytes = llmemory.raw_malloc_usage(other)
            if (self.offset in self.arena.objectsizes and
                bytes < self.arena.objectsizes[self.offset]):
                # looks like we mean "inside the object"
                return llmemory.fakeaddress.__add__(self, other)
            position = self.offset + bytes
        else:
            return NotImplemented
        return self.arena.getaddr(position)

    def __sub__(self, other):
        if isinstance(other, llmemory.AddressOffset):
            other = llmemory.raw_malloc_usage(other)
        if is_valid_int(other):
            return self.arena.getaddr(self.offset - other)
        if isinstance(other, fakearenaaddress):
            if self.arena is not other.arena:
                raise ArenaError("The two addresses are from different arenas")
            return self.offset - other.offset
        return NotImplemented

    def __nonzero__(self):
        return True

    def compare_with_fakeaddr(self, other):
        other = other._fixup()
        if not other:
            return None, None
        obj = other.ptr._obj
        innerobject = False
        while not getattr(obj, '__arena_location__', (False,))[0]:
            obj = obj._parentstructure()
            if obj is None:
                return None, None     # not found in the arena
            innerobject = True
        _, arena, offset = obj.__arena_location__
        if innerobject:
            # 'obj' is really inside the object allocated from the arena,
            # so it's likely that its address "should be" a bit larger than
            # what 'offset' says.
            # We could estimate the correct offset but it's a bit messy;
            # instead, let's check the answer doesn't depend on it
            if self.arena is arena:
                objectsize = arena.objectsizes[offset]
                if offset < self.offset < offset+objectsize:
                    raise AssertionError(
                        "comparing an inner address with a "
                        "fakearenaaddress that points in the "
                        "middle of the same object")
                offset += objectsize // 2      # arbitrary
        return arena, offset

    def __eq__(self, other):
        if isinstance(other, fakearenaaddress):
            arena = other.arena
            offset = other.offset
        elif isinstance(other, llmemory.fakeaddress):
            arena, offset = self.compare_with_fakeaddr(other)
        else:
            return llmemory.fakeaddress.__eq__(self, other)
        return self.arena is arena and self.offset == offset

    def __lt__(self, other):
        if isinstance(other, fakearenaaddress):
            arena = other.arena
            offset = other.offset
        elif isinstance(other, llmemory.fakeaddress):
            arena, offset = self.compare_with_fakeaddr(other)
            if arena is None:
                return False       # self < other-not-in-any-arena  => False
                                   # (arbitrarily)
        else:
            raise TypeError("comparing a %s and a %s" % (
                self.__class__.__name__, other.__class__.__name__))
        if self.arena is arena:
            return self.offset < offset
        else:
            return self.arena._getid() < arena._getid()

    def _cast_to_int(self, symbolic=False):
        assert not symbolic
        return rffi.cast(lltype.Signed, self.arena._getid() + self.offset)


def getfakearenaaddress(addr):
    """Logic to handle test_replace_object_with_stub()."""
    if isinstance(addr, fakearenaaddress):
        return addr
    else:
        assert isinstance(addr, llmemory.fakeaddress)
        assert addr, "NULL address"
        # it must be possible to use the address of an already-freed
        # arena object
        obj = addr.ptr._getobj(check=False)
        return _oldobj_to_address(obj)

def _oldobj_to_address(obj):
    obj = obj._normalizedcontainer(check=False)
    try:
        _, arena, offset = obj.__arena_location__
    except AttributeError:
        if obj._was_freed():
            msg = "taking address of %r, but it was freed"
        else:
            msg = "taking address of %r, but it is not in an arena"
        raise RuntimeError(msg % (obj,))
    return arena.getaddr(offset)

class RoundedUpForAllocation(llmemory.AddressOffset):
    """A size that is rounded up in order to preserve alignment of objects
    following it.  For arenas containing heterogenous objects.
    """
    def __init__(self, basesize, minsize):
        assert isinstance(basesize, llmemory.AddressOffset)
        assert isinstance(minsize, llmemory.AddressOffset) or minsize == 0
        self.basesize = basesize
        self.minsize = minsize

    def __repr__(self):
        return '< RoundedUpForAllocation %r %r >' % (self.basesize,
                                                     self.minsize)

    def known_nonneg(self):
        return self.basesize.known_nonneg()

    def ref(self, ptr):
        return self.basesize.ref(ptr)

    def _raw_malloc(self, rest, zero):
        return self.basesize._raw_malloc(rest, zero=zero)

    def raw_memcopy(self, srcadr, dstadr):
        self.basesize.raw_memcopy(srcadr, dstadr)

# ____________________________________________________________
#
# Public interface: arena_malloc(), arena_free(), arena_reset()
# are similar to raw_malloc(), raw_free() and raw_memclear(), but
# work with fakearenaaddresses on which arbitrary arithmetic is
# possible even on top of the llinterpreter.

# arena_new_view(ptr) is a no-op when translated, returns fresh view
# on previous arena when run on top of llinterp

def arena_malloc(nbytes, zero):
    """Allocate and return a new arena, optionally zero-initialized."""
    return Arena(nbytes, zero).getaddr(0)

def arena_free(arena_addr):
    """Release an arena."""
    assert isinstance(arena_addr, fakearenaaddress)
    assert arena_addr.offset == 0
    arena_addr.arena.reset(False)
    assert not arena_addr.arena.objectptrs
    arena_addr.arena.mark_freed()

def arena_reset(arena_addr, size, zero):
    """Free all objects in the arena, which can then be reused.
    This can also be used on a subrange of the arena.
    The value of 'zero' is:
      * 0: don't fill the area with zeroes
      * 1: clear, optimized for a very large area of memory
      * 2: clear, optimized for a small or medium area of memory
      * 3: fill with garbage
      * 4: large area of memory that can benefit from MADV_FREE
             (i.e. contains garbage, may be zero-filled or not)
    """
    arena_addr = getfakearenaaddress(arena_addr)
    arena_addr.arena.reset(zero, arena_addr.offset, size)

def arena_reserve(addr, size, check_alignment=True):
    """Mark some bytes in an arena as reserved, and returns addr.
    For debugging this can check that reserved ranges of bytes don't
    overlap.  The size must be symbolic; in non-translated version
    this is used to know what type of lltype object to allocate."""
    from rpython.memory.lltypelayout import memory_alignment
    addr = getfakearenaaddress(addr)
    letter = 'x'
    if llmemory.raw_malloc_usage(size) == 1:
        letter = 'b'    # for Byte-aligned allocations
    elif check_alignment and (addr.offset & (memory_alignment-1)) != 0:
        raise ArenaError("object at offset %d would not be correctly aligned"
                         % (addr.offset,))
    addr.arena.allocate_object(addr.offset, size, letter)

def arena_shrink_obj(addr, newsize):
    """ Mark object as shorter than it was
    """
    addr = getfakearenaaddress(addr)
    addr.arena.shrink_obj(addr.offset, newsize)

def round_up_for_allocation(size, minsize=0):
    """Round up the size in order to preserve alignment of objects
    following an object.  For arenas containing heterogenous objects.
    If minsize is specified, it gives a minimum on the resulting size."""
    return _round_up_for_allocation(size, minsize)
round_up_for_allocation._annenforceargs_ = [int, int]

def _round_up_for_allocation(size, minsize):    # internal
    return RoundedUpForAllocation(size, minsize)

def arena_new_view(ptr):
    """Return a fresh memory view on an arena
    """
    return Arena(ptr.arena.nbytes, False).getaddr(0)

def arena_protect(arena_addr, size, inaccessible):
    """For debugging, set or reset memory protection on an arena.
    For now, the starting point and size should reference the whole arena.
    The value of 'inaccessible' is a boolean.
    """
    arena_addr = getfakearenaaddress(arena_addr)
    assert arena_addr.offset == 0
    assert size == arena_addr.arena.nbytes
    arena_addr.arena.set_protect(inaccessible)

# ____________________________________________________________
#
# Translation support: the functions above turn into the code below.
# We can tweak these implementations to be more suited to very large
# chunks of memory.

from rpython.rtyper.lltypesystem import rffi, lltype
from rpython.rtyper.extfunc import register_external
from rpython.rtyper.tool.rffi_platform import memory_alignment

MEMORY_ALIGNMENT = memory_alignment()

if os.name == 'posix':
    # The general Posix solution to clear a large range of memory that
    # was obtained with mmap() is to call mmap() again with MAP_FIXED.

    legacy_getpagesize = rffi.llexternal('getpagesize', [], rffi.INT,
                                         sandboxsafe=True, _nowrapper=True)

    class PosixPageSize:
        def __init__(self):
            self.pagesize = 0
        def _cleanup_(self):
            self.pagesize = 0
        def get(self):
            pagesize = self.pagesize
            if pagesize == 0:
                pagesize = rffi.cast(lltype.Signed, legacy_getpagesize())
                self.pagesize = pagesize
            return pagesize

    posixpagesize = PosixPageSize()

    def clear_large_memory_chunk(baseaddr, size):
        from rpython.rlib import rmmap

        pagesize = posixpagesize.get()
        if size > 2 * pagesize:
            lowbits = rffi.cast(lltype.Signed, baseaddr) & (pagesize - 1)
            if lowbits:     # clear the initial misaligned part, if any
                partpage = pagesize - lowbits
                llmemory.raw_memclear(baseaddr, partpage)
                baseaddr += partpage
                size -= partpage
            length = size & -pagesize
            if rmmap.clear_large_memory_chunk_aligned(baseaddr, length):
                baseaddr += length     # clearing worked
                size -= length

        if size > 0:    # clear the final misaligned part, if any
            llmemory.raw_memclear(baseaddr, size)

else:
    # XXX any better implementation on Windows?
    # Should use VirtualAlloc() to reserve the range of pages,
    # and commit some pages gradually with support from the GC.
    # Or it might be enough to decommit the pages and recommit
    # them immediately.
    clear_large_memory_chunk = llmemory.raw_memclear

    class PosixPageSize:
        def get(self):
            from rpython.rlib import rmmap
            return rmmap.PAGESIZE
    posixpagesize = PosixPageSize()

def madvise_arena_free(baseaddr, size):
    from rpython.rlib import rmmap

    pagesize = posixpagesize.get()
    baseaddr = rffi.cast(lltype.Signed, baseaddr)
    aligned_addr = (baseaddr + pagesize - 1) & ~(pagesize - 1)
    size -= (aligned_addr - baseaddr)
    if size >= pagesize:
        rmmap.madvise_free(rffi.cast(rmmap.PTR, aligned_addr),
                           size & ~(pagesize - 1))


if os.name == "posix":
    from rpython.translator.tool.cbuild import ExternalCompilationInfo
    _eci = ExternalCompilationInfo(includes=['sys/mman.h'])
    raw_mprotect = rffi.llexternal('mprotect',
                                   [llmemory.Address, rffi.SIZE_T, rffi.INT],
                                   rffi.INT,
                                   sandboxsafe=True, _nowrapper=True,
                                   compilation_info=_eci)
    def llimpl_protect(addr, size, inaccessible):
        if inaccessible:
            prot = 0
        else:
            from rpython.rlib.rmmap import PROT_READ, PROT_WRITE
            prot = PROT_READ | PROT_WRITE
        raw_mprotect(addr, rffi.cast(rffi.SIZE_T, size),
                     rffi.cast(rffi.INT, prot))
        # ignore potential errors
    has_protect = True

elif os.name == 'nt':
    def llimpl_protect(addr, size, inaccessible):
        from rpython.rlib.rmmap import VirtualProtect, LPDWORD
        if inaccessible:
            from rpython.rlib.rmmap import PAGE_NOACCESS as newprotect
        else:
            from rpython.rlib.rmmap import PAGE_READWRITE as newprotect
        arg = lltype.malloc(LPDWORD.TO, 1, zero=True, flavor='raw')
        #does not release the GIL
        VirtualProtect(rffi.cast(rffi.VOIDP, addr),
                       size, newprotect, arg)
        # ignore potential errors
        lltype.free(arg, flavor='raw')
    has_protect = True

else:
    has_protect = False


llimpl_malloc = rffi.llexternal('malloc', [lltype.Signed], llmemory.Address,
                                sandboxsafe=True, _nowrapper=True)
llimpl_calloc = rffi.llexternal('calloc', [lltype.Signed, lltype.Signed],
                                llmemory.Address,
                                sandboxsafe=True, _nowrapper=True)
llimpl_free = rffi.llexternal('free', [llmemory.Address], lltype.Void,
                              sandboxsafe=True, _nowrapper=True)

def llimpl_arena_malloc(nbytes, zero):
    if zero:
        addr = llimpl_calloc(nbytes, 1)
    else:
        addr = llimpl_malloc(nbytes)
    return addr
llimpl_arena_malloc._always_inline_ = True
register_external(arena_malloc, [int, int], llmemory.Address,
                  'll_arena.arena_malloc',
                  llimpl=llimpl_arena_malloc,
                  llfakeimpl=arena_malloc,
                  sandboxsafe=True)

register_external(arena_free, [llmemory.Address], None, 'll_arena.arena_free',
                  llimpl=llimpl_free,
                  llfakeimpl=arena_free,
                  sandboxsafe=True)

def llimpl_arena_reset(arena_addr, size, zero):
    if zero:
        if zero == 1:
            clear_large_memory_chunk(arena_addr, size)
        elif zero == 3:
            llop.raw_memset(lltype.Void, arena_addr, ord('#'), size)
        elif zero == 4:
            madvise_arena_free(arena_addr, size)
        else:
            llmemory.raw_memclear(arena_addr, size)
llimpl_arena_reset._always_inline_ = True
register_external(arena_reset, [llmemory.Address, int, int], None,
                  'll_arena.arena_reset',
                  llimpl=llimpl_arena_reset,
                  llfakeimpl=arena_reset,
                  sandboxsafe=True)

def llimpl_arena_reserve(addr, size):
    pass
register_external(arena_reserve, [llmemory.Address, int], None,
                  'll_arena.arena_reserve',
                  llimpl=llimpl_arena_reserve,
                  llfakeimpl=arena_reserve,
                  sandboxsafe=True)

def llimpl_arena_shrink_obj(addr, newsize):
    pass
register_external(arena_shrink_obj, [llmemory.Address, int], None,
                  'll_arena.arena_shrink_obj',
                  llimpl=llimpl_arena_shrink_obj,
                  llfakeimpl=arena_shrink_obj,
                  sandboxsafe=True)

def llimpl_round_up_for_allocation(size, minsize):
    return (max(size, minsize) + (MEMORY_ALIGNMENT-1)) & ~(MEMORY_ALIGNMENT-1)
register_external(_round_up_for_allocation, [int, int], int,
                  'll_arena.round_up_for_allocation',
                  llimpl=llimpl_round_up_for_allocation,
                  llfakeimpl=round_up_for_allocation,
                  sandboxsafe=True)

def llimpl_arena_new_view(addr):
    return addr
register_external(arena_new_view, [llmemory.Address], llmemory.Address,
                  'll_arena.arena_new_view', llimpl=llimpl_arena_new_view,
                  llfakeimpl=arena_new_view, sandboxsafe=True)

def llimpl_arena_protect(addr, size, inaccessible):
    if has_protect:
        # do some alignment
        start = rffi.cast(lltype.Signed, addr)
        end = start + size
        start = (start + 4095) & ~ 4095
        end = end & ~ 4095
        if end > start:
            llimpl_protect(rffi.cast(llmemory.Address, start), end-start,
                           inaccessible)
register_external(arena_protect, [llmemory.Address, lltype.Signed,
                                  lltype.Bool], lltype.Void,
                  'll_arena.arena_protect', llimpl=llimpl_arena_protect,
                  llfakeimpl=arena_protect, sandboxsafe=True)

def llimpl_getfakearenaaddress(addr):
    return addr
register_external(getfakearenaaddress, [llmemory.Address], llmemory.Address,
                  'll_arena.getfakearenaaddress',
                  llimpl=llimpl_getfakearenaaddress,
                  llfakeimpl=getfakearenaaddress,
                  sandboxsafe=True)
