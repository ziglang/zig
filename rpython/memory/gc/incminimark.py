"""Incremental version of the MiniMark GC.

Environment variables can be used to fine-tune the following parameters:

 PYPY_GC_NURSERY         The nursery size.  Defaults to 1/2 of your cache or
                         '4M'.  Small values
                         (like 1 or 1KB) are useful for debugging.

 PYPY_GC_NURSERY_DEBUG   If set to non-zero, will fill nursery with garbage,
                         to help debugging.

 PYPY_GC_INCREMENT_STEP  The size of memory marked during the marking step.
                         Default is size of nursery * 2. If you mark it too high
                         your GC is not incremental at all. The minimum is set
                         to size that survives minor collection * 1.5 so we
                         reclaim anything all the time.

 PYPY_GC_MAJOR_COLLECT   Major collection memory factor.  Default is '1.82',
                         which means trigger a major collection when the
                         memory consumed equals 1.82 times the memory
                         really used at the end of the previous major
                         collection.

 PYPY_GC_GROWTH          Major collection threshold's max growth rate.
                         Default is '1.4'.  Useful to collect more often
                         than normally on sudden memory growth, e.g. when
                         there is a temporary peak in memory usage.

 PYPY_GC_MAX             The max heap size.  If coming near this limit, it
                         will first collect more often, then raise an
                         RPython MemoryError, and if that is not enough,
                         crash the program with a fatal error.  Try values
                         like '1.6GB'.

 PYPY_GC_MAX_DELTA       The major collection threshold will never be set
                         to more than PYPY_GC_MAX_DELTA the amount really
                         used after a collection.  Defaults to 1/8th of the
                         total RAM size (which is constrained to be at most
                         2/3/4GB on 32-bit systems).  Try values like '200MB'.

 PYPY_GC_MIN             Don't collect while the memory size is below this
                         limit.  Useful to avoid spending all the time in
                         the GC in very small programs.  Defaults to 8
                         times the nursery.

 PYPY_GC_DEBUG           Enable extra checks around collections that are
                         too slow for normal use.  Values are 0 (off),
                         1 (on major collections) or 2 (also on minor
                         collections).

 PYPY_GC_MAX_PINNED      The maximal number of pinned objects at any point
                         in time.  Defaults to a conservative value depending
                         on nursery size and maximum object size inside the
                         nursery.  Useful for debugging by setting it to 0.
"""
# XXX Should find a way to bound the major collection threshold by the
# XXX total addressable size.  Maybe by keeping some minimarkpage arenas
# XXX pre-reserved, enough for a few nursery collections?  What about
# XXX raw-malloced memory?

# XXX try merging old_objects_pointing_to_pinned into
# XXX old_objects_pointing_to_young (IRC 2014-10-22, fijal and gregor_w)
import sys
import os
import time
from rpython.rtyper.lltypesystem import lltype, llmemory, llarena, llgroup
from rpython.rtyper.lltypesystem.lloperation import llop
from rpython.rtyper.lltypesystem.llmemory import raw_malloc_usage
from rpython.memory.gc.base import GCBase, MovingGCBase
from rpython.memory.gc import env
from rpython.memory.support import mangle_hash
from rpython.rlib.rarithmetic import ovfcheck, LONG_BIT, intmask, r_uint
from rpython.rlib.rarithmetic import LONG_BIT_SHIFT
from rpython.rlib.debug import ll_assert, debug_print, debug_start, debug_stop
from rpython.rlib.objectmodel import specialize
from rpython.rlib import rgc
from rpython.memory.gc.minimarkpage import out_of_memory

#
# Handles the objects in 2 generations:
#
#  * young objects: allocated in the nursery if they are not too large, or
#    raw-malloced otherwise.  The nursery is a fixed-size memory buffer of
#    4MB by default.  When full, we do a minor collection;
#    - surviving objects from the nursery are moved outside and become old,
#    - non-surviving raw-malloced objects are freed,
#    - and pinned objects are kept at their place inside the nursery and stay
#      young.
#
#  * old objects: never move again.  These objects are either allocated by
#    minimarkpage.py (if they are small), or raw-malloced (if they are not
#    small).  Collected by regular mark-n-sweep during major collections.
#

WORD = LONG_BIT // 8

