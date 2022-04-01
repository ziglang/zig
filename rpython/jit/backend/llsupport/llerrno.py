import sys
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.jit.backend.llsupport.symbolic import WORD

# NOTE: for tests, cpu._debug_tls_errno_container[1] is reserved for
# thread_ident (see lltls.py)

if sys.byteorder == 'little' or sys.maxint <= 2**32:
    long2int = int2long = lambda x: x
else:
    def long2int(x): return x >> 32
    def int2long(x): return x << 32

def get_debug_saved_errno(cpu):
    return long2int(cpu._debug_tls_errno_container[3])

def set_debug_saved_errno(cpu, nerrno):
    assert nerrno >= 0
    cpu._debug_tls_errno_container[3] = int2long(nerrno)

def get_rpy_errno_offset(cpu):
    if cpu.translate_support_code:
        from rpython.rlib import rthread
        return rthread.tlfield_rpy_errno.getoffset()
    else:
        return 3 * WORD


def get_debug_saved_alterrno(cpu):
    return long2int(cpu._debug_tls_errno_container[4])

def set_debug_saved_alterrno(cpu, nerrno):
    assert nerrno >= 0
    cpu._debug_tls_errno_container[4] = int2long(nerrno)

def get_alt_errno_offset(cpu):
    if cpu.translate_support_code:
        from rpython.rlib import rthread
        return rthread.tlfield_alt_errno.getoffset()
    else:
        return 4 * WORD


def get_debug_saved_lasterror(cpu):
    return cpu._debug_tls_errno_container[5]

def set_debug_saved_lasterror(cpu, nerrno):
    assert nerrno >= 0
    cpu._debug_tls_errno_container[5] = nerrno

def get_debug_saved_altlasterror(cpu):
    return cpu._debug_tls_errno_container[6]

def set_debug_saved_altlasterror(cpu, nerrno):
    assert nerrno >= 0
    cpu._debug_tls_errno_container[6] = nerrno

def get_rpy_lasterror_offset(cpu):
    if cpu.translate_support_code:
        from rpython.rlib import rthread
        return rthread.tlfield_rpy_lasterror.getoffset()
    else:
        return 5 * WORD

def get_alt_lasterror_offset(cpu):
    if cpu.translate_support_code:
        from rpython.rlib import rthread
        return rthread.tlfield_alt_lasterror.getoffset()
    else:
        return 6 * WORD


def _fetch_addr_errno():
    eci = ExternalCompilationInfo(
        separate_module_sources=['''
            #include <errno.h>
            RPY_EXPORTED long fetch_addr_errno(void) {
                return (long)(&errno);
            }
        '''])
    func1_ptr = rffi.llexternal('fetch_addr_errno', [], lltype.Signed,
                                compilation_info=eci, _nowrapper=True)
    return func1_ptr()

def get_p_errno_offset(cpu):
    if cpu.translate_support_code:
        from rpython.rlib import rthread
        return rthread.tlfield_p_errno.getoffset()
    else:
        # fetch the real address of errno (in this thread), and store it
        # at offset 2 in the _debug_tls_errno_container
        if cpu._debug_tls_errno_container[2] == 0:
            addr_errno = _fetch_addr_errno()
            assert addr_errno != 0
            cpu._debug_tls_errno_container[2] = addr_errno
        return 2 * WORD
