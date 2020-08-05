/*===--------------- amxintrin.h - AMX intrinsics -*- C/C++ -*---------------===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===------------------------------------------------------------------------===
 */

#ifndef __IMMINTRIN_H
#error "Never use <amxintrin.h> directly; include <immintrin.h> instead."
#endif /* __IMMINTRIN_H */

#ifndef __AMXINTRIN_H
#define __AMXINTRIN_H
#ifdef __x86_64__

#define __DEFAULT_FN_ATTRS \
  __attribute__((__always_inline__, __nodebug__,  __target__("amx-tile")))

/// Load tile configuration from a 64-byte memory location specified by
/// "mem_addr". The tile configuration includes the tile type palette, the
/// number of bytes per row, and the number of rows. If the specified
/// palette_id is zero, that signifies the init state for both the tile
/// config and the tile data, and the tiles are zeroed. Any invalid
/// configurations will result in #GP fault.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> LDTILECFG </c> instruction.
///
/// \param __config
///    A pointer to 512-bits configuration
static __inline__ void __DEFAULT_FN_ATTRS
_tile_loadconfig(const void *__config)
{
  __builtin_ia32_tile_loadconfig(__config);
}

/// Stores the current tile configuration to a 64-byte memory location
/// specified by "mem_addr". The tile configuration includes the tile type
/// palette, the number of bytes per row, and the number of rows. If tiles
/// are not configured, all zeroes will be stored to memory.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> STTILECFG </c> instruction.
///
/// \param __config
///    A pointer to 512-bits configuration
static __inline__ void __DEFAULT_FN_ATTRS
_tile_storeconfig(void *__config)
{
  __builtin_ia32_tile_storeconfig(__config);
}

/// Release the tile configuration to return to the init state, which
/// releases all storage it currently holds.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> TILERELEASE </c> instruction.
static __inline__ void __DEFAULT_FN_ATTRS
_tile_release(void)
{
  __builtin_ia32_tilerelease();
}

/// Load tile rows from memory specifieid by "base" address and "stride" into
/// destination tile "dst" using the tile configuration previously configured
/// via "_tile_loadconfig".
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> TILELOADD </c> instruction.
///
/// \param dst
///    A destination tile. Max size is 1024 Bytes.
/// \param base
///    A pointer to base address.
/// \param stride
///    The stride between the rows' data to be loaded in memory.
#define _tile_loadd(dst, base, stride) \
  __builtin_ia32_tileloadd64((dst), ((const void *)(base)), (__SIZE_TYPE__)(stride))

/// Load tile rows from memory specifieid by "base" address and "stride" into
/// destination tile "dst" using the tile configuration previously configured
/// via "_tile_loadconfig". This intrinsic provides a hint to the implementation
/// that the data will likely not be reused in the near future and the data
/// caching can be optimized accordingly.
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> TILELOADDT1 </c> instruction.
///
/// \param dst
///    A destination tile. Max size is 1024 Bytes.
/// \param base
///    A pointer to base address.
/// \param stride
///    The stride between the rows' data to be loaded in memory.
#define _tile_stream_loadd(dst, base, stride) \
  __builtin_ia32_tileloaddt164((dst), ((const void *)(base)), (__SIZE_TYPE__)(stride))

/// Store the tile specified by "src" to memory specifieid by "base" address and
/// "stride" using the tile configuration previously configured via
/// "_tile_loadconfig".
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> TILESTORED </c> instruction.
///
/// \param dst
///    A destination tile. Max size is 1024 Bytes.
/// \param base
///    A pointer to base address.
/// \param stride
///    The stride between the rows' data to be stored in memory.
#define _tile_stored(dst, base, stride) \
  __builtin_ia32_tilestored64((dst), ((void *)(base)), (__SIZE_TYPE__)(stride))

/// Zero the tile specified by "tdest".
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> TILEZERO </c> instruction.
///
/// \param tile
///    The destination tile to be zero. Max size is 1024 Bytes.
#define _tile_zero(tile) __builtin_ia32_tilezero((tile))

