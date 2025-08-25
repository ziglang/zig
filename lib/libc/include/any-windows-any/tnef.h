/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef TNEF_H
#define TNEF_H

#ifdef __cplusplus
extern "C" {
#endif

#ifndef BEGIN_INTERFACE
#define BEGIN_INTERFACE
#endif

  typedef struct _STnefProblem {
    ULONG ulComponent;
    ULONG ulAttribute;
    ULONG ulPropTag;
    SCODE scode;
  } STnefProblem;

  typedef struct _STnefProblemArray {
    ULONG cProblem;
    STnefProblem aProblem[MAPI_DIM];
  } STnefProblemArray,*LPSTnefProblemArray;

#define CbNewSTnefProblemArray(_cprob) (offsetof(STnefProblemArray,aProblem) + (_cprob)*sizeof(STnefProblem))
#define CbSTnefProblemArray(_lparray) (offsetof(STnefProblemArray,aProblem) + (UINT) ((_lparray)->cProblem*sizeof(STnefProblem)))

  DECLARE_MAPI_INTERFACE_PTR(ITnef,LPITNEF);

#define TNEF_DECODE ((ULONG) 0)
#define TNEF_ENCODE ((ULONG) 2)

#define TNEF_PURE ((ULONG) 0x00010000)
#define TNEF_COMPATIBILITY ((ULONG) 0x00020000)
#define TNEF_BEST_DATA ((ULONG) 0x00040000)
#define TNEF_COMPONENT_ENCODING ((ULONG) 0x80000000)

#define TNEF_PROP_INCLUDE ((ULONG) 0x00000001)
#define TNEF_PROP_EXCLUDE ((ULONG) 0x00000002)
#define TNEF_PROP_CONTAINED ((ULONG) 0x00000004)
#define TNEF_PROP_MESSAGE_ONLY ((ULONG) 0x00000008)
#define TNEF_PROP_ATTACHMENTS_ONLY ((ULONG) 0x00000010)
#define TNEF_PROP_CONTAINED_TNEF ((ULONG) 0x00000040)

#define TNEF_COMPONENT_MESSAGE ((ULONG) 0x00001000)
#define TNEF_COMPONENT_ATTACHMENT ((ULONG) 0x00002000)

#define MAPI_ITNEF_METHODS(IPURE) MAPIMETHOD(AddProps) (THIS_ ULONG ulFlags,ULONG ulElemID,LPVOID lpvData,LPSPropTagArray lpPropList) IPURE; MAPIMETHOD(ExtractProps) (THIS_ ULONG ulFlags,LPSPropTagArray lpPropList,LPSTnefProblemArray *lpProblems) IPURE; MAPIMETHOD(Finish) (THIS_ ULONG ulFlags,WORD *lpKey,LPSTnefProblemArray *lpProblems) IPURE; MAPIMETHOD(OpenTaggedBody) (THIS_ LPMESSAGE lpMessage,ULONG ulFlags,LPSTREAM *lppStream) IPURE; MAPIMETHOD(SetProps) (THIS_ ULONG ulFlags,ULONG ulElemID,ULONG cValues,LPSPropValue lpProps) IPURE; MAPIMETHOD(EncodeRecips) (THIS_ ULONG ulFlags,LPMAPITABLE lpRecipientTable) IPURE; MAPIMETHOD(FinishComponent) (THIS_ ULONG ulFlags,ULONG ulComponentID,LPSPropTagArray lpCustomPropList,LPSPropValue lpCustomProps,LPSPropTagArray lpPropList,LPSTnefProblemArray *lpProblems) IPURE;
#undef INTERFACE
#define INTERFACE ITnef
  DECLARE_MAPI_INTERFACE_(ITnef,IUnknown) {
    BEGIN_INTERFACE
      MAPI_IUNKNOWN_METHODS(PURE)
      MAPI_ITNEF_METHODS(PURE)
  };

  STDMETHODIMP OpenTnefStream(LPVOID lpvSupport,LPSTREAM lpStream,LPTSTR lpszStreamName,ULONG ulFlags,LPMESSAGE lpMessage,WORD wKeyVal,LPITNEF *lppTNEF);
  typedef HRESULT (WINAPI *LPOPENTNEFSTREAM) (LPVOID lpvSupport,LPSTREAM lpStream,LPTSTR lpszStreamName,ULONG ulFlags,LPMESSAGE lpMessage,WORD wKeyVal,LPITNEF *lppTNEF);
  STDMETHODIMP OpenTnefStreamEx(LPVOID lpvSupport,LPSTREAM lpStream,LPTSTR lpszStreamName,ULONG ulFlags,LPMESSAGE lpMessage,WORD wKeyVal,LPADRBOOK lpAdressBook,LPITNEF *lppTNEF);
  typedef HRESULT (WINAPI *LPOPENTNEFSTREAMEX) (LPVOID lpvSupport,LPSTREAM lpStream,LPTSTR lpszStreamName,ULONG ulFlags,LPMESSAGE lpMessage,WORD wKeyVal,LPADRBOOK lpAdressBook,LPITNEF *lppTNEF);
  STDMETHODIMP GetTnefStreamCodepage (LPSTREAM lpStream,ULONG *lpulCodepage,ULONG *lpulSubCodepage);
  typedef HRESULT (WINAPI *LPGETTNEFSTREAMCODEPAGE) (LPSTREAM lpStream,ULONG *lpulCodepage,ULONG *lpulSubCodepage);

#define OPENTNEFSTREAM "OpenTnefStream"
#define OPENTNEFSTREAMEX "OpenTnefStreamEx"
#define GETTNEFSTREAMCODEPAGE "GetTnefStreamCodePage"

#define MAKE_TNEF_VERSION(_mj,_mn) (((ULONG)(0x0000FFFF & _mj) << 16) | (ULONG)(0x0000FFFF & _mn))
#define TNEF_SIGNATURE ((ULONG) 0x223E9F78)
#define TNEF_VERSION ((ULONG) MAKE_TNEF_VERSION(1,0))

  typedef WORD ATYP;
  enum { atypNull,atypFile,atypOle,atypPicture,atypMax };

#define MAC_BINARY ((DWORD) 0x00000001)

#include <pshpack1.h>
  typedef struct _renddata {
    ATYP atyp;
    ULONG ulPosition;
    WORD dxWidth;
    WORD dyHeight;
    DWORD dwFlags;
  } RENDDATA,*PRENDDATA;
#include <poppack.h>

#include <pshpack1.h>
  typedef struct _dtr {
    WORD wYear;
    WORD wMonth;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wDayOfWeek;
  } DTR;
#include <poppack.h>

#define fmsNull ((BYTE) 0x00)
#define fmsModified ((BYTE) 0x01)
#define fmsLocal ((BYTE) 0x02)
#define fmsSubmitted ((BYTE) 0x04)
#define fmsRead ((BYTE) 0x20)
#define fmsHasAttach ((BYTE) 0x80)

#define trpidNull ((WORD) 0x0000)
#define trpidUnresolved ((WORD) 0x0001)
#define trpidResolvedNSID ((WORD) 0x0002)
#define trpidResolvedAddress ((WORD) 0x0003)
#define trpidOneOff ((WORD) 0x0004)
#define trpidGroupNSID ((WORD) 0x0005)
#define trpidOffline ((WORD) 0x0006)
#define trpidIgnore ((WORD) 0x0007)
#define trpidClassEntry ((WORD) 0x0008)
#define trpidResolvedGroupAddress ((WORD) 0x0009)
  typedef struct _trp {
    WORD trpid;
    WORD cbgrtrp;
    WORD cch;
    WORD cbRgb;
  } TRP,*PTRP,*PGRTRP,*LPTRP;
#define CbOfTrp(_p) (sizeof(TRP) + (_p)->cch + (_p)->cbRgb)
#define LpszOfTrp(_p) ((LPSTR)(((LPTRP) (_p)) + 1))
#define LpbOfTrp(_p) (((LPBYTE)(((LPTRP)(_p)) + 1)) + (_p)->cch)
#define LptrpNext(_p) ((LPTRP)((LPBYTE)(_p) + CbOfTrp(_p)))

  typedef DWORD XTYPE;
#define xtypeUnknown ((XTYPE) 0)
#define xtypeInternet ((XTYPE) 6)

#define cbDisplayName 41
#define cbEmailName 11
#define cbSeverName 12
  typedef struct _ADDR_ALIAS {
    char rgchName[cbDisplayName];
    char rgchEName[cbEmailName];
    char rgchSrvr[cbSeverName];
    ULONG dibDetail;
    WORD type;
  } ADDRALIAS,*LPADDRALIAS;
#define cbALIAS sizeof(ALIAS)

#define cbTYPE 16
#define cbMaxIdData 200
  typedef struct _NSID {
    DWORD dwSize;
    unsigned char uchType[cbTYPE];
    XTYPE xtype;
    LONG lTime;
    union {
      ADDRALIAS alias;
      char rgchInterNet[1];
    } address;
  } NSID,*LPNSID;
#define cbNSID sizeof(NSID)

#define prioLow 3
#define prioNorm 2
#define prioHigh 1

#define atpTriples ((WORD) 0x0000)
#define atpString ((WORD) 0x0001)
#define atpText ((WORD) 0x0002)
#define atpDate ((WORD) 0x0003)
#define atpShort ((WORD) 0x0004)
#define atpLong ((WORD) 0x0005)
#define atpByte ((WORD) 0x0006)
#define atpWord ((WORD) 0x0007)
#define atpDword ((WORD) 0x0008)
#define atpMax ((WORD) 0x0009)

#define LVL_MESSAGE ((BYTE) 0x01)
#define LVL_ATTACHMENT ((BYTE) 0x02)

#define ATT_ID(_att) ((WORD) ((_att) & 0x0000FFFF))
#define ATT_TYPE(_att) ((WORD) (((_att) >> 16) & 0x0000FFFF))
#define ATT(_atp,_id) ((((DWORD) (_atp)) << 16) | ((WORD) (_id)))

#define attNull ATT(0,0x0000)
#define attFrom ATT(atpTriples,0x8000)
#define attSubject ATT(atpString,0x8004)
#define attDateSent ATT(atpDate,0x8005)
#define attDateRecd ATT(atpDate,0x8006)
#define attMessageStatus ATT(atpByte,0x8007)
#define attMessageClass ATT(atpWord,0x8008)
#define attMessageID ATT(atpString,0x8009)
#define attParentID ATT(atpString,0x800A)
#define attConversationID ATT(atpString,0x800B)
#define attBody ATT(atpText,0x800C)
#define attPriority ATT(atpShort,0x800D)
#define attAttachData ATT(atpByte,0x800F)
#define attAttachTitle ATT(atpString,0x8010)
#define attAttachMetaFile ATT(atpByte,0x8011)
#define attAttachCreateDate ATT(atpDate,0x8012)
#define attAttachModifyDate ATT(atpDate,0x8013)
#define attDateModified ATT(atpDate,0x8020)
#define attAttachTransportFilename ATT(atpByte,0x9001)
#define attAttachRenddata ATT(atpByte,0x9002)
#define attMAPIProps ATT(atpByte,0x9003)
#define attRecipTable ATT(atpByte,0x9004)
#define attAttachment ATT(atpByte,0x9005)
#define attTnefVersion ATT(atpDword,0x9006)
#define attOemCodepage ATT(atpByte,0x9007)
#define attOriginalMessageClass ATT(atpWord,0x0006)

#define attOwner ATT(atpByte,0x0000)
#define attSentFor ATT(atpByte,0x0001)
#define attDelegate ATT(atpByte,0x0002)
#define attDateStart ATT(atpDate,0x0006)
#define attDateEnd ATT(atpDate,0x0007)
#define attAidOwner ATT(atpLong,0x0008)
#define attRequestRes ATT(atpShort,0x0009)

#ifdef __cplusplus
}
#endif
#endif
