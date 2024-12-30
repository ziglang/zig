/* Determine the wordsize from the preprocessor defines.  */

#if defined __powerpc64__
# define __WORDSIZE	64
#else
# define __WORDSIZE	32
# define __WORDSIZE32_SIZE_ULONG	0
# define __WORDSIZE32_PTRDIFF_LONG	0
#endif
#define __WORDSIZE_TIME64_COMPAT32	1