import sys
from rpython.memory.gc.semispace import SemiSpaceGC
from rpython.memory.gc.generation import GenerationGC, WORD
from rpython.memory.gc.semispace import GCFLAG_EXTERNAL, GCFLAG_FORWARDED
from rpython.memory.gc.semispace import GCFLAG_HASHMASK
from rpython.memory.gc.generation import GCFLAG_NO_YOUNG_PTRS
from rpython.memory.gc.generation import GCFLAG_NO_HEAP_PTRS
from rpython.memory.gc.semispace import GC_HASH_TAKEN_ADDR
from rpython.memory.gc.semispace import GC_HASH_HASFIELD
from rpython.rtyper.lltypesystem import lltype, llmemory, llarena
from rpython.rtyper.lltypesystem.llmemory import raw_malloc_usage
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rlib.debug import ll_assert, have_debug_prints
from rpython.rlib.debug import debug_print, debug_start, debug_stop
from rpython.rlib.rarithmetic import ovfcheck
from rpython.rtyper.lltypesystem import rffi

#   _______in the semispaces_________      ______external (non-moving)_____
#  /                                 \    /                                \
#                                          ___raw_malloc'ed__    _prebuilt_
#  +----------------------------------+   /                  \  /          \
#  |    | | | | |    |                |
#  |    | | | | |    |                |    age < max      age == max
#  |nur-|o|o|o|o|    |                |      +---+      +---+      +---+
#  |sery|b|b|b|b|free|     empty      |      |obj|      |obj|      |obj|  
#  |    |j|j|j|j|    |                |      +---+      +---+      +---+  
#  |    | | | | |    |                |       +---+      +---+      +---+
#  +-----------------+----------------+       |obj|      |obj|      |obj|
#        age <= max                           +---+      +---+      +---+
#            
#  |gen1|------------- generation 2 -----------------|-----generation 3-----|
#
# Object lists:
#   * gen2_rawmalloced_objects
#   * gen3_rawmalloced_objects
#   * old_objects_pointing_to_young: gen2or3 objs that point to gen1 objs
#   * last_generation_root_objects: gen3 objs that point to gen1or2 objs
#
# How to tell the objects apart:
#   * external:      tid & GCFLAG_EXTERNAL
#   * gen1:          is_in_nursery(obj)
#   * gen3:          (tid & (GCFLAG_EXTERNAL|GCFLAG_AGE_MASK)) ==
#                           (GCFLAG_EXTERNAL|GCFLAG_AGE_MAX)
#
# Some invariants:
#   * gen3 are either GCFLAG_NO_HEAP_PTRS or in 'last_generation_root_objects'
#   * between collections, GCFLAG_UNVISITED set exactly for gen2_rawmalloced
#
# A malloc_varsize() of large objects returns objects that are external
# but initially of generation 2.  Old objects from the semispaces are
# moved to external objects directly as generation 3.

# The "age" of an object is the number of times it survived a full
# collections, without counting the step that moved it out of the nursery.
# When a semispace-based object would grow older than MAX_SEMISPACE_AGE,
# it is instead copied to a nonmoving location.  For example, a value of 3
# ensures that an object is copied at most 5 times in total: from the
# nursery to the semispace, then three times between the two spaces,
# then one last time to a nonmoving location.
MAX_SEMISPACE_AGE = 3

GCFLAG_UNVISITED = GenerationGC.first_unused_gcflag << 0
_gcflag_next_bit = GenerationGC.first_unused_gcflag << 1
GCFLAG_AGE_ONE   = _gcflag_next_bit
GCFLAG_AGE_MAX   = _gcflag_next_bit * MAX_SEMISPACE_AGE
GCFLAG_AGE_MASK  = 0
while GCFLAG_AGE_MASK < GCFLAG_AGE_MAX:
    GCFLAG_AGE_MASK |= _gcflag_next_bit
    _gcflag_next_bit <<= 1

# The 3rd generation objects are only collected after the following
# number of calls to semispace_collect():
GENERATION3_COLLECT_THRESHOLD = 20

