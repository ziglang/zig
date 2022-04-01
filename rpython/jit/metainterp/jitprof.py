
""" A small helper module for profiling JIT
"""

import time
from rpython.rlib.debug import debug_print, debug_start, debug_stop
from rpython.rlib.debug import have_debug_prints
from rpython.jit.metainterp.jitexc import JitException
from rpython.rlib.jit import Counters


JITPROF_LINES = Counters.ncounters + 1 + 1
# one for TOTAL, 1 for calls, update if needed
_CPU_LINES = 4       # the last 4 lines are stored on the cpu

class BaseProfiler(object):
    pass

class EmptyProfiler(BaseProfiler):
    initialized = True

    def start(self):
        pass

    def finish(self):
        pass

    def start_tracing(self):
        pass

    def end_tracing(self):
        pass

    def start_backend(self):
        pass

    def end_backend(self):
        pass

    def count(self, kind, inc=1):
        pass

    def count_ops(self, opnum, kind=Counters.OPS):
        pass

    def get_counter(self, num):
        return 0

    def get_times(self, num):
        return 0.0

class Profiler(BaseProfiler):
    initialized = False
    timer = staticmethod(time.time)
    starttime = 0
    t1 = 0
    times = None
    counters = None
    calls = 0
    current = None
    cpu = None

    def start(self):
        self.starttime = self.timer()
        self.t1 = self.starttime
        self.times = [0, 0]
        self.counters = [0] * (Counters.ncounters - _CPU_LINES)
        self.calls = 0
        self.current = []

    def finish(self):
        self.tk = self.timer()
        self.print_stats()

    def _start(self, event):
        t0 = self.t1
        self.t1 = self.timer()
        if self.current:
            self.times[self.current[-1]] += self.t1 - t0
        self.counters[event] += 1
        self.current.append(event)

    def _end(self, event):
        t0 = self.t1
        self.t1 = self.timer()
        if not self.current:
            debug_print("BROKEN PROFILER DATA!")
            return
        ev1 = self.current.pop()
        if ev1 != event:
            debug_print("BROKEN PROFILER DATA!")
            return
        self.times[ev1] += self.t1 - t0

    def start_tracing(self):   self._start(Counters.TRACING)
    def end_tracing(self):     self._end  (Counters.TRACING)

    def start_backend(self):   self._start(Counters.BACKEND)
    def end_backend(self):     self._end  (Counters.BACKEND)

    def count(self, kind, inc=1):
        self.counters[kind] += inc

    def get_counter(self, num):
        if num == Counters.TOTAL_COMPILED_LOOPS:
            return self.cpu.tracker.total_compiled_loops
        elif num == Counters.TOTAL_COMPILED_BRIDGES:
            return self.cpu.tracker.total_compiled_bridges
        elif num == Counters.TOTAL_FREED_LOOPS:
            return self.cpu.tracker.total_freed_loops
        elif num == Counters.TOTAL_FREED_BRIDGES:
            return self.cpu.tracker.total_freed_bridges
        return self.counters[num]

    def get_times(self, num):
        return self.times[num]

    def count_ops(self, opnum, kind=Counters.OPS):
        from rpython.jit.metainterp.resoperation import OpHelpers
        self.counters[kind] += 1
        if OpHelpers.is_call(opnum) and kind == Counters.RECORDED_OPS:
            self.calls += 1

    def print_stats(self):
        debug_start("jit-summary")
        if have_debug_prints():
            self._print_stats()
        debug_stop("jit-summary")

    def _print_stats(self):
        cnt = self.counters
        tim = self.times
        calls = self.calls
        self._print_line_time("Tracing", cnt[Counters.TRACING],
                              tim[Counters.TRACING])
        self._print_line_time("Backend", cnt[Counters.BACKEND],
                              tim[Counters.BACKEND])
        line = "TOTAL:      \t\t%f" % (self.tk - self.starttime, )
        debug_print(line)
        self._print_intline("ops", cnt[Counters.OPS])
        self._print_intline("heapcached ops", cnt[Counters.HEAPCACHED_OPS])
        self._print_intline("recorded ops", cnt[Counters.RECORDED_OPS])
        self._print_intline("  calls", calls)
        self._print_intline("guards", cnt[Counters.GUARDS])
        self._print_intline("opt ops", cnt[Counters.OPT_OPS])
        self._print_intline("opt guards", cnt[Counters.OPT_GUARDS])
        self._print_intline("opt guards shared", cnt[Counters.OPT_GUARDS_SHARED])
        self._print_intline("forcings", cnt[Counters.OPT_FORCINGS])
        self._print_intline("abort: trace too long",
                            cnt[Counters.ABORT_TOO_LONG])
        self._print_intline("abort: compiling", cnt[Counters.ABORT_BRIDGE])
        self._print_intline("abort: vable escape", cnt[Counters.ABORT_ESCAPE])
        self._print_intline("abort: bad loop", cnt[Counters.ABORT_BAD_LOOP])
        self._print_intline("abort: force quasi-immut",
                            cnt[Counters.ABORT_FORCE_QUASIIMMUT])
        self._print_intline("abort: segmenting trace",
                            cnt[Counters.ABORT_SEGMENTED_TRACE])
        self._print_intline("nvirtuals", cnt[Counters.NVIRTUALS])
        self._print_intline("nvholes", cnt[Counters.NVHOLES])
        self._print_intline("nvreused", cnt[Counters.NVREUSED])
        self._print_intline("vecopt tried", cnt[Counters.OPT_VECTORIZE_TRY])
        self._print_intline("vecopt success", cnt[Counters.OPT_VECTORIZED])
        cpu = self.cpu
        if cpu is not None:   # for some tests
            self._print_intline("Total # of loops",
                                cpu.tracker.total_compiled_loops)
            self._print_intline("Total # of bridges",
                                cpu.tracker.total_compiled_bridges)
            self._print_intline("Freed # of loops",
                                cpu.tracker.total_freed_loops)
            self._print_intline("Freed # of bridges",
                                cpu.tracker.total_freed_bridges)

    def _print_line_time(self, string, i, tim):
        final = "%s:%s\t%d\t%f" % (string, " " * max(0, 13-len(string)), i, tim)
        debug_print(final)

    def _print_intline(self, string, i):
        final = string + ':' + " " * max(0, 16-len(string))
        final += '\t' + str(i)
        debug_print(final)


class BrokenProfilerData(JitException):
    pass
