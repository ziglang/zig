#ifndef __wasilibc___macro_PAGESIZE_h
#define __wasilibc___macro_PAGESIZE_h

/*
 * Without custom-page-sizes proposal, the page size in WebAssembly
 * is fixed at 64 KiB.
 *
 * The LLVM versions with a support of custom-page-sizes proposal
 * provides __wasm_first_page_end global to allow page-size-agnostic
 * objects.
 *
 * If this ever needs to be a value outside the range of an `int`, the
 * `getpagesize` function which returns this value will need special
 * consideration. POSIX has deprecated `getpagesize` in favor of
 * `sysconf(_SC_PAGESIZE)` which does not have this problem.
 */
#if __clang_major__ >= 22
extern char __wasm_first_page_end;
#define PAGESIZE ((unsigned long)&__wasm_first_page_end)
#else
#define PAGESIZE (0x10000)
#endif

#endif
