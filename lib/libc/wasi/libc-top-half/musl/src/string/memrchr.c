#include <string.h>

#ifdef __wasm_simd128__
#include <wasm_simd128.h>
#endif

void *__memrchr(const void *m, int c, size_t n)
{
#if defined(__wasm_simd128__) && defined(__wasilibc_simd_string)
	// memrchr is allowed to read up to n bytes from the object.
	// Search backward for the last matching character.
	const v128_t *v = (v128_t *)((char *)m + n);
	const v128_t vc = wasm_i8x16_splat(c);
	for (; n >= sizeof(v128_t); n -= sizeof(v128_t)) {
		const v128_t cmp = wasm_i8x16_eq(wasm_v128_load(--v), vc);
		// Bitmask is slow on AArch64, any_true is much faster.
		if (wasm_v128_any_true(cmp)) {
			// Find the offset of the last one bit (little-endian).
			// The leading 16 bits of the bitmask are always zero,
			// and to be ignored.
			size_t clz = __builtin_clz(wasm_i8x16_bitmask(cmp)) - 16;
			return (char *)(v + 1) - (clz + 1);
		}
	}
#endif

	const unsigned char *s = m;
	c = (unsigned char)c;
	while (n--) if (s[n]==c) return (void *)(s+n);
	return 0;
}

weak_alias(__memrchr, memrchr);
