/*
 * Copyright (c) 2015 Andrew Kelley
 *
 * This file is part of zig, which is MIT licensed.
 * See http://opensource.org/licenses/MIT
 */

#include "os.hpp"
#include "config.h"
#include "codegen.hpp"
#include "analyze.hpp"
#include "compiler.hpp"
#include "install_files.h"
#include "glibc.hpp"

static const char *msvcrt_common_src[] = {
    "misc" OS_SEP "_create_locale.c",
    "misc" OS_SEP "_free_locale.c",
    "misc" OS_SEP "onexit_table.c",
    "misc" OS_SEP "register_tls_atexit.c",
    "stdio" OS_SEP "acrt_iob_func.c",
    "misc" OS_SEP "_configthreadlocale.c",
    "misc" OS_SEP "_get_current_locale.c",
    "misc" OS_SEP "invalid_parameter_handler.c",
    "misc" OS_SEP "output_format.c",
    "misc" OS_SEP "purecall.c",
    "secapi" OS_SEP "_access_s.c",
    "secapi" OS_SEP "_cgets_s.c",
    "secapi" OS_SEP "_cgetws_s.c",
    "secapi" OS_SEP "_chsize_s.c",
    "secapi" OS_SEP "_controlfp_s.c",
    "secapi" OS_SEP "_cprintf_s.c",
    "secapi" OS_SEP "_cprintf_s_l.c",
    "secapi" OS_SEP "_ctime32_s.c",
    "secapi" OS_SEP "_ctime64_s.c",
    "secapi" OS_SEP "_cwprintf_s.c",
    "secapi" OS_SEP "_cwprintf_s_l.c",
    "secapi" OS_SEP "_gmtime32_s.c",
    "secapi" OS_SEP "_gmtime64_s.c",
    "secapi" OS_SEP "_localtime32_s.c",
    "secapi" OS_SEP "_localtime64_s.c",
    "secapi" OS_SEP "_mktemp_s.c",
    "secapi" OS_SEP "_sopen_s.c",
    "secapi" OS_SEP "_strdate_s.c",
    "secapi" OS_SEP "_strtime_s.c",
    "secapi" OS_SEP "_umask_s.c",
    "secapi" OS_SEP "_vcprintf_s.c",
    "secapi" OS_SEP "_vcprintf_s_l.c",
    "secapi" OS_SEP "_vcwprintf_s.c",
    "secapi" OS_SEP "_vcwprintf_s_l.c",
    "secapi" OS_SEP "_vscprintf_p.c",
    "secapi" OS_SEP "_vscwprintf_p.c",
    "secapi" OS_SEP "_vswprintf_p.c",
    "secapi" OS_SEP "_waccess_s.c",
    "secapi" OS_SEP "_wasctime_s.c",
    "secapi" OS_SEP "_wctime32_s.c",
    "secapi" OS_SEP "_wctime64_s.c",
    "secapi" OS_SEP "_wstrtime_s.c",
    "secapi" OS_SEP "_wmktemp_s.c",
    "secapi" OS_SEP "_wstrdate_s.c",
    "secapi" OS_SEP "asctime_s.c",
    "secapi" OS_SEP "memcpy_s.c",
    "secapi" OS_SEP "memmove_s.c",
    "secapi" OS_SEP "rand_s.c",
    "secapi" OS_SEP "sprintf_s.c",
    "secapi" OS_SEP "strerror_s.c",
    "secapi" OS_SEP "vsprintf_s.c",
    "secapi" OS_SEP "wmemcpy_s.c",
    "secapi" OS_SEP "wmemmove_s.c",
    "stdio" OS_SEP "mingw_lock.c",
};

static const char *msvcrt_i386_src[] = {
    "misc" OS_SEP "lc_locale_func.c",
    "misc" OS_SEP "___mb_cur_max_func.c",
};

static const char *msvcrt_other_src[] = {
    "misc" OS_SEP "__p___argv.c",
    "misc" OS_SEP "__p__acmdln.c",
    "misc" OS_SEP "__p__fmode.c",
    "misc" OS_SEP "__p__wcmdln.c",
};

static const char *mingwex_generic_src[] = {
    "complex" OS_SEP "_cabs.c",
    "complex" OS_SEP "cabs.c",
    "complex" OS_SEP "cabsf.c",
    "complex" OS_SEP "cabsl.c",
    "complex" OS_SEP "cacos.c",
    "complex" OS_SEP "cacosf.c",
    "complex" OS_SEP "cacosl.c",
    "complex" OS_SEP "carg.c",
    "complex" OS_SEP "cargf.c",
    "complex" OS_SEP "cargl.c",
    "complex" OS_SEP "casin.c",
    "complex" OS_SEP "casinf.c",
    "complex" OS_SEP "casinl.c",
    "complex" OS_SEP "catan.c",
    "complex" OS_SEP "catanf.c",
    "complex" OS_SEP "catanl.c",
    "complex" OS_SEP "ccos.c",
    "complex" OS_SEP "ccosf.c",
    "complex" OS_SEP "ccosl.c",
    "complex" OS_SEP "cexp.c",
    "complex" OS_SEP "cexpf.c",
    "complex" OS_SEP "cexpl.c",
    "complex" OS_SEP "cimag.c",
    "complex" OS_SEP "cimagf.c",
    "complex" OS_SEP "cimagl.c",
    "complex" OS_SEP "clog.c",
    "complex" OS_SEP "clog10.c",
    "complex" OS_SEP "clog10f.c",
    "complex" OS_SEP "clog10l.c",
    "complex" OS_SEP "clogf.c",
    "complex" OS_SEP "clogl.c",
    "complex" OS_SEP "conj.c",
    "complex" OS_SEP "conjf.c",
    "complex" OS_SEP "conjl.c",
    "complex" OS_SEP "cpow.c",
    "complex" OS_SEP "cpowf.c",
    "complex" OS_SEP "cpowl.c",
    "complex" OS_SEP "cproj.c",
    "complex" OS_SEP "cprojf.c",
    "complex" OS_SEP "cprojl.c",
    "complex" OS_SEP "creal.c",
    "complex" OS_SEP "crealf.c",
    "complex" OS_SEP "creall.c",
    "complex" OS_SEP "csin.c",
    "complex" OS_SEP "csinf.c",
    "complex" OS_SEP "csinl.c",
    "complex" OS_SEP "csqrt.c",
    "complex" OS_SEP "csqrtf.c",
    "complex" OS_SEP "csqrtl.c",
    "complex" OS_SEP "ctan.c",
    "complex" OS_SEP "ctanf.c",
    "complex" OS_SEP "ctanl.c",
    "crt" OS_SEP "dllentry.c",
    "crt" OS_SEP "dllmain.c",
    "gdtoa" OS_SEP "arithchk.c",
    "gdtoa" OS_SEP "dmisc.c",
    "gdtoa" OS_SEP "dtoa.c",
    "gdtoa" OS_SEP "g__fmt.c",
    "gdtoa" OS_SEP "g_dfmt.c",
    "gdtoa" OS_SEP "g_ffmt.c",
    "gdtoa" OS_SEP "g_xfmt.c",
    "gdtoa" OS_SEP "gdtoa.c",
    "gdtoa" OS_SEP "gethex.c",
    "gdtoa" OS_SEP "gmisc.c",
    "gdtoa" OS_SEP "hd_init.c",
    "gdtoa" OS_SEP "hexnan.c",
    "gdtoa" OS_SEP "misc.c",
    "gdtoa" OS_SEP "qnan.c",
    "gdtoa" OS_SEP "smisc.c",
    "gdtoa" OS_SEP "strtodg.c",
    "gdtoa" OS_SEP "strtodnrp.c",
    "gdtoa" OS_SEP "strtof.c",
    "gdtoa" OS_SEP "strtopx.c",
    "gdtoa" OS_SEP "sum.c",
    "gdtoa" OS_SEP "ulp.c",
    "math" OS_SEP "abs64.c",
    "math" OS_SEP "cbrt.c",
    "math" OS_SEP "cbrtf.c",
    "math" OS_SEP "cbrtl.c",
    "math" OS_SEP "cephes_emath.c",
    "math" OS_SEP "copysign.c",
    "math" OS_SEP "copysignf.c",
    "math" OS_SEP "coshf.c",
    "math" OS_SEP "coshl.c",
    "math" OS_SEP "erfl.c",
    "math" OS_SEP "expf.c",
    "math" OS_SEP "fabs.c",
    "math" OS_SEP "fabsf.c",
    "math" OS_SEP "fabsl.c",
    "math" OS_SEP "fdim.c",
    "math" OS_SEP "fdimf.c",
    "math" OS_SEP "fdiml.c",
    "math" OS_SEP "fma.c",
    "math" OS_SEP "fmaf.c",
    "math" OS_SEP "fmal.c",
    "math" OS_SEP "fmax.c",
    "math" OS_SEP "fmaxf.c",
    "math" OS_SEP "fmaxl.c",
    "math" OS_SEP "fmin.c",
    "math" OS_SEP "fminf.c",
    "math" OS_SEP "fminl.c",
    "math" OS_SEP "fp_consts.c",
    "math" OS_SEP "fp_constsf.c",
    "math" OS_SEP "fp_constsl.c",
    "math" OS_SEP "fpclassify.c",
    "math" OS_SEP "fpclassifyf.c",
    "math" OS_SEP "fpclassifyl.c",
    "math" OS_SEP "frexpf.c",
    "math" OS_SEP "hypot.c",
    "math" OS_SEP "hypotf.c",
    "math" OS_SEP "hypotl.c",
    "math" OS_SEP "isnan.c",
    "math" OS_SEP "isnanf.c",
    "math" OS_SEP "isnanl.c",
    "math" OS_SEP "ldexpf.c",
    "math" OS_SEP "lgamma.c",
    "math" OS_SEP "lgammaf.c",
    "math" OS_SEP "lgammal.c",
    "math" OS_SEP "llrint.c",
    "math" OS_SEP "llrintf.c",
    "math" OS_SEP "llrintl.c",
    "math" OS_SEP "llround.c",
    "math" OS_SEP "llroundf.c",
    "math" OS_SEP "llroundl.c",
    "math" OS_SEP "log10f.c",
    "math" OS_SEP "logf.c",
    "math" OS_SEP "lrint.c",
    "math" OS_SEP "lrintf.c",
    "math" OS_SEP "lrintl.c",
    "math" OS_SEP "lround.c",
    "math" OS_SEP "lroundf.c",
    "math" OS_SEP "lroundl.c",
    "math" OS_SEP "modf.c",
    "math" OS_SEP "modff.c",
    "math" OS_SEP "modfl.c",
    "math" OS_SEP "nextafterf.c",
    "math" OS_SEP "nextafterl.c",
    "math" OS_SEP "nexttoward.c",
    "math" OS_SEP "nexttowardf.c",
    "math" OS_SEP "powf.c",
    "math" OS_SEP "powi.c",
    "math" OS_SEP "powif.c",
    "math" OS_SEP "powil.c",
    "math" OS_SEP "rint.c",
    "math" OS_SEP "rintf.c",
    "math" OS_SEP "rintl.c",
    "math" OS_SEP "round.c",
    "math" OS_SEP "roundf.c",
    "math" OS_SEP "roundl.c",
    "math" OS_SEP "s_erf.c",
    "math" OS_SEP "sf_erf.c",
    "math" OS_SEP "signbit.c",
    "math" OS_SEP "signbitf.c",
    "math" OS_SEP "signbitl.c",
    "math" OS_SEP "signgam.c",
    "math" OS_SEP "sinhf.c",
    "math" OS_SEP "sinhl.c",
    "math" OS_SEP "sqrt.c",
    "math" OS_SEP "sqrtf.c",
    "math" OS_SEP "sqrtl.c",
    "math" OS_SEP "tanhf.c",
    "math" OS_SEP "tanhl.c",
    "math" OS_SEP "tgamma.c",
    "math" OS_SEP "tgammaf.c",
    "math" OS_SEP "tgammal.c",
    "math" OS_SEP "truncl.c",
    "misc" OS_SEP "alarm.c",
    "misc" OS_SEP "basename.c",
    "misc" OS_SEP "btowc.c",
    "misc" OS_SEP "delay-f.c",
    "misc" OS_SEP "delay-n.c",
    "misc" OS_SEP "delayimp.c",
    "misc" OS_SEP "dirent.c",
    "misc" OS_SEP "dirname.c",
    "misc" OS_SEP "feclearexcept.c",
    "misc" OS_SEP "fegetenv.c",
    "misc" OS_SEP "fegetexceptflag.c",
    "misc" OS_SEP "fegetround.c",
    "misc" OS_SEP "feholdexcept.c",
    "misc" OS_SEP "feraiseexcept.c",
    "misc" OS_SEP "fesetenv.c",
    "misc" OS_SEP "fesetexceptflag.c",
    "misc" OS_SEP "fesetround.c",
    "misc" OS_SEP "fetestexcept.c",
    "misc" OS_SEP "feupdateenv.c",
    "misc" OS_SEP "ftruncate.c",
    "misc" OS_SEP "ftw.c",
    "misc" OS_SEP "ftw64.c",
    "misc" OS_SEP "fwide.c",
    "misc" OS_SEP "getlogin.c",
    "misc" OS_SEP "getopt.c",
    "misc" OS_SEP "gettimeofday.c",
    "misc" OS_SEP "imaxabs.c",
    "misc" OS_SEP "imaxdiv.c",
    "misc" OS_SEP "isblank.c",
    "misc" OS_SEP "iswblank.c",
    "misc" OS_SEP "mbrtowc.c",
    "misc" OS_SEP "mbsinit.c",
    "misc" OS_SEP "mempcpy.c",
    "misc" OS_SEP "mingw-aligned-malloc.c",
    "misc" OS_SEP "mingw-fseek.c",
    "misc" OS_SEP "mingw_getsp.S",
    "misc" OS_SEP "mingw_matherr.c",
    "misc" OS_SEP "mingw_mbwc_convert.c",
    "misc" OS_SEP "mingw_usleep.c",
    "misc" OS_SEP "mingw_wcstod.c",
    "misc" OS_SEP "mingw_wcstof.c",
    "misc" OS_SEP "mingw_wcstold.c",
    "misc" OS_SEP "mkstemp.c",
    "misc" OS_SEP "seterrno.c",
    "misc" OS_SEP "sleep.c",
    "misc" OS_SEP "strnlen.c",
    "misc" OS_SEP "strsafe.c",
    "misc" OS_SEP "strtoimax.c",
    "misc" OS_SEP "strtold.c",
    "misc" OS_SEP "strtoumax.c",
    "misc" OS_SEP "tdelete.c",
    "misc" OS_SEP "tfind.c",
    "misc" OS_SEP "tsearch.c",
    "misc" OS_SEP "twalk.c",
    "misc" OS_SEP "uchar_c16rtomb.c",
    "misc" OS_SEP "uchar_c32rtomb.c",
    "misc" OS_SEP "uchar_mbrtoc16.c",
    "misc" OS_SEP "uchar_mbrtoc32.c",
    "misc" OS_SEP "wassert.c",
    "misc" OS_SEP "wcrtomb.c",
    "misc" OS_SEP "wcsnlen.c",
    "misc" OS_SEP "wcstof.c",
    "misc" OS_SEP "wcstoimax.c",
    "misc" OS_SEP "wcstold.c",
    "misc" OS_SEP "wcstoumax.c",
    "misc" OS_SEP "wctob.c",
    "misc" OS_SEP "wctrans.c",
    "misc" OS_SEP "wctype.c",
    "misc" OS_SEP "wdirent.c",
    "misc" OS_SEP "winbs_uint64.c",
    "misc" OS_SEP "winbs_ulong.c",
    "misc" OS_SEP "winbs_ushort.c",
    "misc" OS_SEP "wmemchr.c",
    "misc" OS_SEP "wmemcmp.c",
    "misc" OS_SEP "wmemcpy.c",
    "misc" OS_SEP "wmemmove.c",
    "misc" OS_SEP "wmempcpy.c",
    "misc" OS_SEP "wmemset.c",
    "stdio" OS_SEP "_Exit.c",
    "stdio" OS_SEP "_findfirst64i32.c",
    "stdio" OS_SEP "_findnext64i32.c",
    "stdio" OS_SEP "_fstat.c",
    "stdio" OS_SEP "_fstat64i32.c",
    "stdio" OS_SEP "_ftime.c",
    "stdio" OS_SEP "_getc_nolock.c",
    "stdio" OS_SEP "_getwc_nolock.c",
    "stdio" OS_SEP "_putc_nolock.c",
    "stdio" OS_SEP "_putwc_nolock.c",
    "stdio" OS_SEP "_stat.c",
    "stdio" OS_SEP "_stat64i32.c",
    "stdio" OS_SEP "_wfindfirst64i32.c",
    "stdio" OS_SEP "_wfindnext64i32.c",
    "stdio" OS_SEP "_wstat.c",
    "stdio" OS_SEP "_wstat64i32.c",
    "stdio" OS_SEP "asprintf.c",
    "stdio" OS_SEP "atoll.c",
    "stdio" OS_SEP "fgetpos64.c",
    "stdio" OS_SEP "fopen64.c",
    "stdio" OS_SEP "fseeko32.c",
    "stdio" OS_SEP "fseeko64.c",
    "stdio" OS_SEP "fsetpos64.c",
    "stdio" OS_SEP "ftello.c",
    "stdio" OS_SEP "ftello64.c",
    "stdio" OS_SEP "ftruncate64.c",
    "stdio" OS_SEP "lltoa.c",
    "stdio" OS_SEP "lltow.c",
    "stdio" OS_SEP "lseek64.c",
    "stdio" OS_SEP "mingw_asprintf.c",
    "stdio" OS_SEP "mingw_fprintf.c",
    "stdio" OS_SEP "mingw_fprintfw.c",
    "stdio" OS_SEP "mingw_fscanf.c",
    "stdio" OS_SEP "mingw_fwscanf.c",
    "stdio" OS_SEP "mingw_pformat.c",
    "stdio" OS_SEP "mingw_pformatw.c",
    "stdio" OS_SEP "mingw_printf.c",
    "stdio" OS_SEP "mingw_printfw.c",
    "stdio" OS_SEP "mingw_scanf.c",
    "stdio" OS_SEP "mingw_snprintf.c",
    "stdio" OS_SEP "mingw_snprintfw.c",
    "stdio" OS_SEP "mingw_sprintf.c",
    "stdio" OS_SEP "mingw_sprintfw.c",
    "stdio" OS_SEP "mingw_sscanf.c",
    "stdio" OS_SEP "mingw_swscanf.c",
    "stdio" OS_SEP "mingw_vasprintf.c",
    "stdio" OS_SEP "mingw_vfprintf.c",
    "stdio" OS_SEP "mingw_vfprintfw.c",
    "stdio" OS_SEP "mingw_vfscanf.c",
    "stdio" OS_SEP "mingw_vprintf.c",
    "stdio" OS_SEP "mingw_vprintfw.c",
    "stdio" OS_SEP "mingw_vsnprintf.c",
    "stdio" OS_SEP "mingw_vsnprintfw.c",
    "stdio" OS_SEP "mingw_vsprintf.c",
    "stdio" OS_SEP "mingw_vsprintfw.c",
    "stdio" OS_SEP "mingw_wscanf.c",
    "stdio" OS_SEP "mingw_wvfscanf.c",
    "stdio" OS_SEP "scanf.S",
    "stdio" OS_SEP "snprintf.c",
    "stdio" OS_SEP "snwprintf.c",
    "stdio" OS_SEP "strtof.c",
    "stdio" OS_SEP "strtok_r.c",
    "stdio" OS_SEP "truncate.c",
    "stdio" OS_SEP "ulltoa.c",
    "stdio" OS_SEP "ulltow.c",
    "stdio" OS_SEP "vasprintf.c",
    "stdio" OS_SEP "vfscanf.c",
    "stdio" OS_SEP "vfscanf2.S",
    "stdio" OS_SEP "vfwscanf.c",
    "stdio" OS_SEP "vfwscanf2.S",
    "stdio" OS_SEP "vscanf.c",
    "stdio" OS_SEP "vscanf2.S",
    "stdio" OS_SEP "vsnprintf.c",
    "stdio" OS_SEP "vsnwprintf.c",
    "stdio" OS_SEP "vsscanf.c",
    "stdio" OS_SEP "vsscanf2.S",
    "stdio" OS_SEP "vswscanf.c",
    "stdio" OS_SEP "vswscanf2.S",
    "stdio" OS_SEP "vwscanf.c",
    "stdio" OS_SEP "vwscanf2.S",
    "stdio" OS_SEP "wtoll.c",
};

