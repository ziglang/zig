#include <stdlib.h>
#include <string.h>
#include "src/cjkcodecs/multibytecodec.h"
#include "src/cjkcodecs/fixnames.h"


struct pypy_cjk_dec_s *pypy_cjk_dec_new(const MultibyteCodec *codec)
{
  struct pypy_cjk_dec_s *d = malloc(sizeof(struct pypy_cjk_dec_s));
  if (!d)
    return NULL;
  if (codec->decinit != NULL && codec->decinit(&d->state, codec->config) != 0)
    {
      free(d);
      return NULL;
    }
  d->codec = codec;
  d->outbuf_start = NULL;
  return d;
}

Py_ssize_t pypy_cjk_dec_init(struct pypy_cjk_dec_s *d,
                             char *inbuf, Py_ssize_t inlen)
{
  d->inbuf_start = (unsigned char *)inbuf;
  d->inbuf = (unsigned char *)inbuf;
  d->inbuf_end = (unsigned char *)inbuf + inlen;
  if (d->outbuf_start == NULL)
    {
      d->outbuf_start = (inlen <= (PY_SSIZE_T_MAX / sizeof(Py_UNICODE)) ?
                         malloc(inlen * sizeof(Py_UNICODE)) :
                         NULL);
      if (d->outbuf_start == NULL)
        return -1;
      d->outbuf_end = d->outbuf_start + inlen;
    }
  d->outbuf = d->outbuf_start;
  return 0;
}

void pypy_cjk_dec_free(struct pypy_cjk_dec_s *d)
{
  free(d->outbuf_start);
  free(d);
}

static int expand_decodebuffer(struct pypy_cjk_dec_s *d, Py_ssize_t esize)
{
  Py_ssize_t orgpos, orgsize;
  Py_UNICODE *newbuf;

  orgpos = d->outbuf - d->outbuf_start;
  orgsize = d->outbuf_end - d->outbuf_start;
  esize = (esize < (orgsize >> 1) ? (orgsize >> 1) | 1 : esize);
  newbuf = (esize <= (PY_SSIZE_T_MAX / sizeof(Py_UNICODE) - orgsize) ?
            realloc(d->outbuf_start, (orgsize + esize) * sizeof(Py_UNICODE)) :
            NULL);
  if (!newbuf)
    return -1;
  d->outbuf_start = newbuf;
  d->outbuf = newbuf + orgpos;
  d->outbuf_end = newbuf + orgsize + esize;
  return 0;
}

Py_ssize_t pypy_cjk_dec_chunk(struct pypy_cjk_dec_s *d)
{
  while (1)
    {
      Py_ssize_t r;
      Py_ssize_t inleft = (Py_ssize_t)(d->inbuf_end - d->inbuf);
      Py_ssize_t outleft = (Py_ssize_t)(d->outbuf_end - d->outbuf);
      if (inleft == 0)
        return 0;
      r = d->codec->decode(&d->state, d->codec->config,
                           &d->inbuf, inleft, &d->outbuf, outleft);
      if (r != MBERR_TOOSMALL)
        return r;
      /* output buffer too small; grow it and continue. */
      if (expand_decodebuffer(d, -1) == -1)
        return MBERR_NOMEMORY;
    }
}

Py_UNICODE *pypy_cjk_dec_outbuf(struct pypy_cjk_dec_s *d)
{
  return d->outbuf_start;
}

Py_ssize_t pypy_cjk_dec_outlen(struct pypy_cjk_dec_s *d)
{
  return d->outbuf - d->outbuf_start;
}

Py_ssize_t pypy_cjk_dec_inbuf_remaining(struct pypy_cjk_dec_s *d)
{
  return d->inbuf_end - d->inbuf;
}

Py_ssize_t pypy_cjk_dec_inbuf_consumed(struct pypy_cjk_dec_s* d)
{
  return d->inbuf - d->inbuf_start;
}

Py_ssize_t pypy_cjk_dec_replace_on_error(struct pypy_cjk_dec_s* d,
                                         Py_UNICODE *newbuf, Py_ssize_t newlen,
                                         Py_ssize_t in_offset)
{
  if (newlen > 0)
    {
      if (d->outbuf + newlen > d->outbuf_end)
        if (expand_decodebuffer(d, newlen) == -1)
          return MBERR_NOMEMORY;
      memcpy(d->outbuf, newbuf, newlen * sizeof(Py_UNICODE));
      d->outbuf += newlen;
    }
  d->inbuf = d->inbuf_start + in_offset;
  return 0;
}

/************************************************************/

struct pypy_cjk_enc_s *pypy_cjk_enc_new(const MultibyteCodec *codec)
{
  struct pypy_cjk_enc_s *d = malloc(sizeof(struct pypy_cjk_enc_s));
  if (!d)
    return NULL;
  if (codec->encinit != NULL && codec->encinit(&d->state, codec->config) != 0)
    {
      free(d);
      return NULL;
    }
  d->codec = codec;
  d->outbuf_start = NULL;
  return d;
}

