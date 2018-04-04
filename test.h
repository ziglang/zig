#ifndef TEST_H
#define TEST_H


#ifdef __cplusplus
#define TEST_EXTERN_C extern "C"
#else
#define TEST_EXTERN_C
#endif

#if defined(_WIN32)
#define TEST_EXPORT TEST_EXTERN_C __declspec(dllimport)
#else
#define TEST_EXPORT TEST_EXTERN_C __attribute__((visibility ("default")))
#endif


#endif
