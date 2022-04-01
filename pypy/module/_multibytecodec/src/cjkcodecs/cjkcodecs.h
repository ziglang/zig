/*
 * cjkcodecs.h is inspired by the file of the same name from CPython,
 * but was heavily modified to suit PyPy.
 *
 * Original author: Hye-Shik Chang <perky@FreeBSD.org>
 * Modified by: Armin Rigo <arigo@tunes.org>
 */

#ifndef _CJKCODECS_H_
#define _CJKCODECS_H_

#include "src/cjkcodecs/multibytecodec.h"
#include "src/cjkcodecs/fixnames.h"


/* a unicode "undefined" codepoint */
#define UNIINV  0xFFFE

/* internal-use DBCS codepoints which aren't used by any charsets */
#define NOCHAR  0xFFFF
#define MULTIC  0xFFFE
#define DBCINV  0xFFFD

/* shorter macros to save source size of mapping tables */
#define U UNIINV
#define N NOCHAR
#define M MULTIC
#define D DBCINV

struct dbcs_index {
    const ucs2_t *map;
    unsigned char bottom, top;
};
typedef struct dbcs_index decode_map;

struct widedbcs_index {
    const ucs4_t *map;
    unsigned char bottom, top;
};
typedef struct widedbcs_index widedecode_map;

struct unim_index {
    const DBCHAR *map;
    unsigned char bottom, top;
};
typedef struct unim_index encode_map;

struct unim_index_bytebased {
    const unsigned char *map;
    unsigned char bottom, top;
};

struct dbcs_map {
    const char *charset;
    const struct unim_index *encmap;
    const struct dbcs_index *decmap;
};

struct pair_encodemap {
    ucs4_t uniseq;
    DBCHAR code;
};

#define CODEC_INIT(encoding)                                            \
    static int encoding##_codec_init(const void *config)

#define ENCODER_INIT(encoding)                                          \
    static int encoding##_encode_init(                                  \
        MultibyteCodec_State *state, const void *config)
#define ENCODER(encoding)                                               \
    static Py_ssize_t encoding##_encode(                                \
        MultibyteCodec_State *state, const void *config,                \
        const Py_UNICODE **inbuf, Py_ssize_t inleft,                    \
        unsigned char **outbuf, Py_ssize_t outleft, int flags)
#define ENCODER_RESET(encoding)                                         \
    static Py_ssize_t encoding##_encode_reset(                          \
        MultibyteCodec_State *state, const void *config,                \
        unsigned char **outbuf, Py_ssize_t outleft)

#define DECODER_INIT(encoding)                                          \
    static int encoding##_decode_init(                                  \
        MultibyteCodec_State *state, const void *config)
#define DECODER(encoding)                                               \
    static Py_ssize_t encoding##_decode(                                \
        MultibyteCodec_State *state, const void *config,                \
        const unsigned char **inbuf, Py_ssize_t inleft,                 \
        Py_UNICODE **outbuf, Py_ssize_t outleft)
#define DECODER_RESET(encoding)                                         \
    static Py_ssize_t encoding##_decode_reset(                          \
        MultibyteCodec_State *state, const void *config)

#if Py_UNICODE_SIZE == 4
#define UCS4INVALID(code)       \
    if ((code) > 0xFFFF)        \
    return 1;
#else
#define UCS4INVALID(code)       \
    if (0) ;
#endif

#define NEXT_IN(i)                              \
    (*inbuf) += (i);                            \
    (inleft) -= (i);
#define NEXT_OUT(o)                             \
    (*outbuf) += (o);                           \
    (outleft) -= (o);
#define NEXT(i, o)                              \
    NEXT_IN(i) NEXT_OUT(o)

#define REQUIRE_INBUF(n)                        \
    if (inleft < (n))                           \
        return MBERR_TOOFEW;
#define REQUIRE_OUTBUF(n)                       \
    if (outleft < (n))                          \
        return MBERR_TOOSMALL;

#define IN1 ((*inbuf)[0])
#define IN2 ((*inbuf)[1])
#define IN3 ((*inbuf)[2])
#define IN4 ((*inbuf)[3])

#define OUT1(c) ((*outbuf)[0]) = (c);
#define OUT2(c) ((*outbuf)[1]) = (c);
#define OUT3(c) ((*outbuf)[2]) = (c);
#define OUT4(c) ((*outbuf)[3]) = (c);

