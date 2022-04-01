#include "utf8.h"

#include <stddef.h>
#include <stdio.h>
#include <stdint.h>
#include <xmmintrin.h>
#include <smmintrin.h>

#define BIT(B,P) ((B >> (P-1)) & 0x1)

void _print_mmx(const char * msg, __m128i chunk)
{
    printf("%s:", msg);
    // unpack the first 8 bytes, padding with zeros
    uint64_t a = _mm_extract_epi64(chunk, 0);
    uint64_t b = _mm_extract_epi64(chunk, 1);
    printf("%.2x%.2x%.2x%.2x %.2x%.2x%.2x%.2x  %.2x%.2x%.2x%.2x %.2x%.2x%.2x%.2x",
            (unsigned char)((a >> 0) & 0xff),
            (unsigned char)((a >> 8) & 0xff),
            (unsigned char)((a >> 16) & 0xff),
            (unsigned char)((a >> 24) & 0xff),

            (unsigned char)((a >> 32) & 0xff),
            (unsigned char)((a >> 40) & 0xff),
            (unsigned char)((a >> 48) & 0xff),
            (unsigned char)((a >> 56) & 0xff),

            (unsigned char)((b >> 0) & 0xff),
            (unsigned char)((b >> 8) & 0xff),
            (unsigned char)((b >> 16) & 0xff),
            (unsigned char)((b >> 24) & 0xff),

            (unsigned char)((b >> 32) & 0xff),
            (unsigned char)((b >> 40) & 0xff),
            (unsigned char)((b >> 48) & 0xff),
            (unsigned char)((b >> 56) & 0xff)
     );

    printf("\n");
}


