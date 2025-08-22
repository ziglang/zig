#include <string.h>
#include <stdint.h>
#include <limits.h>

#ifdef __wasm_simd128__
#include <wasm_simd128.h>
#endif

#define ALIGN (sizeof(size_t))
#define ONES ((size_t)-1/UCHAR_MAX)
#define HIGHS (ONES * (UCHAR_MAX/2+1))
#define HASZERO(x) ((x)-ONES & ~(x) & HIGHS)

char *__strchrnul(const char *s, int c)
{
	c = (unsigned char)c;
	if (!c) return (char *)s + strlen(s);

#if defined(__wasm_simd128__) && defined(__wasilibc_simd_string)
	// Skip Clang 19 and Clang 20 which have a bug (llvm/llvm-project#146574)
	// which results in an ICE when inline assembly is used with a vector result.
#if __clang_major__ != 19 && __clang_major__ != 20
	// Note that reading before/after the allocation of a pointer is UB in
	// C, so inline assembly is used to generate the exact machine
	// instruction we want with opaque semantics to the compiler to avoid
	// the UB.
	uintptr_t align = (uintptr_t)s % sizeof(v128_t);
	uintptr_t addr = (uintptr_t)s - align;
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
		const v128_t cmp = wasm_i8x16_eq(v, (v128_t){}) | wasm_i8x16_eq(v, vc);
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
				return (char *)s + (addr - (uintptr_t)s + __builtin_ctz(mask));
			}
		}
		align = 0;
		addr += sizeof(v128_t);
	}
#endif
#endif

#ifdef __GNUC__
	typedef size_t __attribute__((__may_alias__)) word;
	const word *w;
	for (; (uintptr_t)s % ALIGN; s++)
		if (!*s || *(unsigned char *)s == c) return (char *)s;
	size_t k = ONES * c;
	for (w = (void *)s; !HASZERO(*w) && !HASZERO(*w^k); w++);
	s = (void *)w;
#endif
	for (; *s && *(unsigned char *)s != c; s++);
	return (char *)s;
}

weak_alias(__strchrnul, strchrnul);
