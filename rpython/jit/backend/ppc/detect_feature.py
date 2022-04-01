import os
import sys
import struct
import platform
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rtyper.tool import rffi_platform
from rpython.rlib.rmmap import alloc, free
from rpython.rlib.rstruct.runpack import runpack

AT_HWCAP = rffi_platform.getconstantinteger('AT_HWCAP', '#include "linux/auxvec.h"')
AT_NULL = rffi_platform.getconstantinteger('AT_NULL', '#include "linux/auxvec.h"')
PPC_FEATURE_HAS_ALTIVEC = rffi_platform.getconstantinteger('PPC_FEATURE_HAS_ALTIVEC',
                                                   '#include "asm/cputable.h"')
SYSTEM = platform.system()

def detect_vsx_linux():
    try:
        fd = os.open("/proc/self/auxv", os.O_RDONLY, 0644)
        try:
            while True:
                buf = os.read(fd, 8)
                buf2 = os.read(fd, 8)
                if not buf or not buf2:
                    break
                key = runpack("L", buf)
                value = runpack("L", buf2)
                if key == AT_HWCAP:
                    if value & PPC_FEATURE_HAS_ALTIVEC:
                        return True
                if key == AT_NULL:
                    return False
        finally:
            os.close(fd)
    except OSError:
        pass
    return False

def detect_vsx():
    if SYSTEM == 'Linux':
        return detect_vsx_linux()
    return False

if __name__ == '__main__':
    print 'The following extensions are supported:'
    if detect_vsx():
        print '  - AltiVec'