class HybridGC(GenerationGC):
    """A two-generations semi-space GC like the GenerationGC,
    except that objects above a certain size are handled separately:
    they are allocated via raw_malloc/raw_free in a mark-n-sweep fashion.
    """
    first_unused_gcflag = _gcflag_next_bit
    prebuilt_gc_objects_are_static_roots = True

    # the following values override the default arguments of __init__ when
    # translating to a real backend.
    TRANSLATION_PARAMS = GenerationGC.TRANSLATION_PARAMS.copy()
    TRANSLATION_PARAMS['large_object'] = 6*1024    # XXX adjust
    TRANSLATION_PARAMS['large_object_gcptrs'] = 31*1024    # XXX adjust
    TRANSLATION_PARAMS['min_nursery_size'] = 128*1024
    # condition: large_object <= large_object_gcptrs < min_nursery_size/4

    def __init__(self, *args, **kwds):
        large_object = kwds.pop('large_object', 6*WORD)
        large_object_gcptrs = kwds.pop('large_object_gcptrs', 8*WORD)
        self.generation3_collect_threshold = kwds.pop(
            'generation3_collect_threshold', GENERATION3_COLLECT_THRESHOLD)
        GenerationGC.__init__(self, *args, **kwds)

        # Objects whose total size is at least 'large_object' bytes are
        # allocated separately in a mark-n-sweep fashion.  If the object
        # has GC pointers in its varsized part, we use instead the
        # higher limit 'large_object_gcptrs'.  The idea is that
        # separately allocated objects are allocated immediately "old"
        # and it's not good to have too many pointers from old to young
        # objects.

        # In this class, we assume that the 'large_object' limit is not
        # very high, so that all objects that wouldn't easily fit in the
        # nursery are considered large by this limit.  This is the
        # meaning of the 'assert' below.
        self.nonlarge_max = large_object - 1
        self.nonlarge_gcptrs_max = large_object_gcptrs - 1
        assert self.nonlarge_gcptrs_max <= self.lb_young_var_basesize
        assert self.nonlarge_max <= self.nonlarge_gcptrs_max

    def setup(self):
        self.large_objects_collect_trigger = self.param_space_size
        self._initial_trigger = self.large_objects_collect_trigger
        self.rawmalloced_objects_to_trace = self.AddressStack()
        self.count_semispaceonly_collects = 0

        self.gen2_rawmalloced_objects = self.AddressStack()
        self.gen3_rawmalloced_objects = self.AddressStack()
        GenerationGC.setup(self)

    def set_max_heap_size(self, size):
        raise NotImplementedError

    # NB. to simplify the code, only varsized objects can be considered
    # 'large'.

    def malloc_varsize_clear(self, typeid, length, size, itemsize,
                             offset_to_length):
        size_gc_header = self.gcheaderbuilder.size_gc_header
        nonvarsize = size_gc_header + size

        # Compute the maximal length that makes the object still
        # below 'nonlarge_max'.  All the following logic is usually
        # constant-folded because self.nonlarge_max, size and itemsize
        # are all constants (the arguments are constant due to
        # inlining) and self.has_gcptr_in_varsize() is constant-folded.
        if self.has_gcptr_in_varsize(typeid):
            nonlarge_max = self.nonlarge_gcptrs_max
        else:
            nonlarge_max = self.nonlarge_max

        if not raw_malloc_usage(itemsize):
            too_many_items = raw_malloc_usage(nonvarsize) > nonlarge_max
        else:
            maxlength = nonlarge_max - raw_malloc_usage(nonvarsize)
            maxlength = maxlength // raw_malloc_usage(itemsize)
            too_many_items = length > maxlength

        if not too_many_items:
            # With the above checks we know now that totalsize cannot be more
            # than 'nonlarge_max'; in particular, the + and * cannot overflow.
            # Let's try to fit the object in the nursery.
            totalsize = nonvarsize + itemsize * length
            result = self.nursery_free
            if raw_malloc_usage(totalsize) <= self.nursery_top - result:
                llarena.arena_reserve(result, totalsize)
                # GCFLAG_NO_YOUNG_PTRS is never set on young objs
                self.init_gc_object(result, typeid, flags=0)
                (result + size_gc_header + offset_to_length).signed[0] = length
                self.nursery_free = result + llarena.round_up_for_allocation(
                    totalsize)
                return llmemory.cast_adr_to_ptr(result+size_gc_header,
                                                llmemory.GCREF)
        return self.malloc_varsize_slowpath(typeid, length)

    def malloc_varsize_slowpath(self, typeid, length):
        # For objects that are too large, or when the nursery is exhausted.
        # In order to keep malloc_varsize_clear() as compact as possible,
        # we recompute what we need in this slow path instead of passing
        # it all as function arguments.
        size_gc_header = self.gcheaderbuilder.size_gc_header
        nonvarsize = size_gc_header + self.fixed_size(typeid)
        itemsize = self.varsize_item_sizes(typeid)
        offset_to_length = self.varsize_offset_to_length(typeid)
        try:
            varsize = ovfcheck(itemsize * length)
            totalsize = ovfcheck(nonvarsize + varsize)
        except OverflowError:
            raise MemoryError()
        if self.has_gcptr_in_varsize(typeid):
            nonlarge_max = self.nonlarge_gcptrs_max
        else:
            nonlarge_max = self.nonlarge_max
        if raw_malloc_usage(totalsize) > nonlarge_max:
            result = self.malloc_varsize_marknsweep(totalsize)
            flags = self.GCFLAGS_FOR_NEW_EXTERNAL_OBJECTS | GCFLAG_UNVISITED
        else:
            result = self.malloc_varsize_collecting_nursery(totalsize)
            flags = self.GCFLAGS_FOR_NEW_YOUNG_OBJECTS
        self.init_gc_object(result, typeid, flags)
        (result + size_gc_header + offset_to_length).signed[0] = length
        return llmemory.cast_adr_to_ptr(result+size_gc_header, llmemory.GCREF)

    malloc_varsize_slowpath._dont_inline_ = True

    def can_move(self, addr):
        tid = self.header(addr).tid
        return not (tid & GCFLAG_EXTERNAL)

    def malloc_varsize_collecting_nursery(self, totalsize):
        result = self.collect_nursery()
        ll_assert(raw_malloc_usage(totalsize) <= self.nursery_top - result,
                  "not enough room in malloc_varsize_collecting_nursery()")
        llarena.arena_reserve(result, totalsize)
        self.nursery_free = result + llarena.round_up_for_allocation(
            totalsize)
        return result

    def _check_rawsize_alloced(self, size_estimate):
        self.large_objects_collect_trigger -= size_estimate
        if self.large_objects_collect_trigger < 0:
            debug_start("gc-rawsize-collect")
            debug_print("allocated", (self._initial_trigger -
                                      self.large_objects_collect_trigger),
                        "bytes, triggering full collection")
            self.semispace_collect()
            debug_stop("gc-rawsize-collect")

    def malloc_varsize_marknsweep(self, totalsize):
        # In order to free the large objects from time to time, we
        # arbitrarily force a full collect() if none occurs when we have
        # allocated self.space_size + rawmalloced bytes of large objects.
        self._check_rawsize_alloced(raw_malloc_usage(totalsize))
        result = self.allocate_external_object(totalsize)
        if not result:
            raise MemoryError()
        # The parent classes guarantee zero-filled allocations, so we
        # need to follow suit.
        llmemory.raw_memclear(result, totalsize)
        size_gc_header = self.gcheaderbuilder.size_gc_header
        self.gen2_rawmalloced_objects.append(result + size_gc_header)
        return result

    def allocate_external_object(self, totalsize):
        # XXX maybe we should use arena_malloc() above a certain size?
        # If so, we'd also use arena_reset() in malloc_varsize_marknsweep().
        return llmemory.raw_malloc(totalsize)

    def init_gc_object_immortal(self, addr, typeid,
                                flags=(GCFLAG_NO_YOUNG_PTRS |
                                       GCFLAG_NO_HEAP_PTRS |
                                       GCFLAG_AGE_MAX)):
        GenerationGC.init_gc_object_immortal(self, addr, typeid, flags)

    # ___________________________________________________________________
    # collect() and semispace_collect() are not synonyms in this GC: the
    # former is a complete collect, while the latter is only collecting
    # the semispaces and not always doing the mark-n-sweep pass over the
    # external objects of 3rd generation.

    def collect(self, gen=2):
        if gen > 1:
            self.count_semispaceonly_collects = self.generation3_collect_threshold
        GenerationGC.collect(self, gen)

    def is_collecting_gen3(self):
        count = self.count_semispaceonly_collects
        return count >= self.generation3_collect_threshold

    # ___________________________________________________________________
    # the following methods are hook into SemiSpaceGC.semispace_collect()

    def starting_full_collect(self):
        # At the start of a collection, the GCFLAG_UNVISITED bit is set
        # exactly on the objects in gen2_rawmalloced_objects.  Only
        # raw_malloc'ed objects can ever have this bit set.
        self.count_semispaceonly_collects += 1
        if self.is_collecting_gen3():
            # set the GCFLAG_UNVISITED on all rawmalloced generation-3 objects
            # as well, to let them be recorded by visit_external_object()
            self.gen3_rawmalloced_objects.foreach(self._set_gcflag_unvisited,
                                                  None)
        ll_assert(not self.rawmalloced_objects_to_trace.non_empty(),
                  "rawmalloced_objects_to_trace should be empty at start")
        self._nonmoving_copy_count = 0
        self._nonmoving_copy_size = 0

    def _set_gcflag_unvisited(self, obj, ignored):
        ll_assert(not (self.header(obj).tid & GCFLAG_UNVISITED),
                  "bogus GCFLAG_UNVISITED on gen3 obj")
        self.header(obj).tid |= GCFLAG_UNVISITED

    def collect_roots(self):
        if not self.is_collecting_gen3():
            GenerationGC.collect_roots(self)
        else:
            # as we don't record which prebuilt gc objects point to
            # rawmalloced generation 3 objects, we have to trace all
            # the prebuilt gc objects.
            self.root_walker.walk_roots(
                SemiSpaceGC._collect_root,  # stack roots
                SemiSpaceGC._collect_root,  # static in prebuilt non-gc structs
                SemiSpaceGC._collect_root)  # static in prebuilt gc objects

    def surviving(self, obj):
        # To use during a collection.  The objects that survive are the
        # ones with GCFLAG_FORWARDED set and GCFLAG_UNVISITED not set.
        # This is equivalent to self.is_forwarded() for all objects except
        # the ones obtained by raw_malloc.
        flags = self.header(obj).tid & (GCFLAG_FORWARDED|GCFLAG_UNVISITED)
        return flags == GCFLAG_FORWARDED

    def is_last_generation(self, obj):
        return ((self.header(obj).tid & (GCFLAG_EXTERNAL|GCFLAG_AGE_MASK)) ==
                (GCFLAG_EXTERNAL|GCFLAG_AGE_MAX))

    def visit_external_object(self, obj):
        hdr = self.header(obj)
        if hdr.tid & GCFLAG_UNVISITED:
            # This is a not-visited-yet raw_malloced object.
            hdr.tid &= ~GCFLAG_UNVISITED
            self.rawmalloced_objects_to_trace.append(obj)

    def make_a_copy(self, obj, objsize):
        # During a full collect, all copied objects might implicitly come
        # from the nursery.  If they do, we must add the GCFLAG_NO_YOUNG_PTRS.
        # If they don't, we count how many times they are copied and when
        # some threshold is reached we make the copy a non-movable "external"
        # object.  The threshold is MAX_SEMISPACE_AGE.
        tid = self.header(obj).tid
        # XXX the following logic is not doing exactly what is explained
        # above: any object without GCFLAG_NO_YOUNG_PTRS has its age not
        # incremented.  This is accidental: it means that objects that
        # are very often modified to point to young objects don't reach
        # the 3rd generation.  For now I'll leave it this way because
        # I'm not sure that it's a bad thing.
        if not (tid & GCFLAG_NO_YOUNG_PTRS):
            tid |= GCFLAG_NO_YOUNG_PTRS    # object comes from the nursery
        elif (tid & GCFLAG_AGE_MASK) < GCFLAG_AGE_MAX:
            tid += GCFLAG_AGE_ONE
        else:
            newobj = self.make_a_nonmoving_copy(obj, objsize)
            if newobj:
                return newobj
            tid &= ~GCFLAG_AGE_MASK
        # skip GenerationGC.make_a_copy() as we already did the right
        # thing about GCFLAG_NO_YOUNG_PTRS
        return self._make_a_copy_with_tid(obj, objsize, tid)

    def make_a_nonmoving_copy(self, obj, objsize):
        # NB. the object can have a finalizer or be a weakref, but
        # it's not an issue.
        totalsize = self.size_gc_header() + objsize
        tid = self.header(obj).tid
        if tid & GCFLAG_HASHMASK:
            totalsize_incl_hash = totalsize + llmemory.sizeof(lltype.Signed)
        else:
            totalsize_incl_hash = totalsize
        newaddr = self.allocate_external_object(totalsize_incl_hash)
        if not newaddr:
            return llmemory.NULL   # can't raise MemoryError during a collect()
        self._nonmoving_copy_count += 1
        self._nonmoving_copy_size += raw_malloc_usage(totalsize)

        llmemory.raw_memcopy(obj - self.size_gc_header(), newaddr, totalsize)
        if tid & GCFLAG_HASHMASK:
            hash = self._get_object_hash(obj, objsize, tid)
            (newaddr + totalsize).signed[0] = hash
            tid |= GC_HASH_HASFIELD
        #
        # GCFLAG_UNVISITED is not set
        # GCFLAG_NO_HEAP_PTRS is not set either, conservatively.  It may be
        # set by the next collection's collect_last_generation_roots().
        # This old object is immediately put at generation 3.
        newobj = newaddr + self.size_gc_header()
        hdr = self.header(newobj)
        hdr.tid = tid | self.GCFLAGS_FOR_NEW_EXTERNAL_OBJECTS
        ll_assert(self.is_last_generation(newobj),
                  "make_a_nonmoving_copy: object too young")
        self.gen3_rawmalloced_objects.append(newobj)
        self.last_generation_root_objects.append(newobj)
        self.rawmalloced_objects_to_trace.append(newobj)   # visit me
        return newobj

    def scan_copied(self, scan):
        # Alternate between scanning the regular objects we just moved
        # and scanning the raw_malloc'ed object we just visited.
        progress = True
        while progress:
            newscan = GenerationGC.scan_copied(self, scan)
            progress = newscan != scan
            scan = newscan
            while self.rawmalloced_objects_to_trace.non_empty():
                obj = self.rawmalloced_objects_to_trace.pop()
                self.trace_and_copy(obj)
                progress = True
        return scan

    def finished_full_collect(self):
        ll_assert(not self.rawmalloced_objects_to_trace.non_empty(),
                  "rawmalloced_objects_to_trace should be empty at end")
        debug_print("| [hybrid] made nonmoving:         ",
                    self._nonmoving_copy_size, "bytes in",
                    self._nonmoving_copy_count, "objs")
        rawmalloced_trigger = 0
        # sweep the nonmarked rawmalloced objects
        if self.is_collecting_gen3():
            rawmalloced_trigger += self.sweep_rawmalloced_objects(generation=3)
        rawmalloced_trigger += self.sweep_rawmalloced_objects(generation=2)
        self.large_objects_collect_trigger = (rawmalloced_trigger +
                                              self.space_size)
        if self.is_collecting_gen3():
            self.count_semispaceonly_collects = 0
        self._initial_trigger = self.large_objects_collect_trigger

    def sweep_rawmalloced_objects(self, generation):
        # free all the rawmalloced objects of the specified generation
        # that have not been marked
        if generation == 2:
            objects = self.gen2_rawmalloced_objects
            # generation 2 sweep: if A points to an object object B that
            # moves from gen2 to gen3, it's possible that A no longer points
            # to any gen2 object.  In this case, A remains a bit too long in
            # last_generation_root_objects, but this will be fixed by the
            # next collect_last_generation_roots().
        elif generation == 3:
            objects = self.gen3_rawmalloced_objects
            # generation 3 sweep: remove from last_generation_root_objects
            # all the objects that we are about to free
            gen3roots = self.last_generation_root_objects
            newgen3roots = self.AddressStack()
            while gen3roots.non_empty():
                obj = gen3roots.pop()
                if not (self.header(obj).tid & GCFLAG_UNVISITED):
                    newgen3roots.append(obj)
            gen3roots.delete()
            self.last_generation_root_objects = newgen3roots
        else:
            ll_assert(False, "bogus 'generation'")
            return 0 # to please the flowspace

        surviving_objects = self.AddressStack()
        # Help the flow space
        alive_count = alive_size = dead_count = dead_size = 0
        debug = have_debug_prints()
        while objects.non_empty():
            obj = objects.pop()
            tid = self.header(obj).tid
            if tid & GCFLAG_UNVISITED:
                if debug:
                    dead_count+=1
                    dead_size+=raw_malloc_usage(self.get_size_incl_hash(obj))
                addr = obj - self.gcheaderbuilder.size_gc_header
                llmemory.raw_free(addr)
            else:
                if debug:
                    alive_count+=1
                alive_size+=raw_malloc_usage(self.get_size_incl_hash(obj))
                if generation == 3:
                    surviving_objects.append(obj)
                elif generation == 2:
                    ll_assert((tid & GCFLAG_AGE_MASK) < GCFLAG_AGE_MAX,
                              "wrong age for generation 2 object")
                    tid += GCFLAG_AGE_ONE
                    if (tid & GCFLAG_AGE_MASK) == GCFLAG_AGE_MAX:
                        # the object becomes part of generation 3
                        self.gen3_rawmalloced_objects.append(obj)
                        # GCFLAG_NO_HEAP_PTRS not set yet, conservatively
                        self.last_generation_root_objects.append(obj)
                    else:
                        # the object stays in generation 2
                        tid |= GCFLAG_UNVISITED
                        surviving_objects.append(obj)
                    self.header(obj).tid = tid
        objects.delete()
        if generation == 2:
            self.gen2_rawmalloced_objects = surviving_objects
        elif generation == 3:
            self.gen3_rawmalloced_objects = surviving_objects
        debug_print("| [hyb] gen", generation,
                    "nonmoving now alive: ",
                    alive_size, "bytes in",
                    alive_count, "objs")
        debug_print("| [hyb] gen", generation,
                    "nonmoving freed:     ",
                    dead_size, "bytes in",
                    dead_count, "objs")
        return alive_size

    def id(self, ptr):
        obj = llmemory.cast_ptr_to_adr(ptr)

        # is it a tagged pointer?
        if not self.is_valid_gc_object(obj):
            return llmemory.cast_adr_to_int(obj)

        if self._is_external(obj):
            # a prebuilt or rawmalloced object
            if self.is_last_generation(obj):
                # a generation 3 object may be one that used to live in
                # the semispace.  So we still need to check if the object had
                # its id taken before.  If not, we can use its address as its
                # id as it is not going to move any more.
                result = self.objects_with_id.get(obj, obj)
            else:
                # a generation 2 external object was never non-external in
                # the past, so it cannot be listed in self.objects_with_id.
                result = obj
        else:
            result = self._compute_id(obj)     # common case
        return llmemory.cast_adr_to_int(result) * 2 # see comment in base.py
        # XXX a possible optimization would be to use three dicts, one
        # for each generation, instead of mixing gen2 and gen3 objects.

    def debug_check_object(self, obj):
        """Check the invariants about 'obj' that should be true
        between collections."""
        GenerationGC.debug_check_object(self, obj)
        tid = self.header(obj).tid
        if tid & GCFLAG_UNVISITED:
            ll_assert(self._d_gen2ro.contains(obj),
                      "GCFLAG_UNVISITED on non-gen2 object")

    def debug_check_consistency(self):
        if self.DEBUG:
            self._d_gen2ro = self.gen2_rawmalloced_objects.stack2dict()
            GenerationGC.debug_check_consistency(self)
            self._d_gen2ro.delete()
            self.gen2_rawmalloced_objects.foreach(self._debug_check_gen2, None)
            self.gen3_rawmalloced_objects.foreach(self._debug_check_gen3, None)

    def _debug_check_gen2(self, obj, ignored):
        tid = self.header(obj).tid
        ll_assert(bool(tid & GCFLAG_EXTERNAL),
                  "gen2: missing GCFLAG_EXTERNAL")
        ll_assert(bool(tid & GC_HASH_TAKEN_ADDR),
                  "gen2: missing GC_HASH_TAKEN_ADDR")
        ll_assert(bool(tid & GCFLAG_UNVISITED),
                  "gen2: missing GCFLAG_UNVISITED")
        ll_assert((tid & GCFLAG_AGE_MASK) < GCFLAG_AGE_MAX,
                  "gen2: age field too large")
    def _debug_check_gen3(self, obj, ignored):
        tid = self.header(obj).tid
        ll_assert(bool(tid & GCFLAG_EXTERNAL),
                  "gen3: missing GCFLAG_EXTERNAL")
        ll_assert(bool(tid & GC_HASH_TAKEN_ADDR),
                  "gen3: missing GC_HASH_TAKEN_ADDR")
        ll_assert(not (tid & GCFLAG_UNVISITED),
                  "gen3: unexpected GCFLAG_UNVISITED")
        ll_assert((tid & GCFLAG_AGE_MASK) == GCFLAG_AGE_MAX,
                  "gen3: wrong age field")