static const char *mingwex_x86_src[] = {
    "math" OS_SEP "x86" OS_SEP "acosf.c",
    "math" OS_SEP "x86" OS_SEP "acosh.c",
    "math" OS_SEP "x86" OS_SEP "acoshf.c",
    "math" OS_SEP "x86" OS_SEP "acoshl.c",
    "math" OS_SEP "x86" OS_SEP "acosl.c",
    "math" OS_SEP "x86" OS_SEP "asinf.c",
    "math" OS_SEP "x86" OS_SEP "asinh.c",
    "math" OS_SEP "x86" OS_SEP "asinhf.c",
    "math" OS_SEP "x86" OS_SEP "asinhl.c",
    "math" OS_SEP "x86" OS_SEP "asinl.c",
    "math" OS_SEP "x86" OS_SEP "atan2.c",
    "math" OS_SEP "x86" OS_SEP "atan2f.c",
    "math" OS_SEP "x86" OS_SEP "atan2l.c",
    "math" OS_SEP "x86" OS_SEP "atanf.c",
    "math" OS_SEP "x86" OS_SEP "atanh.c",
    "math" OS_SEP "x86" OS_SEP "atanhf.c",
    "math" OS_SEP "x86" OS_SEP "atanhl.c",
    "math" OS_SEP "x86" OS_SEP "atanl.c",
    "math" OS_SEP "x86" OS_SEP "ceilf.S",
    "math" OS_SEP "x86" OS_SEP "ceill.S",
    "math" OS_SEP "x86" OS_SEP "ceil.S",
    "math" OS_SEP "x86" OS_SEP "_chgsignl.S",
    "math" OS_SEP "x86" OS_SEP "copysignl.S",
    "math" OS_SEP "x86" OS_SEP "cos.c",
    "math" OS_SEP "x86" OS_SEP "cosf.c",
    "math" OS_SEP "x86" OS_SEP "cosl.c",
    "math" OS_SEP "x86" OS_SEP "cosl_internal.S",
    "math" OS_SEP "x86" OS_SEP "cossin.c",
    "math" OS_SEP "x86" OS_SEP "exp2f.S",
    "math" OS_SEP "x86" OS_SEP "exp2l.S",
    "math" OS_SEP "x86" OS_SEP "exp2.S",
    "math" OS_SEP "x86" OS_SEP "exp.c",
    "math" OS_SEP "x86" OS_SEP "expl.c",
    "math" OS_SEP "x86" OS_SEP "expm1.c",
    "math" OS_SEP "x86" OS_SEP "expm1f.c",
    "math" OS_SEP "x86" OS_SEP "expm1l.c",
    "math" OS_SEP "x86" OS_SEP "floorf.S",
    "math" OS_SEP "x86" OS_SEP "floorl.S",
    "math" OS_SEP "x86" OS_SEP "floor.S",
    "math" OS_SEP "x86" OS_SEP "fmod.c",
    "math" OS_SEP "x86" OS_SEP "fmodf.c",
    "math" OS_SEP "x86" OS_SEP "fmodl.c",
    "math" OS_SEP "x86" OS_SEP "fucom.c",
    "math" OS_SEP "x86" OS_SEP "ilogbf.S",
    "math" OS_SEP "x86" OS_SEP "ilogbl.S",
    "math" OS_SEP "x86" OS_SEP "ilogb.S",
    "math" OS_SEP "x86" OS_SEP "internal_logl.S",
    "math" OS_SEP "x86" OS_SEP "ldexp.c",
    "math" OS_SEP "x86" OS_SEP "ldexpl.c",
    "math" OS_SEP "x86" OS_SEP "log10l.S",
    "math" OS_SEP "x86" OS_SEP "log1pf.S",
    "math" OS_SEP "x86" OS_SEP "log1pl.S",
    "math" OS_SEP "x86" OS_SEP "log1p.S",
    "math" OS_SEP "x86" OS_SEP "log2f.S",
    "math" OS_SEP "x86" OS_SEP "log2l.S",
    "math" OS_SEP "x86" OS_SEP "log2.S",
    "math" OS_SEP "x86" OS_SEP "logb.c",
    "math" OS_SEP "x86" OS_SEP "logbf.c",
    "math" OS_SEP "x86" OS_SEP "logbl.c",
    "math" OS_SEP "x86" OS_SEP "log.c",
    "math" OS_SEP "x86" OS_SEP "logl.c",
    "math" OS_SEP "x86" OS_SEP "nearbyintf.S",
    "math" OS_SEP "x86" OS_SEP "nearbyintl.S",
    "math" OS_SEP "x86" OS_SEP "nearbyint.S",
    "math" OS_SEP "x86" OS_SEP "pow.c",
    "math" OS_SEP "x86" OS_SEP "powl.c",
    "math" OS_SEP "x86" OS_SEP "remainderf.S",
    "math" OS_SEP "x86" OS_SEP "remainderl.S",
    "math" OS_SEP "x86" OS_SEP "remainder.S",
    "math" OS_SEP "x86" OS_SEP "remquof.S",
    "math" OS_SEP "x86" OS_SEP "remquol.S",
    "math" OS_SEP "x86" OS_SEP "remquo.S",
    "math" OS_SEP "x86" OS_SEP "scalbnf.S",
    "math" OS_SEP "x86" OS_SEP "scalbnl.S",
    "math" OS_SEP "x86" OS_SEP "scalbn.S",
    "math" OS_SEP "x86" OS_SEP "sin.c",
    "math" OS_SEP "x86" OS_SEP "sinf.c",
    "math" OS_SEP "x86" OS_SEP "sinl.c",
    "math" OS_SEP "x86" OS_SEP "sinl_internal.S",
    "math" OS_SEP "x86" OS_SEP "tanf.c",
    "math" OS_SEP "x86" OS_SEP "tanl.S",
    "math" OS_SEP "x86" OS_SEP "truncf.S",
    "math" OS_SEP "x86" OS_SEP "trunc.S",
};

static const char *mingwex_arm32_src[] = {
    "math" OS_SEP "arm" OS_SEP "_chgsignl.S",
    "math" OS_SEP "arm" OS_SEP "exp2.c",
    "math" OS_SEP "arm" OS_SEP "nearbyint.S",
    "math" OS_SEP "arm" OS_SEP "nearbyintf.S",
    "math" OS_SEP "arm" OS_SEP "nearbyintl.S",
    "math" OS_SEP "arm" OS_SEP "trunc.S",
    "math" OS_SEP "arm" OS_SEP "truncf.S",
};

static const char *mingwex_arm64_src[] = {
    "math" OS_SEP "arm64" OS_SEP "_chgsignl.S",
    "math" OS_SEP "arm64" OS_SEP "exp2f.S",
    "math" OS_SEP "arm64" OS_SEP "exp2.S",
    "math" OS_SEP "arm64" OS_SEP "nearbyintf.S",
    "math" OS_SEP "arm64" OS_SEP "nearbyintl.S",
    "math" OS_SEP "arm64" OS_SEP "nearbyint.S",
    "math" OS_SEP "arm64" OS_SEP "truncf.S",
    "math" OS_SEP "arm64" OS_SEP "trunc.S",
};

static const char *mingw_uuid_src[] = {
    "libsrc/ativscp-uuid.c",
    "libsrc/atsmedia-uuid.c",
    "libsrc/bth-uuid.c",
    "libsrc/cguid-uuid.c",
    "libsrc/comcat-uuid.c",
    "libsrc/devguid.c",
    "libsrc/docobj-uuid.c",
    "libsrc/dxva-uuid.c",
    "libsrc/exdisp-uuid.c",
    "libsrc/extras-uuid.c",
    "libsrc/fwp-uuid.c",
    "libsrc/guid_nul.c",
    "libsrc/hlguids-uuid.c",
    "libsrc/hlink-uuid.c",
    "libsrc/mlang-uuid.c",
    "libsrc/msctf-uuid.c",
    "libsrc/mshtmhst-uuid.c",
    "libsrc/mshtml-uuid.c",
    "libsrc/msxml-uuid.c",
    "libsrc/netcon-uuid.c",
    "libsrc/ntddkbd-uuid.c",
    "libsrc/ntddmou-uuid.c",
    "libsrc/ntddpar-uuid.c",
    "libsrc/ntddscsi-uuid.c",
    "libsrc/ntddser-uuid.c",
    "libsrc/ntddstor-uuid.c",
    "libsrc/ntddvdeo-uuid.c",
    "libsrc/oaidl-uuid.c",
    "libsrc/objidl-uuid.c",
    "libsrc/objsafe-uuid.c",
    "libsrc/ocidl-uuid.c",
    "libsrc/oleacc-uuid.c",
    "libsrc/olectlid-uuid.c",
    "libsrc/oleidl-uuid.c",
    "libsrc/power-uuid.c",
    "libsrc/powrprof-uuid.c",
    "libsrc/uianimation-uuid.c",
    "libsrc/usbcamdi-uuid.c",
    "libsrc/usbiodef-uuid.c",
    "libsrc/uuid.c",
    "libsrc/vds-uuid.c",
    "libsrc/virtdisk-uuid.c",
    "libsrc/wia-uuid.c",
};

struct MinGWDef {
    const char *name;
    bool always_link;
};
static const MinGWDef mingw_def_list[] = {
    {"advapi32",true},
    {"bcrypt",  false},
    {"comctl32",false},
    {"comdlg32",false},
    {"crypt32", false},
    {"cryptnet",false},
    {"gdi32",   false},
    {"imm32",   false},
    {"kernel32",true},
    {"lz32",    false},
    {"mpr",     false},
    {"msvcrt",  true},
    {"mswsock", false},
    {"ncrypt",  false},
    {"netapi32",false},
    {"ntdll",   true},
    {"ole32",   false},
    {"oleaut32",false},
    {"opengl32",false},
    {"psapi",   false},
    {"rpcns4",  false},
    {"rpcrt4",  false},
    {"scarddlg",false},
    {"setupapi",false},
    {"shell32", true},
    {"shlwapi", false},
    {"urlmon",  false},
    {"user32",  true},
    {"version", false},
    {"winmm",   false},
    {"winscard",false},
    {"winspool",false},
    {"wintrust",false},
    {"ws2_32",  false},
};

struct LinkJob {
    CodeGen *codegen;
    ZigList<const char *> args;
    bool link_in_crt;
    HashMap<Buf *, bool, buf_hash, buf_eql_buf> rpath_table;
    Stage2ProgressNode *build_dep_prog_node;
};

static const char *build_libc_object(CodeGen *parent_gen, const char *name, CFile *c_file,
        Stage2ProgressNode *progress_node)
{
    CodeGen *child_gen = create_child_codegen(parent_gen, nullptr, OutTypeObj, nullptr, name, progress_node);
    child_gen->root_out_name = buf_create_from_str(name);
    ZigList<CFile *> c_source_files = {0};
    c_source_files.append(c_file);
    child_gen->c_source_files = c_source_files;
    codegen_build_and_link(child_gen);
    return buf_ptr(&child_gen->bin_file_output_path);
}

