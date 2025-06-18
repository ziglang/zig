/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#include "internal.h"

#if defined(__i386__) || defined(__x86_64__)

static unsigned int get_mxcsr(void)
{
    unsigned int ret;
#ifdef __arm64ec__
    extern NTSTATUS (*__os_arm64x_get_x64_information)(ULONG,void*,void*);
    __os_arm64x_get_x64_information( 0, &ret, NULL );
#else
    __asm__ __volatile__( "stmxcsr %0" : "=m" (ret) );
#endif
    return ret;
}

static void set_mxcsr( unsigned int val )
{
#ifdef __arm64ec__
    extern NTSTATUS (*__os_arm64x_set_x64_information)(ULONG,ULONG_PTR,void*);
    __os_arm64x_set_x64_information( 0, val, NULL );
#else
    __asm__ __volatile__( "ldmxcsr %0" : : "m" (val) );
#endif
}

void __mingw_setfp_sse( unsigned int *cw, unsigned int cw_mask, unsigned int *sw, unsigned int sw_mask )
{
    unsigned int old_fpword, fpword = get_mxcsr();
    unsigned int flags;

    old_fpword = fpword;

    cw_mask &= _MCW_EM | _MCW_RC | _MCW_DN;
    sw_mask &= _MCW_EM;

    if (sw)
    {
        flags = 0;
        if (fpword & 0x1) flags |= _SW_INVALID;
        if (fpword & 0x2) flags |= _SW_DENORMAL;
        if (fpword & 0x4) flags |= _SW_ZERODIVIDE;
        if (fpword & 0x8) flags |= _SW_OVERFLOW;
        if (fpword & 0x10) flags |= _SW_UNDERFLOW;
        if (fpword & 0x20) flags |= _SW_INEXACT;

        *sw = (flags & ~sw_mask) | (*sw & sw_mask);
        fpword &= ~0x3f;
        if (*sw & _SW_INVALID) fpword |= 0x1;
        if (*sw & _SW_DENORMAL) fpword |= 0x2;
        if (*sw & _SW_ZERODIVIDE) fpword |= 0x4;
        if (*sw & _SW_OVERFLOW) fpword |= 0x8;
        if (*sw & _SW_UNDERFLOW) fpword |= 0x10;
        if (*sw & _SW_INEXACT) fpword |= 0x20;
        *sw = flags;
    }

    if (cw)
    {
        flags = 0;
        if (fpword & 0x80) flags |= _EM_INVALID;
        if (fpword & 0x100) flags |= _EM_DENORMAL;
        if (fpword & 0x200) flags |= _EM_ZERODIVIDE;
        if (fpword & 0x400) flags |= _EM_OVERFLOW;
        if (fpword & 0x800) flags |= _EM_UNDERFLOW;
        if (fpword & 0x1000) flags |= _EM_INEXACT;
        switch (fpword & 0x6000)
        {
        case 0x6000: flags |= _RC_UP|_RC_DOWN; break;
        case 0x4000: flags |= _RC_UP; break;
        case 0x2000: flags |= _RC_DOWN; break;
        }
        switch (fpword & 0x8040)
        {
        case 0x0040: flags |= _DN_FLUSH_OPERANDS_SAVE_RESULTS; break;
        case 0x8000: flags |= _DN_SAVE_OPERANDS_FLUSH_RESULTS; break;
        case 0x8040: flags |= _DN_FLUSH; break;
        }

        *cw = (flags & ~cw_mask) | (*cw & cw_mask);
        fpword &= ~0xffc0;
        if (*cw & _EM_INVALID) fpword |= 0x80;
        if (*cw & _EM_DENORMAL) fpword |= 0x100;
        if (*cw & _EM_ZERODIVIDE) fpword |= 0x200;
        if (*cw & _EM_OVERFLOW) fpword |= 0x400;
        if (*cw & _EM_UNDERFLOW) fpword |= 0x800;
        if (*cw & _EM_INEXACT) fpword |= 0x1000;
        switch (*cw & _MCW_RC)
        {
        case _RC_UP|_RC_DOWN: fpword |= 0x6000; break;
        case _RC_UP: fpword |= 0x4000; break;
        case _RC_DOWN: fpword |= 0x2000; break;
        }
        switch (*cw & _MCW_DN)
        {
        case _DN_FLUSH_OPERANDS_SAVE_RESULTS: fpword |= 0x0040; break;
        case _DN_SAVE_OPERANDS_FLUSH_RESULTS: fpword |= 0x8000; break;
        case _DN_FLUSH: fpword |= 0x8040; break;
        }

        /* clear status word if anything changes */
        if (fpword != old_fpword && !sw) fpword &= ~0x3f;
    }

    if (fpword != old_fpword) set_mxcsr( fpword );
}
#endif

