/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#if !defined(_MAPIUTIL_H) && !defined(_WABUTIL_H)
#define _WABUTIL_H

#include "mapidefs.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef BEGIN_INTERFACE
#define BEGIN_INTERFACE
#endif

  DECLARE_MAPI_INTERFACE_PTR(ITableData,LPTABLEDATA);

  typedef void (WINAPI CALLERRELEASE)(ULONG ulCallerData,LPTABLEDATA lpTblData,LPMAPITABLE lpVue);

#define MAPI_ITABLEDATA_METHODS(IPURE) MAPIMETHOD(HrGetView) (THIS_ LPSSortOrderSet lpSSortOrderSet,CALLERRELEASE *lpfCallerRelease,ULONG ulCallerData,LPMAPITABLE *lppMAPITable) IPURE; MAPIMETHOD(HrModifyRow) (THIS_ LPSRow) IPURE; MAPIMETHOD(HrDeleteRow) (THIS_ LPSPropValue lpSPropValue) IPURE; MAPIMETHOD(HrQueryRow) (THIS_ LPSPropValue lpsPropValue,LPSRow *lppSRow,ULONG *lpuliRow) IPURE; MAPIMETHOD(HrEnumRow) (THIS_ ULONG ulRowNumber,LPSRow *lppSRow) IPURE; MAPIMETHOD(HrNotify) (THIS_ ULONG ulFlags,ULONG cValues,LPSPropValue lpSPropValue) IPURE; MAPIMETHOD(HrInsertRow) (THIS_ ULONG uliRow,LPSRow lpSRow) IPURE; MAPIMETHOD(HrModifyRows) (THIS_ ULONG ulFlags,LPSRowSet lpSRowSet) IPURE; MAPIMETHOD(HrDeleteRows) (THIS_ ULONG ulFlags,LPSRowSet lprowsetToDelete,ULONG *cRowsDeleted) IPURE;
#undef INTERFACE
#define INTERFACE ITableData
  DECLARE_MAPI_INTERFACE_(ITableData,IUnknown) {
    BEGIN_INTERFACE
      MAPI_IUNKNOWN_METHODS(PURE)
      MAPI_ITABLEDATA_METHODS(PURE)
  };

  STDAPI_(SCODE) CreateTable(LPCIID lpInterface,ALLOCATEBUFFER *lpAllocateBuffer,ALLOCATEMORE *lpAllocateMore,FREEBUFFER *lpFreeBuffer,LPVOID lpvReserved,ULONG ulTableType,ULONG ulPropTagIndexColumn,LPSPropTagArray lpSPropTagArrayColumns,LPTABLEDATA *lppTableData);

#define TAD_ALL_ROWS 1

#define MAPI_IPROPDATA_METHODS(IPURE) MAPIMETHOD(HrSetObjAccess) (THIS_ ULONG ulAccess) IPURE; MAPIMETHOD(HrSetPropAccess) (THIS_ LPSPropTagArray lpPropTagArray,ULONG *rgulAccess) IPURE; MAPIMETHOD(HrGetPropAccess) (THIS_ LPSPropTagArray *lppPropTagArray,ULONG **lprgulAccess) IPURE; MAPIMETHOD(HrAddObjProps) (THIS_ LPSPropTagArray lppPropTagArray,LPSPropProblemArray *lprgulAccess) IPURE;

#undef INTERFACE
#define INTERFACE IPropData
  DECLARE_MAPI_INTERFACE_(IPropData,IMAPIProp) {
    BEGIN_INTERFACE
      MAPI_IUNKNOWN_METHODS(PURE)
      MAPI_IMAPIPROP_METHODS(PURE)
      MAPI_IPROPDATA_METHODS(PURE)
  };

  DECLARE_MAPI_INTERFACE_PTR(IPropData,LPPROPDATA);

#ifndef CreateIProp
  STDAPI_(SCODE) CreateIProp(LPCIID lpInterface,ALLOCATEBUFFER *lpAllocateBuffer,ALLOCATEMORE *lpAllocateMore,FREEBUFFER *lpFreeBuffer,LPVOID lpvReserved,LPPROPDATA *lppPropData);
#endif

  STDAPI_(SCODE) WABCreateIProp(LPCIID lpInterface,ALLOCATEBUFFER *lpAllocateBuffer,ALLOCATEMORE *lpAllocateMore,FREEBUFFER *lpFreeBuffer,LPVOID lpvReserved,LPPROPDATA *lppPropData);