static const char *path_from_zig_lib(CodeGen *g, const char *dir, const char *subpath) {
    Buf *dir1 = buf_alloc();
    os_path_join(g->zig_lib_dir, buf_create_from_str(dir), dir1);
    Buf *result = buf_alloc();
    os_path_join(dir1, buf_create_from_str(subpath), result);
    return buf_ptr(result);
}

static const char *path_from_libc(CodeGen *g, const char *subpath) {
    return path_from_zig_lib(g, "libc", subpath);
}

static const char *path_from_libunwind(CodeGen *g, const char *subpath) {
    return path_from_zig_lib(g, "libunwind", subpath);
}

static const char *build_libunwind(CodeGen *parent, Stage2ProgressNode *progress_node) {
    CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr, "unwind", progress_node);
    LinkLib *new_link_lib = codegen_add_link_lib(child_gen, buf_create_from_str("c"));
    new_link_lib->provided_explicitly = false;
    enum SrcKind {
        SrcCpp,
        SrcC,
        SrcAsm,
    };
    static const struct {
        const char *path;
        SrcKind kind;
    } unwind_src[] = {
        {"src" OS_SEP "libunwind.cpp", SrcCpp},
        {"src" OS_SEP "Unwind-EHABI.cpp", SrcCpp},
        {"src" OS_SEP "Unwind-seh.cpp", SrcCpp},

        {"src" OS_SEP "UnwindLevel1.c", SrcC},
        {"src" OS_SEP "UnwindLevel1-gcc-ext.c", SrcC},
        {"src" OS_SEP "Unwind-sjlj.c", SrcC},

        {"src" OS_SEP "UnwindRegistersRestore.S", SrcAsm},
        {"src" OS_SEP "UnwindRegistersSave.S", SrcAsm},
    };
    ZigList<CFile *> c_source_files = {0};
    for (size_t i = 0; i < array_length(unwind_src); i += 1) {
        CFile *c_file = heap::c_allocator.create<CFile>();
        c_file->source_path = path_from_libunwind(parent, unwind_src[i].path);
        switch (unwind_src[i].kind) {
            case SrcC:
                c_file->args.append("-std=c99");
                break;
            case SrcCpp:
                c_file->args.append("-fno-rtti");
                c_file->args.append("-I");
                c_file->args.append(path_from_zig_lib(parent, "libcxx", "include"));
                break;
            case SrcAsm:
                break;
        }
        c_file->args.append("-I");
        c_file->args.append(path_from_libunwind(parent, "include"));
        if (target_supports_fpic(parent->zig_target)) {
            c_file->args.append("-fPIC");
        }
        c_file->args.append("-D_LIBUNWIND_DISABLE_VISIBILITY_ANNOTATIONS");
        c_file->args.append("-Wa,--noexecstack");

        // This is intentionally always defined because the macro definition means, should it only
        // build for the target specified by compiler defines. Since we pass -target the compiler
        // defines will be correct.
        c_file->args.append("-D_LIBUNWIND_IS_NATIVE_ONLY");

        if (parent->build_mode == BuildModeDebug) {
            c_file->args.append("-D_DEBUG");
        }
        if (parent->is_single_threaded) {
            c_file->args.append("-D_LIBUNWIND_HAS_NO_THREADS");
        }
        c_file->args.append("-Wno-bitwise-conditional-parentheses");
        c_source_files.append(c_file);
    }
    child_gen->c_source_files = c_source_files;
    codegen_build_and_link(child_gen);
    return buf_ptr(&child_gen->bin_file_output_path);
}

static void mingw_add_cc_args(CodeGen *parent, CFile *c_file) {
    c_file->args.append("-DHAVE_CONFIG_H");

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "mingw" OS_SEP "include",
                    buf_ptr(parent->zig_lib_dir))));

    c_file->args.append("-isystem");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "any-windows-any",
                    buf_ptr(parent->zig_lib_dir))));

    if (target_is_arm(parent->zig_target) &&
        target_arch_pointer_bit_width(parent->zig_target->arch) == 32)
    {
        c_file->args.append("-mfpu=vfp");
    }

    c_file->args.append("-std=gnu11");
    c_file->args.append("-D_CRTBLD");
    c_file->args.append("-D_WIN32_WINNT=0x0f00");
    c_file->args.append("-D__MSVCRT_VERSION__=0x700");
}

static void glibc_add_include_dirs_arch(CFile *c_file, ZigLLVM_ArchType arch, const char *nptl, const char *dir) {
    bool is_x86 = arch == ZigLLVM_x86 || arch == ZigLLVM_x86_64;
    bool is_aarch64 = arch == ZigLLVM_aarch64 || arch == ZigLLVM_aarch64_be;
    bool is_mips = arch == ZigLLVM_mips || arch == ZigLLVM_mipsel ||
        arch == ZigLLVM_mips64el || arch == ZigLLVM_mips64;
    bool is_arm = arch == ZigLLVM_arm || arch == ZigLLVM_armeb;
    bool is_ppc = arch == ZigLLVM_ppc || arch == ZigLLVM_ppc64 || arch == ZigLLVM_ppc64le;
    bool is_riscv = arch == ZigLLVM_riscv32 || arch == ZigLLVM_riscv64;
    bool is_sparc = arch == ZigLLVM_sparc || arch == ZigLLVM_sparcel || arch == ZigLLVM_sparcv9;
    bool is_64 = target_arch_pointer_bit_width(arch) == 64;

    if (is_x86) {
        if (arch == ZigLLVM_x86_64) {
            if (nptl != nullptr) {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "x86_64" OS_SEP "%s", dir, nptl)));
            } else {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "x86_64", dir)));
            }
        } else if (arch == ZigLLVM_x86) {
            if (nptl != nullptr) {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "i386" OS_SEP "%s", dir, nptl)));
            } else {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "i386", dir)));
            }
        }
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "x86" OS_SEP "%s", dir, nptl)));
        } else {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "x86", dir)));
        }
    } else if (is_arm) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "arm" OS_SEP "%s", dir, nptl)));
        } else {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "arm", dir)));
        }
    } else if (is_mips) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "mips" OS_SEP "%s", dir, nptl)));
        } else {
            if (is_64) {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "mips" OS_SEP "mips64", dir)));
            } else {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "mips" OS_SEP "mips32", dir)));
            }
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "mips", dir)));
        }
    } else if (is_sparc) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "sparc" OS_SEP "%s", dir, nptl)));
        } else {
            if (is_64) {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "sparc" OS_SEP "sparc64", dir)));
            } else {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "sparc" OS_SEP "sparc32", dir)));
            }
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "sparc", dir)));
        }
    } else if (is_aarch64) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "aarch64" OS_SEP "%s", dir, nptl)));
        } else {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "aarch64", dir)));
        }
    } else if (is_ppc) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "powerpc" OS_SEP "%s", dir, nptl)));
        } else {
            if (is_64) {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "powerpc" OS_SEP "powerpc64", dir)));
            } else {
                c_file->args.append("-I");
                c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "powerpc" OS_SEP "powerpc32", dir)));
            }
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "powerpc", dir)));
        }
    } else if (is_riscv) {
        if (nptl != nullptr) {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "riscv" OS_SEP "%s", dir, nptl)));
        } else {
            c_file->args.append("-I");
            c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "riscv", dir)));
        }
    }
}

static void glibc_add_include_dirs(CodeGen *parent, CFile *c_file) {
    ZigLLVM_ArchType arch = parent->zig_target->arch;
    const char *nptl = (parent->zig_target->os == OsLinux) ? "nptl" : "htl";
    const char *glibc = path_from_libc(parent, "glibc");

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "include", glibc)));

    if (parent->zig_target->os == OsLinux) {
        glibc_add_include_dirs_arch(c_file, arch, nullptr,
            path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "unix" OS_SEP "sysv" OS_SEP "linux"));
    }

    if (nptl != nullptr) {
        glibc_add_include_dirs_arch(c_file, arch, nptl, path_from_libc(parent, "glibc" OS_SEP "sysdeps"));
    }

    if (parent->zig_target->os == OsLinux) {
        c_file->args.append("-I");
        c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP
                    "unix" OS_SEP "sysv" OS_SEP "linux" OS_SEP "generic"));

        c_file->args.append("-I");
        c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP
                    "unix" OS_SEP "sysv" OS_SEP "linux" OS_SEP "include"));
        c_file->args.append("-I");
        c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP
                    "unix" OS_SEP "sysv" OS_SEP "linux"));
    }
    if (nptl != nullptr) {
        c_file->args.append("-I");
        c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "sysdeps" OS_SEP "%s", glibc, nptl)));
    }

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "pthread"));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "unix" OS_SEP "sysv"));

    glibc_add_include_dirs_arch(c_file, arch, nullptr,
            path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "unix"));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "unix"));

    glibc_add_include_dirs_arch(c_file, arch, nullptr, path_from_libc(parent, "glibc" OS_SEP "sysdeps"));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "sysdeps" OS_SEP "generic"));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "glibc"));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "%s-%s-%s",
                    buf_ptr(parent->zig_lib_dir), target_arch_name(parent->zig_target->arch),
                    target_os_name(parent->zig_target->os), target_abi_name(parent->zig_target->abi))));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "include" OS_SEP "generic-glibc"));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "%s-linux-any",
                    buf_ptr(parent->zig_lib_dir), target_arch_name(parent->zig_target->arch))));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "include" OS_SEP "any-linux-any"));
}

static const char *glibc_start_asm_path(CodeGen *parent, const char *file) {
    ZigLLVM_ArchType arch = parent->zig_target->arch;
    bool is_aarch64 = arch == ZigLLVM_aarch64 || arch == ZigLLVM_aarch64_be;
    bool is_mips = arch == ZigLLVM_mips || arch == ZigLLVM_mipsel ||
        arch == ZigLLVM_mips64el || arch == ZigLLVM_mips64;
    bool is_arm = arch == ZigLLVM_arm || arch == ZigLLVM_armeb;
    bool is_ppc = arch == ZigLLVM_ppc || arch == ZigLLVM_ppc64 || arch == ZigLLVM_ppc64le;
    bool is_riscv = arch == ZigLLVM_riscv32 || arch == ZigLLVM_riscv64;
    bool is_sparc = arch == ZigLLVM_sparc || arch == ZigLLVM_sparcel || arch == ZigLLVM_sparcv9;
    bool is_64 = target_arch_pointer_bit_width(arch) == 64;

    Buf result = BUF_INIT;
    buf_resize(&result, 0);
    buf_append_buf(&result, parent->zig_lib_dir);
    buf_append_str(&result, OS_SEP "libc" OS_SEP "glibc" OS_SEP "sysdeps" OS_SEP);
    if (is_sparc) {
        if (is_64) {
            buf_append_str(&result, "sparc" OS_SEP "sparc64");
        } else {
            buf_append_str(&result, "sparc" OS_SEP "sparc32");
        }
    } else if (is_arm) {
        buf_append_str(&result, "arm");
    } else if (is_mips) {
        buf_append_str(&result, "mips");
    } else if (arch == ZigLLVM_x86_64) {
        buf_append_str(&result, "x86_64");
    } else if (arch == ZigLLVM_x86) {
        buf_append_str(&result, "i386");
    } else if (is_aarch64) {
        buf_append_str(&result, "aarch64");
    } else if (is_riscv) {
        buf_append_str(&result, "riscv");
    } else if (is_ppc) {
        if (is_64) {
            buf_append_str(&result, "powerpc" OS_SEP "powerpc64");
        } else {
            buf_append_str(&result, "powerpc" OS_SEP "powerpc32");
        }
    }

    buf_append_str(&result, OS_SEP);
    buf_append_str(&result, file);
    return buf_ptr(&result);
}

static const char *musl_start_asm_path(CodeGen *parent, const char *file) {
    Buf *result = buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "crt" OS_SEP "%s" OS_SEP "%s",
                   buf_ptr(parent->zig_lib_dir), target_arch_musl_name(parent->zig_target->arch), file);
    return buf_ptr(result);
}

static void musl_add_cc_args(CodeGen *parent, CFile *c_file, bool want_O3) {
    c_file->args.append("-std=c99");
    c_file->args.append("-ffreestanding");
    // Musl adds these args to builds with gcc but clang does not support them. 
    //c_file->args.append("-fexcess-precision=standard");
    //c_file->args.append("-frounding-math");
    c_file->args.append("-Wa,--noexecstack");
    c_file->args.append("-D_XOPEN_SOURCE=700");

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "arch" OS_SEP "%s",
            buf_ptr(parent->zig_lib_dir), target_arch_musl_name(parent->zig_target->arch))));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "arch" OS_SEP "generic",
            buf_ptr(parent->zig_lib_dir))));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "src" OS_SEP "include",
            buf_ptr(parent->zig_lib_dir)))); 

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "src" OS_SEP "internal",
            buf_ptr(parent->zig_lib_dir))));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "musl" OS_SEP "include",
            buf_ptr(parent->zig_lib_dir))));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf(
            "%s" OS_SEP "libc" OS_SEP "include" OS_SEP "%s-%s-musl",
        buf_ptr(parent->zig_lib_dir),
        target_arch_musl_name(parent->zig_target->arch),
        target_os_name(parent->zig_target->os))));

    c_file->args.append("-I");
    c_file->args.append(buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "include" OS_SEP "generic-musl",
            buf_ptr(parent->zig_lib_dir))));

    if (want_O3)
        c_file->args.append("-O3");
    else
        c_file->args.append("-Os");

    c_file->args.append("-fomit-frame-pointer");
    c_file->args.append("-fno-unwind-tables");
    c_file->args.append("-fno-asynchronous-unwind-tables");
    c_file->args.append("-ffunction-sections");
    c_file->args.append("-fdata-sections");
}

static const char *musl_arch_names[] = {
    "aarch64",
    "arm",
    "generic",
    "i386",
    "m68k",
    "microblaze",
    "mips",
    "mips64",
    "mipsn32",
    "or1k",
    "powerpc",
    "powerpc64",
    "riscv64",
    "s390x",
    "sh",
    "x32",
    "x86_64",
};

static bool is_musl_arch_name(const char *name) {
    for (size_t i = 0; i < array_length(musl_arch_names); i += 1) {
        if (strcmp(name, musl_arch_names[i]) == 0)
            return true;
    }
    return false;
}

enum MuslSrc {
    MuslSrcAsm,
    MuslSrcNormal,
    MuslSrcO3,
};

static void add_musl_src_file(HashMap<Buf *, MuslSrc, buf_hash, buf_eql_buf> &source_table,
        const char *file_path)
{
    Buf *src_file = buf_create_from_str(file_path);

    MuslSrc src_kind;
    if (buf_ends_with_str(src_file, ".c")) {
        bool want_O3 = buf_starts_with_str(src_file, "musl/src/malloc/") ||
            buf_starts_with_str(src_file, "musl/src/string/") ||
            buf_starts_with_str(src_file, "musl/src/internal/");
        src_kind = want_O3 ? MuslSrcO3 : MuslSrcNormal;
    } else if (buf_ends_with_str(src_file, ".s") || buf_ends_with_str(src_file, ".S")) {
        src_kind = MuslSrcAsm;
    } else {
        zig_unreachable();
    }
    if (ZIG_OS_SEP_CHAR != '/') {
        buf_replace(src_file, '/', ZIG_OS_SEP_CHAR);
    }
    source_table.put_unique(src_file, src_kind);
}

