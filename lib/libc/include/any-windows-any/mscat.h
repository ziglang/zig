/*
 * Copyright (C) 2004 Francois Gouget
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

#ifndef __WINE_MSCAT_H
#define __WINE_MSCAT_H

#include <mssip.h>

typedef HANDLE HCATADMIN;
typedef HANDLE HCATINFO;

#ifdef __cplusplus
extern "C" {
#endif

#define CRYPTCAT_ATTR_NAMEASCII             0x00000001
#define CRYPTCAT_ATTR_NAMEOBJID             0x00000002
#define CRYPTCAT_ATTR_DATAASCII             0x00010000
#define CRYPTCAT_ATTR_DATAOBJID             0x00020000
#define CRYPTCAT_ATTR_DATAREPLACE           0x00040000
#define CRYPTCAT_ATTR_NO_AUTO_COMPAT_ENTRY  0x01000000
#define CRYPTCAT_ATTR_AUTHENTICATED         0x10000000
#define CRYPTCAT_ATTR_UNAUTHENTICATED       0x20000000

#define CRYPTCAT_OPEN_CREATENEW             0x00000001
#define CRYPTCAT_OPEN_ALWAYS                0x00000002
#define CRYPTCAT_OPEN_EXISTING              0x00000004
#define CRYPTCAT_OPEN_EXCLUDE_PAGE_HASHES   0x00010000
#define CRYPTCAT_OPEN_INCLUDE_PAGE_HASHES   0x00020000
#define CRYPTCAT_OPEN_VERIFYSIGHASH         0x10000000
#define CRYPTCAT_OPEN_NO_CONTENT_HCRYPTMSG  0x20000000
#define CRYPTCAT_OPEN_SORTED                0x40000000
#define CRYPTCAT_OPEN_FLAGS_MASK            0xffff0000

#define CRYPTCAT_E_AREA_HEADER              0x00000000
#define CRYPTCAT_E_AREA_MEMBER              0x00010000
#define CRYPTCAT_E_AREA_ATTRIBUTE           0x00020000

#define CRYPTCAT_E_CDF_UNSUPPORTED          0x00000001
#define CRYPTCAT_E_CDF_DUPLICATE            0x00000002
#define CRYPTCAT_E_CDF_TAGNOTFOUND          0x00000004

#define CRYPTCAT_E_CDF_MEMBER_FILE_PATH     0x00010001
#define CRYPTCAT_E_CDF_MEMBER_INDIRECTDATA  0x00010002
#define CRYPTCAT_E_CDF_MEMBER_FILENOTFOUND  0x00010004

#define CRYPTCAT_E_CDF_BAD_GUID_CONV        0x00020001
#define CRYPTCAT_E_CDF_ATTR_TOOFEWVALUES    0x00020002
#define CRYPTCAT_E_CDF_ATTR_TYPECOMBO       0x00020004

#define CRYPTCAT_VERSION_1  0x100
#define CRYPTCAT_VERSION_2  0x200

#pragma pack(push,8)

typedef struct CRYPTCATATTRIBUTE_
{
    DWORD cbStruct;
    LPWSTR pwszReferenceTag;
    DWORD dwAttrTypeAndAction;
    DWORD cbValue;
    BYTE *pbValue;
    DWORD dwReserved;
} CRYPTCATATTRIBUTE;

typedef struct CRYPTCATMEMBER_
{
    DWORD cbStruct;
    LPWSTR pwszReferenceTag;
    LPWSTR pwszFileName;
    GUID gSubjectType;
    DWORD fdwMemberFlags;
    struct SIP_INDIRECT_DATA_* pIndirectData;
    DWORD dwCertVersion;
    DWORD dwReserved;
    HANDLE hReserved;
    CRYPT_ATTR_BLOB sEncodedIndirectData;
    CRYPT_ATTR_BLOB sEncodedMemberInfo;
} CRYPTCATMEMBER;

typedef struct CATALOG_INFO_
{
    DWORD cbStruct;
    WCHAR wszCatalogFile[MAX_PATH];
} CATALOG_INFO;

typedef struct CRYPTCATCDF_
{
    DWORD cbStruct;
    HANDLE hFile;
    DWORD dwCurFilePos;
    DWORD dwLastMemberOffset;
    WINBOOL fEOF;
    LPWSTR pwszResultDir;
    HANDLE hCATStore;
} CRYPTCATCDF;

#pragma pack(pop)

typedef void (WINAPI *PFN_CDF_PARSE_ERROR_CALLBACK)(DWORD, DWORD, WCHAR *);

WINBOOL   WINAPI CryptCATAdminAcquireContext(HCATADMIN*,const GUID*,DWORD);
WINBOOL   WINAPI CryptCATAdminAcquireContext2(HCATADMIN*,const GUID*,const WCHAR*,const CERT_STRONG_SIGN_PARA*,DWORD);
HCATINFO  WINAPI CryptCATAdminAddCatalog(HCATADMIN,PWSTR,PWSTR,DWORD);
WINBOOL   WINAPI CryptCATAdminCalcHashFromFileHandle(HANDLE,DWORD*,BYTE*,DWORD);
WINBOOL   WINAPI CryptCATAdminCalcHashFromFileHandle2(HCATADMIN,HANDLE,DWORD*,BYTE*,DWORD);
HCATINFO  WINAPI CryptCATAdminEnumCatalogFromHash(HCATADMIN,BYTE*,DWORD,DWORD,HCATINFO*);
WINBOOL   WINAPI CryptCATAdminReleaseCatalogContext(HCATADMIN,HCATINFO,DWORD);
WINBOOL   WINAPI CryptCATAdminReleaseContext(HCATADMIN,DWORD);
WINBOOL   WINAPI CryptCATAdminRemoveCatalog(HCATADMIN,LPCWSTR,DWORD);
WINBOOL   WINAPI CryptCATAdminResolveCatalogPath(HCATADMIN, WCHAR *, CATALOG_INFO *, DWORD);
WINBOOL   WINAPI CryptCATCatalogInfoFromContext(HCATINFO, CATALOG_INFO *, DWORD);
WINBOOL   WINAPI CryptCATCDFClose(CRYPTCATCDF *);
CRYPTCATATTRIBUTE * WINAPI CryptCATCDFEnumCatAttributes(CRYPTCATCDF *, CRYPTCATATTRIBUTE *,
                                                        PFN_CDF_PARSE_ERROR_CALLBACK);
LPWSTR              WINAPI CryptCATCDFEnumMembersByCDFTagEx(CRYPTCATCDF *, LPWSTR,
                                                            PFN_CDF_PARSE_ERROR_CALLBACK,
                                                            CRYPTCATMEMBER **, WINBOOL, LPVOID);
CRYPTCATCDF       * WINAPI CryptCATCDFOpen(LPWSTR, PFN_CDF_PARSE_ERROR_CALLBACK);
WINBOOL             WINAPI CryptCATClose(HANDLE);
CRYPTCATATTRIBUTE * WINAPI CryptCATEnumerateAttr(HANDLE, CRYPTCATMEMBER *, CRYPTCATATTRIBUTE *);
CRYPTCATATTRIBUTE * WINAPI CryptCATEnumerateCatAttr(HANDLE, CRYPTCATATTRIBUTE *);
CRYPTCATMEMBER    * WINAPI CryptCATEnumerateMember(HANDLE,CRYPTCATMEMBER *);
CRYPTCATATTRIBUTE * WINAPI CryptCATGetAttrInfo(HANDLE, CRYPTCATMEMBER *, LPWSTR);
CRYPTCATATTRIBUTE * WINAPI CryptCATGetCatAttrInfo(HANDLE, LPWSTR);
CRYPTCATMEMBER    * WINAPI CryptCATGetMemberInfo(HANDLE, LPWSTR);
HANDLE    WINAPI CryptCATOpen(LPWSTR,DWORD,HCRYPTPROV,DWORD,DWORD);
WINBOOL   WINAPI CryptCATPersistStore(HANDLE catalog);
CRYPTCATATTRIBUTE * WINAPI CryptCATPutAttrInfo(HANDLE catalog, CRYPTCATMEMBER *member, WCHAR *name, DWORD flags, DWORD size, BYTE *data);
CRYPTCATATTRIBUTE * WINAPI CryptCATPutCatAttrInfo(HANDLE catalog, WCHAR *name, DWORD flags, DWORD size, BYTE *data);
CRYPTCATMEMBER    * WINAPI CryptCATPutMemberInfo(HANDLE catalog, WCHAR *filename, WCHAR *member, GUID *subject, DWORD version, DWORD size, BYTE *data);

#ifdef __cplusplus
}
#endif

#endif
