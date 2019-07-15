/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __MS_BER_H__
#define __MS_BER_H__

#include <msasn1.h>

#include <pshpack8.h>

#ifdef __cplusplus
extern "C" {
#endif

  extern ASN1_PUBLIC int WINAPI ASN1BEREncCharString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t,ASN1char_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncChar16String(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t,ASN1char16_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncChar32String(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t,ASN1char32_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncOctetString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t len,ASN1octet_t *val);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncBitString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t,ASN1octet_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncDouble(ASN1encoding_t enc,ASN1uint32_t tag,double);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncGeneralizedTime(ASN1encoding_t enc,ASN1uint32_t tag,ASN1generalizedtime_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncS32(ASN1encoding_t enc,ASN1uint32_t tag,ASN1int32_t);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncSX(ASN1encoding_t enc,ASN1uint32_t tag,ASN1intx_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncZeroMultibyteString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1ztcharstring_t);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncMultibyteString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1charstring_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncNull(ASN1encoding_t enc,ASN1uint32_t tag);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncObjectIdentifier(ASN1encoding_t enc,ASN1uint32_t tag,ASN1objectidentifier_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncObjectIdentifier2(ASN1encoding_t enc,ASN1uint32_t tag,ASN1objectidentifier2_t *val);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncRemoveZeroBits(ASN1uint32_t *,ASN1octet_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncUTCTime(ASN1encoding_t enc,ASN1uint32_t tag,ASN1utctime_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncFlush(ASN1encoding_t enc);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncOpenType(ASN1encoding_t enc,ASN1open_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecExplicitTag(ASN1decoding_t dec,ASN1uint32_t tag,ASN1decoding_t *dd,ASN1octet_t **di);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecEndOfContents(ASN1decoding_t dec,ASN1decoding_t dd,ASN1octet_t *di);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecOctetString(ASN1decoding_t dec,ASN1uint32_t tag,ASN1octetstring_t *val);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecOctetString2(ASN1decoding_t dec,ASN1uint32_t tag,ASN1octetstring_t *val);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecBitString(ASN1decoding_t dec,ASN1uint32_t tag,ASN1bitstring_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecBitString2(ASN1decoding_t dec,ASN1uint32_t tag,ASN1bitstring_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecChar16String(ASN1decoding_t dec,ASN1uint32_t tag,ASN1char16string_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecChar32String(ASN1decoding_t dec,ASN1uint32_t tag,ASN1char32string_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecCharString(ASN1decoding_t dec,ASN1uint32_t tag,ASN1charstring_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecDouble(ASN1decoding_t dec,ASN1uint32_t tag,double *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecGeneralizedTime(ASN1decoding_t dec,ASN1uint32_t tag,ASN1generalizedtime_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecZeroMultibyteString(ASN1decoding_t dec,ASN1uint32_t tag,ASN1ztcharstring_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecMultibyteString(ASN1decoding_t dec,ASN1uint32_t tag,ASN1charstring_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecNull(ASN1decoding_t dec,ASN1uint32_t tag);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecObjectIdentifier(ASN1decoding_t dec,ASN1uint32_t tag,ASN1objectidentifier_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecObjectIdentifier2(ASN1decoding_t dec,ASN1uint32_t tag,ASN1objectidentifier2_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecS8Val(ASN1decoding_t dec,ASN1uint32_t tag,ASN1int8_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecS16Val(ASN1decoding_t dec,ASN1uint32_t tag,ASN1int16_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecS32Val(ASN1decoding_t dec,ASN1uint32_t tag,ASN1int32_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecSXVal(ASN1decoding_t dec,ASN1uint32_t tag,ASN1intx_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecU8Val(ASN1decoding_t dec,ASN1uint32_t tag,ASN1uint8_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecU16Val(ASN1decoding_t dec,ASN1uint32_t tag,ASN1uint16_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecUTCTime(ASN1decoding_t dec,ASN1uint32_t tag,ASN1utctime_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecZeroChar16String(ASN1decoding_t dec,ASN1uint32_t tag,ASN1ztchar16string_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecZeroChar32String(ASN1decoding_t dec,ASN1uint32_t tag,ASN1ztchar32string_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecZeroCharString(ASN1decoding_t dec,ASN1uint32_t tag,ASN1ztcharstring_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecSkip(ASN1decoding_t dec);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecFlush(ASN1decoding_t dec);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecOpenType(ASN1decoding_t dec,ASN1open_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecOpenType2(ASN1decoding_t dec,ASN1open_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncCheck(ASN1encoding_t enc,ASN1uint32_t noctets);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncTag(ASN1encoding_t enc,ASN1uint32_t tag);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncExplicitTag(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t *pLengthOffset);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncEndOfContents(ASN1encoding_t enc,ASN1uint32_t LengthOffset);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncLength(ASN1encoding_t enc,ASN1uint32_t len);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecCheck(ASN1decoding_t dec,ASN1uint32_t len);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecTag(ASN1decoding_t dec,ASN1uint32_t tag,ASN1uint32_t *constructed);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecLength(ASN1decoding_t dec,ASN1uint32_t *len,ASN1uint32_t *infinite);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecNotEndOfContents(ASN1decoding_t dec,ASN1octet_t *di);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecPeekTag(ASN1decoding_t dec,ASN1uint32_t *tag);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncU32(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecU32Val(ASN1decoding_t dec,ASN1uint32_t tag,ASN1uint32_t *val);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncBool(ASN1encoding_t enc,ASN1uint32_t tag,ASN1bool_t);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecBool(ASN1decoding_t dec,ASN1uint32_t tag,ASN1bool_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncEoid(ASN1encoding_t enc,ASN1uint32_t tag,ASN1encodedOID_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecEoid(ASN1decoding_t dec,ASN1uint32_t tag,ASN1encodedOID_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDotVal2Eoid(ASN1encoding_t enc,char *pszDotVal,ASN1encodedOID_t *pOut);
  extern ASN1_PUBLIC int WINAPI ASN1BEREoid2DotVal(ASN1decoding_t dec,ASN1encodedOID_t *pIn,char **ppszDotVal);
  extern ASN1_PUBLIC void WINAPI ASN1BEREoid_free(ASN1encodedOID_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncUTF8String(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t length,WCHAR *value);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecUTF8String(ASN1decoding_t dec,ASN1uint32_t tag,ASN1wstring_t *val);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncCharString(ASN1encoding_t enc,ASN1uint32_t,ASN1uint32_t,ASN1char_t *);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncChar16String(ASN1encoding_t enc,ASN1uint32_t,ASN1uint32_t,ASN1char16_t *);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncChar32String(ASN1encoding_t enc,ASN1uint32_t,ASN1uint32_t,ASN1char32_t *);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncBitString(ASN1encoding_t enc,ASN1uint32_t,ASN1uint32_t,ASN1octet_t *);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncGeneralizedTime(ASN1encoding_t enc,ASN1uint32_t,ASN1generalizedtime_t *);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncZeroMultibyteString(ASN1encoding_t enc,ASN1uint32_t,ASN1ztcharstring_t);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncMultibyteString(ASN1encoding_t enc,ASN1uint32_t,ASN1charstring_t *);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncOctetString(ASN1encoding_t enc,ASN1uint32_t,ASN1uint32_t,ASN1octet_t *);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncUTCTime(ASN1encoding_t enc,ASN1uint32_t,ASN1utctime_t *);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncBeginBlk(ASN1encoding_t enc,ASN1blocktype_e eBlkType,void **ppBlk);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncNewBlkElement(void *pBlk,ASN1encoding_t *enc2);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncFlushBlkElement(void *pBlk);
  extern ASN1_PUBLIC int WINAPI ASN1CEREncEndBlk(void *pBlk);

#ifndef __CRT__NO_INLINE
  __CRT_INLINE int WINAPI ASN1DEREncGeneralizedTime(ASN1encoding_t enc,ASN1uint32_t tag,ASN1generalizedtime_t *val) { return ASN1CEREncGeneralizedTime(enc,tag,val); }
  __CRT_INLINE int WINAPI ASN1DEREncUTCTime(ASN1encoding_t enc,ASN1uint32_t tag,ASN1utctime_t *val) { return ASN1CEREncUTCTime(enc,tag,val); }
  __CRT_INLINE int WINAPI ASN1DEREncBeginBlk(ASN1encoding_t enc,ASN1blocktype_e eBlkType,void **ppBlk) { return ASN1CEREncBeginBlk(enc,eBlkType,ppBlk); }
  __CRT_INLINE int WINAPI ASN1DEREncNewBlkElement(void *pBlk,ASN1encoding_t *enc2) { return ASN1CEREncNewBlkElement(pBlk,enc2); }
  __CRT_INLINE int WINAPI ASN1DEREncFlushBlkElement(void *pBlk) { return ASN1CEREncFlushBlkElement(pBlk); }
  __CRT_INLINE int WINAPI ASN1DEREncEndBlk(void *pBlk) { return ASN1CEREncEndBlk(pBlk); }
  __CRT_INLINE int WINAPI ASN1DEREncCharString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t len,ASN1char_t *val) { return ASN1BEREncCharString(enc,tag,len,val); }
  __CRT_INLINE int WINAPI ASN1DEREncChar16String(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t len,ASN1char16_t *val) { return ASN1BEREncChar16String(enc,tag,len,val); }
  __CRT_INLINE int WINAPI ASN1DEREncChar32String(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t len,ASN1char32_t *val) { return ASN1BEREncChar32String(enc,tag,len,val); }
  __CRT_INLINE int WINAPI ASN1DEREncBitString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t len,ASN1octet_t *val) { return ASN1BEREncBitString(enc,tag,len,val); }
  __CRT_INLINE int WINAPI ASN1DEREncZeroMultibyteString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1ztcharstring_t val) { return ASN1BEREncZeroMultibyteString(enc,tag,val); }
  __CRT_INLINE int WINAPI ASN1DEREncMultibyteString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1charstring_t *val) { return ASN1BEREncMultibyteString(enc,tag,val); }
  __CRT_INLINE int WINAPI ASN1DEREncOctetString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t len,ASN1octet_t *val) { return ASN1BEREncOctetString(enc,tag,len,val); }
  __CRT_INLINE int WINAPI ASN1DEREncUTF8String(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t length,WCHAR *value) { return ASN1BEREncUTF8String(enc,tag,length,value); }
  __CRT_INLINE int WINAPI ASN1CEREncUTF8String(ASN1encoding_t enc,ASN1uint32_t tag,ASN1uint32_t length,WCHAR *value) { return ASN1BEREncUTF8String(enc,tag,length,value); }
#endif /* !__CRT__NO_INLINE */

  extern ASN1_PUBLIC int WINAPI ASN1BEREncEmbeddedPdv(ASN1encoding_t enc,ASN1uint32_t tag,ASN1embeddedpdv_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncExternal(ASN1encoding_t enc,ASN1uint32_t tag,ASN1external_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BEREncCharacterString(ASN1encoding_t enc,ASN1uint32_t tag,ASN1characterstring_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecEmbeddedPdv(ASN1decoding_t dec,ASN1uint32_t tag,ASN1embeddedpdv_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecExternal(ASN1decoding_t dec,ASN1uint32_t tag,ASN1external_t *);
  extern ASN1_PUBLIC int WINAPI ASN1BERDecCharacterString(ASN1decoding_t dec,ASN1uint32_t tag,ASN1characterstring_t *);

#ifdef __cplusplus
}
#endif

#include <poppack.h>
#endif