static const char *build_musl(CodeGen *parent, Stage2ProgressNode *progress_node) {
    CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr, "c", progress_node);

    // When there is a src/<arch>/foo.* then it should substitute for src/foo.*
    // Even a .s file can substitute for a .c file.

    const char *target_musl_arch_name = target_arch_musl_name(parent->zig_target->arch);

    HashMap<Buf *, MuslSrc, buf_hash, buf_eql_buf> source_table = {};
    source_table.init(2000);

    for (size_t i = 0; i < array_length(ZIG_MUSL_SRC_FILES); i += 1) {
        add_musl_src_file(source_table, ZIG_MUSL_SRC_FILES[i]);
    }

    static const char *time32_compat_arch_list[] = {"arm", "i386", "mips", "powerpc"};
    for (size_t arch_i = 0; arch_i < array_length(time32_compat_arch_list); arch_i += 1) {
        if (strcmp(target_musl_arch_name, time32_compat_arch_list[arch_i]) == 0) {
            for (size_t i = 0; i < array_length(ZIG_MUSL_COMPAT_TIME32_FILES); i += 1) {
                add_musl_src_file(source_table, ZIG_MUSL_COMPAT_TIME32_FILES[i]);
            }
        }
    }


    ZigList<CFile *> c_source_files = {0};

    Buf dirname = BUF_INIT;
    Buf basename = BUF_INIT;
    Buf noextbasename = BUF_INIT;
    Buf dirbasename = BUF_INIT;
    Buf before_arch_dir = BUF_INIT;

    auto source_it = source_table.entry_iterator();
    for (;;) {
        auto *entry = source_it.next();
        if (!entry) break;

        Buf *src_file = entry->key;
        MuslSrc src_kind = entry->value;

        os_path_split(src_file, &dirname, &basename);
        os_path_extname(&basename, &noextbasename, nullptr);
        os_path_split(&dirname, &before_arch_dir, &dirbasename);

        bool is_arch_specific = false;
        // Architecture-specific implementations are under a <arch>/ folder.
        if (is_musl_arch_name(buf_ptr(&dirbasename))) {
            // Not the architecture we're compiling for.
            if (strcmp(buf_ptr(&dirbasename), target_musl_arch_name) != 0)
                continue;
            is_arch_specific = true;
        }

        if (!is_arch_specific) {
            Buf override_path = BUF_INIT;

            // Look for an arch specific override.
            buf_resize(&override_path, 0);
            buf_appendf(&override_path, "%s" OS_SEP "%s" OS_SEP "%s.s",
                        buf_ptr(&dirname), target_musl_arch_name, buf_ptr(&noextbasename));
            if (source_table.maybe_get(&override_path) != nullptr)
                continue;

            buf_resize(&override_path, 0);
            buf_appendf(&override_path, "%s" OS_SEP "%s" OS_SEP "%s.S",
                        buf_ptr(&dirname), target_musl_arch_name, buf_ptr(&noextbasename));
            if (source_table.maybe_get(&override_path) != nullptr)
                continue;

            buf_resize(&override_path, 0);
            buf_appendf(&override_path, "%s" OS_SEP "%s" OS_SEP "%s.c",
                        buf_ptr(&dirname), target_musl_arch_name, buf_ptr(&noextbasename));
            if (source_table.maybe_get(&override_path) != nullptr)
                continue;
        }

        Buf *full_path = buf_sprintf("%s" OS_SEP "libc" OS_SEP "%s",
                buf_ptr(parent->zig_lib_dir), buf_ptr(src_file));

        CFile *c_file = heap::c_allocator.create<CFile>();
        c_file->source_path = buf_ptr(full_path);

        musl_add_cc_args(parent, c_file, src_kind == MuslSrcO3);
        c_file->args.append("-Qunused-arguments");
        c_file->args.append("-w"); // disable all warnings

        c_source_files.append(c_file);
    }

    child_gen->c_source_files = c_source_files;
    codegen_build_and_link(child_gen);
    return buf_ptr(&child_gen->bin_file_output_path);
}

static const char *build_libcxxabi(CodeGen *parent, Stage2ProgressNode *progress_node) {
    CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr, "c++abi", progress_node);
    codegen_add_link_lib(child_gen, buf_create_from_str("c"));

    ZigList<CFile *> c_source_files = {0};

    const char *cxxabi_include_path = buf_ptr(buf_sprintf("%s" OS_SEP "libcxxabi" OS_SEP "include",
                buf_ptr(parent->zig_lib_dir)));
    const char *cxx_include_path = buf_ptr(buf_sprintf("%s" OS_SEP "libcxx" OS_SEP "include",
                buf_ptr(parent->zig_lib_dir)));

    for (size_t i = 0; i < array_length(ZIG_LIBCXXABI_FILES); i += 1) {
        const char *rel_src_path = ZIG_LIBCXXABI_FILES[i];

        CFile *c_file = heap::c_allocator.create<CFile>();
        c_file->source_path = buf_ptr(buf_sprintf("%s" OS_SEP "libcxxabi" OS_SEP "%s",
                    buf_ptr(parent->zig_lib_dir), rel_src_path));

        c_file->args.append("-DHAVE___CXA_THREAD_ATEXIT_IMPL");
        c_file->args.append("-D_LIBCPP_DISABLE_EXTERN_TEMPLATE");
        c_file->args.append("-D_LIBCPP_ENABLE_CXX17_REMOVED_UNEXPECTED_FUNCTIONS");
        c_file->args.append("-D_LIBCXXABI_BUILDING_LIBRARY");
        c_file->args.append("-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS");
        c_file->args.append("-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS");

        if (target_abi_is_musl(parent->zig_target->abi)) {
            c_file->args.append("-D_LIBCPP_HAS_MUSL_LIBC");
        }

        c_file->args.append("-I");
        c_file->args.append(cxxabi_include_path);

        c_file->args.append("-I");
        c_file->args.append(cxx_include_path);

        c_file->args.append("-O3");
        c_file->args.append("-DNDEBUG");
        if (target_supports_fpic(parent->zig_target)) {
            c_file->args.append("-fPIC");
        }
        c_file->args.append("-nostdinc++");
        c_file->args.append("-fstrict-aliasing");
        c_file->args.append("-funwind-tables");
        c_file->args.append("-D_DEBUG");
        c_file->args.append("-UNDEBUG");
        c_file->args.append("-std=c++11");

        c_source_files.append(c_file);
    }


    child_gen->c_source_files = c_source_files;
    codegen_build_and_link(child_gen);
    return buf_ptr(&child_gen->bin_file_output_path);
}

static const char *build_libcxx(CodeGen *parent, Stage2ProgressNode *progress_node) {
    CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr, "c++", progress_node);
    codegen_add_link_lib(child_gen, buf_create_from_str("c"));

    ZigList<CFile *> c_source_files = {0};

    const char *cxxabi_include_path = buf_ptr(buf_sprintf("%s" OS_SEP "libcxxabi" OS_SEP "include",
                buf_ptr(parent->zig_lib_dir)));
    const char *cxx_include_path = buf_ptr(buf_sprintf("%s" OS_SEP "libcxx" OS_SEP "include",
                buf_ptr(parent->zig_lib_dir)));

    for (size_t i = 0; i < array_length(ZIG_LIBCXX_FILES); i += 1) {
        const char *rel_src_path = ZIG_LIBCXX_FILES[i];

        Buf *src_path_buf = buf_create_from_str(rel_src_path);
        if (parent->zig_target->os == OsWindows) {
            // filesystem stuff isn't supported on Windows
            if (buf_starts_with_str(src_path_buf, "src/filesystem/")) {
                continue;
            }
        } else {
            if (buf_starts_with_str(src_path_buf, "src/support/win32/")) {
                continue;
            }
        }

        CFile *c_file = heap::c_allocator.create<CFile>();
        c_file->source_path = buf_ptr(buf_sprintf("%s" OS_SEP "libcxx" OS_SEP "%s",
                    buf_ptr(parent->zig_lib_dir), rel_src_path));

        c_file->args.append("-DNDEBUG");
        c_file->args.append("-D_LIBCPP_BUILDING_LIBRARY");
        c_file->args.append("-D_LIBCPP_HAS_NO_PRAGMA_SYSTEM_HEADER");
        c_file->args.append("-DLIBCXX_BUILDING_LIBCXXABI");
        c_file->args.append("-D_LIBCXXABI_DISABLE_VISIBILITY_ANNOTATIONS");
        c_file->args.append("-D_LIBCPP_DISABLE_VISIBILITY_ANNOTATIONS");

        if (target_abi_is_musl(parent->zig_target->abi)) {
            c_file->args.append("-D_LIBCPP_HAS_MUSL_LIBC");
        }

        c_file->args.append("-I");
        c_file->args.append(cxx_include_path);

        c_file->args.append("-I");
        c_file->args.append(cxxabi_include_path);

        c_file->args.append("-O3");
        c_file->args.append("-DNDEBUG");
        if (target_supports_fpic(parent->zig_target)) {
            c_file->args.append("-fPIC");
        }
        c_file->args.append("-nostdinc++");
        c_file->args.append("-fvisibility-inlines-hidden");
        c_file->args.append("-std=c++14");
        c_file->args.append("-Wno-user-defined-literals");

        c_source_files.append(c_file);
    }


    child_gen->c_source_files = c_source_files;
    codegen_build_and_link(child_gen);
    return buf_ptr(&child_gen->bin_file_output_path);
}

static void add_msvcrt_os_dep(CodeGen *parent, CodeGen *child_gen, const char *src_path) {
    CFile *c_file = heap::c_allocator.create<CFile>();
    c_file->source_path = buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "mingw" OS_SEP "%s",
            buf_ptr(parent->zig_lib_dir), src_path));
    c_file->args.append("-DHAVE_CONFIG_H");
    c_file->args.append("-D__LIBMSVCRT__");

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "mingw" OS_SEP "include"));

    c_file->args.append("-std=gnu99");
    c_file->args.append("-D_CRTBLD");
    c_file->args.append("-D_WIN32_WINNT=0x0f00");
    c_file->args.append("-D__MSVCRT_VERSION__=0x700");

    c_file->args.append("-isystem");
    c_file->args.append(path_from_libc(parent, "include" OS_SEP "any-windows-any"));

    c_file->args.append("-g");
    c_file->args.append("-O2");

    child_gen->c_source_files.append(c_file);
}

static void add_mingwex_dep(CodeGen *parent, CodeGen *child_gen, const char *src_path) {
    CFile *c_file = heap::c_allocator.create<CFile>();
    c_file->source_path = buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "mingw" OS_SEP "%s",
            buf_ptr(parent->zig_lib_dir), src_path));
    c_file->args.append("-DHAVE_CONFIG_H");

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "mingw"));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "mingw" OS_SEP "include"));

    c_file->args.append("-std=gnu99");
    c_file->args.append("-D_CRTBLD");
    c_file->args.append("-D_WIN32_WINNT=0x0f00");
    c_file->args.append("-D__MSVCRT_VERSION__=0x700");
    c_file->args.append("-g");
    c_file->args.append("-O2");

    c_file->args.append("-isystem");
    c_file->args.append(path_from_libc(parent, "include" OS_SEP "any-windows-any"));

    child_gen->c_source_files.append(c_file);
}

static void add_mingw_uuid_dep(CodeGen *parent, CodeGen *child_gen, const char *src_path) {
    CFile *c_file = heap::c_allocator.create<CFile>();
    c_file->source_path = buf_ptr(buf_sprintf("%s" OS_SEP "libc" OS_SEP "mingw" OS_SEP "%s",
            buf_ptr(parent->zig_lib_dir), src_path));
    c_file->args.append("-DHAVE_CONFIG_H");

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "mingw"));

    c_file->args.append("-I");
    c_file->args.append(path_from_libc(parent, "mingw" OS_SEP "include"));

    c_file->args.append("-std=gnu99");
    c_file->args.append("-D_CRTBLD");
    c_file->args.append("-D_WIN32_WINNT=0x0f00");
    c_file->args.append("-D__MSVCRT_VERSION__=0x700");
    c_file->args.append("-g");
    c_file->args.append("-O2");

    c_file->args.append("-isystem");
    c_file->args.append(path_from_libc(parent, "include" OS_SEP "any-windows-any"));

    child_gen->c_source_files.append(c_file);
}