#define IPROP_READONLY ((ULONG) 0x00000001)
#define IPROP_READWRITE ((ULONG) 0x00000002)
#define IPROP_CLEAN ((ULONG) 0x00010000)
#define IPROP_DIRTY ((ULONG) 0x00020000)

#ifndef NOIDLEENGINE

#define PRILOWEST -32768
#define PRIHIGHEST 32767
#define PRIUSER 0

#define IRONULL ((USHORT) 0x0000)
#define FIROWAIT ((USHORT) 0x0001)
#define FIROINTERVAL ((USHORT) 0x0002)
#define FIROPERBLOCK ((USHORT) 0x0004)
#define FIRODISABLED ((USHORT) 0x0020)
#define FIROONCEONLY ((USHORT) 0x0040)

#define IRCNULL ((USHORT) 0x0000)
#define FIRCPFN ((USHORT) 0x0001)
#define FIRCPV ((USHORT) 0x0002)
#define FIRCPRI ((USHORT) 0x0004)
#define FIRCCSEC ((USHORT) 0x0008)
#define FIRCIRO ((USHORT) 0x0010)

  typedef WINBOOL (WINAPI FNIDLE)(LPVOID);
  typedef FNIDLE *PFNIDLE;

  typedef void *FTG;
  typedef FTG *PFTG;
#define FTGNULL ((FTG) NULL)

  STDAPI_(LONG) MAPIInitIdle(LPVOID lpvReserved);
  STDAPI_(VOID) MAPIDeinitIdle(VOID);
  STDAPI_(FTG) FtgRegisterIdleRoutine(PFNIDLE lpfnIdle,LPVOID lpvIdleParam,short priIdle,ULONG csecIdle,USHORT iroIdle);
  STDAPI_(void) DeregisterIdleRoutine(FTG ftg);
  STDAPI_(void) EnableIdleRoutine(FTG ftg,WINBOOL fEnable);
  STDAPI_(void) ChangeIdleRoutine(FTG ftg,PFNIDLE lpfnIdle,LPVOID lpvIdleParam,short priIdle,ULONG csecIdle,USHORT iroIdle,USHORT ircIdle);
#endif

  STDAPI_(LPMALLOC) MAPIGetDefaultMalloc(VOID);

#define SOF_UNIQUEFILENAME ((ULONG) 0x80000000)

  STDMETHODIMP OpenStreamOnFile(LPALLOCATEBUFFER lpAllocateBuffer,LPFREEBUFFER lpFreeBuffer,ULONG ulFlags,LPTSTR lpszFileName,LPTSTR lpszPrefix,LPSTREAM *lppStream);

  typedef HRESULT (WINAPI *LPOPENSTREAMONFILE) (LPALLOCATEBUFFER lpAllocateBuffer,LPFREEBUFFER lpFreeBuffer,ULONG ulFlags,LPTSTR lpszFileName,LPTSTR lpszPrefix,LPSTREAM *lppStream);

#define OPENSTREAMONFILE "OpenStreamOnFile"

  STDAPI_(SCODE) PropCopyMore(LPSPropValue lpSPropValueDest,LPSPropValue lpSPropValueSrc,ALLOCATEMORE *lpfAllocMore,LPVOID lpvObject);
  STDAPI_(ULONG) UlPropSize(LPSPropValue lpSPropValue);
  STDAPI_(WINBOOL) FEqualNames(LPMAPINAMEID lpName1,LPMAPINAMEID lpName2);

