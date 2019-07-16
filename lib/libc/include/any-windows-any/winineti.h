#include <_mingw_unicode.h>
/*
 * Copyright (C) 2007 Francois Gouget
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

#ifndef _WINE_WININETI_H_
#define _WINE_WININETI_H_

/* FIXME: #include <iedial.h> */
#include <schannel.h>
#include <sspi.h>

typedef struct _INTERNET_CACHE_CONFIG_PATH_ENTRYA
{
    CHAR CachePath[MAX_PATH];
    DWORD dwCacheSize;
} INTERNET_CACHE_CONFIG_PATH_ENTRYA, *LPINTERNET_CACHE_CONFIG_PATH_ENTRYA;

typedef struct _INTERNET_CACHE_CONFIG_PATH_ENTRYW
{
    WCHAR CachePath[MAX_PATH];
    DWORD dwCacheSize;
} INTERNET_CACHE_CONFIG_PATH_ENTRYW, *LPINTERNET_CACHE_CONFIG_PATH_ENTRYW;

__MINGW_TYPEDEF_AW(INTERNET_CACHE_CONFIG_PATH_ENTRY)
__MINGW_TYPEDEF_AW(LPINTERNET_CACHE_CONFIG_PATH_ENTRY)

typedef struct _INTERNET_CACHE_CONFIG_INFOA
{
    DWORD dwStructSize;
    DWORD dwContainer;
    DWORD dwQuota;
    DWORD dwReserved4;
    WINBOOL fPerUser;
    DWORD dwSyncMode;
    DWORD dwNumCachePaths;
    __C89_NAMELESS union
    {
        __C89_NAMELESS struct
        {
            CHAR CachePath[MAX_PATH];
            DWORD dwCacheSize;
        } __C89_NAMELESSSTRUCTNAME;
        INTERNET_CACHE_CONFIG_PATH_ENTRYA CachePaths[ANYSIZE_ARRAY];
    } __C89_NAMELESSUNIONNAME;
    DWORD dwNormalUsage;
    DWORD dwExemptUsage;
} INTERNET_CACHE_CONFIG_INFOA, *LPINTERNET_CACHE_CONFIG_INFOA;

typedef struct _INTERNET_CACHE_CONFIG_INFOW
{
    DWORD dwStructSize;
    DWORD dwContainer;
    DWORD dwQuota;
    DWORD dwReserved4;
    WINBOOL  fPerUser;
    DWORD dwSyncMode;
    DWORD dwNumCachePaths;
    __C89_NAMELESS union
    {
        __C89_NAMELESS struct
        {
            WCHAR CachePath[MAX_PATH];
            DWORD dwCacheSize;
        } __C89_NAMELESSSTRUCTNAME;
        INTERNET_CACHE_CONFIG_PATH_ENTRYW CachePaths[ANYSIZE_ARRAY];
    } __C89_NAMELESSUNIONNAME;
    DWORD dwNormalUsage;
    DWORD dwExemptUsage;
} INTERNET_CACHE_CONFIG_INFOW, *LPINTERNET_CACHE_CONFIG_INFOW;

__MINGW_TYPEDEF_AW(INTERNET_CACHE_CONFIG_INFO)
__MINGW_TYPEDEF_AW(LPINTERNET_CACHE_CONFIG_INFO)

typedef enum {
    WININET_SYNC_MODE_NEVER = 0,
    WININET_SYNC_MODE_ON_EXPIRY,
    WININET_SYNC_MODE_ONCE_PER_SESSION,
    WININET_SYNC_MODE_ALWAYS,
    WININET_SYNC_MODE_AUTOMATIC,
    WININET_SYNC_MODE_DEFAULT = WININET_SYNC_MODE_AUTOMATIC
} WININET_SYNC_MODE;

/* Flags for GetUrlCacheConfigInfoA/W and SetUrlCacheConfigInfoA/W */
#define CACHE_CONFIG_FORCE_CLEANUP_FC        0x00000020
#define CACHE_CONFIG_DISK_CACHE_PATHS_FC     0x00000040
#define CACHE_CONFIG_SYNC_MODE_FC            0x00000080
#define CACHE_CONFIG_CONTENT_PATHS_FC        0x00000100
#define CACHE_CONFIG_COOKIES_PATHS_FC        0x00000200
#define CACHE_CONFIG_HISTORY_PATHS_FC        0x00000400
#define CACHE_CONFIG_QUOTA_FC                0x00000800
#define CACHE_CONFIG_USER_MODE_FC            0x00001000
#define CACHE_CONFIG_CONTENT_USAGE_FC        0x00002000
#define CACHE_CONFIG_STICKY_CONTENT_USAGE_FC 0x00004000

#ifdef __cplusplus
extern "C" {
#endif

DWORD       WINAPI DeleteIE3Cache(HWND,HINSTANCE,LPSTR,int);
WINBOOL     WINAPI GetDiskInfoA(PCSTR,PDWORD,PDWORDLONG,PDWORDLONG);
WINBOOL     WINAPI GetUrlCacheConfigInfoA(LPINTERNET_CACHE_CONFIG_INFOA,LPDWORD,DWORD);
WINBOOL     WINAPI GetUrlCacheConfigInfoW(LPINTERNET_CACHE_CONFIG_INFOW,LPDWORD,DWORD);
#define     GetUrlCacheConfigInfo __MINGW_NAME_AW(GetUrlCacheConfigInfo)
WINBOOL     WINAPI IncrementUrlCacheHeaderData(DWORD,LPDWORD);
WINBOOL     WINAPI InternetQueryFortezzaStatus(DWORD*,DWORD_PTR);
WINBOOL     WINAPI IsUrlCacheEntryExpiredA(LPCSTR,DWORD,FILETIME*);
WINBOOL     WINAPI IsUrlCacheEntryExpiredW(LPCWSTR,DWORD,FILETIME*);
#define     IsUrlCacheEntryExpired __MINGW_NAME_AW(IsUrlCacheEntryExpired)
DWORD       WINAPI ParseX509EncodedCertificateForListBoxEntry(LPBYTE,DWORD,LPSTR,LPDWORD);
WINBOOL     WINAPI SetUrlCacheConfigInfoA(LPINTERNET_CACHE_CONFIG_INFOA,DWORD);
WINBOOL     WINAPI SetUrlCacheConfigInfoW(LPINTERNET_CACHE_CONFIG_INFOW,DWORD);
#define     SetUrlCacheConfigInfo __MINGW_NAME_AW(SetUrlCacheConfigInfo)
WINBOOL     WINAPI InternetGetSecurityInfoByURLA(LPSTR,PCCERT_CHAIN_CONTEXT*,DWORD*);
WINBOOL     WINAPI InternetGetSecurityInfoByURLW(LPCWSTR,PCCERT_CHAIN_CONTEXT*,DWORD*);
#define     InternetGetSecurityInfoByURL __MINGW_NAME_AW(InternetGetSecurityInfoByURL)

#ifdef __cplusplus
}
#endif

#endif /* _WINE_WININETI_H_ */
