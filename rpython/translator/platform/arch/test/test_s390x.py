import py
import platform
from rpython.translator.platform.arch.s390x import (s390x_cpu_revision,
        extract_s390x_cpu_ids)

if platform.machine() != 's390x':
    py.test.skip("s390x tests only")

def test_cpuid_s390x():
    revision = s390x_cpu_revision()
    assert revision != 'unknown', 'the model you are running on might be too old'

def test_read_processor_info():
    ids = extract_s390x_cpu_ids("""
processor 0: machine = 12345
processor 1: version = FF, identification = AF
    """.splitlines())
    assert ids == [(0, None, None, 0x12345),
                   (1, 'FF', 'AF', 0),
                  ]