/// Compute dot-product of bytes in tiles with a source/destination accumulator.
/// Multiply groups of 4 adjacent pairs of signed 8-bit integers in src0 with
/// corresponding signed 8-bit integers in src1, producing 4 intermediate 32-bit
/// results. Sum these 4 results with the corresponding 32-bit integer in "dst",
/// and store the 32-bit result back to tile "dst".
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> TDPBSSD </c> instruction.
///
/// \param dst
///    The destination tile. Max size is 1024 Bytes.
/// \param src0
///    The 1st source tile. Max size is 1024 Bytes.
/// \param src1
///    The 2nd source tile. Max size is 1024 Bytes.
#define _tile_dpbssd(dst, src0, src1) __builtin_ia32_tdpbssd((dst), (src0), (src1))

/// Compute dot-product of bytes in tiles with a source/destination accumulator.
/// Multiply groups of 4 adjacent pairs of signed 8-bit integers in src0 with
/// corresponding unsigned 8-bit integers in src1, producing 4 intermediate
/// 32-bit results. Sum these 4 results with the corresponding 32-bit integer
/// in "dst", and store the 32-bit result back to tile "dst".
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> TDPBSUD </c> instruction.
///
/// \param dst
///    The destination tile. Max size is 1024 Bytes.
/// \param src0
///    The 1st source tile. Max size is 1024 Bytes.
/// \param src1
///    The 2nd source tile. Max size is 1024 Bytes.
#define _tile_dpbsud(dst, src0, src1) __builtin_ia32_tdpbsud((dst), (src0), (src1))

/// Compute dot-product of bytes in tiles with a source/destination accumulator.
/// Multiply groups of 4 adjacent pairs of unsigned 8-bit integers in src0 with
/// corresponding signed 8-bit integers in src1, producing 4 intermediate 32-bit
/// results. Sum these 4 results with the corresponding 32-bit integer in "dst",
/// and store the 32-bit result back to tile "dst".
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> TDPBUSD </c> instruction.
///
/// \param dst
///    The destination tile. Max size is 1024 Bytes.
/// \param src0
///    The 1st source tile. Max size is 1024 Bytes.
/// \param src1
///    The 2nd source tile. Max size is 1024 Bytes.
#define _tile_dpbusd(dst, src0, src1) __builtin_ia32_tdpbusd((dst), (src0), (src1))

/// Compute dot-product of bytes in tiles with a source/destination accumulator.
/// Multiply groups of 4 adjacent pairs of unsigned 8-bit integers in src0 with
/// corresponding unsigned 8-bit integers in src1, producing 4 intermediate
/// 32-bit results. Sum these 4 results with the corresponding 32-bit integer in
/// "dst", and store the 32-bit result back to tile "dst".
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> TDPBUUD </c> instruction.
///
/// \param dst
///    The destination tile. Max size is 1024 Bytes.
/// \param src0
///    The 1st source tile. Max size is 1024 Bytes.
/// \param src1
///    The 2nd source tile. Max size is 1024 Bytes.
#define _tile_dpbuud(dst, src0, src1) __builtin_ia32_tdpbuud((dst), (src0), (src1))

/// Compute dot-product of BF16 (16-bit) floating-point pairs in tiles src0 and
/// src1, accumulating the intermediate single-precision (32-bit) floating-point
/// elements with elements in "dst", and store the 32-bit result back to tile
/// "dst".
///
/// \headerfile <x86intrin.h>
///
/// This intrinsic corresponds to the <c> TDPBF16PS </c> instruction.
///
/// \param dst
///    The destination tile. Max size is 1024 Bytes.
/// \param src0
///    The 1st source tile. Max size is 1024 Bytes.
/// \param src1
///    The 2nd source tile. Max size is 1024 Bytes.
#define _tile_dpbf16ps(dst, src0, src1) \
  __builtin_ia32_tdpbf16ps((dst), (src0), (src1))

#undef __DEFAULT_FN_ATTRS

#endif /* __x86_64__ */
#endif /* __AMXINTRIN_H */