static const char *get_libc_crt_file(CodeGen *parent, const char *file, Stage2ProgressNode *progress_node) {
    if (parent->libc == nullptr && parent->zig_target->os == OsWindows) {
        if (strcmp(file, "crt2.o") == 0) {
            CFile *c_file = heap::c_allocator.create<CFile>();
            c_file->source_path = buf_ptr(buf_sprintf(
                "%s" OS_SEP "libc" OS_SEP "mingw" OS_SEP "crt" OS_SEP "crtexe.c", buf_ptr(parent->zig_lib_dir)));
            mingw_add_cc_args(parent, c_file);
            c_file->args.append("-U__CRTDLL__");
            c_file->args.append("-D__MSVCRT__");
            // Uncomment these 3 things for crtu
            //c_file->args.append("-DUNICODE");
            //c_file->args.append("-D_UNICODE");
            //c_file->args.append("-DWPRFLAG=1");
            return build_libc_object(parent, "crt2", c_file, progress_node);
        } else if (strcmp(file, "dllcrt2.o") == 0) {
            CFile *c_file = heap::c_allocator.create<CFile>();
            c_file->source_path = buf_ptr(buf_sprintf(
                "%s" OS_SEP "libc" OS_SEP "mingw" OS_SEP "crt" OS_SEP "crtdll.c", buf_ptr(parent->zig_lib_dir)));
            mingw_add_cc_args(parent, c_file);
            c_file->args.append("-U__CRTDLL__");
            c_file->args.append("-D__MSVCRT__");
            return build_libc_object(parent, "dllcrt2", c_file, progress_node);
        } else if (strcmp(file, "mingw32.lib") == 0) {
            CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr, "mingw32", progress_node);

            static const char *deps[] = {
                "mingw" OS_SEP "crt" OS_SEP "crt0_c.c",
                "mingw" OS_SEP "crt" OS_SEP "dll_argv.c",
                "mingw" OS_SEP "crt" OS_SEP "gccmain.c",
                "mingw" OS_SEP "crt" OS_SEP "natstart.c",
                "mingw" OS_SEP "crt" OS_SEP "pseudo-reloc-list.c",
                "mingw" OS_SEP "crt" OS_SEP "wildcard.c",
                "mingw" OS_SEP "crt" OS_SEP "charmax.c",
                "mingw" OS_SEP "crt" OS_SEP "crt0_w.c",
                "mingw" OS_SEP "crt" OS_SEP "dllargv.c",
                "mingw" OS_SEP "crt" OS_SEP "gs_support.c",
                "mingw" OS_SEP "crt" OS_SEP "_newmode.c",
                "mingw" OS_SEP "crt" OS_SEP "tlssup.c",
                "mingw" OS_SEP "crt" OS_SEP "xncommod.c",
                "mingw" OS_SEP "crt" OS_SEP "cinitexe.c",
                "mingw" OS_SEP "crt" OS_SEP "merr.c",
                "mingw" OS_SEP "crt" OS_SEP "usermatherr.c",
                "mingw" OS_SEP "crt" OS_SEP "pesect.c",
                "mingw" OS_SEP "crt" OS_SEP "udllargc.c",
                "mingw" OS_SEP "crt" OS_SEP "xthdloc.c",
                "mingw" OS_SEP "crt" OS_SEP "CRT_fp10.c",
                "mingw" OS_SEP "crt" OS_SEP "mingw_helpers.c",
                "mingw" OS_SEP "crt" OS_SEP "pseudo-reloc.c",
                "mingw" OS_SEP "crt" OS_SEP "udll_argv.c",
                "mingw" OS_SEP "crt" OS_SEP "xtxtmode.c",
                "mingw" OS_SEP "crt" OS_SEP "crt_handler.c",
                "mingw" OS_SEP "crt" OS_SEP "tlsthrd.c",
                "mingw" OS_SEP "crt" OS_SEP "tlsmthread.c",
                "mingw" OS_SEP "crt" OS_SEP "tlsmcrt.c",
                "mingw" OS_SEP "crt" OS_SEP "cxa_atexit.c",
            };
            for (size_t i = 0; i < array_length(deps); i += 1) {
                CFile *c_file = heap::c_allocator.create<CFile>();
                c_file->source_path = path_from_libc(parent, deps[i]);
                c_file->args.append("-DHAVE_CONFIG_H");
                c_file->args.append("-D_SYSCRT=1");
                c_file->args.append("-DCRTDLL=1");

                c_file->args.append("-isystem");
                c_file->args.append(path_from_libc(parent, "include" OS_SEP "any-windows-any"));

                c_file->args.append("-isystem");
                c_file->args.append(path_from_libc(parent, "mingw" OS_SEP "include"));

                c_file->args.append("-std=gnu99");
                c_file->args.append("-D_CRTBLD");
                c_file->args.append("-D_WIN32_WINNT=0x0f00");
                c_file->args.append("-D__MSVCRT_VERSION__=0x700");
                c_file->args.append("-g");
                c_file->args.append("-O2");

                child_gen->c_source_files.append(c_file);
            }
            codegen_build_and_link(child_gen);
            return buf_ptr(&child_gen->bin_file_output_path);
        } else if (strcmp(file, "msvcrt-os.lib") == 0) {
            CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr, "msvcrt-os", progress_node);

            for (size_t i = 0; i < array_length(msvcrt_common_src); i += 1) {
                add_msvcrt_os_dep(parent, child_gen, msvcrt_common_src[i]);
            }
            if (parent->zig_target->arch == ZigLLVM_x86) {
                for (size_t i = 0; i < array_length(msvcrt_i386_src); i += 1) {
                    add_msvcrt_os_dep(parent, child_gen, msvcrt_i386_src[i]);
                }
            } else {
                for (size_t i = 0; i < array_length(msvcrt_other_src); i += 1) {
                    add_msvcrt_os_dep(parent, child_gen, msvcrt_other_src[i]);
                }
            }
            codegen_build_and_link(child_gen);
            return buf_ptr(&child_gen->bin_file_output_path);
        } else if (strcmp(file, "mingwex.lib") == 0) {
            CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr, "mingwex", progress_node);

            for (size_t i = 0; i < array_length(mingwex_generic_src); i += 1) {
                add_mingwex_dep(parent, child_gen, mingwex_generic_src[i]);
            }
            if (parent->zig_target->arch == ZigLLVM_x86 || parent->zig_target->arch == ZigLLVM_x86_64) {
                for (size_t i = 0; i < array_length(mingwex_x86_src); i += 1) {
                    add_mingwex_dep(parent, child_gen, mingwex_x86_src[i]);
                }
            } else if (target_is_arm(parent->zig_target)) {
                if (target_arch_pointer_bit_width(parent->zig_target->arch) == 32) {
                    for (size_t i = 0; i < array_length(mingwex_arm32_src); i += 1) {
                        add_mingwex_dep(parent, child_gen, mingwex_arm32_src[i]);
                    }
                } else {
                    for (size_t i = 0; i < array_length(mingwex_arm64_src); i += 1) {
                        add_mingwex_dep(parent, child_gen, mingwex_arm64_src[i]);
                    }
                }
            } else {
                zig_unreachable();
            }
            codegen_build_and_link(child_gen);
            return buf_ptr(&child_gen->bin_file_output_path);
        } else if (strcmp(file, "uuid.lib") == 0) {
            CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr, "uuid", progress_node);
            for (size_t i = 0; i < array_length(mingw_uuid_src); i += 1) {
                add_mingw_uuid_dep(parent, child_gen, mingw_uuid_src[i]);
            }
            codegen_build_and_link(child_gen);
            return buf_ptr(&child_gen->bin_file_output_path);
        } else {
            zig_unreachable();
        }
    } else if (parent->libc == nullptr && target_is_glibc(parent->zig_target)) {
        if (strcmp(file, "crti.o") == 0) {
            CFile *c_file = heap::c_allocator.create<CFile>();
            c_file->source_path = glibc_start_asm_path(parent, "crti.S");
            glibc_add_include_dirs(parent, c_file);
            c_file->args.append("-D_LIBC_REENTRANT");
            c_file->args.append("-include");
            c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-modules.h"));
            c_file->args.append("-DMODULE_NAME=libc");
            c_file->args.append("-Wno-nonportable-include-path");
            c_file->args.append("-include");
            c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-symbols.h"));
            c_file->args.append("-DTOP_NAMESPACE=glibc");
            c_file->args.append("-DASSEMBLER");
            c_file->args.append("-g");
            c_file->args.append("-Wa,--noexecstack");
            return build_libc_object(parent, "crti", c_file, progress_node);
        } else if (strcmp(file, "crtn.o") == 0) {
            CFile *c_file = heap::c_allocator.create<CFile>();
            c_file->source_path = glibc_start_asm_path(parent, "crtn.S");
            glibc_add_include_dirs(parent, c_file);
            c_file->args.append("-D_LIBC_REENTRANT");
            c_file->args.append("-DMODULE_NAME=libc");
            c_file->args.append("-DTOP_NAMESPACE=glibc");
            c_file->args.append("-DASSEMBLER");
            c_file->args.append("-g");
            c_file->args.append("-Wa,--noexecstack");
            return build_libc_object(parent, "crtn", c_file, progress_node);
        } else if (strcmp(file, "start.os") == 0) {
            CFile *c_file = heap::c_allocator.create<CFile>();
            c_file->source_path = glibc_start_asm_path(parent, "start.S");
            glibc_add_include_dirs(parent, c_file);
            c_file->args.append("-D_LIBC_REENTRANT");
            c_file->args.append("-include");
            c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-modules.h"));
            c_file->args.append("-DMODULE_NAME=libc");
            c_file->args.append("-Wno-nonportable-include-path");
            c_file->args.append("-include");
            c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-symbols.h"));
            c_file->args.append("-DPIC");
            c_file->args.append("-DSHARED");
            c_file->args.append("-DTOP_NAMESPACE=glibc");
            c_file->args.append("-DASSEMBLER");
            c_file->args.append("-g");
            c_file->args.append("-Wa,--noexecstack");
            return build_libc_object(parent, "start", c_file, progress_node);
        } else if (strcmp(file, "abi-note.o") == 0) {
            CFile *c_file = heap::c_allocator.create<CFile>();
            c_file->source_path = path_from_libc(parent, "glibc" OS_SEP "csu" OS_SEP "abi-note.S");
            c_file->args.append("-I");
            c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "csu"));
            glibc_add_include_dirs(parent, c_file);
            c_file->args.append("-D_LIBC_REENTRANT");
            c_file->args.append("-DMODULE_NAME=libc");
            c_file->args.append("-DTOP_NAMESPACE=glibc");
            c_file->args.append("-DASSEMBLER");
            c_file->args.append("-g");
            c_file->args.append("-Wa,--noexecstack");
            return build_libc_object(parent, "abi-note", c_file, progress_node);
        } else if (strcmp(file, "Scrt1.o") == 0) {
            const char *start_os = get_libc_crt_file(parent, "start.os", progress_node);
            const char *abi_note_o = get_libc_crt_file(parent, "abi-note.o", progress_node);
            CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeObj, nullptr, "Scrt1", progress_node);
            codegen_add_object(child_gen, buf_create_from_str(start_os));
            codegen_add_object(child_gen, buf_create_from_str(abi_note_o));
            codegen_build_and_link(child_gen);
            return buf_ptr(&child_gen->bin_file_output_path);
        } else if (strcmp(file, "libc_nonshared.a") == 0) {
            CodeGen *child_gen = create_child_codegen(parent, nullptr, OutTypeLib, nullptr, "c_nonshared", progress_node);
            {
                CFile *c_file = heap::c_allocator.create<CFile>();
                c_file->source_path = path_from_libc(parent, "glibc" OS_SEP "csu" OS_SEP "elf-init.c");
                c_file->args.append("-std=gnu11");
                c_file->args.append("-fgnu89-inline");
                c_file->args.append("-g");
                c_file->args.append("-O2");
                c_file->args.append("-fmerge-all-constants");
                c_file->args.append("-fno-stack-protector");
                c_file->args.append("-fmath-errno");
                c_file->args.append("-fno-stack-protector");
                c_file->args.append("-I");
                c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "csu"));
                glibc_add_include_dirs(parent, c_file);
                c_file->args.append("-DSTACK_PROTECTOR_LEVEL=0");
                c_file->args.append("-fPIC");
                c_file->args.append("-fno-stack-protector");
                c_file->args.append("-ftls-model=initial-exec");
                c_file->args.append("-D_LIBC_REENTRANT");
                c_file->args.append("-include");
                c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-modules.h"));
                c_file->args.append("-DMODULE_NAME=libc");
                c_file->args.append("-Wno-nonportable-include-path");
                c_file->args.append("-include");
                c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-symbols.h"));
                c_file->args.append("-DPIC");
                c_file->args.append("-DLIBC_NONSHARED=1");
                c_file->args.append("-DTOP_NAMESPACE=glibc");
                codegen_add_object(child_gen, buf_create_from_str(
                            build_libc_object(parent, "elf-init", c_file, progress_node)));
            }
            static const struct {
                const char *name;
                const char *path;
            } deps[] = {
                {"atexit", "glibc" OS_SEP "stdlib" OS_SEP "atexit.c"},
                {"at_quick_exit", "glibc" OS_SEP "stdlib" OS_SEP "at_quick_exit.c"},
                {"stat", "glibc" OS_SEP "io" OS_SEP "stat.c"},
                {"fstat", "glibc" OS_SEP "io" OS_SEP "fstat.c"},
                {"lstat", "glibc" OS_SEP "io" OS_SEP "lstat.c"},
                {"stat64", "glibc" OS_SEP "io" OS_SEP "stat64.c"},
                {"fstat64", "glibc" OS_SEP "io" OS_SEP "fstat64.c"},
                {"lstat64", "glibc" OS_SEP "io" OS_SEP "lstat64.c"},
                {"fstatat", "glibc" OS_SEP "io" OS_SEP "fstatat.c"},
                {"fstatat64", "glibc" OS_SEP "io" OS_SEP "fstatat64.c"},
                {"mknod", "glibc" OS_SEP "io" OS_SEP "mknod.c"},
                {"mknodat", "glibc" OS_SEP "io" OS_SEP "mknodat.c"},
                {"pthread_atfork", "glibc" OS_SEP "nptl" OS_SEP "pthread_atfork.c"},
                {"stack_chk_fail_local", "glibc" OS_SEP "debug" OS_SEP "stack_chk_fail_local.c"},
            };
            for (size_t i = 0; i < array_length(deps); i += 1) {
                CFile *c_file = heap::c_allocator.create<CFile>();
                c_file->source_path = path_from_libc(parent, deps[i].path);
                c_file->args.append("-std=gnu11");
                c_file->args.append("-fgnu89-inline");
                c_file->args.append("-g");
                c_file->args.append("-O2");
                c_file->args.append("-fmerge-all-constants");
                c_file->args.append("-fno-stack-protector");
                c_file->args.append("-fmath-errno");
                c_file->args.append("-ftls-model=initial-exec");
                c_file->args.append("-Wno-ignored-attributes");
                glibc_add_include_dirs(parent, c_file);
                c_file->args.append("-D_LIBC_REENTRANT");
                c_file->args.append("-include");
                c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-modules.h"));
                c_file->args.append("-DMODULE_NAME=libc");
                c_file->args.append("-Wno-nonportable-include-path");
                c_file->args.append("-include");
                c_file->args.append(path_from_libc(parent, "glibc" OS_SEP "include" OS_SEP "libc-symbols.h"));
                c_file->args.append("-DPIC");
                c_file->args.append("-DLIBC_NONSHARED=1");
                c_file->args.append("-DTOP_NAMESPACE=glibc");
                codegen_add_object(child_gen, buf_create_from_str(
                            build_libc_object(parent, deps[i].name, c_file, progress_node)));
            }
            codegen_build_and_link(child_gen);
            return buf_ptr(&child_gen->bin_file_output_path);
        } else {
            zig_unreachable();
        }
    } else if (parent->libc == nullptr && target_is_musl(parent->zig_target)) {
        if (strcmp(file, "crti.o") == 0) {
            CFile *c_file = heap::c_allocator.create<CFile>();
            c_file->source_path = musl_start_asm_path(parent, "crti.s");
            musl_add_cc_args(parent, c_file, false);
            c_file->args.append("-Qunused-arguments");
            return build_libc_object(parent, "crti", c_file, progress_node);
        } else if (strcmp(file, "crtn.o") == 0) {
            CFile *c_file = heap::c_allocator.create<CFile>();
            c_file->source_path = musl_start_asm_path(parent, "crtn.s");
            c_file->args.append("-Qunused-arguments");
            musl_add_cc_args(parent, c_file, false);
            return build_libc_object(parent, "crtn", c_file, progress_node);
        } else if (strcmp(file, "crt1.o") == 0) {
            CFile *c_file = heap::c_allocator.create<CFile>();
            c_file->source_path = path_from_libc(parent, "musl" OS_SEP "crt" OS_SEP "crt1.c");
            musl_add_cc_args(parent, c_file, false);
            c_file->args.append("-fno-stack-protector");
            c_file->args.append("-DCRT");
            return build_libc_object(parent, "crt1", c_file, progress_node);
        } else if (strcmp(file, "Scrt1.o") == 0) {
            CFile *c_file = heap::c_allocator.create<CFile>();
            c_file->source_path = path_from_libc(parent, "musl" OS_SEP "crt" OS_SEP "Scrt1.c");
            musl_add_cc_args(parent, c_file, false);
            c_file->args.append("-fPIC");
            c_file->args.append("-fno-stack-protector");
            c_file->args.append("-DCRT");
            return build_libc_object(parent, "Scrt1", c_file, progress_node);
        } else {
            zig_unreachable();
        }
    } else {
        assert(parent->libc != nullptr);
        Buf *out_buf = buf_alloc();
        os_path_join(buf_create_from_mem(parent->libc->crt_dir, parent->libc->crt_dir_len),
                buf_create_from_str(file), out_buf);
        return buf_ptr(out_buf);
    }
}

static Buf *build_a_raw(CodeGen *parent_gen, const char *aname, Buf *full_path, OutType child_out_type,
        Stage2ProgressNode *progress_node)
{
    CodeGen *child_gen = create_child_codegen(parent_gen, full_path, child_out_type, parent_gen->libc, aname,
            progress_node);

    // This is so that compiler_rt and libc.zig libraries know whether they
    // will eventually be linked with libc. They make different decisions
    // about what to export depending on whether libc is linked.
    if (parent_gen->libc_link_lib != nullptr) {
        LinkLib *new_link_lib = codegen_add_link_lib(child_gen, parent_gen->libc_link_lib->name);
        new_link_lib->provided_explicitly = parent_gen->libc_link_lib->provided_explicitly;
    }

    // Override the inherited build mode parameter
    if (!parent_gen->is_test_build) {
        switch (parent_gen->build_mode) {
            case BuildModeDebug:
            case BuildModeFastRelease:
            case BuildModeSafeRelease:
                child_gen->build_mode = BuildModeFastRelease;
                break;
            case BuildModeSmallRelease:
                break;
        }
    }

    child_gen->function_sections = true;
    child_gen->want_stack_check = WantStackCheckDisabled;

    codegen_build_and_link(child_gen);
    return &child_gen->bin_file_output_path;
}

static Buf *build_compiler_rt(CodeGen *parent_gen, OutType child_out_type, Stage2ProgressNode *progress_node) {
    Buf *full_path = buf_alloc();
    os_path_join(parent_gen->zig_std_special_dir, buf_create_from_str("compiler_rt.zig"), full_path);

    return build_a_raw(parent_gen, "compiler_rt", full_path, child_out_type, progress_node);
}

