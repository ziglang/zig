#ifndef _STDLIB_H

#ifndef _ISOMAC
# include <stddef.h>
#endif
#include <stdlib/stdlib.h>

/* Now define the internal interfaces.  */
#if !defined _ISOMAC
# include <sys/stat.h>

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
extern void _quicksort (void *const pbase, size_t total_elems,
			size_t size, __compar_d_fn_t cmp, void *arg);

extern int __on_exit (void (*__func) (int __status, void *__arg), void *__arg);

extern int __cxa_atexit (void (*func) (void *), void *arg, void *d);
libc_hidden_proto (__cxa_atexit);

extern int __cxa_thread_atexit_impl (void (*func) (void *), void *arg,
				     void *d);
extern void __call_tls_dtors (void)
#ifndef SHARED
  __attribute__ ((weak))
#endif
  ;
libc_hidden_proto (__call_tls_dtors)

extern void __cxa_finalize (void *d);

extern int __posix_memalign (void **memptr, size_t alignment, size_t size);

extern void *__libc_memalign (size_t alignment, size_t size)
     __attribute_malloc__;

extern void *__libc_reallocarray (void *__ptr, size_t __nmemb, size_t __size)
     __THROW __attribute_warn_unused_result__;
libc_hidden_proto (__libc_reallocarray)

extern int __libc_system (const char *line);


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
				       locale_t __loc);
extern unsigned long int ____strtoul_l_internal (const char *
						 __restrict __nptr,
						 char **__restrict __endptr,
						 int __base, int __group,
						 locale_t __loc);
__extension__
extern long long int ____strtoll_l_internal (const char *__restrict __nptr,
					     char **__restrict __endptr,
					     int __base, int __group,
					     locale_t __loc);
__extension__
extern unsigned long long int ____strtoull_l_internal (const char *
						       __restrict __nptr,
						       char **
						       __restrict __endptr,
						       int __base, int __group,
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
#if __LONG_DOUBLE_USES_FLOAT128 == 0
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

extern void *__default_morecore (ptrdiff_t) __THROW;
libc_hidden_proto (__default_morecore)

struct abort_msg_s
{
  unsigned int size;
  char msg[0];
};
extern struct abort_msg_s *__abort_msg;
libc_hidden_proto (__abort_msg)

# if IS_IN (rtld) && !defined NO_RTLD_HIDDEN
extern __typeof (unsetenv) unsetenv attribute_hidden;
extern __typeof (__strtoul_internal) __strtoul_internal attribute_hidden;
# endif

#endif

#endif  /* include/stdlib.h */
