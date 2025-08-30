#include <string.h>
#include <stdint.h>
#include <limits.h>

#ifdef __wasm_simd128__
#include <wasm_simd128.h>
#endif

#define SS (sizeof(size_t))
#define ALIGN (sizeof(size_t)-1)
#define ONES ((size_t)-1/UCHAR_MAX)
#define HIGHS (ONES * (UCHAR_MAX/2+1))
#define HASZERO(x) ((x)-ONES & ~(x) & HIGHS)

void *memchr(const void *src, int c, size_t n)
{
#if defined(__wasm_simd128__) && defined(__wasilibc_simd_string)
	// Skip Clang 19 and Clang 20 which have a bug (llvm/llvm-project#146574)
	// which results in an ICE when inline assembly is used with a vector result.
#if __clang_major__ != 19 && __clang_major__ != 20
	// When n is zero, a function that locates a character finds no occurrence.
	// Otherwise, decrement n to ensure sub_overflow overflows
	// when n would go equal-to-or-below zero.
	if (!n--) {
		return NULL;
	}

	// Note that reading before/after the allocation of a pointer is UB in
	// C, so inline assembly is used to generate the exact machine
	// instruction we want with opaque semantics to the compiler to avoid
	// the UB.
	uintptr_t align = (uintptr_t)src % sizeof(v128_t);
	uintptr_t addr = (uintptr_t)src - align;
	v128_t vc = wasm_i8x16_splat(c);

	for (;;) {
		v128_t v;
		__asm__ (
			"local.get %1\n"
			"v128.load 0\n"
			"local.set %0\n"
			: "=r"(v)
			: "r"(addr)
			: "memory");
		v128_t cmp = wasm_i8x16_eq(v, vc);
		// Bitmask is slow on AArch64, any_true is much faster.
		if (wasm_v128_any_true(cmp)) {
			// Clear the bits corresponding to align (little-endian)
			// so we can count trailing zeros.
			int mask = wasm_i8x16_bitmask(cmp) >> align << align;
			// At least one bit will be set, unless align cleared them.
			// Knowing this helps the compiler if it unrolls the loop.
			__builtin_assume(mask || align);
			// If the mask became zero because of align,
			// it's as if we didn't find anything.
			if (mask) {
				// Find the offset of the first one bit (little-endian).
				// That's a match, unless it is beyond the end of the object.
				// Recall that we decremented n, so less-than-or-equal-to is correct.
				size_t ctz = __builtin_ctz(mask);
				return ctz - align <= n ? (char *)src + (addr + ctz - (uintptr_t)src)
				                        : NULL;
			}
		}
		// Decrement n; if it overflows we're done.
		if (__builtin_sub_overflow(n, sizeof(v128_t) - align, &n)) {
			return NULL;
		}
		align = 0;
		addr += sizeof(v128_t);
	}
#endif
#endif

	const unsigned char *s = src;
	c = (unsigned char)c;
#ifdef __GNUC__
	for (; ((uintptr_t)s & ALIGN) && n && *s != c; s++, n--);
	if (n && *s != c) {
		typedef size_t __attribute__((__may_alias__)) word;
		const word *w;
		size_t k = ONES * c;
		for (w = (const void *)s; n>=SS && !HASZERO(*w^k); w++, n-=SS);
		s = (const void *)w;
	}
#endif
	for (; n && *s != c; s++, n--);
	return n ? (void *)s : 0;
}
