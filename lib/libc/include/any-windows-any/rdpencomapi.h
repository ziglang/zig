/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_RDPENCOMAPI
#define _INC_RDPENCOMAPI

#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _ATTENDEE_DISCONNECT_REASON {
  ATTENDEE_DISCONNECT_REASON_MIN   = 0,
  ATTENDEE_DISCONNECT_REASON_APP   = 0,
  ATTENDEE_DISCONNECT_REASON_ERR   = 1,
  ATTENDEE_DISCONNECT_REASON_CLI   = 2,
  ATTENDEE_DISCONNECT_REASON_MAX   = 2
} ATTENDEE_DISCONNECT_REASON;

typedef enum _CHANNEL_ACCESS_ENUM {
  CHANNEL_ACCESS_ENUM_NONE          = 0,
  CHANNEL_ACCESS_ENUM_SENDRECEIVE   = 1
} CHANNEL_ACCESS_ENUM;

typedef enum _CHANNEL_FLAGS {
  CHANNEL_FLAGS_LEGACY         = 0x01,
  CHANNEL_FLAGS_UNCOMPRESSED   = 0x02
} CHANNEL_FLAGS;

typedef enum _CHANNEL_PRIORITY {
  CHANNEL_PRIORITY_LO    = 0,
  CHANNEL_PRIORITY_MED   = 1,
  CHANNEL_PRIORITY_HI    = 2
} CHANNEL_PRIORITY;

typedef enum _CTRL_LEVEL {
  CTRL_LEVEL_MIN           = 0,
  CTRL_LEVEL_INVALID       = 0,
  CTRL_LEVEL_NONE          = 1,
  CTRL_LEVEL_VIEW          = 2,
  CTRL_LEVEL_INTERACTIVE   = 3,
  CTRL_LEVEL_MAX           = 3
} CTRL_LEVEL;

typedef enum _RDPENCOMAPI_ATTENDEE_FLAGS {
  ATTENDEE_FLAGS_LOCAL   = 1
} RDPENCOMAPI_ATTENDEE_FLAGS;

typedef enum _RDPENCOMAPI_CONSTANTS {
  CONST_MAX_CHANNEL_MESSAGE_SIZE          = 1024,
  CONST_MAX_CHANNEL_NAME_LEN              = 8,
  CONST_MAX_LEGACY_CHANNEL_MESSAGE_SIZE   = 409600,
  CONST_ATTENDEE_ID_EVERYONE              = -1,
  CONST_ATTENDEE_ID_HOST                  = 0,
  CONST_CONN_INTERVAL                     = 50
} RDPENCOMAPI_CONSTANTS;

typedef enum _RDPSRAPI_APP_FLAGS {
  APP_FLAG_PRIVILEGED   = 1
} RDPSRAPI_APP_FLAGS;

typedef enum _RDPSRAPI_WND_FLAGS {
  WND_FLAG_PRIVILEGED   = 1
} RDPSRAPI_WND_FLAGS;

#ifdef __cplusplus
}
#endif

#undef  INTERFACE
#define INTERFACE IRDPSRAPITcpConnectionInfo
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IRDPSRAPITcpConnectionInfo,IDispatch)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDispatch methods */
    STDMETHOD_(HRESULT,GetTypeInfoCount)(THIS_ unsigned int FAR*  pctinfo) PURE;
    STDMETHOD_(HRESULT,GetTypeInfo)(THIS_ unsigned int  iTInfo,LCID  lcid,ITypeInfo FAR* FAR*  ppTInfo) PURE;
    STDMETHOD_(HRESULT,GetIDsOfNames)(THIS_ REFIID  riid,OLECHAR FAR* FAR*  rgszNames,unsigned int  cNames,LCID   lcid,DISPID FAR*  rgDispId) PURE;
    STDMETHOD_(HRESULT,Invoke)(THIS_ DISPID  dispIdMember,REFIID  riid,LCID  lcid,WORD  wFlags,DISPPARAMS FAR*  pDispParams,VARIANT FAR*  pVarResult,EXCEPINFO FAR*  pExcepInfo,unsigned int FAR*  puArgErr) PURE;

    /* IRDPSRAPITcpConnectionInfo methods */
    STDMETHOD_(HRESULT,get_Protocol)(THIS_ __LONG32 *plProtocol) PURE;
    STDMETHOD_(HRESULT,get_LocalPort)(THIS_ __LONG32 *plPort) PURE;
    STDMETHOD_(HRESULT,get_LocalIP)(THIS_ BSTR *pbstrLocalIP) PURE;
    STDMETHOD_(HRESULT,get_PeerPort)(THIS_ __LONG32 *plPort) PURE;
    STDMETHOD_(HRESULT,get_PeerIP)(THIS_ BSTR *pbstrIP) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IRDPSRAPITcpConnectionInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRDPSRAPITcpConnectionInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRDPSRAPITcpConnectionInfo_Release(This) (This)->lpVtbl->Release(This)
