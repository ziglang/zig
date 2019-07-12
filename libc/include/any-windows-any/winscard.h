/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WINSCARD_H_
#define _WINSCARD_H_

#include <_mingw_unicode.h>
#include <wtypes.h>
#include <winioctl.h>
#include "winsmcrd.h"
#ifndef SCARD_S_SUCCESS
#include "SCardErr.h"
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _LPCBYTE_DEFINED
#define _LPCBYTE_DEFINED
  typedef const BYTE *LPCBYTE;
#endif
#ifndef _LPCVOID_DEFINED
#define _LPCVOID_DEFINED
  typedef const VOID *LPCVOID;
#endif

#ifndef WINSCARDAPI
#define WINSCARDAPI
#endif
#ifndef WINSCARDDATA
#define WINSCARDDATA __declspec(dllimport)
#endif

  WINSCARDDATA extern const SCARD_IO_REQUEST g_rgSCardT0Pci,g_rgSCardT1Pci,g_rgSCardRawPci;
#define SCARD_PCI_T0 (&g_rgSCardT0Pci)
#define SCARD_PCI_T1 (&g_rgSCardT1Pci)
#define SCARD_PCI_RAW (&g_rgSCardRawPci)

  typedef ULONG_PTR SCARDCONTEXT;
  typedef SCARDCONTEXT *PSCARDCONTEXT,*LPSCARDCONTEXT;

  typedef ULONG_PTR SCARDHANDLE;
  typedef SCARDHANDLE *PSCARDHANDLE,*LPSCARDHANDLE;

#define SCARD_AUTOALLOCATE (DWORD)(-1)
#define SCARD_SCOPE_USER 0
#define SCARD_SCOPE_TERMINAL 1
#define SCARD_SCOPE_SYSTEM 2

  extern WINSCARDAPI LONG WINAPI SCardEstablishContext(DWORD dwScope,LPCVOID pvReserved1,LPCVOID pvReserved2,LPSCARDCONTEXT phContext);
  extern WINSCARDAPI LONG WINAPI SCardReleaseContext(SCARDCONTEXT hContext);
  extern WINSCARDAPI LONG WINAPI SCardIsValidContext(SCARDCONTEXT hContext);

#define SCARD_ALL_READERS TEXT("SCard$AllReaders\000")
#define SCARD_DEFAULT_READERS TEXT("SCard$DefaultReaders\000")
#define SCARD_LOCAL_READERS TEXT("SCard$LocalReaders\000")
#define SCARD_SYSTEM_READERS TEXT("SCard$SystemReaders\000")

#define SCARD_PROVIDER_PRIMARY 1
#define SCARD_PROVIDER_CSP 2

#define SCardListReaderGroups __MINGW_NAME_AW(SCardListReaderGroups)
#define SCardListReaders __MINGW_NAME_AW(SCardListReaders)
#define SCardListCards __MINGW_NAME_AW(SCardListCards)
#define SCardListInterfaces __MINGW_NAME_AW(SCardListInterfaces)
#define SCardGetProviderId __MINGW_NAME_AW(SCardGetProviderId)
#define SCardGetCardTypeProviderName __MINGW_NAME_AW(SCardGetCardTypeProviderName)
#define SCardIntroduceReaderGroup __MINGW_NAME_AW(SCardIntroduceReaderGroup)
#define SCardForgetReaderGroup __MINGW_NAME_AW(SCardForgetReaderGroup)
#define SCardIntroduceReader __MINGW_NAME_AW(SCardIntroduceReader)
#define SCardForgetReader __MINGW_NAME_AW(SCardForgetReader)
#define SCardAddReaderToGroup __MINGW_NAME_AW(SCardAddReaderToGroup)
#define SCardRemoveReaderFromGroup __MINGW_NAME_AW(SCardRemoveReaderFromGroup)
#define SCardIntroduceCardType __MINGW_NAME_AW(SCardIntroduceCardType)
#define SCardSetCardTypeProviderName __MINGW_NAME_AW(SCardSetCardTypeProviderName)
#define SCardForgetCardType __MINGW_NAME_AW(SCardForgetCardType)

  extern WINSCARDAPI LONG WINAPI SCardListReaderGroupsA(SCARDCONTEXT hContext,LPSTR mszGroups,LPDWORD pcchGroups);
  extern WINSCARDAPI LONG WINAPI SCardListReaderGroupsW(SCARDCONTEXT hContext,LPWSTR mszGroups,LPDWORD pcchGroups);
  extern WINSCARDAPI LONG WINAPI SCardListReadersA(SCARDCONTEXT hContext,LPCSTR mszGroups,LPSTR mszReaders,LPDWORD pcchReaders);
  extern WINSCARDAPI LONG WINAPI SCardListReadersW(SCARDCONTEXT hContext,LPCWSTR mszGroups,LPWSTR mszReaders,LPDWORD pcchReaders);
  extern WINSCARDAPI LONG WINAPI SCardListCardsA(SCARDCONTEXT hContext,LPCBYTE pbAtr,LPCGUID rgquidInterfaces,DWORD cguidInterfaceCount,LPSTR mszCards,LPDWORD pcchCards);
  extern WINSCARDAPI LONG WINAPI SCardListCardsW(SCARDCONTEXT hContext,LPCBYTE pbAtr,LPCGUID rgquidInterfaces,DWORD cguidInterfaceCount,LPWSTR mszCards,LPDWORD pcchCards);
