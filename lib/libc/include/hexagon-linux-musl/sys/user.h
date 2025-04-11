#ifndef _SYS_USER_H
#define _SYS_USER_H
#ifdef __cplusplus
extern "C" {
#endif

#include <limits.h>
#include <stdint.h>
#include <unistd.h>

#include <bits/alltypes.h>

#undef __WORDSIZE
#if __LONG_MAX == 0x7fffffffL
#define __WORDSIZE 32
#else
#define __WORDSIZE 64
#endif

#include <bits/user.h>

#ifdef __cplusplus
}
#endif
#endif