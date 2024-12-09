#ifndef NO_ERROR
#error "missing define
#endif

.text

#if  defined(__APPLE__)
.global _add_asm_prep
_add_asm_prep:
#else
.global add_asm_prep
add_asm_prep:
#endif

#if defined(__linux__) || defined(__unix__) || defined(__APPLE__)
    #if defined(__x86_64__)
        mov     %edi, %eax
        add     %esi, %eax
        ret

    #elif defined(__i386__)
        mov     4(%esp), %eax
        add     8(%esp), %eax
        ret

    #elif defined(__aarch64__)
        add     w0, w0, w1
        ret

    #elif defined(__arm__)
        add     r0, r0, r1
        bx      lr

    #elif defined(__riscv) && __riscv_xlen == 64
        add     a0, a0, a1
        ret

    #else
        #error "Architecture not supported"
    #endif

#elif defined(_WIN32) || defined(_WIN64)
    #if defined(_M_X64) || defined(__x86_64__)
        mov     %ecx, %eax
        add     %edx, %eax
        ret

    #elif defined(_M_IX86) || defined(__i386__)
        mov     4(%esp), %eax
        add     8(%esp), %eax
        ret

    #elif defined(_M_ARM64) || defined(__aarch64__)
        add     w0, w0, w1
        ret

    #elif defined(_M_ARM) || defined(__arm__)
        add     r0, r0, r1
        bx      lr

    #else
        #error "Architecture not supported"
    #endif

#else
    #error "Platform not supported"
#endif
