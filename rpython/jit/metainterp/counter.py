from rpython.rlib.rarithmetic import r_singlefloat, r_uint
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo


r_uint32 = rffi.r_uint
assert r_uint32.BITS == 32
UINT32MAX = 2 ** 32 - 1

# keep in sync with the C code in pypy__decay_jit_counters below
ENTRY = lltype.Struct('timetable_entry',
                      ('times', lltype.FixedSizeArray(rffi.FLOAT, 5)),
                      ('subhashes', lltype.FixedSizeArray(rffi.USHORT, 5)))


class JitCounter:
    """A process translated with the JIT contains one prebuilt instance
    of this class.  It is used for three things:

    * It maps greenkey hashes to counters, to know when we have seen this
      greenkey enough to reach the 'threshold' or 'function_threshold'
      parameters.  This is done in a lossy way by a fixed-size 'timetable'.

    * It handles the counters on the failing guards, for 'trace_eagerness'.
      This is done in the same 'timetable'.

    * It records the JitCell objects that are created when we compile
      a loop, in a non-lossy dictionary-like strurcture.  This is done
      in the 'celltable'.

    The 'timetable' is a table of DEFAULT_SIZE entries, each of which
    containing 5 entries.  From a hash value, we use the index number
    '_get_index(hash)', and then we look in all five entries for a
    matching '_get_subhash(hash)'.  The five entries are roughly kept
    sorted by decreasing recorded time.  The hash value itself should be
    computed accordingly: we only use bits 21:32 for _get_index and
    bits 0:16 for _get_subhash.  (This organization is "probably good"
    to get not-too-random behavior; another motivation for it was for
    the STM branch, to avoid pointless conflicts between threads.)

    The time value stored in the timetable is a (short-precision)
    floating-point number.  The idea is that a value of 0.0 means
    absent, and values go up to the maximum of 1.0.

    'compute_threshold(threshold)' returns basically the fraction
    1.0/threshold, corresponding to the 'increment' value for the
    following APIs.

    'tick(hash, increment)' adds 'increment' to the time value stored
    with the 'hash'.  Remember that only bits 0:16,21:32 of the hash
    are used; in case of collision between two hashes, they will grow
    twice as fast, because each tick() call will contribute to the
    colliding time value.

    'fetch_next_hash()' returns a "random" hash value suitable for
    using in tick() later.  Used when compiling guards; when the
    guard actually fails, we'll tick() the guard's stored random hash.

    'reset(hash)', 'change_current_fraction(hash, new_time_value)'
    change the time value associated with a hash.  The former resets
    it to zero, and the latter changes it to the given value (which
    should be a value close to 1.0).

    'set_decay(decay)', 'decay_all_counters()' is used to globally
    reduce all the stored time values.  They all get multiplied by
    a fraction close to (but smaller than) 1.0, computed from the
    'decay' parameter.

    'install_new_cell(hash, newcell)' adds the new JitCell to the
    celltable, at the index given by 'hash' (bits 21:32).  Unlike
    the timetable, the celltable stores a linked list of JitCells
    for every entry, and so it is not lossy.

    'lookup_chain(hash)' returns the first JitCell at 'hash'.  You can
    then walk the chain by following the '.next' attributes until you
    reach None.

    'cleanup_chain(hash)' resets the timetable's 'hash' entry and
    cleans up the celltable at 'hash'.  It removes those JitCells
    for which 'cell.should_remove_jitcell()' returns True.
    """
    DEFAULT_SIZE = 2048

    def __init__(self, size=DEFAULT_SIZE, translator=None):
        "NOT_RPYTHON"
        self.size = size
        self.shift = 16
        while (UINT32MAX >> self.shift) != size - 1:
            self.shift += 1
            assert self.shift < 999, "size is not a power of two <= 2**16"
        #
        # The table of timings.  This is a 5-ways associative cache.
        # We index into it using a number between 0 and (size - 1),
        # and we're getting a 32-bytes-long entry; then this entry
        # contains 5 possible ways, each occupying 6 bytes: 4 bytes
        # for a float, and the 2 lowest bytes from the original hash.
        self.timetable = lltype.malloc(rffi.CArray(ENTRY), self.size,
                                       flavor='raw', zero=True,
                                       track_allocation=False)
        self._nexthash = r_uint(0)
        #
        # The table of JitCell entries, recording already-compiled loops
        self.celltable = [None] * size
        #
        if translator is not None:
            class Glob:
                step = 0
            glob = Glob()
            def invoke_after_minor_collection():
                # After 32 minor collections, we call decay_all_counters().
                # The "--jit decay=N" option measures the amount the
                # counters are then reduced by.
                glob.step += 1
                if glob.step == 32:
                    glob.step = 0
                    self.decay_all_counters()
            if not hasattr(translator, '_jit2gc'):
                translator._jit2gc = {}
            translator._jit2gc['invoke_after_minor_collection'] = (
                invoke_after_minor_collection)

    def compute_threshold(self, threshold):
        """Return the 'increment' value corresponding to the given number."""
        if threshold <= 0:
            return 0.0   # no increment, never reach 1.0
        return 1.0 / (threshold - 0.001)

    def _get_index(self, hash):
        """Return the index (< self.size) from a hash.  This truncates
        the hash to 32 bits, and then keep the *highest* remaining bits.
        Be sure that hash is computed correctly, by multiplying with
        a large odd number or by fetch_next_hash()."""
        hash32 = r_uint(r_uint32(hash))  # mask off the bits higher than 32
        index = hash32 >> self.shift     # shift, resulting in a value < size
        return index                     # return the result as a r_uint
    _get_index._always_inline_ = True

    @staticmethod
    def _get_subhash(hash):
        return hash & 65535

    def fetch_next_hash(self):
        result = self._nexthash
        # note: all three "1" bits in the following constant are needed
        # to make test_counter.test_fetch_next_index pass.  The first
        # is to increment the "subhash" (lower 16 bits of the hash).
        # The second is to increment the "index" portion of the hash.
        # The third is so that after 65536 passes, the "index" is
        # incremented by one more (by overflow), so that the next
        # 65536 passes don't end up with the same subhashes.
        self._nexthash = result + r_uint(1 | (1 << self.shift) |
                                         (1 << (self.shift - 16)))
        return result

    def _swap(self, p_entry, n):
        if float(p_entry.times[n]) > float(p_entry.times[n + 1]):
            return n + 1
        else:
            x = p_entry.times[n]
            p_entry.times[n] = p_entry.times[n + 1]
            p_entry.times[n + 1] = x
            x = p_entry.subhashes[n]
            p_entry.subhashes[n] = p_entry.subhashes[n + 1]
            p_entry.subhashes[n + 1] = x
            return n
    _swap._always_inline_ = True

    def _tick_slowpath(self, p_entry, subhash):
        if p_entry.subhashes[1] == subhash:
            n = self._swap(p_entry, 0)
        elif p_entry.subhashes[2] == subhash:
            n = self._swap(p_entry, 1)
        elif p_entry.subhashes[3] == subhash:
            n = self._swap(p_entry, 2)
        elif p_entry.subhashes[4] == subhash:
            n = self._swap(p_entry, 3)
        else:
            n = 4
            while n > 0 and float(p_entry.times[n - 1]) == 0.0:
                n -= 1
            p_entry.subhashes[n] = rffi.cast(rffi.USHORT, subhash)
            p_entry.times[n] = r_singlefloat(0.0)
        return n

    def tick(self, hash, increment):
        p_entry = self.timetable[self._get_index(hash)]
        subhash = self._get_subhash(hash)
        #
        if p_entry.subhashes[0] == subhash:
            n = 0
        else:
            n = self._tick_slowpath(p_entry, subhash)
        #
        counter = float(p_entry.times[n]) + increment
        if counter < 1.0:
            p_entry.times[n] = r_singlefloat(counter)
            return False
        else:
            # when the bound is reached, we immediately reset the value to 0.0
            self.reset(hash)
            return True
    tick._always_inline_ = True

    def change_current_fraction(self, hash, new_fraction):
        """Change the value stored for 'hash' to be the given 'new_fraction',
        which should be a float equal to or slightly lower than 1.0.
        """
        p_entry = self.timetable[self._get_index(hash)]
        subhash = self._get_subhash(hash)

        # find in 'n' the index that will be overwritten: the first within
        # range(5) that contains either the right subhash, or a null time
        # (or, if there isn't any, then just n == 4 will do).
        n = 0
        while n < 4 and (p_entry.subhashes[n] != subhash and
                         float(p_entry.times[n]) != 0.0):
            n += 1

        # move one step to the right all elements [n - 1, n - 2, ..., 0],
        # (this overwrites the old item at index 'n')
        while n > 0:
            n -= 1
            p_entry.subhashes[n + 1] = p_entry.subhashes[n]
            p_entry.times[n + 1]     = p_entry.times[n]

        # insert the new hash at index 0.  This is a good approximation,
        # because change_current_fraction() should be used for
        # new_fraction == value close to 1.0.
        p_entry.subhashes[0] = rffi.cast(rffi.USHORT, subhash)
        p_entry.times[0]     = r_singlefloat(new_fraction)

    def reset(self, hash):
        p_entry = self.timetable[self._get_index(hash)]
        subhash = self._get_subhash(hash)
        for i in range(5):
            if p_entry.subhashes[i] == subhash:
                p_entry.times[i] = r_singlefloat(0.0)

    def lookup_chain(self, hash):
        return self.celltable[self._get_index(hash)]

    def cleanup_chain(self, hash):
        self.reset(hash)
        self.install_new_cell(hash, None)

    def install_new_cell(self, hash, newcell):
        index = self._get_index(hash)
        cell = self.celltable[index]
        keep = newcell
        while cell is not None:
            nextcell = cell.next
            if not cell.should_remove_jitcell():
                cell.next = keep
                keep = cell
            cell = nextcell
        self.celltable[index] = keep

    def set_decay(self, decay):
        """Set the decay, from 0 (none) to 1000 (max)."""
        if decay < 0:
            decay = 0
        elif decay > 1000:
            decay = 1000
        self.decay_by_mult = 1.0 - (decay * 0.001)

    def decay_all_counters(self):
        # Called during a minor collection by the GC, to gradually decay
        # counters that didn't reach their maximum.  Thus if a counter
        # is incremented very slowly, it will never reach the maximum.
        # This avoids altogether the JIT compilation of rare paths.
        # We also call this function when any maximum bound is reached,
        # to avoid sudden bursts of JIT-compilation (the next one will
        # not reach the maximum bound immmediately after).  This is
        # important in corner cases where we would suddenly compile more
        # than one loop because all counters reach the bound at the same
        # time, but where compiling all but the first one is pointless.
        p = rffi.cast(rffi.CCHARP, self.timetable)
        pypy__decay_jit_counters(p, self.decay_by_mult, self.size)


