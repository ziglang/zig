#ifndef _STDLIB_H

#ifndef _ISOMAC
# include <stdbool.h>
# include <stddef.h>
#endif

/* Workaround PR90731 with GCC 9 when using ldbl redirects in C++.  */
#include <bits/floatn.h>
#if defined __cplusplus && __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI == 1
# if __GNUC_PREREQ (9, 0) && !__GNUC_PREREQ (9, 3)
#   pragma GCC system_header
# endif
#endif

#include <stdlib/stdlib.h>

/* Now define the internal interfaces.  */
#if !defined _ISOMAC
# include <sys/stat.h>

# include <rtld-malloc.h>
# include <internal-sigset.h>

extern __typeof (strtol_l) __strtol_l;
extern __typeof (strtoul_l) __strtoul_l;
extern __typeof (strtoll_l) __strtoll_l;
extern __typeof (strtoull_l) __strtoull_l;
extern __typeof (strtod_l) __strtod_l;
extern __typeof (strtof_l) __strtof_l;
extern __typeof (strtold_l) __strtold_l;
libc_hidden_proto (__strtol_l)
libc_hidden_proto (__strtoul_l)
libc_hidden_proto (__strtoll_l)
libc_hidden_proto (__strtoull_l)
libc_hidden_proto (__strtod_l)
libc_hidden_proto (__strtof_l)
libc_hidden_proto (__strtold_l)

extern __typeof (strtol) __isoc23_strtol __attribute_copy__ (strtol);
extern __typeof (strtoul) __isoc23_strtoul __attribute_copy__ (strtoul);
extern __typeof (strtoll) __isoc23_strtoll __attribute_copy__ (strtoll);
extern __typeof (strtoull) __isoc23_strtoull __attribute_copy__ (strtoull);
extern __typeof (strtol_l) __isoc23_strtol_l __attribute_copy__ (strtol_l);
extern __typeof (strtoul_l) __isoc23_strtoul_l __attribute_copy__ (strtoul_l);
extern __typeof (strtoll_l) __isoc23_strtoll_l __attribute_copy__ (strtoll_l);
extern __typeof (strtoull_l) __isoc23_strtoull_l __attribute_copy__ (strtoull_l);
libc_hidden_proto (__isoc23_strtol)
libc_hidden_proto (__isoc23_strtoul)
libc_hidden_proto (__isoc23_strtoll)
libc_hidden_proto (__isoc23_strtoull)
libc_hidden_proto (__isoc23_strtol_l)
libc_hidden_proto (__isoc23_strtoul_l)
libc_hidden_proto (__isoc23_strtoll_l)
libc_hidden_proto (__isoc23_strtoull_l)

#if __GLIBC_USE (C23_STRTOL)
/* Redirect internal uses of these functions to the C23 versions; the
   redirection in the installed header does not work with
   libc_hidden_proto.  */
# undef strtol
# define strtol __isoc23_strtol
# undef atoi
# define atoi(nptr) __isoc23_strtol(nptr, NULL, 10)
# undef strtoul
# define strtoul __isoc23_strtoul
# undef strtoll
# define strtoll __isoc23_strtoll
# undef strtoull
# define strtoull __isoc23_strtoull
# undef strtol_l
# define strtol_l __isoc23_strtol_l
# undef strtoul_l
# define strtoul_l __isoc23_strtoul_l
# undef strtoll_l
# define strtoll_l __isoc23_strtoll_l
# undef strtoull_l
# define strtoull_l __isoc23_strtoull_l
#endif

extern void __abort_fork_reset_child (void) attribute_hidden;
extern void __abort_lock_rdlock (internal_sigset_t *set) attribute_hidden;
extern void __abort_lock_wrlock (internal_sigset_t *set) attribute_hidden;
extern void __abort_lock_unlock (const internal_sigset_t *set)
     attribute_hidden;

