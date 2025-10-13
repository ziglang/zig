#ifndef _SYS_REG_H
#define _SYS_REG_H

#include <limits.h>
#include <unistd.h>

#include <bits/alltypes.h>

#undef __WORDSIZE
#if __LONG_MAX == 0x7fffffffL
#define __WORDSIZE 32
#else
#define __WORDSIZE 64
#endif

#include <bits/reg.h>

#endif