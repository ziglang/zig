/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef SPHelper_h
#define SPHelper_h

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#include <malloc.h>
#include <sapi.h>
/* #include <sapiddk.h> */
#include <sperror.h>
#include <limits.h>
#include <mmsystem.h>
#include <comcat.h>
#include <mmreg.h>
/* #include <atlbase.h> */
#include <wchar.h>
#include <tchar.h>
#include <strsafe.h>
#include <intsafe.h>

inline HRESULT SpGetCategoryFromId(const WCHAR *category_id, ISpObjectTokenCategory **ret, BOOL fCreateIfNotExist = FALSE) {
    ISpObjectTokenCategory *obj_token_cat;
    HRESULT hres;

    hres = ::CoCreateInstance(CLSID_SpObjectTokenCategory, NULL, CLSCTX_ALL, __uuidof(ISpObjectTokenCategory),
            (void**)&obj_token_cat);
    if(FAILED(hres))
        return hres;

    hres = obj_token_cat->SetId(category_id, fCreateIfNotExist);
    if(FAILED(hres)) {
        obj_token_cat->Release();
        return hres;
    }

    *ret = obj_token_cat;
    return S_OK;
}

inline HRESULT SpEnumTokens(const WCHAR *category_id, const WCHAR *req_attrs, const WCHAR *opt_attrs, IEnumSpObjectTokens **ret) {
    ISpObjectTokenCategory *category;
    HRESULT hres;

    hres = SpGetCategoryFromId(category_id, &category);
    if(SUCCEEDED(hres)) {
        hres = category->EnumTokens(req_attrs, opt_attrs, ret);
        category->Release();
    }

    return hres;
}

/* str must be at least 9 chars (8 for 32-bit integer in hex + one for '\0').  */
inline void SpHexFromUlong(WCHAR *str, ULONG ul) {
    ::_ultow(ul, str, 16);
}

inline HRESULT SpGetDescription(ISpObjectToken *obj_token, WCHAR **description, LANGID language = GetUserDefaultUILanguage()) {
    WCHAR lang_id[9];
    HRESULT hres;

    SpHexFromUlong(lang_id, language);
    hres = obj_token->GetStringValue(lang_id, description);
    if(hres == SPERR_NOT_FOUND)
        hres = obj_token->GetStringValue(NULL, description);

    return hres;
}

#endif
#endif
