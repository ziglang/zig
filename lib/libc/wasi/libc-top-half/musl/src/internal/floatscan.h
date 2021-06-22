#ifndef FLOATSCAN_H
#define FLOATSCAN_H

#include <stdio.h>

#if defined(__wasilibc_printscan_no_long_double)
hidden long_double __floatscan(FILE *, int, int);
#else
hidden long double __floatscan(FILE *, int, int);
#endif

#endif
