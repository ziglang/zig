from pypy.tool.memusage import log2gnumeric

log = """
[1000] ...
[2000] {gc-collect

.----------- Full collection ------------------
| used before collection:
|          in ArenaCollection:      500 bytes
|          raw_malloced:            100 bytes
| used after collection:
|          in ArenaCollection:      300 bytes
|          raw_malloced:            50 bytes
| number of major collects:         1
`----------------------------------------------
[3000] gc-collect}
[4000] {gc-collect

.----------- Full collection ------------------
| used before collection:
|          in ArenaCollection:      600 bytes
|          raw_malloced:            200 bytes
| used after collection:
|          in ArenaCollection:      400 bytes
|          raw_malloced:            100 bytes
| number of major collects:         1
`----------------------------------------------
[5000] gc-collect}
...
...
[6000] {translation-task
starting annotate
...
...
[7000] translation-task}
[8000] {translation-task
starting rtype_lltype
...
...
[9000] translation-task}
...
[a000] ...
"""

log = log.replace('\n', '')

def test_get_clock_range():
    minclock, maxclock = log2gnumeric.get_clock_range(log)
    assert minclock == 0x1000
    assert maxclock == 0xa000
    

def test_gc_collect_rows():
    rows = list(log2gnumeric.gc_collect_rows(0x1000, log))
    assert len(rows) == 3
    assert rows[0] == (      'clock', 'gc-before', 'gc-after')
    assert rows[1] == (0x3000-0x1000,     500+100,    300+ 50)
    assert rows[2] == (0x5000-0x1000,     600+200,    400+100)
    
def test_tasks_rows():
    rows = list(log2gnumeric.tasks_rows(0x1000, log))
    assert len(rows) == 3
    assert rows[0] == (      'clock', None, 'task')
    assert rows[1] == (0x6000-0x1000,    1, 'annotate')
    assert rows[2] == (0x8000-0x1000,    1, 'rtype_lltype')


def test_vmrss_rows():
    lines = ['100', '200', '300']
    rows = list(log2gnumeric.vmrss_rows_impl(lines, 2000))
    assert len(rows) == 4
    assert rows[0] == ('inferred clock', 'VmRSS')
    assert rows[1] == (0, 100)
    assert rows[2] == (1000, 200)
    assert rows[3] == (2000, 300)

def test_loops_rows():
    log = """\
[1000] {jit-mem-looptoken-alloc
allocating Loop # 0
[1001] jit-mem-looptoken-alloc}
[2000] {jit-mem-looptoken-alloc
allocating Loop # 1
[2001] jit-mem-looptoken-alloc}
[3000] {jit-mem-looptoken-alloc
allocating Bridge # 1 of Loop # 0
[3001] jit-mem-looptoken-alloc}
[4000] {jit-mem-looptoken-free
freeing Loop # 0 with 1 attached bridges
[4001]
"""
    log = log.replace('\n', '')
    rows = list(log2gnumeric.loops_rows(0x1000, log))
    assert len(rows) == 5
    assert rows[0] == ('clock', 'total', 'loops', 'bridges')
    assert rows[1] == (    0x0,       1,       1,         0)
    assert rows[2] == ( 0x1000,       2,       2,         0)
    assert rows[3] == ( 0x2000,       3,       2,         1)
    assert rows[4] == ( 0x3000,       1,       1,         0)