#define WRITE1(c1)              \
    REQUIRE_OUTBUF(1)           \
    (*outbuf)[0] = (c1);
#define WRITE2(c1, c2)          \
    REQUIRE_OUTBUF(2)           \
    (*outbuf)[0] = (c1);        \
    (*outbuf)[1] = (c2);
#define WRITE3(c1, c2, c3)      \
    REQUIRE_OUTBUF(3)           \
    (*outbuf)[0] = (c1);        \
    (*outbuf)[1] = (c2);        \
    (*outbuf)[2] = (c3);
#define WRITE4(c1, c2, c3, c4)  \
    REQUIRE_OUTBUF(4)           \
    (*outbuf)[0] = (c1);        \
    (*outbuf)[1] = (c2);        \
    (*outbuf)[2] = (c3);        \
    (*outbuf)[3] = (c4);

#if Py_UNICODE_SIZE == 2
# define WRITEUCS4(c)                                           \
    REQUIRE_OUTBUF(2)                                           \
    (*outbuf)[0] = 0xd800 + (((c) - 0x10000) >> 10);            \
    (*outbuf)[1] = 0xdc00 + (((c) - 0x10000) & 0x3ff);          \
    NEXT_OUT(2)
#else
# define WRITEUCS4(c)                                           \
    REQUIRE_OUTBUF(1)                                           \
    **outbuf = (Py_UNICODE)(c);                                 \
    NEXT_OUT(1)
#endif

#define _TRYMAP_ENC(m, assi, val)                               \
    ((m)->map != NULL && (val) >= (m)->bottom &&                \
        (val)<= (m)->top && ((assi) = (m)->map[(val) -          \
        (m)->bottom]) != NOCHAR)
#define TRYMAP_ENC_COND(charset, assi, uni)                     \
    _TRYMAP_ENC(&charset##_encmap[(uni) >> 8], assi, (uni) & 0xff)
#define TRYMAP_ENC(charset, assi, uni)                          \
    if TRYMAP_ENC_COND(charset, assi, uni)

#define _TRYMAP_DEC(m, assi, val)                               \
    ((m)->map != NULL && (val) >= (m)->bottom &&                \
        (val)<= (m)->top && ((assi) = (m)->map[(val) -          \
        (m)->bottom]) != UNIINV)
#define TRYMAP_DEC(charset, assi, c1, c2)                       \
    if _TRYMAP_DEC(&charset##_decmap[c1], assi, c2)

#define _TRYMAP_ENC_MPLANE(m, assplane, asshi, asslo, val)      \
    ((m)->map != NULL && (val) >= (m)->bottom &&                \
        (val)<= (m)->top &&                                     \
        ((assplane) = (m)->map[((val) - (m)->bottom)*3]) != 0 && \
        (((asshi) = (m)->map[((val) - (m)->bottom)*3 + 1]), 1) && \
        (((asslo) = (m)->map[((val) - (m)->bottom)*3 + 2]), 1))
#define TRYMAP_ENC_MPLANE(charset, assplane, asshi, asslo, uni) \
    if _TRYMAP_ENC_MPLANE(&charset##_encmap[(uni) >> 8], \
                       assplane, asshi, asslo, (uni) & 0xff)
#define TRYMAP_DEC_MPLANE(charset, assi, plane, c1, c2)         \
    if _TRYMAP_DEC(&charset##_decmap[plane][c1], assi, c2)

#if Py_UNICODE_SIZE == 2
#define DECODE_SURROGATE(c)                                     \
    if (c >> 10 == 0xd800 >> 10) { /* high surrogate */         \
        REQUIRE_INBUF(2)                                        \
        if (IN2 >> 10 == 0xdc00 >> 10) { /* low surrogate */ \
            c = 0x10000 + ((ucs4_t)(c - 0xd800) << 10) + \
            ((ucs4_t)(IN2) - 0xdc00);                           \
        }                                                       \
    }
#define GET_INSIZE(c)   ((c) > 0xffff ? 2 : 1)
#else
#define DECODE_SURROGATE(c) {;}
#define GET_INSIZE(c)   1
#endif

#define BEGIN_MAPPINGS_LIST /* empty */
#define MAPPING_ENCONLY(enc)                                            \
  RPY_EXTERN const struct dbcs_map pypy_cjkmap_##enc;                   \
  const struct dbcs_map pypy_cjkmap_##enc = {#enc, (void*)enc##_encmap, NULL};
#define MAPPING_DECONLY(enc)                                            \
  RPY_EXTERN const struct dbcs_map pypy_cjkmap_##enc;                   \
  const struct dbcs_map pypy_cjkmap_##enc = {#enc, NULL, (void*)enc##_decmap};
#define MAPPING_ENCDEC(enc)                                             \
  RPY_EXTERN const struct dbcs_map pypy_cjkmap_##enc;                   \
  const struct dbcs_map pypy_cjkmap_##enc = {#enc, (void*)enc##_encmap, \
                                             (void*)enc##_decmap};
#define END_MAPPINGS_LIST /* empty */

#define BEGIN_CODECS_LIST /* empty */
#define _CODEC(name)                                                    \
  static MultibyteCodec _pypy_cjkcodec_##name;                          \
  MultibyteCodec *pypy_cjkcodec_##name(void) {                          \
    if (_pypy_cjkcodec_##name.codecinit != NULL) {                      \
      int r = _pypy_cjkcodec_##name.codecinit(_pypy_cjkcodec_##name.config); \
      assert(r == 0);                                                   \
    }                                                                   \
    return &_pypy_cjkcodec_##name;                                      \
  }                                                                     \
  static MultibyteCodec _pypy_cjkcodec_##name
#define _STATEFUL_METHODS(enc)          \
    enc##_encode,                       \
    enc##_encode_init,                  \
    enc##_encode_reset,                 \
    enc##_decode,                       \
    enc##_decode_init,                  \
    enc##_decode_reset,
#define _STATELESS_METHODS(enc)         \
    enc##_encode, NULL, NULL,           \
    enc##_decode, NULL, NULL,
#define CODEC_STATEFUL(enc) _CODEC(enc) = {     \
    #enc, NULL, NULL,                           \
    _STATEFUL_METHODS(enc)                      \
  };
#define CODEC_STATELESS(enc) _CODEC(enc) = {    \
    #enc, NULL, NULL,                           \
    _STATELESS_METHODS(enc)                     \
  };
