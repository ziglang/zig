/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_MBSTRING
#define _INC_MBSTRING

#include <crtdefs.h>

#pragma pack(push,_CRT_PACKING)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _FILE_DEFINED
  struct _iobuf {
    char *_ptr;
    int _cnt;
    char *_base;
    int _flag;
    int _file;
    int _charbuf;
    int _bufsiz;
    char *_tmpfname;
  };
  typedef struct _iobuf FILE;
#define _FILE_DEFINED
#endif

#ifndef _MBSTRING_DEFINED
#define _MBSTRING_DEFINED
  _CRTIMP unsigned char *__cdecl _mbsdup(const unsigned char *_Str);
  _CRTIMP unsigned int __cdecl _mbbtombc(unsigned int _Ch);
  _CRTIMP unsigned int __cdecl _mbbtombc_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _mbbtype(unsigned char _Ch,int _CType);
  _CRTIMP int __cdecl _mbbtype_l(unsigned char _Ch,int _CType,_locale_t _Locale);
  _CRTIMP unsigned int __cdecl _mbctombb(unsigned int _Ch);
  _CRTIMP unsigned int __cdecl _mbctombb_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _mbsbtype(const unsigned char *_Str,size_t _Pos);
  _CRTIMP int __cdecl _mbsbtype_l(const unsigned char *_Str,size_t _Pos,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbscat(unsigned char *_Dest,const unsigned char *_Source);
  _CRTIMP unsigned char *_mbscat_l(unsigned char *_Dest,const unsigned char *_Source,_locale_t _Locale);
  _CRTIMP _CONST_RETURN unsigned char *__cdecl _mbschr(const unsigned char *_Str,unsigned int _Ch);
  _CRTIMP _CONST_RETURN unsigned char *__cdecl _mbschr_l(const unsigned char *_Str,unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _mbscmp(const unsigned char *_Str1,const unsigned char *_Str2);
  _CRTIMP int __cdecl _mbscmp_l(const unsigned char *_Str1,const unsigned char *_Str2,_locale_t _Locale);
  _CRTIMP int __cdecl _mbscoll(const unsigned char *_Str1,const unsigned char *_Str2);
  _CRTIMP int __cdecl _mbscoll_l(const unsigned char *_Str1,const unsigned char *_Str2,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbscpy(unsigned char *_Dest,const unsigned char *_Source);
  _CRTIMP unsigned char *_mbscpy_l(unsigned char *_Dest,const unsigned char *_Source,_locale_t _Locale);
  _CRTIMP size_t __cdecl _mbscspn(const unsigned char *_Str,const unsigned char *_Control);
  _CRTIMP size_t __cdecl _mbscspn_l(const unsigned char *_Str,const unsigned char *_Control,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsdec(const unsigned char *_Start,const unsigned char *_Pos);
  _CRTIMP unsigned char *__cdecl _mbsdec_l(const unsigned char *_Start,const unsigned char *_Pos,_locale_t _Locale);
  _CRTIMP int __cdecl _mbsicmp(const unsigned char *_Str1,const unsigned char *_Str2);
  _CRTIMP int __cdecl _mbsicmp_l(const unsigned char *_Str1,const unsigned char *_Str2,_locale_t _Locale);
  _CRTIMP int __cdecl _mbsicoll(const unsigned char *_Str1,const unsigned char *_Str2);
  _CRTIMP int __cdecl _mbsicoll_l(const unsigned char *_Str1,const unsigned char *_Str2,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsinc(const unsigned char *_Ptr);
  _CRTIMP unsigned char *__cdecl _mbsinc_l(const unsigned char *_Ptr,_locale_t _Locale);
  _CRTIMP size_t __cdecl _mbslen(const unsigned char *_Str);
  _CRTIMP size_t __cdecl _mbslen_l(const unsigned char *_Str,_locale_t _Locale);
  _CRTIMP size_t __cdecl _mbsnlen(const unsigned char *_Str,size_t _MaxCount);
  _CRTIMP size_t __cdecl _mbsnlen_l(const unsigned char *_Str,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbslwr(unsigned char *_String);
  _CRTIMP unsigned char *_mbslwr_l(unsigned char *_String,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsnbcat(unsigned char *_Dest,const unsigned char *_Source,size_t _Count) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *__cdecl _mbsnbcat_l(unsigned char *_Dest,const unsigned char *_Source,size_t _Count,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP int __cdecl _mbsnbcmp(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _mbsnbcmp_l(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _mbsnbcoll(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _mbsnbcoll_l(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP size_t __cdecl _mbsnbcnt(const unsigned char *_Str,size_t _MaxCount);
  _CRTIMP size_t __cdecl _mbsnbcnt_l(const unsigned char *_Str,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsnbcpy(unsigned char *_Dest,const unsigned char *_Source,size_t _Count) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *__cdecl _mbsnbcpy_l(unsigned char *_Dest,const unsigned char *_Source,size_t _Count,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP int __cdecl _mbsnbicmp(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _mbsnbicmp_l(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _mbsnbicoll(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _mbsnbicoll_l(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsnbset(unsigned char *_Str,unsigned int _Ch,size_t _MaxCount) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *__cdecl _mbsnbset_l(unsigned char *_Str,unsigned int _Ch,size_t _MaxCount,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *__cdecl _mbsncat(unsigned char *_Dest,const unsigned char *_Source,size_t _Count) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *__cdecl _mbsncat_l(unsigned char *_Dest,const unsigned char *_Source,size_t _Count,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP size_t __cdecl _mbsnccnt(const unsigned char *_Str,size_t _MaxCount);
  _CRTIMP size_t __cdecl _mbsnccnt_l(const unsigned char *_Str,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _mbsncmp(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _mbsncmp_l(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _mbsncoll(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _mbsncoll_l(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsncpy(unsigned char *_Dest,const unsigned char *_Source,size_t _Count) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *__cdecl _mbsncpy_l(unsigned char *_Dest,const unsigned char *_Source,size_t _Count,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned int __cdecl _mbsnextc (const unsigned char *_Str);
  _CRTIMP unsigned int __cdecl _mbsnextc_l(const unsigned char *_Str,_locale_t _Locale);
  _CRTIMP int __cdecl _mbsnicmp(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _mbsnicmp_l(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _mbsnicoll(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _mbsnicoll_l(const unsigned char *_Str1,const unsigned char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsninc(const unsigned char *_Str,size_t _Count);
  _CRTIMP unsigned char *__cdecl _mbsninc_l(const unsigned char *_Str,size_t _Count,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsnset(unsigned char *_Dst,unsigned int _Val,size_t _MaxCount) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *__cdecl _mbsnset_l(unsigned char *_Dst,unsigned int _Val,size_t _MaxCount,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP _CONST_RETURN unsigned char *__cdecl _mbspbrk(const unsigned char *_Str,const unsigned char *_Control);
  _CRTIMP _CONST_RETURN unsigned char *__cdecl _mbspbrk_l(const unsigned char *_Str,const unsigned char *_Control,_locale_t _Locale);
  _CRTIMP _CONST_RETURN unsigned char *__cdecl _mbsrchr(const unsigned char *_Str,unsigned int _Ch);
  _CRTIMP _CONST_RETURN unsigned char *__cdecl _mbsrchr_l(const unsigned char *_Str,unsigned int _Ch,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsrev(unsigned char *_Str);
  _CRTIMP unsigned char *__cdecl _mbsrev_l(unsigned char *_Str,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsset(unsigned char *_Str,unsigned int _Val) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *__cdecl _mbsset_l(unsigned char *_Str,unsigned int _Val,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP size_t __cdecl _mbsspn(const unsigned char *_Str,const unsigned char *_Control);
  _CRTIMP size_t __cdecl _mbsspn_l(const unsigned char *_Str,const unsigned char *_Control,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbsspnp(const unsigned char *_Str1,const unsigned char *_Str2);
  _CRTIMP unsigned char *__cdecl _mbsspnp_l(const unsigned char *_Str1,const unsigned char *_Str2,_locale_t _Locale);
  _CRTIMP _CONST_RETURN unsigned char *__cdecl _mbsstr(const unsigned char *_Str,const unsigned char *_Substr);
  _CRTIMP _CONST_RETURN unsigned char *__cdecl _mbsstr_l(const unsigned char *_Str,const unsigned char *_Substr,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbstok(unsigned char *_Str,const unsigned char *_Delim) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *__cdecl _mbstok_l(unsigned char *_Str,const unsigned char *_Delim,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *__cdecl _mbsupr(unsigned char *_String) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP unsigned char *_mbsupr_l(unsigned char *_String,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP size_t __cdecl _mbclen(const unsigned char *_Str);
  _CRTIMP size_t __cdecl _mbclen_l(const unsigned char *_Str,_locale_t _Locale);
  _CRTIMP void __cdecl _mbccpy(unsigned char *_Dst,const unsigned char *_Src) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP void __cdecl _mbccpy_l(unsigned char *_Dst,const unsigned char *_Src,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#define _mbccmp(_cpc1,_cpc2) _mbsncmp((_cpc1),(_cpc2),1)

#ifdef __cplusplus
#ifndef _CPP_MBCS_INLINES_DEFINED
#define _CPP_MBCS_INLINES_DEFINED
  extern "C++" {
    static inline unsigned char *__cdecl _mbschr(unsigned char *_String,unsigned int _Char) { return ((unsigned char *)_mbschr((const unsigned char *)_String,_Char)); }
    static inline unsigned char *__cdecl _mbschr_l(unsigned char *_String,unsigned int _Char,_locale_t _Locale) { return ((unsigned char *)_mbschr_l((const unsigned char *)_String,_Char,_Locale)); }
    static inline unsigned char *__cdecl _mbspbrk(unsigned char *_String,const unsigned char *_CharSet) { return ((unsigned char *)_mbspbrk((const unsigned char *)_String,_CharSet)); }
    static inline unsigned char *__cdecl _mbspbrk_l(unsigned char *_String,const unsigned char *_CharSet,_locale_t _Locale) { return ((unsigned char *)_mbspbrk_l((const unsigned char *)_String,_CharSet,_Locale)); }
    static inline unsigned char *__cdecl _mbsrchr(unsigned char *_String,unsigned int _Char) { return ((unsigned char *)_mbsrchr((const unsigned char *)_String,_Char)); }
    static inline unsigned char *__cdecl _mbsrchr_l(unsigned char *_String,unsigned int _Char,_locale_t _Locale) { return ((unsigned char *)_mbsrchr_l((const unsigned char *)_String,_Char,_Locale)); }
    static inline unsigned char *__cdecl _mbsstr(unsigned char *_String,const unsigned char *_Match) { return ((unsigned char *)_mbsstr((const unsigned char *)_String,_Match)); }
    static inline unsigned char *__cdecl _mbsstr_l(unsigned char *_String,const unsigned char *_Match,_locale_t _Locale) { return ((unsigned char *)_mbsstr_l((const unsigned char *)_String,_Match,_Locale)); }
  }
#endif
#endif

  _CRTIMP int __cdecl _ismbcalnum(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcalnum_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcalpha(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcalpha_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcdigit(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcdigit_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcgraph(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcgraph_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbclegal(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbclegal_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbclower(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbclower_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcprint(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcprint_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcpunct(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcpunct_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcspace(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcspace_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcupper(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcupper_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP unsigned int __cdecl _mbctolower(unsigned int _Ch);
  _CRTIMP unsigned int __cdecl _mbctolower_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP unsigned int __cdecl _mbctoupper(unsigned int _Ch);
  _CRTIMP unsigned int __cdecl _mbctoupper_l(unsigned int _Ch,_locale_t _Locale);
#endif

#ifndef _MBLEADTRAIL_DEFINED
#define _MBLEADTRAIL_DEFINED
  _CRTIMP int __cdecl _ismbblead(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbblead_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbbtrail(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbbtrail_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbslead(const unsigned char *_Str,const unsigned char *_Pos);
  _CRTIMP int __cdecl _ismbslead_l(const unsigned char *_Str,const unsigned char *_Pos,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbstrail(const unsigned char *_Str,const unsigned char *_Pos);
  _CRTIMP int __cdecl _ismbstrail_l(const unsigned char *_Str,const unsigned char *_Pos,_locale_t _Locale);
#endif

  _CRTIMP int __cdecl _ismbchira(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbchira_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbckata(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbckata_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcsymbol(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcsymbol_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcl0(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcl0_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcl1(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcl1_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbcl2(unsigned int _Ch);
  _CRTIMP int __cdecl _ismbcl2_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP unsigned int __cdecl _mbcjistojms(unsigned int _Ch);
  _CRTIMP unsigned int __cdecl _mbcjistojms_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP unsigned int __cdecl _mbcjmstojis(unsigned int _Ch);
  _CRTIMP unsigned int __cdecl _mbcjmstojis_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP unsigned int __cdecl _mbctohira(unsigned int _Ch);
  _CRTIMP unsigned int __cdecl _mbctohira_l(unsigned int _Ch,_locale_t _Locale);
  _CRTIMP unsigned int __cdecl _mbctokata(unsigned int _Ch);
  _CRTIMP unsigned int __cdecl _mbctokata_l(unsigned int _Ch,_locale_t _Locale);

#ifdef __cplusplus
}
#endif

#pragma pack(pop)

#include <sec_api/mbstring_s.h>

#endif