#define SCardListCardTypes SCardListCards
  extern WINSCARDAPI LONG WINAPI SCardListInterfacesA(SCARDCONTEXT hContext,LPCSTR szCard,LPGUID pguidInterfaces,LPDWORD pcguidInterfaces);
  extern WINSCARDAPI LONG WINAPI SCardListInterfacesW(SCARDCONTEXT hContext,LPCWSTR szCard,LPGUID pguidInterfaces,LPDWORD pcguidInterfaces);
  extern WINSCARDAPI LONG WINAPI SCardGetProviderIdA(SCARDCONTEXT hContext,LPCSTR szCard,LPGUID pguidProviderId);
  extern WINSCARDAPI LONG WINAPI SCardGetProviderIdW(SCARDCONTEXT hContext,LPCWSTR szCard,LPGUID pguidProviderId);
  extern WINSCARDAPI LONG WINAPI SCardGetCardTypeProviderNameA(SCARDCONTEXT hContext,LPCSTR szCardName,DWORD dwProviderId,LPSTR szProvider,LPDWORD pcchProvider);
  extern WINSCARDAPI LONG WINAPI SCardGetCardTypeProviderNameW(SCARDCONTEXT hContext,LPCWSTR szCardName,DWORD dwProviderId,LPWSTR szProvider,LPDWORD pcchProvider);
  extern WINSCARDAPI LONG WINAPI SCardIntroduceReaderGroupA(SCARDCONTEXT hContext,LPCSTR szGroupName);
  extern WINSCARDAPI LONG WINAPI SCardIntroduceReaderGroupW(SCARDCONTEXT hContext,LPCWSTR szGroupName);
  extern WINSCARDAPI LONG WINAPI SCardForgetReaderGroupA(SCARDCONTEXT hContext,LPCSTR szGroupName);
  extern WINSCARDAPI LONG WINAPI SCardForgetReaderGroupW(SCARDCONTEXT hContext,LPCWSTR szGroupName);
  extern WINSCARDAPI LONG WINAPI SCardIntroduceReaderA(SCARDCONTEXT hContext,LPCSTR szReaderName,LPCSTR szDeviceName);
  extern WINSCARDAPI LONG WINAPI SCardIntroduceReaderW(SCARDCONTEXT hContext,LPCWSTR szReaderName,LPCWSTR szDeviceName);
  extern WINSCARDAPI LONG WINAPI SCardForgetReaderA(SCARDCONTEXT hContext,LPCSTR szReaderName);
  extern WINSCARDAPI LONG WINAPI SCardForgetReaderW(SCARDCONTEXT hContext,LPCWSTR szReaderName);
  extern WINSCARDAPI LONG WINAPI SCardAddReaderToGroupA(SCARDCONTEXT hContext,LPCSTR szReaderName,LPCSTR szGroupName);
  extern WINSCARDAPI LONG WINAPI SCardAddReaderToGroupW(SCARDCONTEXT hContext,LPCWSTR szReaderName,LPCWSTR szGroupName);
  extern WINSCARDAPI LONG WINAPI SCardRemoveReaderFromGroupA(SCARDCONTEXT hContext,LPCSTR szReaderName,LPCSTR szGroupName);
  extern WINSCARDAPI LONG WINAPI SCardRemoveReaderFromGroupW(SCARDCONTEXT hContext,LPCWSTR szReaderName,LPCWSTR szGroupName);
  extern WINSCARDAPI LONG WINAPI SCardIntroduceCardTypeA(SCARDCONTEXT hContext,LPCSTR szCardName,LPCGUID pguidPrimaryProvider,LPCGUID rgguidInterfaces,DWORD dwInterfaceCount,LPCBYTE pbAtr,LPCBYTE pbAtrMask,DWORD cbAtrLen);
  extern WINSCARDAPI LONG WINAPI SCardIntroduceCardTypeW(SCARDCONTEXT hContext,LPCWSTR szCardName,LPCGUID pguidPrimaryProvider,LPCGUID rgguidInterfaces,DWORD dwInterfaceCount,LPCBYTE pbAtr,LPCBYTE pbAtrMask,DWORD cbAtrLen);