#define CODEC_STATELESS_WINIT(enc) _CODEC(enc) = {      \
    #enc, NULL,                                         \
    enc##_codec_init,                                   \
    _STATELESS_METHODS(enc)                             \
  };
#define CODEC_STATELESS_CONFIG(enc, config, baseenc) _CODEC(enc) = {    \
    #enc, config, NULL,                                                 \
    _STATELESS_METHODS(baseenc)                                         \
  };
#define CODEC_STATEFUL_CONFIG(enc, variation, config)   \
  _CODEC(enc##_##variation) = {                         \
    #enc "_" #variation,                                \
    config,                                             \
    enc##_codec_init,                                   \
    _STATEFUL_METHODS(enc)                              \
  };
#define END_CODECS_LIST /* empty */


#ifdef USING_BINARY_PAIR_SEARCH
static DBCHAR
find_pairencmap(ucs2_t body, ucs2_t modifier,
                const struct pair_encodemap *haystack, int haystacksize)
{
    int pos, min, max;
    ucs4_t value = body << 16 | modifier;

    min = 0;
    max = haystacksize;

    for (pos = haystacksize >> 1; min != max; pos = (min + max) >> 1) {
        if (value < haystack[pos].uniseq) {
            if (max != pos) {
                max = pos;
                continue;
            }
        }
        else if (value > haystack[pos].uniseq) {
            if (min != pos) {
                min = pos;
                continue;
            }
        }
        break;
    }

    if (value == haystack[pos].uniseq) {
        return haystack[pos].code;
    }
    return DBCINV;
}
#endif


#ifdef USING_IMPORTED_MAPS
#define USING_IMPORTED_MAP(charset) \
  RPY_EXTERN const struct dbcs_map pypy_cjkmap_##charset;

#define IMPORT_MAP(locale, charset, encmap, decmap)                     \
  importmap(&pypy_cjkmap_##charset, encmap, decmap)

static void importmap(const struct dbcs_map *src, void *encmp,
                      void *decmp)
{
  if (encmp) *(const encode_map **)encmp = src->encmap;
  if (decmp) *(const decode_map **)decmp = src->decmap;
}
#endif


#define I_AM_A_MODULE_FOR(loc) /* empty */


#endif
