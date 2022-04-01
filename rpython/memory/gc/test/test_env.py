import os, py
from rpython.memory.gc import env
from rpython.rlib.rarithmetic import r_uint
from rpython.tool.udir import udir


class FakeEnviron:
    def __init__(self, value):
        self._value = value
    def get(self, varname):
        assert varname == 'FOOBAR'
        return self._value

def check_equal(x, y):
    assert x == y
    assert type(x) == type(y)

def test_get_total_memory_darwin():
    # this only tests clipping
    BIG = 2 * env.addressable_size
    SMALL = env.addressable_size / 2
    assert env.addressable_size == env.get_total_memory_darwin(0)
    assert env.addressable_size == env.get_total_memory_darwin(-1)
    assert env.addressable_size == env.get_total_memory_darwin(BIG)
    assert SMALL == env.get_total_memory_darwin(SMALL)

def test_get_total_memory():
    # total memory should be at least a megabyte
    assert env.get_total_memory() > 1024*1024

def test_read_from_env():
    saved = os.environ
    try:
        os.environ = FakeEnviron(None)
        check_equal(env.read_from_env('FOOBAR'), 0)
        check_equal(env.read_uint_from_env('FOOBAR'), r_uint(0))
        check_equal(env.read_float_from_env('FOOBAR'), 0.0)
        #
        os.environ = FakeEnviron('')
        check_equal(env.read_from_env('FOOBAR'), 0)
        check_equal(env.read_uint_from_env('FOOBAR'), r_uint(0))
        check_equal(env.read_float_from_env('FOOBAR'), 0.0)
        #
        os.environ = FakeEnviron('???')
        check_equal(env.read_from_env('FOOBAR'), 0)
        check_equal(env.read_uint_from_env('FOOBAR'), r_uint(0))
        check_equal(env.read_float_from_env('FOOBAR'), 0.0)
        #
        os.environ = FakeEnviron('1')
        check_equal(env.read_from_env('FOOBAR'), 1)
        check_equal(env.read_uint_from_env('FOOBAR'), r_uint(1))
        check_equal(env.read_float_from_env('FOOBAR'), 1.0)
        #
        os.environ = FakeEnviron('12345678')
        check_equal(env.read_from_env('FOOBAR'), 12345678)
        check_equal(env.read_uint_from_env('FOOBAR'), r_uint(12345678))
        check_equal(env.read_float_from_env('FOOBAR'), 12345678.0)
        #
        os.environ = FakeEnviron('1234B')
        check_equal(env.read_from_env('FOOBAR'), 1234)
        check_equal(env.read_uint_from_env('FOOBAR'), r_uint(1234))
        check_equal(env.read_float_from_env('FOOBAR'), 1234.0)
        #
        os.environ = FakeEnviron('1.5')
        check_equal(env.read_float_from_env('FOOBAR'), 1.5)
        #
        os.environ = FakeEnviron('1.5Kb')
        check_equal(env.read_from_env('FOOBAR'), 1536)
        check_equal(env.read_uint_from_env('FOOBAR'), r_uint(1536))
        check_equal(env.read_float_from_env('FOOBAR'), 0.0)
        #
        os.environ = FakeEnviron('1.5mB')
        check_equal(env.read_from_env('FOOBAR'), int(1.5*1024*1024))
        check_equal(env.read_uint_from_env('FOOBAR'), r_uint(1.5*1024*1024))
        check_equal(env.read_float_from_env('FOOBAR'), 0.0)
        #
        os.environ = FakeEnviron('1.5g')
        check_equal(env.read_from_env('FOOBAR'), int(1.5*1024*1024*1024))
        check_equal(env.read_uint_from_env('FOOBAR'), r_uint(1.5*1024*1024*1024))
        check_equal(env.read_float_from_env('FOOBAR'), 0.0)
        #
    finally:
        os.environ = saved

def test_get_total_memory_linux2():
    filepath = udir.join('get_total_memory_linux2')
    filepath.write("""\
MemTotal:        1976804 kB
MemFree:           32200 kB
Buffers:          144092 kB
Cached:          1385196 kB
SwapCached:         8408 kB
Active:          1181436 kB
etc.
""")
    result = env.get_total_memory_linux2(str(filepath))
    assert result == 1976804 * 1024

def test_get_total_memory_linux2_32bit_limit():
    filepath = udir.join('get_total_memory_linux2')
    filepath.write("""\
MemTotal:        3145728 kB
etc.
""")
    saved = env.addressable_size
    try:
        env.addressable_size = float(2**31)
        result = env.get_total_memory_linux2(str(filepath))
        check_equal(result, float(2**31))    # limit hit
        #
        env.addressable_size = float(2**32)
        result = env.get_total_memory_linux2(str(filepath))
        check_equal(result, float(3145728 * 1024))    # limit not hit
    finally:
        env.addressable_size = saved

def test_estimate_best_nursery_size_linux2():
    filepath = udir.join('estimate_best_nursery_size_linux2')
    filepath.write("""\
processor   : 0
vendor_id   : GenuineIntel
cpu family  : 6
model       : 37
model name  : Intel(R) Core(TM) i5 CPU       M 540  @ 2.53GHz
stepping    : 5
cpu MHz     : 1199.000
cache size  : 3072 KB
physical id : 0
siblings    : 4
core id     : 0
cpu cores   : 2
apicid      : 0
initial apicid  : 0
fpu     : yes
fpu_exception   : yes
cpuid level : 11
wp      : yes
flags       : fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx rdtscp lm constant_tsc arch_perfmon pebs bts rep_good xtopology nonstop_tsc aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 cx16 xtpr pdcm sse4_1 sse4_2 popcnt aes lahf_lm ida arat tpr_shadow vnmi flexpriority ept vpid
bogomips    : 5054.78
clflush size    : 64
cache_alignment : 64
address sizes   : 36 bits physical, 48 bits virtual
power management:

processor   : 1
vendor_id   : GenuineIntel
cpu family  : 6
model       : 37
model name  : Intel(R) Core(TM) i5 CPU       M 540  @ 2.53GHz
stepping    : 5
cpu MHz     : 2534.000
cache size  : 3072 KB
physical id : 0
siblings    : 4
core id     : 0
cpu cores   : 2
apicid      : 1
initial apicid  : 1
fpu     : yes
etc.
""")
    result = env.get_L2cache_linux2_cpuinfo(str(filepath))
    assert result == 3072 * 1024

def test_estimate_nursery_s390x():
    filepath = udir.join('estimate_best_nursery_size_linux2')
    filepath.write("""\
vendor_id       : IBM/S390
# processors    : 2
bogomips per cpu: 20325.00
...
cache2          : level=2 type=Data scope=Private size=2048K line_size=256 associativity=8
cache3          : level=2 type=Instruction scope=Private size=2048K line_size=256 associativity=8
...
""")
    result = env.get_L2cache_linux2_cpuinfo_s390x(str(filepath))
    assert result == 2048 * 1024

    filepath = udir.join('estimate_best_nursery_size_linux3')
    filepath.write("""\
vendor_id       : IBM/S390
# processors    : 2
bogomips per cpu: 9398.00
...
cache2          : level=2 type=Unified scope=Private size=1536K line_size=256 associativity=12
cache3          : level=3 type=Unified scope=Shared size=24576K line_size=256 associativity=12
...
""")
    result = env.get_L2cache_linux2_cpuinfo_s390x(str(filepath), label='cache3')
    assert result == 24576 * 1024
    result = env.get_L2cache_linux2_cpuinfo_s390x(str(filepath), label='cache2')
    assert result == 1536 * 1024