static Buf *build_c(CodeGen *parent_gen, OutType child_out_type, Stage2ProgressNode *progress_node) {
    Buf *full_path = buf_alloc();
    os_path_join(parent_gen->zig_std_special_dir, buf_create_from_str("c.zig"), full_path);

    return build_a_raw(parent_gen, "c", full_path, child_out_type, progress_node);
}

static const char *get_darwin_arch_string(const ZigTarget *t) {
    switch (t->arch) {
        case ZigLLVM_aarch64:
            return "arm64";
        case ZigLLVM_thumb:
        case ZigLLVM_arm:
            return "arm";
        case ZigLLVM_ppc:
            return "ppc";
        case ZigLLVM_ppc64:
            return "ppc64";
        case ZigLLVM_ppc64le:
            return "ppc64le";
        default:
            return ZigLLVMGetArchTypeName(t->arch);
    }
}


static const char *getLDMOption(const ZigTarget *t) {
    switch (t->arch) {
        case ZigLLVM_x86:
            return "elf_i386";
        case ZigLLVM_aarch64:
            return "aarch64linux";
        case ZigLLVM_aarch64_be:
            return "aarch64_be_linux";
        case ZigLLVM_arm:
        case ZigLLVM_thumb:
            return "armelf_linux_eabi";
        case ZigLLVM_armeb:
        case ZigLLVM_thumbeb:
            return "armebelf_linux_eabi";
        case ZigLLVM_ppc:
            return "elf32ppclinux";
        case ZigLLVM_ppc64:
            return "elf64ppc";
        case ZigLLVM_ppc64le:
            return "elf64lppc";
        case ZigLLVM_sparc:
        case ZigLLVM_sparcel:
            return "elf32_sparc";
        case ZigLLVM_sparcv9:
            return "elf64_sparc";
        case ZigLLVM_mips:
            return "elf32btsmip";
        case ZigLLVM_mipsel:
            return "elf32ltsmip";
            return "elf64btsmip";
        case ZigLLVM_mips64el:
            return "elf64ltsmip";
        case ZigLLVM_systemz:
            return "elf64_s390";
        case ZigLLVM_x86_64:
            if (t->abi == ZigLLVM_GNUX32) {
                return "elf32_x86_64";
            }
            // Any target elf will use the freebsd osabi if suffixed with "_fbsd".
            if (t->os == OsFreeBSD) {
                return "elf_x86_64_fbsd";
            }
            return "elf_x86_64";
        case ZigLLVM_riscv32:
            return "elf32lriscv";
        case ZigLLVM_riscv64:
            return "elf64lriscv";
        default:
            zig_unreachable();
    }
}

static void add_rpath(LinkJob *lj, Buf *rpath) {
    if (lj->rpath_table.maybe_get(rpath) != nullptr)
        return;

    lj->args.append("-rpath");
    lj->args.append(buf_ptr(rpath));

    lj->rpath_table.put(rpath, true);
}

static void add_glibc_libs(LinkJob *lj) {
    Error err;
    ZigGLibCAbi *glibc_abi;
    if ((err = glibc_load_metadata(&glibc_abi, lj->codegen->zig_lib_dir, true))) {
        fprintf(stderr, "%s\n", err_str(err));
        exit(1);
    }

    Buf *artifact_dir;
    if ((err = glibc_build_dummies_and_maps(lj->codegen, glibc_abi, lj->codegen->zig_target,
                    &artifact_dir, true, lj->build_dep_prog_node)))
    {
        fprintf(stderr, "%s\n", err_str(err));
        exit(1);
    }

    size_t lib_count = glibc_lib_count();
    for (size_t i = 0; i < lib_count; i += 1) {
        const ZigGLibCLib *lib = glibc_lib_enum(i);
        Buf *so_path = buf_sprintf("%s" OS_SEP "lib%s.so.%d.0.0", buf_ptr(artifact_dir), lib->name, lib->sover);
        lj->args.append(buf_ptr(so_path));
    }
}

static void construct_linker_job_elf(LinkJob *lj) {
    CodeGen *g = lj->codegen;

    lj->args.append("-error-limit=0");

    if (g->out_type == OutTypeExe) {
        lj->args.append("-z");
        size_t stack_size = (g->stack_size_override == 0) ? 16777216 : g->stack_size_override;
        lj->args.append(buf_ptr(buf_sprintf("stack-size=%" ZIG_PRI_usize, stack_size)));
    }

    if (g->linker_script) {
        lj->args.append("-T");
        lj->args.append(g->linker_script);
    }

    switch (g->linker_gc_sections) {
        case OptionalBoolNull:
            if (g->out_type != OutTypeObj) {
                lj->args.append("--gc-sections");
            }
            break;
        case OptionalBoolTrue:
            lj->args.append("--gc-sections");
            break;
        case OptionalBoolFalse:
            break;
    }

    if (g->link_eh_frame_hdr) {
        lj->args.append("--eh-frame-hdr");
    }

    if (g->linker_rdynamic) {
        lj->args.append("--export-dynamic");
    }

    if (g->linker_optimization != nullptr) {
        lj->args.append(buf_ptr(g->linker_optimization));
    }

    if (g->linker_z_nodelete) {
        lj->args.append("-z");
        lj->args.append("nodelete");
    }
    if (g->linker_z_defs) {
        lj->args.append("-z");
        lj->args.append("defs");
    }

    lj->args.append("-m");
    lj->args.append(getLDMOption(g->zig_target));

    bool is_lib = g->out_type == OutTypeLib;
    bool is_dyn_lib = g->is_dynamic && is_lib;
    if (!g->have_dynamic_link) {
        if (g->zig_target->arch == ZigLLVM_arm || g->zig_target->arch == ZigLLVM_armeb ||
            g->zig_target->arch == ZigLLVM_thumb || g->zig_target->arch == ZigLLVM_thumbeb)
        {
            lj->args.append("-Bstatic");
        } else {
            lj->args.append("-static");
        }
    } else if (is_dyn_lib) {
        lj->args.append("-shared");
    }

    if (target_requires_pie(g->zig_target) && g->out_type == OutTypeExe) {
        lj->args.append("-pie");
    }

    assert(buf_len(&g->bin_file_output_path) != 0);
    lj->args.append("-o");
    lj->args.append(buf_ptr(&g->bin_file_output_path));

    if (lj->link_in_crt) {
        const char *crt1o;
        if (g->zig_target->os == OsNetBSD) {
            crt1o = "crt0.o";
        } else if (target_is_android(g->zig_target)) {
            if (g->have_dynamic_link) {
                crt1o = "crtbegin_dynamic.o";
            } else {
                crt1o = "crtbegin_static.o";
            }
        } else if (!g->have_dynamic_link) {
            crt1o = "crt1.o";
        } else {
            crt1o = "Scrt1.o";
        }
        lj->args.append(get_libc_crt_file(g, crt1o, lj->build_dep_prog_node));
        if (target_libc_needs_crti_crtn(g->zig_target)) {
            lj->args.append(get_libc_crt_file(g, "crti.o", lj->build_dep_prog_node));
        }
    }

    for (size_t i = 0; i < g->rpath_list.length; i += 1) {
        Buf *rpath = g->rpath_list.at(i);
        add_rpath(lj, rpath);
    }
    if (g->each_lib_rpath) {
        for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
            const char *lib_dir = g->lib_dirs.at(i);
            for (size_t i = 0; i < g->link_libs_list.length; i += 1) {
                LinkLib *link_lib = g->link_libs_list.at(i);
                if (buf_eql_str(link_lib->name, "c")) {
                    continue;
                }
                bool does_exist;
                Buf *test_path = buf_sprintf("%s/lib%s.so", lib_dir, buf_ptr(link_lib->name));
                if (os_file_exists(test_path, &does_exist) != ErrorNone) {
                    zig_panic("link: unable to check if file exists: %s", buf_ptr(test_path));
                }
                if (does_exist) {
                    add_rpath(lj, buf_create_from_str(lib_dir));
                    break;
                }
            }
        }
    }

    for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
        const char *lib_dir = g->lib_dirs.at(i);
        lj->args.append("-L");
        lj->args.append(lib_dir);
    }

    if (g->libc_link_lib != nullptr) {
        if (g->libc != nullptr) {
            lj->args.append("-L");
            lj->args.append(buf_ptr(buf_create_from_mem(g->libc->crt_dir, g->libc->crt_dir_len)));
        }

        if (g->have_dynamic_link && (is_dyn_lib || g->out_type == OutTypeExe)) {
            assert(g->zig_target->dynamic_linker != nullptr);
            lj->args.append("-dynamic-linker");
            lj->args.append(g->zig_target->dynamic_linker);
        }
    }

    if (is_dyn_lib) {
        Buf *soname = (g->override_soname == nullptr) ?
            buf_sprintf("lib%s.so.%" ZIG_PRI_usize, buf_ptr(g->root_out_name), g->version_major) :
            g->override_soname;
        lj->args.append("-soname");
        lj->args.append(buf_ptr(soname));

        if (g->version_script_path != nullptr) {
            lj->args.append("-version-script");
            lj->args.append(buf_ptr(g->version_script_path));
        }
    }

    // .o files
    for (size_t i = 0; i < g->link_objects.length; i += 1) {
        lj->args.append((const char *)buf_ptr(g->link_objects.at(i)));
    }

    if (!g->is_dummy_so && (g->out_type == OutTypeExe || is_dyn_lib)) {
        if (g->libc_link_lib == nullptr) {
            Buf *libc_a_path = build_c(g, OutTypeLib, lj->build_dep_prog_node);
            lj->args.append(buf_ptr(libc_a_path));
        }

        Buf *compiler_rt_o_path = build_compiler_rt(g, OutTypeLib, lj->build_dep_prog_node);
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }

    // libraries
    for (size_t i = 0; i < g->link_libs_list.length; i += 1) {
        LinkLib *link_lib = g->link_libs_list.at(i);
        if (buf_eql_str(link_lib->name, "c")) {
            // libc is linked specially
            continue;
        }
        if (target_is_libcpp_lib_name(g->zig_target, buf_ptr(link_lib->name))) {
            // libc++ is linked specially
            continue;
        }
        if (g->libc == nullptr && target_is_libc_lib_name(g->zig_target, buf_ptr(link_lib->name))) {
            // these libraries are always linked below when targeting glibc
            continue;
        }
        Buf *arg;
        if (buf_starts_with_str(link_lib->name, "/") || buf_ends_with_str(link_lib->name, ".a") ||
            buf_ends_with_str(link_lib->name, ".so"))
        {
            arg = link_lib->name;
        } else {
            arg = buf_sprintf("-l%s", buf_ptr(link_lib->name));
        }
        lj->args.append(buf_ptr(arg));
    }

    // libc++ dep
    if (g->libcpp_link_lib != nullptr && g->out_type != OutTypeObj) {
        lj->args.append(build_libcxxabi(g, lj->build_dep_prog_node));
        lj->args.append(build_libcxx(g, lj->build_dep_prog_node));
    }

    // libc dep
    if (g->libc_link_lib != nullptr && g->out_type != OutTypeObj) {
        if (g->libc != nullptr) {
            if (!g->have_dynamic_link) {
                lj->args.append("--start-group");
                lj->args.append("-lc");
                lj->args.append("-lm");
                lj->args.append("--end-group");
            } else {
                lj->args.append("-lc");
                lj->args.append("-lm");
            }

            if (g->zig_target->os == OsFreeBSD ||
                g->zig_target->os == OsNetBSD)
            {
                lj->args.append("-lpthread");
            }
        } else if (target_is_glibc(g->zig_target)) {
            lj->args.append(build_libunwind(g, lj->build_dep_prog_node));
            add_glibc_libs(lj);
            lj->args.append(get_libc_crt_file(g, "libc_nonshared.a", lj->build_dep_prog_node));
        } else if (target_is_musl(g->zig_target)) {
            lj->args.append(build_libunwind(g, lj->build_dep_prog_node));
            lj->args.append(build_musl(g, lj->build_dep_prog_node));
        } else if (g->libcpp_link_lib != nullptr) {
            lj->args.append(build_libunwind(g, lj->build_dep_prog_node));
        } else {
            zig_unreachable();
        }
    }

    // crt end
    if (lj->link_in_crt) {
        if (target_is_android(g->zig_target)) {
            lj->args.append(get_libc_crt_file(g, "crtend_android.o", lj->build_dep_prog_node));
        } else if (target_libc_needs_crti_crtn(g->zig_target)) {
            lj->args.append(get_libc_crt_file(g, "crtn.o", lj->build_dep_prog_node));
        }
    }

    switch (g->linker_allow_shlib_undefined) {
        case OptionalBoolNull:
            if (!g->zig_target->is_native_os) {
                lj->args.append("--allow-shlib-undefined");
            }
            break;
        case OptionalBoolFalse:
            break;
        case OptionalBoolTrue:
            lj->args.append("--allow-shlib-undefined");
            break;
    }
    switch (g->linker_bind_global_refs_locally) {
        case OptionalBoolNull:
        case OptionalBoolFalse:
            break;
        case OptionalBoolTrue:
            lj->args.append("-Bsymbolic");
            break;
    }
}

static void construct_linker_job_wasm(LinkJob *lj) {
    CodeGen *g = lj->codegen;

    lj->args.append("-error-limit=0");
    // Increase the default stack size to a more reasonable value of 1MB instead of
    // the default of 1 Wasm page being 64KB, unless overriden by the user.
    size_t stack_size = (g->stack_size_override == 0) ? 1048576 : g->stack_size_override;
    lj->args.append("-z");
    lj->args.append(buf_ptr(buf_sprintf("stack-size=%" ZIG_PRI_usize, stack_size)));

    // put stack before globals so that stack overflow results in segfault immediately before corrupting globals
    // see https://github.com/ziglang/zig/issues/4496
    lj->args.append("--stack-first");

    if (g->out_type != OutTypeExe) {
        lj->args.append("--no-entry"); // So lld doesn't look for _start.

        // If there are any C source files we cannot rely on individual exports.
        if (g->c_source_files.length != 0) {
            lj->args.append("--export-all");
        } else {
            auto export_it = g->exported_symbol_names.entry_iterator();
            decltype(g->exported_symbol_names)::Entry *curr_entry = nullptr;
            while ((curr_entry = export_it.next()) != nullptr) {
                Buf *arg = buf_sprintf("--export=%s", buf_ptr(curr_entry->key));
                lj->args.append(buf_ptr(arg));
            }
        }
    }
    lj->args.append("--allow-undefined");
    lj->args.append("-o");
    lj->args.append(buf_ptr(&g->bin_file_output_path));

    // .o files
    for (size_t i = 0; i < g->link_objects.length; i += 1) {
        lj->args.append((const char *)buf_ptr(g->link_objects.at(i)));
    }

    if (g->out_type != OutTypeObj) {
        Buf *libc_o_path = build_c(g, OutTypeObj, lj->build_dep_prog_node);
        lj->args.append(buf_ptr(libc_o_path));

        Buf *compiler_rt_o_path = build_compiler_rt(g, OutTypeObj, lj->build_dep_prog_node);
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }
}

static void coff_append_machine_arg(CodeGen *g, ZigList<const char *> *list) {
    if (g->zig_target->arch == ZigLLVM_x86) {
        list->append("-MACHINE:X86");
    } else if (g->zig_target->arch == ZigLLVM_x86_64) {
        list->append("-MACHINE:X64");
    } else if (target_is_arm(g->zig_target)) {
        if (target_arch_pointer_bit_width(g->zig_target->arch) == 32) {
            list->append("-MACHINE:ARM");
        } else {
            list->append("-MACHINE:ARM64");
        }
    }
}

