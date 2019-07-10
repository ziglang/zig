/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#ifndef _WINBER_DEFINED_
#define _WINBER_DEFINED_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _WINBER_
#define WINBERAPI DECLSPEC_IMPORT
#else
#define WINBERAPI
#endif

#ifndef BERAPI
#define BERAPI __cdecl
#endif

#define LBER_ERROR __MSABI_LONG(0xffffffff)
#define LBER_DEFAULT __MSABI_LONG(0xffffffff)

  typedef unsigned int ber_tag_t;
  typedef int ber_int_t;
  typedef unsigned int ber_uint_t;
  typedef unsigned int ber_len_t;
  typedef int ber_slen_t;

  WINBERAPI BerElement *BERAPI ber_init (BERVAL *pBerVal);
  WINBERAPI VOID BERAPI ber_free (BerElement *pBerElement, INT fbuf);
  WINBERAPI VOID BERAPI ber_bvfree (BERVAL *pBerVal);
  WINBERAPI VOID BERAPI ber_bvecfree (PBERVAL *pBerVal);
  WINBERAPI BERVAL *BERAPI ber_bvdup (BERVAL *pBerVal);
  WINBERAPI BerElement *BERAPI ber_alloc_t (INT options);
  WINBERAPI ULONG BERAPI ber_skip_tag (BerElement *pBerElement, ULONG *pLen);
  WINBERAPI ULONG BERAPI ber_peek_tag (BerElement *pBerElement, ULONG *pLen);
  WINBERAPI ULONG BERAPI ber_first_element (BerElement *pBerElement, ULONG *pLen, CHAR **ppOpaque);
  WINBERAPI ULONG BERAPI ber_next_element (BerElement *pBerElement, ULONG *pLen, CHAR *opaque);
  WINBERAPI INT BERAPI ber_flatten (BerElement *pBerElement, PBERVAL *pBerVal);
  WINBERAPI INT BERAPI ber_printf (BerElement *pBerElement, PSTR fmt,...);
  WINBERAPI ULONG BERAPI ber_scanf (BerElement *pBerElement, PSTR fmt,...);

#ifdef __cplusplus
}
#endif

#endif

#endif
