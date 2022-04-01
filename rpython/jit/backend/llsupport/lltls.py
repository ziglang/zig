from rpython.rlib import rthread
from rpython.jit.backend.llsupport.symbolic import WORD


def get_thread_ident_offset(cpu):
    if cpu.translate_support_code:
        return rthread.tlfield_thread_ident.getoffset()
    else:
        return 1 * WORD