libc_hidden_proto (exit)
libc_hidden_proto (abort)
libc_hidden_proto (getenv)
extern __typeof (secure_getenv) __libc_secure_getenv;
libc_hidden_proto (__libc_secure_getenv)
libc_hidden_proto (bsearch)
libc_hidden_proto (qsort)
extern __typeof (qsort_r) __qsort_r;
libc_hidden_proto (__qsort_r)
libc_hidden_proto (lrand48_r)
libc_hidden_proto (wctomb)

extern long int __random (void) attribute_hidden;
extern void __srandom (unsigned int __seed);
extern char *__initstate (unsigned int __seed, char *__statebuf,
			  size_t __statelen);
extern char *__setstate (char *__statebuf);
extern int __random_r (struct random_data *__buf, int32_t *__result)
     attribute_hidden;
extern int __srandom_r (unsigned int __seed, struct random_data *__buf)
     attribute_hidden;
extern int __initstate_r (unsigned int __seed, char *__statebuf,
			  size_t __statelen, struct random_data *__buf)
     attribute_hidden;
extern int __setstate_r (char *__statebuf, struct random_data *__buf)
     attribute_hidden;
extern int __rand_r (unsigned int *__seed);
extern int __erand48_r (unsigned short int __xsubi[3],
			struct drand48_data *__buffer, double *__result)
     attribute_hidden;
extern int __nrand48_r (unsigned short int __xsubi[3],
			struct drand48_data *__buffer,
			long int *__result) attribute_hidden;
extern int __jrand48_r (unsigned short int __xsubi[3],
			struct drand48_data *__buffer,
			long int *__result) attribute_hidden;
extern int __srand48_r (long int __seedval,
			struct drand48_data *__buffer) attribute_hidden;
extern int __seed48_r (unsigned short int __seed16v[3],
		       struct drand48_data *__buffer) attribute_hidden;
extern int __lcong48_r (unsigned short int __param[7],
			struct drand48_data *__buffer) attribute_hidden;

/* Internal function to compute next state of the generator.  */
extern int __drand48_iterate (unsigned short int __xsubi[3],
			      struct drand48_data *__buffer)
     attribute_hidden;

/* Global state for non-reentrant functions.  Defined in drand48-iter.c.  */
extern struct drand48_data __libc_drand48_data attribute_hidden;

extern int __setenv (const char *__name, const char *__value, int __replace)
     attribute_hidden;
extern int __unsetenv (const char *__name) attribute_hidden;
extern int __clearenv (void) attribute_hidden;
extern char *__mktemp (char *__template) __THROW __nonnull ((1));
libc_hidden_proto (__mktemp)
extern char *__canonicalize_file_name (const char *__name);
extern char *__realpath (const char *__name, char *__resolved);
libc_hidden_proto (__realpath)
extern int __ptsname_r (int __fd, char *__buf, size_t __buflen)
     attribute_hidden;
# ifndef _ISOMAC
extern int __ptsname_internal (int fd, char *buf, size_t buflen,
			       struct stat64 *stp) attribute_hidden;
# endif
extern int __getpt (void);
extern int __posix_openpt (int __oflag) attribute_hidden;

extern int __add_to_environ (const char *name, const char *value,
			     const char *combines, int replace)
     attribute_hidden;

extern int __on_exit (void (*__func) (int __status, void *__arg), void *__arg);

extern int __cxa_atexit (void (*func) (void *), void *arg, void *d);
libc_hidden_proto (__cxa_atexit);

extern int __cxa_thread_atexit_impl (void (*func) (void *), void *arg,
				     void *d);
extern void __call_tls_dtors (void);
libc_hidden_proto (__call_tls_dtors)

extern void __cxa_finalize (void *d);

extern int __posix_memalign (void **memptr, size_t alignment, size_t size);

extern void *__libc_memalign (size_t alignment, size_t size)
     __attribute_malloc__;

extern void *__libc_reallocarray (void *__ptr, size_t __nmemb, size_t __size)
     __THROW __attribute_warn_unused_result__;
libc_hidden_proto (__libc_reallocarray)

extern int __libc_system (const char *line);