#define IRDPSRAPITcpConnectionInfo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRDPSRAPITcpConnectionInfo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRDPSRAPITcpConnectionInfo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRDPSRAPITcpConnectionInfo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRDPSRAPITcpConnectionInfo_get_Protocol(This,plProtocol) (This)->lpVtbl->get_Protocol(This,plProtocol)
#define IRDPSRAPITcpConnectionInfo_get_LocalPort(This,plPort) (This)->lpVtbl->get_LocalPort(This,plPort)
#define IRDPSRAPITcpConnectionInfo_get_LocalIP(This,pbstrLocalIP) (This)->lpVtbl->get_LocalIP(This,pbstrLocalIP)
#define IRDPSRAPITcpConnectionInfo_get_PeerPort(This,plPort) (This)->lpVtbl->get_PeerPort(This,plPort)
#define IRDPSRAPITcpConnectionInfo_get_PeerIP(This,pbstrIP) (This)->lpVtbl->get_PeerIP(This,pbstrIP)
#endif /*COBJMACROS*/

#undef  INTERFACE
#define INTERFACE IRDPSRAPIAttendee
#ifdef __GNUC__
#warning COM interfaces layout in this header has not been verified.
#warning COM interfaces with incorrect layout may not work at all.
__MINGW_BROKEN_INTERFACE(INTERFACE)
#endif
DECLARE_INTERFACE_(IRDPSRAPIAttendee,IDispatch)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IDispatch methods */
    STDMETHOD_(HRESULT,GetTypeInfoCount)(THIS_ unsigned int FAR*  pctinfo) PURE;
    STDMETHOD_(HRESULT,GetTypeInfo)(THIS_ unsigned int  iTInfo,LCID  lcid,ITypeInfo FAR* FAR*  ppTInfo) PURE;
    STDMETHOD_(HRESULT,GetIDsOfNames)(THIS_ REFIID  riid,OLECHAR FAR* FAR*  rgszNames,unsigned int  cNames,LCID   lcid,DISPID FAR*  rgDispId) PURE;
    STDMETHOD_(HRESULT,Invoke)(THIS_ DISPID  dispIdMember,REFIID  riid,LCID  lcid,WORD  wFlags,DISPPARAMS FAR*  pDispParams,VARIANT FAR*  pVarResult,EXCEPINFO FAR*  pExcepInfo,unsigned int FAR*  puArgErr) PURE;

    /* IRDPSRAPIAttendee methods */
    STDMETHOD_(HRESULT,get_Id)(THIS_ __LONG32 *pId) PURE;
    STDMETHOD_(HRESULT,get_RemoteName)(THIS_ BSTR *pVal) PURE;
    STDMETHOD_(HRESULT,get_ControlLevel)(THIS_ CTRL_LEVEL *pVal) PURE;
    STDMETHOD_(HRESULT,put_ControlLevel)(THIS_ CTRL_LEVEL pNewVal) PURE;
    STDMETHOD_(HRESULT,get_Invitation)(THIS_ IRDPSRAPIInvitation **ppVal) PURE;
    STDMETHOD_(HRESULT,TerminateConnection)(THIS) PURE;
    STDMETHOD_(HRESULT,get_Flags)(THIS_ __LONG32 *plFlags) PURE;
    STDMETHOD_(HRESULT,get_ConnectivityInfo)(THIS_ IUnknown **ppVal) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IRDPSRAPIAttendee_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRDPSRAPIAttendee_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRDPSRAPIAttendee_Release(This) (This)->lpVtbl->Release(This)
#define IRDPSRAPIAttendee_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRDPSRAPIAttendee_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRDPSRAPIAttendee_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRDPSRAPIAttendee_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRDPSRAPIAttendee_get_Id(This,pId) (This)->lpVtbl->get_Id(This,pId)
#define IRDPSRAPIAttendee_get_RemoteName(This,pVal) (This)->lpVtbl->get_RemoteName(This,pVal)
#define IRDPSRAPIAttendee_get_ControlLevel(This,pVal) (This)->lpVtbl->get_ControlLevel(This,pVal)
#define IRDPSRAPIAttendee_put_ControlLevel(This,pNewVal) (This)->lpVtbl->put_ControlLevel(This,pNewVal)
#define IRDPSRAPIAttendee_get_Invitation(This,ppVal) (This)->lpVtbl->get_Invitation(This,ppVal)
#define IRDPSRAPIAttendee_TerminateConnection() (This)->lpVtbl->TerminateConnection(This)
#define IRDPSRAPIAttendee_get_Flags(This,plFlags) (This)->lpVtbl->get_Flags(This,plFlags)
#define IRDPSRAPIAttendee_get_ConnectivityInfo(This,ppVal) (This)->lpVtbl->get_ConnectivityInfo(This,ppVal)
#endif /*COBJMACROS*/

#endif /*(_WIN32_WINNT >= 0x0600)*/

#endif /*_INC_RDPENCOMAPI */

