import sys
from rpython.memory.gc.semispace import SemiSpaceGC
from rpython.memory.gc.semispace import GCFLAG_EXTERNAL, GCFLAG_FORWARDED
from rpython.memory.gc.semispace import GC_HASH_TAKEN_ADDR
from rpython.memory.gc import env
from rpython.rtyper.lltypesystem.llmemory import NULL, raw_malloc_usage
from rpython.rtyper.lltypesystem import lltype, llmemory, llarena
from rpython.rlib.objectmodel import free_non_gc_object
from rpython.rlib.debug import ll_assert
from rpython.rlib.debug import debug_print, debug_start, debug_stop
from rpython.rlib.rarithmetic import intmask, LONG_BIT
from rpython.rtyper.lltypesystem.lloperation import llop

WORD = LONG_BIT // 8

# The following flag is never set on young objects, i.e. the ones living
# in the nursery.  It is initially set on all prebuilt and old objects,
# and gets cleared by the write_barrier() when we write in them a
# pointer to a young object.
GCFLAG_NO_YOUNG_PTRS = SemiSpaceGC.first_unused_gcflag << 0

# The following flag is set on some last-generation objects (== prebuilt
# objects for GenerationGC, but see also HybridGC).  The flag is set
# unless the object is already listed in 'last_generation_root_objects'.
# When a pointer is written inside an object with GCFLAG_NO_HEAP_PTRS
# set, the write_barrier clears the flag and adds the object to
# 'last_generation_root_objects'.
GCFLAG_NO_HEAP_PTRS = SemiSpaceGC.first_unused_gcflag << 1

