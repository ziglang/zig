#if __STDC_VERSION__ >= 201112L
#define noreturn _Noreturn
#elif __GNUC__
#define noreturn __attribute__ ((noreturn))
#elif _MSC_VER
#define noreturn __declspec(noreturn)
#else
#define noreturn
#endif