#ifndef _WINNT
#define _WINNT
#endif

  STDAPI_(void) GetInstance(LPSPropValue lpPropMv,LPSPropValue lpPropSv,ULONG uliInst);

  extern unsigned char rgchCsds[];
  extern unsigned char rgchCids[];
  extern unsigned char rgchCsdi[];
  extern unsigned char rgchCidi[];

  STDAPI_(WINBOOL) FPropContainsProp(LPSPropValue lpSPropValueDst,LPSPropValue lpSPropValueSrc,ULONG ulFuzzyLevel);
  STDAPI_(WINBOOL) FPropCompareProp(LPSPropValue lpSPropValue1,ULONG ulRelOp,LPSPropValue lpSPropValue2);
  STDAPI_(LONG) LPropCompareProp(LPSPropValue lpSPropValueA,LPSPropValue lpSPropValueB);
  STDAPI_(HRESULT) HrAddColumns(LPMAPITABLE lptbl,LPSPropTagArray lpproptagColumnsNew,LPALLOCATEBUFFER lpAllocateBuffer,LPFREEBUFFER lpFreeBuffer);
  STDAPI_(HRESULT) HrAddColumnsEx(LPMAPITABLE lptbl,LPSPropTagArray lpproptagColumnsNew,LPALLOCATEBUFFER lpAllocateBuffer,LPFREEBUFFER lpFreeBuffer,void (*lpfnFilterColumns)(LPSPropTagArray ptaga));
  STDAPI HrAllocAdviseSink(LPNOTIFCALLBACK lpfnCallback,LPVOID lpvContext,LPMAPIADVISESINK *lppAdviseSink);
  STDAPI HrThisThreadAdviseSink(LPMAPIADVISESINK lpAdviseSink,LPMAPIADVISESINK *lppAdviseSink);
  STDAPI HrDispatchNotifications(ULONG ulFlags);

  typedef struct {
    ULONG ulCtlType;
    ULONG ulCtlFlags;
    LPBYTE lpbNotif;
    ULONG cbNotif;
    LPTSTR lpszFilter;
    ULONG ulItemID;
    union {
      LPVOID lpv;
      LPDTBLLABEL lplabel;
      LPDTBLEDIT lpedit;
      LPDTBLLBX lplbx;
      LPDTBLCOMBOBOX lpcombobox;
      LPDTBLDDLBX lpddlbx;
      LPDTBLCHECKBOX lpcheckbox;
      LPDTBLGROUPBOX lpgroupbox;
      LPDTBLBUTTON lpbutton;
      LPDTBLRADIOBUTTON lpradiobutton;
      LPDTBLMVLISTBOX lpmvlbx;
      LPDTBLMVDDLBX lpmvddlbx;
      LPDTBLPAGE lppage;
    } ctl;
  } DTCTL,*LPDTCTL;

  typedef struct {
    ULONG cctl;
    LPTSTR lpszResourceName;
    __C89_NAMELESS union {
      LPTSTR lpszComponent;
      ULONG ulItemID;
    };
    LPDTCTL lpctl;
  } DTPAGE,*LPDTPAGE;

  STDAPI BuildDisplayTable(LPALLOCATEBUFFER lpAllocateBuffer,LPALLOCATEMORE lpAllocateMore,LPFREEBUFFER lpFreeBuffer,LPMALLOC lpMalloc,HINSTANCE hInstance,UINT cPages,LPDTPAGE lpPage,ULONG ulFlags,LPMAPITABLE *lppTable,LPTABLEDATA *lppTblData);
  STDAPI_(SCODE) ScCountNotifications(int cNotifications,LPNOTIFICATION lpNotifications,ULONG *lpcb);
  STDAPI_(SCODE) ScCopyNotifications(int cNotification,LPNOTIFICATION lpNotifications,LPVOID lpvDst,ULONG *lpcb);
  STDAPI_(SCODE) ScRelocNotifications(int cNotification,LPNOTIFICATION lpNotifications,LPVOID lpvBaseOld,LPVOID lpvBaseNew,ULONG *lpcb);
  STDAPI_(SCODE) ScCountProps(int cValues,LPSPropValue lpPropArray,ULONG *lpcb);
  STDAPI_(LPSPropValue) LpValFindProp(ULONG ulPropTag,ULONG cValues,LPSPropValue lpPropArray);
  STDAPI_(SCODE) ScCopyProps(int cValues,LPSPropValue lpPropArray,LPVOID lpvDst,ULONG *lpcb);
  STDAPI_(SCODE) ScRelocProps(int cValues,LPSPropValue lpPropArray,LPVOID lpvBaseOld,LPVOID lpvBaseNew,ULONG *lpcb);
  STDAPI_(SCODE) ScDupPropset(int cValues,LPSPropValue lpPropArray,LPALLOCATEBUFFER lpAllocateBuffer,LPSPropValue *lppPropArray);
  STDAPI_(ULONG) UlAddRef(LPVOID lpunk);
  STDAPI_(ULONG) UlRelease(LPVOID lpunk);
  STDAPI HrGetOneProp(LPMAPIPROP lpMapiProp,ULONG ulPropTag,LPSPropValue *lppProp);
  STDAPI HrSetOneProp(LPMAPIPROP lpMapiProp,LPSPropValue lpProp);
  STDAPI_(WINBOOL) FPropExists(LPMAPIPROP lpMapiProp,ULONG ulPropTag);
  STDAPI_(LPSPropValue) PpropFindProp(LPSPropValue lpPropArray,ULONG cValues,ULONG ulPropTag);
  STDAPI_(void) FreePadrlist(LPADRLIST lpAdrlist);
  STDAPI_(void) FreeProws(LPSRowSet lpRows);
  STDAPI HrQueryAllRows(LPMAPITABLE lpTable,LPSPropTagArray lpPropTags,LPSRestriction lpRestriction,LPSSortOrderSet lpSortOrderSet,LONG crowsMax,LPSRowSet *lppRows);
  STDAPI_(LPTSTR) SzFindCh(LPCTSTR lpsz,USHORT ch);
  STDAPI_(LPTSTR) SzFindLastCh(LPCTSTR lpsz,USHORT ch);
  STDAPI_(LPTSTR) SzFindSz(LPCTSTR lpsz,LPCTSTR lpszKey);
  STDAPI_(unsigned int) UFromSz(LPCTSTR lpsz);
  STDAPI_(SCODE) ScUNCFromLocalPath(LPSTR lpszLocal,LPSTR lpszUNC,UINT cchUNC);
  STDAPI_(SCODE) ScLocalPathFromUNC(LPSTR lpszUNC,LPSTR lpszLocal,UINT cchLocal);
  STDAPI_(FILETIME) FtAddFt(FILETIME ftAddend1,FILETIME ftAddend2);
  STDAPI_(FILETIME) FtMulDwDw(DWORD ftMultiplicand,DWORD ftMultiplier);
  STDAPI_(FILETIME) FtMulDw(DWORD ftMultiplier,FILETIME ftMultiplicand);
  STDAPI_(FILETIME) FtSubFt(FILETIME ftMinuend,FILETIME ftSubtrahend);
  STDAPI_(FILETIME) FtNegFt(FILETIME ft);
  STDAPI_(SCODE) ScCreateConversationIndex(ULONG cbParent,LPBYTE lpbParent,ULONG *lpcbConvIndex,LPBYTE *lppbConvIndex);
  STDAPI WrapStoreEntryID(ULONG ulFlags,LPTSTR lpszDLLName,ULONG cbOrigEntry,LPENTRYID lpOrigEntry,ULONG *lpcbWrappedEntry,LPENTRYID *lppWrappedEntry);

