/*
 * Copyright 2008 James Hawkins for CodeWeavers
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __WINE_PROPVARUTIL_H
#define __WINE_PROPVARUTIL_H

#include <shtypes.h>
#include <shlwapi.h>

#ifndef WINE_NTSTATUS_DECLARED
#define WINE_NTSTATUS_DECLARED
typedef LONG NTSTATUS;
#endif

#ifndef PSSTDAPI
#ifdef _PROPSYS_
#define PSSTDAPI          STDAPI
#define PSSTDAPI_(type)   STDAPI_(type)
#else
#define PSSTDAPI          DECLSPEC_IMPORT STDAPI
#define PSSTDAPI_(type)   DECLSPEC_IMPORT STDAPI_(type)
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

enum tagPROPVAR_CHANGE_FLAGS
{
    PVCHF_DEFAULT           = 0x00000000,
    PVCHF_NOVALUEPROP       = 0x00000001,
    PVCHF_ALPHABOOL         = 0x00000002,
    PVCHF_NOUSEROVERRIDE    = 0x00000004,
    PVCHF_LOCALBOOL         = 0x00000008,
    PVCHF_NOHEXSTRING       = 0x00000010,
};

typedef int PROPVAR_CHANGE_FLAGS;

enum tagPROPVAR_COMPARE_UNIT
{
    PVCU_DEFAULT           = 0x00000000,
    PVCU_SECOND            = 0x00000001,
    PVCU_MINUTE            = 0x00000002,
    PVCU_HOUR              = 0x00000003,
    PVCU_DAY               = 0x00000004,
    PVCU_MONTH             = 0x00000005,
    PVCU_YEAR              = 0x00000006,
};

typedef int PROPVAR_COMPARE_UNIT;

enum tagPROPVAR_COMPARE_FLAGS
{
    PVCF_DEFAULT           = 0x00000000,
    PVCF_TREATEMPTYASGREATERTHAN = 0x00000001,
    PVCF_USESTRCMP         = 0x00000002,
    PVCF_USESTRCMPC        = 0x00000004,
    PVCF_USESTRCMPI        = 0x00000008,
    PVCF_USESTRCMPIC       = 0x00000010,
};

typedef int PROPVAR_COMPARE_FLAGS;

PSSTDAPI PropVariantChangeType(PROPVARIANT *ppropvarDest, REFPROPVARIANT propvarSrc,
                                     PROPVAR_CHANGE_FLAGS flags, VARTYPE vt);
PSSTDAPI InitPropVariantFromGUIDAsString(REFGUID guid, PROPVARIANT *ppropvar);
PSSTDAPI InitVariantFromFileTime(const FILETIME *ft, VARIANT *var);
PSSTDAPI InitVariantFromGUIDAsString(REFGUID guid, VARIANT *pvar);
PSSTDAPI InitPropVariantFromBuffer(const VOID *pv, UINT cb, PROPVARIANT *ppropvar);
PSSTDAPI InitPropVariantFromCLSID(REFCLSID clsid, PROPVARIANT *ppropvar);
PSSTDAPI InitVariantFromBuffer(const VOID *pv, UINT cb, VARIANT *pvar);
PSSTDAPI PropVariantToGUID(const PROPVARIANT *ppropvar, GUID *guid);
PSSTDAPI VariantToGUID(const VARIANT *pvar, GUID *guid);
PSSTDAPI_(INT) PropVariantCompareEx(REFPROPVARIANT propvar1, REFPROPVARIANT propvar2,
                                PROPVAR_COMPARE_UNIT uint, PROPVAR_COMPARE_FLAGS flags);
PSSTDAPI InitPropVariantFromFileTime(const FILETIME *pftIn, PROPVARIANT *ppropvar);
PSSTDAPI InitPropVariantFromStringVector(PCWSTR *strs, ULONG count, PROPVARIANT *ppropvar);

PSSTDAPI PropVariantToDouble(REFPROPVARIANT propvarIn, double *ret);
PSSTDAPI PropVariantToInt16(REFPROPVARIANT propvarIn, SHORT *ret);
PSSTDAPI PropVariantToInt32(REFPROPVARIANT propvarIn, LONG *ret);
PSSTDAPI PropVariantToInt64(REFPROPVARIANT propvarIn, LONGLONG *ret);
PSSTDAPI PropVariantToUInt16(REFPROPVARIANT propvarIn, USHORT *ret);
PSSTDAPI PropVariantToUInt32(REFPROPVARIANT propvarIn, ULONG *ret);
PSSTDAPI_(ULONG) PropVariantToUInt32WithDefault(REFPROPVARIANT propvarIn, ULONG uLDefault);
PSSTDAPI PropVariantToUInt64(REFPROPVARIANT propvarIn, ULONGLONG *ret);
PSSTDAPI PropVariantToBoolean(REFPROPVARIANT propvarIn, WINBOOL *ret);
PSSTDAPI PropVariantToBSTR(REFPROPVARIANT propvar, BSTR *bstr);
PSSTDAPI PropVariantToBuffer(REFPROPVARIANT propvarIn, void *ret, UINT cb);
PSSTDAPI PropVariantToString(REFPROPVARIANT propvarIn, PWSTR ret, UINT cch);
PSSTDAPI_(PCWSTR) PropVariantToStringWithDefault(REFPROPVARIANT propvarIn, LPCWSTR pszDefault);
PSSTDAPI_(PCWSTR) VariantToStringWithDefault(const VARIANT *pvar, LPCWSTR pszDefault);
PSSTDAPI VariantToString(REFVARIANT var, PWSTR ret, UINT cch);

PSSTDAPI PropVariantToStringAlloc(REFPROPVARIANT propvarIn, WCHAR **ret);

PSSTDAPI PropVariantToVariant(const PROPVARIANT *propvar, VARIANT *var);
PSSTDAPI VariantToPropVariant(const VARIANT* var, PROPVARIANT* propvar);

PSSTDAPI PropVariantGetStringElem(const PROPVARIANT *propvar, ULONG idx, WCHAR **ret);

#ifdef __cplusplus

HRESULT InitPropVariantFromBoolean(WINBOOL fVal, PROPVARIANT *ppropvar);
HRESULT InitPropVariantFromInt16(SHORT nVal, PROPVARIANT *ppropvar);
HRESULT InitPropVariantFromUInt16(USHORT uiVal, PROPVARIANT *ppropvar);
HRESULT InitPropVariantFromInt32(LONG lVal, PROPVARIANT *ppropvar);
HRESULT InitPropVariantFromUInt32(ULONG ulVal, PROPVARIANT *ppropvar);
HRESULT InitPropVariantFromInt64(LONGLONG llVal, PROPVARIANT *ppropvar);
HRESULT InitPropVariantFromUInt64(ULONGLONG ullVal, PROPVARIANT *ppropvar);
HRESULT InitPropVariantFromDouble(DOUBLE dblVal, PROPVARIANT *ppropvar);
HRESULT InitPropVariantFromString(PCWSTR psz, PROPVARIANT *ppropvar);
HRESULT InitPropVariantFromGUIDAsBuffer(REFGUID guid, PROPVARIANT *ppropvar);
WINBOOL IsPropVariantVector(REFPROPVARIANT propvar);
WINBOOL IsPropVariantString(REFPROPVARIANT propvar);

#ifndef NO_PROPVAR_INLINES

inline HRESULT InitPropVariantFromBoolean(WINBOOL fVal, PROPVARIANT *ppropvar)
{
    ppropvar->vt = VT_BOOL;
    ppropvar->boolVal = fVal ? VARIANT_TRUE : VARIANT_FALSE;
    return S_OK;
}

inline HRESULT InitPropVariantFromInt16(SHORT nVal, PROPVARIANT *ppropvar)
{
    ppropvar->vt = VT_I2;
    ppropvar->iVal = nVal;
    return S_OK;
}

inline HRESULT InitPropVariantFromUInt16(USHORT uiVal, PROPVARIANT *ppropvar)
{
    ppropvar->vt = VT_UI2;
    ppropvar->uiVal = uiVal;
    return S_OK;
}

inline HRESULT InitPropVariantFromInt32(LONG lVal, PROPVARIANT *ppropvar)
{
    ppropvar->vt = VT_I4;
    ppropvar->lVal = lVal;
    return S_OK;
}

inline HRESULT InitPropVariantFromUInt32(ULONG ulVal, PROPVARIANT *ppropvar)
{
    ppropvar->vt = VT_UI4;
    ppropvar->ulVal = ulVal;
    return S_OK;
}

inline HRESULT InitPropVariantFromInt64(LONGLONG llVal, PROPVARIANT *ppropvar)
{
    ppropvar->vt = VT_I8;
    ppropvar->hVal.QuadPart = llVal;
    return S_OK;
}

inline HRESULT InitPropVariantFromUInt64(ULONGLONG ullVal, PROPVARIANT *ppropvar)
{
    ppropvar->vt = VT_UI8;
    ppropvar->uhVal.QuadPart = ullVal;
    return S_OK;
}

inline HRESULT InitPropVariantFromDouble(DOUBLE dblVal, PROPVARIANT *ppropvar)
{
    ppropvar->vt = VT_R8;
    ppropvar->dblVal = dblVal;
    return S_OK;
}

inline HRESULT InitPropVariantFromString(PCWSTR psz, PROPVARIANT *ppropvar)
{
    HRESULT hres;

    hres = SHStrDupW(psz, &ppropvar->pwszVal);
    if(SUCCEEDED(hres))
        ppropvar->vt = VT_LPWSTR;
    else
        PropVariantInit(ppropvar);

    return hres;
}

inline HRESULT InitPropVariantFromGUIDAsBuffer(REFGUID guid, PROPVARIANT *ppropvar)
{
#ifdef __cplusplus
    return InitPropVariantFromBuffer(&guid, sizeof(GUID), ppropvar);
#else
    return InitPropVariantFromBuffer(guid, sizeof(GUID), ppropvar);
#endif
}

inline WINBOOL IsPropVariantVector(REFPROPVARIANT propvar)
{
    return (propvar.vt & (VT_ARRAY | VT_VECTOR));
}

inline WINBOOL IsPropVariantString(REFPROPVARIANT propvar)
{
    return (PropVariantToStringWithDefault(propvar, NULL) != NULL);
}

#endif /* NO_PROPVAR_INLINES */
#endif /* __cplusplus */

PSSTDAPI StgSerializePropVariant(const PROPVARIANT *ppropvar, SERIALIZEDPROPERTYVALUE **ppprop, ULONG *pcb);
PSSTDAPI StgDeserializePropVariant(const SERIALIZEDPROPERTYVALUE *pprop, ULONG cbmax, PROPVARIANT *ppropvar);

#ifdef __cplusplus
}
#endif

#endif /* __WINE_PROPVARUTIL_H */
