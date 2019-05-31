#if defined(_POSIX_SOURCE) || defined(_POSIX_C_SOURCE) \
 || defined(_XOPEN_SOURCE) || defined(_GNU_SOURCE) || defined(_BSD_SOURCE)
#define PAGESIZE 8192
#define LONG_BIT 32
#endif

#define LONG_MAX  0x7fffffffL
#define LLONG_MAX  0x7fffffffffffffffLL
