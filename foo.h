#ifndef FOO_H
#define FOO_H


#ifdef __cplusplus
#define FOO_EXTERN_C extern "C"
#else
#define FOO_EXTERN_C
#endif

#if defined(_WIN32)
#define FOO_EXPORT FOO_EXTERN_C __declspec(dllimport)
#else
#define FOO_EXPORT FOO_EXTERN_C __attribute__((visibility ("default")))
#endif

FOO_EXPORT double foo_strict(double x);
FOO_EXPORT double foo_optimized(double x);

#endif