first_gcflag = 1 << (LONG_BIT//2)

# The following flag is set on objects if we need to do something to
# track the young pointers that it might contain.  The flag is not set
# on young objects (unless they are large arrays, see below), and we
# simply assume that any young object can point to any other young object.
# For old and prebuilt objects, the flag is usually set, and is cleared
# when we write any pointer to it.  For large arrays with
# GCFLAG_HAS_CARDS, we rely on card marking to track where the
# young pointers are; the flag GCFLAG_TRACK_YOUNG_PTRS is set in this
# case too, to speed up the write barrier.
GCFLAG_TRACK_YOUNG_PTRS = first_gcflag << 0

# The following flag is set on some prebuilt objects.  The flag is set
# unless the object is already listed in 'prebuilt_root_objects'.
# When a pointer is written inside an object with GCFLAG_NO_HEAP_PTRS
# set, the write_barrier clears the flag and adds the object to
# 'prebuilt_root_objects'.
GCFLAG_NO_HEAP_PTRS = first_gcflag << 1

# The following flag is set on surviving objects during a major collection.
GCFLAG_VISITED      = first_gcflag << 2

# The following flag is set on nursery objects of which we asked the id
# or the identityhash.  It means that a space of the size of the object
# has already been allocated in the nonmovable part.
GCFLAG_HAS_SHADOW   = first_gcflag << 3

# The following flag is set temporarily on some objects during a major
# collection.  See pypy/doc/discussion/finalizer-order.txt
GCFLAG_FINALIZATION_ORDERING = first_gcflag << 4

# This flag is reserved for RPython.
GCFLAG_EXTRA        = first_gcflag << 5

# The following flag is set on externally raw_malloc'ed arrays of pointers.
# They are allocated with some extra space in front of them for a bitfield,
# one bit per 'card_page_indices' indices.
GCFLAG_HAS_CARDS    = first_gcflag << 6
GCFLAG_CARDS_SET    = first_gcflag << 7     # <- at least one card bit is set
# note that GCFLAG_CARDS_SET is the most significant bit of a byte:
# this is required for the JIT (x86)

# The following flag is set on surviving raw-malloced young objects during
# a minor collection.
GCFLAG_VISITED_RMY   = first_gcflag << 8

# The following flag is set on nursery objects to keep them in the nursery.
# This means that a young object with this flag is not moved out
# of the nursery during a minor collection. See pin()/unpin() for further
# details.
GCFLAG_PINNED        = first_gcflag << 9

# The following flag is set only on objects outside the nursery
# (i.e. old objects).  Therefore we can reuse GCFLAG_PINNED as it is used for
# the same feature (object pinning) and GCFLAG_PINNED is only used on nursery
# objects.
# If this flag is set, the flagged object is already an element of
# 'old_objects_pointing_to_pinned' and doesn't have to be added again.
GCFLAG_PINNED_OBJECT_PARENT_KNOWN = GCFLAG_PINNED

# record that ignore_finalizer() has been called
GCFLAG_IGNORE_FINALIZER = first_gcflag << 10

# shadow objects can have its memory initialized when it is created.
# It does not need an additional copy in trace out
GCFLAG_SHADOW_INITIALIZED   = first_gcflag << 11

# another flag set only on specific objects: the ll_dummy_value from
# rpython.rtyper.rmodel
GCFLAG_DUMMY        = first_gcflag << 12

_GCFLAG_FIRST_UNUSED = first_gcflag << 13    # the first unused bit


# States for the incremental GC

# The scanning phase, next step call will scan the current roots
# This state must complete in a single step
STATE_SCANNING = 0

# The marking phase. We walk the list 'objects_to_trace' of all gray objects
# and mark all of the things they point to gray. This step lasts until there
# are no more gray objects.  ('objects_to_trace' never contains pinned objs.)
STATE_MARKING = 1

# here we kill all the unvisited objects
STATE_SWEEPING = 2

# here we call all the finalizers
STATE_FINALIZING = 3

GC_STATES = ['SCANNING', 'MARKING', 'SWEEPING', 'FINALIZING']


FORWARDSTUB = lltype.GcStruct('forwarding_stub',
                              ('forw', llmemory.Address))
FORWARDSTUBPTR = lltype.Ptr(FORWARDSTUB)
NURSARRAY = lltype.Array(llmemory.Address)

# ____________________________________________________________



class IncrementalMiniMarkGC(MovingGCBase):
    _alloc_flavor_ = "raw"
    inline_simple_malloc = True
    inline_simple_malloc_varsize = True
    needs_write_barrier = True
    prebuilt_gc_objects_are_static_roots = False
    can_usually_pin_objects = True
    malloc_zero_filled = False
    gcflag_extra = GCFLAG_EXTRA
    gcflag_dummy = GCFLAG_DUMMY

    # All objects start with a HDR, i.e. with a field 'tid' which contains
    # a word.  This word is divided in two halves: the lower half contains
    # the typeid, and the upper half contains various flags, as defined
    # by GCFLAG_xxx above.
    HDR = lltype.Struct('header', ('tid', lltype.Signed))
    typeid_is_in_field = 'tid'

    # During a minor collection, the objects in the nursery that are
    # moved outside are changed in-place: their header is replaced with
    # the value -42, and the following word is set to the address of
    # where the object was moved.  This means that all objects in the
    # nursery need to be at least 2 words long, but objects outside the
    # nursery don't need to.
    minimal_size_in_nursery = (
        llmemory.sizeof(HDR) + llmemory.sizeof(llmemory.Address))


    TRANSLATION_PARAMS = {
        # Automatically adjust the size of the nursery and the
        # 'major_collection_threshold' from the environment.
        # See docstring at the start of the file.
        "read_from_env": True,

        # The size of the nursery.  Note that this is only used as a
        # fall-back number.
        "nursery_size": 896*1024,

        # The system page size.  Like malloc, we assume that it is 4K
        # for 32-bit systems; unlike malloc, we assume that it is 8K
        # for 64-bit systems, for consistent results.
        "page_size": 1024*WORD,

        # The size of an arena.  Arenas are groups of pages allocated
        # together.
        "arena_size": 65536*WORD,

        # The maximum size of an object allocated compactly.  All objects
        # that are larger are just allocated with raw_malloc().  Note that
        # the size limit for being first allocated in the nursery is much
        # larger; see below.
        "small_request_threshold": 35*WORD,

        # Full collection threshold: after a major collection, we record
        # the total size consumed; and after every minor collection, if the
        # total size is now more than 'major_collection_threshold' times,
        # we trigger the next major collection.
        "major_collection_threshold": 1.82,

        # Threshold to avoid that the total heap size grows by a factor of
        # major_collection_threshold at every collection: it can only
        # grow at most by the following factor from one collection to the
        # next.  Used e.g. when there is a sudden, temporary peak in memory
        # usage; this avoids that the upper bound grows too fast.
        "growth_rate_max": 1.4,

        # The number of array indices that are mapped to a single bit in
        # write_barrier_from_array().  Must be a power of two.  The default
        # value of 128 means that card pages are 512 bytes (1024 on 64-bits)
        # in regular arrays of pointers; more in arrays whose items are
        # larger.  A value of 0 disables card marking.
        "card_page_indices": 128,

        # Objects whose total size is at least 'large_object' bytes are
        # allocated out of the nursery immediately, as old objects.  The
        # minimal allocated size of the nursery is 2x the following
        # number (by default, at least 132KB on 32-bit and 264KB on 64-bit).
        "large_object": (16384+512)*WORD,
        }

    def __init__(self, config,
                 read_from_env=False,
                 nursery_size=32*WORD,
                 nursery_cleanup=9*WORD,
                 page_size=16*WORD,
                 arena_size=64*WORD,
                 small_request_threshold=5*WORD,
                 major_collection_threshold=2.5,
                 growth_rate_max=2.5,   # for tests
                 card_page_indices=0,
                 large_object=8*WORD,
                 ArenaCollectionClass=None,
                 **kwds):
        "NOT_RPYTHON"
        MovingGCBase.__init__(self, config, **kwds)
        assert small_request_threshold % WORD == 0
        self.read_from_env = read_from_env
        self.nursery_size = nursery_size

        self.small_request_threshold = small_request_threshold
        self.major_collection_threshold = major_collection_threshold
        self.growth_rate_max = growth_rate_max
        self.num_major_collects = 0
        self.min_heap_size = 0.0
        self.max_heap_size = 0.0
        self.max_heap_size_already_raised = False
        self.max_delta = float(r_uint(-1))
        self.max_number_of_pinned_objects = 0      # computed later
        #
        self.card_page_indices = card_page_indices
        if self.card_page_indices > 0:
            self.card_page_shift = 0
            while (1 << self.card_page_shift) < self.card_page_indices:
                self.card_page_shift += 1
        #
        # 'large_object' limit how big objects can be in the nursery, so
        # it gives a lower bound on the allowed size of the nursery.
        self.nonlarge_max = large_object - 1
        #
        self.nursery      = llmemory.NULL
        self.nursery_free = llmemory.NULL
        self.nursery_top  = llmemory.NULL
        self.debug_tiny_nursery = -1
        self.debug_rotating_nurseries = lltype.nullptr(NURSARRAY)
        self.extra_threshold = 0
        #
        # The ArenaCollection() handles the nonmovable objects allocation.
        if ArenaCollectionClass is None:
            from rpython.memory.gc import minimarkpage
            ArenaCollectionClass = minimarkpage.ArenaCollection
        self.ac = ArenaCollectionClass(arena_size, page_size,
                                       small_request_threshold)
        #
        # Used by minor collection: a list of (mostly non-young) objects that
        # (may) contain a pointer to a young object.  Populated by
        # the write barrier: when we clear GCFLAG_TRACK_YOUNG_PTRS, we
        # add it to this list.
        # Note that young array objects may (by temporary "mistake") be added
        # to this list, but will be removed again at the start of the next
        # minor collection.
        self.old_objects_pointing_to_young = self.AddressStack()
        #
        # Similar to 'old_objects_pointing_to_young', but lists objects
        # that have the GCFLAG_CARDS_SET bit.  For large arrays.  Note
        # that it is possible for an object to be listed both in here
        # and in 'old_objects_pointing_to_young', in which case we
        # should just clear the cards and trace it fully, as usual.
        # Note also that young array objects are never listed here.
        self.old_objects_with_cards_set = self.AddressStack()
        #
        # A list of all prebuilt GC objects that contain pointers to the heap
        self.prebuilt_root_objects = self.AddressStack()
        #
        self._init_writebarrier_logic()
        #
        # The size of all the objects turned from 'young' to 'old'
        # since we started the last major collection cycle.  This is
        # used to track progress of the incremental GC: normally, we
        # run one major GC step after each minor collection, but if a
        # lot of objects are made old, we need run two or more steps.
        # Otherwise the risk is that we create old objects faster than
        # we're collecting them.  The 'threshold' is incremented after
        # each major GC step at a fixed rate; the idea is that as long
        # as 'size_objects_made_old > threshold_objects_made_old' then
        # we must do more major GC steps.  See major_collection_step()
        # for more details.
        self.size_objects_made_old = r_uint(0)
        self.threshold_objects_made_old = r_uint(0)


    def setup(self):
        """Called at run-time to initialize the GC."""
        #
        # Hack: MovingGCBase.setup() sets up stuff related to id(), which
        # we implement differently anyway.  So directly call GCBase.setup().
        GCBase.setup(self)
        #
        # Two lists of all raw_malloced objects (the objects too large)
        self.young_rawmalloced_objects = self.null_address_dict()
        self.old_rawmalloced_objects = self.AddressStack()
        self.raw_malloc_might_sweep = self.AddressStack()
        self.rawmalloced_total_size = r_uint(0)
        self.rawmalloced_peak_size = r_uint(0)
        self.total_gc_time = 0.0

        self.gc_state = STATE_SCANNING

        # if the GC is disabled, it runs only minor collections; major
        # collections need to be manually triggered by explicitly calling
        # collect()
        self.enabled = True
        #
        # Two lists of all objects with finalizers.  Actually they are lists
        # of pairs (finalization_queue_nr, object).  "probably young objects"
        # are all traced and moved to the "old" list by the next minor
        # collection.
        self.probably_young_objects_with_finalizers = self.AddressDeque()
        self.old_objects_with_finalizers = self.AddressDeque()
        p = lltype.malloc(self._ADDRARRAY, 1, flavor='raw',
                          track_allocation=False)
        self.singleaddr = llmemory.cast_ptr_to_adr(p)
        #
        # Two lists of all objects with destructors.
        self.young_objects_with_destructors = self.AddressStack()
        self.old_objects_with_destructors = self.AddressStack()
        #
        # Two lists of the objects with weakrefs.  No weakref can be an
        # old object weakly pointing to a young object: indeed, weakrefs
        # are immutable so they cannot point to an object that was
        # created after it.
        self.young_objects_with_weakrefs = self.AddressStack()
        self.old_objects_with_weakrefs = self.AddressStack()
        #
        # Support for id and identityhash: map nursery objects with
        # GCFLAG_HAS_SHADOW to their future location at the next
        # minor collection.
        self.nursery_objects_shadows = self.AddressDict()
        #
        # A sorted deque containing addresses of pinned objects.
        # This collection is used to make sure we don't overwrite pinned objects.
        # Each minor collection creates a new deque containing the active pinned
        # objects. The addresses are used to set the next 'nursery_top'.
        self.nursery_barriers = self.AddressDeque()
        #
        # Counter tracking how many pinned objects currently reside inside
        # the nursery.
        self.pinned_objects_in_nursery = 0
        #
        # This flag is set if the previous minor collection found at least
        # one pinned object alive.
        self.any_pinned_object_kept = False
        #
        # Keeps track of old objects pointing to pinned objects. These objects
        # must be traced every minor collection. Without tracing them the
        # referenced pinned object wouldn't be visited and therefore collected.
        self.old_objects_pointing_to_pinned = self.AddressStack()
        self.updated_old_objects_pointing_to_pinned = False
        #
        # Allocate a nursery.  In case of auto_nursery_size, start by
        # allocating a very small nursery, enough to do things like look
        # up the env var, which requires the GC; and then really
        # allocate the nursery of the final size.
        if not self.read_from_env:
            self.allocate_nursery()
            self.gc_increment_step = self.nursery_size * 4
            self.gc_nursery_debug = False
        else:
            #
            defaultsize = self.nursery_size
            minsize = 2 * (self.nonlarge_max + 1)
            self.nursery_size = minsize
            self.allocate_nursery()
            #
            # From there on, the GC is fully initialized and the code
            # below can use it
            newsize = env.read_from_env('PYPY_GC_NURSERY')
            # PYPY_GC_NURSERY=smallvalue means that minor collects occur
            # very frequently; the extreme case is PYPY_GC_NURSERY=1, which
            # forces a minor collect for every malloc.  Useful to debug
            # external factors, like trackgcroot or the handling of the write
            # barrier.  Implemented by still using 'minsize' for the nursery
            # size (needed to handle mallocs just below 'large_objects') but
            # hacking at the current nursery position in collect_and_reserve().
            if newsize <= 0:
                newsize = env.estimate_best_nursery_size()
                if newsize <= 0:
                    newsize = defaultsize
            if newsize < minsize:
                self.debug_tiny_nursery = newsize & ~(WORD-1)
                newsize = minsize
            #
            major_coll = env.read_float_from_env('PYPY_GC_MAJOR_COLLECT')
            if major_coll > 1.0:
                self.major_collection_threshold = major_coll
            #
            growth = env.read_float_from_env('PYPY_GC_GROWTH')
            if growth > 1.0:
                self.growth_rate_max = growth
            #
            min_heap_size = env.read_uint_from_env('PYPY_GC_MIN')
            if min_heap_size > 0:
                self.min_heap_size = float(min_heap_size)
            else:
                # defaults to 8 times the nursery
                self.min_heap_size = newsize * 8
            #
            max_heap_size = env.read_uint_from_env('PYPY_GC_MAX')
            if max_heap_size > 0:
                self.max_heap_size = float(max_heap_size)
            #
            max_delta = env.read_uint_from_env('PYPY_GC_MAX_DELTA')
            if max_delta > 0:
                self.max_delta = float(max_delta)
            else:
                self.max_delta = 0.125 * env.get_total_memory()

            gc_increment_step = env.read_uint_from_env('PYPY_GC_INCREMENT_STEP')
            if gc_increment_step > 0:
                self.gc_increment_step = gc_increment_step
            else:
                self.gc_increment_step = newsize * 4
            #
            nursery_debug = env.read_uint_from_env('PYPY_GC_NURSERY_DEBUG')
            if nursery_debug > 0:
                self.gc_nursery_debug = True
            else:
                self.gc_nursery_debug = False
            self._minor_collection()    # to empty the nursery
            llarena.arena_free(self.nursery)
            self.nursery_size = newsize
            self.allocate_nursery()
        #
        env_max_number_of_pinned_objects = os.environ.get('PYPY_GC_MAX_PINNED')
        if env_max_number_of_pinned_objects:
            try:
                env_max_number_of_pinned_objects = int(env_max_number_of_pinned_objects)
            except ValueError:
                env_max_number_of_pinned_objects = 0
            #
            if env_max_number_of_pinned_objects >= 0: # 0 allows to disable pinning completely
                self.max_number_of_pinned_objects = env_max_number_of_pinned_objects
        else:
            # Estimate this number conservatively
            bigobj = self.nonlarge_max + 1
            self.max_number_of_pinned_objects = self.nursery_size / (bigobj * 2)

    def enable(self):
        self.enabled = True

    def disable(self):
        self.enabled = False

    def isenabled(self):
        return self.enabled

    def _nursery_memory_size(self):
        extra = self.nonlarge_max + 1
        return self.nursery_size + extra

    def _alloc_nursery(self):
        # the start of the nursery: we actually allocate a bit more for
        # the nursery than really needed, to simplify pointer arithmetic
        # in malloc_fixedsize().  The few extra pages are never used
        # anyway so it doesn't even count.
        nursery = llarena.arena_malloc(self._nursery_memory_size(), 0)
        if not nursery:
            out_of_memory("cannot allocate nursery")
        return nursery

    def allocate_nursery(self):
        debug_start("gc-set-nursery-size")
        debug_print("nursery size:", self.nursery_size)
        self.nursery = self._alloc_nursery()
        # the current position in the nursery:
        self.nursery_free = self.nursery
        # the end of the nursery:
        self.nursery_top = self.nursery + self.nursery_size
        # initialize the threshold
        self.min_heap_size = max(self.min_heap_size, self.nursery_size *
                                              self.major_collection_threshold)
        # the following two values are usually equal, but during raw mallocs
        # with memory pressure accounting, next_major_collection_threshold
        # is decremented to make the next major collection arrive earlier.
        # See translator/c/test/test_newgc, test_nongc_attached_to_gc
        self.next_major_collection_initial = self.min_heap_size
        self.next_major_collection_threshold = self.min_heap_size
        self.set_major_threshold_from(0.0)
        ll_assert(self.extra_threshold == 0, "extra_threshold set too early")
        debug_stop("gc-set-nursery-size")


    def set_major_threshold_from(self, threshold, reserving_size=0):
        # Set the next_major_collection_threshold.
        threshold_max = (self.next_major_collection_initial *
                         self.growth_rate_max)
        if threshold > threshold_max:
            threshold = threshold_max
        #
        threshold += reserving_size
        if threshold < self.min_heap_size:
            threshold = self.min_heap_size
        #
        if self.max_heap_size > 0.0 and threshold > self.max_heap_size:
            threshold = self.max_heap_size
            bounded = True
        else:
            bounded = False
        #
        self.next_major_collection_initial = threshold
        self.next_major_collection_threshold = threshold
        return bounded


    def post_setup(self):
        # set up extra stuff for PYPY_GC_DEBUG.
        MovingGCBase.post_setup(self)
        if self.DEBUG and llarena.has_protect:
            # gc debug mode: allocate 7 nurseries instead of just 1,
            # and use them alternatively, while mprotect()ing the unused
            # ones to detect invalid access.
            debug_start("gc-debug")
            self.debug_rotating_nurseries = lltype.malloc(
                NURSARRAY, 6, flavor='raw', track_allocation=False)
            i = 0
            while i < 6:
                nurs = self._alloc_nursery()
                llarena.arena_protect(nurs, self._nursery_memory_size(), True)
                self.debug_rotating_nurseries[i] = nurs
                i += 1
            debug_print("allocated", len(self.debug_rotating_nurseries),
                        "extra nurseries")
            debug_stop("gc-debug")

    def debug_rotate_nursery(self):
        if self.debug_rotating_nurseries:
            debug_start("gc-debug")
            oldnurs = self.nursery
            llarena.arena_protect(oldnurs, self._nursery_memory_size(), True)
            #
            newnurs = self.debug_rotating_nurseries[0]
            i = 0
            while i < len(self.debug_rotating_nurseries) - 1:
                self.debug_rotating_nurseries[i] = (
                    self.debug_rotating_nurseries[i + 1])
                i += 1
            self.debug_rotating_nurseries[i] = oldnurs
            #
            llarena.arena_protect(newnurs, self._nursery_memory_size(), False)
            self.nursery = newnurs
            self.nursery_top = self.nursery + self.nursery_size
            debug_print("switching from nursery", oldnurs,
                        "to nursery", self.nursery,
                        "size", self.nursery_size)
            debug_stop("gc-debug")


    def malloc_fixedsize(self, typeid, size,
                               needs_finalizer=False,
                               is_finalizer_light=False,
                               contains_weakptr=False):
        size_gc_header = self.gcheaderbuilder.size_gc_header
        totalsize = size_gc_header + size
        rawtotalsize = raw_malloc_usage(totalsize)
        #
        # If the object needs a finalizer, ask for a rawmalloc.
        # The following check should be constant-folded.
        if needs_finalizer and not is_finalizer_light:
            # old-style finalizers only!
            ll_assert(not contains_weakptr,
                     "'needs_finalizer' and 'contains_weakptr' both specified")
            obj = self.external_malloc(typeid, 0, alloc_young=False)
            res = llmemory.cast_adr_to_ptr(obj, llmemory.GCREF)
            self.register_finalizer(-1, res)
            return res
        #
        # If totalsize is greater than nonlarge_max (which should never be
        # the case in practice), ask for a rawmalloc.  The following check
        # should be constant-folded.
        if rawtotalsize > self.nonlarge_max:
            ll_assert(not contains_weakptr,
                      "'contains_weakptr' specified for a large object")
            obj = self.external_malloc(typeid, 0, alloc_young=True)
            #
        else:
            # If totalsize is smaller than minimal_size_in_nursery, round it
            # up.  The following check should also be constant-folded.
            min_size = raw_malloc_usage(self.minimal_size_in_nursery)
            if rawtotalsize < min_size:
                totalsize = rawtotalsize = min_size
            #
            # Get the memory from the nursery.  If there is not enough space
            # there, do a collect first.
            result = self.nursery_free
            ll_assert(result != llmemory.NULL, "uninitialized nursery")
            self.nursery_free = new_free = result + totalsize
            if new_free > self.nursery_top:
                result = self.collect_and_reserve(totalsize)
            #
            # Build the object.
            llarena.arena_reserve(result, totalsize)
            obj = result + size_gc_header
            self.init_gc_object(result, typeid, flags=0)
        #
        # If it is a weakref or has a lightweight destructor, record it
        # (checks constant-folded).
        if needs_finalizer:
            self.young_objects_with_destructors.append(obj)
        if contains_weakptr:
            self.young_objects_with_weakrefs.append(obj)
        return llmemory.cast_adr_to_ptr(obj, llmemory.GCREF)


    def malloc_varsize(self, typeid, length, size, itemsize,
                             offset_to_length):
        size_gc_header = self.gcheaderbuilder.size_gc_header
        nonvarsize = size_gc_header + size
        #
        # Compute the maximal length that makes the object still
        # below 'nonlarge_max'.  All the following logic is usually
        # constant-folded because self.nonlarge_max, size and itemsize
        # are all constants (the arguments are constant due to
        # inlining).
        maxsize = self.nonlarge_max - raw_malloc_usage(nonvarsize)
        if maxsize < 0:
            toobig = r_uint(0)    # the nonvarsize alone is too big
        elif raw_malloc_usage(itemsize):
            toobig = r_uint(maxsize // raw_malloc_usage(itemsize)) + 1
        else:
            toobig = r_uint(sys.maxint) + 1

        if r_uint(length) >= r_uint(toobig):
            #
            # If the total size of the object would be larger than
            # 'nonlarge_max', then allocate it externally.  We also
            # go there if 'length' is actually negative.
            obj = self.external_malloc(typeid, length, alloc_young=True)
            #
        else:
            # With the above checks we know now that totalsize cannot be more
            # than 'nonlarge_max'; in particular, the + and * cannot overflow.
            totalsize = nonvarsize + itemsize * length
            totalsize = llarena.round_up_for_allocation(totalsize)
            #
            # 'totalsize' should contain at least the GC header and
            # the length word, so it should never be smaller than
            # 'minimal_size_in_nursery'
            ll_assert(raw_malloc_usage(totalsize) >=
                      raw_malloc_usage(self.minimal_size_in_nursery),
                      "malloc_varsize(): totalsize < minimalsize")
            #
            # Get the memory from the nursery.  If there is not enough space
            # there, do a collect first.
            result = self.nursery_free
            ll_assert(result != llmemory.NULL, "uninitialized nursery")
            self.nursery_free = new_free = result + totalsize
            if new_free > self.nursery_top:
                result = self.collect_and_reserve(totalsize)
            #
            # Build the object.
            llarena.arena_reserve(result, totalsize)
            self.init_gc_object(result, typeid, flags=0)
            #
            # Set the length and return the object.
            obj = result + size_gc_header
            (obj + offset_to_length).signed[0] = length
        #
        return llmemory.cast_adr_to_ptr(obj, llmemory.GCREF)


    def malloc_fixed_or_varsize_nonmovable(self, typeid, length):
        # length==0 for fixedsize
        obj = self.external_malloc(typeid, length, alloc_young=True)
        return llmemory.cast_adr_to_ptr(obj, llmemory.GCREF)

    def move_out_of_nursery(self, obj):
        # called twice, it should return the same shadow object,
        # and not creating another shadow object.  As a safety feature,
        # when called on a non-nursery object, do nothing.
        if not self.is_in_nursery(obj):
            return obj
        shadow = self._find_shadow(obj)
        if (self.header(obj).tid & GCFLAG_SHADOW_INITIALIZED) == 0:
            self.header(obj).tid |= GCFLAG_SHADOW_INITIALIZED
            totalsize = self.get_size(obj)
            llmemory.raw_memcopy(obj, shadow, totalsize)
        return shadow

    def collect(self, gen=2):
        """Do a minor (gen=0), start a major (gen=1), or do a full
        major (gen>=2) collection."""
        if gen < 0:
            # Dangerous! this makes no progress on the major GC cycle.
            # If called too often, the memory usage will keep increasing,
            # because we'll never completely fill the nursery (and so
            # never run anything about the major collection).
            self._minor_collection()
        elif gen == 0:
            # This runs a minor collection.  This is basically what occurs
            # when the nursery is full.  If a major collection is in
            # progress, it also runs one more step of it.  It might also
            # decide to start a major collection just now, depending on
            # current memory pressure.
            self.minor_collection_with_major_progress(force_enabled=True)
        elif gen == 1:
            # This is like gen == 0, but if no major collection is running,
            # then it forces one to start now.
            self.minor_collection_with_major_progress(force_enabled=True)
            if self.gc_state == STATE_SCANNING:
                self.major_collection_step()
        else:
            # This does a complete minor and major collection.
            self.minor_and_major_collection()
        self.rrc_invoke_callback()

    def collect_step(self):
        """
        Do a single major collection step. Return True when the major collection
        is completed.

        This is meant to be used together with gc.disable(), to have a
        fine-grained control on when the GC runs.
        """
        old_state = self.gc_state
        self._minor_collection()
        self.major_collection_step()
        self.rrc_invoke_callback()
        return rgc._encode_states(old_state, self.gc_state)

    def minor_collection_with_major_progress(self, extrasize=0,
                                             force_enabled=False):
        """Do a minor collection.  Then, if the GC is enabled and there
        is already a major GC in progress, run at least one major collection
        step.  If there is no major GC but the threshold is reached, start a
        major GC.
        """
        self._minor_collection()
        if not self.enabled and not force_enabled:
            return

        # If the gc_state is STATE_SCANNING, we're not in the middle
        # of an incremental major collection.  In that case, wait
        # until there is too much garbage before starting the next
        # major collection.  But if we are in the middle of an
        # incremental major collection, then always do (at least) one
        # step now.
        #
        # Within a major collection cycle, every call to
        # major_collection_step() increments
        # 'threshold_objects_made_old' by nursery_size/2.

        if self.gc_state != STATE_SCANNING or self.threshold_reached(extrasize):
            self.major_collection_step(extrasize)

            # See documentation in major_collection_step() for target invariants
            while self.gc_state != STATE_SCANNING:    # target (A1)
                threshold = self.threshold_objects_made_old
                if threshold >= r_uint(extrasize):
                    threshold -= r_uint(extrasize)     # (*)
                    if self.size_objects_made_old <= threshold:   # target (A2)
                        break
                    # Note that target (A2) is tweaked by (*); see
                    # test_gc_set_max_heap_size in translator/c, test_newgc.py

                self._minor_collection()
                self.major_collection_step(extrasize)

        self.rrc_invoke_callback()


    def collect_and_reserve(self, totalsize):
        """To call when nursery_free overflows nursery_top.
        First check if pinned objects are in front of nursery_top. If so,
        jump over the pinned object and try again to reserve totalsize.
        Otherwise do a minor collection, and possibly some steps of a
        major collection, and finally reserve totalsize bytes.
        """

        minor_collection_count = 0
        while True:
            self.nursery_free = llmemory.NULL      # debug: don't use me
            # note: no "raise MemoryError" between here and the next time
            # we initialize nursery_free!

            if self.nursery_barriers.non_empty():
                # Pinned object in front of nursery_top. Try reserving totalsize
                # by jumping into the next, yet unused, area inside the
                # nursery. "Next area" in this case is the space between the
                # pinned object in front of nusery_top and the pinned object
                # after that. Graphically explained:
                # 
                #     |- allocating totalsize failed in this area
                #     |     |- nursery_top
                #     |     |    |- pinned object in front of nursery_top,
                #     v     v    v  jump over this
                # +---------+--------+--------+--------+-----------+ }
                # | used    | pinned | empty  | pinned |  empty    | }- nursery
                # +---------+--------+--------+--------+-----------+ }
                #                       ^- try reserving totalsize in here next
                #
                # All pinned objects are represented by entries in
                # nursery_barriers (see minor_collection). The last entry is
                # always the end of the nursery. Therefore if nursery_barriers
                # contains only one element, we jump over a pinned object and
                # the "next area" (the space where we will try to allocate
                # totalsize) starts at the end of the pinned object and ends at
                # nursery's end.
                #
                # find the size of the pinned object after nursery_top
                size_gc_header = self.gcheaderbuilder.size_gc_header
                pinned_obj_size = size_gc_header + self.get_size(
                        self.nursery_top + size_gc_header)
                #
                # update used nursery space to allocate objects
                self.nursery_free = self.nursery_top + pinned_obj_size
                self.nursery_top = self.nursery_barriers.popleft()
            else:
                minor_collection_count += 1
                if minor_collection_count == 1:
                    self.minor_collection_with_major_progress()
                else:
                    # Nursery too full again.  This is likely because of
                    # execute_finalizers() or rrc_invoke_callback().
                    # we need to fix it with another call to minor_collection()
                    # ---this time only the minor part so that we are sure that
                    # the nursery is empty (apart from pinned objects).
                    #
                    # Note that this still works with the counters:
                    # 'size_objects_made_old' will be increased by
                    # the _minor_collection() below.  We don't
                    # immediately restore the target invariant that
                    # 'size_objects_made_old <= threshold_objects_made_old'.
                    # But we will do it in the next call to
                    # minor_collection_with_major_progress().
                    #
                    ll_assert(minor_collection_count == 2,
                              "Calling minor_collection() twice is not "
                              "enough. Too many pinned objects?")
                    self._minor_collection()
            #
            # Tried to do something about nursery_free overflowing
            # nursery_top before this point. Try to reserve totalsize now.
            # If this succeeds break out of loop.
            result = self.nursery_free
            if self.nursery_free + totalsize <= self.nursery_top:
                self.nursery_free = result + totalsize
                ll_assert(self.nursery_free <= self.nursery_top, "nursery overflow")
                break
            #
        #
        if self.debug_tiny_nursery >= 0:   # for debugging
            if self.nursery_top - self.nursery_free > self.debug_tiny_nursery:
                self.nursery_free = self.nursery_top - self.debug_tiny_nursery
        #
        return result
    collect_and_reserve._dont_inline_ = True


    # XXX kill alloc_young and make it always True
    def external_malloc(self, typeid, length, alloc_young):
        """Allocate a large object using the ArenaCollection or
        raw_malloc(), possibly as an object with card marking enabled,
        if it has gc pointers in its var-sized part.  'length' should be
        specified as 0 if the object is not varsized.  The returned
        object is fully initialized, but not zero-filled."""
        #
        # Here we really need a valid 'typeid', not 0 (as the JIT might
        # try to send us if there is still a bug).
        ll_assert(bool(self.combine(typeid, 0)),
                  "external_malloc: typeid == 0")
        #
        # Compute the total size, carefully checking for overflows.
        size_gc_header = self.gcheaderbuilder.size_gc_header
        nonvarsize = size_gc_header + self.fixed_size(typeid)
        if length == 0:
            # this includes the case of fixed-size objects, for which we
            # should not even ask for the varsize_item_sizes().
            totalsize = nonvarsize
        elif length > 0:
            # var-sized allocation with at least one item
            itemsize = self.varsize_item_sizes(typeid)
            try:
                varsize = ovfcheck(itemsize * length)
                totalsize = ovfcheck(nonvarsize + varsize)
            except OverflowError:
                raise MemoryError
        else:
            # negative length!  This likely comes from an overflow
            # earlier.  We will just raise MemoryError here.
            raise MemoryError
        #
        # If somebody calls this function a lot, we must eventually
        # force a collection.  We use threshold_reached(), which might
        # be true now but become false at some point after a few calls
        # to major_collection_step().  If there is really no memory,
        # then when the major collection finishes it will raise
        # MemoryError.
        if self.threshold_reached(raw_malloc_usage(totalsize)):
            self.minor_collection_with_major_progress(
                raw_malloc_usage(totalsize) + self.nursery_size // 2)
        #
        # Check if the object would fit in the ArenaCollection.
        # Also, an object allocated from ArenaCollection must be old.
        if (raw_malloc_usage(totalsize) <= self.small_request_threshold
            and not alloc_young):
            #
            # Yes.  Round up 'totalsize' (it cannot overflow and it
            # must remain <= self.small_request_threshold.)
            totalsize = llarena.round_up_for_allocation(totalsize)
            ll_assert(raw_malloc_usage(totalsize) <=
                      self.small_request_threshold,
                      "rounding up made totalsize > small_request_threshold")
            #
            # Allocate from the ArenaCollection.  Don't clear it.
            result = self.ac.malloc(totalsize)
            #
            extra_flags = GCFLAG_TRACK_YOUNG_PTRS
            #
        else:
            # No, so proceed to allocate it externally with raw_malloc().
            # Check if we need to introduce the card marker bits area.
            if (self.card_page_indices <= 0  # <- this check is constant-folded
                or not self.has_gcptr_in_varsize(typeid) or
                raw_malloc_usage(totalsize) <= self.nonlarge_max):
                #
                # In these cases, we don't want a card marker bits area.
                # This case also includes all fixed-size objects.
                cardheadersize = 0
                extra_flags = 0
                #
            else:
                # Reserve N extra words containing card bits before the object.
                extra_words = self.card_marking_words_for_length(length)
                cardheadersize = WORD * extra_words
                extra_flags = GCFLAG_HAS_CARDS | GCFLAG_TRACK_YOUNG_PTRS
                # if 'alloc_young', then we also immediately set
                # GCFLAG_CARDS_SET, but without adding the object to
                # 'old_objects_with_cards_set'.  In this way it should
                # never be added to that list as long as it is young.
                if alloc_young:
                    extra_flags |= GCFLAG_CARDS_SET
            #
            # Detect very rare cases of overflows
            if raw_malloc_usage(totalsize) > (sys.maxint - (WORD-1)
                                              - cardheadersize):
                raise MemoryError("rare case of overflow")
            #
            # Now we know that the following computations cannot overflow.
            # Note that round_up_for_allocation() is also needed to get the
            # correct number added to 'rawmalloced_total_size'.
            allocsize = (cardheadersize + raw_malloc_usage(
                            llarena.round_up_for_allocation(totalsize)))
            #
            # Allocate the object using arena_malloc(), which we assume here
            # is just the same as raw_malloc(), but allows the extra
            # flexibility of saying that we have extra words in the header.
            # The memory returned is not cleared.
            arena = llarena.arena_malloc(allocsize, 0)
            if not arena:
                raise MemoryError("cannot allocate large object")
            #
            # Reserve the card mark bits as a list of single bytes,
            # and clear these bytes.
            i = 0
            while i < cardheadersize:
                p = arena + i
                llarena.arena_reserve(p, llmemory.sizeof(lltype.Char))
                p.char[0] = '\x00'
                i += 1
            #
            # Reserve the actual object.  (This is a no-op in C).
            result = arena + cardheadersize
            llarena.arena_reserve(result, totalsize)
            #
            # Record the newly allocated object and its full malloced size.
            # The object is young or old depending on the argument.
            self.rawmalloced_total_size += r_uint(allocsize)
            self.rawmalloced_peak_size = max(self.rawmalloced_total_size,
                                             self.rawmalloced_peak_size)
            if alloc_young:
                if not self.young_rawmalloced_objects:
                    self.young_rawmalloced_objects = self.AddressDict()
                self.young_rawmalloced_objects.add(result + size_gc_header)
            else:
                self.old_rawmalloced_objects.append(result + size_gc_header)
                extra_flags |= GCFLAG_TRACK_YOUNG_PTRS
        #
        # Common code to fill the header and length of the object.
        self.init_gc_object(result, typeid, extra_flags)
        if self.is_varsize(typeid):
            offset_to_length = self.varsize_offset_to_length(typeid)
            (result + size_gc_header + offset_to_length).signed[0] = length
        return result + size_gc_header


    # ----------
    # Other functions in the GC API

    def set_max_heap_size(self, size):
        self.max_heap_size = float(size)
        if self.max_heap_size > 0.0:
            if self.max_heap_size < self.next_major_collection_initial:
                self.next_major_collection_initial = self.max_heap_size
            if self.max_heap_size < self.next_major_collection_threshold:
                self.next_major_collection_threshold = self.max_heap_size

    def raw_malloc_memory_pressure(self, sizehint, adr):
        # Decrement by 'sizehint' plus a very little bit extra.  This
        # is needed e.g. for _rawffi, which may allocate a lot of tiny
        # arrays.
        self.next_major_collection_threshold -= (sizehint + 2 * WORD)
        if self.next_major_collection_threshold < 0:
            # cannot trigger a full collection now, but we can ensure
            # that one will occur very soon
            self.nursery_free = self.nursery_top

    def can_optimize_clean_setarrayitems(self):
        if self.card_page_indices > 0:
            return False
        return MovingGCBase.can_optimize_clean_setarrayitems(self)

    def can_move(self, obj):
        """Overrides the parent can_move()."""
        return self.is_in_nursery(obj)

    def pin(self, obj):
        if self.pinned_objects_in_nursery >= self.max_number_of_pinned_objects:
            return False
        if not self.is_in_nursery(obj):
            # old objects are already non-moving, therefore pinning
            # makes no sense. If you run into this case, you may forgot
            # to check can_move(obj).
            return False
        if self._is_pinned(obj):
            # already pinned, we do not allow to pin it again.
            # Reason: It would be possible that the first caller unpins
            # while the second caller thinks it's still pinned.
            return False
        #
        obj_type_id = self.get_type_id(obj)
        if self.cannot_pin(obj_type_id):
            # objects containing GC pointers can't be pinned. If we would add
            # it, we would have to track all pinned objects and trace them
            # every minor collection to make sure the referenced object are
            # kept alive. Right now this is not a use case that's needed.
            # The check above also tests for being a less common kind of
            # object: a weakref, or one with any kind of finalizer.
            return False
        #
        self.header(obj).tid |= GCFLAG_PINNED
        self.pinned_objects_in_nursery += 1
        return True


    def unpin(self, obj):
        ll_assert(self._is_pinned(obj),
            "unpin: object is already not pinned")
        #
        self.header(obj).tid &= ~GCFLAG_PINNED
        self.pinned_objects_in_nursery -= 1

    def _is_pinned(self, obj):
        return (self.header(obj).tid & GCFLAG_PINNED) != 0

    def shrink_array(self, obj, smallerlength):
        #
        # Only objects in the nursery can be "resized".  Resizing them
        # means recording that they have a smaller size, so that when
        # moved out of the nursery, they will consume less memory.
        # In particular, an array with GCFLAG_HAS_CARDS is never resized.
        # Also, a nursery object with GCFLAG_HAS_SHADOW is not resized
        # either, as this would potentially loose part of the memory in
        # the already-allocated shadow.
        if not self.is_in_nursery(obj):
            return False
        if self.header(obj).tid & GCFLAG_HAS_SHADOW:
            return False
        #
        size_gc_header = self.gcheaderbuilder.size_gc_header
        typeid = self.get_type_id(obj)
        totalsmallersize = (
            size_gc_header + self.fixed_size(typeid) +
            self.varsize_item_sizes(typeid) * smallerlength)
        llarena.arena_shrink_obj(obj - size_gc_header, totalsmallersize)
        #
        offset_to_length = self.varsize_offset_to_length(typeid)
        (obj + offset_to_length).signed[0] = smallerlength
        return True

    # ----------
    # Simple helpers

    def get_type_id(self, obj):
        tid = self.header(obj).tid
        return llop.extract_ushort(llgroup.HALFWORD, tid)

    def combine(self, typeid16, flags):
        return llop.combine_ushort(lltype.Signed, typeid16, flags)

    def init_gc_object(self, addr, typeid16, flags=0):
        # The default 'flags' is zero.  The flags GCFLAG_NO_xxx_PTRS
        # have been chosen to allow 'flags' to be zero in the common
        # case (hence the 'NO' in their name).
        hdr = llmemory.cast_adr_to_ptr(addr, lltype.Ptr(self.HDR))
        hdr.tid = self.combine(typeid16, flags)

    def init_gc_object_immortal(self, addr, typeid16, flags=0):
        # For prebuilt GC objects, the flags must contain
        # GCFLAG_NO_xxx_PTRS, at least initially.
        flags |= GCFLAG_NO_HEAP_PTRS | GCFLAG_TRACK_YOUNG_PTRS
        self.init_gc_object(addr, typeid16, flags)

    def is_in_nursery(self, addr):
        ll_assert(llmemory.cast_adr_to_int(addr) & 1 == 0,
                  "odd-valued (i.e. tagged) pointer unexpected here")
        return self.nursery <= addr < self.nursery + self.nursery_size

    def is_young_object(self, addr):
        # Check if the object at 'addr' is young.
        if not self.is_valid_gc_object(addr):
            return False     # filter out tagged pointers explicitly.
        if self.is_in_nursery(addr):
            return True      # addr is in the nursery
        # Else, it may be in the set 'young_rawmalloced_objects'
        return (bool(self.young_rawmalloced_objects) and
                self.young_rawmalloced_objects.contains(addr))

    def debug_is_old_object(self, addr):
        return (self.is_valid_gc_object(addr)
                and not self.is_young_object(addr))

    def is_forwarded(self, obj):
        """Returns True if the nursery obj is marked as forwarded.
        Implemented a bit obscurely by checking an unrelated flag
        that can never be set on a young object -- except if tid == -42.
        """
        ll_assert(self.is_in_nursery(obj),
                  "Can't forward an object outside the nursery.")
        tid = self.header(obj).tid
        result = (tid & GCFLAG_FINALIZATION_ORDERING != 0)
        if result:
            ll_assert(tid == -42, "bogus header for young obj")
        else:
            ll_assert(bool(tid), "bogus header (1)")
            ll_assert(tid & -_GCFLAG_FIRST_UNUSED == 0, "bogus header (2)")
        return result

    def get_forwarding_address(self, obj):
        return llmemory.cast_adr_to_ptr(obj, FORWARDSTUBPTR).forw

    def get_possibly_forwarded_type_id(self, obj):
        if self.is_in_nursery(obj) and self.is_forwarded(obj):
            obj = self.get_forwarding_address(obj)
        return self.get_type_id(obj)

    def get_possibly_forwarded_tid(self, obj):
        if self.is_in_nursery(obj) and self.is_forwarded(obj):
            obj = self.get_forwarding_address(obj)
        return self.header(obj).tid

    def get_total_memory_used(self):
        """Return the total memory used, not counting any object in the
        nursery: only objects in the ArenaCollection or raw-malloced.
        """
        return self.ac.total_memory_used + self.rawmalloced_total_size

    def get_total_memory_alloced(self):
        """ Return the total memory allocated
        """
        return self.ac.total_memory_alloced + self.rawmalloced_total_size

    def get_peak_memory_alloced(self):
        """ Return the peak memory ever allocated. The peaks
        can be at different times, but we just don't worry for now
        """
        return self.ac.peak_memory_alloced + self.rawmalloced_peak_size

    def get_peak_memory_used(self):
        """ Return the peak memory GC felt ever responsible for
        """
        mem_allocated = max(self.ac.peak_memory_used,
                            self.ac.total_memory_used)
        return mem_allocated + self.rawmalloced_peak_size

    def threshold_reached(self, extra=0):
        return (self.next_major_collection_threshold -
                float(self.get_total_memory_used())) < float(extra)

    def card_marking_words_for_length(self, length):
        # --- Unoptimized version:
        #num_bits = ((length-1) >> self.card_page_shift) + 1
        #return (num_bits + (LONG_BIT - 1)) >> LONG_BIT_SHIFT
        # --- Optimized version:
        return intmask(
          ((r_uint(length) + r_uint((LONG_BIT << self.card_page_shift) - 1)) >>
           (self.card_page_shift + LONG_BIT_SHIFT)))

    def card_marking_bytes_for_length(self, length):
        # --- Unoptimized version:
        #num_bits = ((length-1) >> self.card_page_shift) + 1
        #return (num_bits + 7) >> 3
        # --- Optimized version:
        return intmask(
            ((r_uint(length) + r_uint((8 << self.card_page_shift) - 1)) >>
             (self.card_page_shift + 3)))

    def debug_check_consistency(self):
        if self.DEBUG:
            ll_assert(not self.young_rawmalloced_objects,
                      "young raw-malloced objects in a major collection")
            ll_assert(not self.young_objects_with_weakrefs.non_empty(),
                      "young objects with weakrefs in a major collection")

            if self.raw_malloc_might_sweep.non_empty():
                ll_assert(self.gc_state == STATE_SWEEPING,
                      "raw_malloc_might_sweep must be empty outside SWEEPING")

            if self.gc_state == STATE_MARKING:
                self.objects_to_trace.foreach(self._check_not_in_nursery, None)
                self.more_objects_to_trace.foreach(self._check_not_in_nursery,
                                                   None)
                self._debug_objects_to_trace_dict1 = \
                                            self.objects_to_trace.stack2dict()
                self._debug_objects_to_trace_dict2 = \
                                       self.more_objects_to_trace.stack2dict()
                MovingGCBase.debug_check_consistency(self)
                self._debug_objects_to_trace_dict2.delete()
                self._debug_objects_to_trace_dict1.delete()
            else:
                MovingGCBase.debug_check_consistency(self)

    def _check_not_in_nursery(self, obj, ignore):
        ll_assert(not self.is_in_nursery(obj),
                  "'objects_to_trace' contains a nursery object")

    def debug_check_object(self, obj):
        # We are after a minor collection, and possibly after a major
        # collection step.  No object should be in the nursery (except
        # pinned ones)
        if not self._is_pinned(obj):
            ll_assert(not self.is_in_nursery(obj),
                      "object in nursery after collection")
            ll_assert(self.header(obj).tid & GCFLAG_VISITED_RMY == 0,
                      "GCFLAG_VISITED_RMY after collection")
            ll_assert(self.header(obj).tid & GCFLAG_PINNED == 0,
                      "GCFLAG_PINNED outside the nursery after collection")
        else:
            ll_assert(self.is_in_nursery(obj),
                      "pinned object not in nursery")

        if self.gc_state == STATE_SCANNING:
            self._debug_check_object_scanning(obj)
        elif self.gc_state == STATE_MARKING:
            self._debug_check_object_marking(obj)
        elif self.gc_state == STATE_SWEEPING:
            self._debug_check_object_sweeping(obj)
        elif self.gc_state == STATE_FINALIZING:
            self._debug_check_object_finalizing(obj)
        else:
            ll_assert(False, "unknown gc_state value")

    def _debug_check_object_marking(self, obj):
        if self.header(obj).tid & GCFLAG_VISITED != 0:
            # A black object.  Should NEVER point to a white object.
            self.trace(obj, self._debug_check_not_white, None)
            # During marking, all visited (black) objects should always have
            # the GCFLAG_TRACK_YOUNG_PTRS flag set, for the write barrier to
            # trigger --- at least if they contain any gc ptr.  We are just
            # after a minor or major collection here, so we can't see the
            # object state VISITED & ~WRITE_BARRIER.
            typeid = self.get_type_id(obj)
            if self.has_gcptr(typeid):
                ll_assert(self.header(obj).tid & GCFLAG_TRACK_YOUNG_PTRS != 0,
                          "black object without GCFLAG_TRACK_YOUNG_PTRS")

    def _debug_check_not_white(self, root, ignored):
        obj = root.address[0]
        if self.header(obj).tid & GCFLAG_VISITED != 0:
            pass    # black -> black
        elif (self._debug_objects_to_trace_dict1.contains(obj) or
              self._debug_objects_to_trace_dict2.contains(obj)):
            pass    # black -> gray
        elif self.header(obj).tid & GCFLAG_NO_HEAP_PTRS != 0:
            pass    # black -> white-but-prebuilt-so-dont-care
        elif self._is_pinned(obj):
            # black -> pinned: the pinned object is a white one as
            # every minor collection visits them and takes care of
            # visiting pinned objects.
            # XXX (groggi) double check with fijal/armin
            pass    # black -> pinned
        else:
            ll_assert(False, "black -> white pointer found")

    def _debug_check_object_sweeping(self, obj):
        # We see only reachable objects here.  They all start as VISITED
        # but this flag is progressively removed in the sweeping phase.

        # All objects should have this flag, except if they
        # don't have any GC pointer or are pinned objects
        typeid = self.get_type_id(obj)
        if self.has_gcptr(typeid) and not self._is_pinned(obj):
            ll_assert(self.header(obj).tid & GCFLAG_TRACK_YOUNG_PTRS != 0,
                      "missing GCFLAG_TRACK_YOUNG_PTRS")
        # the GCFLAG_FINALIZATION_ORDERING should not be set between coll.
        ll_assert(self.header(obj).tid & GCFLAG_FINALIZATION_ORDERING == 0,
                  "unexpected GCFLAG_FINALIZATION_ORDERING")
        # the GCFLAG_CARDS_SET should not be set between collections
        ll_assert(self.header(obj).tid & GCFLAG_CARDS_SET == 0,
                  "unexpected GCFLAG_CARDS_SET")
        # if the GCFLAG_HAS_CARDS is set, check that all bits are zero now
        if self.header(obj).tid & GCFLAG_HAS_CARDS:
            if self.card_page_indices <= 0:
                ll_assert(False, "GCFLAG_HAS_CARDS but not using card marking")
                return
            typeid = self.get_type_id(obj)
            ll_assert(self.has_gcptr_in_varsize(typeid),
                      "GCFLAG_HAS_CARDS but not has_gcptr_in_varsize")
            ll_assert(self.header(obj).tid & GCFLAG_NO_HEAP_PTRS == 0,
                      "GCFLAG_HAS_CARDS && GCFLAG_NO_HEAP_PTRS")
            offset_to_length = self.varsize_offset_to_length(typeid)
            length = (obj + offset_to_length).signed[0]
            extra_words = self.card_marking_words_for_length(length)
            #
            size_gc_header = self.gcheaderbuilder.size_gc_header
            p = llarena.getfakearenaaddress(obj - size_gc_header)
            i = extra_words * WORD
            while i > 0:
                p -= 1
                ll_assert(p.char[0] == '\x00',
                          "the card marker bits are not cleared")
                i -= 1

    def _debug_check_object_finalizing(self, obj):
        # Same invariants as STATE_SCANNING.
        self._debug_check_object_scanning(obj)

    def _debug_check_object_scanning(self, obj):
        # This check is called before scanning starts.
        # Scanning is done in a single step.
        # the GCFLAG_VISITED should not be set between collections
        ll_assert(self.header(obj).tid & GCFLAG_VISITED == 0,
                  "unexpected GCFLAG_VISITED")

        # All other invariants from the sweeping phase should still be
        # satisfied.
        self._debug_check_object_sweeping(obj)


    # ----------
    # Write barrier

    # for the JIT: a minimal description of the write_barrier() method
    # (the JIT assumes it is of the shape
    #  "if addr_struct.int0 & JIT_WB_IF_FLAG: remember_young_pointer()")
    JIT_WB_IF_FLAG = GCFLAG_TRACK_YOUNG_PTRS

    # for the JIT to generate custom code corresponding to the array
    # write barrier for the simplest case of cards.  If JIT_CARDS_SET
    # is already set on an object, it will execute code like this:
    #    MOV eax, index
    #    SHR eax, JIT_WB_CARD_PAGE_SHIFT
    #    XOR eax, -8
    #    BTS [object], eax
    if TRANSLATION_PARAMS['card_page_indices'] > 0:
        JIT_WB_CARDS_SET = GCFLAG_CARDS_SET
        JIT_WB_CARD_PAGE_SHIFT = 1
        while ((1 << JIT_WB_CARD_PAGE_SHIFT) !=
               TRANSLATION_PARAMS['card_page_indices']):
            JIT_WB_CARD_PAGE_SHIFT += 1

    @classmethod
    def JIT_max_size_of_young_obj(cls):
        return cls.TRANSLATION_PARAMS['large_object']

    @classmethod
    def JIT_minimal_size_in_nursery(cls):
        return cls.minimal_size_in_nursery

    def write_barrier(self, addr_struct):
        # see OP_GC_BIT in translator/c/gc.py
        if llop.gc_bit(lltype.Signed, self.header(addr_struct),
                       GCFLAG_TRACK_YOUNG_PTRS):
            self.remember_young_pointer(addr_struct)

    def write_barrier_from_array(self, addr_array, index):
        if llop.gc_bit(lltype.Signed, self.header(addr_array),
                       GCFLAG_TRACK_YOUNG_PTRS):
            if self.card_page_indices > 0:
                self.remember_young_pointer_from_array2(addr_array, index)
            else:
                self.remember_young_pointer(addr_array)

    def _init_writebarrier_logic(self):
        DEBUG = self.DEBUG
        # The purpose of attaching remember_young_pointer to the instance
        # instead of keeping it as a regular method is to
        # make the code in write_barrier() marginally smaller
        # (which is important because it is inlined *everywhere*).
        def remember_young_pointer(addr_struct):
            # 'addr_struct' is the address of the object in which we write.
            # We know that 'addr_struct' has GCFLAG_TRACK_YOUNG_PTRS so far.
            #
            if DEBUG:   # note: PYPY_GC_DEBUG=1 does not enable this
                ll_assert(self.debug_is_old_object(addr_struct) or
                          self.header(addr_struct).tid & GCFLAG_HAS_CARDS != 0,
                      "young object with GCFLAG_TRACK_YOUNG_PTRS and no cards")
            #
            # We need to remove the flag GCFLAG_TRACK_YOUNG_PTRS and add
            # the object to the list 'old_objects_pointing_to_young'.
            # We know that 'addr_struct' cannot be in the nursery,
            # because nursery objects never have the flag
            # GCFLAG_TRACK_YOUNG_PTRS to start with.  Note that in
            # theory we don't need to do that if the pointer that we're
            # writing into the object isn't pointing to a young object.
            # However, it isn't really a win, because then sometimes
            # we're going to call this function a lot of times for the
            # same object; moreover we'd need to pass the 'newvalue' as
            # an argument here.  The JIT has always called a
            # 'newvalue'-less version, too.  Moreover, the incremental
            # GC nowadays relies on this fact.
            self.old_objects_pointing_to_young.append(addr_struct)
            objhdr = self.header(addr_struct)
            objhdr.tid &= ~GCFLAG_TRACK_YOUNG_PTRS
            #
            # Second part: if 'addr_struct' is actually a prebuilt GC
            # object and it's the first time we see a write to it, we
            # add it to the list 'prebuilt_root_objects'.
            if objhdr.tid & GCFLAG_NO_HEAP_PTRS:
                objhdr.tid &= ~GCFLAG_NO_HEAP_PTRS
                self.prebuilt_root_objects.append(addr_struct)

        remember_young_pointer._dont_inline_ = True
        self.remember_young_pointer = remember_young_pointer
        #
        if self.card_page_indices > 0:
            self._init_writebarrier_with_card_marker()


    def _init_writebarrier_with_card_marker(self):
        DEBUG = self.DEBUG
        def remember_young_pointer_from_array2(addr_array, index):
            # 'addr_array' is the address of the object in which we write,
            # which must have an array part;  'index' is the index of the
            # item that is (or contains) the pointer that we write.
            # We know that 'addr_array' has GCFLAG_TRACK_YOUNG_PTRS so far.
            #
            objhdr = self.header(addr_array)
            if objhdr.tid & GCFLAG_HAS_CARDS == 0:
                #
                if DEBUG:   # note: PYPY_GC_DEBUG=1 does not enable this
                    ll_assert(self.debug_is_old_object(addr_array),
                        "young array with no card but GCFLAG_TRACK_YOUNG_PTRS")
                #
                # no cards, use default logic.  Mostly copied from above.
                self.old_objects_pointing_to_young.append(addr_array)
                objhdr.tid &= ~GCFLAG_TRACK_YOUNG_PTRS
                if objhdr.tid & GCFLAG_NO_HEAP_PTRS:
                    objhdr.tid &= ~GCFLAG_NO_HEAP_PTRS
                    self.prebuilt_root_objects.append(addr_array)
                return
            #
            # 'addr_array' is a raw_malloc'ed array with card markers
            # in front.  Compute the index of the bit to set:
            bitindex = index >> self.card_page_shift
            byteindex = bitindex >> 3
            bitmask = 1 << (bitindex & 7)
            #
            # If the bit is already set, leave now.
            addr_byte = self.get_card(addr_array, byteindex)
            byte = ord(addr_byte.char[0])
            if byte & bitmask:
                return
            #
            # We set the flag (even if the newly written address does not
            # actually point to the nursery, which seems to be ok -- actually
            # it seems more important that remember_young_pointer_from_array2()
            # does not take 3 arguments).
            addr_byte.char[0] = chr(byte | bitmask)
            #
            if objhdr.tid & GCFLAG_CARDS_SET == 0:
                self.old_objects_with_cards_set.append(addr_array)
                objhdr.tid |= GCFLAG_CARDS_SET

        remember_young_pointer_from_array2._dont_inline_ = True
        ll_assert(self.card_page_indices > 0,
                  "non-positive card_page_indices")
        self.remember_young_pointer_from_array2 = (
            remember_young_pointer_from_array2)

        def jit_remember_young_pointer_from_array(addr_array):
            # minimal version of the above, with just one argument,
            # called by the JIT when GCFLAG_TRACK_YOUNG_PTRS is set
            # but GCFLAG_CARDS_SET is cleared.  This tries to set
            # GCFLAG_CARDS_SET if possible; otherwise, it falls back
            # to remember_young_pointer().
            objhdr = self.header(addr_array)
            if objhdr.tid & GCFLAG_HAS_CARDS:
                self.old_objects_with_cards_set.append(addr_array)
                objhdr.tid |= GCFLAG_CARDS_SET
            else:
                self.remember_young_pointer(addr_array)

        self.jit_remember_young_pointer_from_array = (
            jit_remember_young_pointer_from_array)

    def get_card(self, obj, byteindex):
        size_gc_header = self.gcheaderbuilder.size_gc_header
        addr_byte = obj - size_gc_header
        return llarena.getfakearenaaddress(addr_byte) + (~byteindex)


    def writebarrier_before_copy(self, source_addr, dest_addr,
                                 source_start, dest_start, length):
        """ This has the same effect as calling writebarrier over
        each element in dest copied from source, except it might reset
        one of the following flags a bit too eagerly, which means we'll have
        a bit more objects to track, but being on the safe side.
        """
        # obscuuuure.  The flag 'updated_old_objects_pointing_to_pinned'
        # is set to True when 'old_objects_pointing_to_pinned' is modified.
        # Here, when it was modified, then we do a write_barrier() on
        # all items in that list (there should only be a small number,
        # so we don't care).  The goal is that the logic that follows below
        # works as expected...
        if self.updated_old_objects_pointing_to_pinned:
            self.old_objects_pointing_to_pinned.foreach(
                self._wb_old_object_pointing_to_pinned, None)
            self.updated_old_objects_pointing_to_pinned = False
        #
        source_hdr = self.header(source_addr)
        dest_hdr = self.header(dest_addr)
        if dest_hdr.tid & GCFLAG_TRACK_YOUNG_PTRS == 0:
            return True
        # ^^^ a fast path of write-barrier
        #
        if (self.card_page_indices > 0 and     # check constant-folded
            source_hdr.tid & GCFLAG_HAS_CARDS != 0):
            #
            if source_hdr.tid & GCFLAG_TRACK_YOUNG_PTRS == 0:
                # The source object may have random young pointers.
                # Return False to mean "do it manually in ll_arraycopy".
                return False
            #
            if source_hdr.tid & GCFLAG_CARDS_SET == 0:
                # The source object has no young pointers at all.  Done.
                return True
            #
            if dest_hdr.tid & GCFLAG_HAS_CARDS == 0:
                # The dest object doesn't have cards.  Do it manually.
                return False
            #
            if source_start != 0 or dest_start != 0:
                # Misaligned.  Do it manually.
                return False
            #
            self.manually_copy_card_bits(source_addr, dest_addr, length)
            return True
        #
        if source_hdr.tid & GCFLAG_TRACK_YOUNG_PTRS == 0:
            # there might be in source a pointer to a young object
            self.old_objects_pointing_to_young.append(dest_addr)
            dest_hdr.tid &= ~GCFLAG_TRACK_YOUNG_PTRS
        #
        if dest_hdr.tid & GCFLAG_NO_HEAP_PTRS:
            if source_hdr.tid & GCFLAG_NO_HEAP_PTRS == 0:
                dest_hdr.tid &= ~GCFLAG_NO_HEAP_PTRS
                self.prebuilt_root_objects.append(dest_addr)
        return True

    def writebarrier_before_move(self, array_addr):
        """If 'array_addr' uses cards, then this has the same effect as
        a call to the generic writebarrier, effectively generalizing the
        cards to "any item may be young".
        """
        if self.card_page_indices <= 0:     # check constant-folded
            return     # no cards, nothing to do
        #
        array_hdr = self.header(array_addr)
        if array_hdr.tid & GCFLAG_CARDS_SET != 0:
            self.write_barrier(array_addr)

    def manually_copy_card_bits(self, source_addr, dest_addr, length):
        # manually copy the individual card marks from source to dest
        ll_assert(self.card_page_indices > 0,
                  "non-positive card_page_indices")
        bytes = self.card_marking_bytes_for_length(length)
        #
        anybyte = 0
        i = 0
        while i < bytes:
            addr_srcbyte = self.get_card(source_addr, i)
            addr_dstbyte = self.get_card(dest_addr, i)
            byte = ord(addr_srcbyte.char[0])
            anybyte |= byte
            addr_dstbyte.char[0] = chr(ord(addr_dstbyte.char[0]) | byte)
            i += 1
        #
        if anybyte:
            dest_hdr = self.header(dest_addr)
            if dest_hdr.tid & GCFLAG_CARDS_SET == 0:
                self.old_objects_with_cards_set.append(dest_addr)
                dest_hdr.tid |= GCFLAG_CARDS_SET

    def _wb_old_object_pointing_to_pinned(self, obj, ignore):
        self.write_barrier(obj)

    def record_pinned_object_with_shadow(self, obj, new_shadow_object_dict):
        # checks if the pinned object has a shadow and if so add it to the
        # dict of shadows.
        obj = obj + self.gcheaderbuilder.size_gc_header
        shadow = self.nursery_objects_shadows.get(obj)
        if shadow != llmemory.NULL:
            # visit shadow to keep it alive
            # XXX seems like it is save to set GCFLAG_VISITED, however
            # should be double checked
            self.header(shadow).tid |= GCFLAG_VISITED
            new_shadow_object_dict.setitem(obj, shadow)

    def register_finalizer(self, fq_index, gcobj):
        from rpython.rtyper.lltypesystem import rffi
        obj = llmemory.cast_ptr_to_adr(gcobj)
        fq_index = rffi.cast(llmemory.Address, fq_index)
        self.probably_young_objects_with_finalizers.append(obj)
        self.probably_young_objects_with_finalizers.append(fq_index)

    # ----------
    # Nursery collection

    def _minor_collection(self):
        """Perform a minor collection: find the objects from the nursery
        that remain alive and move them out."""
        #
        start = time.time()
        debug_start("gc-minor")
        #
        # All nursery barriers are invalid from this point on.  They
        # are evaluated anew as part of the minor collection.
        self.nursery_barriers.delete()
        #
        # Keeps track of surviving pinned objects. See also '_trace_drag_out()'
        # where this stack is filled.  Pinning an object only prevents it from
        # being moved, not from being collected if it is not reachable anymore.
        self.surviving_pinned_objects = self.AddressStack()
        # The following counter keeps track of alive and pinned young objects
        # inside the nursery. We reset it here and increase it in
        # '_trace_drag_out()'.
        any_pinned_object_from_earlier = self.any_pinned_object_kept
        self.pinned_objects_in_nursery = 0
        self.any_pinned_object_kept = False
        #
        # Before everything else, remove from 'old_objects_pointing_to_young'
        # the young arrays.
        if self.young_rawmalloced_objects:
            self.remove_young_arrays_from_old_objects_pointing_to_young()
        #
        # A special step in the STATE_MARKING phase.
        if self.gc_state == STATE_MARKING:
            # Copy the 'old_objects_pointing_to_young' list so far to
            # 'more_objects_to_trace'.  Turn black objects back to gray.
            # This is because these are precisely the old objects that
            # have been modified and need rescanning.
            self.old_objects_pointing_to_young.foreach(
                self._add_to_more_objects_to_trace_if_black, None)
            # Old black objects pointing to pinned objects that may no
            # longer be pinned now: careful,
            # _visit_old_objects_pointing_to_pinned() will move the
            # previously-pinned object, and that creates a white object.
            # We prevent the "black->white" situation by forcing the
            # old black object to become gray again.
            self.old_objects_pointing_to_pinned.foreach(
                self._add_to_more_objects_to_trace_if_black, None)
        #
        # First, find the roots that point to young objects.  All nursery
        # objects found are copied out of the nursery, and the occasional
        # young raw-malloced object is flagged with GCFLAG_VISITED_RMY.
        # Note that during this step, we ignore references to further
        # young objects; only objects directly referenced by roots
        # are copied out or flagged.  They are also added to the list
        # 'old_objects_pointing_to_young'.
        self.nursery_surviving_size = 0
        self.collect_roots_in_nursery(any_pinned_object_from_earlier)
        #
        # visit all objects that are known for pointing to pinned
        # objects. This way we populate 'surviving_pinned_objects'
        # with pinned object that are (only) visible from an old
        # object.
        # Additionally we create a new list as it may be that an old object
        # no longer points to a pinned one. Such old objects won't be added
        # again to 'old_objects_pointing_to_pinned'.
        if self.old_objects_pointing_to_pinned.non_empty():
            current_old_objects_pointing_to_pinned = \
                    self.old_objects_pointing_to_pinned
            self.old_objects_pointing_to_pinned = self.AddressStack()
            current_old_objects_pointing_to_pinned.foreach(
                self._visit_old_objects_pointing_to_pinned, None)
            current_old_objects_pointing_to_pinned.delete()
        #
        # visit the P list from rawrefcount, if enabled.
        if self.rrc_enabled:
            self.rrc_minor_collection_trace()
        #
        # visit the "probably young" objects with finalizers.  They
        # all survive, except if IGNORE_FINALIZER is set.
        if self.probably_young_objects_with_finalizers.non_empty():
            self.deal_with_young_objects_with_finalizers()
        #
        while True:
            # If we are using card marking, do a partial trace of the arrays
            # that are flagged with GCFLAG_CARDS_SET.
            if self.card_page_indices > 0:
                self.collect_cardrefs_to_nursery()
            #
            # Now trace objects from 'old_objects_pointing_to_young'.
            # All nursery objects they reference are copied out of the
            # nursery, and again added to 'old_objects_pointing_to_young'.
            # All young raw-malloced object found are flagged
            # GCFLAG_VISITED_RMY.
            # We proceed until 'old_objects_pointing_to_young' is empty.
            self.collect_oldrefs_to_nursery()
            #
            # We have to loop back if collect_oldrefs_to_nursery caused
            # new objects to show up in old_objects_with_cards_set
            if self.card_page_indices > 0:
                if self.old_objects_with_cards_set.non_empty():
                    continue
            break
        #
        # Now all live nursery objects should be out.  Update the young
        # weakrefs' targets.
        if self.young_objects_with_weakrefs.non_empty():
            self.invalidate_young_weakrefs()
        if self.young_objects_with_destructors.non_empty():
            self.deal_with_young_objects_with_destructors()
        #
        # Clear this mapping.  Without pinned objects we just clear the dict
        # as all objects in the nursery are dragged out of the nursery and, if
        # needed, into their shadow.  However, if we have pinned objects we have
        # to check if those pinned object have a shadow and keep a dictionary
        # filled with shadow information for them as they stay in the nursery.
        if self.nursery_objects_shadows.length() > 0:
            if self.surviving_pinned_objects.non_empty():
                new_shadows = self.AddressDict()
                self.surviving_pinned_objects.foreach(
                    self.record_pinned_object_with_shadow, new_shadows)
                self.nursery_objects_shadows.delete()
                self.nursery_objects_shadows = new_shadows
            else:
                self.nursery_objects_shadows.clear()
        #
        # visit the P and O lists from rawrefcount, if enabled.
        if self.rrc_enabled:
            self.rrc_minor_collection_free()
        #
        # Walk the list of young raw-malloced objects, and either free
        # them or make them old.
        if self.young_rawmalloced_objects:
            self.free_young_rawmalloced_objects()
        #
        # All live nursery objects are out of the nursery or pinned inside
        # the nursery.  Create nursery barriers to protect the pinned objects,
        # fill the rest of the nursery with zeros and reset the current nursery
        # pointer.
        size_gc_header = self.gcheaderbuilder.size_gc_header
        nursery_barriers = self.AddressDeque()
        prev = self.nursery
        self.surviving_pinned_objects.sort()
        ll_assert(
            self.pinned_objects_in_nursery == \
            self.surviving_pinned_objects.length(),
            "pinned_objects_in_nursery != surviving_pinned_objects.length()")
        while self.surviving_pinned_objects.non_empty():
            #
            cur = self.surviving_pinned_objects.pop()
            ll_assert(
                cur >= prev, "pinned objects encountered in backwards order")
            #
            # clear the arena between the last pinned object (or arena start)
            # and the pinned object
            free_range_size = llarena.getfakearenaaddress(cur) - prev
            if self.gc_nursery_debug:
                llarena.arena_reset(prev, free_range_size, 3)
            else:
                llarena.arena_reset(prev, free_range_size, 0)
            #
            # clean up object's flags
            obj = cur + size_gc_header
            self.header(obj).tid &= ~GCFLAG_VISITED
            #
            # create a new nursery barrier for the pinned object
            nursery_barriers.append(cur)
            #
            # update 'prev' to the end of the 'cur' object
            prev = prev + free_range_size + \
                (size_gc_header + self.get_size(obj))
        #
        # reset everything after the last pinned object till the end of the arena
        if self.gc_nursery_debug:
            llarena.arena_reset(prev, self.nursery + self.nursery_size - prev, 3)
            if not nursery_barriers.non_empty():   # no pinned objects
                self.debug_rotate_nursery()
        else:
            llarena.arena_reset(prev, self.nursery + self.nursery_size - prev, 0)
        #
        # always add the end of the nursery to the list
        nursery_barriers.append(self.nursery + self.nursery_size)
        #
        self.nursery_barriers = nursery_barriers
        self.surviving_pinned_objects.delete()
        #
        self.nursery_free = self.nursery
        self.nursery_top = self.nursery_barriers.popleft()
        #
        # clear GCFLAG_PINNED_OBJECT_PARENT_KNOWN from all parents in the list.
        self.old_objects_pointing_to_pinned.foreach(
                self._reset_flag_old_objects_pointing_to_pinned, None)
        #
        # Accounting: 'nursery_surviving_size' is the size of objects
        # from the nursery that we just moved out.
        self.size_objects_made_old += r_uint(self.nursery_surviving_size)
        #
        total_memory_used = self.get_total_memory_used()
        debug_print("minor collect, total memory used:", total_memory_used)
        debug_print("number of pinned objects:",
                    self.pinned_objects_in_nursery)
        debug_print("total size of surviving objects:", self.nursery_surviving_size)
        if self.DEBUG >= 2:
            self.debug_check_consistency()     # expensive!
        #
        self.root_walker.finished_minor_collection()
        #
        debug_stop("gc-minor")
        duration = time.time() - start
        self.total_gc_time += duration
        self.hooks.fire_gc_minor(
            duration=duration,
            total_memory_used=total_memory_used,
            pinned_objects=self.pinned_objects_in_nursery)

    def _reset_flag_old_objects_pointing_to_pinned(self, obj, ignore):
        ll_assert(self.header(obj).tid & GCFLAG_PINNED_OBJECT_PARENT_KNOWN != 0,
                  "!GCFLAG_PINNED_OBJECT_PARENT_KNOWN, but requested to reset.")
        self.header(obj).tid &= ~GCFLAG_PINNED_OBJECT_PARENT_KNOWN

    def _visit_old_objects_pointing_to_pinned(self, obj, ignore):
        self.trace(obj, self._trace_drag_out, obj)

    def collect_roots_in_nursery(self, any_pinned_object_from_earlier):
        # we don't need to trace prebuilt GcStructs during a minor collect:
        # if a prebuilt GcStruct contains a pointer to a young object,
        # then the write_barrier must have ensured that the prebuilt
        # GcStruct is in the list self.old_objects_pointing_to_young.
        debug_start("gc-minor-walkroots")
        if self.gc_state == STATE_MARKING:
            callback = IncrementalMiniMarkGC._trace_drag_out1_marking_phase
        else:
            callback = IncrementalMiniMarkGC._trace_drag_out1
        #
        # Note a subtlety: if the nursery contains pinned objects "from
        # earlier", i.e. created earlier than the previous minor
        # collection, then we can't use the "is_minor=True" optimization.
        # We really need to walk the complete stack to be sure we still
        # see them.
        use_jit_frame_stoppers = not any_pinned_object_from_earlier
        #
        self.root_walker.walk_roots(
            callback,     # stack roots
            callback,     # static in prebuilt non-gc
            None,         # static in prebuilt gc
            is_minor=use_jit_frame_stoppers)
        debug_stop("gc-minor-walkroots")

    def collect_cardrefs_to_nursery(self):
        size_gc_header = self.gcheaderbuilder.size_gc_header
        oldlist = self.old_objects_with_cards_set
        while oldlist.non_empty():
            obj = oldlist.pop()
            #
            # Remove the GCFLAG_CARDS_SET flag.
            ll_assert(self.header(obj).tid & GCFLAG_CARDS_SET != 0,
                "!GCFLAG_CARDS_SET but object in 'old_objects_with_cards_set'")
            self.header(obj).tid &= ~GCFLAG_CARDS_SET
            #
            # Get the number of card marker bytes in the header.
            typeid = self.get_type_id(obj)
            offset_to_length = self.varsize_offset_to_length(typeid)
            length = (obj + offset_to_length).signed[0]
            bytes = self.card_marking_bytes_for_length(length)
            p = llarena.getfakearenaaddress(obj - size_gc_header)
            #
            # If the object doesn't have GCFLAG_TRACK_YOUNG_PTRS, then it
            # means that it is in 'old_objects_pointing_to_young' and
            # will be fully traced by collect_oldrefs_to_nursery() just
            # afterwards.
            if self.header(obj).tid & GCFLAG_TRACK_YOUNG_PTRS == 0:
                #
                # In that case, we just have to reset all card bits.
                while bytes > 0:
                    p -= 1
                    p.char[0] = '\x00'
                    bytes -= 1
                #
            else:
                # Walk the bytes encoding the card marker bits, and for
                # each bit set, call trace_and_drag_out_of_nursery_partial().
                interval_start = 0
                while bytes > 0:
                    p -= 1
                    cardbyte = ord(p.char[0])
                    p.char[0] = '\x00'           # reset the bits
                    bytes -= 1
                    next_byte_start = interval_start + 8*self.card_page_indices
                    #
                    while cardbyte != 0:
                        interval_stop = interval_start + self.card_page_indices
                        #
                        if cardbyte & 1:
                            if interval_stop > length:
                                interval_stop = length
                                #--- the sanity check below almost always
                                #--- passes, except in situations like
                                #--- test_writebarrier_before_copy_manually\
                                #    _copy_card_bits
                                #ll_assert(cardbyte <= 1 and bytes == 0,
                                #          "premature end of object")
                                ll_assert(bytes == 0, "premature end of object")
                                if interval_stop <= interval_start:
                                    break
                            self.trace_and_drag_out_of_nursery_partial(
                                obj, interval_start, interval_stop)
                        #
                        interval_start = interval_stop
                        cardbyte >>= 1
                    interval_start = next_byte_start
                #
                # If we're incrementally marking right now, sorry, we also
                # need to add the object to 'more_objects_to_trace' and have
                # it fully traced once at the end of the current marking phase.
                ll_assert(not self.is_in_nursery(obj),
                          "expected nursery obj in collect_cardrefs_to_nursery")
                if self.gc_state == STATE_MARKING:
                    self.header(obj).tid &= ~GCFLAG_VISITED
                    self.more_objects_to_trace.append(obj)


    def collect_oldrefs_to_nursery(self):
        # Follow the old_objects_pointing_to_young list and move the
        # young objects they point to out of the nursery.
        oldlist = self.old_objects_pointing_to_young
        while oldlist.non_empty():
            obj = oldlist.pop()
            #
            # Check that the flags are correct: we must not have
            # GCFLAG_TRACK_YOUNG_PTRS so far.
            ll_assert(self.header(obj).tid & GCFLAG_TRACK_YOUNG_PTRS == 0,
                      "old_objects_pointing_to_young contains obj with "
                      "GCFLAG_TRACK_YOUNG_PTRS")
            #
            # Add the flag GCFLAG_TRACK_YOUNG_PTRS.  All live objects should
            # have this flag set after a nursery collection.
            self.header(obj).tid |= GCFLAG_TRACK_YOUNG_PTRS
            #
            # Trace the 'obj' to replace pointers to nursery with pointers
            # outside the nursery, possibly forcing nursery objects out
            # and adding them to 'old_objects_pointing_to_young' as well.
            self.trace_and_drag_out_of_nursery(obj)

    def trace_and_drag_out_of_nursery(self, obj):
        """obj must not be in the nursery.  This copies all the
        young objects it references out of the nursery.
        """
        self.trace(obj, self._trace_drag_out, obj)

    def trace_and_drag_out_of_nursery_partial(self, obj, start, stop):
        """Like trace_and_drag_out_of_nursery(), but limited to the array
        indices in range(start, stop).
        """
        ll_assert(start < stop, "empty or negative range "
                                "in trace_and_drag_out_of_nursery_partial()")
        #print 'trace_partial:', start, stop, '\t', obj
        self.trace_partial(obj, start, stop, self._trace_drag_out, obj)


    def _trace_drag_out1(self, root):
        self._trace_drag_out(root, llmemory.NULL)

    def _trace_drag_out1_marking_phase(self, root):
        self._trace_drag_out(root, llmemory.NULL)
        #
        # We are in the MARKING state: we must also record this object
        # if it was young.  Don't bother with old objects in general,
        # as they are anyway added to 'more_objects_to_trace' if they
        # are modified (see _add_to_more_objects_to_trace).  But we do
        # need to record the not-visited-yet (white) old objects.  So
        # as a conservative approximation, we need to add the object to
        # the list if and only if it doesn't have GCFLAG_VISITED yet.
        #
        # Additionally, ignore pinned objects.
        #
        obj = root.address[0]
        if (self.header(obj).tid & (GCFLAG_VISITED | GCFLAG_PINNED)) == 0:
            self.more_objects_to_trace.append(obj)

    def _trace_drag_out(self, root, parent):
        obj = root.address[0]
        #print '_trace_drag_out(%x: %r)' % (hash(obj.ptr._obj), obj)
        #
        # If 'obj' is not in the nursery, nothing to change -- expect
        # that we must set GCFLAG_VISITED_RMY on young raw-malloced objects.
        if not self.is_in_nursery(obj):
            # cache usage trade-off: I think that it is a better idea to
            # check if 'obj' is in young_rawmalloced_objects with an access
            # to this (small) dictionary, rather than risk a lot of cache
            # misses by reading a flag in the header of all the 'objs' that
            # arrive here.
            if (bool(self.young_rawmalloced_objects)
                and self.young_rawmalloced_objects.contains(obj)):
                self._visit_young_rawmalloced_object(obj)
            return
        # copy the contents of the object? usually yes, but not for some
        # shadow objects
        copy = True
        #
        size_gc_header = self.gcheaderbuilder.size_gc_header
        if self.header(obj).tid & (GCFLAG_HAS_SHADOW | GCFLAG_PINNED) == 0:
            #
            # Common case: 'obj' was not already forwarded (otherwise
            # tid == -42, containing all flags), and it doesn't have the
            # HAS_SHADOW flag either.  We must move it out of the nursery,
            # into a new nonmovable location.
            totalsize = size_gc_header + self.get_size(obj)
            self.nursery_surviving_size += raw_malloc_usage(totalsize)
            newhdr = self._malloc_out_of_nursery(totalsize)
            #
        elif self.is_forwarded(obj):
            #
            # 'obj' was already forwarded.  Change the original reference
            # to point to its forwarding address, and we're done.
            root.address[0] = self.get_forwarding_address(obj)
            return
            #
        elif self._is_pinned(obj):
            hdr = self.header(obj)
            #
            # track parent of pinned object specially. This mus be done before
            # checking for GCFLAG_VISITED: it may be that the same pinned object
            # is reachable from multiple sources (e.g. two old objects pointing
            # to the same pinned object). In such a case we need all parents
            # of the pinned object in the list. Otherwise he pinned object could
            # become dead and be removed just because the first parent of it
            # is dead and collected.
            if parent != llmemory.NULL and \
                not self.header(parent).tid & GCFLAG_PINNED_OBJECT_PARENT_KNOWN:
                #
                self.old_objects_pointing_to_pinned.append(parent)
                self.updated_old_objects_pointing_to_pinned = True
                self.header(parent).tid |= GCFLAG_PINNED_OBJECT_PARENT_KNOWN
            #
            if hdr.tid & GCFLAG_VISITED:
                return
            #
            hdr.tid |= GCFLAG_VISITED
            #
            self.surviving_pinned_objects.append(
                llarena.getfakearenaaddress(obj - size_gc_header))
            self.pinned_objects_in_nursery += 1
            self.any_pinned_object_kept = True
            return
        else:
            # First visit to an object that has already a shadow.
            newobj = self.nursery_objects_shadows.get(obj)
            ll_assert(newobj != llmemory.NULL, "GCFLAG_HAS_SHADOW but no shadow found")
            newhdr = newobj - size_gc_header
            #
            # The flags GCFLAG_HAS_SHADOW and GCFLAG_SHADOW_INITIALIZED
            # have no meaning in non-nursery objects.  We don't need to
            # remove them explicitly here before doing the copy.
            tid = self.header(obj).tid
            if (tid & GCFLAG_SHADOW_INITIALIZED) != 0:
                copy = False
            #
            totalsize = size_gc_header + self.get_size(obj)
            self.nursery_surviving_size += raw_malloc_usage(totalsize)
        #
        # Copy it.  Note that references to other objects in the
        # nursery are kept unchanged in this step.
        if copy:
            llmemory.raw_memcopy(obj - size_gc_header, newhdr, totalsize)
        #
        # Set the old object's tid to -42 (containing all flags) and
        # replace the old object's content with the target address.
        # A bit of no-ops to convince llarena that we are changing
        # the layout, in non-translated versions.
        typeid = self.get_type_id(obj)
        obj = llarena.getfakearenaaddress(obj)
        llarena.arena_reset(obj - size_gc_header, totalsize, 0)
        llarena.arena_reserve(obj - size_gc_header,
                              size_gc_header + llmemory.sizeof(FORWARDSTUB))
        self.header(obj).tid = -42
        newobj = newhdr + size_gc_header
        llmemory.cast_adr_to_ptr(obj, FORWARDSTUBPTR).forw = newobj
        #
        # Change the original pointer to this object.
        root.address[0] = newobj
        #
        # Add the newobj to the list 'old_objects_pointing_to_young',
        # because it can contain further pointers to other young objects.
        # We will fix such references to point to the copy of the young
        # objects when we walk 'old_objects_pointing_to_young'.
        if self.has_gcptr(typeid):
            # we only have to do it if we have any gcptrs
            self.old_objects_pointing_to_young.append(newobj)

    _trace_drag_out._always_inline_ = True

    def _visit_young_rawmalloced_object(self, obj):
        # 'obj' points to a young, raw-malloced object.
        # Any young rawmalloced object never seen by the code here
        # will end up without GCFLAG_VISITED_RMY, and be freed at the
        # end of the current minor collection.  Note that there was
        # a bug in which dying young arrays with card marks would
        # still be scanned before being freed, keeping a lot of
        # objects unnecessarily alive.
        hdr = self.header(obj)
        if hdr.tid & GCFLAG_VISITED_RMY:
            return
        hdr.tid |= GCFLAG_VISITED_RMY
        #
        # Accounting
        size_gc_header = self.gcheaderbuilder.size_gc_header
        size = size_gc_header + self.get_size(obj)
        self.size_objects_made_old += r_uint(raw_malloc_usage(size))
        #
        # we just made 'obj' old, so we need to add it to the correct lists
        added_somewhere = False
        #
        if hdr.tid & GCFLAG_TRACK_YOUNG_PTRS == 0:
            self.old_objects_pointing_to_young.append(obj)
            added_somewhere = True
        #
        if hdr.tid & GCFLAG_HAS_CARDS != 0:
            ll_assert(hdr.tid & GCFLAG_CARDS_SET != 0,
                      "young array: GCFLAG_HAS_CARDS without GCFLAG_CARDS_SET")
            self.old_objects_with_cards_set.append(obj)
            added_somewhere = True
        #
        ll_assert(added_somewhere, "wrong flag combination on young array")


    def _malloc_out_of_nursery(self, totalsize):
        """Allocate non-movable memory for an object of the given
        'totalsize' that lives so far in the nursery."""
        if (r_uint(raw_malloc_usage(totalsize)) <=
            r_uint(self.small_request_threshold)):
            # most common path
            return self.ac.malloc(totalsize)
        else:
            # for nursery objects that are not small
            return self._malloc_out_of_nursery_nonsmall(totalsize)
    _malloc_out_of_nursery._always_inline_ = True

    def _malloc_out_of_nursery_nonsmall(self, totalsize):
        if r_uint(raw_malloc_usage(totalsize)) > r_uint(self.nursery_size):
            out_of_memory("memory corruption: bad size for object in the "
                          "nursery")
        # 'totalsize' should be aligned.
        ll_assert(raw_malloc_usage(totalsize) & (WORD-1) == 0,
                  "misaligned totalsize in _malloc_out_of_nursery_nonsmall")
        #
        arena = llarena.arena_malloc(raw_malloc_usage(totalsize), False)
        if not arena:
            out_of_memory("out of memory: couldn't allocate a few KB more")
        llarena.arena_reserve(arena, totalsize)
        #
        size_gc_header = self.gcheaderbuilder.size_gc_header
        self.rawmalloced_total_size += r_uint(raw_malloc_usage(totalsize))
        self.rawmalloced_peak_size = max(self.rawmalloced_total_size,
                                         self.rawmalloced_peak_size)
        self.old_rawmalloced_objects.append(arena + size_gc_header)
        return arena

    def free_young_rawmalloced_objects(self):
        self.young_rawmalloced_objects.foreach(
            self._free_young_rawmalloced_obj, None)
        self.young_rawmalloced_objects.delete()
        self.young_rawmalloced_objects = self.null_address_dict()

    def _free_young_rawmalloced_obj(self, obj, ignored1, ignored2):
        # If 'obj' has GCFLAG_VISITED_RMY, it was seen by _trace_drag_out
        # and survives.  Otherwise, it dies.
        self.free_rawmalloced_object_if_unvisited(obj, GCFLAG_VISITED_RMY)

    def remove_young_arrays_from_old_objects_pointing_to_young(self):
        old = self.old_objects_pointing_to_young
        new = self.AddressStack()
        while old.non_empty():
            obj = old.pop()
            if not self.young_rawmalloced_objects.contains(obj):
                new.append(obj)
        # an extra copy, to avoid assignments to
        # 'self.old_objects_pointing_to_young'
        while new.non_empty():
            old.append(new.pop())
        new.delete()

    def _add_to_more_objects_to_trace(self, obj, ignored):
        ll_assert(not self.is_in_nursery(obj), "unexpected nursery obj here")
        self.header(obj).tid &= ~GCFLAG_VISITED
        self.more_objects_to_trace.append(obj)

    def _add_to_more_objects_to_trace_if_black(self, obj, ignored):
        if self.header(obj).tid & GCFLAG_VISITED:
            self._add_to_more_objects_to_trace(obj, ignored)

    def minor_and_major_collection(self):
        # First, finish the current major gc, if there is one in progress.
        # This is a no-op if the gc_state is already STATE_SCANNING.
        self.gc_step_until(STATE_SCANNING)
        #
        # Then do a complete collection again.
        self.gc_step_until(STATE_MARKING)
        self.gc_step_until(STATE_SCANNING)

    def gc_step_until(self, state):
        while self.gc_state != state:
            self._minor_collection()
            self.major_collection_step()

    debug_gc_step_until = gc_step_until   # xxx

    def debug_gc_step(self, n=1):
        while n > 0:
            self._minor_collection()
            self.major_collection_step()
            n -= 1

    # Note - minor collections seem fast enough so that one
    # is done before every major collection step
    def major_collection_step(self, reserving_size=0):
        start = time.time()
        debug_start("gc-collect-step")
        oldstate = self.gc_state
        debug_print("starting gc state: ", GC_STATES[self.gc_state])
        # Debugging checks
        if self.pinned_objects_in_nursery == 0:
            ll_assert(self.nursery_free == self.nursery,
                      "nursery not empty in major_collection_step()")
        else:
            # XXX try to add some similar check to the above one for the case
            # that the nursery still contains some pinned objects (groggi)
            pass
        self.debug_check_consistency()

        #
        # 'threshold_objects_made_old', is used inside comparisons
        # with 'size_objects_made_old' to know when we must do
        # several major GC steps (i.e. several consecutive calls
        # to the present function).  Here is the target that
        # we try to aim to: either (A1) or (A2)
        #
        #  (A1)  gc_state == STATE_SCANNING   (i.e. major GC cycle ended)
        #  (A2)  size_objects_made_old <= threshold_objects_made_old
        #
        # Every call to major_collection_step() adds nursery_size//2
        # to 'threshold_objects_made_old'.
        # In the common case, this is larger than the size of all
        # objects that survive a minor collection.  After a few
        # minor collections (each followed by one call to
        # major_collection_step()) the threshold is much higher than
        # the 'size_objects_made_old', making the target invariant (A2)
        # true by a large margin.
        #
        # However there are less common cases:
        #
        # * if more than half of the nursery consistently survives:
        #   then we need two calls to major_collection_step() after
        #   some minor collection;
        #
        # * or if we're allocating a large number of bytes in
        #   external_malloc() and some of them survive the following
        #   minor collection.  In that case, more than two major
        #   collection steps must be done immediately, until we
        #   restore the target invariant (A2).
        #
        self.threshold_objects_made_old += r_uint(self.nursery_size // 2)


        if self.gc_state == STATE_SCANNING:
            # starting a major GC cycle: reset these two counters
            self.size_objects_made_old = r_uint(0)
            self.threshold_objects_made_old = r_uint(self.nursery_size // 2)

            self.objects_to_trace = self.AddressStack()
            self.collect_roots()
            self.gc_state = STATE_MARKING
            self.more_objects_to_trace = self.AddressStack()
            #END SCANNING
        elif self.gc_state == STATE_MARKING:
            debug_print("number of objects to mark",
                        self.objects_to_trace.length(),
                        "plus",
                        self.more_objects_to_trace.length())
            estimate = self.gc_increment_step
            estimate_from_nursery = self.nursery_surviving_size * 2
            if estimate_from_nursery > estimate:
                estimate = estimate_from_nursery
            estimate = intmask(estimate)
            remaining = self.visit_all_objects_step(estimate)
            #
            if remaining >= estimate // 2:
                if self.more_objects_to_trace.non_empty():
                    # We consumed less than 1/2 of our step's time, and
                    # there are more objects added during the marking steps
                    # of this major collection.  Visit them all now.
                    # The idea is to ensure termination at the cost of some
                    # incrementality, in theory.
                    swap = self.objects_to_trace
                    self.objects_to_trace = self.more_objects_to_trace
                    self.more_objects_to_trace = swap
                    self.visit_all_objects()

            # XXX A simplifying assumption that should be checked,
            # finalizers/weak references are rare and short which means that
            # they do not need a separate state and do not need to be
            # made incremental.
            # For now, the same applies to rawrefcount'ed objects.
            if (not self.objects_to_trace.non_empty() and
                not self.more_objects_to_trace.non_empty()):
                #
                # First, 'prebuilt_root_objects' might have grown since
                # we scanned it in collect_roots() (rare case).  Rescan.
                self.collect_nonstack_roots()
                self.visit_all_objects()
                #
                if self.rrc_enabled:
                    self.rrc_major_collection_trace()
                #
                ll_assert(not (self.probably_young_objects_with_finalizers
                               .non_empty()),
                    "probably_young_objects_with_finalizers should be empty")
                self.kept_alive_by_finalizer = r_uint(0)
                if self.old_objects_with_finalizers.non_empty():
                    self.deal_with_objects_with_finalizers()
                elif self.old_objects_with_weakrefs.non_empty():
                    # Weakref support: clear the weak pointers to dying objects
                    # (if we call deal_with_objects_with_finalizers(), it will
                    # invoke invalidate_old_weakrefs() itself directly)
                    self.invalidate_old_weakrefs()

                ll_assert(not self.objects_to_trace.non_empty(),
                          "objects_to_trace should be empty")
                ll_assert(not self.more_objects_to_trace.non_empty(),
                          "more_objects_to_trace should be empty")
                self.objects_to_trace.delete()
                self.more_objects_to_trace.delete()

                #
                # Destructors
                if self.old_objects_with_destructors.non_empty():
                    self.deal_with_old_objects_with_destructors()
                # objects_to_trace processed fully, can move on to sweeping
                self.ac.mass_free_prepare()
                self.start_free_rawmalloc_objects()
                #
                # get rid of objects pointing to pinned objects that were not
                # visited
                if self.old_objects_pointing_to_pinned.non_empty():
                    new_old_objects_pointing_to_pinned = self.AddressStack()
                    self.old_objects_pointing_to_pinned.foreach(
                            self._sweep_old_objects_pointing_to_pinned,
                            new_old_objects_pointing_to_pinned)
                    self.old_objects_pointing_to_pinned.delete()
                    self.old_objects_pointing_to_pinned = \
                            new_old_objects_pointing_to_pinned
                    self.updated_old_objects_pointing_to_pinned = True
                #
                if self.rrc_enabled:
                    self.rrc_major_collection_free()
                #
                self.stat_ac_arenas_count = self.ac.arenas_count
                self.stat_rawmalloced_total_size = self.rawmalloced_total_size
                self.gc_state = STATE_SWEEPING
            #END MARKING
        elif self.gc_state == STATE_SWEEPING:
            #
            if self.raw_malloc_might_sweep.non_empty():
                # Walk all rawmalloced objects and free the ones that don't
                # have the GCFLAG_VISITED flag.  Visit at most 'limit' objects.
                # This limit is conservatively high enough to guarantee that
                # a total object size of at least '3 * nursery_size' bytes
                # is processed.
                limit = 3 * self.nursery_size // self.small_request_threshold
                nobjects = self.free_unvisited_rawmalloc_objects_step(limit)
                debug_print("freeing raw objects:", limit-nobjects,
                            "freed, limit was", limit)
                done = False    # the 2nd half below must still be done
            else:
                # Ask the ArenaCollection to visit a fraction of the objects.
                # Free the ones that have not been visited above, and reset
                # GCFLAG_VISITED on the others.  Visit at most '3 *
                # nursery_size' bytes.
                limit = 3 * self.nursery_size // self.ac.page_size
                done = self.ac.mass_free_incremental(self._free_if_unvisited,
                                                     limit)
                status = done and "No more pages left." or "More to do."
                debug_print("freeing GC objects, up to", limit, "pages.", status)
            # XXX tweak the limits above
            #
            if done:
                self.num_major_collects += 1
                #
                # We also need to reset the GCFLAG_VISITED on prebuilt GC objects.
                self.prebuilt_root_objects.foreach(self._reset_gcflag_visited, None)
                #
                # Set the threshold for the next major collection to be when we
                # have allocated 'major_collection_threshold' times more than
                # we currently have -- but no more than 'max_delta' more than
                # we currently have.
                total_memory_used = float(self.get_total_memory_used())
                total_memory_used -= float(self.kept_alive_by_finalizer)
                if total_memory_used < 0:
                    total_memory_used = 0
                bounded = self.set_major_threshold_from(
                    min(total_memory_used * self.major_collection_threshold,
                        total_memory_used + self.max_delta),
                    reserving_size)
                #
                # Print statistics
                debug_start("gc-collect-done")
                debug_print("arenas:               ",
                            self.stat_ac_arenas_count, " => ",
                            self.ac.arenas_count)
                debug_print("bytes used in arenas: ",
                            self.ac.total_memory_used)
                debug_print("bytes raw-malloced:   ",
                            self.stat_rawmalloced_total_size, " => ",
                            self.rawmalloced_total_size)
                debug_print("next major collection threshold: ",
                            self.next_major_collection_threshold)
                debug_stop("gc-collect-done")
                self.hooks.fire_gc_collect(
                    num_major_collects=self.num_major_collects,
                    arenas_count_before=self.stat_ac_arenas_count,
                    arenas_count_after=self.ac.arenas_count,
                    arenas_bytes=self.ac.total_memory_used,
                    rawmalloc_bytes_before=self.stat_rawmalloced_total_size,
                    rawmalloc_bytes_after=self.rawmalloced_total_size)
                #
                # Max heap size: gives an upper bound on the threshold.  If we
                # already have at least this much allocated, raise MemoryError.
                if bounded and self.threshold_reached(reserving_size):
                    #
                    # First raise MemoryError, giving the program a chance to
                    # quit cleanly.  It might still allocate in the nursery,
                    # which might eventually be emptied, triggering another
                    # major collect and (possibly) reaching here again with an
                    # even higher memory consumption.  To prevent it, if it's
                    # the second time we are here, then abort the program.
                    if self.max_heap_size_already_raised:
                        out_of_memory("using too much memory, aborting")
                    self.max_heap_size_already_raised = True
                    self.gc_state = STATE_SCANNING
                    raise MemoryError

                self.gc_state = STATE_FINALIZING
            # FINALIZING not yet incrementalised
            # but it seems safe to allow mutator to run after sweeping and
            # before finalizers are called. This is because run_finalizers
            # is a different list to objects_with_finalizers.
            # END SWEEPING
        elif self.gc_state == STATE_FINALIZING:
            # XXX This is considered rare,
            # so should we make the calling incremental? or leave as is

            # Must be ready to start another scan
            # just in case finalizer calls collect again.
            self.gc_state = STATE_SCANNING

            self.execute_finalizers()
            #END FINALIZING
        else:
            ll_assert(False, "bogus gc_state")

        debug_print("stopping, now in gc state: ", GC_STATES[self.gc_state])
        debug_stop("gc-collect-step")
        duration = time.time() - start
        self.total_gc_time += duration
        self.hooks.fire_gc_collect_step(
            duration=duration,
            oldstate=oldstate,
            newstate=self.gc_state)

    def _sweep_old_objects_pointing_to_pinned(self, obj, new_list):
        if self.header(obj).tid & GCFLAG_VISITED:
            new_list.append(obj)

    def _free_if_unvisited(self, hdr):
        size_gc_header = self.gcheaderbuilder.size_gc_header
        obj = hdr + size_gc_header
        if self.header(obj).tid & GCFLAG_VISITED:
            self.header(obj).tid &= ~GCFLAG_VISITED
            return False     # survives
        return True      # dies

    def _reset_gcflag_visited(self, obj, ignored):
        self.header(obj).tid &= ~GCFLAG_VISITED

    def free_rawmalloced_object_if_unvisited(self, obj, check_flag):
        if self.header(obj).tid & check_flag:
            self.header(obj).tid &= ~check_flag   # survives
            self.old_rawmalloced_objects.append(obj)
        else:
            size_gc_header = self.gcheaderbuilder.size_gc_header
            totalsize = size_gc_header + self.get_size(obj)
            allocsize = raw_malloc_usage(totalsize)
            arena = llarena.getfakearenaaddress(obj - size_gc_header)
            #
            # Must also include the card marker area, if any
            if (self.card_page_indices > 0    # <- this is constant-folded
                and self.header(obj).tid & GCFLAG_HAS_CARDS):
                #
                # Get the length and compute the number of extra bytes
                typeid = self.get_type_id(obj)
                ll_assert(self.has_gcptr_in_varsize(typeid),
                          "GCFLAG_HAS_CARDS but not has_gcptr_in_varsize")
                offset_to_length = self.varsize_offset_to_length(typeid)
                length = (obj + offset_to_length).signed[0]
                extra_words = self.card_marking_words_for_length(length)
                arena -= extra_words * WORD
                allocsize += extra_words * WORD
            #
            llarena.arena_free(arena)
            self.rawmalloced_total_size -= r_uint(allocsize)

    def start_free_rawmalloc_objects(self):
        ll_assert(not self.raw_malloc_might_sweep.non_empty(),
                  "raw_malloc_might_sweep must be empty")
        swap = self.raw_malloc_might_sweep
        self.raw_malloc_might_sweep = self.old_rawmalloced_objects
        self.old_rawmalloced_objects = swap

    # Returns true when finished processing objects
    def free_unvisited_rawmalloc_objects_step(self, nobjects):
        while self.raw_malloc_might_sweep.non_empty() and nobjects > 0:
            obj = self.raw_malloc_might_sweep.pop()
            self.free_rawmalloced_object_if_unvisited(obj, GCFLAG_VISITED)
            nobjects -= 1

        return nobjects


    def collect_nonstack_roots(self):
        # Non-stack roots: first, the objects from 'prebuilt_root_objects'
        self.prebuilt_root_objects.foreach(self._collect_obj, None)
        #
        # Add the roots from static prebuilt non-gc structures
        self.root_walker.walk_roots(
            None,
            IncrementalMiniMarkGC._collect_ref_stk,
            None)   # we don't need the static in all prebuilt gc objects
        #
        # If we are in an inner collection caused by a call to a finalizer,
        # the 'run_finalizers' objects also need to be kept alive.
        self.enum_pending_finalizers(self._collect_obj, None)

    def collect_roots(self):
        # Collect all roots.  Starts from the non-stack roots.
        self.collect_nonstack_roots()
        #
        # Add the stack roots.
        self.root_walker.walk_roots(
            IncrementalMiniMarkGC._collect_ref_stk, # stack roots
            None,
            None)

    def enumerate_all_roots(self, callback, arg):
        self.prebuilt_root_objects.foreach(callback, arg)
        MovingGCBase.enumerate_all_roots(self, callback, arg)
    enumerate_all_roots._annspecialcase_ = 'specialize:arg(1)'

    def enum_live_with_finalizers(self, callback, arg):
        self.probably_young_objects_with_finalizers.foreach(callback, arg, 2)
        self.old_objects_with_finalizers.foreach(callback, arg, 2)
    enum_live_with_finalizers._annspecialcase_ = 'specialize:arg(1)'

    def _collect_obj(self, obj, ignored):
        # Ignore pinned objects, which are the ones still in the nursery here.
        # Cache effects: don't read any flag out of 'obj' at this point.
        # But only checking if it is in the nursery or not is fine.
        llop.debug_nonnull_pointer(lltype.Void, obj)
        if not self.is_in_nursery(obj):
            self.objects_to_trace.append(obj)
        else:
            # A pinned object can be found here. Such an object is handled
            # by minor collections and shouldn't be specially handled by
            # major collections. Therefore we only add non-pinned objects
            # to the 'objects_to_trace' list.
            ll_assert(self._is_pinned(obj),
                      "non-pinned nursery obj in _collect_obj")
    _collect_obj._always_inline_ = True

    def _collect_ref_stk(self, root):
        self._collect_obj(root.address[0], None)

    def _collect_ref_rec(self, root, ignored):
        self._collect_obj(root.address[0], None)

    def visit_all_objects(self):
        while self.objects_to_trace.non_empty():
            self.visit_all_objects_step(sys.maxint)

    TEST_VISIT_SINGLE_STEP = False    # for tests

    def visit_all_objects_step(self, size_to_track):
        # Objects can be added to pending by visit
        pending = self.objects_to_trace
        while pending.non_empty():
            obj = pending.pop()
            size_to_track -= self.visit(obj)
            if size_to_track < 0 or self.TEST_VISIT_SINGLE_STEP:
                return 0
        return size_to_track

    def visit(self, obj):
        #
        # 'obj' is a live object.  Check GCFLAG_VISITED to know if we
        # have already seen it before.
        #
        # Moreover, we can ignore prebuilt objects with GCFLAG_NO_HEAP_PTRS.
        # If they have this flag set, then they cannot point to heap
        # objects, so ignoring them is fine.  If they don't have this
        # flag set, then the object should be in 'prebuilt_root_objects',
        # and the GCFLAG_VISITED will be reset at the end of the
        # collection.
        # We shouldn't see an object with GCFLAG_PINNED here (the pinned
        # objects are never added to 'objects_to_trace').  The same-valued
        # flag GCFLAG_PINNED_OBJECT_PARENT_KNOWN is used during minor
        # collections and shouldn't be set here either.
        #
        hdr = self.header(obj)
        ll_assert((hdr.tid & GCFLAG_PINNED) == 0,
                  "pinned object in 'objects_to_trace'")
        ll_assert(not self.is_in_nursery(obj),
                  "nursery object in 'objects_to_trace'")
        if hdr.tid & (GCFLAG_VISITED | GCFLAG_NO_HEAP_PTRS):
            return 0
        #
        # It's the first time.  We set the flag VISITED.  The trick is
        # to also set TRACK_YOUNG_PTRS here, for the write barrier.
        hdr.tid |= GCFLAG_VISITED | GCFLAG_TRACK_YOUNG_PTRS

        if self.has_gcptr(llop.extract_ushort(llgroup.HALFWORD, hdr.tid)):
            #
            # Trace the content of the object and put all objects it references
            # into the 'objects_to_trace' list.
            self.trace(obj, self._collect_ref_rec, None)

        size_gc_header = self.gcheaderbuilder.size_gc_header
        totalsize = size_gc_header + self.get_size(obj)
        return raw_malloc_usage(totalsize)

    # ----------
    # id() and identityhash() support

    def _allocate_shadow(self, obj):
        size_gc_header = self.gcheaderbuilder.size_gc_header
        size = self.get_size(obj)
        shadowhdr = self._malloc_out_of_nursery(size_gc_header +
                                                size)
        # Initialize the shadow enough to be considered a
        # valid gc object.  If the original object stays
        # alive at the next minor collection, it will anyway
        # be copied over the shadow and overwrite the
        # following fields.  But if the object dies, then
        # the shadow will stay around and only be freed at
        # the next major collection, at which point we want
        # it to look valid (but ready to be freed).
        shadow = shadowhdr + size_gc_header
        self.header(shadow).tid = self.header(obj).tid
        typeid = self.get_type_id(obj)
        if self.is_varsize(typeid):
            lenofs = self.varsize_offset_to_length(typeid)
            (shadow + lenofs).signed[0] = (obj + lenofs).signed[0]
        #
        self.header(obj).tid |= GCFLAG_HAS_SHADOW
        self.nursery_objects_shadows.setitem(obj, shadow)
        return shadow

    def _find_shadow(self, obj):
        #
        # The object is not a tagged pointer, and it is still in the
        # nursery.  Find or allocate a "shadow" object, which is
        # where the object will be moved by the next minor
        # collection
        if self.header(obj).tid & GCFLAG_HAS_SHADOW:
            shadow = self.nursery_objects_shadows.get(obj)
            ll_assert(shadow != llmemory.NULL,
                      "GCFLAG_HAS_SHADOW but no shadow found")
        else:
            shadow = self._allocate_shadow(obj)
        #
        # The answer is the address of the shadow.
        return shadow
    _find_shadow._dont_inline_ = True

    def id_or_identityhash(self, gcobj):
        """Implement the common logic of id() and identityhash()
        of an object, given as a GCREF.
        """
        obj = llmemory.cast_ptr_to_adr(gcobj)
        if self.is_valid_gc_object(obj):
            if self.is_in_nursery(obj):
                obj = self._find_shadow(obj)
        return llmemory.cast_adr_to_int(obj)
    id_or_identityhash._always_inline_ = True

    def id(self, gcobj):
        return self.id_or_identityhash(gcobj)

    def identityhash(self, gcobj):
        return mangle_hash(self.id_or_identityhash(gcobj))

    # ----------
    # Finalizers

    def deal_with_young_objects_with_destructors(self):
        """We can reasonably assume that destructors don't do
        anything fancy and *just* call them. Among other things
        they won't resurrect objects
        """
        while self.young_objects_with_destructors.non_empty():
            obj = self.young_objects_with_destructors.pop()
            if not self.is_forwarded(obj):
                self.call_destructor(obj)
            else:
                obj = self.get_forwarding_address(obj)
                self.old_objects_with_destructors.append(obj)

    def deal_with_old_objects_with_destructors(self):
        """We can reasonably assume that destructors don't do
        anything fancy and *just* call them. Among other things
        they won't resurrect objects
        """
        new_objects = self.AddressStack()
        while self.old_objects_with_destructors.non_empty():
            obj = self.old_objects_with_destructors.pop()
            if self.header(obj).tid & GCFLAG_VISITED:
                # surviving
                new_objects.append(obj)
            else:
                # dying
                self.call_destructor(obj)
        self.old_objects_with_destructors.delete()
        self.old_objects_with_destructors = new_objects

    def deal_with_young_objects_with_finalizers(self):
        while self.probably_young_objects_with_finalizers.non_empty():
            obj = self.probably_young_objects_with_finalizers.popleft()
            fq_nr = self.probably_young_objects_with_finalizers.popleft()
            if self.get_possibly_forwarded_tid(obj) & GCFLAG_IGNORE_FINALIZER:
                continue
            self.singleaddr.address[0] = obj
            self._trace_drag_out1(self.singleaddr)
            obj = self.singleaddr.address[0]
            self.old_objects_with_finalizers.append(obj)
            self.old_objects_with_finalizers.append(fq_nr)

    def deal_with_objects_with_finalizers(self):
        # Walk over list of objects with finalizers.
        # If it is not surviving, add it to the list of to-be-called
        # finalizers and make it survive, to make the finalizer runnable.
        # We try to run the finalizers in a "reasonable" order, like
        # CPython does.  The details of this algorithm are in
        # pypy/doc/discussion/finalizer-order.txt.
        new_with_finalizer = self.AddressDeque()
        marked = self.AddressDeque()
        pending = self.AddressStack()
        self.tmpstack = self.AddressStack()
        while self.old_objects_with_finalizers.non_empty():
            x = self.old_objects_with_finalizers.popleft()
            fq_nr = self.old_objects_with_finalizers.popleft()
            ll_assert(self._finalization_state(x) != 1,
                      "bad finalization state 1")
            if self.header(x).tid & GCFLAG_IGNORE_FINALIZER:
                continue
            if self.header(x).tid & GCFLAG_VISITED:
                new_with_finalizer.append(x)
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
            self._recursively_bump_finalization_state_from_1_to_2(x)

        # Clear the weak pointers to dying objects.  Also clears them if
        # they point to objects which have the GCFLAG_FINALIZATION_ORDERING
        # bit set here.  These are objects which will be added to
        # run_finalizers().
        self.invalidate_old_weakrefs()

        while marked.non_empty():
            x = marked.popleft()
            fq_nr = marked.popleft()
            state = self._finalization_state(x)
            ll_assert(state >= 2, "unexpected finalization state < 2")
            if state == 2:
                from rpython.rtyper.lltypesystem import rffi
                fq_index = rffi.cast(lltype.Signed, fq_nr)
                self.mark_finalizer_to_run(fq_index, x)
                # we must also fix the state from 2 to 3 here, otherwise
                # we leave the GCFLAG_FINALIZATION_ORDERING bit behind
                # which will confuse the next collection
                self._recursively_bump_finalization_state_from_2_to_3(x)
            else:
                new_with_finalizer.append(x)
                new_with_finalizer.append(fq_nr)

        self.tmpstack.delete()
        pending.delete()
        marked.delete()
        self.old_objects_with_finalizers.delete()
        self.old_objects_with_finalizers = new_with_finalizer

    def _append_if_nonnull(pointer, stack):
        stack.append(pointer.address[0])
    _append_if_nonnull = staticmethod(_append_if_nonnull)

    def _finalization_state(self, obj):
        tid = self.header(obj).tid
        if tid & GCFLAG_VISITED:
            if tid & GCFLAG_FINALIZATION_ORDERING:
                return 2
            else:
                return 3
        else:
            if tid & GCFLAG_FINALIZATION_ORDERING:
                return 1
            else:
                return 0

    def _bump_finalization_state_from_0_to_1(self, obj):
        ll_assert(self._finalization_state(obj) == 0,
                  "unexpected finalization state != 0")
        size_gc_header = self.gcheaderbuilder.size_gc_header
        totalsize = size_gc_header + self.get_size(obj)
        hdr = self.header(obj)
        hdr.tid |= GCFLAG_FINALIZATION_ORDERING
        # A bit hackish, but we will not count these objects as "alive"
        # for the purpose of computing when the next major GC should
        # occur.  This is done for issue #2590: without this, if we
        # allocate mostly objects with finalizers, the
        # next_major_collection_threshold grows forever and actual
        # memory usage is not bounded.
        self.kept_alive_by_finalizer += raw_malloc_usage(totalsize)

    def _recursively_bump_finalization_state_from_2_to_3(self, obj):
        ll_assert(self._finalization_state(obj) == 2,
                  "unexpected finalization state != 2")
        pending = self.tmpstack
        ll_assert(not pending.non_empty(), "tmpstack not empty")
        pending.append(obj)
        while pending.non_empty():
            y = pending.pop()
            hdr = self.header(y)
            if hdr.tid & GCFLAG_FINALIZATION_ORDERING:     # state 2 ?
                hdr.tid &= ~GCFLAG_FINALIZATION_ORDERING   # change to state 3
                self.trace(y, self._append_if_nonnull, pending)

    def _recursively_bump_finalization_state_from_1_to_2(self, obj):
        # recursively convert objects from state 1 to state 2.
        # The call to visit_all_objects() will add the GCFLAG_VISITED
        # recursively.
        ll_assert(not self.is_in_nursery(obj), "pinned finalizer object??")
        self.objects_to_trace.append(obj)
        self.visit_all_objects()

    def ignore_finalizer(self, obj):
        self.header(obj).tid |= GCFLAG_IGNORE_FINALIZER


    # ----------
    # Weakrefs

    # XXX (groggi): weakref pointing to pinned object not supported.
    # XXX (groggi): missing asserts/checks for the missing feature.

    # The code relies on the fact that no weakref can be an old object
    # weakly pointing to a young object.  Indeed, weakrefs are immutable
    # so they cannot point to an object that was created after it.
    # Thanks to this, during a minor collection, we don't have to fix
    # or clear the address stored in old weakrefs.
    def invalidate_young_weakrefs(self):
        """Called during a nursery collection."""
        # walk over the list of objects that contain weakrefs and are in the
        # nursery.  if the object it references survives then update the
        # weakref; otherwise invalidate the weakref
        while self.young_objects_with_weakrefs.non_empty():
            obj = self.young_objects_with_weakrefs.pop()
            if not self.is_forwarded(obj):
                continue # weakref itself dies
            obj = self.get_forwarding_address(obj)
            offset = self.weakpointer_offset(self.get_type_id(obj))
            pointing_to = (obj + offset).address[0]
            if self.is_in_nursery(pointing_to):
                if self.is_forwarded(pointing_to):
                    (obj + offset).address[0] = self.get_forwarding_address(
                        pointing_to)
                else:
                    # If the target is pinned, then we reach this point too.
                    # It means that a hypothetical RPython interpreter that
                    # would let you take a weakref to a pinned object (strange
                    # thing not possible at all in PyPy) might see these
                    # weakrefs marked as dead too early.
                    (obj + offset).address[0] = llmemory.NULL
                    continue    # no need to remember this weakref any longer
            #
            elif (bool(self.young_rawmalloced_objects) and
                  self.young_rawmalloced_objects.contains(pointing_to)):
                # young weakref to a young raw-malloced object
                if self.header(pointing_to).tid & GCFLAG_VISITED_RMY:
                    pass    # survives, but does not move
                else:
                    (obj + offset).address[0] = llmemory.NULL
                    continue    # no need to remember this weakref any longer
            #
            elif self.header(pointing_to).tid & GCFLAG_NO_HEAP_PTRS:
                # see test_weakref_to_prebuilt: it's not useful to put
                # weakrefs into 'old_objects_with_weakrefs' if they point
                # to a prebuilt object (they are immortal).  If moreover
                # the 'pointing_to' prebuilt object still has the
                # GCFLAG_NO_HEAP_PTRS flag, then it's even wrong, because
                # 'pointing_to' will not get the GCFLAG_VISITED during
                # the next major collection.  Solve this by not registering
                # the weakref into 'old_objects_with_weakrefs'.
                continue
            #
            self.old_objects_with_weakrefs.append(obj)

    def invalidate_old_weakrefs(self):
        """Called during a major collection."""
        # walk over list of objects that contain weakrefs
        # if the object it references does not survive, invalidate the weakref
        new_with_weakref = self.AddressStack()
        while self.old_objects_with_weakrefs.non_empty():
            obj = self.old_objects_with_weakrefs.pop()
            if self.header(obj).tid & GCFLAG_VISITED == 0:
                continue # weakref itself dies
            offset = self.weakpointer_offset(self.get_type_id(obj))
            pointing_to = (obj + offset).address[0]
            ll_assert((self.header(pointing_to).tid & GCFLAG_NO_HEAP_PTRS)
                      == 0, "registered old weakref should not "
                            "point to a NO_HEAP_PTRS obj")
            tid = self.header(pointing_to).tid
            if ((tid & (GCFLAG_VISITED | GCFLAG_FINALIZATION_ORDERING)) ==
                        GCFLAG_VISITED):
                new_with_weakref.append(obj)
            else:
                (obj + offset).address[0] = llmemory.NULL
        self.old_objects_with_weakrefs.delete()
        self.old_objects_with_weakrefs = new_with_weakref

    def get_stats(self, stats_no):
        from rpython.memory.gc import inspector

        if stats_no == rgc.TOTAL_MEMORY:
            return intmask(self.get_total_memory_used() + self.nursery_size)
        elif stats_no == rgc.PEAK_MEMORY:
            return intmask(self.get_peak_memory_used() + self.nursery_size)
        elif stats_no == rgc.PEAK_ALLOCATED_MEMORY:
            return intmask(self.get_peak_memory_alloced() + self.nursery_size)
        elif stats_no == rgc.TOTAL_ALLOCATED_MEMORY:
            return intmask(self.get_total_memory_alloced() + self.nursery_size)
        elif stats_no == rgc.TOTAL_MEMORY_PRESSURE:
            return inspector.count_memory_pressure(self)
        elif stats_no == rgc.TOTAL_ARENA_MEMORY:
            return intmask(self.ac.total_memory_used)
        elif stats_no == rgc.TOTAL_RAWMALLOCED_MEMORY:
            return intmask(self.rawmalloced_total_size)
        elif stats_no == rgc.PEAK_RAWMALLOCED_MEMORY:
            return intmask(self.rawmalloced_peak_size)
        elif stats_no == rgc.PEAK_ARENA_MEMORY:
            return intmask(max(self.ac.peak_memory_used,
                               self.ac.total_memory_used))
        elif stats_no == rgc.NURSERY_SIZE:
            return intmask(self.nursery_size)
        elif stats_no == rgc.TOTAL_GC_TIME:
            return int(self.total_gc_time * 1000)
        return 0


    # ----------
    # RawRefCount

    rrc_enabled = False

    _ADDRARRAY = lltype.Array(llmemory.Address, hints={'nolength': True})
    PYOBJ_HDR = lltype.Struct('GCHdr_PyObject',
                              ('ob_refcnt', lltype.Signed),
                              ('ob_pypy_link', lltype.Signed))
    PYOBJ_HDR_PTR = lltype.Ptr(PYOBJ_HDR)
    RAWREFCOUNT_DEALLOC_TRIGGER = lltype.Ptr(lltype.FuncType([], lltype.Void))

    def _pyobj(self, pyobjaddr):
        return llmemory.cast_adr_to_ptr(pyobjaddr, self.PYOBJ_HDR_PTR)

    def rawrefcount_init(self, dealloc_trigger_callback):
        # see pypy/doc/discussion/rawrefcount.rst
        if not self.rrc_enabled:
            self.rrc_p_list_young = self.AddressStack()
            self.rrc_p_list_old   = self.AddressStack()
            self.rrc_o_list_young = self.AddressStack()
            self.rrc_o_list_old   = self.AddressStack()
            self.rrc_p_dict       = self.AddressDict()  # non-nursery keys only
            self.rrc_p_dict_nurs  = self.AddressDict()  # nursery keys only
            self.rrc_dealloc_trigger_callback = dealloc_trigger_callback
            self.rrc_dealloc_pending = self.AddressStack()
            self.rrc_enabled = True

    def check_no_more_rawrefcount_state(self):
        "NOT_RPYTHON: for tests"
        assert self.rrc_p_list_young.length() == 0
        assert self.rrc_p_list_old  .length() == 0
        assert self.rrc_o_list_young.length() == 0
        assert self.rrc_o_list_old  .length() == 0
        def check_value_is_null(key, value, ignore):
            assert value == llmemory.NULL
        self.rrc_p_dict.foreach(check_value_is_null, None)
        self.rrc_p_dict_nurs.foreach(check_value_is_null, None)

    def rawrefcount_create_link_pypy(self, gcobj, pyobject):
        ll_assert(self.rrc_enabled, "rawrefcount.init not called")
        obj = llmemory.cast_ptr_to_adr(gcobj)
        objint = llmemory.cast_adr_to_int(obj, "symbolic")
        self._pyobj(pyobject).ob_pypy_link = objint
        #
        lst = self.rrc_p_list_young
        if self.is_in_nursery(obj):
            dct = self.rrc_p_dict_nurs
        else:
            dct = self.rrc_p_dict
            if not self.is_young_object(obj):
                lst = self.rrc_p_list_old
        lst.append(pyobject)
        dct.setitem(obj, pyobject)

    def rawrefcount_create_link_pyobj(self, gcobj, pyobject):
        ll_assert(self.rrc_enabled, "rawrefcount.init not called")
        obj = llmemory.cast_ptr_to_adr(gcobj)
        if self.is_young_object(obj):
            self.rrc_o_list_young.append(pyobject)
        else:
            self.rrc_o_list_old.append(pyobject)
        objint = llmemory.cast_adr_to_int(obj, "symbolic")
        self._pyobj(pyobject).ob_pypy_link = objint
        # there is no rrc_o_dict

    def rawrefcount_mark_deallocating(self, gcobj, pyobject):
        ll_assert(self.rrc_enabled, "rawrefcount.init not called")
        obj = llmemory.cast_ptr_to_adr(gcobj)   # should be a prebuilt obj
        objint = llmemory.cast_adr_to_int(obj, "symbolic")
        self._pyobj(pyobject).ob_pypy_link = objint

    def rawrefcount_from_obj(self, gcobj):
        obj = llmemory.cast_ptr_to_adr(gcobj)
        if self.is_in_nursery(obj):
            dct = self.rrc_p_dict_nurs
        else:
            dct = self.rrc_p_dict
        return dct.get(obj)

    def rawrefcount_to_obj(self, pyobject):
        obj = llmemory.cast_int_to_adr(self._pyobj(pyobject).ob_pypy_link)
        return llmemory.cast_adr_to_ptr(obj, llmemory.GCREF)

    def rawrefcount_next_dead(self):
        if self.rrc_dealloc_pending.non_empty():
            return self.rrc_dealloc_pending.pop()
        return llmemory.NULL


    def rrc_invoke_callback(self):
        if self.rrc_enabled and self.rrc_dealloc_pending.non_empty():
            self.rrc_dealloc_trigger_callback()

    def rrc_minor_collection_trace(self):
        length_estimate = self.rrc_p_dict_nurs.length()
        self.rrc_p_dict_nurs.delete()
        self.rrc_p_dict_nurs = self.AddressDict(length_estimate)
        self.rrc_p_list_young.foreach(self._rrc_minor_trace,
                                      self.singleaddr)

    def _rrc_minor_trace(self, pyobject, singleaddr):
        from rpython.rlib.rawrefcount import REFCNT_FROM_PYPY
        from rpython.rlib.rawrefcount import REFCNT_FROM_PYPY_LIGHT
        #
        rc = self._pyobj(pyobject).ob_refcnt
        if rc == REFCNT_FROM_PYPY or rc == REFCNT_FROM_PYPY_LIGHT:
            pass     # the corresponding object may die
        else:
            # force the corresponding object to be alive
            intobj = self._pyobj(pyobject).ob_pypy_link
            singleaddr.address[0] = llmemory.cast_int_to_adr(intobj)
            self._trace_drag_out1(singleaddr)

    def rrc_minor_collection_free(self):
        ll_assert(self.rrc_p_dict_nurs.length() == 0, "p_dict_nurs not empty 1")
        lst = self.rrc_p_list_young
        while lst.non_empty():
            self._rrc_minor_free(lst.pop(), self.rrc_p_list_old,
                                            self.rrc_p_dict)
        lst = self.rrc_o_list_young
        no_o_dict = self.null_address_dict()
        while lst.non_empty():
            self._rrc_minor_free(lst.pop(), self.rrc_o_list_old,
                                            no_o_dict)

    def _rrc_minor_free(self, pyobject, surviving_list, surviving_dict):
        intobj = self._pyobj(pyobject).ob_pypy_link
        obj = llmemory.cast_int_to_adr(intobj)
        if self.is_in_nursery(obj):
            if self.is_forwarded(obj):
                # Common case: survives and moves
                obj = self.get_forwarding_address(obj)
                intobj = llmemory.cast_adr_to_int(obj, "symbolic")
                self._pyobj(pyobject).ob_pypy_link = intobj
                surviving = True
                if surviving_dict:
                    # Surviving nursery object: was originally in
                    # rrc_p_dict_nurs and now must be put into rrc_p_dict
                    surviving_dict.setitem(obj, pyobject)
            else:
                surviving = False
        elif (bool(self.young_rawmalloced_objects) and
              self.young_rawmalloced_objects.contains(obj)):
            # young weakref to a young raw-malloced object
            if self.header(obj).tid & GCFLAG_VISITED_RMY:
                surviving = True    # survives, but does not move
            else:
                surviving = False
                if surviving_dict:
                    # Dying young large object: was in rrc_p_dict,
                    # must be deleted
                    surviving_dict.setitem(obj, llmemory.NULL)
        else:
            ll_assert(False, "rrc_X_list_young contains non-young obj")
            return
        #
        if surviving:
            surviving_list.append(pyobject)
        else:
            self._rrc_free(pyobject)

    def _rrc_free(self, pyobject):
        from rpython.rlib.rawrefcount import REFCNT_FROM_PYPY
        from rpython.rlib.rawrefcount import REFCNT_FROM_PYPY_LIGHT
        #
        rc = self._pyobj(pyobject).ob_refcnt
        if rc >= REFCNT_FROM_PYPY_LIGHT:
            rc -= REFCNT_FROM_PYPY_LIGHT
            if rc == 0:
                lltype.free(self._pyobj(pyobject), flavor='raw')
            else:
                # can only occur if LIGHT is used in create_link_pyobj()
                self._pyobj(pyobject).ob_refcnt = rc
                self._pyobj(pyobject).ob_pypy_link = 0
        else:
            ll_assert(rc >= REFCNT_FROM_PYPY, "refcount underflow?")
            ll_assert(rc < int(REFCNT_FROM_PYPY_LIGHT * 0.99),
                      "refcount underflow from REFCNT_FROM_PYPY_LIGHT?")
            rc -= REFCNT_FROM_PYPY
            self._pyobj(pyobject).ob_pypy_link = 0
            if rc == 0:
                self.rrc_dealloc_pending.append(pyobject)
                # an object with refcnt == 0 cannot stay around waiting
                # for its deallocator to be called.  Some code (lxml)
                # expects that tp_dealloc is called immediately when
                # the refcnt drops to 0.  If it isn't, we get some
                # uncleared raw pointer that can still be used to access
                # the object; but (PyObject *)raw_pointer is then bogus
                # because after a Py_INCREF()/Py_DECREF() on it, its
                # tp_dealloc is also called!
                rc = 1
            self._pyobj(pyobject).ob_refcnt = rc
    _rrc_free._always_inline_ = True

    def rrc_major_collection_trace(self):
        self.rrc_p_list_old.foreach(self._rrc_major_trace, None)

    def _rrc_major_trace(self, pyobject, ignore):
        from rpython.rlib.rawrefcount import REFCNT_FROM_PYPY
        from rpython.rlib.rawrefcount import REFCNT_FROM_PYPY_LIGHT
        #
        rc = self._pyobj(pyobject).ob_refcnt
        if rc == REFCNT_FROM_PYPY or rc == REFCNT_FROM_PYPY_LIGHT:
            pass     # the corresponding object may die
        else:
            # force the corresponding object to be alive
            intobj = self._pyobj(pyobject).ob_pypy_link
            obj = llmemory.cast_int_to_adr(intobj)
            self.objects_to_trace.append(obj)
            self.visit_all_objects()

    def rrc_major_collection_free(self):
        ll_assert(self.rrc_p_dict_nurs.length() == 0, "p_dict_nurs not empty 2")
        length_estimate = self.rrc_p_dict.length()
        self.rrc_p_dict.delete()
        self.rrc_p_dict = new_p_dict = self.AddressDict(length_estimate)
        new_p_list = self.AddressStack()
        while self.rrc_p_list_old.non_empty():
            self._rrc_major_free(self.rrc_p_list_old.pop(), new_p_list,
                                                            new_p_dict)
        self.rrc_p_list_old.delete()
        self.rrc_p_list_old = new_p_list
        #
        new_o_list = self.AddressStack()
        no_o_dict = self.null_address_dict()
        while self.rrc_o_list_old.non_empty():
            self._rrc_major_free(self.rrc_o_list_old.pop(), new_o_list,
                                                            no_o_dict)
        self.rrc_o_list_old.delete()
        self.rrc_o_list_old = new_o_list

    def _rrc_major_free(self, pyobject, surviving_list, surviving_dict):
        # The pyobject survives if the corresponding obj survives.
        # This is true if the obj has one of the following two flags:
        #  * GCFLAG_VISITED: was seen during tracing
        #  * GCFLAG_NO_HEAP_PTRS: immortal object never traced (so far)
        intobj = self._pyobj(pyobject).ob_pypy_link
        obj = llmemory.cast_int_to_adr(intobj)
        if self.header(obj).tid & (GCFLAG_VISITED | GCFLAG_NO_HEAP_PTRS):
            surviving_list.append(pyobject)
            if surviving_dict:
                surviving_dict.insertclean(obj, pyobject)
        else:
            self._rrc_free(pyobject)
