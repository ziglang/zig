import sys
import struct
from rpython.rtyper.lltypesystem import lltype, rffi
from rpython.rlib.rmmap import alloc, free

CPU_ID_FUNC_PTR = lltype.Ptr(lltype.FuncType([], lltype.Signed))

def cpu_info(instr):
    data = alloc(4096)
    pos = 0
    for c in instr:
        data[pos] = c
        pos += 1
    fnptr = rffi.cast(CPU_ID_FUNC_PTR, data)
    code = fnptr()
    free(data, 4096)
    return code

def detect_sse2():
    code = cpu_id(eax=1)
    return bool(code & (1<<25)) and bool(code & (1<<26))

def cpu_id(eax = 1, ret_edx = True, ret_ecx = False):
    asm = ["\xB8",                     # MOV EAX, $eax
                chr(eax & 0xff),
                chr((eax >> 8) & 0xff),
                chr((eax >> 16) & 0xff),
                chr((eax >> 24) & 0xff),
           "\x53",                     # PUSH EBX
           "\x0F\xA2",                 # CPUID
           "\x5B",                     # POP EBX
          ]
    if ret_edx:
        asm.append("\x92")             # XCHG EAX, EDX
    elif ret_ecx:
        asm.append("\x91")             # XCHG EAX, ECX
    asm.append("\xC3")                 # RET
    return cpu_info(''.join(asm))

def detect_sse4_1(code=-1):
    if code == -1:
        code = cpu_id(eax=1, ret_edx=False, ret_ecx=True)
    return bool(code & (1<<19))

def detect_sse4_2(code=-1):
    if code == -1:
        code = cpu_id(eax=1, ret_edx=False, ret_ecx=True)
    return bool(code & (1<<20))

def detect_sse4a(code=-1):
    if code == -1:
        code = cpu_id(eax=0x80000001, ret_edx=False, ret_ecx=True)
    return bool(code & (1<<20))

def detect_x32_mode():
    # 32-bit         64-bit / x32
    code = cpu_info("\x48"                # DEC EAX
                    "\xB8\xC8\x00\x00\x00"# MOV EAX, 200   MOV RAX, 0x40404040000000C8
                    "\x40\x40\x40\x40"    # 4x INC EAX
                    "\xC3")               # RET            RET
    assert code in (200, 204, 0x40404040000000C8)
    return code == 200


if __name__ == '__main__':
    if detect_sse2():
        print 'Processor supports sse2'
    if detect_sse4_1():
        print 'Processor supports sse4.1'
    if detect_sse4_2():
        print 'Processor supports sse4.2'
    if detect_sse4a():
        print 'Processor supports sse4a'

    if detect_x32_mode():
        print 'Process is running in "x32" mode.'