extern __typeof (getpt) __getpt;
extern __typeof (ptsname_r) __ptsname_r;
libc_hidden_proto (__getpt)
libc_hidden_proto (__ptsname_r)
libc_hidden_proto (grantpt)
libc_hidden_proto (unlockpt)

__typeof (arc4random) __arc4random;
libc_hidden_proto (__arc4random);
__typeof (arc4random_buf) __arc4random_buf;
libc_hidden_proto (__arc4random_buf);
__typeof (arc4random_uniform) __arc4random_uniform;
libc_hidden_proto (__arc4random_uniform);
extern void __arc4random_buf_internal (void *buffer, size_t len)
     attribute_hidden;

extern double __strtod_internal (const char *__restrict __nptr,
				 char **__restrict __endptr, int __group)
     __THROW __nonnull ((1)) __wur;
extern float __strtof_internal (const char *__restrict __nptr,
				char **__restrict __endptr, int __group)
     __THROW __nonnull ((1)) __wur;
extern long double __strtold_internal (const char *__restrict __nptr,
				       char **__restrict __endptr,
				       int __group)
     __THROW __nonnull ((1)) __wur;
extern long int __strtol_internal (const char *__restrict __nptr,
				   char **__restrict __endptr,
				   int __base, int __group)
     __THROW __nonnull ((1)) __wur;
extern unsigned long int __strtoul_internal (const char *__restrict __nptr,
					     char **__restrict __endptr,
					     int __base, int __group)
     __THROW __nonnull ((1)) __wur;
__extension__
extern long long int __strtoll_internal (const char *__restrict __nptr,
					 char **__restrict __endptr,
					 int __base, int __group)
     __THROW __nonnull ((1)) __wur;
__extension__
extern unsigned long long int __strtoull_internal (const char *
						   __restrict __nptr,
						   char **__restrict __endptr,
						   int __base, int __group)
     __THROW __nonnull ((1)) __wur;
libc_hidden_proto (__strtof_internal)
libc_hidden_proto (__strtod_internal)
libc_hidden_proto (__strtold_internal)
libc_hidden_proto (__strtol_internal)
libc_hidden_proto (__strtoll_internal)
libc_hidden_proto (__strtoul_internal)
libc_hidden_proto (__strtoull_internal)

extern double ____strtod_l_internal (const char *__restrict __nptr,
				     char **__restrict __endptr, int __group,
				     locale_t __loc);
extern float ____strtof_l_internal (const char *__restrict __nptr,
				    char **__restrict __endptr, int __group,
				    locale_t __loc);
extern long double ____strtold_l_internal (const char *__restrict __nptr,
					   char **__restrict __endptr,
					   int __group, locale_t __loc);
extern long int ____strtol_l_internal (const char *__restrict __nptr,
				       char **__restrict __endptr,
				       int __base, int __group,
				       bool __bin_cst, locale_t __loc);
extern unsigned long int ____strtoul_l_internal (const char *
						 __restrict __nptr,
						 char **__restrict __endptr,
						 int __base, int __group,
						 bool __bin_cst,
						 locale_t __loc);
__extension__
extern long long int ____strtoll_l_internal (const char *__restrict __nptr,
					     char **__restrict __endptr,
					     int __base, int __group,
					     bool __bin_cst, locale_t __loc);
__extension__
extern unsigned long long int ____strtoull_l_internal (const char *
						       __restrict __nptr,
						       char **
						       __restrict __endptr,
						       int __base, int __group,
						       bool __bin_cst,
						       locale_t __loc);

libc_hidden_proto (____strtof_l_internal)
libc_hidden_proto (____strtod_l_internal)
libc_hidden_proto (____strtold_l_internal)
libc_hidden_proto (____strtol_l_internal)
libc_hidden_proto (____strtoll_l_internal)
libc_hidden_proto (____strtoul_l_internal)
libc_hidden_proto (____strtoull_l_internal)