static void link_diag_callback(void *context, const char *ptr, size_t len) {
    Buf *diag = reinterpret_cast<Buf *>(context);
    buf_append_mem(diag, ptr, len);
}

static bool zig_lld_link(ZigLLVM_ObjectFormatType oformat, const char **args, size_t arg_count,
        Buf *diag)
{
    Buf *stdout_diag = buf_alloc();
    buf_resize(diag, 0);
    bool result = ZigLLDLink(oformat, args, arg_count, link_diag_callback, stdout_diag, diag);
    buf_destroy(stdout_diag);
    return result;
}

static void add_uefi_link_args(LinkJob *lj) {
    lj->args.append("-BASE:0");
    lj->args.append("-ENTRY:EfiMain");
    lj->args.append("-OPT:REF");
    lj->args.append("-SAFESEH:NO");
    lj->args.append("-MERGE:.rdata=.data");
    lj->args.append("-ALIGN:32");
    lj->args.append("-NODEFAULTLIB");
    lj->args.append("-SECTION:.xdata,D");
}

static void add_msvc_link_args(LinkJob *lj, bool is_library) {
    CodeGen *g = lj->codegen;

    bool is_dynamic = g->is_dynamic;
    const char *lib_str = is_dynamic ? "" : "lib";
    const char *d_str = (g->build_mode == BuildModeDebug) ? "d" : "";

    if (!is_dynamic) {
        Buf *cmt_lib_name = buf_sprintf("libcmt%s.lib", d_str);
        lj->args.append(buf_ptr(cmt_lib_name));
    } else {
        Buf *msvcrt_lib_name = buf_sprintf("msvcrt%s.lib", d_str);
        lj->args.append(buf_ptr(msvcrt_lib_name));
    }

    Buf *vcruntime_lib_name = buf_sprintf("%svcruntime%s.lib", lib_str, d_str);
    lj->args.append(buf_ptr(vcruntime_lib_name));

    Buf *crt_lib_name = buf_sprintf("%sucrt%s.lib", lib_str, d_str);
    lj->args.append(buf_ptr(crt_lib_name));

    //Visual C++ 2015 Conformance Changes
    //https://msdn.microsoft.com/en-us/library/bb531344.aspx
    lj->args.append("legacy_stdio_definitions.lib");

    // msvcrt depends on kernel32 and ntdll
    lj->args.append("kernel32.lib");
    lj->args.append("ntdll.lib");
}

static void print_zig_cc_cmd(ZigList<const char *> *args) {
    for (size_t arg_i = 0; arg_i < args->length; arg_i += 1) {
        const char *space_str = (arg_i == 0) ? "" : " ";
        fprintf(stderr, "%s%s", space_str, args->at(arg_i));
    }
    fprintf(stderr, "\n");
}

static const char *get_def_lib(CodeGen *parent, const char *name, Buf *def_in_file) {
    Error err;

    Buf *self_exe_path = buf_alloc();
    if ((err = os_self_exe_path(self_exe_path))) {
        fprintf(stderr, "Unable to get self exe path: %s\n", err_str(err));
        exit(1);
    }
    Buf *compiler_id;
    if ((err = get_compiler_id(&compiler_id))) {
        fprintf(stderr, "Unable to get compiler id: %s\n", err_str(err));
        exit(1);
    }

    Buf *cache_dir = get_global_cache_dir();
    Buf *o_dir = buf_sprintf("%s" OS_SEP CACHE_OUT_SUBDIR, buf_ptr(cache_dir));
    Buf *manifest_dir = buf_sprintf("%s" OS_SEP CACHE_HASH_SUBDIR, buf_ptr(cache_dir));

    Buf *def_include_dir = buf_sprintf("%s" OS_SEP "libc" OS_SEP "mingw" OS_SEP "def-include",
            buf_ptr(parent->zig_lib_dir));

    CacheHash *cache_hash = heap::c_allocator.create<CacheHash>();
    cache_init(cache_hash, manifest_dir);

    cache_buf(cache_hash, compiler_id);
    cache_file(cache_hash, def_in_file);
    cache_buf(cache_hash, def_include_dir);
    cache_int(cache_hash, parent->zig_target->arch);

    Buf digest = BUF_INIT;
    buf_resize(&digest, 0);
    if ((err = cache_hit(cache_hash, &digest))) {
        if (err != ErrorInvalidFormat) {
            if (err == ErrorCacheUnavailable) {
                // already printed error
            } else {
                fprintf(stderr, "unable to check cache when processing .def.in file: %s\n", err_str(err));
            }
            exit(1);
        }
    }

    Buf *artifact_dir;
    Buf *lib_final_path;
    Buf *final_lib_basename = buf_sprintf("%s.lib", name);

    bool is_cache_miss = (buf_len(&digest) == 0);
    if (is_cache_miss) {
        if ((err = cache_final(cache_hash, &digest))) {
            fprintf(stderr, "Unable to finalize cache hash: %s\n", err_str(err));
            exit(1);
        }
        artifact_dir = buf_alloc();
        os_path_join(o_dir, &digest, artifact_dir);
        if ((err = os_make_path(artifact_dir))) {
            fprintf(stderr, "Unable to create output directory '%s': %s",
                    buf_ptr(artifact_dir), err_str(err));
            exit(1);
        }
        Buf *final_def_basename = buf_sprintf("%s.def", name);
        Buf *def_final_path = buf_alloc();
        os_path_join(artifact_dir, final_def_basename, def_final_path);

        ZigList<const char *> args = {};
        args.append(buf_ptr(self_exe_path));
        args.append("clang");
        args.append("-x");
        args.append("c");
        args.append(buf_ptr(def_in_file));
        args.append("-Wp,-w");
        args.append("-undef");
        args.append("-P");
        args.append("-I");
        args.append(buf_ptr(def_include_dir));
        if (target_is_arm(parent->zig_target)) {
            if (target_arch_pointer_bit_width(parent->zig_target->arch) == 32) {
                args.append("-DDEF_ARM32");
            } else {
                args.append("-DDEF_ARM64");
            }
        } else if (parent->zig_target->arch == ZigLLVM_x86) {
            args.append("-DDEF_I386");
        } else if (parent->zig_target->arch == ZigLLVM_x86_64) {
            args.append("-DDEF_X64");
        } else {
            zig_unreachable();
        }
        args.append("-E");
        args.append("-o");
        args.append(buf_ptr(def_final_path));

        if (parent->verbose_cc) {
            print_zig_cc_cmd(&args);
        }
        Termination term;
        os_spawn_process(args, &term);
        if (term.how != TerminationIdClean || term.code != 0) {
            fprintf(stderr, "\nThe following command failed:\n");
            print_zig_cc_cmd(&args);
            exit(1);
        }

        lib_final_path = buf_alloc();
        os_path_join(artifact_dir, final_lib_basename, lib_final_path);

        if (ZigLLVMWriteImportLibrary(buf_ptr(def_final_path),
                                      parent->zig_target->arch,
                                      buf_ptr(lib_final_path),
                                      /* kill_at */ true))
        {
            zig_panic("link: could not emit %s", buf_ptr(lib_final_path));
        }
    } else {
        // cache hit
        artifact_dir = buf_alloc();
        os_path_join(o_dir, &digest, artifact_dir);
        lib_final_path = buf_alloc();
        os_path_join(artifact_dir, final_lib_basename, lib_final_path);
    }
    parent->caches_to_release.append(cache_hash);

    return buf_ptr(lib_final_path);
}

static bool is_linking_system_lib(CodeGen *g, const char *name) {
    for (size_t lib_i = 0; lib_i < g->link_libs_list.length; lib_i += 1) {
        LinkLib *link_lib = g->link_libs_list.at(lib_i);
        if (buf_eql_str(link_lib->name, name)) {
            return true;
        }
    }
    return false;
}

static Error find_mingw_lib_def(LinkJob *lj, const char *name, Buf *out_path) {
    CodeGen *g = lj->codegen;
    Buf override_path = BUF_INIT;
    Error err;

    char const *lib_path = nullptr;
    if (g->zig_target->arch == ZigLLVM_x86) {
        lib_path = "lib32";
    } else if (g->zig_target->arch == ZigLLVM_x86_64) {
        lib_path = "lib64";
    } else if (target_is_arm(g->zig_target)) {
        const bool is_32 = target_arch_pointer_bit_width(g->zig_target->arch) == 32;
        lib_path = is_32 ? "libarm32" : "libarm64";
    } else {
        zig_unreachable();
    }

    // Try the archtecture-specific path first
    buf_resize(&override_path, 0);
    buf_appendf(&override_path, "%s" OS_SEP "libc" OS_SEP "mingw" OS_SEP "%s" OS_SEP "%s.def", buf_ptr(g->zig_lib_dir), lib_path, name);

    bool does_exist;
    if ((err = os_file_exists(&override_path, &does_exist)) != ErrorNone) {
        return err;
    }

    if (!does_exist) {
        // Try the generic version
        buf_resize(&override_path, 0);
        buf_appendf(&override_path, "%s" OS_SEP "libc" OS_SEP "mingw" OS_SEP "lib-common" OS_SEP "%s.def", buf_ptr(g->zig_lib_dir), name);

        if ((err = os_file_exists(&override_path, &does_exist)) != ErrorNone) {
            return err;
        }
    }

    if (!does_exist) {
        // Try the generic version and preprocess it
        buf_resize(&override_path, 0);
        buf_appendf(&override_path, "%s" OS_SEP "libc" OS_SEP "mingw" OS_SEP "lib-common" OS_SEP "%s.def.in", buf_ptr(g->zig_lib_dir), name);

        if ((err = os_file_exists(&override_path, &does_exist)) != ErrorNone) {
            return err;
        }
    }

    if (!does_exist) {
        return ErrorFileNotFound;
    }

    buf_init_from_buf(out_path, &override_path);
    return ErrorNone;
}

static void add_mingw_link_args(LinkJob *lj, bool is_library) {
    CodeGen *g = lj->codegen;

    lj->args.append("-lldmingw");

    bool is_dll = g->out_type == OutTypeLib && g->is_dynamic;

    if (g->zig_target->arch == ZigLLVM_x86) {
        lj->args.append("-ALTERNATENAME:__image_base__=___ImageBase");
    } else {
        lj->args.append("-ALTERNATENAME:__image_base__=__ImageBase");
    }

    if (is_dll) {
        lj->args.append(get_libc_crt_file(g, "dllcrt2.o", lj->build_dep_prog_node));
    } else {
        lj->args.append(get_libc_crt_file(g, "crt2.o", lj->build_dep_prog_node));
    }

    lj->args.append(get_libc_crt_file(g, "mingw32.lib", lj->build_dep_prog_node));
    lj->args.append(get_libc_crt_file(g, "mingwex.lib", lj->build_dep_prog_node));
    lj->args.append(get_libc_crt_file(g, "msvcrt-os.lib", lj->build_dep_prog_node));

    for (size_t def_i = 0; def_i < array_length(mingw_def_list); def_i += 1) {
        const char *name = mingw_def_list[def_i].name;
        const bool always_link = mingw_def_list[def_i].always_link;

        if (always_link || is_linking_system_lib(g, name)) {
            Buf lib_path = BUF_INIT;
            Error err = find_mingw_lib_def(lj, name, &lib_path);

            if (err == ErrorFileNotFound) {
                zig_panic("link: could not find .def file to build %s\n", name);
            } else if (err != ErrorNone) {
                zig_panic("link: unable to check if .def file for %s exists: %s",
                        name, err_str(err));
            }

            lj->args.append(get_def_lib(g, name, &lib_path));
        }
    }
}

static void add_win_link_args(LinkJob *lj, bool is_library, bool *have_windows_dll_import_libs) {
    if (lj->link_in_crt) {
        if (target_abi_is_gnu(lj->codegen->zig_target->abi)) {
            *have_windows_dll_import_libs = true;
            add_mingw_link_args(lj, is_library);
        } else {
            add_msvc_link_args(lj, is_library);
        }
    } else {
        lj->args.append("-NODEFAULTLIB");
        if (!is_library) {
            if (lj->codegen->have_winmain) {
                lj->args.append("-ENTRY:WinMain");
            } else if (lj->codegen->have_wwinmain) {
                lj->args.append("-ENTRY:wWinMain");
            } else if (lj->codegen->have_wwinmain_crt_startup) {
                lj->args.append("-ENTRY:wWinMainCRTStartup");
            } else {
                lj->args.append("-ENTRY:WinMainCRTStartup");
            }
        }
    }
}

