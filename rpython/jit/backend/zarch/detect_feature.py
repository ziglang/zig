import sys
import struct
import platform
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.tool import rffi_platform
from rpython.rlib.rmmap import alloc, free
from rpython.rlib.rstruct.runpack import runpack
from rpython.translator.platform.arch.s390x import s390x_detect_vx

SYSTEM = platform.system()

def detect_simd_z_linux():
    return s390x_detect_vx()

def detect_simd_z():
    if SYSTEM == 'Linux':
        return detect_simd_z_linux()
    return False

if __name__ == '__main__':
    print 'The following extensions are supported:'
    if detect_simd_z():
        print '  - SIMD Z'