#define PCSCardIntroduceCardType(hContext,szCardName,pbAtr,pbAtrMask,cbAtrLen,pguidPrimaryProvider,rgguidInterfaces,dwInterfaceCount) SCardIntroduceCardType(hContext,szCardName,pguidPrimaryProvider,rgguidInterfaces,dwInterfaceCount,pbAtr,pbAtrMask,cbAtrLen)

  extern WINSCARDAPI LONG WINAPI SCardSetCardTypeProviderNameA(SCARDCONTEXT hContext,LPCSTR szCardName,DWORD dwProviderId,LPCSTR szProvider);
  extern WINSCARDAPI LONG WINAPI SCardSetCardTypeProviderNameW(SCARDCONTEXT hContext,LPCWSTR szCardName,DWORD dwProviderId,LPCWSTR szProvider);
  extern WINSCARDAPI LONG WINAPI SCardForgetCardTypeA(SCARDCONTEXT hContext,LPCSTR szCardName);
  extern WINSCARDAPI LONG WINAPI SCardForgetCardTypeW(SCARDCONTEXT hContext,LPCWSTR szCardName);
  extern WINSCARDAPI LONG WINAPI SCardFreeMemory(SCARDCONTEXT hContext,LPCVOID pvMem);
  extern WINSCARDAPI HANDLE WINAPI SCardAccessStartedEvent(void);
  extern WINSCARDAPI void WINAPI SCardReleaseStartedEvent(void);

  typedef struct {
    LPCSTR szReader;
    LPVOID pvUserData;
    DWORD dwCurrentState;
    DWORD dwEventState;
    DWORD cbAtr;
    BYTE rgbAtr[36];
  } SCARD_READERSTATEA,*PSCARD_READERSTATEA,*LPSCARD_READERSTATEA;

  typedef struct {
    LPCWSTR szReader;
    LPVOID pvUserData;
    DWORD dwCurrentState;
    DWORD dwEventState;
    DWORD cbAtr;
    BYTE rgbAtr[36];
  } SCARD_READERSTATEW,*PSCARD_READERSTATEW,*LPSCARD_READERSTATEW;

  __MINGW_TYPEDEF_AW(SCARD_READERSTATE)
  __MINGW_TYPEDEF_AW(PSCARD_READERSTATE)
  __MINGW_TYPEDEF_AW(LPSCARD_READERSTATE)

#define SCardLocateCards __MINGW_NAME_AW(SCardLocateCards)
#define SCardLocateCardsByATR __MINGW_NAME_AW(SCardLocateCardsByATR)
#define SCardGetStatusChange __MINGW_NAME_AW(SCardGetStatusChange)
#define SCardConnect __MINGW_NAME_AW(SCardConnect)
#define SCardStatus __MINGW_NAME_AW(SCardStatus)

