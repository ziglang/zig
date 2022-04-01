
#ifndef _PYPY_MULTIBYTECODEC_H_
#define _PYPY_MULTIBYTECODEC_H_

#include "src/precommondefs.h"


#include <stddef.h>
#include <assert.h>

#ifdef _WIN64
typedef __int64 pypymbc_ssize_t;
#elif defined(_WIN32)
typedef int pypymbc_ssize_t;
#else
#include <unistd.h>
typedef ssize_t pypymbc_ssize_t;
#endif

#ifdef _WIN32
#define pypymbc_UNICODE_SIZE 2
#else
#define pypymbc_UNICODE_SIZE 4
#endif
typedef wchar_t pypymbc_wchar_t;

#ifdef _WIN32
typedef unsigned int pypymbc_ucs4_t;
typedef unsigned short pypymbc_ucs2_t;
#else
#include <stdint.h>
typedef uint32_t pypymbc_ucs4_t;
typedef uint16_t pypymbc_ucs2_t;
#endif



typedef union {
    void *p;
    int i;
    unsigned char c[8];
    pypymbc_ucs2_t u2[4];
    pypymbc_ucs4_t u4[2];
} MultibyteCodec_State;

typedef int (*mbcodec_init)(const void *config);
typedef pypymbc_ssize_t (*mbencode_func)(MultibyteCodec_State *state,
                        const void *config,
                        const pypymbc_wchar_t **inbuf, pypymbc_ssize_t inleft,
                        unsigned char **outbuf, pypymbc_ssize_t outleft,
                        int flags);
typedef int (*mbencodeinit_func)(MultibyteCodec_State *state,
                                 const void *config);
typedef pypymbc_ssize_t (*mbencodereset_func)(MultibyteCodec_State *state,
                        const void *config,
                        unsigned char **outbuf, pypymbc_ssize_t outleft);
typedef pypymbc_ssize_t (*mbdecode_func)(MultibyteCodec_State *state,
                        const void *config,
                        const unsigned char **inbuf, pypymbc_ssize_t inleft,
                        pypymbc_wchar_t **outbuf, pypymbc_ssize_t outleft);
typedef int (*mbdecodeinit_func)(MultibyteCodec_State *state,
                                 const void *config);
typedef pypymbc_ssize_t (*mbdecodereset_func)(MultibyteCodec_State *state,
                                         const void *config);

typedef struct MultibyteCodec_s {
    const char *encoding;
    const void *config;
    mbcodec_init codecinit;
    mbencode_func encode;
    mbencodeinit_func encinit;
    mbencodereset_func encreset;
    mbdecode_func decode;
    mbdecodeinit_func decinit;
    mbdecodereset_func decreset;
} MultibyteCodec;


/* positive values for illegal sequences */
#define MBERR_TOOSMALL          (-1) /* insufficient output buffer space */
#define MBERR_TOOFEW            (-2) /* incomplete input buffer */
#define MBERR_INTERNAL          (-3) /* internal runtime error */
#define MBERR_NOMEMORY          (-4) /* out of memory */

#define MBENC_FLUSH             0x0001 /* encode all characters encodable */
#define MBENC_RESET             0x0002 /* reset after an encoding session */
#define MBENC_MAX               MBENC_FLUSH


struct pypy_cjk_dec_s {
  const MultibyteCodec *codec;
  MultibyteCodec_State state;
  const unsigned char *inbuf_start, *inbuf, *inbuf_end;
  pypymbc_wchar_t *outbuf_start, *outbuf, *outbuf_end;
};

RPY_EXTERN
struct pypy_cjk_dec_s *pypy_cjk_dec_new(const MultibyteCodec *codec);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_dec_init(struct pypy_cjk_dec_s *d,
                             char *inbuf, pypymbc_ssize_t inlen);
RPY_EXTERN
void pypy_cjk_dec_free(struct pypy_cjk_dec_s *);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_dec_chunk(struct pypy_cjk_dec_s *);
RPY_EXTERN
pypymbc_wchar_t *pypy_cjk_dec_outbuf(struct pypy_cjk_dec_s *);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_dec_outlen(struct pypy_cjk_dec_s *);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_dec_inbuf_remaining(struct pypy_cjk_dec_s *d);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_dec_inbuf_consumed(struct pypy_cjk_dec_s* d);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_dec_replace_on_error(struct pypy_cjk_dec_s* d,
                            pypymbc_wchar_t *, pypymbc_ssize_t, pypymbc_ssize_t);

struct pypy_cjk_enc_s {
  const MultibyteCodec *codec;
  MultibyteCodec_State state;
  const pypymbc_wchar_t *inbuf_start, *inbuf, *inbuf_end;
  unsigned char *outbuf_start, *outbuf, *outbuf_end;
};

RPY_EXTERN
struct pypy_cjk_enc_s *pypy_cjk_enc_new(const MultibyteCodec *codec);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_enc_init(struct pypy_cjk_enc_s *d,
                             pypymbc_wchar_t *inbuf, pypymbc_ssize_t inlen);
RPY_EXTERN
void pypy_cjk_enc_free(struct pypy_cjk_enc_s *);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_enc_chunk(struct pypy_cjk_enc_s *, pypymbc_ssize_t);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_enc_reset(struct pypy_cjk_enc_s *);
RPY_EXTERN
char *pypy_cjk_enc_outbuf(struct pypy_cjk_enc_s *);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_enc_outlen(struct pypy_cjk_enc_s *);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_enc_inbuf_remaining(struct pypy_cjk_enc_s *d);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_enc_inbuf_consumed(struct pypy_cjk_enc_s* d);
RPY_EXTERN
pypymbc_ssize_t pypy_cjk_enc_replace_on_error(struct pypy_cjk_enc_s* d,
                                      char *, pypymbc_ssize_t, pypymbc_ssize_t);
RPY_EXTERN
const MultibyteCodec *pypy_cjk_enc_getcodec(struct pypy_cjk_enc_s *);
RPY_EXTERN
void pypy_cjk_enc_copystate(struct pypy_cjk_enc_s *dst, struct pypy_cjk_enc_s *src);

/* list of codecs defined in the .c files */

#define DEFINE_CODEC(name)                              \
    RPY_EXTERN MultibyteCodec *pypy_cjkcodec_##name(void);

// _codecs_cn
DEFINE_CODEC(gb2312)
DEFINE_CODEC(gbk)
DEFINE_CODEC(gb18030)
DEFINE_CODEC(hz)

//_codecs_hk
DEFINE_CODEC(big5hkscs)

//_codecs_iso2022
DEFINE_CODEC(iso2022_kr)
DEFINE_CODEC(iso2022_jp)
DEFINE_CODEC(iso2022_jp_1)
DEFINE_CODEC(iso2022_jp_2)
DEFINE_CODEC(iso2022_jp_2004)
DEFINE_CODEC(iso2022_jp_3)
DEFINE_CODEC(iso2022_jp_ext)

//_codecs_jp
DEFINE_CODEC(shift_jis)
DEFINE_CODEC(cp932)
DEFINE_CODEC(euc_jp)
DEFINE_CODEC(shift_jis_2004)
DEFINE_CODEC(euc_jis_2004)
DEFINE_CODEC(euc_jisx0213)
DEFINE_CODEC(shift_jisx0213)

//_codecs_kr
DEFINE_CODEC(euc_kr)
DEFINE_CODEC(cp949)
DEFINE_CODEC(johab)

//_codecs_tw
DEFINE_CODEC(big5)
DEFINE_CODEC(cp950)

#undef DEFINE_CODEC


#endif
