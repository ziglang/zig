#ifdef PTR64
#define WEAK64 .weak
#define PTR_SIZE_BYTES 8
#define PTR2_SIZE_BYTES 16
#else
#define WEAK64 .globl
#define PTR_SIZE_BYTES 4
#define PTR2_SIZE_BYTES 8
#endif
.bss
.weak ___environ
.type ___environ, %object;
.size ___environ, PTR_SIZE_BYTES
___environ:
.globl __daylight
.type __daylight, %object;
.size __daylight, 4
__daylight:
.globl __environ
.type __environ, %object;
.size __environ, PTR_SIZE_BYTES
__environ:
.globl __optpos
.type __optpos, %object;
.size __optpos, 4
__optpos:
.globl __optreset
.type __optreset, %object;
.size __optreset, 4
__optreset:
.globl __progname
.type __progname, %object;
.size __progname, PTR_SIZE_BYTES
__progname:
.globl __progname_full
.type __progname_full, %object;
.size __progname_full, PTR_SIZE_BYTES
__progname_full:
.globl __signgam
.type __signgam, %object;
.size __signgam, 4
__signgam:
.globl __stack_chk_guard
.type __stack_chk_guard, %object;
.size __stack_chk_guard, PTR_SIZE_BYTES
__stack_chk_guard:
.globl __timezone
.type __timezone, %object;
.size __timezone, PTR_SIZE_BYTES
__timezone:
.globl __tzname
.type __tzname, %object;
.size __tzname, PTR2_SIZE_BYTES
__tzname:
.weak _environ
.type _environ, %object;
.size _environ, PTR_SIZE_BYTES
_environ:
.weak daylight
.type daylight, %object;
.size daylight, 4
daylight:
.weak environ
.type environ, %object;
.size environ, PTR_SIZE_BYTES
environ:
.globl getdate_err
.type getdate_err, %object;
.size getdate_err, 4
getdate_err:
.globl h_errno
.type h_errno, %object;
.size h_errno, 4
h_errno:
.globl optarg
.type optarg, %object;
.size optarg, PTR_SIZE_BYTES
optarg:
.globl optopt
.type optopt, %object;
.size optopt, 4
optopt:
.weak optreset
.type optreset, %object;
.size optreset, 4
optreset:
.weak program_invocation_name
.type program_invocation_name, %object;
.size program_invocation_name, PTR_SIZE_BYTES
program_invocation_name:
.weak program_invocation_short_name
.type program_invocation_short_name, %object;
.size program_invocation_short_name, PTR_SIZE_BYTES
program_invocation_short_name:
.weak signgam
.type signgam, %object;
.size signgam, 4
signgam:
.weak timezone
.type timezone, %object;
.size timezone, PTR_SIZE_BYTES
timezone:
.weak tzname
.type tzname, %object;
.size tzname, PTR2_SIZE_BYTES
tzname:
.data
.globl _dl_debug_addr
.type _dl_debug_addr, %object;
.size _dl_debug_addr, PTR_SIZE_BYTES
_dl_debug_addr:
.globl opterr
.type opterr, %object;
.size opterr, 4
opterr:
.globl optind
.type optind, %object;
.size optind, 4
optind:
.data.rel.ro
.globl stderr
.type stderr, %object;
.size stderr, PTR_SIZE_BYTES
stderr:
.globl stdin
.type stdin, %object;
.size stdin, PTR_SIZE_BYTES
stdin:
.globl stdout
.type stdout, %object;
.size stdout, PTR_SIZE_BYTES
stdout:
.rodata
.globl _ns_flagdata
.type _ns_flagdata, %object;
.size _ns_flagdata, 128
_ns_flagdata:
.globl in6addr_any
.type in6addr_any, %object;
.size in6addr_any, 16
in6addr_any:
.globl in6addr_loopback
.type in6addr_loopback, %object;
.size in6addr_loopback, 16
in6addr_loopback:
.text
.globl _Exit
.type _Exit, %function;
_Exit:
.globl _Fork
.type _Fork, %function;
_Fork:
.weak _IO_feof_unlocked
.type _IO_feof_unlocked, %function;
_IO_feof_unlocked:
.weak _IO_ferror_unlocked
.type _IO_ferror_unlocked, %function;
_IO_ferror_unlocked:
.weak _IO_getc
.type _IO_getc, %function;
_IO_getc:
.weak _IO_getc_unlocked
.type _IO_getc_unlocked, %function;
_IO_getc_unlocked:
.weak _IO_putc
.type _IO_putc, %function;
_IO_putc:
.weak _IO_putc_unlocked
.type _IO_putc_unlocked, %function;
_IO_putc_unlocked:
#if !defined(ARCH_riscv64) && !defined(ARCH_mips) && !defined(ARCH_mips64) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.globl ___tls_get_addr
.type ___tls_get_addr, %function;
___tls_get_addr:
#endif
#ifdef PTR32
.globl __adjtime64
.type __adjtime64, %function;
__adjtime64:
.globl __adjtimex_time64
.type __adjtimex_time64, %function;
__adjtimex_time64:
.globl __aio_suspend_time64
.type __aio_suspend_time64, %function;
__aio_suspend_time64:
#endif
.globl __assert_fail
.type __assert_fail, %function;
__assert_fail:
#if !defined(ARCH_riscv64) && !defined(ARCH_x86) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.globl __cachectl
.type __cachectl, %function;
__cachectl:
#endif
#ifdef PTR32
.globl __clock_adjtime64
.type __clock_adjtime64, %function;
__clock_adjtime64:
.globl __clock_getres_time64
.type __clock_getres_time64, %function;
__clock_getres_time64:
.weak __clock_gettime64
.type __clock_gettime64, %function;
__clock_gettime64:
.weak __clock_nanosleep_time64
.type __clock_nanosleep_time64, %function;
__clock_nanosleep_time64:
.globl __clock_settime64
.type __clock_settime64, %function;
__clock_settime64:
.globl __cnd_timedwait_time64
.type __cnd_timedwait_time64, %function;
__cnd_timedwait_time64:
.globl __ctime64
.type __ctime64, %function;
__ctime64:
.globl __ctime64_r
.type __ctime64_r, %function;
__ctime64_r:
#endif
.globl __ctype_b_loc
.type __ctype_b_loc, %function;
__ctype_b_loc:
.globl __ctype_get_mb_cur_max
.type __ctype_get_mb_cur_max, %function;
__ctype_get_mb_cur_max:
.globl __ctype_tolower_loc
.type __ctype_tolower_loc, %function;
__ctype_tolower_loc:
.globl __ctype_toupper_loc
.type __ctype_toupper_loc, %function;
__ctype_toupper_loc:
.globl __cxa_atexit
.type __cxa_atexit, %function;
__cxa_atexit:
.globl __cxa_finalize
.type __cxa_finalize, %function;
__cxa_finalize:
#ifdef PTR32
.globl __difftime64
.type __difftime64, %function;
__difftime64:
#endif
.globl __dls2b
.type __dls2b, %function;
__dls2b:
.globl __dls3
.type __dls3, %function;
__dls3:
#ifdef PTR32
.globl __dlsym_time64
.type __dlsym_time64, %function;
__dlsym_time64:
#endif
.globl __duplocale
.type __duplocale, %function;
__duplocale:
.globl __errno_location
.type __errno_location, %function;
__errno_location:
.globl __fbufsize
.type __fbufsize, %function;
__fbufsize:
.globl __fgetwc_unlocked
.type __fgetwc_unlocked, %function;
__fgetwc_unlocked:
.globl __flbf
.type __flbf, %function;
__flbf:
.globl __flt_rounds
.type __flt_rounds, %function;
__flt_rounds:
.globl __fpclassify
.type __fpclassify, %function;
__fpclassify:
.globl __fpclassifyf
.type __fpclassifyf, %function;
__fpclassifyf:
.globl __fpclassifyl
.type __fpclassifyl, %function;
__fpclassifyl:
.globl __fpending
.type __fpending, %function;
__fpending:
.globl __fpurge
.type __fpurge, %function;
__fpurge:
.globl __fputwc_unlocked
.type __fputwc_unlocked, %function;
__fputwc_unlocked:
.globl __freadable
.type __freadable, %function;
__freadable:
.globl __freadahead
.type __freadahead, %function;
__freadahead:
.globl __freading
.type __freading, %function;
__freading:
.globl __freadptr
.type __freadptr, %function;
__freadptr:
.globl __freadptrinc
.type __freadptrinc, %function;
__freadptrinc:
.weak __freelocale
.type __freelocale, %function;
__freelocale:
.globl __fseterr
.type __fseterr, %function;
__fseterr:
.globl __fsetlocking
.type __fsetlocking, %function;
__fsetlocking:
#ifdef PTR32
.weak __fstat_time64
.type __fstat_time64, %function;
__fstat_time64:
.weak __fstatat_time64
.type __fstatat_time64, %function;
__fstatat_time64:
.globl __ftime64
.type __ftime64, %function;
__ftime64:
.globl __futimens_time64
.type __futimens_time64, %function;
__futimens_time64:
.globl __futimes_time64
.type __futimes_time64, %function;
__futimes_time64:
.weak __futimesat_time64
.type __futimesat_time64, %function;
__futimesat_time64:
#endif
.globl __fwritable
.type __fwritable, %function;
__fwritable:
.globl __fwriting
.type __fwriting, %function;
__fwriting:
.globl __fxstat
.type __fxstat, %function;
__fxstat:
.globl __fxstatat
.type __fxstatat, %function;
__fxstatat:
.weak __getdelim
.type __getdelim, %function;
__getdelim:
#ifdef PTR32
.globl __getitimer_time64
.type __getitimer_time64, %function;
__getitimer_time64:
.globl __getrusage_time64
.type __getrusage_time64, %function;
__getrusage_time64:
.globl __gettimeofday_time64
.type __gettimeofday_time64, %function;
__gettimeofday_time64:
.globl __gmtime64
.type __gmtime64, %function;
__gmtime64:
.weak __gmtime64_r
.type __gmtime64_r, %function;
__gmtime64_r:
#endif
.globl __h_errno_location
.type __h_errno_location, %function;
__h_errno_location:
.globl __isalnum_l
.type __isalnum_l, %function;
__isalnum_l:
.globl __isalpha_l
.type __isalpha_l, %function;
__isalpha_l:
.globl __isblank_l
.type __isblank_l, %function;
__isblank_l:
.globl __iscntrl_l
.type __iscntrl_l, %function;
__iscntrl_l:
.globl __isdigit_l
.type __isdigit_l, %function;
__isdigit_l:
.globl __isgraph_l
.type __isgraph_l, %function;
__isgraph_l:
.globl __islower_l
.type __islower_l, %function;
__islower_l:
.weak __isoc99_fscanf
.type __isoc99_fscanf, %function;
__isoc99_fscanf:
.weak __isoc99_fwscanf
.type __isoc99_fwscanf, %function;
__isoc99_fwscanf:
.weak __isoc99_scanf
.type __isoc99_scanf, %function;
__isoc99_scanf:
.weak __isoc99_sscanf
.type __isoc99_sscanf, %function;
__isoc99_sscanf:
.weak __isoc99_swscanf
.type __isoc99_swscanf, %function;
__isoc99_swscanf:
.weak __isoc99_vfscanf
.type __isoc99_vfscanf, %function;
__isoc99_vfscanf:
.weak __isoc99_vfwscanf
.type __isoc99_vfwscanf, %function;
__isoc99_vfwscanf:
.weak __isoc99_vscanf
.type __isoc99_vscanf, %function;
__isoc99_vscanf:
.weak __isoc99_vsscanf
.type __isoc99_vsscanf, %function;
__isoc99_vsscanf:
.weak __isoc99_vswscanf
.type __isoc99_vswscanf, %function;
__isoc99_vswscanf:
.weak __isoc99_vwscanf
.type __isoc99_vwscanf, %function;
__isoc99_vwscanf:
.weak __isoc99_wscanf
.type __isoc99_wscanf, %function;
__isoc99_wscanf:
.globl __isprint_l
.type __isprint_l, %function;
__isprint_l:
.globl __ispunct_l
.type __ispunct_l, %function;
__ispunct_l:
.globl __isspace_l
.type __isspace_l, %function;
__isspace_l:
.globl __isupper_l
.type __isupper_l, %function;
__isupper_l:
.globl __iswalnum_l
.type __iswalnum_l, %function;
__iswalnum_l:
.globl __iswalpha_l
.type __iswalpha_l, %function;
__iswalpha_l:
.globl __iswblank_l
.type __iswblank_l, %function;
__iswblank_l:
.globl __iswcntrl_l
.type __iswcntrl_l, %function;
__iswcntrl_l:
.globl __iswctype_l
.type __iswctype_l, %function;
__iswctype_l:
.globl __iswdigit_l
.type __iswdigit_l, %function;
__iswdigit_l:
.globl __iswgraph_l
.type __iswgraph_l, %function;
__iswgraph_l:
.globl __iswlower_l
.type __iswlower_l, %function;
__iswlower_l:
.globl __iswprint_l
.type __iswprint_l, %function;
__iswprint_l:
.globl __iswpunct_l
.type __iswpunct_l, %function;
__iswpunct_l:
.globl __iswspace_l
.type __iswspace_l, %function;
__iswspace_l:
.globl __iswupper_l
.type __iswupper_l, %function;
__iswupper_l:
.globl __iswxdigit_l
.type __iswxdigit_l, %function;
__iswxdigit_l:
.globl __isxdigit_l
.type __isxdigit_l, %function;
__isxdigit_l:
.globl __lgammal_r
.type __lgammal_r, %function;
__lgammal_r:
.globl __libc_current_sigrtmax
.type __libc_current_sigrtmax, %function;
__libc_current_sigrtmax:
.globl __libc_current_sigrtmin
.type __libc_current_sigrtmin, %function;
__libc_current_sigrtmin:
.globl __libc_start_main
.type __libc_start_main, %function;
__libc_start_main:
#ifdef PTR32
.globl __localtime64
.type __localtime64, %function;
__localtime64:
.weak __localtime64_r
.type __localtime64_r, %function;
__localtime64_r:
#endif
#if !defined(ARCH_mips) && !defined(ARCH_mips64) && !defined(ARCH_x86) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_loongarch64)
.globl __longjmp
.type __longjmp, %function;
__longjmp:
#endif
#ifdef PTR32
.globl __lstat_time64
.type __lstat_time64, %function;
__lstat_time64:
.globl __lutimes_time64
.type __lutimes_time64, %function;
__lutimes_time64:
#endif
.globl __lxstat
.type __lxstat, %function;
__lxstat:
#ifdef PTR32
.globl __mktime64
.type __mktime64, %function;
__mktime64:
.globl __mq_timedreceive_time64
.type __mq_timedreceive_time64, %function;
__mq_timedreceive_time64:
.globl __mq_timedsend_time64
.type __mq_timedsend_time64, %function;
__mq_timedsend_time64:
.globl __mtx_timedlock_time64
.type __mtx_timedlock_time64, %function;
__mtx_timedlock_time64:
.globl __nanosleep_time64
.type __nanosleep_time64, %function;
__nanosleep_time64:
#endif
.globl __newlocale
.type __newlocale, %function;
__newlocale:
.globl __nl_langinfo
.type __nl_langinfo, %function;
__nl_langinfo:
.globl __nl_langinfo_l
.type __nl_langinfo_l, %function;
__nl_langinfo_l:
.globl __overflow
.type __overflow, %function;
.protected __overflow
__overflow:
.weak __posix_getopt
.type __posix_getopt, %function;
__posix_getopt:
#ifdef PTR32
.globl __ppoll_time64
.type __ppoll_time64, %function;
__ppoll_time64:
.globl __pselect_time64
.type __pselect_time64, %function;
__pselect_time64:
.weak __pthread_cond_timedwait_time64
.type __pthread_cond_timedwait_time64, %function;
__pthread_cond_timedwait_time64:
.weak __pthread_mutex_timedlock_time64
.type __pthread_mutex_timedlock_time64, %function;
__pthread_mutex_timedlock_time64:
.weak __pthread_rwlock_timedrdlock_time64
.type __pthread_rwlock_timedrdlock_time64, %function;
__pthread_rwlock_timedrdlock_time64:
.weak __pthread_rwlock_timedwrlock_time64
.type __pthread_rwlock_timedwrlock_time64, %function;
__pthread_rwlock_timedwrlock_time64:
.weak __pthread_timedjoin_np_time64
.type __pthread_timedjoin_np_time64, %function;
__pthread_timedjoin_np_time64:
.globl __recvmmsg_time64
.type __recvmmsg_time64, %function;
__recvmmsg_time64:
#endif
.globl __res_state
.type __res_state, %function;
__res_state:
#if !defined(ARCH_mips) && !defined(ARCH_mips64) && !defined(ARCH_x86) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.globl __restore
.type __restore, %function;
__restore:
#endif
#if !defined(ARCH_mips) && !defined(ARCH_mips64) && !defined(ARCH_x86) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.globl __restore_rt
.type __restore_rt, %function;
__restore_rt:
#endif
#if !defined(ARCH_mips) && !defined(ARCH_mips64) && !defined(ARCH_x86) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_loongarch64)
.globl __riscv_flush_icache
.type __riscv_flush_icache, %function;
__riscv_flush_icache:
#endif
.globl __sched_cpucount
.type __sched_cpucount, %function;
__sched_cpucount:
#ifdef PTR32
.globl __sched_rr_get_interval_time64
.type __sched_rr_get_interval_time64, %function;
__sched_rr_get_interval_time64:
.globl __select_time64
.type __select_time64, %function;
__select_time64:
.globl __sem_timedwait_time64
.type __sem_timedwait_time64, %function;
__sem_timedwait_time64:
.globl __semtimedop_time64
.type __semtimedop_time64, %function;
__semtimedop_time64:
.globl __setitimer_time64
.type __setitimer_time64, %function;
__setitimer_time64:
#endif
.globl __setjmp
.type __setjmp, %function;
__setjmp:
#ifdef PTR32
.globl __settimeofday_time64
.type __settimeofday_time64, %function;
__settimeofday_time64:
#endif
.globl __signbit
.type __signbit, %function;
__signbit:
.globl __signbitf
.type __signbitf, %function;
__signbitf:
.globl __signbitl
.type __signbitl, %function;
__signbitl:
.globl __sigsetjmp
.type __sigsetjmp, %function;
__sigsetjmp:
#ifdef PTR32
.globl __sigtimedwait_time64
.type __sigtimedwait_time64, %function;
__sigtimedwait_time64:
#endif
.globl __stack_chk_fail
.type __stack_chk_fail, %function;
__stack_chk_fail:
#ifdef PTR32
.globl __stat_time64
.type __stat_time64, %function;
__stat_time64:
.globl __stime64
.type __stime64, %function;
__stime64:
#endif
.globl __strcasecmp_l
.type __strcasecmp_l, %function;
__strcasecmp_l:
.globl __strcoll_l
.type __strcoll_l, %function;
__strcoll_l:
.globl __strerror_l
.type __strerror_l, %function;
__strerror_l:
.globl __strncasecmp_l
.type __strncasecmp_l, %function;
__strncasecmp_l:
.weak __strtod_l
.type __strtod_l, %function;
__strtod_l:
.weak __strtof_l
.type __strtof_l, %function;
__strtof_l:
.weak __strtoimax_internal
.type __strtoimax_internal, %function;
__strtoimax_internal:
.weak __strtol_internal
.type __strtol_internal, %function;
__strtol_internal:
.weak __strtold_l
.type __strtold_l, %function;
__strtold_l:
.weak __strtoll_internal
.type __strtoll_internal, %function;
__strtoll_internal:
.weak __strtoul_internal
.type __strtoul_internal, %function;
__strtoul_internal:
.weak __strtoull_internal
.type __strtoull_internal, %function;
__strtoull_internal:
.weak __strtoumax_internal
.type __strtoumax_internal, %function;
__strtoumax_internal:
.globl __strxfrm_l
.type __strxfrm_l, %function;
__strxfrm_l:
.weak __sysv_signal
.type __sysv_signal, %function;
__sysv_signal:
#ifdef PTR32
.globl __thrd_sleep_time64
.type __thrd_sleep_time64, %function;
__thrd_sleep_time64:
.globl __time64
.type __time64, %function;
__time64:
.globl __timegm_time64
.type __timegm_time64, %function;
__timegm_time64:
.globl __timer_gettime64
.type __timer_gettime64, %function;
__timer_gettime64:
.globl __timer_settime64
.type __timer_settime64, %function;
__timer_settime64:
.globl __timerfd_gettime64
.type __timerfd_gettime64, %function;
__timerfd_gettime64:
.globl __timerfd_settime64
.type __timerfd_settime64, %function;
__timerfd_settime64:
.globl __timespec_get_time64
.type __timespec_get_time64, %function;
__timespec_get_time64:
#endif
.globl __tls_get_addr
.type __tls_get_addr, %function;
__tls_get_addr:
.globl __tolower_l
.type __tolower_l, %function;
__tolower_l:
.globl __toupper_l
.type __toupper_l, %function;
__toupper_l:
.globl __towctrans_l
.type __towctrans_l, %function;
__towctrans_l:
.globl __towlower_l
.type __towlower_l, %function;
__towlower_l:
.globl __towupper_l
.type __towupper_l, %function;
__towupper_l:
.globl __uflow
.type __uflow, %function;
.protected __uflow
__uflow:
.globl __uselocale
.type __uselocale, %function;
__uselocale:
#ifdef PTR32
.globl __utime64
.type __utime64, %function;
__utime64:
.globl __utimensat_time64
.type __utimensat_time64, %function;
__utimensat_time64:
.globl __utimes_time64
.type __utimes_time64, %function;
__utimes_time64:
.globl __wait3_time64
.type __wait3_time64, %function;
__wait3_time64:
.globl __wait4_time64
.type __wait4_time64, %function;
__wait4_time64:
#endif
.globl __wcscoll_l
.type __wcscoll_l, %function;
__wcscoll_l:
.globl __wcsftime_l
.type __wcsftime_l, %function;
__wcsftime_l:
.globl __wcsxfrm_l
.type __wcsxfrm_l, %function;
__wcsxfrm_l:
.globl __wctrans_l
.type __wctrans_l, %function;
__wctrans_l:
.globl __wctype_l
.type __wctype_l, %function;
__wctype_l:
.globl __xmknod
.type __xmknod, %function;
__xmknod:
.globl __xmknodat
.type __xmknodat, %function;
__xmknodat:
.weak __xpg_basename
.type __xpg_basename, %function;
__xpg_basename:
.weak __xpg_strerror_r
.type __xpg_strerror_r, %function;
__xpg_strerror_r:
.globl __xstat
.type __xstat, %function;
__xstat:
.weak _dl_debug_state
.type _dl_debug_state, %function;
_dl_debug_state:
.globl _dlstart
.type _dlstart, %function;
_dlstart:
#if !defined(ARCH_riscv64) && !defined(ARCH_mips) && !defined(ARCH_x86) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.globl _dlstart_data
.type _dlstart_data, %function;
_dlstart_data:
#endif
.globl _exit
.type _exit, %function;
_exit:
.weak _fini
.type _fini, %function;
_fini:
#if !defined(ARCH_riscv64) && !defined(ARCH_x86) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.globl _flush_cache
.type _flush_cache, %function;
_flush_cache:
#endif
.globl _flushlbf
.type _flushlbf, %function;
_flushlbf:
.weak _init
.type _init, %function;
_init:
.globl _longjmp
.type _longjmp, %function;
_longjmp:
.globl _pthread_cleanup_pop
.type _pthread_cleanup_pop, %function;
_pthread_cleanup_pop:
.globl _pthread_cleanup_push
.type _pthread_cleanup_push, %function;
_pthread_cleanup_push:
.globl _setjmp
.type _setjmp, %function;
_setjmp:
.globl a64l
.type a64l, %function;
a64l:
.globl abort
.type abort, %function;
abort:
.globl abs
.type abs, %function;
abs:
.globl accept
.type accept, %function;
accept:
.globl accept4
.type accept4, %function;
accept4:
.globl access
.type access, %function;
access:
.globl acct
.type acct, %function;
acct:
.globl acos
.type acos, %function;
acos:
.globl acosf
.type acosf, %function;
acosf:
.globl acosh
.type acosh, %function;
acosh:
.globl acoshf
.type acoshf, %function;
acoshf:
.globl acoshl
.type acoshl, %function;
acoshl:
.globl acosl
.type acosl, %function;
acosl:
.globl addmntent
.type addmntent, %function;
addmntent:
.globl adjtime
.type adjtime, %function;
adjtime:
.globl adjtimex
.type adjtimex, %function;
adjtimex:
.globl aio_cancel
.type aio_cancel, %function;
aio_cancel:
.globl aio_error
.type aio_error, %function;
aio_error:
.globl aio_fsync
.type aio_fsync, %function;
aio_fsync:
.globl aio_read
.type aio_read, %function;
aio_read:
.globl aio_return
.type aio_return, %function;
aio_return:
.globl aio_suspend
.type aio_suspend, %function;
aio_suspend:
.globl aio_write
.type aio_write, %function;
aio_write:
.globl alarm
.type alarm, %function;
alarm:
.globl aligned_alloc
.type aligned_alloc, %function;
aligned_alloc:
.globl alphasort
.type alphasort, %function;
alphasort:
#if !defined(ARCH_riscv64) && !defined(ARCH_mips) && !defined(ARCH_mips64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.globl arch_prctl
.type arch_prctl, %function;
arch_prctl:
#endif
.globl asctime
.type asctime, %function;
asctime:
.weak asctime_r
.type asctime_r, %function;
asctime_r:
.globl asin
.type asin, %function;
asin:
.globl asinf
.type asinf, %function;
asinf:
.globl asinh
.type asinh, %function;
asinh:
.globl asinhf
.type asinhf, %function;
asinhf:
.globl asinhl
.type asinhl, %function;
asinhl:
.globl asinl
.type asinl, %function;
asinl:
.globl asprintf
.type asprintf, %function;
asprintf:
.globl at_quick_exit
.type at_quick_exit, %function;
at_quick_exit:
.globl atan
.type atan, %function;
atan:
.globl atan2
.type atan2, %function;
atan2:
.globl atan2f
.type atan2f, %function;
atan2f:
.globl atan2l
.type atan2l, %function;
atan2l:
.globl atanf
.type atanf, %function;
atanf:
.globl atanh
.type atanh, %function;
atanh:
.globl atanhf
.type atanhf, %function;
atanhf:
.globl atanhl
.type atanhl, %function;
atanhl:
.globl atanl
.type atanl, %function;
atanl:
.globl atexit
.type atexit, %function;
atexit:
.globl atof
.type atof, %function;
atof:
.globl atoi
.type atoi, %function;
atoi:
.globl atol
.type atol, %function;
atol:
.globl atoll
.type atoll, %function;
atoll:
.globl basename
.type basename, %function;
basename:
.globl bcmp
.type bcmp, %function;
bcmp:
.globl bcopy
.type bcopy, %function;
bcopy:
.globl bind
.type bind, %function;
bind:
.globl bind_textdomain_codeset
.type bind_textdomain_codeset, %function;
bind_textdomain_codeset:
.globl bindtextdomain
.type bindtextdomain, %function;
bindtextdomain:
.globl brk
.type brk, %function;
brk:
.weak bsd_signal
.type bsd_signal, %function;
bsd_signal:
.globl bsearch
.type bsearch, %function;
bsearch:
.globl btowc
.type btowc, %function;
btowc:
.globl bzero
.type bzero, %function;
bzero:
.globl c16rtomb
.type c16rtomb, %function;
c16rtomb:
.globl c32rtomb
.type c32rtomb, %function;
c32rtomb:
.globl cabs
.type cabs, %function;
cabs:
.globl cabsf
.type cabsf, %function;
cabsf:
.globl cabsl
.type cabsl, %function;
cabsl:
#if !defined(ARCH_riscv64) && !defined(ARCH_x86) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.weak cachectl
.type cachectl, %function;
cachectl:
#endif
#if !defined(ARCH_riscv64) && !defined(ARCH_x86) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.weak cacheflush
.type cacheflush, %function;
cacheflush:
#endif
.globl cacos
.type cacos, %function;
cacos:
.globl cacosf
.type cacosf, %function;
cacosf:
.globl cacosh
.type cacosh, %function;
cacosh:
.globl cacoshf
.type cacoshf, %function;
cacoshf:
.globl cacoshl
.type cacoshl, %function;
cacoshl:
.globl cacosl
.type cacosl, %function;
cacosl:
.globl call_once
.type call_once, %function;
call_once:
.globl calloc
.type calloc, %function;
calloc:
.globl capget
.type capget, %function;
capget:
.globl capset
.type capset, %function;
capset:
.globl carg
.type carg, %function;
carg:
.globl cargf
.type cargf, %function;
cargf:
.globl cargl
.type cargl, %function;
cargl:
.globl casin
.type casin, %function;
casin:
.globl casinf
.type casinf, %function;
casinf:
.globl casinh
.type casinh, %function;
casinh:
.globl casinhf
.type casinhf, %function;
casinhf:
.globl casinhl
.type casinhl, %function;
casinhl:
.globl casinl
.type casinl, %function;
casinl:
.globl catan
.type catan, %function;
catan:
.globl catanf
.type catanf, %function;
catanf:
.globl catanh
.type catanh, %function;
catanh:
.globl catanhf
.type catanhf, %function;
catanhf:
.globl catanhl
.type catanhl, %function;
catanhl:
.globl catanl
.type catanl, %function;
catanl:
.globl catclose
.type catclose, %function;
catclose:
.globl catgets
.type catgets, %function;
catgets:
.globl catopen
.type catopen, %function;
catopen:
.globl cbrt
.type cbrt, %function;
cbrt:
.globl cbrtf
.type cbrtf, %function;
cbrtf:
.globl cbrtl
.type cbrtl, %function;
cbrtl:
.globl ccos
.type ccos, %function;
ccos:
.globl ccosf
.type ccosf, %function;
ccosf:
.globl ccosh
.type ccosh, %function;
ccosh:
.globl ccoshf
.type ccoshf, %function;
ccoshf:
.globl ccoshl
.type ccoshl, %function;
ccoshl:
.globl ccosl
.type ccosl, %function;
ccosl:
.globl ceil
.type ceil, %function;
ceil:
.globl ceilf
.type ceilf, %function;
ceilf:
.globl ceill
.type ceill, %function;
ceill:
.globl cexp
.type cexp, %function;
cexp:
.globl cexpf
.type cexpf, %function;
cexpf:
.globl cexpl
.type cexpl, %function;
cexpl:
.globl cfgetispeed
.type cfgetispeed, %function;
cfgetispeed:
.globl cfgetospeed
.type cfgetospeed, %function;
cfgetospeed:
.globl cfmakeraw
.type cfmakeraw, %function;
cfmakeraw:
.globl cfsetispeed
.type cfsetispeed, %function;
cfsetispeed:
.globl cfsetospeed
.type cfsetospeed, %function;
cfsetospeed:
.weak cfsetspeed
.type cfsetspeed, %function;
cfsetspeed:
.globl chdir
.type chdir, %function;
chdir:
.globl chmod
.type chmod, %function;
chmod:
.globl chown
.type chown, %function;
chown:
.globl chroot
.type chroot, %function;
chroot:
.globl cimag
.type cimag, %function;
cimag:
.globl cimagf
.type cimagf, %function;
cimagf:
.globl cimagl
.type cimagl, %function;
cimagl:
.globl clearenv
.type clearenv, %function;
clearenv:
.globl clearerr
.type clearerr, %function;
clearerr:
.weak clearerr_unlocked
.type clearerr_unlocked, %function;
clearerr_unlocked:
.globl clock
.type clock, %function;
clock:
.globl clock_adjtime
.type clock_adjtime, %function;
clock_adjtime:
.globl clock_getcpuclockid
.type clock_getcpuclockid, %function;
clock_getcpuclockid:
.globl clock_getres
.type clock_getres, %function;
clock_getres:
WEAK64 clock_gettime
.type clock_gettime, %function;
clock_gettime:
WEAK64 clock_nanosleep
.type clock_nanosleep, %function;
clock_nanosleep:
.globl clock_settime
.type clock_settime, %function;
clock_settime:
.globl clog
.type clog, %function;
clog:
.globl clogf
.type clogf, %function;
clogf:
.globl clogl
.type clogl, %function;
clogl:
.globl clone
.type clone, %function;
clone:
.globl close
.type close, %function;
close:
.globl closedir
.type closedir, %function;
closedir:
.globl closelog
.type closelog, %function;
closelog:
.globl cnd_broadcast
.type cnd_broadcast, %function;
cnd_broadcast:
.globl cnd_destroy
.type cnd_destroy, %function;
cnd_destroy:
.globl cnd_init
.type cnd_init, %function;
cnd_init:
.globl cnd_signal
.type cnd_signal, %function;
cnd_signal:
.globl cnd_timedwait
.type cnd_timedwait, %function;
cnd_timedwait:
.globl cnd_wait
.type cnd_wait, %function;
cnd_wait:
.globl confstr
.type confstr, %function;
confstr:
.globl conj
.type conj, %function;
conj:
.globl conjf
.type conjf, %function;
conjf:
.globl conjl
.type conjl, %function;
conjl:
.globl connect
.type connect, %function;
connect:
.globl copy_file_range
.type copy_file_range, %function;
copy_file_range:
.globl copysign
.type copysign, %function;
copysign:
.globl copysignf
.type copysignf, %function;
copysignf:
.globl copysignl
.type copysignl, %function;
copysignl:
.globl cos
.type cos, %function;
cos:
.globl cosf
.type cosf, %function;
cosf:
.globl cosh
.type cosh, %function;
cosh:
.globl coshf
.type coshf, %function;
coshf:
.globl coshl
.type coshl, %function;
coshl:
.globl cosl
.type cosl, %function;
cosl:
.globl cpow
.type cpow, %function;
cpow:
.globl cpowf
.type cpowf, %function;
cpowf:
.globl cpowl
.type cpowl, %function;
cpowl:
.globl cproj
.type cproj, %function;
cproj:
.globl cprojf
.type cprojf, %function;
cprojf:
.globl cprojl
.type cprojl, %function;
cprojl:
.globl creal
.type creal, %function;
creal:
.globl crealf
.type crealf, %function;
crealf:
.globl creall
.type creall, %function;
creall:
.globl creat
.type creat, %function;
creat:
.globl crypt
.type crypt, %function;
crypt:
.weak crypt_r
.type crypt_r, %function;
crypt_r:
.globl csin
.type csin, %function;
csin:
.globl csinf
.type csinf, %function;
csinf:
.globl csinh
.type csinh, %function;
csinh:
.globl csinhf
.type csinhf, %function;
csinhf:
.globl csinhl
.type csinhl, %function;
csinhl:
.globl csinl
.type csinl, %function;
csinl:
.globl csqrt
.type csqrt, %function;
csqrt:
.globl csqrtf
.type csqrtf, %function;
csqrtf:
.globl csqrtl
.type csqrtl, %function;
csqrtl:
.globl ctan
.type ctan, %function;
ctan:
.globl ctanf
.type ctanf, %function;
ctanf:
.globl ctanh
.type ctanh, %function;
ctanh:
.globl ctanhf
.type ctanhf, %function;
ctanhf:
.globl ctanhl
.type ctanhl, %function;
ctanhl:
.globl ctanl
.type ctanl, %function;
ctanl:
.globl ctermid
.type ctermid, %function;
ctermid:
.globl ctime
.type ctime, %function;
ctime:
.globl ctime_r
.type ctime_r, %function;
ctime_r:
.globl cuserid
.type cuserid, %function;
cuserid:
.globl daemon
.type daemon, %function;
daemon:
.globl dcgettext
.type dcgettext, %function;
dcgettext:
.globl dcngettext
.type dcngettext, %function;
dcngettext:
.globl delete_module
.type delete_module, %function;
delete_module:
.globl dgettext
.type dgettext, %function;
dgettext:
.globl difftime
.type difftime, %function;
difftime:
.globl dirfd
.type dirfd, %function;
dirfd:
.globl dirname
.type dirname, %function;
dirname:
.globl div
.type div, %function;
div:
.globl dl_iterate_phdr
.type dl_iterate_phdr, %function;
dl_iterate_phdr:
.globl dladdr
.type dladdr, %function;
dladdr:
.globl dlclose
.type dlclose, %function;
dlclose:
.globl dlerror
.type dlerror, %function;
dlerror:
.globl dlinfo
.type dlinfo, %function;
dlinfo:
.globl dlopen
.type dlopen, %function;
dlopen:
.globl dlsym
.type dlsym, %function;
dlsym:
.globl dn_comp
.type dn_comp, %function;
dn_comp:
.weak dn_expand
.type dn_expand, %function;
dn_expand:
.globl dn_skipname
.type dn_skipname, %function;
dn_skipname:
.globl dngettext
.type dngettext, %function;
dngettext:
.globl dprintf
.type dprintf, %function;
dprintf:
.globl drand48
.type drand48, %function;
drand48:
.weak drem
.type drem, %function;
drem:
.weak dremf
.type dremf, %function;
dremf:
.globl dup
.type dup, %function;
dup:
.globl dup2
.type dup2, %function;
dup2:
.weak dup3
.type dup3, %function;
dup3:
.weak duplocale
.type duplocale, %function;
duplocale:
.weak eaccess
.type eaccess, %function;
eaccess:
.globl ecvt
.type ecvt, %function;
ecvt:
.globl encrypt
.type encrypt, %function;
encrypt:
.weak endgrent
.type endgrent, %function;
endgrent:
.globl endhostent
.type endhostent, %function;
endhostent:
.globl endmntent
.type endmntent, %function;
endmntent:
.weak endnetent
.type endnetent, %function;
endnetent:
.globl endprotoent
.type endprotoent, %function;
endprotoent:
.weak endpwent
.type endpwent, %function;
endpwent:
.globl endservent
.type endservent, %function;
endservent:
.globl endspent
.type endspent, %function;
endspent:
.globl endusershell
.type endusershell, %function;
endusershell:
.weak endutent
.type endutent, %function;
endutent:
.globl endutxent
.type endutxent, %function;
endutxent:
.globl epoll_create
.type epoll_create, %function;
epoll_create:
.globl epoll_create1
.type epoll_create1, %function;
epoll_create1:
.globl epoll_ctl
.type epoll_ctl, %function;
epoll_ctl:
.globl epoll_pwait
.type epoll_pwait, %function;
epoll_pwait:
.globl epoll_wait
.type epoll_wait, %function;
epoll_wait:
.globl erand48
.type erand48, %function;
erand48:
.globl erf
.type erf, %function;
erf:
.globl erfc
.type erfc, %function;
erfc:
.globl erfcf
.type erfcf, %function;
erfcf:
.globl erfcl
.type erfcl, %function;
erfcl:
.globl erff
.type erff, %function;
erff:
.globl erfl
.type erfl, %function;
erfl:
.globl err
.type err, %function;
err:
.globl errx
.type errx, %function;
errx:
.globl ether_aton
.type ether_aton, %function;
ether_aton:
.globl ether_aton_r
.type ether_aton_r, %function;
ether_aton_r:
.globl ether_hostton
.type ether_hostton, %function;
ether_hostton:
.globl ether_line
.type ether_line, %function;
ether_line:
.globl ether_ntoa
.type ether_ntoa, %function;
ether_ntoa:
.globl ether_ntoa_r
.type ether_ntoa_r, %function;
ether_ntoa_r:
.globl ether_ntohost
.type ether_ntohost, %function;
ether_ntohost:
.globl euidaccess
.type euidaccess, %function;
euidaccess:
.globl eventfd
.type eventfd, %function;
eventfd:
.globl eventfd_read
.type eventfd_read, %function;
eventfd_read:
.globl eventfd_write
.type eventfd_write, %function;
eventfd_write:
.globl execl
.type execl, %function;
execl:
.globl execle
.type execle, %function;
execle:
.globl execlp
.type execlp, %function;
execlp:
.globl execv
.type execv, %function;
execv:
.globl execve
.type execve, %function;
execve:
.globl execvp
.type execvp, %function;
execvp:
.weak execvpe
.type execvpe, %function;
execvpe:
.globl exit
.type exit, %function;
exit:
.globl exp
.type exp, %function;
exp:
.globl exp10
.type exp10, %function;
exp10:
.globl exp10f
.type exp10f, %function;
exp10f:
.globl exp10l
.type exp10l, %function;
exp10l:
.globl exp2
.type exp2, %function;
exp2:
.globl exp2f
.type exp2f, %function;
exp2f:
.globl exp2l
.type exp2l, %function;
exp2l:
.globl expf
.type expf, %function;
expf:
.globl expl
.type expl, %function;
expl:
.globl explicit_bzero
.type explicit_bzero, %function;
explicit_bzero:
.globl expm1
.type expm1, %function;
expm1:
.globl expm1f
.type expm1f, %function;
expm1f:
.globl expm1l
.type expm1l, %function;
expm1l:
.globl fabs
.type fabs, %function;
fabs:
.globl fabsf
.type fabsf, %function;
fabsf:
.globl fabsl
.type fabsl, %function;
fabsl:
.globl faccessat
.type faccessat, %function;
faccessat:
.globl fallocate
.type fallocate, %function;
fallocate:
.globl fanotify_init
.type fanotify_init, %function;
fanotify_init:
.globl fanotify_mark
.type fanotify_mark, %function;
fanotify_mark:
.globl fchdir
.type fchdir, %function;
fchdir:
.globl fchmod
.type fchmod, %function;
fchmod:
.globl fchmodat
.type fchmodat, %function;
fchmodat:
.globl fchown
.type fchown, %function;
fchown:
.globl fchownat
.type fchownat, %function;
fchownat:
.globl fclose
.type fclose, %function;
fclose:
.globl fcntl
.type fcntl, %function;
fcntl:
.globl fcvt
.type fcvt, %function;
fcvt:
.globl fdatasync
.type fdatasync, %function;
fdatasync:
.globl fdim
.type fdim, %function;
fdim:
.globl fdimf
.type fdimf, %function;
fdimf:
.globl fdiml
.type fdiml, %function;
fdiml:
.weak fdopen
.type fdopen, %function;
fdopen:
.globl fdopendir
.type fdopendir, %function;
fdopendir:
.globl feclearexcept
.type feclearexcept, %function;
feclearexcept:
.globl fegetenv
.type fegetenv, %function;
fegetenv:
.globl fegetexceptflag
.type fegetexceptflag, %function;
fegetexceptflag:
.globl fegetround
.type fegetround, %function;
fegetround:
.globl feholdexcept
.type feholdexcept, %function;
feholdexcept:
.globl feof
.type feof, %function;
feof:
.weak feof_unlocked
.type feof_unlocked, %function;
feof_unlocked:
.globl feraiseexcept
.type feraiseexcept, %function;
feraiseexcept:
.globl ferror
.type ferror, %function;
ferror:
.weak ferror_unlocked
.type ferror_unlocked, %function;
ferror_unlocked:
.globl fesetenv
.type fesetenv, %function;
fesetenv:
.globl fesetexceptflag
.type fesetexceptflag, %function;
fesetexceptflag:
.globl fesetround
.type fesetround, %function;
fesetround:
.globl fetestexcept
.type fetestexcept, %function;
fetestexcept:
.globl feupdateenv
.type feupdateenv, %function;
feupdateenv:
.globl fexecve
.type fexecve, %function;
fexecve:
.globl fflush
.type fflush, %function;
fflush:
.weak fflush_unlocked
.type fflush_unlocked, %function;
fflush_unlocked:
.globl ffs
.type ffs, %function;
ffs:
.globl ffsl
.type ffsl, %function;
ffsl:
.globl ffsll
.type ffsll, %function;
ffsll:
.globl fgetc
.type fgetc, %function;
fgetc:
.weak fgetc_unlocked
.type fgetc_unlocked, %function;
fgetc_unlocked:
.globl fgetgrent
.type fgetgrent, %function;
fgetgrent:
.globl fgetln
.type fgetln, %function;
fgetln:
.globl fgetpos
.type fgetpos, %function;
fgetpos:
.globl fgetpwent
.type fgetpwent, %function;
fgetpwent:
.globl fgets
.type fgets, %function;
fgets:
.weak fgets_unlocked
.type fgets_unlocked, %function;
fgets_unlocked:
.globl fgetspent
.type fgetspent, %function;
fgetspent:
.globl fgetwc
.type fgetwc, %function;
fgetwc:
.weak fgetwc_unlocked
.type fgetwc_unlocked, %function;
fgetwc_unlocked:
.globl fgetws
.type fgetws, %function;
fgetws:
.weak fgetws_unlocked
.type fgetws_unlocked, %function;
fgetws_unlocked:
.globl fgetxattr
.type fgetxattr, %function;
fgetxattr:
.globl fileno
.type fileno, %function;
fileno:
.weak fileno_unlocked
.type fileno_unlocked, %function;
fileno_unlocked:
.globl finite
.type finite, %function;
finite:
.globl finitef
.type finitef, %function;
finitef:
.globl flistxattr
.type flistxattr, %function;
flistxattr:
.globl flock
.type flock, %function;
flock:
.globl flockfile
.type flockfile, %function;
flockfile:
.globl floor
.type floor, %function;
floor:
.globl floorf
.type floorf, %function;
floorf:
.globl floorl
.type floorl, %function;
floorl:
.globl fma
.type fma, %function;
fma:
.globl fmaf
.type fmaf, %function;
fmaf:
.globl fmal
.type fmal, %function;
fmal:
.globl fmax
.type fmax, %function;
fmax:
.globl fmaxf
.type fmaxf, %function;
fmaxf:
.globl fmaxl
.type fmaxl, %function;
fmaxl:
.globl fmemopen
.type fmemopen, %function;
fmemopen:
.globl fmin
.type fmin, %function;
fmin:
.globl fminf
.type fminf, %function;
fminf:
.globl fminl
.type fminl, %function;
fminl:
.globl fmod
.type fmod, %function;
fmod:
.globl fmodf
.type fmodf, %function;
fmodf:
.globl fmodl
.type fmodl, %function;
fmodl:
.globl fmtmsg
.type fmtmsg, %function;
fmtmsg:
.globl fnmatch
.type fnmatch, %function;
fnmatch:
.globl fopen
.type fopen, %function;
fopen:
.globl fopencookie
.type fopencookie, %function;
fopencookie:
.globl fork
.type fork, %function;
fork:
.globl forkpty
.type forkpty, %function;
forkpty:
.globl fpathconf
.type fpathconf, %function;
fpathconf:
.globl fprintf
.type fprintf, %function;
fprintf:
.weak fpurge
.type fpurge, %function;
fpurge:
.globl fputc
.type fputc, %function;
fputc:
.weak fputc_unlocked
.type fputc_unlocked, %function;
fputc_unlocked:
.globl fputs
.type fputs, %function;
fputs:
.weak fputs_unlocked
.type fputs_unlocked, %function;
fputs_unlocked:
.globl fputwc
.type fputwc, %function;
fputwc:
.weak fputwc_unlocked
.type fputwc_unlocked, %function;
fputwc_unlocked:
.globl fputws
.type fputws, %function;
fputws:
.weak fputws_unlocked
.type fputws_unlocked, %function;
fputws_unlocked:
.globl fread
.type fread, %function;
fread:
.weak fread_unlocked
.type fread_unlocked, %function;
fread_unlocked:
.globl free
.type free, %function;
free:
.globl freeaddrinfo
.type freeaddrinfo, %function;
freeaddrinfo:
.globl freeifaddrs
.type freeifaddrs, %function;
freeifaddrs:
.globl freelocale
.type freelocale, %function;
freelocale:
.globl fremovexattr
.type fremovexattr, %function;
fremovexattr:
.globl freopen
.type freopen, %function;
freopen:
.globl frexp
.type frexp, %function;
frexp:
.globl frexpf
.type frexpf, %function;
frexpf:
.globl frexpl
.type frexpl, %function;
frexpl:
.globl fscanf
.type fscanf, %function;
fscanf:
.globl fseek
.type fseek, %function;
fseek:
.weak fseeko
.type fseeko, %function;
fseeko:
.globl fsetpos
.type fsetpos, %function;
fsetpos:
.globl fsetxattr
.type fsetxattr, %function;
fsetxattr:
WEAK64 fstat
.type fstat, %function;
fstat:
WEAK64 fstatat
.type fstatat, %function;
fstatat:
.weak fstatfs
.type fstatfs, %function;
fstatfs:
.globl fstatvfs
.type fstatvfs, %function;
fstatvfs:
.globl fsync
.type fsync, %function;
fsync:
.globl ftell
.type ftell, %function;
ftell:
.weak ftello
.type ftello, %function;
ftello:
.globl ftime
.type ftime, %function;
ftime:
.globl ftok
.type ftok, %function;
ftok:
.globl ftruncate
.type ftruncate, %function;
ftruncate:
.globl ftrylockfile
.type ftrylockfile, %function;
ftrylockfile:
.globl ftw
.type ftw, %function;
ftw:
.globl funlockfile
.type funlockfile, %function;
funlockfile:
.globl futimens
.type futimens, %function;
futimens:
.globl futimes
.type futimes, %function;
futimes:
WEAK64 futimesat
.type futimesat, %function;
futimesat:
.globl fwide
.type fwide, %function;
fwide:
.globl fwprintf
.type fwprintf, %function;
fwprintf:
.globl fwrite
.type fwrite, %function;
fwrite:
.weak fwrite_unlocked
.type fwrite_unlocked, %function;
fwrite_unlocked:
.globl fwscanf
.type fwscanf, %function;
fwscanf:
.globl gai_strerror
.type gai_strerror, %function;
gai_strerror:
.globl gcvt
.type gcvt, %function;
gcvt:
.globl get_avphys_pages
.type get_avphys_pages, %function;
get_avphys_pages:
.globl get_current_dir_name
.type get_current_dir_name, %function;
get_current_dir_name:
.globl get_nprocs
.type get_nprocs, %function;
get_nprocs:
.globl get_nprocs_conf
.type get_nprocs_conf, %function;
get_nprocs_conf:
.globl get_phys_pages
.type get_phys_pages, %function;
get_phys_pages:
.globl getaddrinfo
.type getaddrinfo, %function;
getaddrinfo:
.weak getauxval
.type getauxval, %function;
getauxval:
.globl getc
.type getc, %function;
getc:
.globl getc_unlocked
.type getc_unlocked, %function;
getc_unlocked:
.globl getchar
.type getchar, %function;
getchar:
.globl getchar_unlocked
.type getchar_unlocked, %function;
getchar_unlocked:
.globl getcwd
.type getcwd, %function;
getcwd:
.globl getdate
.type getdate, %function;
getdate:
.globl getdelim
.type getdelim, %function;
getdelim:
.globl getdents
.type getdents, %function;
getdents:
.globl getdomainname
.type getdomainname, %function;
getdomainname:
.globl getdtablesize
.type getdtablesize, %function;
getdtablesize:
.globl getegid
.type getegid, %function;
getegid:
.globl getentropy
.type getentropy, %function;
getentropy:
.globl getenv
.type getenv, %function;
getenv:
.globl geteuid
.type geteuid, %function;
geteuid:
.globl getgid
.type getgid, %function;
getgid:
.globl getgrent
.type getgrent, %function;
getgrent:
.globl getgrgid
.type getgrgid, %function;
getgrgid:
.globl getgrgid_r
.type getgrgid_r, %function;
getgrgid_r:
.globl getgrnam
.type getgrnam, %function;
getgrnam:
.globl getgrnam_r
.type getgrnam_r, %function;
getgrnam_r:
.globl getgrouplist
.type getgrouplist, %function;
getgrouplist:
.globl getgroups
.type getgroups, %function;
getgroups:
.globl gethostbyaddr
.type gethostbyaddr, %function;
gethostbyaddr:
.globl gethostbyaddr_r
.type gethostbyaddr_r, %function;
gethostbyaddr_r:
.globl gethostbyname
.type gethostbyname, %function;
gethostbyname:
.globl gethostbyname2
.type gethostbyname2, %function;
gethostbyname2:
.globl gethostbyname2_r
.type gethostbyname2_r, %function;
gethostbyname2_r:
.globl gethostbyname_r
.type gethostbyname_r, %function;
gethostbyname_r:
.globl gethostent
.type gethostent, %function;
gethostent:
.globl gethostid
.type gethostid, %function;
gethostid:
.globl gethostname
.type gethostname, %function;
gethostname:
.globl getifaddrs
.type getifaddrs, %function;
getifaddrs:
.globl getitimer
.type getitimer, %function;
getitimer:
.globl getline
.type getline, %function;
getline:
.globl getloadavg
.type getloadavg, %function;
getloadavg:
.globl getlogin
.type getlogin, %function;
getlogin:
.globl getlogin_r
.type getlogin_r, %function;
getlogin_r:
.globl getmntent
.type getmntent, %function;
getmntent:
.globl getmntent_r
.type getmntent_r, %function;
getmntent_r:
.globl getnameinfo
.type getnameinfo, %function;
getnameinfo:
.globl getnetbyaddr
.type getnetbyaddr, %function;
getnetbyaddr:
.globl getnetbyname
.type getnetbyname, %function;
getnetbyname:
.globl getnetent
.type getnetent, %function;
getnetent:
.globl getopt
.type getopt, %function;
getopt:
.globl getopt_long
.type getopt_long, %function;
getopt_long:
.globl getopt_long_only
.type getopt_long_only, %function;
getopt_long_only:
.globl getpagesize
.type getpagesize, %function;
getpagesize:
.globl getpass
.type getpass, %function;
getpass:
.globl getpeername
.type getpeername, %function;
getpeername:
.globl getpgid
.type getpgid, %function;
getpgid:
.globl getpgrp
.type getpgrp, %function;
getpgrp:
.globl getpid
.type getpid, %function;
getpid:
.globl getppid
.type getppid, %function;
getppid:
.globl getpriority
.type getpriority, %function;
getpriority:
.globl getprotobyname
.type getprotobyname, %function;
getprotobyname:
.globl getprotobynumber
.type getprotobynumber, %function;
getprotobynumber:
.globl getprotoent
.type getprotoent, %function;
getprotoent:
.globl getpwent
.type getpwent, %function;
getpwent:
.globl getpwnam
.type getpwnam, %function;
getpwnam:
.globl getpwnam_r
.type getpwnam_r, %function;
getpwnam_r:
.globl getpwuid
.type getpwuid, %function;
getpwuid:
.globl getpwuid_r
.type getpwuid_r, %function;
getpwuid_r:
.globl getrandom
.type getrandom, %function;
getrandom:
.globl getresgid
.type getresgid, %function;
getresgid:
.globl getresuid
.type getresuid, %function;
getresuid:
.globl getrlimit
.type getrlimit, %function;
getrlimit:
.globl getrusage
.type getrusage, %function;
getrusage:
.globl gets
.type gets, %function;
gets:
.globl getservbyname
.type getservbyname, %function;
getservbyname:
.globl getservbyname_r
.type getservbyname_r, %function;
getservbyname_r:
.globl getservbyport
.type getservbyport, %function;
getservbyport:
.globl getservbyport_r
.type getservbyport_r, %function;
getservbyport_r:
.globl getservent
.type getservent, %function;
getservent:
.globl getsid
.type getsid, %function;
getsid:
.globl getsockname
.type getsockname, %function;
getsockname:
.globl getsockopt
.type getsockopt, %function;
getsockopt:
.globl getspent
.type getspent, %function;
getspent:
.globl getspnam
.type getspnam, %function;
getspnam:
.globl getspnam_r
.type getspnam_r, %function;
getspnam_r:
.globl getsubopt
.type getsubopt, %function;
getsubopt:
.globl gettext
.type gettext, %function;
gettext:
.globl gettid
.type gettid, %function;
gettid:
.globl gettimeofday
.type gettimeofday, %function;
gettimeofday:
.globl getuid
.type getuid, %function;
getuid:
.globl getusershell
.type getusershell, %function;
getusershell:
.weak getutent
.type getutent, %function;
getutent:
.weak getutid
.type getutid, %function;
getutid:
.weak getutline
.type getutline, %function;
getutline:
.globl getutxent
.type getutxent, %function;
getutxent:
.globl getutxid
.type getutxid, %function;
getutxid:
.globl getutxline
.type getutxline, %function;
getutxline:
.globl getw
.type getw, %function;
getw:
.globl getwc
.type getwc, %function;
getwc:
.weak getwc_unlocked
.type getwc_unlocked, %function;
getwc_unlocked:
.globl getwchar
.type getwchar, %function;
getwchar:
.weak getwchar_unlocked
.type getwchar_unlocked, %function;
getwchar_unlocked:
.globl getxattr
.type getxattr, %function;
getxattr:
.globl glob
.type glob, %function;
glob:
.globl globfree
.type globfree, %function;
globfree:
.globl gmtime
.type gmtime, %function;
gmtime:
WEAK64 gmtime_r
.type gmtime_r, %function;
gmtime_r:
.globl grantpt
.type grantpt, %function;
grantpt:
.globl hasmntopt
.type hasmntopt, %function;
hasmntopt:
.globl hcreate
.type hcreate, %function;
hcreate:
.weak hcreate_r
.type hcreate_r, %function;
hcreate_r:
.globl hdestroy
.type hdestroy, %function;
hdestroy:
.weak hdestroy_r
.type hdestroy_r, %function;
hdestroy_r:
.globl herror
.type herror, %function;
herror:
.globl hsearch
.type hsearch, %function;
hsearch:
.weak hsearch_r
.type hsearch_r, %function;
hsearch_r:
.globl hstrerror
.type hstrerror, %function;
hstrerror:
.globl htonl
.type htonl, %function;
htonl:
.globl htons
.type htons, %function;
htons:
.globl hypot
.type hypot, %function;
hypot:
.globl hypotf
.type hypotf, %function;
hypotf:
.globl hypotl
.type hypotl, %function;
hypotl:
.globl iconv
.type iconv, %function;
iconv:
.globl iconv_close
.type iconv_close, %function;
iconv_close:
.globl iconv_open
.type iconv_open, %function;
iconv_open:
.globl if_freenameindex
.type if_freenameindex, %function;
if_freenameindex:
.globl if_indextoname
.type if_indextoname, %function;
if_indextoname:
.globl if_nameindex
.type if_nameindex, %function;
if_nameindex:
.globl if_nametoindex
.type if_nametoindex, %function;
if_nametoindex:
.globl ilogb
.type ilogb, %function;
ilogb:
.globl ilogbf
.type ilogbf, %function;
ilogbf:
.globl ilogbl
.type ilogbl, %function;
ilogbl:
.globl imaxabs
.type imaxabs, %function;
imaxabs:
.globl imaxdiv
.type imaxdiv, %function;
imaxdiv:
.globl index
.type index, %function;
index:
.globl inet_addr
.type inet_addr, %function;
inet_addr:
.weak inet_aton
.type inet_aton, %function;
inet_aton:
.globl inet_lnaof
.type inet_lnaof, %function;
inet_lnaof:
.globl inet_makeaddr
.type inet_makeaddr, %function;
inet_makeaddr:
.globl inet_netof
.type inet_netof, %function;
inet_netof:
.globl inet_network
.type inet_network, %function;
inet_network:
.globl inet_ntoa
.type inet_ntoa, %function;
inet_ntoa:
.globl inet_ntop
.type inet_ntop, %function;
inet_ntop:
.globl inet_pton
.type inet_pton, %function;
inet_pton:
.globl init_module
.type init_module, %function;
init_module:
.globl initgroups
.type initgroups, %function;
initgroups:
.globl initstate
.type initstate, %function;
initstate:
.globl inotify_add_watch
.type inotify_add_watch, %function;
inotify_add_watch:
.globl inotify_init
.type inotify_init, %function;
inotify_init:
.globl inotify_init1
.type inotify_init1, %function;
inotify_init1:
.globl inotify_rm_watch
.type inotify_rm_watch, %function;
inotify_rm_watch:
.globl insque
.type insque, %function;
insque:
.globl ioctl
.type ioctl, %function;
ioctl:
#if !defined(ARCH_riscv64) && !defined(ARCH_mips64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.globl ioperm
.type ioperm, %function;
ioperm:
#endif
#if !defined(ARCH_riscv64) && !defined(ARCH_mips64) && !defined(ARCH_aarch64) && !defined(ARCH_riscv32) && !defined(ARCH_loongarch64)
.globl iopl
.type iopl, %function;
iopl:
#endif
.globl isalnum
.type isalnum, %function;
isalnum:
.weak isalnum_l
.type isalnum_l, %function;
isalnum_l:
.globl isalpha
.type isalpha, %function;
isalpha:
.weak isalpha_l
.type isalpha_l, %function;
isalpha_l:
.globl isascii
.type isascii, %function;
isascii:
.globl isastream
.type isastream, %function;
isastream:
.globl isatty
.type isatty, %function;
isatty:
.globl isblank
.type isblank, %function;
isblank:
.weak isblank_l
.type isblank_l, %function;
isblank_l:
.globl iscntrl
.type iscntrl, %function;
iscntrl:
.weak iscntrl_l
.type iscntrl_l, %function;
iscntrl_l:
.globl isdigit
.type isdigit, %function;
isdigit:
.weak isdigit_l
.type isdigit_l, %function;
isdigit_l:
.globl isgraph
.type isgraph, %function;
isgraph:
.weak isgraph_l
.type isgraph_l, %function;
isgraph_l:
.globl islower
.type islower, %function;
islower:
.weak islower_l
.type islower_l, %function;
islower_l:
.globl isprint
.type isprint, %function;
isprint:
.weak isprint_l
.type isprint_l, %function;
isprint_l:
.globl ispunct
.type ispunct, %function;
ispunct:
.weak ispunct_l
.type ispunct_l, %function;
ispunct_l:
.globl issetugid
.type issetugid, %function;
issetugid:
.globl isspace
.type isspace, %function;
isspace:
.weak isspace_l
.type isspace_l, %function;
isspace_l:
.globl isupper
.type isupper, %function;
isupper:
.weak isupper_l
.type isupper_l, %function;
isupper_l:
.globl iswalnum
.type iswalnum, %function;
iswalnum:
.weak iswalnum_l
.type iswalnum_l, %function;
iswalnum_l:
.globl iswalpha
.type iswalpha, %function;
iswalpha:
.weak iswalpha_l
.type iswalpha_l, %function;
iswalpha_l:
.globl iswblank
.type iswblank, %function;
iswblank:
.weak iswblank_l
.type iswblank_l, %function;
iswblank_l:
.globl iswcntrl
.type iswcntrl, %function;
iswcntrl:
.weak iswcntrl_l
.type iswcntrl_l, %function;
iswcntrl_l:
.globl iswctype
.type iswctype, %function;
iswctype:
.weak iswctype_l
.type iswctype_l, %function;
iswctype_l:
.globl iswdigit
.type iswdigit, %function;
iswdigit:
.weak iswdigit_l
.type iswdigit_l, %function;
iswdigit_l:
.globl iswgraph
.type iswgraph, %function;
iswgraph:
.weak iswgraph_l
.type iswgraph_l, %function;
iswgraph_l:
.globl iswlower
.type iswlower, %function;
iswlower:
.weak iswlower_l
.type iswlower_l, %function;
iswlower_l:
.globl iswprint
.type iswprint, %function;
iswprint:
.weak iswprint_l
.type iswprint_l, %function;
iswprint_l:
.globl iswpunct
.type iswpunct, %function;
iswpunct:
.weak iswpunct_l
.type iswpunct_l, %function;
iswpunct_l:
.globl iswspace
.type iswspace, %function;
iswspace:
.weak iswspace_l
.type iswspace_l, %function;
iswspace_l:
.globl iswupper
.type iswupper, %function;
iswupper:
.weak iswupper_l
.type iswupper_l, %function;
iswupper_l:
.globl iswxdigit
.type iswxdigit, %function;
iswxdigit:
.weak iswxdigit_l
.type iswxdigit_l, %function;
iswxdigit_l:
.globl isxdigit
.type isxdigit, %function;
isxdigit:
.weak isxdigit_l
.type isxdigit_l, %function;
isxdigit_l:
.globl j0
.type j0, %function;
j0:
.globl j0f
.type j0f, %function;
j0f:
.globl j1
.type j1, %function;
j1:
.globl j1f
.type j1f, %function;
j1f:
.globl jn
.type jn, %function;
jn:
.globl jnf
.type jnf, %function;
jnf:
.globl jrand48
.type jrand48, %function;
jrand48:
.globl kill
.type kill, %function;
kill:
.globl killpg
.type killpg, %function;
killpg:
.globl klogctl
.type klogctl, %function;
klogctl:
.globl l64a
.type l64a, %function;
l64a:
.globl labs
.type labs, %function;
labs:
.globl lchmod
.type lchmod, %function;
lchmod:
.globl lchown
.type lchown, %function;
lchown:
.globl lckpwdf
.type lckpwdf, %function;
lckpwdf:
.globl lcong48
.type lcong48, %function;
lcong48:
.globl ldexp
.type ldexp, %function;
ldexp:
.globl ldexpf
.type ldexpf, %function;
ldexpf:
.globl ldexpl
.type ldexpl, %function;
ldexpl:
.globl ldiv
.type ldiv, %function;
ldiv:
.globl lfind
.type lfind, %function;
lfind:
.globl lgamma
.type lgamma, %function;
lgamma:
.weak lgamma_r
.type lgamma_r, %function;
lgamma_r:
.globl lgammaf
.type lgammaf, %function;
lgammaf:
.weak lgammaf_r
.type lgammaf_r, %function;
lgammaf_r:
.globl lgammal
.type lgammal, %function;
lgammal:
.weak lgammal_r
.type lgammal_r, %function;
lgammal_r:
.globl lgetxattr
.type lgetxattr, %function;
lgetxattr:
.globl link
.type link, %function;
link:
.globl linkat
.type linkat, %function;
linkat:
.globl lio_listio
.type lio_listio, %function;
lio_listio:
.globl listen
.type listen, %function;
listen:
.globl listxattr
.type listxattr, %function;
listxattr:
.globl llabs
.type llabs, %function;
llabs:
.globl lldiv
.type lldiv, %function;
lldiv:
.globl llistxattr
.type llistxattr, %function;
llistxattr:
.globl llrint
.type llrint, %function;
llrint:
.globl llrintf
.type llrintf, %function;
llrintf:
.globl llrintl
.type llrintl, %function;
llrintl:
.globl llround
.type llround, %function;
llround:
.globl llroundf
.type llroundf, %function;
llroundf:
.globl llroundl
.type llroundl, %function;
llroundl:
.globl localeconv
.type localeconv, %function;
localeconv:
.globl localtime
.type localtime, %function;
localtime:
WEAK64 localtime_r
.type localtime_r, %function;
localtime_r:
.globl lockf
.type lockf, %function;
lockf:
.globl log
.type log, %function;
log:
.globl log10
.type log10, %function;
log10:
.globl log10f
.type log10f, %function;
log10f:
.globl log10l
.type log10l, %function;
log10l:
.globl log1p
.type log1p, %function;
log1p:
.globl log1pf
.type log1pf, %function;
log1pf:
.globl log1pl
.type log1pl, %function;
log1pl:
.globl log2
.type log2, %function;
log2:
.globl log2f
.type log2f, %function;
log2f:
.globl log2l
.type log2l, %function;
log2l:
.globl logb
.type logb, %function;
logb:
.globl logbf
.type logbf, %function;
logbf:
.globl logbl
.type logbl, %function;
logbl:
.globl logf
.type logf, %function;
logf:
.globl login_tty
.type login_tty, %function;
login_tty:
.globl logl
.type logl, %function;
logl:
.globl longjmp
.type longjmp, %function;
longjmp:
.globl lrand48
.type lrand48, %function;
lrand48:
.globl lremovexattr
.type lremovexattr, %function;
lremovexattr:
.globl lrint
.type lrint, %function;
lrint:
.globl lrintf
.type lrintf, %function;
lrintf:
.globl lrintl
.type lrintl, %function;
lrintl:
.globl lround
.type lround, %function;
lround:
.globl lroundf
.type lroundf, %function;
lroundf:
.globl lroundl
.type lroundl, %function;
lroundl:
.globl lsearch
.type lsearch, %function;
lsearch:
.weak lseek
.type lseek, %function;
lseek:
.globl lsetxattr
.type lsetxattr, %function;
lsetxattr:
.globl lstat
.type lstat, %function;
lstat:
.globl lutimes
.type lutimes, %function;
lutimes:
.weak madvise
.type madvise, %function;
madvise:
.weak malloc
.type malloc, %function;
malloc:
.globl malloc_usable_size
.type malloc_usable_size, %function;
malloc_usable_size:
.globl mblen
.type mblen, %function;
mblen:
.globl mbrlen
.type mbrlen, %function;
mbrlen:
.globl mbrtoc16
.type mbrtoc16, %function;
mbrtoc16:
.globl mbrtoc32
.type mbrtoc32, %function;
mbrtoc32:
.globl mbrtowc
.type mbrtowc, %function;
mbrtowc:
.globl mbsinit
.type mbsinit, %function;
mbsinit:
.globl mbsnrtowcs
.type mbsnrtowcs, %function;
mbsnrtowcs:
.globl mbsrtowcs
.type mbsrtowcs, %function;
mbsrtowcs:
.globl mbstowcs
.type mbstowcs, %function;
mbstowcs:
.globl mbtowc
.type mbtowc, %function;
mbtowc:
.globl memalign
.type memalign, %function;
memalign:
.weak membarrier
.type membarrier, %function;
membarrier:
.globl memccpy
.type memccpy, %function;
memccpy:
.globl memchr
.type memchr, %function;
memchr:
.globl memcmp
.type memcmp, %function;
memcmp:
.globl memcpy
.type memcpy, %function;
memcpy:
.globl memfd_create
.type memfd_create, %function;
memfd_create:
.globl memmem
.type memmem, %function;
memmem:
.globl memmove
.type memmove, %function;
memmove:
.globl mempcpy
.type mempcpy, %function;
mempcpy:
.weak memrchr
.type memrchr, %function;
memrchr:
.globl memset
.type memset, %function;
memset:
.globl mincore
.type mincore, %function;
mincore:
.globl mkdir
.type mkdir, %function;
mkdir:
.globl mkdirat
.type mkdirat, %function;
mkdirat:
.globl mkdtemp
.type mkdtemp, %function;
mkdtemp:
.globl mkfifo
.type mkfifo, %function;
mkfifo:
.globl mkfifoat
.type mkfifoat, %function;
mkfifoat:
.globl mknod
.type mknod, %function;
mknod:
.globl mknodat
.type mknodat, %function;
mknodat:
.globl mkostemp
.type mkostemp, %function;
mkostemp:
.weak mkostemps
.type mkostemps, %function;
mkostemps:
.globl mkstemp
.type mkstemp, %function;
mkstemp:
.globl mkstemps
.type mkstemps, %function;
mkstemps:
.globl mktemp
.type mktemp, %function;
mktemp:
.globl mktime
.type mktime, %function;
mktime:
.globl mlock
.type mlock, %function;
mlock:
.globl mlock2
.type mlock2, %function;
mlock2:
.globl mlockall
.type mlockall, %function;
mlockall:
.weak mmap
.type mmap, %function;
mmap:
.globl modf
.type modf, %function;
modf:
.globl modff
.type modff, %function;
modff:
.globl modfl
.type modfl, %function;
modfl:
.globl mount
.type mount, %function;
mount:
.weak mprotect
.type mprotect, %function;
mprotect:
.globl mq_close
.type mq_close, %function;
mq_close:
.globl mq_getattr
.type mq_getattr, %function;
mq_getattr:
.globl mq_notify
.type mq_notify, %function;
mq_notify:
.globl mq_open
.type mq_open, %function;
mq_open:
.globl mq_receive
.type mq_receive, %function;
mq_receive:
.globl mq_send
.type mq_send, %function;
mq_send:
.globl mq_setattr
.type mq_setattr, %function;
mq_setattr:
.globl mq_timedreceive
.type mq_timedreceive, %function;
mq_timedreceive:
.globl mq_timedsend
.type mq_timedsend, %function;
mq_timedsend:
.globl mq_unlink
.type mq_unlink, %function;
mq_unlink:
.globl mrand48
.type mrand48, %function;
mrand48:
.weak mremap
.type mremap, %function;
mremap:
.globl msgctl
.type msgctl, %function;
msgctl:
.globl msgget
.type msgget, %function;
msgget:
.globl msgrcv
.type msgrcv, %function;
msgrcv:
.globl msgsnd
.type msgsnd, %function;
msgsnd:
.globl msync
.type msync, %function;
msync:
.globl mtx_destroy
.type mtx_destroy, %function;
mtx_destroy:
.globl mtx_init
.type mtx_init, %function;
mtx_init:
.globl mtx_lock
.type mtx_lock, %function;
mtx_lock:
.globl mtx_timedlock
.type mtx_timedlock, %function;
mtx_timedlock:
.globl mtx_trylock
.type mtx_trylock, %function;
mtx_trylock:
.globl mtx_unlock
.type mtx_unlock, %function;
mtx_unlock:
.globl munlock
.type munlock, %function;
munlock:
.globl munlockall
.type munlockall, %function;
munlockall:
.weak munmap
.type munmap, %function;
munmap:
.globl name_to_handle_at
.type name_to_handle_at, %function;
name_to_handle_at:
.globl nan
.type nan, %function;
nan:
.globl nanf
.type nanf, %function;
nanf:
.globl nanl
.type nanl, %function;
nanl:
.globl nanosleep
.type nanosleep, %function;
nanosleep:
.globl nearbyint
.type nearbyint, %function;
nearbyint:
.globl nearbyintf
.type nearbyintf, %function;
nearbyintf:
.globl nearbyintl
.type nearbyintl, %function;
nearbyintl:
.weak newlocale
.type newlocale, %function;
newlocale:
.globl nextafter
.type nextafter, %function;
nextafter:
.globl nextafterf
.type nextafterf, %function;
nextafterf:
.globl nextafterl
.type nextafterl, %function;
nextafterl:
.globl nexttoward
.type nexttoward, %function;
nexttoward:
.globl nexttowardf
.type nexttowardf, %function;
nexttowardf:
.globl nexttowardl
.type nexttowardl, %function;
nexttowardl:
.globl nftw
.type nftw, %function;
nftw:
.globl ngettext
.type ngettext, %function;
ngettext:
.globl nice
.type nice, %function;
nice:
.weak nl_langinfo
.type nl_langinfo, %function;
nl_langinfo:
.weak nl_langinfo_l
.type nl_langinfo_l, %function;
nl_langinfo_l:
.globl nrand48
.type nrand48, %function;
nrand48:
.globl ns_get16
.type ns_get16, %function;
ns_get16:
.globl ns_get32
.type ns_get32, %function;
ns_get32:
.globl ns_initparse
.type ns_initparse, %function;
ns_initparse:
.globl ns_name_uncompress
.type ns_name_uncompress, %function;
ns_name_uncompress:
.globl ns_parserr
.type ns_parserr, %function;
ns_parserr:
.globl ns_put16
.type ns_put16, %function;
ns_put16:
.globl ns_put32
.type ns_put32, %function;
ns_put32:
.globl ns_skiprr
.type ns_skiprr, %function;
ns_skiprr:
.globl ntohl
.type ntohl, %function;
ntohl:
.globl ntohs
.type ntohs, %function;
ntohs:
.globl open
.type open, %function;
open:
.globl open_by_handle_at
.type open_by_handle_at, %function;
open_by_handle_at:
.globl open_memstream
.type open_memstream, %function;
open_memstream:
.globl open_wmemstream
.type open_wmemstream, %function;
open_wmemstream:
.globl openat
.type openat, %function;
openat:
.globl opendir
.type opendir, %function;
opendir:
.globl openlog
.type openlog, %function;
openlog:
.globl openpty
.type openpty, %function;
openpty:
.globl pathconf
.type pathconf, %function;
pathconf:
.globl pause
.type pause, %function;
pause:
.globl pclose
.type pclose, %function;
pclose:
.globl perror
.type perror, %function;
perror:
.globl personality
.type personality, %function;
personality:
.globl pipe
.type pipe, %function;
pipe:
.globl pipe2
.type pipe2, %function;
pipe2:
.globl pivot_root
.type pivot_root, %function;
pivot_root:
.globl poll
.type poll, %function;
poll:
.globl popen
.type popen, %function;
popen:
.globl posix_close
.type posix_close, %function;
posix_close:
.globl posix_fadvise
.type posix_fadvise, %function;
posix_fadvise:
.globl posix_fallocate
.type posix_fallocate, %function;
posix_fallocate:
.globl posix_madvise
.type posix_madvise, %function;
posix_madvise:
.globl posix_memalign
.type posix_memalign, %function;
posix_memalign:
.globl posix_openpt
.type posix_openpt, %function;
posix_openpt:
.globl posix_spawn
.type posix_spawn, %function;
posix_spawn:
.globl posix_spawn_file_actions_addchdir_np
.type posix_spawn_file_actions_addchdir_np, %function;
posix_spawn_file_actions_addchdir_np:
.globl posix_spawn_file_actions_addclose
.type posix_spawn_file_actions_addclose, %function;
posix_spawn_file_actions_addclose:
.globl posix_spawn_file_actions_adddup2
.type posix_spawn_file_actions_adddup2, %function;
posix_spawn_file_actions_adddup2:
.globl posix_spawn_file_actions_addfchdir_np
.type posix_spawn_file_actions_addfchdir_np, %function;
posix_spawn_file_actions_addfchdir_np:
.globl posix_spawn_file_actions_addopen
.type posix_spawn_file_actions_addopen, %function;
posix_spawn_file_actions_addopen:
.globl posix_spawn_file_actions_destroy
.type posix_spawn_file_actions_destroy, %function;
posix_spawn_file_actions_destroy:
.globl posix_spawn_file_actions_init
.type posix_spawn_file_actions_init, %function;
posix_spawn_file_actions_init:
.globl posix_spawnattr_destroy
.type posix_spawnattr_destroy, %function;
posix_spawnattr_destroy:
.globl posix_spawnattr_getflags
.type posix_spawnattr_getflags, %function;
posix_spawnattr_getflags:
.globl posix_spawnattr_getpgroup
.type posix_spawnattr_getpgroup, %function;
posix_spawnattr_getpgroup:
.globl posix_spawnattr_getschedparam
.type posix_spawnattr_getschedparam, %function;
posix_spawnattr_getschedparam:
.globl posix_spawnattr_getschedpolicy
.type posix_spawnattr_getschedpolicy, %function;
posix_spawnattr_getschedpolicy:
.globl posix_spawnattr_getsigdefault
.type posix_spawnattr_getsigdefault, %function;
posix_spawnattr_getsigdefault:
.globl posix_spawnattr_getsigmask
.type posix_spawnattr_getsigmask, %function;
posix_spawnattr_getsigmask:
.globl posix_spawnattr_init
.type posix_spawnattr_init, %function;
posix_spawnattr_init:
.globl posix_spawnattr_setflags
.type posix_spawnattr_setflags, %function;
posix_spawnattr_setflags:
.globl posix_spawnattr_setpgroup
.type posix_spawnattr_setpgroup, %function;
posix_spawnattr_setpgroup:
.globl posix_spawnattr_setschedparam
.type posix_spawnattr_setschedparam, %function;
posix_spawnattr_setschedparam:
.globl posix_spawnattr_setschedpolicy
.type posix_spawnattr_setschedpolicy, %function;
posix_spawnattr_setschedpolicy:
.globl posix_spawnattr_setsigdefault
.type posix_spawnattr_setsigdefault, %function;
posix_spawnattr_setsigdefault:
.globl posix_spawnattr_setsigmask
.type posix_spawnattr_setsigmask, %function;
posix_spawnattr_setsigmask:
.globl posix_spawnp
.type posix_spawnp, %function;
posix_spawnp:
.globl pow
.type pow, %function;
pow:
.weak pow10
.type pow10, %function;
pow10:
.weak pow10f
.type pow10f, %function;
pow10f:
.weak pow10l
.type pow10l, %function;
pow10l:
.globl powf
.type powf, %function;
powf:
.globl powl
.type powl, %function;
powl:
.globl ppoll
.type ppoll, %function;
ppoll:
.globl prctl
.type prctl, %function;
prctl:
.globl pread
.type pread, %function;
pread:
.globl preadv
.type preadv, %function;
preadv:
.globl preadv2
.type preadv2, %function;
preadv2:
.globl printf
.type printf, %function;
printf:
.globl prlimit
.type prlimit, %function;
prlimit:
.globl process_vm_readv
.type process_vm_readv, %function;
process_vm_readv:
.globl process_vm_writev
.type process_vm_writev, %function;
process_vm_writev:
.globl pselect
.type pselect, %function;
pselect:
.globl psiginfo
.type psiginfo, %function;
psiginfo:
.globl psignal
.type psignal, %function;
psignal:
.globl pthread_atfork
.type pthread_atfork, %function;
pthread_atfork:
.globl pthread_attr_destroy
.type pthread_attr_destroy, %function;
pthread_attr_destroy:
.globl pthread_attr_getdetachstate
.type pthread_attr_getdetachstate, %function;
pthread_attr_getdetachstate:
.globl pthread_attr_getguardsize
.type pthread_attr_getguardsize, %function;
pthread_attr_getguardsize:
.globl pthread_attr_getinheritsched
.type pthread_attr_getinheritsched, %function;
pthread_attr_getinheritsched:
.globl pthread_attr_getschedparam
.type pthread_attr_getschedparam, %function;
pthread_attr_getschedparam:
.globl pthread_attr_getschedpolicy
.type pthread_attr_getschedpolicy, %function;
pthread_attr_getschedpolicy:
.globl pthread_attr_getscope
.type pthread_attr_getscope, %function;
pthread_attr_getscope:
.globl pthread_attr_getstack
.type pthread_attr_getstack, %function;
pthread_attr_getstack:
.globl pthread_attr_getstacksize
.type pthread_attr_getstacksize, %function;
pthread_attr_getstacksize:
.globl pthread_attr_init
.type pthread_attr_init, %function;
pthread_attr_init:
.globl pthread_attr_setdetachstate
.type pthread_attr_setdetachstate, %function;
pthread_attr_setdetachstate:
.globl pthread_attr_setguardsize
.type pthread_attr_setguardsize, %function;
pthread_attr_setguardsize:
.globl pthread_attr_setinheritsched
.type pthread_attr_setinheritsched, %function;
pthread_attr_setinheritsched:
.globl pthread_attr_setschedparam
.type pthread_attr_setschedparam, %function;
pthread_attr_setschedparam:
.globl pthread_attr_setschedpolicy
.type pthread_attr_setschedpolicy, %function;
pthread_attr_setschedpolicy:
.globl pthread_attr_setscope
.type pthread_attr_setscope, %function;
pthread_attr_setscope:
.globl pthread_attr_setstack
.type pthread_attr_setstack, %function;
pthread_attr_setstack:
.globl pthread_attr_setstacksize
.type pthread_attr_setstacksize, %function;
pthread_attr_setstacksize:
.globl pthread_barrier_destroy
.type pthread_barrier_destroy, %function;
pthread_barrier_destroy:
.globl pthread_barrier_init
.type pthread_barrier_init, %function;
pthread_barrier_init:
.globl pthread_barrier_wait
.type pthread_barrier_wait, %function;
pthread_barrier_wait:
.globl pthread_barrierattr_destroy
.type pthread_barrierattr_destroy, %function;
pthread_barrierattr_destroy:
.globl pthread_barrierattr_getpshared
.type pthread_barrierattr_getpshared, %function;
pthread_barrierattr_getpshared:
.globl pthread_barrierattr_init
.type pthread_barrierattr_init, %function;
pthread_barrierattr_init:
.globl pthread_barrierattr_setpshared
.type pthread_barrierattr_setpshared, %function;
pthread_barrierattr_setpshared:
.globl pthread_cancel
.type pthread_cancel, %function;
pthread_cancel:
.globl pthread_cond_broadcast
.type pthread_cond_broadcast, %function;
pthread_cond_broadcast:
.globl pthread_cond_destroy
.type pthread_cond_destroy, %function;
pthread_cond_destroy:
.globl pthread_cond_init
.type pthread_cond_init, %function;
pthread_cond_init:
.globl pthread_cond_signal
.type pthread_cond_signal, %function;
pthread_cond_signal:
WEAK64 pthread_cond_timedwait
.type pthread_cond_timedwait, %function;
pthread_cond_timedwait:
.globl pthread_cond_wait
.type pthread_cond_wait, %function;
pthread_cond_wait:
.globl pthread_condattr_destroy
.type pthread_condattr_destroy, %function;
pthread_condattr_destroy:
.globl pthread_condattr_getclock
.type pthread_condattr_getclock, %function;
pthread_condattr_getclock:
.globl pthread_condattr_getpshared
.type pthread_condattr_getpshared, %function;
pthread_condattr_getpshared:
.globl pthread_condattr_init
.type pthread_condattr_init, %function;
pthread_condattr_init:
.globl pthread_condattr_setclock
.type pthread_condattr_setclock, %function;
pthread_condattr_setclock:
.globl pthread_condattr_setpshared
.type pthread_condattr_setpshared, %function;
pthread_condattr_setpshared:
.weak pthread_create
.type pthread_create, %function;
pthread_create:
.weak pthread_detach
.type pthread_detach, %function;
pthread_detach:
.weak pthread_equal
.type pthread_equal, %function;
pthread_equal:
.weak pthread_exit
.type pthread_exit, %function;
pthread_exit:
.globl pthread_getaffinity_np
.type pthread_getaffinity_np, %function;
pthread_getaffinity_np:
.globl pthread_getattr_default_np
.type pthread_getattr_default_np, %function;
pthread_getattr_default_np:
.globl pthread_getattr_np
.type pthread_getattr_np, %function;
pthread_getattr_np:
.globl pthread_getconcurrency
.type pthread_getconcurrency, %function;
pthread_getconcurrency:
.globl pthread_getcpuclockid
.type pthread_getcpuclockid, %function;
pthread_getcpuclockid:
.globl pthread_getname_np
.type pthread_getname_np, %function;
pthread_getname_np:
.globl pthread_getschedparam
.type pthread_getschedparam, %function;
pthread_getschedparam:
.weak pthread_getspecific
.type pthread_getspecific, %function;
pthread_getspecific:
.weak pthread_join
.type pthread_join, %function;
pthread_join:
.weak pthread_key_create
.type pthread_key_create, %function;
pthread_key_create:
.weak pthread_key_delete
.type pthread_key_delete, %function;
pthread_key_delete:
.globl pthread_kill
.type pthread_kill, %function;
pthread_kill:
.globl pthread_mutex_consistent
.type pthread_mutex_consistent, %function;
pthread_mutex_consistent:
.globl pthread_mutex_destroy
.type pthread_mutex_destroy, %function;
pthread_mutex_destroy:
.globl pthread_mutex_getprioceiling
.type pthread_mutex_getprioceiling, %function;
pthread_mutex_getprioceiling:
.globl pthread_mutex_init
.type pthread_mutex_init, %function;
pthread_mutex_init:
.weak pthread_mutex_lock
.type pthread_mutex_lock, %function;
pthread_mutex_lock:
.globl pthread_mutex_setprioceiling
.type pthread_mutex_setprioceiling, %function;
pthread_mutex_setprioceiling:
WEAK64 pthread_mutex_timedlock
.type pthread_mutex_timedlock, %function;
pthread_mutex_timedlock:
.weak pthread_mutex_trylock
.type pthread_mutex_trylock, %function;
pthread_mutex_trylock:
.weak pthread_mutex_unlock
.type pthread_mutex_unlock, %function;
pthread_mutex_unlock:
.globl pthread_mutexattr_destroy
.type pthread_mutexattr_destroy, %function;
pthread_mutexattr_destroy:
.globl pthread_mutexattr_getprotocol
.type pthread_mutexattr_getprotocol, %function;
pthread_mutexattr_getprotocol:
.globl pthread_mutexattr_getpshared
.type pthread_mutexattr_getpshared, %function;
pthread_mutexattr_getpshared:
.globl pthread_mutexattr_getrobust
.type pthread_mutexattr_getrobust, %function;
pthread_mutexattr_getrobust:
.globl pthread_mutexattr_gettype
.type pthread_mutexattr_gettype, %function;
pthread_mutexattr_gettype:
.globl pthread_mutexattr_init
.type pthread_mutexattr_init, %function;
pthread_mutexattr_init:
.globl pthread_mutexattr_setprotocol
.type pthread_mutexattr_setprotocol, %function;
pthread_mutexattr_setprotocol:
.globl pthread_mutexattr_setpshared
.type pthread_mutexattr_setpshared, %function;
pthread_mutexattr_setpshared:
.globl pthread_mutexattr_setrobust
.type pthread_mutexattr_setrobust, %function;
pthread_mutexattr_setrobust:
.globl pthread_mutexattr_settype
.type pthread_mutexattr_settype, %function;
pthread_mutexattr_settype:
.weak pthread_once
.type pthread_once, %function;
pthread_once:
.globl pthread_rwlock_destroy
.type pthread_rwlock_destroy, %function;
pthread_rwlock_destroy:
.globl pthread_rwlock_init
.type pthread_rwlock_init, %function;
pthread_rwlock_init:
.weak pthread_rwlock_rdlock
.type pthread_rwlock_rdlock, %function;
pthread_rwlock_rdlock:
WEAK64 pthread_rwlock_timedrdlock
.type pthread_rwlock_timedrdlock, %function;
pthread_rwlock_timedrdlock:
WEAK64 pthread_rwlock_timedwrlock
.type pthread_rwlock_timedwrlock, %function;
pthread_rwlock_timedwrlock:
.weak pthread_rwlock_tryrdlock
.type pthread_rwlock_tryrdlock, %function;
pthread_rwlock_tryrdlock:
.weak pthread_rwlock_trywrlock
.type pthread_rwlock_trywrlock, %function;
pthread_rwlock_trywrlock:
.weak pthread_rwlock_unlock
.type pthread_rwlock_unlock, %function;
pthread_rwlock_unlock:
.weak pthread_rwlock_wrlock
.type pthread_rwlock_wrlock, %function;
pthread_rwlock_wrlock:
.globl pthread_rwlockattr_destroy
.type pthread_rwlockattr_destroy, %function;
pthread_rwlockattr_destroy:
.globl pthread_rwlockattr_getpshared
.type pthread_rwlockattr_getpshared, %function;
pthread_rwlockattr_getpshared:
.globl pthread_rwlockattr_init
.type pthread_rwlockattr_init, %function;
pthread_rwlockattr_init:
.globl pthread_rwlockattr_setpshared
.type pthread_rwlockattr_setpshared, %function;
pthread_rwlockattr_setpshared:
.weak pthread_self
.type pthread_self, %function;
pthread_self:
.globl pthread_setaffinity_np
.type pthread_setaffinity_np, %function;
pthread_setaffinity_np:
.globl pthread_setattr_default_np
.type pthread_setattr_default_np, %function;
pthread_setattr_default_np:
.weak pthread_setcancelstate
.type pthread_setcancelstate, %function;
pthread_setcancelstate:
.globl pthread_setcanceltype
.type pthread_setcanceltype, %function;
pthread_setcanceltype:
.globl pthread_setconcurrency
.type pthread_setconcurrency, %function;
pthread_setconcurrency:
.globl pthread_setname_np
.type pthread_setname_np, %function;
pthread_setname_np:
.globl pthread_setschedparam
.type pthread_setschedparam, %function;
pthread_setschedparam:
.globl pthread_setschedprio
.type pthread_setschedprio, %function;
pthread_setschedprio:
.globl pthread_setspecific
.type pthread_setspecific, %function;
pthread_setspecific:
.globl pthread_sigmask
.type pthread_sigmask, %function;
pthread_sigmask:
.globl pthread_spin_destroy
.type pthread_spin_destroy, %function;
pthread_spin_destroy:
.globl pthread_spin_init
.type pthread_spin_init, %function;
pthread_spin_init:
.globl pthread_spin_lock
.type pthread_spin_lock, %function;
pthread_spin_lock:
.globl pthread_spin_trylock
.type pthread_spin_trylock, %function;
pthread_spin_trylock:
.globl pthread_spin_unlock
.type pthread_spin_unlock, %function;
pthread_spin_unlock:
.weak pthread_testcancel
.type pthread_testcancel, %function;
pthread_testcancel:
WEAK64 pthread_timedjoin_np
.type pthread_timedjoin_np, %function;
pthread_timedjoin_np:
.weak pthread_tryjoin_np
.type pthread_tryjoin_np, %function;
pthread_tryjoin_np:
.globl ptrace
.type ptrace, %function;
ptrace:
.globl ptsname
.type ptsname, %function;
ptsname:
.weak ptsname_r
.type ptsname_r, %function;
ptsname_r:
.globl putc
.type putc, %function;
putc:
.globl putc_unlocked
.type putc_unlocked, %function;
putc_unlocked:
.globl putchar
.type putchar, %function;
putchar:
.globl putchar_unlocked
.type putchar_unlocked, %function;
putchar_unlocked:
.globl putenv
.type putenv, %function;
putenv:
.globl putgrent
.type putgrent, %function;
putgrent:
.globl putpwent
.type putpwent, %function;
putpwent:
.globl puts
.type puts, %function;
puts:
.globl putspent
.type putspent, %function;
putspent:
.weak pututline
.type pututline, %function;
pututline:
.globl pututxline
.type pututxline, %function;
pututxline:
.globl putw
.type putw, %function;
putw:
.globl putwc
.type putwc, %function;
putwc:
.weak putwc_unlocked
.type putwc_unlocked, %function;
putwc_unlocked:
.globl putwchar
.type putwchar, %function;
putwchar:
.weak putwchar_unlocked
.type putwchar_unlocked, %function;
putwchar_unlocked:
.globl pwrite
.type pwrite, %function;
pwrite:
.globl pwritev
.type pwritev, %function;
pwritev:
.globl pwritev2
.type pwritev2, %function;
pwritev2:
.globl qsort
.type qsort, %function;
qsort:
.weak qsort_r
.type qsort_r, %function;
qsort_r:
.globl quick_exit
.type quick_exit, %function;
quick_exit:
.globl quotactl
.type quotactl, %function;
quotactl:
.globl raise
.type raise, %function;
raise:
.globl rand
.type rand, %function;
rand:
.globl rand_r
.type rand_r, %function;
rand_r:
.globl random
.type random, %function;
random:
.globl read
.type read, %function;
read:
.globl readahead
.type readahead, %function;
readahead:
.globl readdir
.type readdir, %function;
readdir:
.globl readdir_r
.type readdir_r, %function;
readdir_r:
.globl readlink
.type readlink, %function;
readlink:
.globl readlinkat
.type readlinkat, %function;
readlinkat:
.globl readv
.type readv, %function;
readv:
.globl realloc
.type realloc, %function;
realloc:
.globl reallocarray
.type reallocarray, %function;
reallocarray:
.globl realpath
.type realpath, %function;
realpath:
.globl reboot
.type reboot, %function;
reboot:
.globl recv
.type recv, %function;
recv:
.globl recvfrom
.type recvfrom, %function;
recvfrom:
.globl recvmmsg
.type recvmmsg, %function;
recvmmsg:
.globl recvmsg
.type recvmsg, %function;
recvmsg:
.globl regcomp
.type regcomp, %function;
regcomp:
.globl regerror
.type regerror, %function;
regerror:
.globl regexec
.type regexec, %function;
regexec:
.globl regfree
.type regfree, %function;
regfree:
.globl remainder
.type remainder, %function;
remainder:
.globl remainderf
.type remainderf, %function;
remainderf:
.globl remainderl
.type remainderl, %function;
remainderl:
.globl remap_file_pages
.type remap_file_pages, %function;
remap_file_pages:
.globl remove
.type remove, %function;
remove:
.globl removexattr
.type removexattr, %function;
removexattr:
.globl remque
.type remque, %function;
remque:
.globl remquo
.type remquo, %function;
remquo:
.globl remquof
.type remquof, %function;
remquof:
.globl remquol
.type remquol, %function;
remquol:
.globl rename
.type rename, %function;
rename:
.globl renameat
.type renameat, %function;
renameat:
.globl res_init
.type res_init, %function;
res_init:
.weak res_mkquery
.type res_mkquery, %function;
res_mkquery:
.globl res_query
.type res_query, %function;
res_query:
.globl res_querydomain
.type res_querydomain, %function;
res_querydomain:
.weak res_search
.type res_search, %function;
res_search:
.weak res_send
.type res_send, %function;
res_send:
.globl rewind
.type rewind, %function;
rewind:
.globl rewinddir
.type rewinddir, %function;
rewinddir:
.globl rindex
.type rindex, %function;
rindex:
.globl rint
.type rint, %function;
rint:
.globl rintf
.type rintf, %function;
rintf:
.globl rintl
.type rintl, %function;
rintl:
#if !defined(ARCH_mips) && !defined(ARCH_mips64) && !defined(ARCH_x86) && !defined(ARCH_x86_64) && !defined(ARCH_powerpc) && !defined(ARCH_powerpc64) && !defined(ARCH_aarch64) && !defined(ARCH_loongarch64)
.weak riscv_flush_icache
.type riscv_flush_icache, %function;
riscv_flush_icache:
#endif
.globl rmdir
.type rmdir, %function;
rmdir:
.globl round
.type round, %function;
round:
.globl roundf
.type roundf, %function;
roundf:
.globl roundl
.type roundl, %function;
roundl:
.globl sbrk
.type sbrk, %function;
sbrk:
.globl scalb
.type scalb, %function;
scalb:
.globl scalbf
.type scalbf, %function;
scalbf:
.globl scalbln
.type scalbln, %function;
scalbln:
.globl scalblnf
.type scalblnf, %function;
scalblnf:
.globl scalblnl
.type scalblnl, %function;
scalblnl:
.globl scalbn
.type scalbn, %function;
scalbn:
.globl scalbnf
.type scalbnf, %function;
scalbnf:
.globl scalbnl
.type scalbnl, %function;
scalbnl:
.globl scandir
.type scandir, %function;
scandir:
.globl scanf
.type scanf, %function;
scanf:
.globl sched_get_priority_max
.type sched_get_priority_max, %function;
sched_get_priority_max:
.globl sched_get_priority_min
.type sched_get_priority_min, %function;
sched_get_priority_min:
.globl sched_getaffinity
.type sched_getaffinity, %function;
sched_getaffinity:
.globl sched_getcpu
.type sched_getcpu, %function;
sched_getcpu:
.globl sched_getparam
.type sched_getparam, %function;
sched_getparam:
.globl sched_getscheduler
.type sched_getscheduler, %function;
sched_getscheduler:
.globl sched_rr_get_interval
.type sched_rr_get_interval, %function;
sched_rr_get_interval:
.globl sched_setaffinity
.type sched_setaffinity, %function;
sched_setaffinity:
.globl sched_setparam
.type sched_setparam, %function;
sched_setparam:
.globl sched_setscheduler
.type sched_setscheduler, %function;
sched_setscheduler:
.globl sched_yield
.type sched_yield, %function;
sched_yield:
.globl secure_getenv
.type secure_getenv, %function;
secure_getenv:
.globl seed48
.type seed48, %function;
seed48:
.globl seekdir
.type seekdir, %function;
seekdir:
.globl select
.type select, %function;
select:
.globl sem_close
.type sem_close, %function;
sem_close:
.globl sem_destroy
.type sem_destroy, %function;
sem_destroy:
.globl sem_getvalue
.type sem_getvalue, %function;
sem_getvalue:
.globl sem_init
.type sem_init, %function;
sem_init:
.globl sem_open
.type sem_open, %function;
sem_open:
.globl sem_post
.type sem_post, %function;
sem_post:
.globl sem_timedwait
.type sem_timedwait, %function;
sem_timedwait:
.globl sem_trywait
.type sem_trywait, %function;
sem_trywait:
.globl sem_unlink
.type sem_unlink, %function;
sem_unlink:
.globl sem_wait
.type sem_wait, %function;
sem_wait:
.globl semctl
.type semctl, %function;
semctl:
.globl semget
.type semget, %function;
semget:
.globl semop
.type semop, %function;
semop:
.globl semtimedop
.type semtimedop, %function;
semtimedop:
.globl send
.type send, %function;
send:
.globl sendfile
.type sendfile, %function;
sendfile:
.globl sendmmsg
.type sendmmsg, %function;
sendmmsg:
.globl sendmsg
.type sendmsg, %function;
sendmsg:
.globl sendto
.type sendto, %function;
sendto:
.globl setbuf
.type setbuf, %function;
setbuf:
.globl setbuffer
.type setbuffer, %function;
setbuffer:
.globl setdomainname
.type setdomainname, %function;
setdomainname:
.globl setegid
.type setegid, %function;
setegid:
.globl setenv
.type setenv, %function;
setenv:
.globl seteuid
.type seteuid, %function;
seteuid:
.globl setfsgid
.type setfsgid, %function;
setfsgid:
.globl setfsuid
.type setfsuid, %function;
setfsuid:
.globl setgid
.type setgid, %function;
setgid:
.globl setgrent
.type setgrent, %function;
setgrent:
.globl setgroups
.type setgroups, %function;
setgroups:
.globl sethostent
.type sethostent, %function;
sethostent:
.globl sethostname
.type sethostname, %function;
sethostname:
.globl setitimer
.type setitimer, %function;
setitimer:
.globl setjmp
.type setjmp, %function;
setjmp:
.globl setkey
.type setkey, %function;
setkey:
.globl setlinebuf
.type setlinebuf, %function;
setlinebuf:
.globl setlocale
.type setlocale, %function;
setlocale:
.globl setlogmask
.type setlogmask, %function;
setlogmask:
.globl setmntent
.type setmntent, %function;
setmntent:
.weak setnetent
.type setnetent, %function;
setnetent:
.globl setns
.type setns, %function;
setns:
.globl setpgid
.type setpgid, %function;
setpgid:
.globl setpgrp
.type setpgrp, %function;
setpgrp:
.globl setpriority
.type setpriority, %function;
setpriority:
.globl setprotoent
.type setprotoent, %function;
setprotoent:
.globl setpwent
.type setpwent, %function;
setpwent:
.globl setregid
.type setregid, %function;
setregid:
.globl setresgid
.type setresgid, %function;
setresgid:
.globl setresuid
.type setresuid, %function;
setresuid:
.globl setreuid
.type setreuid, %function;
setreuid:
.globl setrlimit
.type setrlimit, %function;
setrlimit:
.globl setservent
.type setservent, %function;
setservent:
.globl setsid
.type setsid, %function;
setsid:
.globl setsockopt
.type setsockopt, %function;
setsockopt:
.globl setspent
.type setspent, %function;
setspent:
.globl setstate
.type setstate, %function;
setstate:
.globl settimeofday
.type settimeofday, %function;
settimeofday:
.globl setuid
.type setuid, %function;
setuid:
.globl setusershell
.type setusershell, %function;
setusershell:
.weak setutent
.type setutent, %function;
setutent:
.globl setutxent
.type setutxent, %function;
setutxent:
.globl setvbuf
.type setvbuf, %function;
setvbuf:
.globl setxattr
.type setxattr, %function;
setxattr:
.globl shm_open
.type shm_open, %function;
shm_open:
.globl shm_unlink
.type shm_unlink, %function;
shm_unlink:
.globl shmat
.type shmat, %function;
shmat:
.globl shmctl
.type shmctl, %function;
shmctl:
.globl shmdt
.type shmdt, %function;
shmdt:
.globl shmget
.type shmget, %function;
shmget:
.globl shutdown
.type shutdown, %function;
shutdown:
.weak sigaction
.type sigaction, %function;
sigaction:
.globl sigaddset
.type sigaddset, %function;
sigaddset:
.globl sigaltstack
.type sigaltstack, %function;
sigaltstack:
.globl sigandset
.type sigandset, %function;
sigandset:
.globl sigdelset
.type sigdelset, %function;
sigdelset:
.globl sigemptyset
.type sigemptyset, %function;
sigemptyset:
.globl sigfillset
.type sigfillset, %function;
sigfillset:
.globl sighold
.type sighold, %function;
sighold:
.globl sigignore
.type sigignore, %function;
sigignore:
.globl siginterrupt
.type siginterrupt, %function;
siginterrupt:
.globl sigisemptyset
.type sigisemptyset, %function;
sigisemptyset:
.globl sigismember
.type sigismember, %function;
sigismember:
.globl siglongjmp
.type siglongjmp, %function;
siglongjmp:
.globl signal
.type signal, %function;
signal:
.globl signalfd
.type signalfd, %function;
signalfd:
.globl significand
.type significand, %function;
significand:
.globl significandf
.type significandf, %function;
significandf:
.globl sigorset
.type sigorset, %function;
sigorset:
.globl sigpause
.type sigpause, %function;
sigpause:
.globl sigpending
.type sigpending, %function;
sigpending:
.globl sigprocmask
.type sigprocmask, %function;
sigprocmask:
.globl sigqueue
.type sigqueue, %function;
sigqueue:
.globl sigrelse
.type sigrelse, %function;
sigrelse:
.globl sigset
.type sigset, %function;
sigset:
.globl sigsetjmp
.type sigsetjmp, %function;
sigsetjmp:
.globl sigsuspend
.type sigsuspend, %function;
sigsuspend:
.globl sigtimedwait
.type sigtimedwait, %function;
sigtimedwait:
.globl sigwait
.type sigwait, %function;
sigwait:
.globl sigwaitinfo
.type sigwaitinfo, %function;
sigwaitinfo:
.globl sin
.type sin, %function;
sin:
.globl sincos
.type sincos, %function;
sincos:
.globl sincosf
.type sincosf, %function;
sincosf:
.globl sincosl
.type sincosl, %function;
sincosl:
.globl sinf
.type sinf, %function;
sinf:
.globl sinh
.type sinh, %function;
sinh:
.globl sinhf
.type sinhf, %function;
sinhf:
.globl sinhl
.type sinhl, %function;
sinhl:
.globl sinl
.type sinl, %function;
sinl:
.globl sleep
.type sleep, %function;
sleep:
.globl snprintf
.type snprintf, %function;
snprintf:
.globl sockatmark
.type sockatmark, %function;
sockatmark:
.globl socket
.type socket, %function;
socket:
.globl socketpair
.type socketpair, %function;
socketpair:
.globl splice
.type splice, %function;
splice:
.globl sprintf
.type sprintf, %function;
sprintf:
.globl sqrt
.type sqrt, %function;
sqrt:
.globl sqrtf
.type sqrtf, %function;
sqrtf:
.globl sqrtl
.type sqrtl, %function;
sqrtl:
.globl srand
.type srand, %function;
srand:
.globl srand48
.type srand48, %function;
srand48:
.globl srandom
.type srandom, %function;
srandom:
.globl sscanf
.type sscanf, %function;
sscanf:
.globl stat
.type stat, %function;
stat:
.weak statfs
.type statfs, %function;
statfs:
.globl statvfs
.type statvfs, %function;
statvfs:
.globl statx
.type statx, %function;
statx:
.globl stime
.type stime, %function;
stime:
.weak stpcpy
.type stpcpy, %function;
stpcpy:
.weak stpncpy
.type stpncpy, %function;
stpncpy:
.globl strcasecmp
.type strcasecmp, %function;
strcasecmp:
.weak strcasecmp_l
.type strcasecmp_l, %function;
strcasecmp_l:
.globl strcasestr
.type strcasestr, %function;
strcasestr:
.globl strcat
.type strcat, %function;
strcat:
.globl strchr
.type strchr, %function;
strchr:
.weak strchrnul
.type strchrnul, %function;
strchrnul:
.globl strcmp
.type strcmp, %function;
strcmp:
.globl strcoll
.type strcoll, %function;
strcoll:
.weak strcoll_l
.type strcoll_l, %function;
strcoll_l:
.globl strcpy
.type strcpy, %function;
strcpy:
.globl strcspn
.type strcspn, %function;
strcspn:
.globl strdup
.type strdup, %function;
strdup:
.globl strerror
.type strerror, %function;
strerror:
.weak strerror_l
.type strerror_l, %function;
strerror_l:
.globl strerror_r
.type strerror_r, %function;
strerror_r:
.globl strfmon
.type strfmon, %function;
strfmon:
.globl strfmon_l
.type strfmon_l, %function;
strfmon_l:
.globl strftime
.type strftime, %function;
strftime:
.weak strftime_l
.type strftime_l, %function;
strftime_l:
.globl strlcat
.type strlcat, %function;
strlcat:
.globl strlcpy
.type strlcpy, %function;
strlcpy:
.globl strlen
.type strlen, %function;
strlen:
.globl strncasecmp
.type strncasecmp, %function;
strncasecmp:
.weak strncasecmp_l
.type strncasecmp_l, %function;
strncasecmp_l:
.globl strncat
.type strncat, %function;
strncat:
.globl strncmp
.type strncmp, %function;
strncmp:
.globl strncpy
.type strncpy, %function;
strncpy:
.globl strndup
.type strndup, %function;
strndup:
.globl strnlen
.type strnlen, %function;
strnlen:
.globl strpbrk
.type strpbrk, %function;
strpbrk:
.globl strptime
.type strptime, %function;
strptime:
.globl strrchr
.type strrchr, %function;
strrchr:
.globl strsep
.type strsep, %function;
strsep:
.globl strsignal
.type strsignal, %function;
strsignal:
.globl strspn
.type strspn, %function;
strspn:
.globl strstr
.type strstr, %function;
strstr:
.globl strtod
.type strtod, %function;
strtod:
.globl strtod_l
.type strtod_l, %function;
strtod_l:
.globl strtof
.type strtof, %function;
strtof:
.globl strtof_l
.type strtof_l, %function;
strtof_l:
.globl strtoimax
.type strtoimax, %function;
strtoimax:
.globl strtok
.type strtok, %function;
strtok:
.globl strtok_r
.type strtok_r, %function;
strtok_r:
.globl strtol
.type strtol, %function;
strtol:
.globl strtold
.type strtold, %function;
strtold:
.globl strtold_l
.type strtold_l, %function;
strtold_l:
.globl strtoll
.type strtoll, %function;
strtoll:
.globl strtoul
.type strtoul, %function;
strtoul:
.globl strtoull
.type strtoull, %function;
strtoull:
.globl strtoumax
.type strtoumax, %function;
strtoumax:
.globl strverscmp
.type strverscmp, %function;
strverscmp:
.globl strxfrm
.type strxfrm, %function;
strxfrm:
.weak strxfrm_l
.type strxfrm_l, %function;
strxfrm_l:
.globl swab
.type swab, %function;
swab:
.globl swapoff
.type swapoff, %function;
swapoff:
.globl swapon
.type swapon, %function;
swapon:
.globl swprintf
.type swprintf, %function;
swprintf:
.globl swscanf
.type swscanf, %function;
swscanf:
.globl symlink
.type symlink, %function;
symlink:
.globl symlinkat
.type symlinkat, %function;
symlinkat:
.globl sync
.type sync, %function;
sync:
.globl sync_file_range
.type sync_file_range, %function;
sync_file_range:
.globl syncfs
.type syncfs, %function;
syncfs:
.globl syscall
.type syscall, %function;
syscall:
.globl sysconf
.type sysconf, %function;
sysconf:
.weak sysinfo
.type sysinfo, %function;
sysinfo:
.globl syslog
.type syslog, %function;
syslog:
.globl system
.type system, %function;
system:
.globl tan
.type tan, %function;
tan:
.globl tanf
.type tanf, %function;
tanf:
.globl tanh
.type tanh, %function;
tanh:
.globl tanhf
.type tanhf, %function;
tanhf:
.globl tanhl
.type tanhl, %function;
tanhl:
.globl tanl
.type tanl, %function;
tanl:
.globl tcdrain
.type tcdrain, %function;
tcdrain:
.globl tcflow
.type tcflow, %function;
tcflow:
.globl tcflush
.type tcflush, %function;
tcflush:
.globl tcgetattr
.type tcgetattr, %function;
tcgetattr:
.globl tcgetpgrp
.type tcgetpgrp, %function;
tcgetpgrp:
.globl tcgetsid
.type tcgetsid, %function;
tcgetsid:
.globl tcgetwinsize
.type tcgetwinsize, %function;
tcgetwinsize:
.globl tcsendbreak
.type tcsendbreak, %function;
tcsendbreak:
.globl tcsetattr
.type tcsetattr, %function;
tcsetattr:
.globl tcsetpgrp
.type tcsetpgrp, %function;
tcsetpgrp:
.globl tcsetwinsize
.type tcsetwinsize, %function;
tcsetwinsize:
.globl tdelete
.type tdelete, %function;
tdelete:
.globl tdestroy
.type tdestroy, %function;
tdestroy:
.globl tee
.type tee, %function;
tee:
.globl telldir
.type telldir, %function;
telldir:
.globl tempnam
.type tempnam, %function;
tempnam:
.globl textdomain
.type textdomain, %function;
textdomain:
.globl tfind
.type tfind, %function;
tfind:
.globl tgamma
.type tgamma, %function;
tgamma:
.globl tgammaf
.type tgammaf, %function;
tgammaf:
.globl tgammal
.type tgammal, %function;
tgammal:
.globl thrd_create
.type thrd_create, %function;
thrd_create:
.weak thrd_current
.type thrd_current, %function;
thrd_current:
.weak thrd_detach
.type thrd_detach, %function;
thrd_detach:
.weak thrd_equal
.type thrd_equal, %function;
thrd_equal:
.globl thrd_exit
.type thrd_exit, %function;
thrd_exit:
.globl thrd_join
.type thrd_join, %function;
thrd_join:
.globl thrd_sleep
.type thrd_sleep, %function;
thrd_sleep:
.globl thrd_yield
.type thrd_yield, %function;
thrd_yield:
.globl time
.type time, %function;
time:
.globl timegm
.type timegm, %function;
timegm:
.globl timer_create
.type timer_create, %function;
timer_create:
.globl timer_delete
.type timer_delete, %function;
timer_delete:
.globl timer_getoverrun
.type timer_getoverrun, %function;
timer_getoverrun:
.globl timer_gettime
.type timer_gettime, %function;
timer_gettime:
.globl timer_settime
.type timer_settime, %function;
timer_settime:
.globl timerfd_create
.type timerfd_create, %function;
timerfd_create:
.globl timerfd_gettime
.type timerfd_gettime, %function;
timerfd_gettime:
.globl timerfd_settime
.type timerfd_settime, %function;
timerfd_settime:
.globl times
.type times, %function;
times:
.globl timespec_get
.type timespec_get, %function;
timespec_get:
.globl tmpfile
.type tmpfile, %function;
tmpfile:
.globl tmpnam
.type tmpnam, %function;
tmpnam:
.globl toascii
.type toascii, %function;
toascii:
.globl tolower
.type tolower, %function;
tolower:
.weak tolower_l
.type tolower_l, %function;
tolower_l:
.globl toupper
.type toupper, %function;
toupper:
.weak toupper_l
.type toupper_l, %function;
toupper_l:
.globl towctrans
.type towctrans, %function;
towctrans:
.weak towctrans_l
.type towctrans_l, %function;
towctrans_l:
.globl towlower
.type towlower, %function;
towlower:
.weak towlower_l
.type towlower_l, %function;
towlower_l:
.globl towupper
.type towupper, %function;
towupper:
.weak towupper_l
.type towupper_l, %function;
towupper_l:
.globl trunc
.type trunc, %function;
trunc:
.globl truncate
.type truncate, %function;
truncate:
.globl truncf
.type truncf, %function;
truncf:
.globl truncl
.type truncl, %function;
truncl:
.globl tsearch
.type tsearch, %function;
tsearch:
.globl tss_create
.type tss_create, %function;
tss_create:
.globl tss_delete
.type tss_delete, %function;
tss_delete:
.weak tss_get
.type tss_get, %function;
tss_get:
.globl tss_set
.type tss_set, %function;
tss_set:
.globl ttyname
.type ttyname, %function;
ttyname:
.globl ttyname_r
.type ttyname_r, %function;
ttyname_r:
.globl twalk
.type twalk, %function;
twalk:
.weak tzset
.type tzset, %function;
tzset:
.globl ualarm
.type ualarm, %function;
ualarm:
.globl ulckpwdf
.type ulckpwdf, %function;
ulckpwdf:
.globl ulimit
.type ulimit, %function;
ulimit:
.globl umask
.type umask, %function;
umask:
.globl umount
.type umount, %function;
umount:
.globl umount2
.type umount2, %function;
umount2:
.globl uname
.type uname, %function;
uname:
.globl ungetc
.type ungetc, %function;
ungetc:
.globl ungetwc
.type ungetwc, %function;
ungetwc:
.globl unlink
.type unlink, %function;
unlink:
.globl unlinkat
.type unlinkat, %function;
unlinkat:
.globl unlockpt
.type unlockpt, %function;
unlockpt:
.globl unsetenv
.type unsetenv, %function;
unsetenv:
.globl unshare
.type unshare, %function;
unshare:
.weak updwtmp
.type updwtmp, %function;
updwtmp:
.globl updwtmpx
.type updwtmpx, %function;
updwtmpx:
.weak uselocale
.type uselocale, %function;
uselocale:
.globl usleep
.type usleep, %function;
usleep:
.globl utime
.type utime, %function;
utime:
.globl utimensat
.type utimensat, %function;
utimensat:
.globl utimes
.type utimes, %function;
utimes:
.weak utmpname
.type utmpname, %function;
utmpname:
.weak utmpxname
.type utmpxname, %function;
utmpxname:
.globl valloc
.type valloc, %function;
valloc:
.globl vasprintf
.type vasprintf, %function;
vasprintf:
.globl vdprintf
.type vdprintf, %function;
vdprintf:
.globl verr
.type verr, %function;
verr:
.globl verrx
.type verrx, %function;
verrx:
.globl versionsort
.type versionsort, %function;
versionsort:
.globl vfork
.type vfork, %function;
vfork:
.globl vfprintf
.type vfprintf, %function;
vfprintf:
.globl vfscanf
.type vfscanf, %function;
vfscanf:
.globl vfwprintf
.type vfwprintf, %function;
vfwprintf:
.globl vfwscanf
.type vfwscanf, %function;
vfwscanf:
.globl vhangup
.type vhangup, %function;
vhangup:
.globl vmsplice
.type vmsplice, %function;
vmsplice:
.globl vprintf
.type vprintf, %function;
vprintf:
.globl vscanf
.type vscanf, %function;
vscanf:
.globl vsnprintf
.type vsnprintf, %function;
vsnprintf:
.globl vsprintf
.type vsprintf, %function;
vsprintf:
.globl vsscanf
.type vsscanf, %function;
vsscanf:
.globl vswprintf
.type vswprintf, %function;
vswprintf:
.globl vswscanf
.type vswscanf, %function;
vswscanf:
.weak vsyslog
.type vsyslog, %function;
vsyslog:
.globl vwarn
.type vwarn, %function;
vwarn:
.globl vwarnx
.type vwarnx, %function;
vwarnx:
.globl vwprintf
.type vwprintf, %function;
vwprintf:
.globl vwscanf
.type vwscanf, %function;
vwscanf:
.globl wait
.type wait, %function;
wait:
.globl wait3
.type wait3, %function;
wait3:
.globl wait4
.type wait4, %function;
wait4:
.globl waitid
.type waitid, %function;
waitid:
.globl waitpid
.type waitpid, %function;
waitpid:
.globl warn
.type warn, %function;
warn:
.globl warnx
.type warnx, %function;
warnx:
.globl wcpcpy
.type wcpcpy, %function;
wcpcpy:
.globl wcpncpy
.type wcpncpy, %function;
wcpncpy:
.globl wcrtomb
.type wcrtomb, %function;
wcrtomb:
.globl wcscasecmp
.type wcscasecmp, %function;
wcscasecmp:
.globl wcscasecmp_l
.type wcscasecmp_l, %function;
wcscasecmp_l:
.globl wcscat
.type wcscat, %function;
wcscat:
.globl wcschr
.type wcschr, %function;
wcschr:
.globl wcscmp
.type wcscmp, %function;
wcscmp:
.globl wcscoll
.type wcscoll, %function;
wcscoll:
.weak wcscoll_l
.type wcscoll_l, %function;
wcscoll_l:
.globl wcscpy
.type wcscpy, %function;
wcscpy:
.globl wcscspn
.type wcscspn, %function;
wcscspn:
.globl wcsdup
.type wcsdup, %function;
wcsdup:
.globl wcsftime
.type wcsftime, %function;
wcsftime:
.weak wcsftime_l
.type wcsftime_l, %function;
wcsftime_l:
.globl wcslen
.type wcslen, %function;
wcslen:
.globl wcsncasecmp
.type wcsncasecmp, %function;
wcsncasecmp:
.globl wcsncasecmp_l
.type wcsncasecmp_l, %function;
wcsncasecmp_l:
.globl wcsncat
.type wcsncat, %function;
wcsncat:
.globl wcsncmp
.type wcsncmp, %function;
wcsncmp:
.globl wcsncpy
.type wcsncpy, %function;
wcsncpy:
.globl wcsnlen
.type wcsnlen, %function;
wcsnlen:
.globl wcsnrtombs
.type wcsnrtombs, %function;
wcsnrtombs:
.globl wcspbrk
.type wcspbrk, %function;
wcspbrk:
.globl wcsrchr
.type wcsrchr, %function;
wcsrchr:
.globl wcsrtombs
.type wcsrtombs, %function;
wcsrtombs:
.globl wcsspn
.type wcsspn, %function;
wcsspn:
.globl wcsstr
.type wcsstr, %function;
wcsstr:
.globl wcstod
.type wcstod, %function;
wcstod:
.globl wcstof
.type wcstof, %function;
wcstof:
.globl wcstoimax
.type wcstoimax, %function;
wcstoimax:
.globl wcstok
.type wcstok, %function;
wcstok:
.globl wcstol
.type wcstol, %function;
wcstol:
.globl wcstold
.type wcstold, %function;
wcstold:
.globl wcstoll
.type wcstoll, %function;
wcstoll:
.globl wcstombs
.type wcstombs, %function;
wcstombs:
.globl wcstoul
.type wcstoul, %function;
wcstoul:
.globl wcstoull
.type wcstoull, %function;
wcstoull:
.globl wcstoumax
.type wcstoumax, %function;
wcstoumax:
.globl wcswcs
.type wcswcs, %function;
wcswcs:
.globl wcswidth
.type wcswidth, %function;
wcswidth:
.globl wcsxfrm
.type wcsxfrm, %function;
wcsxfrm:
.weak wcsxfrm_l
.type wcsxfrm_l, %function;
wcsxfrm_l:
.globl wctob
.type wctob, %function;
wctob:
.globl wctomb
.type wctomb, %function;
wctomb:
.globl wctrans
.type wctrans, %function;
wctrans:
.weak wctrans_l
.type wctrans_l, %function;
wctrans_l:
.globl wctype
.type wctype, %function;
wctype:
.weak wctype_l
.type wctype_l, %function;
wctype_l:
.globl wcwidth
.type wcwidth, %function;
wcwidth:
.globl wmemchr
.type wmemchr, %function;
wmemchr:
.globl wmemcmp
.type wmemcmp, %function;
wmemcmp:
.globl wmemcpy
.type wmemcpy, %function;
wmemcpy:
.globl wmemmove
.type wmemmove, %function;
wmemmove:
.globl wmemset
.type wmemset, %function;
wmemset:
.globl wordexp
.type wordexp, %function;
wordexp:
.globl wordfree
.type wordfree, %function;
wordfree:
.globl wprintf
.type wprintf, %function;
wprintf:
.globl write
.type write, %function;
write:
.globl writev
.type writev, %function;
writev:
.globl wscanf
.type wscanf, %function;
wscanf:
.globl y0
.type y0, %function;
y0:
.globl y0f
.type y0f, %function;
y0f:
.globl y1
.type y1, %function;
y1:
.globl y1f
.type y1f, %function;
y1f:
.globl yn
.type yn, %function;
yn:
.globl ynf
.type ynf, %function;
ynf:
