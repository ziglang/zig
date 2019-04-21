#ifndef __wasm_basics___macro_PAGESIZE_h
#define __wasm_basics___macro_PAGESIZE_h

/*
 * The page size in WebAssembly is fixed at 64 KiB. If this ever changes,
 * it's expected that applications will need to opt in, so we can change
 * this.
 */
#define PAGESIZE (0x10000)

#endif
