import sys
from rpython.rtyper.lltypesystem import rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.jit.backend.x86.arch import WORD

if WORD == 4:
    extra = ['-DPYPY_X86_CHECK_SSE2']
    if sys.platform != 'win32':
        extra += ['-msse2', '-mfpmath=sse']
    else:
        extra += ['/arch:SSE2']
else:
    extra = []    # the -m options above are always on by default on x86-64

extra = ['-DPYPY_CPU_HAS_STANDARD_PRECISION'] + extra

ensure_sse2_floats = rffi.llexternal_use_eci(ExternalCompilationInfo(
    compile_extra = extra,
))
