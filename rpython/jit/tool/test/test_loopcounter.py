from cStringIO import StringIO
from rpython.jit.tool.loopcounter import count_loops_and_bridges

def test_loopcounter():
    log = StringIO("""
[1200] {stuff
...
[1201] stuff}
[120a] {jit-mem-looptoken-alloc
allocating Loop # 0
[120b] jit-mem-looptoken-alloc}
[1300] {jit-mem-looptoken-alloc
allocating Bridge # 1 of Loop # 0
[1301] jit-mem-looptoken-alloc}
[1400] {jit-mem-looptoken-alloc
allocating Bridge # 2 of Loop # 0
[1401] jit-mem-looptoken-alloc}
[1500] {jit-mem-looptoken-alloc
allocating Loop # 1
[1501] jit-mem-looptoken-alloc}
[1600] {jit-mem-looptoken-free
freeing Loop # 0 with 2 attached bridges
[1601] jit-mem-looptoken-free}
""")
    lines = list(count_loops_and_bridges(log))
    assert lines == [
        # time   total    loops    bridges
        (0x00a,      1,       1,         0),
        (0x100,      2,       1,         1),
        (0x200,      3,       1,         2),
        (0x300,      4,       2,         2),
        (0x400,      1,       1,         0),
        ]
