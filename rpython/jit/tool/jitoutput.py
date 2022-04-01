
""" Helpers for parsing various outputs jit produces.
Notably:
1. Statistics of log.ops
2. Parsing what jitprof produces
"""

import re

REGEXES = [
    (('tracing_no', 'tracing_time'), '^Tracing:\s+([\d.]+)\s+([\d.]+)$'),
    (('backend_no', 'backend_time'), '^Backend:\s+([\d.]+)\s+([\d.]+)$'),
    (None, '^TOTAL.*$'),
    (('ops.total',), '^ops:\s+(\d+)$'),
    (('heapcached_ops', ), '^heapcached ops:\s+(\d+)$'),
    (('recorded_ops.total',), '^recorded ops:\s+(\d+)$'),
    (('recorded_ops.calls',), '^\s+calls:\s+(\d+)$'),
    (('guards',), '^guards:\s+(\d+)$'),
    (('opt_ops',), '^opt ops:\s+(\d+)$'),
    (('opt_guards',), '^opt guards:\s+(\d+)$'),
    (('opt_guards_shared',), '^opt guards shared:\s+(\d+)$'),
    (('forcings',), '^forcings:\s+(\d+)$'),
    (('abort.trace_too_long',), '^abort: trace too long:\s+(\d+)$'),
    (('abort.compiling',), '^abort: compiling:\s+(\d+)$'),
    (('abort.vable_escape',), '^abort: vable escape:\s+(\d+)$'),
    (('abort.bad_loop',), '^abort: bad loop:\s+(\d+)$'),
    (('abort.force_quasiimmut',), '^abort: force quasi-immut:\s+(\d+)$'),
    (('abort.segmenting_trace',), '^abort: segmenting trace:\s+(\d+)$'),
    (('nvirtuals',), '^nvirtuals:\s+(\d+)$'),
    (('nvholes',), '^nvholes:\s+(\d+)$'),
    (('nvreused',), '^nvreused:\s+(\d+)$'),
    (('vecopt_tried',), '^vecopt tried:\s+(\d+)$'),
    (('vecopt_success',), '^vecopt success:\s+(\d+)$'),
    (('total_compiled_loops',),   '^Total # of loops:\s+(\d+)$'),
    (('total_compiled_bridges',), '^Total # of bridges:\s+(\d+)$'),
    (('total_freed_loops',),      '^Freed # of loops:\s+(\d+)$'),
    (('total_freed_bridges',),    '^Freed # of bridges:\s+(\d+)$'),
    ]

class Ops(object):
    total = 0

class RecordedOps(Ops):
    calls = 0

class Aborts(object):
    trace_too_long = 0
    compiling = 0
    vable_escape = 0

class OutputInfo(object):
    tracing_no = 0
    tracing_time = 0.0
    backend_no = 0
    backend_time = 0.0
    asm_no = 0
    asm_time = 0.0
    guards = 0
    opt_ops = 0
    opt_guards = 0
    forcings = 0
    nvirtuals = 0
    nvholes = 0
    nvreused = 0
    vecopt_tried = 0
    vecopt_success = 0

    def __init__(self):
        self.ops = Ops()
        self.recorded_ops = RecordedOps()
        self.abort = Aborts()

def parse_prof(output):
    lines = output.splitlines()
    # assert len(lines) == len(REGEXES)
    info = OutputInfo()
    for (attrs, regexp), line in zip(REGEXES, lines):
        m = re.match(regexp, line)
        assert m is not None, "Error parsing line: %s" % line
        if attrs:
            for i, a in enumerate(attrs):
                v = m.group(i + 1)
                if '.' in v:
                    v = float(v)
                else:
                    v = int(v)
                if '.' in a:
                    before, after = a.split('.')
                    setattr(getattr(info, before), after, v)
                else:
                    setattr(info, a, v)
    return info