static bool is_mingw_link_lib(Buf *name) {
    for (size_t def_i = 0; def_i < array_length(mingw_def_list); def_i += 1) {
        if (buf_eql_str_ignore_case(name, mingw_def_list[def_i].name)) {
            return true;
        }
    }
    return false;
}
static void construct_linker_job_coff(LinkJob *lj) {
    Error err;
    CodeGen *g = lj->codegen;

    lj->args.append("-ERRORLIMIT:0");

    lj->args.append("-NOLOGO");

    if (!g->strip_debug_symbols) {
        lj->args.append("-DEBUG");
    }

    if (g->out_type == OutTypeExe) {
        // TODO compile time stack upper bound detection
        size_t stack_size = (g->stack_size_override == 0) ? 16777216 : g->stack_size_override;
        lj->args.append(buf_ptr(buf_sprintf("-STACK:%" ZIG_PRI_usize, stack_size)));
    }

    coff_append_machine_arg(g, &lj->args);

    bool is_library = g->out_type == OutTypeLib;
    if (is_library && g->is_dynamic) {
        lj->args.append("-DLL");
    }

    lj->args.append(buf_ptr(buf_sprintf("-OUT:%s", buf_ptr(&g->bin_file_output_path))));

    if (g->libc_link_lib != nullptr && g->libc != nullptr) {
        Buf *buff0 = buf_create_from_str("-LIBPATH:");
        buf_append_mem(buff0, g->libc->crt_dir, g->libc->crt_dir_len);
        lj->args.append(buf_ptr(buff0));

        if (target_abi_is_gnu(g->zig_target->abi)) {
            Buf *buff1 = buf_create_from_str("-LIBPATH:");
            buf_append_mem(buff1, g->libc->sys_include_dir, g->libc->sys_include_dir_len);
            lj->args.append(buf_ptr(buff1));

            Buf *buff2 = buf_create_from_str("-LIBPATH:");
            buf_append_mem(buff2, g->libc->include_dir, g->libc->include_dir_len);
            lj->args.append(buf_ptr(buff2));
        } else {
            Buf *buff1 = buf_create_from_str("-LIBPATH:");
            buf_append_mem(buff1, g->libc->msvc_lib_dir, g->libc->msvc_lib_dir_len);
            lj->args.append(buf_ptr(buff1));

            Buf *buff2 = buf_create_from_str("-LIBPATH:");
            buf_append_mem(buff2, g->libc->kernel32_lib_dir, g->libc->kernel32_lib_dir_len);
            lj->args.append(buf_ptr(buff2));
        }
    }

    for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
        const char *lib_dir = g->lib_dirs.at(i);
        lj->args.append(buf_ptr(buf_sprintf("-LIBPATH:%s", lib_dir)));
    }

    for (size_t i = 0; i < g->link_objects.length; i += 1) {
        lj->args.append((const char *)buf_ptr(g->link_objects.at(i)));
    }

    bool have_windows_dll_import_libs = false;
    switch (detect_subsystem(g)) {
        case TargetSubsystemAuto:
            if (g->zig_target->os == OsUefi) {
                add_uefi_link_args(lj);
            } else {
                add_win_link_args(lj, is_library, &have_windows_dll_import_libs);
            }
            break;
        case TargetSubsystemConsole:
            lj->args.append("-SUBSYSTEM:console");
            add_win_link_args(lj, is_library, &have_windows_dll_import_libs);
            break;
        case TargetSubsystemEfiApplication:
            lj->args.append("-SUBSYSTEM:efi_application");
            add_uefi_link_args(lj);
            break;
        case TargetSubsystemEfiBootServiceDriver:
            lj->args.append("-SUBSYSTEM:efi_boot_service_driver");
            add_uefi_link_args(lj);
            break;
        case TargetSubsystemEfiRom:
            lj->args.append("-SUBSYSTEM:efi_rom");
            add_uefi_link_args(lj);
            break;
        case TargetSubsystemEfiRuntimeDriver:
            lj->args.append("-SUBSYSTEM:efi_runtime_driver");
            add_uefi_link_args(lj);
            break;
        case TargetSubsystemNative:
            lj->args.append("-SUBSYSTEM:native");
            add_win_link_args(lj, is_library, &have_windows_dll_import_libs);
            break;
        case TargetSubsystemPosix:
            lj->args.append("-SUBSYSTEM:posix");
            add_win_link_args(lj, is_library, &have_windows_dll_import_libs);
            break;
        case TargetSubsystemWindows:
            lj->args.append("-SUBSYSTEM:windows");
            add_win_link_args(lj, is_library, &have_windows_dll_import_libs);
            break;
    }

    // libc++ dep
    if (g->libcpp_link_lib != nullptr && g->out_type != OutTypeObj) {
        lj->args.append(build_libcxxabi(g, lj->build_dep_prog_node));
        lj->args.append(build_libcxx(g, lj->build_dep_prog_node));
        lj->args.append(build_libunwind(g, lj->build_dep_prog_node));
    }

    if (g->out_type == OutTypeExe || (g->out_type == OutTypeLib && g->is_dynamic)) {
        if (g->libc_link_lib == nullptr && !g->is_dummy_so) {
            Buf *libc_a_path = build_c(g, OutTypeLib, lj->build_dep_prog_node);
            lj->args.append(buf_ptr(libc_a_path));
        }

        // msvc compiler_rt is missing some stuff, so we still build it and rely on weak linkage
        Buf *compiler_rt_o_path = build_compiler_rt(g, OutTypeLib, lj->build_dep_prog_node);
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }

    for (size_t lib_i = 0; lib_i < g->link_libs_list.length; lib_i += 1) {
        LinkLib *link_lib = g->link_libs_list.at(lib_i);
        if (buf_eql_str(link_lib->name, "c")) {
            continue;
        }
        if (target_is_libcpp_lib_name(g->zig_target, buf_ptr(link_lib->name))) {
            // libc++ is linked specially
            continue;
        }
        if (g->libc == nullptr && target_is_libc_lib_name(g->zig_target, buf_ptr(link_lib->name))) {
            // these libraries are always linked below when targeting glibc
            continue;
        }
        bool is_sys_lib = is_mingw_link_lib(link_lib->name);
        if (have_windows_dll_import_libs && is_sys_lib) {
            continue;
        }
        // If we're linking in the CRT or the libs are provided explictly we don't want to generate def/libs
        if ((lj->link_in_crt && is_sys_lib) || link_lib->provided_explicitly) {
            if (target_abi_is_gnu(lj->codegen->zig_target->abi)) {
                if (buf_eql_str(link_lib->name, "uuid")) {
                    // mingw-w64 provides this lib
                    lj->args.append(get_libc_crt_file(g, "uuid.lib", lj->build_dep_prog_node));
                } else {
                    Buf* lib_name = buf_sprintf("lib%s.a", buf_ptr(link_lib->name));
                    lj->args.append(buf_ptr(lib_name));
                }
            } else {
                Buf* lib_name = buf_sprintf("%s.lib", buf_ptr(link_lib->name));
                lj->args.append(buf_ptr(lib_name));
            }
            continue;
        }

        // This library may be a system one and we may have a suitable .lib file

        // Normalize the library name to lower case, the FS may be
        // case-sensitive
        char *name = strdup(buf_ptr(link_lib->name));
        assert(name != nullptr);
        for (char *ch = name; *ch; ++ch) *ch = tolower(*ch);

        Buf lib_path = BUF_INIT;
        err = find_mingw_lib_def(lj, name, &lib_path);

        if (err == ErrorFileNotFound) {
            zig_panic("link: could not find .def file to build %s\n", name);
        } else if (err != ErrorNone) {
            zig_panic("link: unable to check if .def file for %s exists: %s",
                      name, err_str(err));
        }

        lj->args.append(get_def_lib(g, name, &lib_path));

        mem::os::free(name);
    }
}

static void construct_linker_job_macho(LinkJob *lj) {
    CodeGen *g = lj->codegen;

    lj->args.append("-error-limit");
    lj->args.append("0");
    lj->args.append("-demangle");

    switch (g->linker_gc_sections) {
        case OptionalBoolNull:
            // TODO why do we not follow the same logic of elf here?
            break;
        case OptionalBoolTrue:
            lj->args.append("--gc-sections");
            break;
        case OptionalBoolFalse:
            break;
    }

    if (g->linker_rdynamic) {
        lj->args.append("-export_dynamic");
    }

    if (g->linker_optimization != nullptr) {
        lj->args.append(buf_ptr(g->linker_optimization));
    }

    if (g->linker_z_nodelete) {
        lj->args.append("-z");
        lj->args.append("nodelete");
    }
    if (g->linker_z_defs) {
        lj->args.append("-z");
        lj->args.append("defs");
    }

    bool is_lib = g->out_type == OutTypeLib;
    bool is_dyn_lib = g->is_dynamic && is_lib;
    if (is_lib && !g->is_dynamic) {
        lj->args.append("-static");
    } else {
        lj->args.append("-dynamic");
    }

    if (is_dyn_lib) {
        lj->args.append("-dylib");

        Buf *compat_vers = buf_sprintf("%" ZIG_PRI_usize ".0.0", g->version_major);
        lj->args.append("-compatibility_version");
        lj->args.append(buf_ptr(compat_vers));

        Buf *cur_vers = buf_sprintf("%" ZIG_PRI_usize ".%" ZIG_PRI_usize ".%" ZIG_PRI_usize,
            g->version_major, g->version_minor, g->version_patch);
        lj->args.append("-current_version");
        lj->args.append(buf_ptr(cur_vers));

        // TODO getting an error when running an executable when doing this rpath thing
        //Buf *dylib_install_name = buf_sprintf("@rpath/lib%s.%" ZIG_PRI_usize ".dylib",
        //    buf_ptr(g->root_out_name), g->version_major);
        //lj->args.append("-install_name");
        //lj->args.append(buf_ptr(dylib_install_name));

        assert(buf_len(&g->bin_file_output_path) != 0);
    }

    lj->args.append("-arch");
    lj->args.append(get_darwin_arch_string(g->zig_target));

    if (g->zig_target->glibc_or_darwin_version != nullptr) {
        if (g->zig_target->os == OsMacOSX) {
            lj->args.append("-macosx_version_min");
        } else if (g->zig_target->os == OsIOS) {
            if (g->zig_target->arch == ZigLLVM_x86 || g->zig_target->arch == ZigLLVM_x86_64) {
                lj->args.append("-ios_simulator_version_min");
            } else {
                lj->args.append("-iphoneos_version_min");
            }
        }

        Buf *version_string = buf_sprintf("%d.%d.%d",
            g->zig_target->glibc_or_darwin_version->major,
            g->zig_target->glibc_or_darwin_version->minor,
            g->zig_target->glibc_or_darwin_version->patch);
        lj->args.append(buf_ptr(version_string));

        lj->args.append("-sdk_version");
        lj->args.append(buf_ptr(version_string));
    } else if (stage2_is_zig0 && g->zig_target->os == OsMacOSX) {
        // running `zig0`; `-pie` requires versions >= 10.5; select 10.13
        lj->args.append("-macosx_version_min");
        lj->args.append("10.13");
        lj->args.append("-sdk_version");
        lj->args.append("10.13");
    }

    if (g->out_type == OutTypeExe) {
        lj->args.append("-pie");
    }

    lj->args.append("-o");
    lj->args.append(buf_ptr(&g->bin_file_output_path));

    for (size_t i = 0; i < g->rpath_list.length; i += 1) {
        Buf *rpath = g->rpath_list.at(i);
        add_rpath(lj, rpath);
    }
    if (is_dyn_lib) {
        add_rpath(lj, &g->bin_file_output_path);
    }

    if (is_dyn_lib) {
        if (g->system_linker_hack) {
            lj->args.append("-headerpad_max_install_names");
        }
    }

    for (size_t i = 0; i < g->lib_dirs.length; i += 1) {
        const char *lib_dir = g->lib_dirs.at(i);
        lj->args.append("-L");
        lj->args.append(lib_dir);
    }

    // .o files
    for (size_t i = 0; i < g->link_objects.length; i += 1) {
        lj->args.append((const char *)buf_ptr(g->link_objects.at(i)));
    }

    // compiler_rt on darwin is missing some stuff, so we still build it and rely on LinkOnce
    if (g->out_type == OutTypeExe || is_dyn_lib) {
        Buf *compiler_rt_o_path = build_compiler_rt(g, OutTypeLib, lj->build_dep_prog_node);
        lj->args.append(buf_ptr(compiler_rt_o_path));
    }

    // libraries
    for (size_t lib_i = 0; lib_i < g->link_libs_list.length; lib_i += 1) {
        LinkLib *link_lib = g->link_libs_list.at(lib_i);
        if (buf_eql_str(link_lib->name, "c")) {
            // libc is linked specially
            continue;
        }
        if (target_is_libcpp_lib_name(g->zig_target, buf_ptr(link_lib->name))) {
            // libc++ is linked specially
            continue;
        }
        if (g->zig_target->is_native_os && target_is_libc_lib_name(g->zig_target, buf_ptr(link_lib->name))) {
            // libSystem is linked specially
            continue;
        }

        Buf *arg;
        if (buf_starts_with_str(link_lib->name, "/") || buf_ends_with_str(link_lib->name, ".a") ||
            buf_ends_with_str(link_lib->name, ".dylib"))
        {
            arg = link_lib->name;
        } else {
            arg = buf_sprintf("-l%s", buf_ptr(link_lib->name));
        }
        lj->args.append(buf_ptr(arg));
    }

    // libc++ dep
    if (g->libcpp_link_lib != nullptr && g->out_type != OutTypeObj) {
        lj->args.append(build_libcxxabi(g, lj->build_dep_prog_node));
        lj->args.append(build_libcxx(g, lj->build_dep_prog_node));
    }

    // libc dep
    if (g->zig_target->is_native_os || stage2_is_zig0) {
        // on Darwin, libSystem has libc in it, but also you have to use it
        // to make syscalls because the syscall numbers are not documented
        // and change between versions.
        // so we always link against libSystem
        lj->args.append("-lSystem");
    }

    for (size_t i = 0; i < g->framework_dirs.length; i += 1) {
        const char *framework_dir = g->framework_dirs.at(i);
        lj->args.append("-F");
        lj->args.append(framework_dir);
    }

    for (size_t i = 0; i < g->darwin_frameworks.length; i += 1) {
        lj->args.append("-framework");
        lj->args.append(buf_ptr(g->darwin_frameworks.at(i)));
    }

    switch (g->linker_allow_shlib_undefined) {
        case OptionalBoolNull:
            if (!g->zig_target->is_native_os && !stage2_is_zig0) {
                // TODO https://github.com/ziglang/zig/issues/5059
                lj->args.append("-undefined");
                lj->args.append("dynamic_lookup");
            }
            break;
        case OptionalBoolFalse:
            break;
        case OptionalBoolTrue:
            lj->args.append("-undefined");
            lj->args.append("dynamic_lookup");
            break;
    }
    switch (g->linker_bind_global_refs_locally) {
        case OptionalBoolNull:
        case OptionalBoolFalse:
            break;
        case OptionalBoolTrue:
            lj->args.append("-Bsymbolic");
            break;
    }
}

static void construct_linker_job(LinkJob *lj) {
    switch (target_object_format(lj->codegen->zig_target)) {
        case ZigLLVM_UnknownObjectFormat:
        case ZigLLVM_XCOFF:
            zig_unreachable();

        case ZigLLVM_COFF:
            return construct_linker_job_coff(lj);
        case ZigLLVM_ELF:
            return construct_linker_job_elf(lj);
        case ZigLLVM_MachO:
            return construct_linker_job_macho(lj);
        case ZigLLVM_Wasm:
            return construct_linker_job_wasm(lj);
    }
}

void zig_link_add_compiler_rt(CodeGen *g, Stage2ProgressNode *progress_node) {
    Buf *compiler_rt_o_path = build_compiler_rt(g, OutTypeObj, progress_node);
    g->link_objects.append(compiler_rt_o_path);
}

void codegen_link(CodeGen *g) {
    codegen_add_time_event(g, "Build Dependencies");
    LinkJob lj = {0};

    {
        const char *progress_name = "Build Dependencies";
        codegen_switch_sub_prog_node(g, stage2_progress_start(g->main_progress_node,
                progress_name, strlen(progress_name), 0));
        lj.build_dep_prog_node = g->sub_progress_node;
    }


    // even though we're calling LLD as a library it thinks the first
    // argument is its own exe name
    lj.args.append("lld");

    lj.rpath_table.init(4);
    lj.codegen = g;

    if (g->out_type == OutTypeObj) {
        lj.args.append("-r");
    }

    if (g->out_type == OutTypeLib && !g->is_dynamic && !target_is_wasm(g->zig_target)) {
        ZigList<const char *> file_names = {};
        for (size_t i = 0; i < g->link_objects.length; i += 1) {
            file_names.append(buf_ptr(g->link_objects.at(i)));
        }
        ZigLLVM_OSType os_type = get_llvm_os_type(g->zig_target->os);
        codegen_add_time_event(g, "LLVM Link");
        {
            const char *progress_name = "Link";
            codegen_switch_sub_prog_node(g, stage2_progress_start(g->main_progress_node,
                    progress_name, strlen(progress_name), 0));
        }
        if (g->verbose_link) {
            fprintf(stderr, "ar rcs %s", buf_ptr(&g->bin_file_output_path));
            for (size_t i = 0; i < file_names.length; i += 1) {
                fprintf(stderr, " %s", file_names.at(i));
            }
            fprintf(stderr, "\n");
        }
        if (ZigLLVMWriteArchive(buf_ptr(&g->bin_file_output_path), file_names.items, file_names.length, os_type)) {
            fprintf(stderr, "Unable to write archive '%s'\n", buf_ptr(&g->bin_file_output_path));
            exit(1);
        }
        return;
    }

    lj.link_in_crt = (g->libc_link_lib != nullptr && g->out_type == OutTypeExe);

    construct_linker_job(&lj);

    if (g->verbose_link) {
        for (size_t i = 0; i < lj.args.length; i += 1) {
            const char *space = (i != 0) ? " " : "";
            fprintf(stderr, "%s%s", space, lj.args.at(i));
        }
        fprintf(stderr, "\n");
    }

    Buf diag = BUF_INIT;

    codegen_add_time_event(g, "LLVM Link");
    {
        const char *progress_name = "Link";
        codegen_switch_sub_prog_node(g, stage2_progress_start(g->main_progress_node,
                progress_name, strlen(progress_name), 0));
    }
    if (g->system_linker_hack && g->zig_target->os == OsMacOSX) {
        Termination term;
        ZigList<const char *> args = {};
        args.append("ld");
        for (size_t i = 1; i < lj.args.length; i += 1) {
            args.append(lj.args.at(i));
        }
        os_spawn_process(args, &term);
        if (term.how != TerminationIdClean || term.code != 0) {
            exit(1);
        }
    } else if (!zig_lld_link(target_object_format(g->zig_target), lj.args.items, lj.args.length, &diag)) {
        fprintf(stderr, "%s\n", buf_ptr(&diag));
        exit(1);
    }
}