class GenerationGC(SemiSpaceGC):
    """A basic generational GC: it's a SemiSpaceGC with an additional
    nursery for young objects.  A write barrier is used to ensure that
    old objects that contain pointers to young objects are recorded in
    a list.
    """
    inline_simple_malloc = True
    inline_simple_malloc_varsize = True
    needs_write_barrier = True
    prebuilt_gc_objects_are_static_roots = False
    first_unused_gcflag = SemiSpaceGC.first_unused_gcflag << 2

    # the following values override the default arguments of __init__ when
    # translating to a real backend.
    TRANSLATION_PARAMS = {'space_size': 8*1024*1024,     # 8 MB
                          'nursery_size': 3*1024*1024,   # 3 MB
                          'min_nursery_size': 48*1024,
                          'auto_nursery_size': True}

    nursery_hash_base = -1

    def __init__(self, config,
                 nursery_size=32*WORD,
                 min_nursery_size=32*WORD,
                 auto_nursery_size=False,
                 space_size=1024*WORD,
                 max_space_size=sys.maxint//2+1,
                 **kwds):
        SemiSpaceGC.__init__(self, config,
                             space_size = space_size,
                             max_space_size = max_space_size,
                             **kwds)
        assert min_nursery_size <= nursery_size <= space_size // 2
        self.initial_nursery_size = nursery_size
        self.auto_nursery_size = auto_nursery_size
        self.min_nursery_size = min_nursery_size

        # define nursery fields
        self.reset_nursery()
        self._setup_wb()

        # compute the constant lower bounds for the attributes
        # largest_young_fixedsize and largest_young_var_basesize.
        # It is expected that most (or all) objects have a fixedsize
        # that is much lower anyway.
        sz = self.get_young_fixedsize(self.min_nursery_size)
        self.lb_young_fixedsize = sz
        sz = self.get_young_var_basesize(self.min_nursery_size)
        self.lb_young_var_basesize = sz

    def setup(self):
        self.old_objects_pointing_to_young = self.AddressStack()
        # ^^^ a list of addresses inside the old objects space; it
        # may contain static prebuilt objects as well.  More precisely,
        # it lists exactly the old and static objects whose
        # GCFLAG_NO_YOUNG_PTRS bit is not set.
        self.young_objects_with_weakrefs = self.AddressStack()

        self.last_generation_root_objects = self.AddressStack()
        self.young_objects_with_id = self.AddressDict()
        SemiSpaceGC.setup(self)
        self.set_nursery_size(self.initial_nursery_size)
        # the GC is fully setup now.  The rest can make use of it.
        if self.auto_nursery_size:
            newsize = nursery_size_from_env()
            #if newsize <= 0:
            #    ---disabled--- just use the default value.
            #    newsize = env.estimate_best_nursery_size()
            if newsize > 0:
                self.set_nursery_size(newsize)

        self.reset_nursery()

    def _teardown(self):
        self.collect() # should restore last gen objects flags
        SemiSpaceGC._teardown(self)

    def reset_nursery(self):
        self.nursery      = NULL
        self.nursery_top  = NULL
        self.nursery_free = NULL

    def set_nursery_size(self, newsize):
        debug_start("gc-set-nursery-size")
        if newsize < self.min_nursery_size:
            newsize = self.min_nursery_size
        if newsize > self.space_size // 2:
            newsize = self.space_size // 2

        # Compute the new bounds for how large young objects can be
        # (larger objects are allocated directly old).   XXX adjust
        self.nursery_size = newsize
        self.largest_young_fixedsize = self.get_young_fixedsize(newsize)
        self.largest_young_var_basesize = self.get_young_var_basesize(newsize)
        scale = 0
        while (self.min_nursery_size << (scale+1)) <= newsize:
            scale += 1
        self.nursery_scale = scale
        debug_print("nursery_size =", newsize)
        debug_print("largest_young_fixedsize =",
                    self.largest_young_fixedsize)
        debug_print("largest_young_var_basesize =",
                    self.largest_young_var_basesize)
        debug_print("nursery_scale =", scale)
        # we get the following invariant:
        assert self.nursery_size >= (self.min_nursery_size << scale)

        # Force a full collect to remove the current nursery whose size
        # no longer matches the bounds that we just computed.  This must
        # be done after changing the bounds, because it might re-create
        # a new nursery (e.g. if it invokes finalizers).
        self.semispace_collect()
        debug_stop("gc-set-nursery-size")

    @staticmethod
    def get_young_fixedsize(nursery_size):
        return nursery_size // 2 - 1

    @staticmethod
    def get_young_var_basesize(nursery_size):
        return nursery_size // 4 - 1

    @classmethod
    def JIT_max_size_of_young_obj(cls):
        min_nurs_size = cls.TRANSLATION_PARAMS['min_nursery_size']
        return cls.get_young_fixedsize(min_nurs_size)

    def is_in_nursery(self, addr):
        ll_assert(llmemory.cast_adr_to_int(addr) & 1 == 0,
                  "odd-valued (i.e. tagged) pointer unexpected here")
        return self.nursery <= addr < self.nursery_top

    def appears_to_be_in_nursery(self, addr):
        # same as is_in_nursery(), but may return True accidentally if
        # 'addr' is a tagged pointer with just the wrong value.
        if not self.translated_to_c:
            if not self.is_valid_gc_object(addr):
                return False
        return self.nursery <= addr < self.nursery_top

    def malloc_fixedsize_clear(self, typeid, size,
                               has_finalizer=False,
                               is_finalizer_light=False,
                               contains_weakptr=False):
        if (has_finalizer or
            (raw_malloc_usage(size) > self.lb_young_fixedsize and
             raw_malloc_usage(size) > self.largest_young_fixedsize)):
            # ^^^ we do two size comparisons; the first one appears redundant,
            #     but it can be constant-folded if 'size' is a constant; then
            #     it almost always folds down to False, which kills the
            #     second comparison as well.
            ll_assert(not contains_weakptr, "wrong case for mallocing weakref")
            # "non-simple" case or object too big: don't use the nursery
            return SemiSpaceGC.malloc_fixedsize_clear(self, typeid, size,
                                                      has_finalizer,
                                                      is_finalizer_light,
                                                      contains_weakptr)
        size_gc_header = self.gcheaderbuilder.size_gc_header
        totalsize = size_gc_header + size
        result = self.nursery_free
        if raw_malloc_usage(totalsize) > self.nursery_top - result:
            result = self.collect_nursery()
        llarena.arena_reserve(result, totalsize)
        # GCFLAG_NO_YOUNG_PTRS is never set on young objs
        self.init_gc_object(result, typeid, flags=0)
        self.nursery_free = result + totalsize
        if contains_weakptr:
            self.young_objects_with_weakrefs.append(result + size_gc_header)
        return llmemory.cast_adr_to_ptr(result+size_gc_header, llmemory.GCREF)

    def malloc_varsize_clear(self, typeid, length, size, itemsize,
                             offset_to_length):
        # Only use the nursery if there are not too many items.
        if not raw_malloc_usage(itemsize):
            too_many_items = False
        else:
            # The following line is usually constant-folded because both
            # min_nursery_size and itemsize are constants (the latter
            # due to inlining).
            maxlength_for_minimal_nursery = (self.min_nursery_size // 4 //
                                             raw_malloc_usage(itemsize))
            
            # The actual maximum length for our nursery depends on how
            # many times our nursery is bigger than the minimal size.
            # The computation is done in this roundabout way so that
            # only the only remaining computation is the following
            # shift.
            maxlength = maxlength_for_minimal_nursery << self.nursery_scale
            too_many_items = length > maxlength

        if (too_many_items or
            (raw_malloc_usage(size) > self.lb_young_var_basesize and
             raw_malloc_usage(size) > self.largest_young_var_basesize)):
            # ^^^ we do two size comparisons; the first one appears redundant,
            #     but it can be constant-folded if 'size' is a constant; then
            #     it almost always folds down to False, which kills the
            #     second comparison as well.
            return SemiSpaceGC.malloc_varsize_clear(self, typeid, length, size,
                                                    itemsize, offset_to_length)
        # with the above checks we know now that totalsize cannot be more
        # than about half of the nursery size; in particular, the + and *
        # cannot overflow
        size_gc_header = self.gcheaderbuilder.size_gc_header
        totalsize = size_gc_header + size + itemsize * length
        result = self.nursery_free
        if raw_malloc_usage(totalsize) > self.nursery_top - result:
            result = self.collect_nursery()
        llarena.arena_reserve(result, totalsize)
        # GCFLAG_NO_YOUNG_PTRS is never set on young objs
        self.init_gc_object(result, typeid, flags=0)
        (result + size_gc_header + offset_to_length).signed[0] = length
        self.nursery_free = result + llarena.round_up_for_allocation(totalsize)
        return llmemory.cast_adr_to_ptr(result+size_gc_header, llmemory.GCREF)

    # override the init_gc_object methods to change the default value of 'flags',
    # used by objects that are directly created outside the nursery by the SemiSpaceGC.
    # These objects must have the GCFLAG_NO_YOUNG_PTRS flag set immediately.
    def init_gc_object(self, addr, typeid, flags=GCFLAG_NO_YOUNG_PTRS):
        SemiSpaceGC.init_gc_object(self, addr, typeid, flags)

    def init_gc_object_immortal(self, addr, typeid,
                                flags=GCFLAG_NO_YOUNG_PTRS|GCFLAG_NO_HEAP_PTRS):
        SemiSpaceGC.init_gc_object_immortal(self, addr, typeid, flags)

    # flags exposed for the HybridGC subclass
    GCFLAGS_FOR_NEW_YOUNG_OBJECTS = 0   # NO_YOUNG_PTRS never set on young objs
    GCFLAGS_FOR_NEW_EXTERNAL_OBJECTS = (GCFLAG_EXTERNAL | GCFLAG_FORWARDED |
                                        GCFLAG_NO_YOUNG_PTRS |
                                        GC_HASH_TAKEN_ADDR)

    # ____________________________________________________________
    # Support code for full collections

    def collect(self, gen=1):
        if gen == 0:
            self.collect_nursery()
        else:
            SemiSpaceGC.collect(self)

    def semispace_collect(self, size_changing=False):
        self.reset_young_gcflags() # we are doing a full collection anyway
        self.weakrefs_grow_older()
        self.ids_grow_older()
        self.reset_nursery()
        SemiSpaceGC.semispace_collect(self, size_changing)

    def make_a_copy(self, obj, objsize):
        tid = self.header(obj).tid
        # During a full collect, all copied objects might implicitly come
        # from the nursery.  In case they do, we must add this flag:
        tid |= GCFLAG_NO_YOUNG_PTRS
        return self._make_a_copy_with_tid(obj, objsize, tid)
        # history: this was missing and caused an object to become old but without the
        # flag set.  Such an object is bogus in the sense that the write_barrier doesn't
        # work on it.  So it can eventually contain a ptr to a young object but we didn't
        # know about it.  That ptr was not updated in the next minor collect... boom at
        # the next usage.

    def reset_young_gcflags(self):
        # This empties self.old_objects_pointing_to_young, and puts the
        # GCFLAG_NO_YOUNG_PTRS back on all these objects.  We could put
        # the flag back more lazily but we expect this list to be short
        # anyway, and it's much saner to stick to the invariant:
        # non-young objects all have GCFLAG_NO_YOUNG_PTRS set unless
        # they are listed in old_objects_pointing_to_young.
        oldlist = self.old_objects_pointing_to_young
        while oldlist.non_empty():
            obj = oldlist.pop()
            hdr = self.header(obj)
            hdr.tid |= GCFLAG_NO_YOUNG_PTRS

    def weakrefs_grow_older(self):
        while self.young_objects_with_weakrefs.non_empty():
            obj = self.young_objects_with_weakrefs.pop()
            self.objects_with_weakrefs.append(obj)

    def collect_roots(self):
        """GenerationGC: collects all roots.
           HybridGC: collects all roots, excluding the generation 3 ones.
        """
        # Warning!  References from static (and possibly gen3) objects
        # are found by collect_last_generation_roots(), which must be
        # called *first*!  If it is called after walk_roots(), then the
        # HybridGC explodes if one of the _collect_root causes an object
        # to be added to self.last_generation_root_objects.  Indeed, in
        # this case, the newly added object is traced twice: once by
        # collect_last_generation_roots() and once because it was added
        # in self.rawmalloced_objects_to_trace.
        self.collect_last_generation_roots()
        self.root_walker.walk_roots(
            SemiSpaceGC._collect_root,  # stack roots
            SemiSpaceGC._collect_root,  # static in prebuilt non-gc structures
            None)   # we don't need the static in prebuilt gc objects

    def collect_last_generation_roots(self):
        stack = self.last_generation_root_objects
        self.last_generation_root_objects = self.AddressStack()
        while stack.non_empty():
            obj = stack.pop()
            self.header(obj).tid |= GCFLAG_NO_HEAP_PTRS
            # ^^^ the flag we just added will be removed immediately if
            # the object still contains pointers to younger objects
            self.trace(obj, self._trace_external_obj, obj)
        stack.delete()

    def _trace_external_obj(self, pointer, obj):
        addr = pointer.address[0]
        newaddr = self.copy(addr)
        pointer.address[0] = newaddr
        self.write_into_last_generation_obj(obj)

    # ____________________________________________________________
    # Implementation of nursery-only collections

    def collect_nursery(self):
        if self.nursery_size > self.top_of_space - self.free:
            # the semispace is running out, do a full collect
            self.obtain_free_space(self.nursery_size)
            ll_assert(self.nursery_size <= self.top_of_space - self.free,
                         "obtain_free_space failed to do its job")
        if self.nursery:
            debug_start("gc-minor")
            debug_print("--- minor collect ---")
            debug_print("nursery:", self.nursery, "to", self.nursery_top)
            # a nursery-only collection
            scan = beginning = self.free
            self.collect_oldrefs_to_nursery()
            self.collect_roots_in_nursery()
            self.collect_young_objects_with_finalizers()
            scan = self.scan_objects_just_copied_out_of_nursery(scan)
            # at this point, all static and old objects have got their
            # GCFLAG_NO_YOUNG_PTRS set again by trace_and_drag_out_of_nursery
            if self.young_objects_with_weakrefs.non_empty():
                self.invalidate_young_weakrefs()
            if self.young_objects_with_id.length() > 0:
                self.update_young_objects_with_id()
            # mark the nursery as free and fill it with zeroes again
            llarena.arena_reset(self.nursery, self.nursery_size, 2)
            debug_print("survived (fraction of the size):",
                        float(scan - beginning) / self.nursery_size)
            debug_stop("gc-minor")
            #self.debug_check_consistency()   # -- quite expensive
        else:
            # no nursery - this occurs after a full collect, triggered either
            # just above or by some previous non-nursery-based allocation.
            # Grab a piece of the current space for the nursery.
            self.nursery = self.free
            self.nursery_top = self.nursery + self.nursery_size
            self.free = self.nursery_top
        self.nursery_free = self.nursery
        # at this point we know that the nursery is empty
        self.change_nursery_hash_base()
        return self.nursery_free

    def change_nursery_hash_base(self):
        # The following should be enough to ensure that young objects
        # tend to always get a different hash.  It also makes sure that
        # nursery_hash_base is not a multiple of 4, to avoid collisions
        # with the hash of non-young objects.
        hash_base = self.nursery_hash_base
        hash_base += self.nursery_size - 1
        if (hash_base & 3) == 0:
            hash_base -= 1
        self.nursery_hash_base = intmask(hash_base)

    # NB. we can use self.copy() to move objects out of the nursery,
    # but only if the object was really in the nursery.

    def collect_oldrefs_to_nursery(self):
        # Follow the old_objects_pointing_to_young list and move the
        # young objects they point to out of the nursery.
        count = 0
        oldlist = self.old_objects_pointing_to_young
        while oldlist.non_empty():
            count += 1
            obj = oldlist.pop()
            hdr = self.header(obj)
            hdr.tid |= GCFLAG_NO_YOUNG_PTRS
            self.trace_and_drag_out_of_nursery(obj)
        debug_print("collect_oldrefs_to_nursery", count)

    def collect_roots_in_nursery(self):
        # we don't need to trace prebuilt GcStructs during a minor collect:
        # if a prebuilt GcStruct contains a pointer to a young object,
        # then the write_barrier must have ensured that the prebuilt
        # GcStruct is in the list self.old_objects_pointing_to_young.
        self.root_walker.walk_roots(
            GenerationGC._collect_root_in_nursery,  # stack roots
            GenerationGC._collect_root_in_nursery,  # static in prebuilt non-gc
            None)                                   # static in prebuilt gc

    def _collect_root_in_nursery(self, root):
        obj = root.address[0]
        if self.is_in_nursery(obj):
            root.address[0] = self.copy(obj)

    def collect_young_objects_with_finalizers(self):
        # XXX always walk the whole 'objects_with_finalizers' list here
        new = self.AddressDeque()
        while self.objects_with_finalizers.non_empty():
            obj = self.objects_with_finalizers.popleft()
            fq_nr = self.objects_with_finalizers.popleft()
            if self.is_in_nursery(obj):
                obj = self.copy(obj)
            new.append(obj)
            new.append(fq_nr)
        self.objects_with_finalizers.delete()
        self.objects_with_finalizers = new

    def scan_objects_just_copied_out_of_nursery(self, scan):
        while scan < self.free:
            curr = scan + self.size_gc_header()
            self.trace_and_drag_out_of_nursery(curr)
            scan += self.size_gc_header() + self.get_size_incl_hash(curr)
        return scan

    def trace_and_drag_out_of_nursery(self, obj):
        """obj must not be in the nursery.  This copies all the
        young objects it references out of the nursery.
        """
        self.trace(obj, self._trace_drag_out, None)

    def _trace_drag_out(self, pointer, ignored):
        if self.is_in_nursery(pointer.address[0]):
            pointer.address[0] = self.copy(pointer.address[0])

    # The code relies on the fact that no weakref can be an old object
    # weakly pointing to a young object.  Indeed, weakrefs are immutable
    # so they cannot point to an object that was created after it.
    def invalidate_young_weakrefs(self):
        # walk over the list of objects that contain weakrefs and are in the
        # nursery.  if the object it references survives then update the
        # weakref; otherwise invalidate the weakref
        while self.young_objects_with_weakrefs.non_empty():
            obj = self.young_objects_with_weakrefs.pop()
            if not self.surviving(obj):
                continue # weakref itself dies
            obj = self.get_forwarding_address(obj)
            offset = self.weakpointer_offset(self.get_type_id(obj))
            pointing_to = (obj + offset).address[0]
            if self.is_in_nursery(pointing_to):
                if self.surviving(pointing_to):
                    (obj + offset).address[0] = self.get_forwarding_address(
                        pointing_to)
                else:
                    (obj + offset).address[0] = NULL
                    continue    # no need to remember this weakref any longer
            self.objects_with_weakrefs.append(obj)

    # for the JIT: a minimal description of the write_barrier() method
    # (the JIT assumes it is of the shape
    #  "if addr_struct.int0 & JIT_WB_IF_FLAG: remember_young_pointer()")
    JIT_WB_IF_FLAG = GCFLAG_NO_YOUNG_PTRS

    def write_barrier(self, addr_struct):
        if self.header(addr_struct).tid & GCFLAG_NO_YOUNG_PTRS:
            self.remember_young_pointer(addr_struct)

    def _setup_wb(self):
        DEBUG = self.DEBUG
        # The purpose of attaching remember_young_pointer to the instance
        # instead of keeping it as a regular method is to help the JIT call it.
        # Additionally, it makes the code in write_barrier() marginally smaller
        # (which is important because it is inlined *everywhere*).
        # For x86, there is also an extra requirement: when the JIT calls
        # remember_young_pointer(), it assumes that it will not touch the SSE
        # registers, so it does not save and restore them (that's a *hack*!).
        def remember_young_pointer(addr_struct):
            #llop.debug_print(lltype.Void, "\tremember_young_pointer",
            #                 addr_struct)
            if DEBUG:
                ll_assert(not self.is_in_nursery(addr_struct),
                          "nursery object with GCFLAG_NO_YOUNG_PTRS")
            #
            # What is important in this function is that it *must*
            # clear the flag GCFLAG_NO_YOUNG_PTRS from 'addr_struct'
            # if the newly written value is in the nursery.  It is ok
            # if it also clears the flag in some more cases --- it is
            # a win to not actually pass the 'newvalue' pointer here.
            self.old_objects_pointing_to_young.append(addr_struct)
            self.header(addr_struct).tid &= ~GCFLAG_NO_YOUNG_PTRS
            self.write_into_last_generation_obj(addr_struct)
        remember_young_pointer._dont_inline_ = True
        self.remember_young_pointer = remember_young_pointer

    def write_into_last_generation_obj(self, addr_struct):
        objhdr = self.header(addr_struct)
        if objhdr.tid & GCFLAG_NO_HEAP_PTRS:
            objhdr.tid &= ~GCFLAG_NO_HEAP_PTRS
            self.last_generation_root_objects.append(addr_struct)
    write_into_last_generation_obj._always_inline_ = True

    def writebarrier_before_copy(self, source_addr, dest_addr,
                                 source_start, dest_start, length):
        """ This has the same effect as calling writebarrier over
        each element in dest copied from source, except it might reset
        one of the following flags a bit too eagerly, which means we'll have
        a bit more objects to track, but being on the safe side.
        """
        source_hdr = self.header(source_addr)
        dest_hdr = self.header(dest_addr)
        if dest_hdr.tid & GCFLAG_NO_YOUNG_PTRS == 0:
            return True
        # ^^^ a fast path of write-barrier
        if source_hdr.tid & GCFLAG_NO_YOUNG_PTRS == 0:
            # there might be an object in source that is in nursery
            self.old_objects_pointing_to_young.append(dest_addr)
            dest_hdr.tid &= ~GCFLAG_NO_YOUNG_PTRS
        if dest_hdr.tid & GCFLAG_NO_HEAP_PTRS:
            if source_hdr.tid & GCFLAG_NO_HEAP_PTRS == 0:
                # ^^^ equivalend of addr from source not being in last
                #     gen
                dest_hdr.tid &= ~GCFLAG_NO_HEAP_PTRS
                self.last_generation_root_objects.append(dest_addr)
        return True

    def writebarrier_before_move(self, array_addr):
        pass      # nothing to do

    def is_last_generation(self, obj):
        # overridden by HybridGC
        return (self.header(obj).tid & GCFLAG_EXTERNAL) != 0

    def _compute_id(self, obj):
        if self.is_in_nursery(obj):
            result = self.young_objects_with_id.get(obj)
            if not result:
                result = self._next_id()
                self.young_objects_with_id.setitem(obj, result)
            return result
        else:
            return SemiSpaceGC._compute_id(self, obj)

    def update_young_objects_with_id(self):
        self.young_objects_with_id.foreach(self._update_object_id,
                                           self.objects_with_id)
        self.young_objects_with_id.clear()
        # NB. the clear() also makes the dictionary shrink back to its
        # minimal size, which is actually a good idea: a large, mostly-empty
        # table is bad for the next call to 'foreach'.

    def ids_grow_older(self):
        self.young_objects_with_id.foreach(self._id_grow_older, None)
        self.young_objects_with_id.clear()

    def _id_grow_older(self, obj, id, ignored):
        self.objects_with_id.setitem(obj, id)

    def _compute_current_nursery_hash(self, obj):
        return intmask(llmemory.cast_adr_to_int(obj) + self.nursery_hash_base)

    def enumerate_all_roots(self, callback, arg):
        self.last_generation_root_objects.foreach(callback, arg)
        SemiSpaceGC.enumerate_all_roots(self, callback, arg)
    enumerate_all_roots._annspecialcase_ = 'specialize:arg(1)'

    def debug_check_object(self, obj):
        """Check the invariants about 'obj' that should be true
        between collections."""
        SemiSpaceGC.debug_check_object(self, obj)
        tid = self.header(obj).tid
        if tid & GCFLAG_NO_YOUNG_PTRS:
            ll_assert(not self.is_in_nursery(obj),
                      "nursery object with GCFLAG_NO_YOUNG_PTRS")
            self.trace(obj, self._debug_no_nursery_pointer, None)
        elif not self.is_in_nursery(obj):
            ll_assert(self._d_oopty.contains(obj),
                      "missing from old_objects_pointing_to_young")
        if tid & GCFLAG_NO_HEAP_PTRS:
            ll_assert(self.is_last_generation(obj),
                      "GCFLAG_NO_HEAP_PTRS on non-3rd-generation object")
            self.trace(obj, self._debug_no_gen1or2_pointer, None)
        elif self.is_last_generation(obj):
            ll_assert(self._d_lgro.contains(obj),
                      "missing from last_generation_root_objects")

    def _debug_no_nursery_pointer(self, root, ignored):
        ll_assert(not self.is_in_nursery(root.address[0]),
                  "GCFLAG_NO_YOUNG_PTRS but found a young pointer")
    def _debug_no_gen1or2_pointer(self, root, ignored):
        target = root.address[0]
        ll_assert(not target or self.is_last_generation(target),
                  "GCFLAG_NO_HEAP_PTRS but found a pointer to gen1or2")

    def debug_check_consistency(self):
        if self.DEBUG:
            self._d_oopty = self.old_objects_pointing_to_young.stack2dict()
            self._d_lgro = self.last_generation_root_objects.stack2dict()
            SemiSpaceGC.debug_check_consistency(self)
            self._d_oopty.delete()
            self._d_lgro.delete()
            self.old_objects_pointing_to_young.foreach(
                self._debug_check_flag_1, None)
            self.last_generation_root_objects.foreach(
                self._debug_check_flag_2, None)

    def _debug_check_flag_1(self, obj, ignored):
        ll_assert(not (self.header(obj).tid & GCFLAG_NO_YOUNG_PTRS),
                  "unexpected GCFLAG_NO_YOUNG_PTRS")
    def _debug_check_flag_2(self, obj, ignored):
        ll_assert(not (self.header(obj).tid & GCFLAG_NO_HEAP_PTRS),
                  "unexpected GCFLAG_NO_HEAP_PTRS")

    def debug_check_can_copy(self, obj):
        if self.is_in_nursery(obj):
            pass    # it's ok to copy an object out of the nursery
        else:
            SemiSpaceGC.debug_check_can_copy(self, obj)


# ____________________________________________________________

def nursery_size_from_env():
    return env.read_from_env('PYPY_GENERATIONGC_NURSERY')