void __mingw_setfp( unsigned int *cw, unsigned int cw_mask,
                    unsigned int *sw, unsigned int sw_mask )
{
#if defined(__arm64ec__)
    __mingw_setfp_sse(cw, cw_mask, sw, sw_mask);
#elif defined(__i386__) || defined(__x86_64__)
    unsigned long oldcw = 0, newcw = 0;
    unsigned long oldsw = 0, newsw = 0;
    unsigned int flags;

    cw_mask &= _MCW_EM | _MCW_IC | _MCW_RC | _MCW_PC;
    sw_mask &= _MCW_EM;

    if (sw)
    {
        __asm__ __volatile__( "fstsw %0" : "=m" (newsw) );
        oldsw = newsw;

        flags = 0;
        if (newsw & 0x1) flags |= _SW_INVALID;
        if (newsw & 0x2) flags |= _SW_DENORMAL;
        if (newsw & 0x4) flags |= _SW_ZERODIVIDE;
        if (newsw & 0x8) flags |= _SW_OVERFLOW;
        if (newsw & 0x10) flags |= _SW_UNDERFLOW;
        if (newsw & 0x20) flags |= _SW_INEXACT;

        *sw = (flags & ~sw_mask) | (*sw & sw_mask);
        newsw &= ~0x3f;
        if (*sw & _SW_INVALID) newsw |= 0x1;
        if (*sw & _SW_DENORMAL) newsw |= 0x2;
        if (*sw & _SW_ZERODIVIDE) newsw |= 0x4;
        if (*sw & _SW_OVERFLOW) newsw |= 0x8;
        if (*sw & _SW_UNDERFLOW) newsw |= 0x10;
        if (*sw & _SW_INEXACT) newsw |= 0x20;
        *sw = flags;
    }

    if (cw)
    {
        __asm__ __volatile__( "fstcw %0" : "=m" (newcw) );
        oldcw = newcw;

        flags = 0;
        if (newcw & 0x1) flags |= _EM_INVALID;
        if (newcw & 0x2) flags |= _EM_DENORMAL;
        if (newcw & 0x4) flags |= _EM_ZERODIVIDE;
        if (newcw & 0x8) flags |= _EM_OVERFLOW;
        if (newcw & 0x10) flags |= _EM_UNDERFLOW;
        if (newcw & 0x20) flags |= _EM_INEXACT;
        switch (newcw & 0xc00)
        {
        case 0xc00: flags |= _RC_UP|_RC_DOWN; break;
        case 0x800: flags |= _RC_UP; break;
        case 0x400: flags |= _RC_DOWN; break;
        }
        switch (newcw & 0x300)
        {
        case 0x0: flags |= _PC_24; break;
        case 0x200: flags |= _PC_53; break;
        case 0x300: flags |= _PC_64; break;
        }
        if (newcw & 0x1000) flags |= _IC_AFFINE;

        *cw = (flags & ~cw_mask) | (*cw & cw_mask);
        newcw &= ~0x1f3f;
        if (*cw & _EM_INVALID) newcw |= 0x1;
        if (*cw & _EM_DENORMAL) newcw |= 0x2;
        if (*cw & _EM_ZERODIVIDE) newcw |= 0x4;
        if (*cw & _EM_OVERFLOW) newcw |= 0x8;
        if (*cw & _EM_UNDERFLOW) newcw |= 0x10;
        if (*cw & _EM_INEXACT) newcw |= 0x20;
        switch (*cw & _MCW_RC)
        {
        case _RC_UP|_RC_DOWN: newcw |= 0xc00; break;
        case _RC_UP: newcw |= 0x800; break;
        case _RC_DOWN: newcw |= 0x400; break;
        }
        switch (*cw & _MCW_PC)
        {
        case _PC_64: newcw |= 0x300; break;
        case _PC_53: newcw |= 0x200; break;
        case _PC_24: newcw |= 0x0; break;
        }
        if (*cw & _IC_AFFINE) newcw |= 0x1000;
    }

    if (oldsw != newsw && (newsw & 0x3f))
    {
        struct {
            WORD control_word;
            WORD unused1;
            WORD status_word;
            WORD unused2;
            WORD tag_word;
            WORD unused3;
            DWORD instruction_pointer;
            WORD code_segment;
            WORD unused4;
            DWORD operand_addr;
            WORD data_segment;
            WORD unused5;
        } fenv;

        __asm__ __volatile__( "fnstenv %0" : "=m" (fenv) );
        fenv.control_word = newcw;
        fenv.status_word = newsw;
        __asm__ __volatile__( "fldenv %0" : : "m" (fenv) : "st", "st(1)",
                "st(2)", "st(3)", "st(4)", "st(5)", "st(6)", "st(7)" );
        return;
    }

    if (oldsw != newsw)
        __asm__ __volatile__( "fnclex" );
    if (oldcw != newcw)
        __asm__ __volatile__( "fldcw %0" : : "m" (newcw) );
#elif defined(__aarch64__)
    ULONG_PTR old_fpsr = 0, fpsr = 0, old_fpcr = 0, fpcr = 0;
    unsigned int flags;

    cw_mask &= _MCW_EM | _MCW_RC;
    sw_mask &= _MCW_EM;

    if (sw)
    {
        __asm__ __volatile__( "mrs %0, fpsr" : "=r" (fpsr) );
        old_fpsr = fpsr;

        flags = 0;
        if (fpsr & 0x1) flags |= _SW_INVALID;
        if (fpsr & 0x2) flags |= _SW_ZERODIVIDE;
        if (fpsr & 0x4) flags |= _SW_OVERFLOW;
        if (fpsr & 0x8) flags |= _SW_UNDERFLOW;
        if (fpsr & 0x10) flags |= _SW_INEXACT;
        if (fpsr & 0x80) flags |= _SW_DENORMAL;

        *sw = (flags & ~sw_mask) | (*sw & sw_mask);
        fpsr &= ~0x9f;
        if (*sw & _SW_INVALID) fpsr |= 0x1;
        if (*sw & _SW_ZERODIVIDE) fpsr |= 0x2;
        if (*sw & _SW_OVERFLOW) fpsr |= 0x4;
        if (*sw & _SW_UNDERFLOW) fpsr |= 0x8;
        if (*sw & _SW_INEXACT) fpsr |= 0x10;
        if (*sw & _SW_DENORMAL) fpsr |= 0x80;
        *sw = flags;
    }

    if (cw)
    {
        __asm__ __volatile__( "mrs %0, fpcr" : "=r" (fpcr) );
        old_fpcr = fpcr;

        flags = 0;
        if (!(fpcr & 0x100)) flags |= _EM_INVALID;
        if (!(fpcr & 0x200)) flags |= _EM_ZERODIVIDE;
        if (!(fpcr & 0x400)) flags |= _EM_OVERFLOW;
        if (!(fpcr & 0x800)) flags |= _EM_UNDERFLOW;
        if (!(fpcr & 0x1000)) flags |= _EM_INEXACT;
        if (!(fpcr & 0x8000)) flags |= _EM_DENORMAL;
        switch (fpcr & 0xc00000)
        {
        case 0x400000: flags |= _RC_UP; break;
        case 0x800000: flags |= _RC_DOWN; break;
        case 0xc00000: flags |= _RC_CHOP; break;
        }

        *cw = (flags & ~cw_mask) | (*cw & cw_mask);
        fpcr &= ~0xc09f00ul;
        if (!(*cw & _EM_INVALID)) fpcr |= 0x100;
        if (!(*cw & _EM_ZERODIVIDE)) fpcr |= 0x200;
        if (!(*cw & _EM_OVERFLOW)) fpcr |= 0x400;
        if (!(*cw & _EM_UNDERFLOW)) fpcr |= 0x800;
        if (!(*cw & _EM_INEXACT)) fpcr |= 0x1000;
        if (!(*cw & _EM_DENORMAL)) fpcr |= 0x8000;
        switch (*cw & _MCW_RC)
        {
        case _RC_CHOP: fpcr |= 0xc00000; break;
        case _RC_UP: fpcr |= 0x400000; break;
        case _RC_DOWN: fpcr |= 0x800000; break;
        }
    }

    /* mask exceptions if needed */
    if (old_fpcr != fpcr && ~(old_fpcr >> 8) & fpsr & 0x9f != fpsr & 0x9f)
    {
        ULONG_PTR mask = fpcr & ~0x9f00;
        __asm__ __volatile__( "msr fpcr, %0" :: "r" (mask) );
    }

    if (old_fpsr != fpsr)
        __asm__ __volatile__( "msr fpsr, %0" :: "r" (fpsr) );
    if (old_fpcr != fpcr)
        __asm__ __volatile__( "msr fpcr, %0" :: "r" (fpcr) );
#elif defined(__arm__)
    DWORD old_fpscr, fpscr;
    unsigned int flags;

    __asm__ __volatile__( "vmrs %0, fpscr" : "=r" (fpscr) );
    old_fpscr = fpscr;

    cw_mask &= _MCW_EM | _MCW_RC;
    sw_mask &= _MCW_EM;

    if (sw)
    {
        flags = 0;
        if (fpscr & 0x1) flags |= _SW_INVALID;
        if (fpscr & 0x2) flags |= _SW_ZERODIVIDE;
        if (fpscr & 0x4) flags |= _SW_OVERFLOW;
        if (fpscr & 0x8) flags |= _SW_UNDERFLOW;
        if (fpscr & 0x10) flags |= _SW_INEXACT;
        if (fpscr & 0x80) flags |= _SW_DENORMAL;

        *sw = (flags & ~sw_mask) | (*sw & sw_mask);
        fpscr &= ~0x9f;
        if (*sw & _SW_INVALID) fpscr |= 0x1;
        if (*sw & _SW_ZERODIVIDE) fpscr |= 0x2;
        if (*sw & _SW_OVERFLOW) fpscr |= 0x4;
        if (*sw & _SW_UNDERFLOW) fpscr |= 0x8;
        if (*sw & _SW_INEXACT) fpscr |= 0x10;
        if (*sw & _SW_DENORMAL) fpscr |= 0x80;
        *sw = flags;
    }

    if (cw)
    {
        flags = 0;
        if (!(fpscr & 0x100)) flags |= _EM_INVALID;
        if (!(fpscr & 0x200)) flags |= _EM_ZERODIVIDE;
        if (!(fpscr & 0x400)) flags |= _EM_OVERFLOW;
        if (!(fpscr & 0x800)) flags |= _EM_UNDERFLOW;
        if (!(fpscr & 0x1000)) flags |= _EM_INEXACT;
        if (!(fpscr & 0x8000)) flags |= _EM_DENORMAL;
        switch (fpscr & 0xc00000)
        {
        case 0x400000: flags |= _RC_UP; break;
        case 0x800000: flags |= _RC_DOWN; break;
        case 0xc00000: flags |= _RC_CHOP; break;
        }

        *cw = (flags & ~cw_mask) | (*cw & cw_mask);
        fpscr &= ~0xc09f00ul;
        if (!(*cw & _EM_INVALID)) fpscr |= 0x100;
        if (!(*cw & _EM_ZERODIVIDE)) fpscr |= 0x200;
        if (!(*cw & _EM_OVERFLOW)) fpscr |= 0x400;
        if (!(*cw & _EM_UNDERFLOW)) fpscr |= 0x800;
        if (!(*cw & _EM_INEXACT)) fpscr |= 0x1000;
        if (!(*cw & _EM_DENORMAL)) fpscr |= 0x8000;
        switch (*cw & _MCW_RC)
        {
        case _RC_CHOP: fpscr |= 0xc00000; break;
        case _RC_UP: fpscr |= 0x400000; break;
        case _RC_DOWN: fpscr |= 0x800000; break;
        }
    }

    if (old_fpscr != fpscr)
        __asm__ __volatile__( "vmsr fpscr, %0" :: "r" (fpscr) );
#endif
}