#include <bits/floatn.h>
libc_hidden_proto (strtof)
libc_hidden_proto (strtod)
#if __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI == 0
libc_hidden_proto (strtold)
#endif
libc_hidden_proto (strtol)
libc_hidden_proto (strtoll)
libc_hidden_proto (strtoul)
libc_hidden_proto (strtoull)

libc_hidden_proto (atoi)

extern float __strtof_nan (const char *, char **, char);
extern double __strtod_nan (const char *, char **, char);
extern long double __strtold_nan (const char *, char **, char);
extern float __wcstof_nan (const wchar_t *, wchar_t **, wchar_t);
extern double __wcstod_nan (const wchar_t *, wchar_t **, wchar_t);
extern long double __wcstold_nan (const wchar_t *, wchar_t **, wchar_t);

libc_hidden_proto (__strtof_nan)
libc_hidden_proto (__strtod_nan)
libc_hidden_proto (__strtold_nan)
libc_hidden_proto (__wcstof_nan)
libc_hidden_proto (__wcstod_nan)
libc_hidden_proto (__wcstold_nan)

/* Enable _FloatN bits as needed.  */
#include <bits/floatn.h>

#if __HAVE_DISTINCT_FLOAT128
extern __typeof (strtof128_l) __strtof128_l;

libc_hidden_proto (__strtof128_l)
libc_hidden_proto (strtof128)

extern _Float128 __strtof128_nan (const char *, char **, char);
extern _Float128 __wcstof128_nan (const wchar_t *, wchar_t **, wchar_t);

libc_hidden_proto (__strtof128_nan)
libc_hidden_proto (__wcstof128_nan)

extern _Float128 __strtof128_internal (const char *__restrict __nptr,
				       char **__restrict __endptr,
				       int __group);
libc_hidden_proto (__strtof128_internal)

extern _Float128 ____strtof128_l_internal (const char *__restrict __nptr,
					   char **__restrict __endptr,
					   int __group, locale_t __loc);

libc_hidden_proto (____strtof128_l_internal)
#endif

extern char *__ecvt (double __value, int __ndigit, int *__restrict __decpt,
		     int *__restrict __sign);
extern char *__fcvt (double __value, int __ndigit, int *__restrict __decpt,
		     int *__restrict __sign);
extern char *__gcvt (double __value, int __ndigit, char *__buf);
extern int __ecvt_r (double __value, int __ndigit, int *__restrict __decpt,
		     int *__restrict __sign, char *__restrict __buf,
		     size_t __len);
libc_hidden_proto (__ecvt_r)
extern int __fcvt_r (double __value, int __ndigit, int *__restrict __decpt,
		     int *__restrict __sign, char *__restrict __buf,
		     size_t __len);
libc_hidden_proto (__fcvt_r)
extern char *__qecvt (long double __value, int __ndigit,
		      int *__restrict __decpt, int *__restrict __sign);
extern char *__qfcvt (long double __value, int __ndigit,
		      int *__restrict __decpt, int *__restrict __sign);
extern char *__qgcvt (long double __value, int __ndigit, char *__buf);
extern int __qecvt_r (long double __value, int __ndigit,
		      int *__restrict __decpt, int *__restrict __sign,
		      char *__restrict __buf, size_t __len);
libc_hidden_proto (__qecvt_r)
extern int __qfcvt_r (long double __value, int __ndigit,
		      int *__restrict __decpt, int *__restrict __sign,
		      char *__restrict __buf, size_t __len);
libc_hidden_proto (__qfcvt_r)

# if IS_IN (libc)
#  undef MB_CUR_MAX
#  define MB_CUR_MAX (_NL_CURRENT_WORD (LC_CTYPE, _NL_CTYPE_MB_CUR_MAX))
# endif

struct abort_msg_s
{
  unsigned int size;
  char msg[0];
};
extern struct abort_msg_s *__abort_msg;
libc_hidden_proto (__abort_msg)

# if IS_IN (rtld)
extern __typeof (unsetenv) unsetenv attribute_hidden;
extern __typeof (__strtoul_internal) __strtoul_internal attribute_hidden;
# endif

#endif

#endif  /* include/stdlib.h */
