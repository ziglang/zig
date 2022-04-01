import math
from rpython.rlib.rarithmetic import r_int64
from rpython.rlib.debug import debug_start, debug_print, debug_stop
from rpython.rlib.objectmodel import we_are_translated

#
# Logic to decide which loops are old and not used any more.
#
# All the long-lived references to LoopToken are weakrefs (see JitCell
# in warmstate.py), apart from the 'alive_loops' set in MemoryManager,
# which is the only (long-living) place that keeps them alive.  If a
# loop was not called for long enough, then it is removed from
# 'alive_loops'.  It will soon be freed by the GC.  LoopToken.__del__
# calls the method cpu.free_loop_and_bridges().
#
# The alive_loops set is maintained using the notion of a global
# 'current generation' which is, in practice, the total number of loops
# and bridges produced so far.  A LoopToken is declared "old" if its
# 'generation' field is much smaller than the current generation, and
# removed from the set.
#

class MemoryManager(object):

    def __init__(self):
        self.check_frequency = -1
        # NB. use of r_int64 to be extremely far on the safe side:
        # this is increasing by one after each loop or bridge is
        # compiled, and it must not overflow.  If the backend implements
        # complete freeing in cpu.free_loop_and_bridges(), then it may
        # be possible to get arbitrary many of them just by waiting long
        # enough.  But in this day and age, you'd still never have the
        # patience of waiting for a slowly-increasing 64-bit number to
        # overflow :-)

        # According to my estimates it's about 5e9 years given 1000 loops
        # per second
        self.current_generation = r_int64(1)
        self.next_check = r_int64(-1)
        self.alive_loops = {}

    def set_max_age(self, max_age, check_frequency=0):
        if max_age <= 0:
            self.next_check = r_int64(-1)
        else:
            self.max_age = max_age
            if check_frequency <= 0:
                check_frequency = int(math.sqrt(max_age))
            self.check_frequency = check_frequency
            self.next_check = self.current_generation + 1

    def next_generation(self):
        self.current_generation += 1
        if self.current_generation == self.next_check:
            self._kill_old_loops_now()
            self.next_check = self.current_generation + self.check_frequency

    def keep_loop_alive(self, looptoken):
        if looptoken.generation != self.current_generation:
            looptoken.generation = self.current_generation
            self.alive_loops[looptoken] = None

    def _kill_old_loops_now(self):
        debug_start("jit-mem-collect")
        oldtotal = len(self.alive_loops)
        #print self.alive_loops.keys()
        debug_print("Current generation:", self.current_generation)
        debug_print("Loop tokens before:", oldtotal)
        max_generation = self.current_generation - (self.max_age-1)
        for looptoken in self.alive_loops.keys():
            if (0 <= looptoken.generation < max_generation or
                looptoken.invalidated):
                del self.alive_loops[looptoken]
        newtotal = len(self.alive_loops)
        debug_print("Loop tokens freed: ", oldtotal - newtotal)
        debug_print("Loop tokens left:  ", newtotal)
        #print self.alive_loops.keys()
        if not we_are_translated() and oldtotal != newtotal:
            looptoken = None
            from rpython.rlib import rgc
            # a single one is not enough for all tests :-(
            rgc.collect(); rgc.collect(); rgc.collect()
        debug_stop("jit-mem-collect")

    def release_all_loops(self):
        debug_start("jit-mem-releaseall")
        debug_print("Loop tokens cleared:", len(self.alive_loops))
        self.alive_loops.clear()
        debug_stop("jit-mem-releaseall")