#define SCARD_READERSTATE_A SCARD_READERSTATEA
#define SCARD_READERSTATE_W SCARD_READERSTATEW
#define PSCARD_READERSTATE_A PSCARD_READERSTATEA
#define PSCARD_READERSTATE_W PSCARD_READERSTATEW
#define LPSCARD_READERSTATE_A LPSCARD_READERSTATEA
#define LPSCARD_READERSTATE_W LPSCARD_READERSTATEW

#define SCARD_STATE_UNAWARE 0x00000000
#define SCARD_STATE_IGNORE 0x00000001
#define SCARD_STATE_CHANGED 0x00000002
#define SCARD_STATE_UNKNOWN 0x00000004
#define SCARD_STATE_UNAVAILABLE 0x00000008
#define SCARD_STATE_EMPTY 0x00000010
#define SCARD_STATE_PRESENT 0x00000020
#define SCARD_STATE_ATRMATCH 0x00000040
#define SCARD_STATE_EXCLUSIVE 0x00000080
#define SCARD_STATE_INUSE 0x00000100
#define SCARD_STATE_MUTE 0x00000200
#define SCARD_STATE_UNPOWERED 0x00000400

  extern WINSCARDAPI LONG WINAPI SCardLocateCardsA(SCARDCONTEXT hContext,LPCSTR mszCards,LPSCARD_READERSTATEA rgReaderStates,DWORD cReaders);
  extern WINSCARDAPI LONG WINAPI SCardLocateCardsW(SCARDCONTEXT hContext,LPCWSTR mszCards,LPSCARD_READERSTATEW rgReaderStates,DWORD cReaders);

  typedef struct _SCARD_ATRMASK {
    DWORD cbAtr;
    BYTE rgbAtr[36];
    BYTE rgbMask[36];
  } SCARD_ATRMASK,*PSCARD_ATRMASK,*LPSCARD_ATRMASK;

  extern WINSCARDAPI LONG WINAPI SCardLocateCardsByATRA(SCARDCONTEXT hContext,LPSCARD_ATRMASK rgAtrMasks,DWORD cAtrs,LPSCARD_READERSTATEA rgReaderStates,DWORD cReaders);
  extern WINSCARDAPI LONG WINAPI SCardLocateCardsByATRW(SCARDCONTEXT hContext,LPSCARD_ATRMASK rgAtrMasks,DWORD cAtrs,LPSCARD_READERSTATEW rgReaderStates,DWORD cReaders);
  extern WINSCARDAPI LONG WINAPI SCardGetStatusChangeA(SCARDCONTEXT hContext,DWORD dwTimeout,LPSCARD_READERSTATEA rgReaderStates,DWORD cReaders);
  extern WINSCARDAPI LONG WINAPI SCardGetStatusChangeW(SCARDCONTEXT hContext,DWORD dwTimeout,LPSCARD_READERSTATEW rgReaderStates,DWORD cReaders);
  extern WINSCARDAPI LONG WINAPI SCardCancel(SCARDCONTEXT hContext);

#define SCARD_SHARE_EXCLUSIVE 1
#define SCARD_SHARE_SHARED 2
#define SCARD_SHARE_DIRECT 3

