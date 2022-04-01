import py
from rpython.tool.udir import udir
from rpython.jit.backend.arm.detect import detect_arch_version, getauxval

cpuinfo = "Processor : ARMv%d-compatible processor rev 7 (v6l)"""
cpuinfo2 = """processor       : 0
vendor_id       : GenuineIntel
cpu family      : 6
model           : 23
model name      : Intel(R) Core(TM)2 Duo CPU     E8400  @ 3.00GHz
stepping        : 10
microcode       : 0xa07
cpu MHz         : 2997.000
cache size      : 6144 KB
physical id     : 0
siblings        : 2
core id         : 0
cpu cores       : 2
apicid          : 0
initial apicid  : 0
fpu             : yes
fpu_exception   : yes
cpuid level     : 13
wp              : yes
flags           : fpu vme ...
bogomips        : 5993.08
clflush size    : 64
cache_alignment : 64
address sizes   : 36 bits physical, 48 bits virtual
power management:
"""
# From a Marvell Armada 370/XP
auxv = (
    '\x10\x00\x00\x00\xd7\xa8\x1e\x00\x06\x00\x00\x00\x00\x10\x00\x00\x11\x00'
    '\x00\x00d\x00\x00\x00\x03\x00\x00\x004\x00\x01\x00\x04\x00\x00\x00 \x00'
    '\x00\x00\x05\x00\x00\x00\t\x00\x00\x00\x07\x00\x00\x00\x00\xe0\xf3\xb6'
    '\x08\x00\x00\x00\x00\x00\x00\x00\t\x00\x00\x00t\xcf\x04\x00\x0b\x00\x00'
    '\x000\x0c\x00\x00\x0c\x00\x00\x000\x0c\x00\x00\r\x00\x00\x000\x0c\x00\x00'
    '\x0e\x00\x00\x000\x0c\x00\x00\x17\x00\x00\x00\x00\x00\x00\x00\x19\x00\x00'
    '\x00\x8a\xf3\x87\xbe\x1a\x00\x00\x00\x00\x00\x00\x00\x1f\x00\x00\x00\xec'
    '\xff\x87\xbe\x0f\x00\x00\x00\x9a\xf3\x87\xbe\x00\x00\x00\x00\x00\x00\x00'
    '\x00'
)


def write_cpuinfo(info):
    filepath = udir.join('get_arch_version')
    filepath.write(info)
    return str(filepath)


def test_detect_arch_version():
    # currently supported cases
    for i in (6, 7, ):
        filepath = write_cpuinfo(cpuinfo % i)
        assert detect_arch_version(filepath) == i
    # unsupported cases
    assert detect_arch_version(write_cpuinfo(cpuinfo % 8)) == 7
    py.test.raises(ValueError,
            'detect_arch_version(write_cpuinfo(cpuinfo % 5))')
    assert detect_arch_version(write_cpuinfo(cpuinfo2)) == 6


def test_getauxval_no_neon():
    path = udir.join('auxv')
    path.write(auxv, 'wb')
    AT_HWCAP = 16
    assert getauxval(AT_HWCAP, filename=str(path)) == 2009303
