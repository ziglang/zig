#if __STDC_VERSION__ >= 201112L
#define noreturn _Noreturn
#elif __GNUC__ && !__STRICT_ANSI__
#define noreturn __attribute__ ((noreturn))
#else
#define noreturn
#endif