#define RTF_SYNC_RTF_CHANGED ((ULONG) 0x00000001)
#define RTF_SYNC_BODY_CHANGED ((ULONG) 0x00000002)

  STDAPI_(HRESULT) RTFSync (LPMESSAGE lpMessage,ULONG ulFlags,WINBOOL *lpfMessageUpdated);
  STDAPI_(HRESULT) WrapCompressedRTFStream (LPSTREAM lpCompressedRTFStream,ULONG ulFlags,LPSTREAM *lpUncompressedRTFStream);
  STDAPI_(HRESULT) HrIStorageFromStream (LPUNKNOWN lpUnkIn,LPCIID lpInterface,ULONG ulFlags,LPSTORAGE *lppStorageOut);
  STDAPI_(SCODE) ScInitMapiUtil(ULONG ulFlags);
  STDAPI_(VOID) DeinitMapiUtil(VOID);

#ifdef _X86_
#define szHrDispatchNotifications "_HrDispatchNotifications@4"
#endif

  typedef HRESULT (WINAPI DISPATCHNOTIFICATIONS)(ULONG ulFlags);
  typedef DISPATCHNOTIFICATIONS *LPDISPATCHNOTIFICATIONS;

#ifdef _X86_
#define szScCreateConversationIndex "_ScCreateConversationIndex@16"
#endif

  typedef SCODE (WINAPI CREATECONVERSATIONINDEX)(ULONG cbParent,LPBYTE lpbParent,ULONG *lpcbConvIndex,LPBYTE *lppbConvIndex);
  typedef CREATECONVERSATIONINDEX *LPCREATECONVERSATIONINDEX;

#ifdef __cplusplus
}
#endif
#endif