#define SCARD_LEAVE_CARD 0
#define SCARD_RESET_CARD 1
#define SCARD_UNPOWER_CARD 2
#define SCARD_EJECT_CARD 3

  extern WINSCARDAPI LONG WINAPI SCardConnectA(SCARDCONTEXT hContext,LPCSTR szReader,DWORD dwShareMode,DWORD dwPreferredProtocols,LPSCARDHANDLE phCard,LPDWORD pdwActiveProtocol);
  extern WINSCARDAPI LONG WINAPI SCardConnectW(SCARDCONTEXT hContext,LPCWSTR szReader,DWORD dwShareMode,DWORD dwPreferredProtocols,LPSCARDHANDLE phCard,LPDWORD pdwActiveProtocol);
  extern WINSCARDAPI LONG WINAPI SCardReconnect(SCARDHANDLE hCard,DWORD dwShareMode,DWORD dwPreferredProtocols,DWORD dwInitialization,LPDWORD pdwActiveProtocol);
  extern WINSCARDAPI LONG WINAPI SCardDisconnect(SCARDHANDLE hCard,DWORD dwDisposition);
  extern WINSCARDAPI LONG WINAPI SCardBeginTransaction(SCARDHANDLE hCard);
  extern WINSCARDAPI LONG WINAPI SCardEndTransaction(SCARDHANDLE hCard,DWORD dwDisposition);
  extern WINSCARDAPI LONG WINAPI SCardCancelTransaction(SCARDHANDLE hCard);
  extern WINSCARDAPI LONG WINAPI SCardState(SCARDHANDLE hCard,LPDWORD pdwState,LPDWORD pdwProtocol,LPBYTE pbAtr,LPDWORD pcbAtrLen);
  extern WINSCARDAPI LONG WINAPI SCardStatusA(SCARDHANDLE hCard,LPSTR szReaderName,LPDWORD pcchReaderLen,LPDWORD pdwState,LPDWORD pdwProtocol,LPBYTE pbAtr,LPDWORD pcbAtrLen);
  extern WINSCARDAPI LONG WINAPI SCardStatusW(SCARDHANDLE hCard,LPWSTR szReaderName,LPDWORD pcchReaderLen,LPDWORD pdwState,LPDWORD pdwProtocol,LPBYTE pbAtr,LPDWORD pcbAtrLen);
  extern WINSCARDAPI LONG WINAPI SCardTransmit(SCARDHANDLE hCard,LPCSCARD_IO_REQUEST pioSendPci,LPCBYTE pbSendBuffer,DWORD cbSendLength,LPSCARD_IO_REQUEST pioRecvPci,LPBYTE pbRecvBuffer,LPDWORD pcbRecvLength);
  extern WINSCARDAPI LONG WINAPI SCardControl(SCARDHANDLE hCard,DWORD dwControlCode,LPCVOID lpInBuffer,DWORD nInBufferSize,LPVOID lpOutBuffer,DWORD nOutBufferSize,LPDWORD lpBytesReturned);
  extern WINSCARDAPI LONG WINAPI SCardGetAttrib(SCARDHANDLE hCard,DWORD dwAttrId,LPBYTE pbAttr,LPDWORD pcbAttrLen);

#define SCardGetReaderCapabilities SCardGetAttrib

  extern WINSCARDAPI LONG WINAPI SCardSetAttrib(SCARDHANDLE hCard,DWORD dwAttrId,LPCBYTE pbAttr,DWORD cbAttrLen);

#define SCardSetReaderCapabilities SCardSetAttrib

#define SC_DLG_MINIMAL_UI 0x01
#define SC_DLG_NO_UI 0x02
#define SC_DLG_FORCE_UI 0x04

#define SCERR_NOCARDNAME 0x4000
#define SCERR_NOGUIDS 0x8000