# this function is written directly in C; gcc will optimize it using SSE
eci = ExternalCompilationInfo(post_include_bits=["""
static void pypy__decay_jit_counters(char *data, double f1, long size) {
    struct rpy_jitcnt { float times[5]; unsigned short subhashes[5]; };
    struct rpy_jitcnt *p = (struct rpy_jitcnt *)data;
    float f = (float)f1;
    long i;
    for (i=0; i<size; i++) {
        p->times[0] *= f;
        p->times[1] *= f;
        p->times[2] *= f;
        p->times[3] *= f;
        p->times[4] *= f;
        ++p;
    }
}
"""])

pypy__decay_jit_counters = rffi.llexternal(
    "pypy__decay_jit_counters", [rffi.CCHARP, lltype.Float, lltype.Signed],
    lltype.Void, compilation_info=eci, _nowrapper=True, sandboxsafe=True)


# ____________________________________________________________
#
# A non-RPython version that avoids issues with rare random collisions,
# which make all tests brittle

class DeterministicJitCounter(JitCounter):
    def __init__(self):
        from collections import defaultdict
        JitCounter.__init__(self, size=8)
        def make_null_entry():
            return lltype.malloc(ENTRY, immortal=True, zero=True)
        self.timetable = defaultdict(make_null_entry)
        self.celltable = defaultdict(lambda: None)

    def _get_index(self, hash):
        "NOT_RPYTHON"
        return hash

    def decay_all_counters(self):
        "NOT_RPYTHON"
        pass

    def _clear_all(self):
        self.timetable.clear()
        self.celltable.clear()