ssize_t fu8_count_utf8_codepoints_sse4(const char * utf8, size_t len)
{
    const uint8_t * encoded = (const uint8_t*)utf8;
    __builtin_prefetch(encoded, 0, 0);
    size_t num_codepoints = 0;
    __m128i chunk;

    if (len == 0) {
        return 0;
    }
    __m128i zero = _mm_set1_epi8(0x00);

    while (len >= 16) {
        chunk = _mm_loadu_si128((__m128i*)encoded);
        if (_mm_movemask_epi8(chunk) == 0) {
            // valid ascii chars!
            len -= 16;
            encoded += 16;
            num_codepoints += 16;
            continue;
        }
        __builtin_prefetch(encoded+16, 0, 0);

        __m128i count = _mm_set1_epi8(0x1);
        //_print_mmx("chunk", chunk);
        // fight against the fact that there is no comparison on unsigned values
        __m128i chunk_signed = _mm_add_epi8(chunk, _mm_set1_epi8(0x80));
        //_print_mmx("shunk", chunk_signed);

        // ERROR checking
        // checking procedure works the following way:
        //
        // 1) mark all continuation bytes with either 0x1, 0x3, 0x7 (one, two or three bytes continuation)
        // 2) then check that there is no byte that has an invalid continuation
        __m128i twobytemarker = _mm_cmplt_epi8(_mm_set1_epi8(0xc0-1-0x80), chunk_signed);
        __m128i threebytemarker = _mm_cmplt_epi8(_mm_set1_epi8(0xe0-1-0x80), chunk_signed);
        __m128i fourbytemarker = _mm_cmplt_epi8(_mm_set1_epi8(0xf0-1-0x80), chunk_signed);

        // the general idea of the following code collects 0xff for each byte position
        // in the variable contbytes.
        // at the end check if each position in contbytes set to 0xff is a valid continuation byte

        // check that 0xc0 > 0xc2
        __m128i validtwobm = _mm_cmplt_epi8(_mm_set1_epi8(0xc2-1-0x80), chunk_signed);
        if (_mm_movemask_epi8(_mm_xor_si128(validtwobm, twobytemarker)) != 0) {
            // two byte marker should not be in range [0xc0-0xc2)
            return -1;
        }

        __m128i state2 = _mm_andnot_si128(threebytemarker, twobytemarker);
        __m128i contbytes = _mm_slli_si128(_mm_blendv_epi8(state2, _mm_set1_epi8(0x1), twobytemarker), 1);

        if (_mm_movemask_epi8(threebytemarker) != 0) {
            // contains at least one 3 byte marker
            __m128i istate3 = _mm_andnot_si128(fourbytemarker, threebytemarker);
            __m128i state3 = _mm_slli_si128(_mm_blendv_epi8(zero, _mm_set1_epi8(0x3), istate3), 1);
            state3 = _mm_or_si128(state3, _mm_slli_si128(state3, 1));

            contbytes = _mm_or_si128(contbytes, state3);

            // range check
            __m128i equal_e0 = _mm_cmpeq_epi8(_mm_blendv_epi8(zero, chunk_signed, istate3),
                                              _mm_set1_epi8(0xe0-0x80));
            if (_mm_movemask_epi8(equal_e0) != 0) {
                __m128i mask = _mm_blendv_epi8(_mm_set1_epi8(0x7f), chunk_signed, _mm_slli_si128(equal_e0, 1));
                __m128i check_surrogate = _mm_cmplt_epi8(mask, _mm_set1_epi8(0xa0-0x80));
                if (_mm_movemask_epi8(check_surrogate) != 0) {
                    // invalid surrograte character!!!
                    return -1;
                }
            }

            // verify that there are now surrogates
            if (!ALLOW_SURROGATES) {
                __m128i equal_ed = _mm_cmpeq_epi8(_mm_blendv_epi8(zero, chunk_signed, istate3),
                                                  _mm_set1_epi8(0xed-0x80));
                if (_mm_movemask_epi8(equal_ed) != 0) {
                    __m128i mask = _mm_blendv_epi8(_mm_set1_epi8(0x80), chunk_signed, _mm_slli_si128(equal_ed, 1));
                    __m128i check_surrogate = _mm_cmpgt_epi8(mask, _mm_set1_epi8(0xa0-1-0x80));
                    if (_mm_movemask_epi8(check_surrogate) != 0) {
                        // invalid surrograte character!!!
                        return -1;
                    }
                }
            }
        }

        if (_mm_movemask_epi8(fourbytemarker) != 0) {
            // contain a 4 byte marker
            __m128i istate4 = _mm_slli_si128(_mm_blendv_epi8(zero, _mm_set1_epi8(0x7), fourbytemarker), 1);
            __m128i state4 =_mm_or_si128(istate4, _mm_slli_si128(istate4, 1));
            state4 =_mm_or_si128(state4, _mm_slli_si128(istate4, 2));

            contbytes = _mm_or_si128(contbytes, state4);

            // range check, filter out f0 and 
            __m128i equal_f0 = _mm_cmpeq_epi8(_mm_blendv_epi8(zero, chunk_signed, fourbytemarker),
                                              _mm_set1_epi8(0xf0-0x80));
            if (_mm_movemask_epi8(equal_f0) != 0) {
                __m128i mask = _mm_blendv_epi8(_mm_set1_epi8(0x7f), chunk_signed, _mm_slli_si128(equal_f0, 1));
                __m128i check_surrogate = _mm_cmplt_epi8(mask, _mm_set1_epi8(0x90-0x80));
                if (_mm_movemask_epi8(check_surrogate) != 0) {
                    return -1;
                }
            }

            __m128i equal_f4 = _mm_cmpeq_epi8(_mm_blendv_epi8(zero, chunk_signed, fourbytemarker),
                                              _mm_set1_epi8(0xf4-0x80));
            if (_mm_movemask_epi8(equal_f4) != 0) {
                __m128i mask = _mm_blendv_epi8(_mm_set1_epi8(0x80), chunk_signed, _mm_slli_si128(equal_f4, 1));
                __m128i check_surrogate = _mm_cmpgt_epi8(mask, _mm_set1_epi8(0x90-1-0x80));
                if (_mm_movemask_epi8(check_surrogate) != 0) {
                    return -1;
                }
            }

            __m128i equal_f5_gt = _mm_cmpgt_epi8(_mm_blendv_epi8(zero, chunk_signed, fourbytemarker),
                                              _mm_set1_epi8(0xf4-0x80));
            if (_mm_movemask_epi8(equal_f5_gt) != 0) {
                return -1;
            }
        }

        // now check that contbytes and the actual byte values have a valid
        // continuation at each position the marker indicates to have one
        __m128i check_cont = _mm_cmpgt_epi8(contbytes, zero);
        __m128i contpos = _mm_and_si128(_mm_set1_epi8(0xc0), chunk);
        contpos = _mm_cmpeq_epi8(_mm_set1_epi8(0x80), contpos);
        __m128i validcont = _mm_xor_si128(check_cont, contpos);
        if (_mm_movemask_epi8(validcont) != 0) {
            // uff, nope, that is really not utf8
            return -1;
        }

        // CORRECT, calculate the length
        // copy 0x00 over to each place which is a continuation byte
        count = _mm_blendv_epi8(count, zero, contpos);

        // count the code points using 2x 32 bit hadd and one last 16 hadd
        // the result will end up at the lowest position
        count = _mm_hadd_epi32(count, count);
        count = _mm_hadd_epi32(count, count);
        count = _mm_hadd_epi16(count, count);
        uint16_t c = _mm_extract_epi16(count, 0);

        // these cases need to be handled:
        //                      16 byte boundary -> | <- 16 byte boundary
        // -----------------------------------------+--------------------
        // 1) 2 byte code point. e.g. ...  c2       | 80 ...
        // 2) 3 byte code point. e.g. ...  e6       | 80 80 ...
        // 3) 3 byte code point. e.g. ...  e6 80    | 80 ...
        // 4) 4 byte code point. e.g. ...  f2       | 80 80 80 ...
        // 5) 4 byte code point. e.g. ...  f2 80    | 80 80 ...
        // 6) 4 byte code point. e.g. ...  f2 80 80 | 80 ...
        //
        int mask_chunk = _mm_movemask_epi8(chunk);
        int mask_conti = _mm_movemask_epi8(contpos);

        // little endian
        int lenoff = 16;
        int minus_codepoints = 0;
        if (BIT(mask_chunk, 16) != 0 && BIT(mask_conti, 16) == 0) { // 1), 2), 4)
            minus_codepoints = 1;
            lenoff -= 1;
        } else if (BIT(mask_chunk, 15) != 0 && BIT(mask_conti, 15) == 0 &&
                   BIT(mask_conti, 16) == 1) { // 3), 5)
            minus_codepoints = 1;
            lenoff -= 2;
        } else if (BIT(mask_chunk, 14) != 0 && BIT(mask_conti, 14) == 0 &&
                   BIT(mask_conti, 15) == 1 && BIT(mask_conti, 16) == 1) { // 6)
            minus_codepoints = 1;
            lenoff -= 3;
        }

        num_codepoints += (c & 0xff) + ((c >> 8) & 0xff) - minus_codepoints;
        len -= lenoff;
        encoded += lenoff;
    }

    if (len == 0) {
        return num_codepoints;
    }

    ssize_t result = fu8_count_utf8_codepoints_seq(encoded, len);
    if (result == -1) {
        return -1;
    }

    return num_codepoints + result;
}

ssize_t fu8_idx2bytepos_sse4(size_t index,
                             const uint8_t * utf8, size_t len,
                             struct fu8_idxtab * t)
{
    return 0;
}