#define LPOCNCONNPROC __MINGW_NAME_AW(LPOCNCONNPROC)

  typedef SCARDHANDLE (WINAPI *LPOCNCONNPROCA) (SCARDCONTEXT,LPSTR,LPSTR,PVOID);
  typedef SCARDHANDLE (WINAPI *LPOCNCONNPROCW) (SCARDCONTEXT,LPWSTR,LPWSTR,PVOID);
  typedef WINBOOL (WINAPI *LPOCNCHKPROC) (SCARDCONTEXT,SCARDHANDLE,PVOID);
  typedef void (WINAPI *LPOCNDSCPROC) (SCARDCONTEXT,SCARDHANDLE,PVOID);

  typedef struct {
    DWORD dwStructSize;
    LPSTR lpstrGroupNames;
    DWORD nMaxGroupNames;
    LPCGUID rgguidInterfaces;
    DWORD cguidInterfaces;
    LPSTR lpstrCardNames;
    DWORD nMaxCardNames;
    LPOCNCHKPROC lpfnCheck;
    LPOCNCONNPROCA lpfnConnect;
    LPOCNDSCPROC lpfnDisconnect;
    LPVOID pvUserData;
    DWORD dwShareMode;
    DWORD dwPreferredProtocols;
  } OPENCARD_SEARCH_CRITERIAA,*POPENCARD_SEARCH_CRITERIAA,*LPOPENCARD_SEARCH_CRITERIAA;

  typedef struct {
    DWORD dwStructSize;
    LPWSTR lpstrGroupNames;
    DWORD nMaxGroupNames;
    LPCGUID rgguidInterfaces;
    DWORD cguidInterfaces;
    LPWSTR lpstrCardNames;
    DWORD nMaxCardNames;
    LPOCNCHKPROC lpfnCheck;
    LPOCNCONNPROCW lpfnConnect;
    LPOCNDSCPROC lpfnDisconnect;
    LPVOID pvUserData;
    DWORD dwShareMode;
    DWORD dwPreferredProtocols;
  } OPENCARD_SEARCH_CRITERIAW,*POPENCARD_SEARCH_CRITERIAW,*LPOPENCARD_SEARCH_CRITERIAW;

  __MINGW_TYPEDEF_AW(OPENCARD_SEARCH_CRITERIA)
  __MINGW_TYPEDEF_AW(POPENCARD_SEARCH_CRITERIA)
  __MINGW_TYPEDEF_AW(LPOPENCARD_SEARCH_CRITERIA)

  typedef struct {
    DWORD dwStructSize;
    SCARDCONTEXT hSCardContext;
    HWND hwndOwner;
    DWORD dwFlags;
    LPCSTR lpstrTitle;
    LPCSTR lpstrSearchDesc;
    HICON hIcon;
    POPENCARD_SEARCH_CRITERIAA pOpenCardSearchCriteria;
    LPOCNCONNPROCA lpfnConnect;
    LPVOID pvUserData;
    DWORD dwShareMode;
    DWORD dwPreferredProtocols;
    LPSTR lpstrRdr;
    DWORD nMaxRdr;
    LPSTR lpstrCard;
    DWORD nMaxCard;
    DWORD dwActiveProtocol;
    SCARDHANDLE hCardHandle;
  } OPENCARDNAME_EXA,*POPENCARDNAME_EXA,*LPOPENCARDNAME_EXA;

  typedef struct {
    DWORD dwStructSize;
    SCARDCONTEXT hSCardContext;
    HWND hwndOwner;
    DWORD dwFlags;
    LPCWSTR lpstrTitle;
    LPCWSTR lpstrSearchDesc;
    HICON hIcon;
    POPENCARD_SEARCH_CRITERIAW pOpenCardSearchCriteria;
    LPOCNCONNPROCW lpfnConnect;
    LPVOID pvUserData;
    DWORD dwShareMode;
    DWORD dwPreferredProtocols;
    LPWSTR lpstrRdr;
    DWORD nMaxRdr;
    LPWSTR lpstrCard;
    DWORD nMaxCard;
    DWORD dwActiveProtocol;
    SCARDHANDLE hCardHandle;
  } OPENCARDNAME_EXW,*POPENCARDNAME_EXW,*LPOPENCARDNAME_EXW;

  __MINGW_TYPEDEF_AW(OPENCARDNAME_EX)
  __MINGW_TYPEDEF_AW(POPENCARDNAME_EX)
  __MINGW_TYPEDEF_AW(LPOPENCARDNAME_EX)

#define OPENCARDNAMEA_EX OPENCARDNAME_EXA
#define OPENCARDNAMEW_EX OPENCARDNAME_EXW
#define POPENCARDNAMEA_EX POPENCARDNAME_EXA
#define POPENCARDNAMEW_EX POPENCARDNAME_EXW
#define LPOPENCARDNAMEA_EX LPOPENCARDNAME_EXA
#define LPOPENCARDNAMEW_EX LPOPENCARDNAME_EXW