void pypy_cjk_enc_copystate(struct pypy_cjk_enc_s *dst, struct pypy_cjk_enc_s *src)
{
    dst->state = src->state;
}

Py_ssize_t pypy_cjk_enc_init(struct pypy_cjk_enc_s *d,
                             Py_UNICODE *inbuf, Py_ssize_t inlen)
{
  Py_ssize_t outlen;
  d->inbuf_start = inbuf;
  d->inbuf = inbuf;
  d->inbuf_end = inbuf + inlen;
  if (d->outbuf_start == NULL)
    {
      if (inlen > (PY_SSIZE_T_MAX - 16) / 2)
        return -1;
      outlen = inlen * 2 + 16;
      d->outbuf_start = malloc(outlen);
      if (d->outbuf_start == NULL)
        return -1;
      d->outbuf_end = d->outbuf_start + outlen;
    }
  d->outbuf = d->outbuf_start;
  return 0;
}

void pypy_cjk_enc_free(struct pypy_cjk_enc_s *d)
{
  free(d->outbuf_start);
  free(d);
}

static int expand_encodebuffer(struct pypy_cjk_enc_s *d, Py_ssize_t esize)
{
  Py_ssize_t orgpos, orgsize;
  unsigned char *newbuf;

  orgpos = d->outbuf - d->outbuf_start;
  orgsize = d->outbuf_end - d->outbuf_start;
  esize = (esize < (orgsize >> 1) ? (orgsize >> 1) | 1 : esize);
  newbuf = (esize <= PY_SSIZE_T_MAX - orgsize ?
            realloc(d->outbuf_start, orgsize + esize) :
            NULL);
  if (!newbuf)
    return -1;
  d->outbuf_start = newbuf;
  d->outbuf = newbuf + orgpos;
  d->outbuf_end = newbuf + orgsize + esize;
  return 0;
}

Py_ssize_t pypy_cjk_enc_chunk(struct pypy_cjk_enc_s *d, Py_ssize_t flags)
{
  while (1)
    {
      Py_ssize_t r;
      Py_ssize_t inleft = (Py_ssize_t)(d->inbuf_end - d->inbuf);
      Py_ssize_t outleft = (Py_ssize_t)(d->outbuf_end - d->outbuf);
      if (inleft == 0 && !(flags & MBENC_RESET))
        return 0;
      r = d->codec->encode(&d->state, d->codec->config,
                           &d->inbuf, inleft, &d->outbuf, outleft, flags);
      if (r != MBERR_TOOSMALL)
        return r;
      /* output buffer too small; grow it and continue. */
      if (expand_encodebuffer(d, -1) == -1)
        return MBERR_NOMEMORY;
    }
}

Py_ssize_t pypy_cjk_enc_reset(struct pypy_cjk_enc_s *d)
{
  if (d->codec->encreset == NULL)
    return 0;

  while (1)
    {
      Py_ssize_t r;
      Py_ssize_t outleft = (Py_ssize_t)(d->outbuf_end - d->outbuf);
      r = d->codec->encreset(&d->state, d->codec->config, &d->outbuf, outleft);
      if (r != MBERR_TOOSMALL)
        return r;
      /* output buffer too small; grow it and continue. */
      if (expand_encodebuffer(d, -1) == -1)
        return MBERR_NOMEMORY;
    }
}

char *pypy_cjk_enc_outbuf(struct pypy_cjk_enc_s *d)
{
  return (char *)d->outbuf_start;
}

Py_ssize_t pypy_cjk_enc_outlen(struct pypy_cjk_enc_s *d)
{
  return d->outbuf - d->outbuf_start;
}

Py_ssize_t pypy_cjk_enc_inbuf_remaining(struct pypy_cjk_enc_s *d)
{
  return d->inbuf_end - d->inbuf;
}

Py_ssize_t pypy_cjk_enc_inbuf_consumed(struct pypy_cjk_enc_s* d)
{
  return d->inbuf - d->inbuf_start;
}

Py_ssize_t pypy_cjk_enc_replace_on_error(struct pypy_cjk_enc_s* d,
                                         char *newbuf, Py_ssize_t newlen,
                                         Py_ssize_t in_offset)
{
  if (newlen > 0)
    {
      if (d->outbuf + newlen > d->outbuf_end)
        if (expand_encodebuffer(d, newlen) == -1)
          return MBERR_NOMEMORY;
      memcpy(d->outbuf, newbuf, newlen);
      d->outbuf += newlen;
    }
  d->inbuf = d->inbuf_start + in_offset;
  return 0;
}

const MultibyteCodec *pypy_cjk_enc_getcodec(struct pypy_cjk_enc_s *d)
{
  return d->codec;
}
