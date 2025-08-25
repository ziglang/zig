/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef MAPIAUXGUID_H
#ifdef INITGUID
#include <mapiguid.h>
#define MAPIAUXGUID_H
#endif /* INITGUID */

#if !defined(INITGUID) || defined(USES_IID_IMsgServiceAdmin2)
DEFINE_OLEGUID(IID_IMsgServiceAdmin2,0x00020387, 0, 0);
#endif

#if !defined(INITGUID) || defined(USES_IID_IMessageRaw)
DEFINE_OLEGUID(IID_IMessageRaw,0x0002038a, 0, 0);
#endif

#endif /* MAPIAUXGUID_H */

#ifndef MAPIAUX_H
#define MAPIAUX_H

#ifndef MAPIDEFS_H
#include <mapidefs.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef BEGIN_INTERFACE
#define BEGIN_INTERFACE
#endif

DECLARE_MAPI_INTERFACE_PTR(IMsgServiceAdmin2, LPSERVICEADMIN2);

#define PR_ATTACH_CONTENT_ID PROP_TAG(PT_TSTRING, 0x3712)
#define PR_ATTACH_CONTENT_ID_W PROP_TAG(PT_UNICODE, 0x3712)
#define PR_ATTACH_CONTENT_ID_A PROP_TAG(PT_STRING8, 0x3712)

#define PR_DISPLAY_TYPE_EX PROP_TAG(PT_LONG, 0x3905)
#define PR_MSG_EDITOR_FORMAT PROP_TAG(PT_LONG, 0x5909)
#define PR_ROH_FLAGS PROP_TAG(PT_LONG, 0x6623)
#define PR_ROH_PROXY_AUTH_SCHEME PROP_TAG(PT_LONG, 0x6627)

#define MAPI_BG_SESSION 0x00200000
#define MAPI_NO_COINIT 0x00000008

#define SPAMFILTER_ONSAVE ((ULONG)0x00000080)
#define ITEMPROC_FORCE ((ULONG)0x00000800)
#define NON_EMS_XP_SAVE ((ULONG)0x00001000)

#define MDB_ONLINE ((ULONG)0x00000100)

#define STORE_UNICODE_OK ((ULONG)0x00040000)
#define STORE_ITEMPROC ((ULONG)0x00200000)

#define MAPI_NO_CACHE ((ULONG)0x00000200)
#define MAPI_CACHE_ONLY ((ULONG)0x00004000)

#define AG_MONTHS 0
#define AG_WEEKS 1
#define AG_DAYS 2
#define NUM_AG_TYPES 3

#define DTE_FLAG_REMOTE_VALID 0x80000000
#define DTE_FLAG_ACL_CAPABLE 0x40000000
#define DTE_MASK_REMOTE 0x0000ff00
#define DTE_MASK_LOCAL 0x000000ff

#define DTE_IS_REMOTE_VALID(v) (!!((v) & DTE_FLAG_REMOTE_VALID))
#define DTE_IS_ACL_CAPABLE(v) (!!((v) & DTE_FLAG_ACL_CAPABLE))
#define DTE_REMOTE(v) (((v) & DTE_MASK_REMOTE) >> 8)
#define DTE_LOCAL(v) ((v) & DTE_MASK_LOCAL)

#define DT_ROOM ((ULONG)0x00000007)
#define DT_EQUIPMENT ((ULONG)0x00000008)
#define DT_SEC_DISTLIST ((ULONG)0x00000009)

#define EDITOR_FORMAT_DONTKNOW ((ULONG)0)
#define EDITOR_FORMAT_PLAINTEXT ((ULONG)1)
#define EDITOR_FORMAT_HTML ((ULONG)2)
#define EDITOR_FORMAT_RTF ((ULONG)3)

#define ROHFLAGS_USE_ROH 0x1
#define ROHFLAGS_SSL_ONLY 0x2
#define ROHFLAGS_MUTUAL_AUTH 0x4
#define ROHFLAGS_HTTP_FIRST_ON_FAST 0x8
#define ROHFLAGS_HTTP_FIRST_ON_SLOW 0x20

#define ROHAUTH_BASIC 0x1
#define ROHAUTH_NTLM 0x2

#define MAPI_IMSGSERVICEADMIN_METHODS(IPURE) \
  MAPIMETHOD(GetLastError) (THIS_ HRESULT hResult, ULONG ulFlags, LPMAPIERROR *lppMAPIError) IPURE; \
  MAPIMETHOD(GetMsgServiceTable) (THIS_ ULONG ulFlags, LPMAPITABLE *lppTable) IPURE; \
  MAPIMETHOD(CreateMsgService) (THIS_ LPTSTR lpszService, LPTSTR lpszDisplayName, ULONG_PTR ulUIParam, ULONG ulFlags) IPURE; \
  MAPIMETHOD(DeleteMsgService) (THIS_ LPMAPIUID lpUID) IPURE; \
  MAPIMETHOD(CopyMsgService) (THIS_ LPMAPIUID lpUID, LPTSTR lpszDisplayName, LPCIID lpInterfaceToCopy, LPCIID lpInterfaceDst, LPVOID lpObjectDst, ULONG_PTR ulUIParam, ULONG ulFlags) IPURE; \
  MAPIMETHOD(RenameMsgService) (THIS_ LPMAPIUID lpUID, ULONG ulFlags, LPTSTR lpszDisplayName) IPURE; \
  MAPIMETHOD(ConfigureMsgService) (THIS_ LPMAPIUID lpUID, ULONG_PTR ulUIParam, ULONG ulFlags, ULONG cValues, LPSPropValue lpProps) IPURE; \
  MAPIMETHOD(OpenProfileSection) (THIS_ LPMAPIUID lpUID, LPCIID lpInterface, ULONG ulFlags, LPPROFSECT *lppProfSect) IPURE; \
  MAPIMETHOD(MsgServiceTransportOrder) (THIS_ ULONG cUID, LPMAPIUID lpUIDList, ULONG ulFlags) IPURE; \
  MAPIMETHOD(AdminProviders) (THIS_ LPMAPIUID lpUID, ULONG ulFlags, LPPROVIDERADMIN *lppProviderAdmin) IPURE; \
  MAPIMETHOD(SetPrimaryIdentity) (THIS_ LPMAPIUID lpUID, ULONG ulFlags) IPURE; \
  MAPIMETHOD(GetProviderTable) (THIS_ ULONG ulFlags, LPMAPITABLE *lppTable) IPURE; \

#define MAPI_IMSGSERVICEADMIN_METHODS2(IPURE) \
  MAPIMETHOD(CreateMsgServiceEx) (THIS_ LPTSTR lpszService, LPTSTR lpszDisplayName, ULONG_PTR ulUIParam, ULONG ulFlags, LPMAPIUID lpuidService) IPURE; \

#undef INTERFACE
#define INTERFACE IMsgServiceAdmin2
DECLARE_MAPI_INTERFACE_(IMsgServiceAdmin2, IUnknown)
{
  BEGIN_INTERFACE
  MAPI_IUNKNOWN_METHODS(PURE)
  MAPI_IMSGSERVICEADMIN_METHODS(PURE)
  MAPI_IMSGSERVICEADMIN_METHODS2(PURE)
};

#ifdef __cplusplus
}
#endif

#endif /* MAPIAUX_H */
