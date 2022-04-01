"""
Support for valgrind: tell it when we patch code in-place.
"""

from rpython.rtyper.tool import rffi_platform
from rpython.rtyper.lltypesystem import lltype, llmemory, rffi
from rpython.translator.tool.cbuild import ExternalCompilationInfo
from rpython.rlib.objectmodel import we_are_translated
from rpython.jit.backend.x86.arch import WORD


eci = ExternalCompilationInfo(includes = ['valgrind/valgrind.h'])

try:
    rffi_platform.verify_eci(eci)
except rffi_platform.CompilationError:
    # Can't open 'valgrind/valgrind.h'.  It is a bad idea to just go
    # ahead and not compile the valgrind-specific hacks.  Instead,
    # we'll include manually the few needed macros from a hopefully
    # standard valgrind.h file.
    eci = ExternalCompilationInfo(post_include_bits = [r"""
/************ Valgrind support: only with GCC/clang for now ***********/
/**  This code is inserted only if valgrind/valgrind.h is not found  **/
/**********************************************************************/
#ifdef __GNUC__

#if ${WORD} == 4     /* if 32-bit x86 */

#define VG__SPECIAL_INSTRUCTION_PREAMBLE                          \
                     "roll $3,  %%edi ; roll $13, %%edi\n\t"      \
                     "roll $29, %%edi ; roll $19, %%edi\n\t"
#define VALGRIND_DO_CLIENT_REQUEST_EXPR(                          \
        _zzq_default, _zzq_request,                               \
        _zzq_arg1, _zzq_arg2, _zzq_arg3, _zzq_arg4, _zzq_arg5)    \
  __extension__                                                   \
  ({volatile unsigned int _zzq_args[6];                           \
    volatile unsigned int _zzq_result;                            \
    _zzq_args[0] = (unsigned int)(_zzq_request);                  \
    _zzq_args[1] = (unsigned int)(_zzq_arg1);                     \
    _zzq_args[2] = (unsigned int)(_zzq_arg2);                     \
    _zzq_args[3] = (unsigned int)(_zzq_arg3);                     \
    _zzq_args[4] = (unsigned int)(_zzq_arg4);                     \
    _zzq_args[5] = (unsigned int)(_zzq_arg5);                     \
    __asm__ volatile(VG__SPECIAL_INSTRUCTION_PREAMBLE             \
                     /* %EDX = client_request ( %EAX ) */         \
                     "xchgl %%ebx,%%ebx"                          \
                     : "=d" (_zzq_result)                         \
                     : "a" (&_zzq_args[0]), "0" (_zzq_default)    \
                     : "cc", "memory"                             \
                    );                                            \
    _zzq_result;                                                  \
  })

#else          /* 64-bit x86-64 */

#define VG__SPECIAL_INSTRUCTION_PREAMBLE                          \
                     "rolq $3,  %%rdi ; rolq $13, %%rdi\n\t"      \
                     "rolq $61, %%rdi ; rolq $51, %%rdi\n\t"
#define VALGRIND_DO_CLIENT_REQUEST_EXPR(                          \
        _zzq_default, _zzq_request,                               \
        _zzq_arg1, _zzq_arg2, _zzq_arg3, _zzq_arg4, _zzq_arg5)    \
    __extension__                                                 \
    ({ volatile unsigned long long int _zzq_args[6];              \
    volatile unsigned long long int _zzq_result;                  \
    _zzq_args[0] = (unsigned long long int)(_zzq_request);        \
    _zzq_args[1] = (unsigned long long int)(_zzq_arg1);           \
    _zzq_args[2] = (unsigned long long int)(_zzq_arg2);           \
    _zzq_args[3] = (unsigned long long int)(_zzq_arg3);           \
    _zzq_args[4] = (unsigned long long int)(_zzq_arg4);           \
    _zzq_args[5] = (unsigned long long int)(_zzq_arg5);           \
    __asm__ volatile(VG__SPECIAL_INSTRUCTION_PREAMBLE             \
                     /* %RDX = client_request ( %RAX ) */         \
                     "xchgq %%rbx,%%rbx"                          \
                     : "=d" (_zzq_result)                         \
                     : "a" (&_zzq_args[0]), "0" (_zzq_default)    \
                     : "cc", "memory"                             \
                    );                                            \
    _zzq_result;                                                  \
    })
#endif

#define VALGRIND_DO_CLIENT_REQUEST_STMT(_zzq_request, _zzq_arg1,        \
                           _zzq_arg2,  _zzq_arg3, _zzq_arg4, _zzq_arg5) \
  do { (void) VALGRIND_DO_CLIENT_REQUEST_EXPR(0,                        \
                    (_zzq_request), (_zzq_arg1), (_zzq_arg2),           \
                    (_zzq_arg3), (_zzq_arg4), (_zzq_arg5)); } while (0)

#define VG_USERREQ__DISCARD_TRANSLATIONS   0x1002
#define VALGRIND_DISCARD_TRANSLATIONS(_qzz_addr,_qzz_len)              \
    VALGRIND_DO_CLIENT_REQUEST_STMT(VG_USERREQ__DISCARD_TRANSLATIONS,  \
                                    _qzz_addr, _qzz_len, 0, 0, 0)

/**********************************************************************/
#else    /* if !__GNUC__ */
#define VALGRIND_DISCARD_TRANSLATIONS(_qzz_addr,_qzz_len)  do { } while(0)
#endif
/**********************************************************************/
""".replace("${WORD}", str(WORD))])


VALGRIND_DISCARD_TRANSLATIONS = rffi.llexternal(
        "VALGRIND_DISCARD_TRANSLATIONS",
        [llmemory.Address, lltype.Signed],
        lltype.Void,
        compilation_info=eci,
        _nowrapper=True,
        sandboxsafe=True)

# ____________________________________________________________

def discard_translations(data, size):
    if we_are_translated():
        VALGRIND_DISCARD_TRANSLATIONS(llmemory.cast_int_to_adr(data), size)
