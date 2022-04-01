from rpython.rtyper.lltypesystem.llmemory import raw_malloc, raw_free
from rpython.rtyper.lltypesystem.llmemory import raw_memcopy, raw_memclear
from rpython.rtyper.lltypesystem.llmemory import NULL, raw_malloc_usage
from rpython.memory.support import get_address_stack, get_address_deque
from rpython.memory.support import AddressDict
from rpython.rtyper.lltypesystem import lltype, llmemory, llarena, rffi, llgroup
from rpython.rlib.objectmodel import free_non_gc_object
from rpython.rlib.debug import ll_assert, have_debug_prints
from rpython.rlib.debug import debug_print, debug_start, debug_stop
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.rarithmetic import ovfcheck, LONG_BIT
from rpython.memory.gc.base import MovingGCBase, ARRAY_TYPEID_MAP,\
     TYPEID_MAP

import sys, os

first_gcflag = 1 << (LONG_BIT//2)
GCFLAG_FORWARDED = first_gcflag
# GCFLAG_EXTERNAL is set on objects not living in the semispace:
# either immortal objects or (for HybridGC) externally raw_malloc'ed
GCFLAG_EXTERNAL = first_gcflag << 1
GCFLAG_FINALIZATION_ORDERING = first_gcflag << 2

_GCFLAG_HASH_BASE = first_gcflag << 3
GCFLAG_HASHMASK = _GCFLAG_HASH_BASE * 0x3   # also consumes 'first_gcflag << 4'
# the two bits in GCFLAG_HASHMASK can have one of the following values:
#   - nobody ever asked for the hash of the object
GC_HASH_NOTTAKEN   = _GCFLAG_HASH_BASE * 0x0
#   - someone asked, and we gave the address of the object
GC_HASH_TAKEN_ADDR = _GCFLAG_HASH_BASE * 0x1
#   - someone asked, and we gave the address plus 'nursery_hash_base'
GC_HASH_TAKEN_NURS = _GCFLAG_HASH_BASE * 0x2
#   - we have our own extra field to store the hash
GC_HASH_HASFIELD   = _GCFLAG_HASH_BASE * 0x3

GCFLAG_EXTRA = first_gcflag << 5    # for RPython abuse only

memoryError = MemoryError()


class SemiSpaceGC(MovingGCBase):
    _alloc_flavor_ = "raw"
    inline_simple_malloc = True
    inline_simple_malloc_varsize = True
    malloc_zero_filled = True
    first_unused_gcflag = first_gcflag << 6
    gcflag_extra = GCFLAG_EXTRA

    HDR = lltype.Struct('header', ('tid', lltype.Signed))   # XXX or rffi.INT?
    typeid_is_in_field = 'tid'
    FORWARDSTUB = lltype.GcStruct('forwarding_stub',
                                  ('forw', llmemory.Address))
    FORWARDSTUBPTR = lltype.Ptr(FORWARDSTUB)

    object_minimal_size = llmemory.sizeof(FORWARDSTUB)

    # the following values override the default arguments of __init__ when
    # translating to a real backend.
    TRANSLATION_PARAMS = {'space_size': 8*1024*1024} # XXX adjust

    def __init__(self, config, space_size=4096, max_space_size=sys.maxint//2+1,
                 **kwds):
        self.param_space_size = space_size
        self.param_max_space_size = max_space_size
        MovingGCBase.__init__(self, config, **kwds)

    def setup(self):
        #self.total_collection_time = 0.0
        self.total_collection_count = 0

        self.space_size = self.param_space_size
        self.max_space_size = self.param_max_space_size
        self.red_zone = 0

        #self.program_start_time = time.time()
        self.tospace = llarena.arena_malloc(self.space_size, True)
        ll_assert(bool(self.tospace), "couldn't allocate tospace")
        self.top_of_space = self.tospace + self.space_size
        self.fromspace = llarena.arena_malloc(self.space_size, True)
        ll_assert(bool(self.fromspace), "couldn't allocate fromspace")
        self.free = self.tospace
        MovingGCBase.setup(self)
        self.objects_with_finalizers = self.AddressDeque()
        self.objects_with_light_finalizers = self.AddressStack()
        self.objects_with_weakrefs = self.AddressStack()

    def _teardown(self):
        debug_print("Teardown")
        llarena.arena_free(self.fromspace)
        llarena.arena_free(self.tospace)

    # This class only defines the malloc_{fixed,var}size_clear() methods
    # because the spaces are filled with zeroes in advance.

    def malloc_fixedsize_clear(self, typeid16, size,
                               has_finalizer=False,
                               is_finalizer_light=False,
                               contains_weakptr=False):
        size_gc_header = self.gcheaderbuilder.size_gc_header
        totalsize = size_gc_header + size
        result = self.free
        if raw_malloc_usage(totalsize) > self.top_of_space - result:
            result = self.obtain_free_space(totalsize)
        llarena.arena_reserve(result, totalsize)
        self.init_gc_object(result, typeid16)
        self.free = result + totalsize
        #if is_finalizer_light:
        #    self.objects_with_light_finalizers.append(result + size_gc_header)
        #else:
        if has_finalizer:
            from rpython.rtyper.lltypesystem import rffi
            self.objects_with_finalizers.append(result + size_gc_header)
            self.objects_with_finalizers.append(rffi.cast(llmemory.Address, -1))
        if contains_weakptr:
            self.objects_with_weakrefs.append(result + size_gc_header)
        return llmemory.cast_adr_to_ptr(result+size_gc_header, llmemory.GCREF)

    def malloc_varsize_clear(self, typeid16, length, size, itemsize,
                             offset_to_length):
        size_gc_header = self.gcheaderbuilder.size_gc_header
        nonvarsize = size_gc_header + size
        try:
            varsize = ovfcheck(itemsize * length)
            totalsize = ovfcheck(nonvarsize + varsize)
        except OverflowError:
            raise memoryError
        result = self.free
        if raw_malloc_usage(totalsize) > self.top_of_space - result:
            result = self.obtain_free_space(totalsize)
        llarena.arena_reserve(result, totalsize)
        self.init_gc_object(result, typeid16)
        (result + size_gc_header + offset_to_length).signed[0] = length
        self.free = result + llarena.round_up_for_allocation(totalsize)
        return llmemory.cast_adr_to_ptr(result+size_gc_header, llmemory.GCREF)

    def shrink_array(self, addr, smallerlength):
        size_gc_header = self.gcheaderbuilder.size_gc_header
        if self._is_in_the_space(addr - size_gc_header):
            typeid = self.get_type_id(addr)
            totalsmallersize = (
                size_gc_header + self.fixed_size(typeid) +
                self.varsize_item_sizes(typeid) * smallerlength)
            llarena.arena_shrink_obj(addr - size_gc_header, totalsmallersize)
            #
            offset_to_length = self.varsize_offset_to_length(typeid)
            (addr + offset_to_length).signed[0] = smallerlength
            return True
        else:
            return False

    def register_finalizer(self, fq_index, gcobj):
        from rpython.rtyper.lltypesystem import rffi
        obj = llmemory.cast_ptr_to_adr(gcobj)
        fq_index = rffi.cast(llmemory.Address, fq_index)
        self.objects_with_finalizers.append(obj)
        self.objects_with_finalizers.append(fq_index)

    def obtain_free_space(self, needed):
        # a bit of tweaking to maximize the performance and minimize the
        # amount of code in an inlined version of malloc_fixedsize_clear()
        if not self.try_obtain_free_space(needed):
            raise memoryError
        return self.free
    obtain_free_space._dont_inline_ = True

    def try_obtain_free_space(self, needed):
        # XXX for bonus points do big objects differently
        needed = raw_malloc_usage(needed)
        if (self.red_zone >= 2 and self.space_size < self.max_space_size and
            self.double_space_size()):
            pass    # collect was done during double_space_size()
        else:
            self.semispace_collect()
        missing = needed - (self.top_of_space - self.free)
        if missing <= 0:
            return True      # success
        else:
            # first check if the object could possibly fit
            proposed_size = self.space_size
            while missing > 0:
                if proposed_size >= self.max_space_size:
                    return False    # no way
                missing -= proposed_size
                proposed_size *= 2
            # For address space fragmentation reasons, we double the space
            # size possibly several times, moving the objects at each step,
            # instead of going directly for the final size.  We assume that
            # it's a rare case anyway.
            while self.space_size < proposed_size:
                if not self.double_space_size():
                    return False
            ll_assert(needed <= self.top_of_space - self.free,
                         "double_space_size() failed to do its job")
            return True

    def double_space_size(self):
        self.red_zone = 0
        old_fromspace = self.fromspace
        newsize = self.space_size * 2
        newspace = llarena.arena_malloc(newsize, True)
        if not newspace:
            return False    # out of memory
        llarena.arena_free(old_fromspace)
        self.fromspace = newspace
        # now self.tospace contains the existing objects and
        # self.fromspace is the freshly allocated bigger space

        self.semispace_collect(size_changing=True)
        self.top_of_space = self.tospace + newsize
        # now self.tospace is the freshly allocated bigger space,
        # and self.fromspace is the old smaller space, now empty
        llarena.arena_free(self.fromspace)

        newspace = llarena.arena_malloc(newsize, True)
        if not newspace:
            # Complex failure case: we have in self.tospace a big chunk
            # of memory, and the two smaller original spaces are already gone.
            # Unsure if it's worth these efforts, but we can artificially
            # split self.tospace in two again...
            self.max_space_size = self.space_size    # don't try to grow again,
            #              because doing arena_free(self.fromspace) would crash
            self.fromspace = self.tospace + self.space_size
            self.top_of_space = self.fromspace
            ll_assert(self.free <= self.top_of_space,
                         "unexpected growth of GC space usage during collect")
            return False     # out of memory

        self.fromspace = newspace
        self.space_size = newsize
        return True    # success

    def set_max_heap_size(self, size):
        # Set the maximum semispace size.
        # The size is rounded down to the next power of two.  Also, this is
        # the size of one semispace only, so actual usage can be the double
        # during a collection.  Finally, note that this will never shrink
        # an already-allocated heap.
        if size < 1:
            size = 1     # actually, the minimum is 8MB in default translations
        self.max_space_size = sys.maxint//2+1
        while self.max_space_size > size:
            self.max_space_size >>= 1

    @classmethod
    def JIT_minimal_size_in_nursery(cls):
        return cls.object_minimal_size

    def collect(self, gen=0):
        self.debug_check_consistency()
        self.semispace_collect()
        # the indirection is required by the fact that collect() is referred
        # to by the gc transformer, and the default argument would crash
        # (this is also a hook for the HybridGC)

    def semispace_collect(self, size_changing=False):
        debug_start("gc-collect")
        debug_print()
        debug_print(".----------- Full collection ------------------")
        start_usage = self.free - self.tospace
        debug_print("| used before collection:          ",
                    start_usage, "bytes")
        #start_time = time.time()
        #llop.debug_print(lltype.Void, 'semispace_collect', int(size_changing))

        # Switch the spaces.  We copy everything over to the empty space
        # (self.fromspace at the beginning of the collection), and clear the old
        # one (self.tospace at the beginning).  Their purposes will be reversed
        # for the next collection.
        tospace = self.fromspace
        fromspace = self.tospace
        self.fromspace = fromspace
        self.tospace = tospace
        self.top_of_space = tospace + self.space_size
        scan = self.free = tospace
        self.starting_full_collect()
        self.collect_roots()
        self.copy_pending_finalizers(self.copy)
        scan = self.scan_copied(scan)
        if self.objects_with_light_finalizers.non_empty():
            self.deal_with_objects_with_light_finalizers()
        if self.objects_with_finalizers.non_empty():
            scan = self.deal_with_objects_with_finalizers(scan)
        if self.objects_with_weakrefs.non_empty():
            self.invalidate_weakrefs()
        self.update_objects_with_id()
        self.finished_full_collect()
        self.debug_check_consistency()
        if not size_changing:
            llarena.arena_reset(fromspace, self.space_size, True)
            self.record_red_zone()
            self.execute_finalizers()
        #llop.debug_print(lltype.Void, 'collected', self.space_size, size_changing, self.top_of_space - self.free)
        if have_debug_prints():
            #end_time = time.time()
            #elapsed_time = end_time - start_time
            #self.total_collection_time += elapsed_time
            self.total_collection_count += 1
            #total_program_time = end_time - self.program_start_time
            end_usage = self.free - self.tospace
            debug_print("| used after collection:           ",
                        end_usage, "bytes")
            debug_print("| freed:                           ",
                        start_usage - end_usage, "bytes")
            debug_print("| size of each semispace:          ",
                        self.space_size, "bytes")
            debug_print("| fraction of semispace now used:  ",
                        end_usage * 100.0 / self.space_size, "%")
            #ct = self.total_collection_time
            cc = self.total_collection_count
            debug_print("| number of semispace_collects:    ",
                        cc)
            #debug_print("|                         i.e.:    ",
            #            cc / total_program_time, "per second")
            #debug_print("| total time in semispace_collect: ",
            #            ct, "seconds")
            #debug_print("|                            i.e.: ",
            #            ct * 100.0 / total_program_time, "%")
            debug_print("`----------------------------------------------")
        debug_stop("gc-collect")

    def starting_full_collect(self):
        pass    # hook for the HybridGC

    def finished_full_collect(self):
        pass    # hook for the HybridGC

    def record_red_zone(self):
        # red zone: if the space is more than 80% full, the next collection
        # should double its size.  If it is more than 66% full twice in a row,
        # then it should double its size too.  (XXX adjust)
        # The goal is to avoid many repeated collection that don't free a lot
        # of memory each, if the size of the live object set is just below the
        # size of the space.
        free_after_collection = self.top_of_space - self.free
        if free_after_collection > self.space_size // 3:
            self.red_zone = 0
        else:
            self.red_zone += 1
            if free_after_collection < self.space_size // 5:
                self.red_zone += 1

    def get_size_incl_hash(self, obj):
        size = self.get_size(obj)
        hdr = self.header(obj)
        if (hdr.tid & GCFLAG_HASHMASK) == GC_HASH_HASFIELD:
            size += llmemory.sizeof(lltype.Signed)
        return size

    def scan_copied(self, scan):
        while scan < self.free:
            curr = scan + self.size_gc_header()
            self.trace_and_copy(curr)
            scan += self.size_gc_header() + self.get_size_incl_hash(curr)
        return scan

    def collect_roots(self):
        self.root_walker.walk_roots(
            SemiSpaceGC._collect_root,  # stack roots
            SemiSpaceGC._collect_root,  # static in prebuilt non-gc structures
            SemiSpaceGC._collect_root)  # static in prebuilt gc objects

    def _collect_root(self, root):
        root.address[0] = self.copy(root.address[0])

    def copy(self, obj):
        if self.DEBUG:
            self.debug_check_can_copy(obj)
        if self.is_forwarded(obj):
            #llop.debug_print(lltype.Void, obj, "already copied to", self.get_forwarding_address(obj))
            return self.get_forwarding_address(obj)
        else:
            objsize = self.get_size(obj)
            newobj = self.make_a_copy(obj, objsize)
            #llop.debug_print(lltype.Void, obj, "copied to", newobj,
            #                 "tid", self.header(obj).tid,
            #                 "size", totalsize)
            self.set_forwarding_address(obj, newobj, objsize)
            return newobj

    def _get_object_hash(self, obj, objsize, tid):
        # Returns the hash of the object, which must not be GC_HASH_NOTTAKEN.
        gc_hash = tid & GCFLAG_HASHMASK
        if gc_hash == GC_HASH_HASFIELD:
            obj = llarena.getfakearenaaddress(obj)
            return (obj + objsize).signed[0]
        elif gc_hash == GC_HASH_TAKEN_ADDR:
            return llmemory.cast_adr_to_int(obj)
        elif gc_hash == GC_HASH_TAKEN_NURS:
            return self._compute_current_nursery_hash(obj)
        else:
            assert 0, "gc_hash == GC_HASH_NOTTAKEN"

    def _make_a_copy_with_tid(self, obj, objsize, tid):
        totalsize = self.size_gc_header() + objsize
        newaddr = self.free
        llarena.arena_reserve(newaddr, totalsize)
        raw_memcopy(obj - self.size_gc_header(), newaddr, totalsize)
        if tid & GCFLAG_HASHMASK:
            hash = self._get_object_hash(obj, objsize, tid)
            llarena.arena_reserve(newaddr + totalsize,
                                  llmemory.sizeof(lltype.Signed))
            (newaddr + totalsize).signed[0] = hash
            tid |= GC_HASH_HASFIELD
            totalsize += llmemory.sizeof(lltype.Signed)
        self.free += totalsize
        newhdr = llmemory.cast_adr_to_ptr(newaddr, lltype.Ptr(self.HDR))
        newhdr.tid = tid
        newobj = newaddr + self.size_gc_header()
        return newobj

    def make_a_copy(self, obj, objsize):
        tid = self.header(obj).tid
        return self._make_a_copy_with_tid(obj, objsize, tid)

    def trace_and_copy(self, obj):
        self.trace(obj, self._trace_copy, None)

    def _trace_copy(self, pointer, ignored):
        pointer.address[0] = self.copy(pointer.address[0])

    def surviving(self, obj):
        # To use during a collection.  Check if the object is currently
        # marked as surviving the collection.  This is equivalent to
        # self.is_forwarded() for all objects except the nonmoving objects
        # created by the HybridGC subclass.  In all cases, if an object
        # survives, self.get_forwarding_address() returns its new address.
        return self.is_forwarded(obj)

    def is_forwarded(self, obj):
        return self.header(obj).tid & GCFLAG_FORWARDED != 0
        # note: all prebuilt objects also have this flag set

    def get_forwarding_address(self, obj):
        tid = self.header(obj).tid
        if tid & GCFLAG_EXTERNAL:
            self.visit_external_object(obj)
            return obj      # external or prebuilt objects are "forwarded"
                            # to themselves
        else:
            stub = llmemory.cast_adr_to_ptr(obj, self.FORWARDSTUBPTR)
            return stub.forw

    def visit_external_object(self, obj):
        pass    # hook for the HybridGC

    def get_possibly_forwarded_type_id(self, obj):
        tid = self.header(obj).tid
        if self.is_forwarded(obj) and not (tid & GCFLAG_EXTERNAL):
            obj = self.get_forwarding_address(obj)
        return self.get_type_id(obj)

    def set_forwarding_address(self, obj, newobj, objsize):
        # To mark an object as forwarded, we set the GCFLAG_FORWARDED and
        # overwrite the object with a FORWARDSTUB.  Doing so is a bit
        # long-winded on llarena, but it all melts down to two memory
        # writes after translation to C.
        size_gc_header = self.size_gc_header()
        stubsize = llmemory.sizeof(self.FORWARDSTUB)
        tid = self.header(obj).tid
        ll_assert(tid & GCFLAG_EXTERNAL == 0,  "unexpected GCFLAG_EXTERNAL")
        ll_assert(tid & GCFLAG_FORWARDED == 0, "unexpected GCFLAG_FORWARDED")
        # replace the object at 'obj' with a FORWARDSTUB.
        hdraddr = obj - size_gc_header
        llarena.arena_reset(hdraddr, size_gc_header + objsize, False)
        llarena.arena_reserve(hdraddr, size_gc_header + stubsize)
        hdr = llmemory.cast_adr_to_ptr(hdraddr, lltype.Ptr(self.HDR))
        hdr.tid = tid | GCFLAG_FORWARDED
        stub = llmemory.cast_adr_to_ptr(obj, self.FORWARDSTUBPTR)
        stub.forw = newobj

    def combine(self, typeid16, flags):
        return llop.combine_ushort(lltype.Signed, typeid16, flags)

    def get_type_id(self, addr):
        tid = self.header(addr).tid
        ll_assert(tid & (GCFLAG_FORWARDED|GCFLAG_EXTERNAL) != GCFLAG_FORWARDED,
                  "get_type_id on forwarded obj")
        # Non-prebuilt forwarded objects are overwritten with a FORWARDSTUB.
        # Although calling get_type_id() on a forwarded object works by itself,
        # we catch it as an error because it's likely that what is then
        # done with the typeid is bogus.
        return llop.extract_ushort(llgroup.HALFWORD, tid)

    def init_gc_object(self, addr, typeid16, flags=0):
        hdr = llmemory.cast_adr_to_ptr(addr, lltype.Ptr(self.HDR))
        hdr.tid = self.combine(typeid16, flags)

    def init_gc_object_immortal(self, addr, typeid16, flags=0):
        hdr = llmemory.cast_adr_to_ptr(addr, lltype.Ptr(self.HDR))
        flags |= GCFLAG_EXTERNAL | GCFLAG_FORWARDED | GC_HASH_TAKEN_ADDR
        hdr.tid = self.combine(typeid16, flags)
        # immortal objects always have GCFLAG_FORWARDED set;
        # see get_forwarding_address().

    def deal_with_objects_with_light_finalizers(self):
        """ This is a much simpler version of dealing with finalizers
        and an optimization - we can reasonably assume that those finalizers
        don't do anything fancy and *just* call them. Among other things
        they won't resurrect objects
        """
        new_objects = self.AddressStack()
        while self.objects_with_light_finalizers.non_empty():
            obj = self.objects_with_light_finalizers.pop()
            if self.surviving(obj):
                new_objects.append(self.get_forwarding_address(obj))
            else:
                self.call_destructor(obj)
        self.objects_with_light_finalizers.delete()
        self.objects_with_light_finalizers = new_objects

    def deal_with_objects_with_finalizers(self, scan):
        # walk over list of objects with finalizers
        # if it is not copied, add it to the list of to-be-called finalizers
        # and copy it, to me make the finalizer runnable
        # We try to run the finalizers in a "reasonable" order, like
        # CPython does.  The details of this algorithm are in
        # pypy/doc/discussion/finalizer-order.txt.
        new_with_finalizer = self.AddressDeque()
        marked = self.AddressDeque()
        pending = self.AddressStack()
        self.tmpstack = self.AddressStack()
        while self.objects_with_finalizers.non_empty():
            x = self.objects_with_finalizers.popleft()
            fq_nr = self.objects_with_finalizers.popleft()
            ll_assert(self._finalization_state(x) != 1, 
                      "bad finalization state 1")
            if self.surviving(x):
                new_with_finalizer.append(self.get_forwarding_address(x))
                new_with_finalizer.append(fq_nr)
                continue
            marked.append(x)
            marked.append(fq_nr)
            pending.append(x)
            while pending.non_empty():
                y = pending.pop()
                state = self._finalization_state(y)
                if state == 0:
                    self._bump_finalization_state_from_0_to_1(y)
                    self.trace(y, self._append_if_nonnull, pending)
                elif state == 2:
                    self._recursively_bump_finalization_state_from_2_to_3(y)
            scan = self._recursively_bump_finalization_state_from_1_to_2(
                       x, scan)

        while marked.non_empty():
            x = marked.popleft()
            fq_nr = marked.popleft()
            state = self._finalization_state(x)
            ll_assert(state >= 2, "unexpected finalization state < 2")
            newx = self.get_forwarding_address(x)
            if state == 2:
                from rpython.rtyper.lltypesystem import rffi
                fq_index = rffi.cast(lltype.Signed, fq_nr)
                self.mark_finalizer_to_run(fq_index, newx)
                # we must also fix the state from 2 to 3 here, otherwise
                # we leave the GCFLAG_FINALIZATION_ORDERING bit behind
                # which will confuse the next collection
                self._recursively_bump_finalization_state_from_2_to_3(x)
            else:
                new_with_finalizer.append(newx)
                new_with_finalizer.append(fq_nr)

        self.tmpstack.delete()
        pending.delete()
        marked.delete()
        self.objects_with_finalizers.delete()
        self.objects_with_finalizers = new_with_finalizer
        return scan

    def _append_if_nonnull(pointer, stack):
        stack.append(pointer.address[0])
    _append_if_nonnull = staticmethod(_append_if_nonnull)

    def _finalization_state(self, obj):
        if self.surviving(obj):
            newobj = self.get_forwarding_address(obj)
            hdr = self.header(newobj)
            if hdr.tid & GCFLAG_FINALIZATION_ORDERING:
                return 2
            else:
                return 3
        else:
            hdr = self.header(obj)
            if hdr.tid & GCFLAG_FINALIZATION_ORDERING:
                return 1
            else:
                return 0

    def _bump_finalization_state_from_0_to_1(self, obj):
        ll_assert(self._finalization_state(obj) == 0,
                  "unexpected finalization state != 0")
        hdr = self.header(obj)
        hdr.tid |= GCFLAG_FINALIZATION_ORDERING

    def _recursively_bump_finalization_state_from_2_to_3(self, obj):
        ll_assert(self._finalization_state(obj) == 2,
                  "unexpected finalization state != 2")
        newobj = self.get_forwarding_address(obj)
        pending = self.tmpstack
        ll_assert(not pending.non_empty(), "tmpstack not empty")
        pending.append(newobj)
        while pending.non_empty():
            y = pending.pop()
            hdr = self.header(y)
            if hdr.tid & GCFLAG_FINALIZATION_ORDERING:     # state 2 ?
                hdr.tid &= ~GCFLAG_FINALIZATION_ORDERING   # change to state 3
                self.trace(y, self._append_if_nonnull, pending)

    def _recursively_bump_finalization_state_from_1_to_2(self, obj, scan):
        # recursively convert objects from state 1 to state 2.
        # Note that copy() copies all bits, including the
        # GCFLAG_FINALIZATION_ORDERING.  The mapping between
        # state numbers and the presence of this bit was designed
        # for the following to work :-)
        self.copy(obj)
        return self.scan_copied(scan)

    def invalidate_weakrefs(self):
        # walk over list of objects that contain weakrefs
        # if the object it references survives then update the weakref
        # otherwise invalidate the weakref
        new_with_weakref = self.AddressStack()
        while self.objects_with_weakrefs.non_empty():
            obj = self.objects_with_weakrefs.pop()
            if not self.surviving(obj):
                continue # weakref itself dies
            obj = self.get_forwarding_address(obj)
            offset = self.weakpointer_offset(self.get_type_id(obj))
            pointing_to = (obj + offset).address[0]
            # XXX I think that pointing_to cannot be NULL here
            if pointing_to:
                if self.surviving(pointing_to):
                    (obj + offset).address[0] = self.get_forwarding_address(
                        pointing_to)
                    new_with_weakref.append(obj)
                else:
                    (obj + offset).address[0] = NULL
        self.objects_with_weakrefs.delete()
        self.objects_with_weakrefs = new_with_weakref

    def _is_external(self, obj):
        return (self.header(obj).tid & GCFLAG_EXTERNAL) != 0

    def _is_in_the_space(self, obj):
        return self.tospace <= obj < self.free

    def debug_check_object(self, obj):
        """Check the invariants about 'obj' that should be true
        between collections."""
        tid = self.header(obj).tid
        if tid & GCFLAG_EXTERNAL:
            ll_assert(tid & GCFLAG_FORWARDED != 0, "bug: external+!forwarded")
            ll_assert(not (self.tospace <= obj < self.free),
                      "external flag but object inside the semispaces")
        else:
            ll_assert(not (tid & GCFLAG_FORWARDED), "bug: !external+forwarded")
            ll_assert(self.tospace <= obj < self.free,
                      "!external flag but object outside the semispaces")
        ll_assert(not (tid & GCFLAG_FINALIZATION_ORDERING),
                  "unexpected GCFLAG_FINALIZATION_ORDERING")

    def debug_check_can_copy(self, obj):
        ll_assert(not (self.tospace <= obj < self.free),
                  "copy() on already-copied object")

    STATISTICS_NUMBERS = 0

    def is_in_nursery(self, addr):
        # overridden in generation.py.
        return False

    def _compute_current_nursery_hash(self, obj):
        # overridden in generation.py.
        raise AssertionError("should not be called")

    def identityhash(self, gcobj):
        # The following loop should run at most twice.
        while 1:
            obj = llmemory.cast_ptr_to_adr(gcobj)
            hdr = self.header(obj)
            if hdr.tid & GCFLAG_HASHMASK:
                break
            # It's the first time we ask for a hash, and it's not an
            # external object.  Shrink the top of space by the extra
            # hash word that will be needed after a collect.
            shrunk_top = self.top_of_space - llmemory.sizeof(lltype.Signed)
            if shrunk_top < self.free:
                # Cannot shrink!  Do a collection, asking for at least
                # one word of free space, and try again.  May raise
                # MemoryError.  Obscure: not called directly, but
                # across an llop, to make sure that there is the
                # correct push_roots/pop_roots around the call...
                llop.gc_obtain_free_space(llmemory.Address,
                                          llmemory.sizeof(lltype.Signed))
                continue
            else:
                # Now we can have side-effects: lower the top of space
                # and set one of the GC_HASH_TAKEN_xxx flags.
                self.top_of_space = shrunk_top
                if self.is_in_nursery(obj):
                    hdr.tid |= GC_HASH_TAKEN_NURS
                else:
                    hdr.tid |= GC_HASH_TAKEN_ADDR
                break
        # Now we can return the result
        objsize = self.get_size(obj)
        return self._get_object_hash(obj, objsize, hdr.tid)

    def track_heap_parent(self, obj, parent):
        addr = obj.address[0]
        parent_idx = llop.get_member_index(lltype.Signed,
                                           self.get_type_id(parent))
        idx = llop.get_member_index(lltype.Signed, self.get_type_id(addr))
        self._ll_typeid_map[parent_idx].links[idx] += 1
        self.track_heap(addr)

    def track_heap(self, adr):
        if self._tracked_dict.contains(adr):
            return
        self._tracked_dict.add(adr)
        idx = llop.get_member_index(lltype.Signed, self.get_type_id(adr))
        self._ll_typeid_map[idx].count += 1
        totsize = self.get_size(adr) + self.size_gc_header()
        self._ll_typeid_map[idx].size += llmemory.raw_malloc_usage(totsize)
        self.trace(adr, self.track_heap_parent, adr)

    @staticmethod
    def _track_heap_root(obj, self):
        self.track_heap(obj)

    def heap_stats(self):
        self._tracked_dict = self.AddressDict()
        max_tid = self.root_walker.gcdata.max_type_id
        ll_typeid_map = lltype.malloc(ARRAY_TYPEID_MAP, max_tid, zero=True)
        for i in range(max_tid):
            ll_typeid_map[i] = lltype.malloc(TYPEID_MAP, max_tid, zero=True)
        self._ll_typeid_map = ll_typeid_map
        self._tracked_dict.add(llmemory.cast_ptr_to_adr(ll_typeid_map))
        i = 0
        while i < max_tid:
            self._tracked_dict.add(llmemory.cast_ptr_to_adr(ll_typeid_map[i]))
            i += 1
        self.enumerate_all_roots(SemiSpaceGC._track_heap_root, self)
        self._ll_typeid_map = lltype.nullptr(ARRAY_TYPEID_MAP)
        self._tracked_dict.delete()
        return ll_typeid_map