#define SCardUIDlgSelectCard __MINGW_NAME_AW(SCardUIDlgSelectCard)

  extern WINSCARDAPI LONG WINAPI SCardUIDlgSelectCardA(LPOPENCARDNAMEA_EX);
  extern WINSCARDAPI LONG WINAPI SCardUIDlgSelectCardW(LPOPENCARDNAMEW_EX);

  typedef struct {
    DWORD dwStructSize;
    HWND hwndOwner;
    SCARDCONTEXT hSCardContext;
    LPSTR lpstrGroupNames;
    DWORD nMaxGroupNames;
    LPSTR lpstrCardNames;
    DWORD nMaxCardNames;
    LPCGUID rgguidInterfaces;
    DWORD cguidInterfaces;
    LPSTR lpstrRdr;
    DWORD nMaxRdr;
    LPSTR lpstrCard;
    DWORD nMaxCard;
    LPCSTR lpstrTitle;
    DWORD dwFlags;
    LPVOID pvUserData;
    DWORD dwShareMode;
    DWORD dwPreferredProtocols;
    DWORD dwActiveProtocol;
    LPOCNCONNPROCA lpfnConnect;
    LPOCNCHKPROC lpfnCheck;
    LPOCNDSCPROC lpfnDisconnect;
    SCARDHANDLE hCardHandle;
  } OPENCARDNAMEA,*POPENCARDNAMEA,*LPOPENCARDNAMEA;

  typedef struct {
    DWORD dwStructSize;
    HWND hwndOwner;
    SCARDCONTEXT hSCardContext;
    LPWSTR lpstrGroupNames;
    DWORD nMaxGroupNames;
    LPWSTR lpstrCardNames;
    DWORD nMaxCardNames;
    LPCGUID rgguidInterfaces;
    DWORD cguidInterfaces;
    LPWSTR lpstrRdr;
    DWORD nMaxRdr;
    LPWSTR lpstrCard;
    DWORD nMaxCard;
    LPCWSTR lpstrTitle;
    DWORD dwFlags;
    LPVOID pvUserData;
    DWORD dwShareMode;
    DWORD dwPreferredProtocols;
    DWORD dwActiveProtocol;
    LPOCNCONNPROCW lpfnConnect;
    LPOCNCHKPROC lpfnCheck;
    LPOCNDSCPROC lpfnDisconnect;
    SCARDHANDLE hCardHandle;
  } OPENCARDNAMEW,*POPENCARDNAMEW,*LPOPENCARDNAMEW;

  __MINGW_TYPEDEF_AW(OPENCARDNAME)
  __MINGW_TYPEDEF_AW(POPENCARDNAME)
  __MINGW_TYPEDEF_AW(LPOPENCARDNAME)

#define OPENCARDNAME_A OPENCARDNAMEA
#define OPENCARDNAME_W OPENCARDNAMEW
#define POPENCARDNAME_A POPENCARDNAMEA
#define POPENCARDNAME_W POPENCARDNAMEW
#define LPOPENCARDNAME_A LPOPENCARDNAMEA
#define LPOPENCARDNAME_W LPOPENCARDNAMEW

#define GetOpenCardName __MINGW_NAME_AW(GetOpenCardName)

  extern WINSCARDAPI LONG WINAPI GetOpenCardNameA(LPOPENCARDNAMEA);
  extern WINSCARDAPI LONG WINAPI GetOpenCardNameW(LPOPENCARDNAMEW);
  extern WINSCARDAPI LONG WINAPI SCardDlgExtendedError(void);

#if (_WIN32_WINNT >= 0x0600)
LONG WINAPI SCardGetTransmitCount(
  SCARDHANDLE hCard,
  LPDWORD pcTransmitCount
);

LONG WINAPI SCardReadCacheA(
  SCARDCONTEXT hContext,
  UUID *CardIdentifier,
  DWORD FreshnessCounter,
  LPSTR LookupName,
  PBYTE Data,
  DWORD *DataLen
);

LONG WINAPI SCardReadCacheW(
  SCARDCONTEXT hContext,
  UUID *CardIdentifier,
  DWORD FreshnessCounter,
  LPWSTR LookupName,
  PBYTE Data,
  DWORD *DataLen
);

#define SCardReadCache __MINGW_NAME_AW(SCardReadCache)

LONG WINAPI SCardWriteCacheA(
  SCARDCONTEXT hContext,
  UUID *CardIdentifier,
  DWORD FreshnessCounter,
  LPSTR LookupName,
  PBYTE Data,
  DWORD DataLen
);

LONG WINAPI SCardWriteCacheW(
  SCARDCONTEXT hContext,
  UUID *CardIdentifier,
  DWORD FreshnessCounter,
  LPWSTR LookupName,
  PBYTE Data,
  DWORD DataLen
);

#define SCardWriteCache __MINGW_NAME_AW(SCardWriteCache)

#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif
#endif
