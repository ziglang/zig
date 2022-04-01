
import py
from rpython.jit.metainterp.warmspot import ll_meta_interp
from rpython.rlib.jit import JitDriver
from rpython.jit.backend.llgraph import runner
from rpython.jit.metainterp.jitprof import Profiler, JITPROF_LINES
from rpython.jit.tool.jitoutput import parse_prof
from rpython.tool.logparser import parse_log, extract_category

def test_really_run():
    """ This test checks whether output of jitprof did not change.
    It'll explode when someone touches jitprof.py
    """
    mydriver = JitDriver(reds = ['i', 'n'], greens = [])
    def f(n):
        i = 0
        while i < n:
            mydriver.can_enter_jit(i=i, n=n)
            mydriver.jit_merge_point(i=i, n=n)
            i += 1

    cap = py.io.StdCaptureFD()
    try:
        ll_meta_interp(f, [10], CPUClass=runner.LLGraphCPU,
                       ProfilerClass=Profiler)
    finally:
        out, err = cap.reset()

    log = parse_log(err.splitlines(True))
    err_sections = list(extract_category(log, 'jit-summary'))
    [err1] = err_sections    # there should be exactly one jit-summary
    assert err1.count("\n") == JITPROF_LINES
    info = parse_prof(err1)
    # assert did not crash
    # asserts below are a bit delicate, possibly they might be deleted
    assert info.tracing_no == 1
    assert info.backend_no == 1
    assert info.ops.total == 2
    assert info.recorded_ops.total == 2
    assert info.recorded_ops.calls == 0
    assert info.guards == 2
    assert info.opt_ops == 11
    assert info.opt_guards == 2
    assert info.forcings == 0

DATA = '''Tracing:         1       0.006992
Backend:        1       0.000525
TOTAL:                  0.025532
ops:                    2
heapcached ops:         111
recorded ops:           6
  calls:                3
guards:                 1
opt ops:                6
opt guards:             1
opt guards shared:      1
forcings:               1
abort: trace too long:  10
abort: compiling:       11
abort: vable escape:    12
abort: bad loop:        135
abort: force quasi-immut: 3
abort: segmenting trace: 0
nvirtuals:              13
nvholes:                14
nvreused:               15
vecopt tried:           12
vecopt success:         4
Total # of loops:       100
Total # of bridges:     300
Freed # of loops:       99
Freed # of bridges:     299
'''

def test_parse():
    info = parse_prof(DATA)
    assert info.tracing_no == 1
    assert info.tracing_time == 0.006992
    assert info.backend_no == 1
    assert info.backend_time == 0.000525
    assert info.ops.total == 2
    assert info.heapcached_ops == 111
    assert info.recorded_ops.total == 6
    assert info.recorded_ops.calls == 3
    assert info.guards == 1
    assert info.opt_ops == 6
    assert info.opt_guards == 1
    assert info.forcings == 1
    assert info.abort.trace_too_long == 10
    assert info.abort.compiling == 11
    assert info.abort.vable_escape == 12
    assert info.abort.bad_loop == 135
    assert info.abort.force_quasiimmut == 3
    assert info.nvirtuals == 13
    assert info.nvholes == 14
    assert info.nvreused == 15
    assert info.vecopt_tried == 12
    assert info.vecopt_success == 4
