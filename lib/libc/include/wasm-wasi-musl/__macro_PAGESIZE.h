#ifndef __wasilibc___macro_PAGESIZE_h
#define __wasilibc___macro_PAGESIZE_h

/*
 * The page size in WebAssembly is fixed at 64 KiB. If this ever changes,
 * it's expected that applications will need to opt in, so we can change
 * this.
 *
 * If this ever needs to be a value outside the range of an `int`, the
 * `getpagesize` function which returns this value will need special
 * consideration. POSIX has deprecated `getpagesize` in favor of
 * `sysconf(_SC_PAGESIZE)` which does not have this problem.
 */
#define PAGESIZE (0x10000)

#endif
