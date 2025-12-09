/*-
 * This file is in the public domain.
 */
#ifndef MAXPHYS
#ifdef __ILP32__
#define MAXPHYS		(128 * 1024)
#else
#define MAXPHYS		(1024 * 1024)
#endif
#endif