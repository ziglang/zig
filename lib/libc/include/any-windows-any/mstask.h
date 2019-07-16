/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __mstask_h__
#define __mstask_h__

#ifndef __ITaskTrigger_FWD_DEFINED__
#define __ITaskTrigger_FWD_DEFINED__
typedef struct ITaskTrigger ITaskTrigger;
#endif

#ifndef __IScheduledWorkItem_FWD_DEFINED__
#define __IScheduledWorkItem_FWD_DEFINED__
typedef struct IScheduledWorkItem IScheduledWorkItem;
#endif

#ifndef __ITask_FWD_DEFINED__
#define __ITask_FWD_DEFINED__
typedef struct ITask ITask;
#endif

#ifndef __IEnumWorkItems_FWD_DEFINED__
#define __IEnumWorkItems_FWD_DEFINED__
typedef struct IEnumWorkItems IEnumWorkItems;
#endif

#ifndef __ITaskScheduler_FWD_DEFINED__
#define __ITaskScheduler_FWD_DEFINED__
typedef struct ITaskScheduler ITaskScheduler;
#endif

#ifndef __IProvideTaskPage_FWD_DEFINED__
#define __IProvideTaskPage_FWD_DEFINED__
typedef struct IProvideTaskPage IProvideTaskPage;
#endif

#include "oaidl.h"
#include "oleidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define TASK_SUNDAY (0x1)
#define TASK_MONDAY (0x2)
#define TASK_TUESDAY (0x4)
#define TASK_WEDNESDAY (0x8)
#define TASK_THURSDAY (0x10)
#define TASK_FRIDAY (0x20)
#define TASK_SATURDAY (0x40)
#define TASK_FIRST_WEEK (1)
#define TASK_SECOND_WEEK (2)
#define TASK_THIRD_WEEK (3)
#define TASK_FOURTH_WEEK (4)
#define TASK_LAST_WEEK (5)
#define TASK_JANUARY (0x1)
#define TASK_FEBRUARY (0x2)
#define TASK_MARCH (0x4)
#define TASK_APRIL (0x8)
#define TASK_MAY (0x10)
#define TASK_JUNE (0x20)
#define TASK_JULY (0x40)
#define TASK_AUGUST (0x80)
#define TASK_SEPTEMBER (0x100)
#define TASK_OCTOBER (0x200)
#define TASK_NOVEMBER (0x400)
#define TASK_DECEMBER (0x800)
#define TASK_FLAG_INTERACTIVE (0x1)
#define TASK_FLAG_DELETE_WHEN_DONE (0x2)
#define TASK_FLAG_DISABLED (0x4)
#define TASK_FLAG_START_ONLY_IF_IDLE (0x10)
#define TASK_FLAG_KILL_ON_IDLE_END (0x20)
#define TASK_FLAG_DONT_START_IF_ON_BATTERIES (0x40)
#define TASK_FLAG_KILL_IF_GOING_ON_BATTERIES (0x80)
#define TASK_FLAG_RUN_ONLY_IF_DOCKED (0x100)
#define TASK_FLAG_HIDDEN (0x200)
#define TASK_FLAG_RUN_IF_CONNECTED_TO_INTERNET (0x400)
#define TASK_FLAG_RESTART_ON_IDLE_RESUME (0x800)
#define TASK_FLAG_SYSTEM_REQUIRED (0x1000)
#define TASK_FLAG_RUN_ONLY_IF_LOGGED_ON (0x2000)
#define TASK_TRIGGER_FLAG_HAS_END_DATE (0x1)
#define TASK_TRIGGER_FLAG_KILL_AT_DURATION_END (0x2)
#define TASK_TRIGGER_FLAG_DISABLED (0x4)
#define TASK_MAX_RUN_TIMES (1440)

  typedef enum _TASK_TRIGGER_TYPE {
    TASK_TIME_TRIGGER_ONCE = 0,TASK_TIME_TRIGGER_DAILY = 1,TASK_TIME_TRIGGER_WEEKLY = 2,TASK_TIME_TRIGGER_MONTHLYDATE = 3,
    TASK_TIME_TRIGGER_MONTHLYDOW = 4,TASK_EVENT_TRIGGER_ON_IDLE = 5,TASK_EVENT_TRIGGER_AT_SYSTEMSTART = 6,TASK_EVENT_TRIGGER_AT_LOGON = 7
  } TASK_TRIGGER_TYPE;

  typedef enum _TASK_TRIGGER_TYPE *PTASK_TRIGGER_TYPE;

  typedef struct _DAILY {
    WORD DaysInterval;
  } DAILY;

  typedef struct _WEEKLY {
    WORD WeeksInterval;
    WORD rgfDaysOfTheWeek;
  } WEEKLY;

  typedef struct _MONTHLYDATE {
    DWORD rgfDays;
    WORD rgfMonths;
  } MONTHLYDATE;

  typedef struct _MONTHLYDOW {
    WORD wWhichWeek;
    WORD rgfDaysOfTheWeek;
    WORD rgfMonths;
  } MONTHLYDOW;

  typedef union _TRIGGER_TYPE_UNION {
    DAILY Daily;
    WEEKLY Weekly;
    MONTHLYDATE MonthlyDate;
    MONTHLYDOW MonthlyDOW;
  } TRIGGER_TYPE_UNION;

  typedef struct _TASK_TRIGGER {
    WORD cbTriggerSize;
    WORD Reserved1;
    WORD wBeginYear;
    WORD wBeginMonth;
    WORD wBeginDay;
    WORD wEndYear;
    WORD wEndMonth;
    WORD wEndDay;
    WORD wStartHour;
    WORD wStartMinute;
    DWORD MinutesDuration;
    DWORD MinutesInterval;
    DWORD rgFlags;
    TASK_TRIGGER_TYPE TriggerType;
    TRIGGER_TYPE_UNION Type;
    WORD Reserved2;
    WORD wRandomMinutesInterval;
  } TASK_TRIGGER;

  typedef struct _TASK_TRIGGER *PTASK_TRIGGER;

  DEFINE_GUID(IID_ITaskTrigger,0x148BD52B,0xA2AB,0x11CE,0xB1,0x1F,0x00,0xAA,0x00,0x53,0x05,0x03);

  extern RPC_IF_HANDLE __MIDL_itf_mstask_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mstask_0000_v0_0_s_ifspec;

#ifndef __ITaskTrigger_INTERFACE_DEFINED__
#define __ITaskTrigger_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITaskTrigger;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITaskTrigger : public IUnknown {
  public:
    virtual HRESULT WINAPI SetTrigger(const PTASK_TRIGGER pTrigger) = 0;
    virtual HRESULT WINAPI GetTrigger(PTASK_TRIGGER pTrigger) = 0;
    virtual HRESULT WINAPI GetTriggerString(LPWSTR *ppwszTrigger) = 0;
  };
#else
  typedef struct ITaskTriggerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITaskTrigger *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITaskTrigger *This);
      ULONG (WINAPI *Release)(ITaskTrigger *This);
      HRESULT (WINAPI *SetTrigger)(ITaskTrigger *This,const PTASK_TRIGGER pTrigger);
      HRESULT (WINAPI *GetTrigger)(ITaskTrigger *This,PTASK_TRIGGER pTrigger);
      HRESULT (WINAPI *GetTriggerString)(ITaskTrigger *This,LPWSTR *ppwszTrigger);
    END_INTERFACE
  } ITaskTriggerVtbl;
  struct ITaskTrigger {
    CONST_VTBL struct ITaskTriggerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITaskTrigger_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITaskTrigger_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITaskTrigger_Release(This) (This)->lpVtbl->Release(This)
#define ITaskTrigger_SetTrigger(This,pTrigger) (This)->lpVtbl->SetTrigger(This,pTrigger)
#define ITaskTrigger_GetTrigger(This,pTrigger) (This)->lpVtbl->GetTrigger(This,pTrigger)
#define ITaskTrigger_GetTriggerString(This,ppwszTrigger) (This)->lpVtbl->GetTriggerString(This,ppwszTrigger)
#endif
#endif
  HRESULT WINAPI ITaskTrigger_SetTrigger_Proxy(ITaskTrigger *This,const PTASK_TRIGGER pTrigger);
  void __RPC_STUB ITaskTrigger_SetTrigger_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITaskTrigger_GetTrigger_Proxy(ITaskTrigger *This,PTASK_TRIGGER pTrigger);
  void __RPC_STUB ITaskTrigger_GetTrigger_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITaskTrigger_GetTriggerString_Proxy(ITaskTrigger *This,LPWSTR *ppwszTrigger);
  void __RPC_STUB ITaskTrigger_GetTriggerString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(IID_IScheduledWorkItem,0xa6b952f0,0xa4b1,0x11d0,0x99,0x7d,0x00,0xaa,0x00,0x68,0x87,0xec);
  extern RPC_IF_HANDLE __MIDL_itf_mstask_0140_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mstask_0140_v0_0_s_ifspec;
#ifndef __IScheduledWorkItem_INTERFACE_DEFINED__
#define __IScheduledWorkItem_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IScheduledWorkItem;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IScheduledWorkItem : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateTrigger(WORD *piNewTrigger,ITaskTrigger **ppTrigger) = 0;
    virtual HRESULT WINAPI DeleteTrigger(WORD iTrigger) = 0;
    virtual HRESULT WINAPI GetTriggerCount(WORD *pwCount) = 0;
    virtual HRESULT WINAPI GetTrigger(WORD iTrigger,ITaskTrigger **ppTrigger) = 0;
    virtual HRESULT WINAPI GetTriggerString(WORD iTrigger,LPWSTR *ppwszTrigger) = 0;
    virtual HRESULT WINAPI GetRunTimes(const LPSYSTEMTIME pstBegin,const LPSYSTEMTIME pstEnd,WORD *pCount,LPSYSTEMTIME *rgstTaskTimes) = 0;
    virtual HRESULT WINAPI GetNextRunTime(SYSTEMTIME *pstNextRun) = 0;
    virtual HRESULT WINAPI SetIdleWait(WORD wIdleMinutes,WORD wDeadlineMinutes) = 0;
    virtual HRESULT WINAPI GetIdleWait(WORD *pwIdleMinutes,WORD *pwDeadlineMinutes) = 0;
    virtual HRESULT WINAPI Run(void) = 0;
    virtual HRESULT WINAPI Terminate(void) = 0;
    virtual HRESULT WINAPI EditWorkItem(HWND hParent,DWORD dwReserved) = 0;
    virtual HRESULT WINAPI GetMostRecentRunTime(SYSTEMTIME *pstLastRun) = 0;
    virtual HRESULT WINAPI GetStatus(HRESULT *phrStatus) = 0;
    virtual HRESULT WINAPI GetExitCode(DWORD *pdwExitCode) = 0;
    virtual HRESULT WINAPI SetComment(LPCWSTR pwszComment) = 0;
    virtual HRESULT WINAPI GetComment(LPWSTR *ppwszComment) = 0;
    virtual HRESULT WINAPI SetCreator(LPCWSTR pwszCreator) = 0;
    virtual HRESULT WINAPI GetCreator(LPWSTR *ppwszCreator) = 0;
    virtual HRESULT WINAPI SetWorkItemData(WORD cbData,BYTE rgbData[]) = 0;
    virtual HRESULT WINAPI GetWorkItemData(WORD *pcbData,BYTE **prgbData) = 0;
    virtual HRESULT WINAPI SetErrorRetryCount(WORD wRetryCount) = 0;
    virtual HRESULT WINAPI GetErrorRetryCount(WORD *pwRetryCount) = 0;
    virtual HRESULT WINAPI SetErrorRetryInterval(WORD wRetryInterval) = 0;
    virtual HRESULT WINAPI GetErrorRetryInterval(WORD *pwRetryInterval) = 0;
    virtual HRESULT WINAPI SetFlags(DWORD dwFlags) = 0;
    virtual HRESULT WINAPI GetFlags(DWORD *pdwFlags) = 0;
    virtual HRESULT WINAPI SetAccountInformation(LPCWSTR pwszAccountName,LPCWSTR pwszPassword) = 0;
    virtual HRESULT WINAPI GetAccountInformation(LPWSTR *ppwszAccountName) = 0;
  };
#else
  typedef struct IScheduledWorkItemVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IScheduledWorkItem *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IScheduledWorkItem *This);
      ULONG (WINAPI *Release)(IScheduledWorkItem *This);
      HRESULT (WINAPI *CreateTrigger)(IScheduledWorkItem *This,WORD *piNewTrigger,ITaskTrigger **ppTrigger);
      HRESULT (WINAPI *DeleteTrigger)(IScheduledWorkItem *This,WORD iTrigger);
      HRESULT (WINAPI *GetTriggerCount)(IScheduledWorkItem *This,WORD *pwCount);
      HRESULT (WINAPI *GetTrigger)(IScheduledWorkItem *This,WORD iTrigger,ITaskTrigger **ppTrigger);
      HRESULT (WINAPI *GetTriggerString)(IScheduledWorkItem *This,WORD iTrigger,LPWSTR *ppwszTrigger);
      HRESULT (WINAPI *GetRunTimes)(IScheduledWorkItem *This,const LPSYSTEMTIME pstBegin,const LPSYSTEMTIME pstEnd,WORD *pCount,LPSYSTEMTIME *rgstTaskTimes);
      HRESULT (WINAPI *GetNextRunTime)(IScheduledWorkItem *This,SYSTEMTIME *pstNextRun);
      HRESULT (WINAPI *SetIdleWait)(IScheduledWorkItem *This,WORD wIdleMinutes,WORD wDeadlineMinutes);
      HRESULT (WINAPI *GetIdleWait)(IScheduledWorkItem *This,WORD *pwIdleMinutes,WORD *pwDeadlineMinutes);
      HRESULT (WINAPI *Run)(IScheduledWorkItem *This);
      HRESULT (WINAPI *Terminate)(IScheduledWorkItem *This);
      HRESULT (WINAPI *EditWorkItem)(IScheduledWorkItem *This,HWND hParent,DWORD dwReserved);
      HRESULT (WINAPI *GetMostRecentRunTime)(IScheduledWorkItem *This,SYSTEMTIME *pstLastRun);
      HRESULT (WINAPI *GetStatus)(IScheduledWorkItem *This,HRESULT *phrStatus);
      HRESULT (WINAPI *GetExitCode)(IScheduledWorkItem *This,DWORD *pdwExitCode);
      HRESULT (WINAPI *SetComment)(IScheduledWorkItem *This,LPCWSTR pwszComment);
      HRESULT (WINAPI *GetComment)(IScheduledWorkItem *This,LPWSTR *ppwszComment);
      HRESULT (WINAPI *SetCreator)(IScheduledWorkItem *This,LPCWSTR pwszCreator);
      HRESULT (WINAPI *GetCreator)(IScheduledWorkItem *This,LPWSTR *ppwszCreator);
      HRESULT (WINAPI *SetWorkItemData)(IScheduledWorkItem *This,WORD cbData,BYTE rgbData[]);
      HRESULT (WINAPI *GetWorkItemData)(IScheduledWorkItem *This,WORD *pcbData,BYTE **prgbData);
      HRESULT (WINAPI *SetErrorRetryCount)(IScheduledWorkItem *This,WORD wRetryCount);
      HRESULT (WINAPI *GetErrorRetryCount)(IScheduledWorkItem *This,WORD *pwRetryCount);
      HRESULT (WINAPI *SetErrorRetryInterval)(IScheduledWorkItem *This,WORD wRetryInterval);
      HRESULT (WINAPI *GetErrorRetryInterval)(IScheduledWorkItem *This,WORD *pwRetryInterval);
      HRESULT (WINAPI *SetFlags)(IScheduledWorkItem *This,DWORD dwFlags);
      HRESULT (WINAPI *GetFlags)(IScheduledWorkItem *This,DWORD *pdwFlags);
      HRESULT (WINAPI *SetAccountInformation)(IScheduledWorkItem *This,LPCWSTR pwszAccountName,LPCWSTR pwszPassword);
      HRESULT (WINAPI *GetAccountInformation)(IScheduledWorkItem *This,LPWSTR *ppwszAccountName);
    END_INTERFACE
  } IScheduledWorkItemVtbl;
  struct IScheduledWorkItem {
    CONST_VTBL struct IScheduledWorkItemVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IScheduledWorkItem_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IScheduledWorkItem_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IScheduledWorkItem_Release(This) (This)->lpVtbl->Release(This)
#define IScheduledWorkItem_CreateTrigger(This,piNewTrigger,ppTrigger) (This)->lpVtbl->CreateTrigger(This,piNewTrigger,ppTrigger)
#define IScheduledWorkItem_DeleteTrigger(This,iTrigger) (This)->lpVtbl->DeleteTrigger(This,iTrigger)
#define IScheduledWorkItem_GetTriggerCount(This,pwCount) (This)->lpVtbl->GetTriggerCount(This,pwCount)
#define IScheduledWorkItem_GetTrigger(This,iTrigger,ppTrigger) (This)->lpVtbl->GetTrigger(This,iTrigger,ppTrigger)
#define IScheduledWorkItem_GetTriggerString(This,iTrigger,ppwszTrigger) (This)->lpVtbl->GetTriggerString(This,iTrigger,ppwszTrigger)
#define IScheduledWorkItem_GetRunTimes(This,pstBegin,pstEnd,pCount,rgstTaskTimes) (This)->lpVtbl->GetRunTimes(This,pstBegin,pstEnd,pCount,rgstTaskTimes)
#define IScheduledWorkItem_GetNextRunTime(This,pstNextRun) (This)->lpVtbl->GetNextRunTime(This,pstNextRun)
#define IScheduledWorkItem_SetIdleWait(This,wIdleMinutes,wDeadlineMinutes) (This)->lpVtbl->SetIdleWait(This,wIdleMinutes,wDeadlineMinutes)
#define IScheduledWorkItem_GetIdleWait(This,pwIdleMinutes,pwDeadlineMinutes) (This)->lpVtbl->GetIdleWait(This,pwIdleMinutes,pwDeadlineMinutes)
#define IScheduledWorkItem_Run(This) (This)->lpVtbl->Run(This)
#define IScheduledWorkItem_Terminate(This) (This)->lpVtbl->Terminate(This)
#define IScheduledWorkItem_EditWorkItem(This,hParent,dwReserved) (This)->lpVtbl->EditWorkItem(This,hParent,dwReserved)
#define IScheduledWorkItem_GetMostRecentRunTime(This,pstLastRun) (This)->lpVtbl->GetMostRecentRunTime(This,pstLastRun)
#define IScheduledWorkItem_GetStatus(This,phrStatus) (This)->lpVtbl->GetStatus(This,phrStatus)
#define IScheduledWorkItem_GetExitCode(This,pdwExitCode) (This)->lpVtbl->GetExitCode(This,pdwExitCode)
#define IScheduledWorkItem_SetComment(This,pwszComment) (This)->lpVtbl->SetComment(This,pwszComment)
#define IScheduledWorkItem_GetComment(This,ppwszComment) (This)->lpVtbl->GetComment(This,ppwszComment)
#define IScheduledWorkItem_SetCreator(This,pwszCreator) (This)->lpVtbl->SetCreator(This,pwszCreator)
#define IScheduledWorkItem_GetCreator(This,ppwszCreator) (This)->lpVtbl->GetCreator(This,ppwszCreator)
#define IScheduledWorkItem_SetWorkItemData(This,cbData,rgbData) (This)->lpVtbl->SetWorkItemData(This,cbData,rgbData)
#define IScheduledWorkItem_GetWorkItemData(This,pcbData,prgbData) (This)->lpVtbl->GetWorkItemData(This,pcbData,prgbData)
#define IScheduledWorkItem_SetErrorRetryCount(This,wRetryCount) (This)->lpVtbl->SetErrorRetryCount(This,wRetryCount)
#define IScheduledWorkItem_GetErrorRetryCount(This,pwRetryCount) (This)->lpVtbl->GetErrorRetryCount(This,pwRetryCount)
#define IScheduledWorkItem_SetErrorRetryInterval(This,wRetryInterval) (This)->lpVtbl->SetErrorRetryInterval(This,wRetryInterval)
#define IScheduledWorkItem_GetErrorRetryInterval(This,pwRetryInterval) (This)->lpVtbl->GetErrorRetryInterval(This,pwRetryInterval)
#define IScheduledWorkItem_SetFlags(This,dwFlags) (This)->lpVtbl->SetFlags(This,dwFlags)
#define IScheduledWorkItem_GetFlags(This,pdwFlags) (This)->lpVtbl->GetFlags(This,pdwFlags)
#define IScheduledWorkItem_SetAccountInformation(This,pwszAccountName,pwszPassword) (This)->lpVtbl->SetAccountInformation(This,pwszAccountName,pwszPassword)
#define IScheduledWorkItem_GetAccountInformation(This,ppwszAccountName) (This)->lpVtbl->GetAccountInformation(This,ppwszAccountName)
#endif
#endif
  HRESULT WINAPI IScheduledWorkItem_CreateTrigger_Proxy(IScheduledWorkItem *This,WORD *piNewTrigger,ITaskTrigger **ppTrigger);
  void __RPC_STUB IScheduledWorkItem_CreateTrigger_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_DeleteTrigger_Proxy(IScheduledWorkItem *This,WORD iTrigger);
  void __RPC_STUB IScheduledWorkItem_DeleteTrigger_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetTriggerCount_Proxy(IScheduledWorkItem *This,WORD *pwCount);
  void __RPC_STUB IScheduledWorkItem_GetTriggerCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetTrigger_Proxy(IScheduledWorkItem *This,WORD iTrigger,ITaskTrigger **ppTrigger);
  void __RPC_STUB IScheduledWorkItem_GetTrigger_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetTriggerString_Proxy(IScheduledWorkItem *This,WORD iTrigger,LPWSTR *ppwszTrigger);
  void __RPC_STUB IScheduledWorkItem_GetTriggerString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetRunTimes_Proxy(IScheduledWorkItem *This,const LPSYSTEMTIME pstBegin,const LPSYSTEMTIME pstEnd,WORD *pCount,LPSYSTEMTIME *rgstTaskTimes);
  void __RPC_STUB IScheduledWorkItem_GetRunTimes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetNextRunTime_Proxy(IScheduledWorkItem *This,SYSTEMTIME *pstNextRun);
  void __RPC_STUB IScheduledWorkItem_GetNextRunTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_SetIdleWait_Proxy(IScheduledWorkItem *This,WORD wIdleMinutes,WORD wDeadlineMinutes);
  void __RPC_STUB IScheduledWorkItem_SetIdleWait_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetIdleWait_Proxy(IScheduledWorkItem *This,WORD *pwIdleMinutes,WORD *pwDeadlineMinutes);
  void __RPC_STUB IScheduledWorkItem_GetIdleWait_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_Run_Proxy(IScheduledWorkItem *This);
  void __RPC_STUB IScheduledWorkItem_Run_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_Terminate_Proxy(IScheduledWorkItem *This);
  void __RPC_STUB IScheduledWorkItem_Terminate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_EditWorkItem_Proxy(IScheduledWorkItem *This,HWND hParent,DWORD dwReserved);
  void __RPC_STUB IScheduledWorkItem_EditWorkItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetMostRecentRunTime_Proxy(IScheduledWorkItem *This,SYSTEMTIME *pstLastRun);
  void __RPC_STUB IScheduledWorkItem_GetMostRecentRunTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetStatus_Proxy(IScheduledWorkItem *This,HRESULT *phrStatus);
  void __RPC_STUB IScheduledWorkItem_GetStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetExitCode_Proxy(IScheduledWorkItem *This,DWORD *pdwExitCode);
  void __RPC_STUB IScheduledWorkItem_GetExitCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_SetComment_Proxy(IScheduledWorkItem *This,LPCWSTR pwszComment);
  void __RPC_STUB IScheduledWorkItem_SetComment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetComment_Proxy(IScheduledWorkItem *This,LPWSTR *ppwszComment);
  void __RPC_STUB IScheduledWorkItem_GetComment_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_SetCreator_Proxy(IScheduledWorkItem *This,LPCWSTR pwszCreator);
  void __RPC_STUB IScheduledWorkItem_SetCreator_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetCreator_Proxy(IScheduledWorkItem *This,LPWSTR *ppwszCreator);
  void __RPC_STUB IScheduledWorkItem_GetCreator_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_SetWorkItemData_Proxy(IScheduledWorkItem *This,WORD cbData,BYTE rgbData[]);
  void __RPC_STUB IScheduledWorkItem_SetWorkItemData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetWorkItemData_Proxy(IScheduledWorkItem *This,WORD *pcbData,BYTE **prgbData);
  void __RPC_STUB IScheduledWorkItem_GetWorkItemData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_SetErrorRetryCount_Proxy(IScheduledWorkItem *This,WORD wRetryCount);
  void __RPC_STUB IScheduledWorkItem_SetErrorRetryCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetErrorRetryCount_Proxy(IScheduledWorkItem *This,WORD *pwRetryCount);
  void __RPC_STUB IScheduledWorkItem_GetErrorRetryCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_SetErrorRetryInterval_Proxy(IScheduledWorkItem *This,WORD wRetryInterval);
  void __RPC_STUB IScheduledWorkItem_SetErrorRetryInterval_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetErrorRetryInterval_Proxy(IScheduledWorkItem *This,WORD *pwRetryInterval);
  void __RPC_STUB IScheduledWorkItem_GetErrorRetryInterval_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_SetFlags_Proxy(IScheduledWorkItem *This,DWORD dwFlags);
  void __RPC_STUB IScheduledWorkItem_SetFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetFlags_Proxy(IScheduledWorkItem *This,DWORD *pdwFlags);
  void __RPC_STUB IScheduledWorkItem_GetFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_SetAccountInformation_Proxy(IScheduledWorkItem *This,LPCWSTR pwszAccountName,LPCWSTR pwszPassword);
  void __RPC_STUB IScheduledWorkItem_SetAccountInformation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScheduledWorkItem_GetAccountInformation_Proxy(IScheduledWorkItem *This,LPWSTR *ppwszAccountName);
  void __RPC_STUB IScheduledWorkItem_GetAccountInformation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(IID_ITask,0x148BD524,0xA2AB,0x11CE,0xB1,0x1F,0x00,0xAA,0x00,0x53,0x05,0x03);

  extern RPC_IF_HANDLE __MIDL_itf_mstask_0141_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mstask_0141_v0_0_s_ifspec;

#ifndef __ITask_INTERFACE_DEFINED__
#define __ITask_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITask;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITask : public IScheduledWorkItem {
  public:
    virtual HRESULT WINAPI SetApplicationName(LPCWSTR pwszApplicationName) = 0;
    virtual HRESULT WINAPI GetApplicationName(LPWSTR *ppwszApplicationName) = 0;
    virtual HRESULT WINAPI SetParameters(LPCWSTR pwszParameters) = 0;
    virtual HRESULT WINAPI GetParameters(LPWSTR *ppwszParameters) = 0;
    virtual HRESULT WINAPI SetWorkingDirectory(LPCWSTR pwszWorkingDirectory) = 0;
    virtual HRESULT WINAPI GetWorkingDirectory(LPWSTR *ppwszWorkingDirectory) = 0;
    virtual HRESULT WINAPI SetPriority(DWORD dwPriority) = 0;
    virtual HRESULT WINAPI GetPriority(DWORD *pdwPriority) = 0;
    virtual HRESULT WINAPI SetTaskFlags(DWORD dwFlags) = 0;
    virtual HRESULT WINAPI GetTaskFlags(DWORD *pdwFlags) = 0;
    virtual HRESULT WINAPI SetMaxRunTime(DWORD dwMaxRunTimeMS) = 0;
    virtual HRESULT WINAPI GetMaxRunTime(DWORD *pdwMaxRunTimeMS) = 0;
  };
#else
  typedef struct ITaskVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITask *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITask *This);
      ULONG (WINAPI *Release)(ITask *This);
      HRESULT (WINAPI *CreateTrigger)(ITask *This,WORD *piNewTrigger,ITaskTrigger **ppTrigger);
      HRESULT (WINAPI *DeleteTrigger)(ITask *This,WORD iTrigger);
      HRESULT (WINAPI *GetTriggerCount)(ITask *This,WORD *pwCount);
      HRESULT (WINAPI *GetTrigger)(ITask *This,WORD iTrigger,ITaskTrigger **ppTrigger);
      HRESULT (WINAPI *GetTriggerString)(ITask *This,WORD iTrigger,LPWSTR *ppwszTrigger);
      HRESULT (WINAPI *GetRunTimes)(ITask *This,const LPSYSTEMTIME pstBegin,const LPSYSTEMTIME pstEnd,WORD *pCount,LPSYSTEMTIME *rgstTaskTimes);
      HRESULT (WINAPI *GetNextRunTime)(ITask *This,SYSTEMTIME *pstNextRun);
      HRESULT (WINAPI *SetIdleWait)(ITask *This,WORD wIdleMinutes,WORD wDeadlineMinutes);
      HRESULT (WINAPI *GetIdleWait)(ITask *This,WORD *pwIdleMinutes,WORD *pwDeadlineMinutes);
      HRESULT (WINAPI *Run)(ITask *This);
      HRESULT (WINAPI *Terminate)(ITask *This);
      HRESULT (WINAPI *EditWorkItem)(ITask *This,HWND hParent,DWORD dwReserved);
      HRESULT (WINAPI *GetMostRecentRunTime)(ITask *This,SYSTEMTIME *pstLastRun);
      HRESULT (WINAPI *GetStatus)(ITask *This,HRESULT *phrStatus);
      HRESULT (WINAPI *GetExitCode)(ITask *This,DWORD *pdwExitCode);
      HRESULT (WINAPI *SetComment)(ITask *This,LPCWSTR pwszComment);
      HRESULT (WINAPI *GetComment)(ITask *This,LPWSTR *ppwszComment);
      HRESULT (WINAPI *SetCreator)(ITask *This,LPCWSTR pwszCreator);
      HRESULT (WINAPI *GetCreator)(ITask *This,LPWSTR *ppwszCreator);
      HRESULT (WINAPI *SetWorkItemData)(ITask *This,WORD cbData,BYTE rgbData[]);
      HRESULT (WINAPI *GetWorkItemData)(ITask *This,WORD *pcbData,BYTE **prgbData);
      HRESULT (WINAPI *SetErrorRetryCount)(ITask *This,WORD wRetryCount);
      HRESULT (WINAPI *GetErrorRetryCount)(ITask *This,WORD *pwRetryCount);
      HRESULT (WINAPI *SetErrorRetryInterval)(ITask *This,WORD wRetryInterval);
      HRESULT (WINAPI *GetErrorRetryInterval)(ITask *This,WORD *pwRetryInterval);
      HRESULT (WINAPI *SetFlags)(ITask *This,DWORD dwFlags);
      HRESULT (WINAPI *GetFlags)(ITask *This,DWORD *pdwFlags);
      HRESULT (WINAPI *SetAccountInformation)(ITask *This,LPCWSTR pwszAccountName,LPCWSTR pwszPassword);
      HRESULT (WINAPI *GetAccountInformation)(ITask *This,LPWSTR *ppwszAccountName);
      HRESULT (WINAPI *SetApplicationName)(ITask *This,LPCWSTR pwszApplicationName);
      HRESULT (WINAPI *GetApplicationName)(ITask *This,LPWSTR *ppwszApplicationName);
      HRESULT (WINAPI *SetParameters)(ITask *This,LPCWSTR pwszParameters);
      HRESULT (WINAPI *GetParameters)(ITask *This,LPWSTR *ppwszParameters);
      HRESULT (WINAPI *SetWorkingDirectory)(ITask *This,LPCWSTR pwszWorkingDirectory);
      HRESULT (WINAPI *GetWorkingDirectory)(ITask *This,LPWSTR *ppwszWorkingDirectory);
      HRESULT (WINAPI *SetPriority)(ITask *This,DWORD dwPriority);
      HRESULT (WINAPI *GetPriority)(ITask *This,DWORD *pdwPriority);
      HRESULT (WINAPI *SetTaskFlags)(ITask *This,DWORD dwFlags);
      HRESULT (WINAPI *GetTaskFlags)(ITask *This,DWORD *pdwFlags);
      HRESULT (WINAPI *SetMaxRunTime)(ITask *This,DWORD dwMaxRunTimeMS);
      HRESULT (WINAPI *GetMaxRunTime)(ITask *This,DWORD *pdwMaxRunTimeMS);
    END_INTERFACE
  } ITaskVtbl;
  struct ITask {
    CONST_VTBL struct ITaskVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITask_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITask_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITask_Release(This) (This)->lpVtbl->Release(This)
#define ITask_CreateTrigger(This,piNewTrigger,ppTrigger) (This)->lpVtbl->CreateTrigger(This,piNewTrigger,ppTrigger)
#define ITask_DeleteTrigger(This,iTrigger) (This)->lpVtbl->DeleteTrigger(This,iTrigger)
#define ITask_GetTriggerCount(This,pwCount) (This)->lpVtbl->GetTriggerCount(This,pwCount)
#define ITask_GetTrigger(This,iTrigger,ppTrigger) (This)->lpVtbl->GetTrigger(This,iTrigger,ppTrigger)
#define ITask_GetTriggerString(This,iTrigger,ppwszTrigger) (This)->lpVtbl->GetTriggerString(This,iTrigger,ppwszTrigger)
#define ITask_GetRunTimes(This,pstBegin,pstEnd,pCount,rgstTaskTimes) (This)->lpVtbl->GetRunTimes(This,pstBegin,pstEnd,pCount,rgstTaskTimes)
#define ITask_GetNextRunTime(This,pstNextRun) (This)->lpVtbl->GetNextRunTime(This,pstNextRun)
#define ITask_SetIdleWait(This,wIdleMinutes,wDeadlineMinutes) (This)->lpVtbl->SetIdleWait(This,wIdleMinutes,wDeadlineMinutes)
#define ITask_GetIdleWait(This,pwIdleMinutes,pwDeadlineMinutes) (This)->lpVtbl->GetIdleWait(This,pwIdleMinutes,pwDeadlineMinutes)
#define ITask_Run(This) (This)->lpVtbl->Run(This)
#define ITask_Terminate(This) (This)->lpVtbl->Terminate(This)
#define ITask_EditWorkItem(This,hParent,dwReserved) (This)->lpVtbl->EditWorkItem(This,hParent,dwReserved)
#define ITask_GetMostRecentRunTime(This,pstLastRun) (This)->lpVtbl->GetMostRecentRunTime(This,pstLastRun)
#define ITask_GetStatus(This,phrStatus) (This)->lpVtbl->GetStatus(This,phrStatus)
#define ITask_GetExitCode(This,pdwExitCode) (This)->lpVtbl->GetExitCode(This,pdwExitCode)
#define ITask_SetComment(This,pwszComment) (This)->lpVtbl->SetComment(This,pwszComment)
#define ITask_GetComment(This,ppwszComment) (This)->lpVtbl->GetComment(This,ppwszComment)
#define ITask_SetCreator(This,pwszCreator) (This)->lpVtbl->SetCreator(This,pwszCreator)
#define ITask_GetCreator(This,ppwszCreator) (This)->lpVtbl->GetCreator(This,ppwszCreator)
#define ITask_SetWorkItemData(This,cbData,rgbData) (This)->lpVtbl->SetWorkItemData(This,cbData,rgbData)
#define ITask_GetWorkItemData(This,pcbData,prgbData) (This)->lpVtbl->GetWorkItemData(This,pcbData,prgbData)
#define ITask_SetErrorRetryCount(This,wRetryCount) (This)->lpVtbl->SetErrorRetryCount(This,wRetryCount)
#define ITask_GetErrorRetryCount(This,pwRetryCount) (This)->lpVtbl->GetErrorRetryCount(This,pwRetryCount)
#define ITask_SetErrorRetryInterval(This,wRetryInterval) (This)->lpVtbl->SetErrorRetryInterval(This,wRetryInterval)
#define ITask_GetErrorRetryInterval(This,pwRetryInterval) (This)->lpVtbl->GetErrorRetryInterval(This,pwRetryInterval)
#define ITask_SetFlags(This,dwFlags) (This)->lpVtbl->SetFlags(This,dwFlags)
#define ITask_GetFlags(This,pdwFlags) (This)->lpVtbl->GetFlags(This,pdwFlags)
#define ITask_SetAccountInformation(This,pwszAccountName,pwszPassword) (This)->lpVtbl->SetAccountInformation(This,pwszAccountName,pwszPassword)
#define ITask_GetAccountInformation(This,ppwszAccountName) (This)->lpVtbl->GetAccountInformation(This,ppwszAccountName)
#define ITask_SetApplicationName(This,pwszApplicationName) (This)->lpVtbl->SetApplicationName(This,pwszApplicationName)
#define ITask_GetApplicationName(This,ppwszApplicationName) (This)->lpVtbl->GetApplicationName(This,ppwszApplicationName)
#define ITask_SetParameters(This,pwszParameters) (This)->lpVtbl->SetParameters(This,pwszParameters)
#define ITask_GetParameters(This,ppwszParameters) (This)->lpVtbl->GetParameters(This,ppwszParameters)
#define ITask_SetWorkingDirectory(This,pwszWorkingDirectory) (This)->lpVtbl->SetWorkingDirectory(This,pwszWorkingDirectory)
#define ITask_GetWorkingDirectory(This,ppwszWorkingDirectory) (This)->lpVtbl->GetWorkingDirectory(This,ppwszWorkingDirectory)
#define ITask_SetPriority(This,dwPriority) (This)->lpVtbl->SetPriority(This,dwPriority)
#define ITask_GetPriority(This,pdwPriority) (This)->lpVtbl->GetPriority(This,pdwPriority)
#define ITask_SetTaskFlags(This,dwFlags) (This)->lpVtbl->SetTaskFlags(This,dwFlags)
#define ITask_GetTaskFlags(This,pdwFlags) (This)->lpVtbl->GetTaskFlags(This,pdwFlags)
#define ITask_SetMaxRunTime(This,dwMaxRunTimeMS) (This)->lpVtbl->SetMaxRunTime(This,dwMaxRunTimeMS)
#define ITask_GetMaxRunTime(This,pdwMaxRunTimeMS) (This)->lpVtbl->GetMaxRunTime(This,pdwMaxRunTimeMS)
#endif
#endif
  HRESULT WINAPI ITask_SetApplicationName_Proxy(ITask *This,LPCWSTR pwszApplicationName);
  void __RPC_STUB ITask_SetApplicationName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_GetApplicationName_Proxy(ITask *This,LPWSTR *ppwszApplicationName);
  void __RPC_STUB ITask_GetApplicationName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_SetParameters_Proxy(ITask *This,LPCWSTR pwszParameters);
  void __RPC_STUB ITask_SetParameters_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_GetParameters_Proxy(ITask *This,LPWSTR *ppwszParameters);
  void __RPC_STUB ITask_GetParameters_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_SetWorkingDirectory_Proxy(ITask *This,LPCWSTR pwszWorkingDirectory);
  void __RPC_STUB ITask_SetWorkingDirectory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_GetWorkingDirectory_Proxy(ITask *This,LPWSTR *ppwszWorkingDirectory);
  void __RPC_STUB ITask_GetWorkingDirectory_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_SetPriority_Proxy(ITask *This,DWORD dwPriority);
  void __RPC_STUB ITask_SetPriority_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_GetPriority_Proxy(ITask *This,DWORD *pdwPriority);
  void __RPC_STUB ITask_GetPriority_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_SetTaskFlags_Proxy(ITask *This,DWORD dwFlags);
  void __RPC_STUB ITask_SetTaskFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_GetTaskFlags_Proxy(ITask *This,DWORD *pdwFlags);
  void __RPC_STUB ITask_GetTaskFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_SetMaxRunTime_Proxy(ITask *This,DWORD dwMaxRunTimeMS);
  void __RPC_STUB ITask_SetMaxRunTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITask_GetMaxRunTime_Proxy(ITask *This,DWORD *pdwMaxRunTimeMS);
  void __RPC_STUB ITask_GetMaxRunTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(IID_IEnumWorkItems,0x148BD528,0xA2AB,0x11CE,0xB1,0x1F,0x00,0xAA,0x00,0x53,0x05,0x03);

  extern RPC_IF_HANDLE __MIDL_itf_mstask_0142_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mstask_0142_v0_0_s_ifspec;

#ifndef __IEnumWorkItems_INTERFACE_DEFINED__
#define __IEnumWorkItems_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumWorkItems;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumWorkItems : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,LPWSTR **rgpwszNames,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumWorkItems **ppEnumWorkItems) = 0;
  };
#else
  typedef struct IEnumWorkItemsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumWorkItems *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumWorkItems *This);
      ULONG (WINAPI *Release)(IEnumWorkItems *This);
      HRESULT (WINAPI *Next)(IEnumWorkItems *This,ULONG celt,LPWSTR **rgpwszNames,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumWorkItems *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumWorkItems *This);
      HRESULT (WINAPI *Clone)(IEnumWorkItems *This,IEnumWorkItems **ppEnumWorkItems);
    END_INTERFACE
  } IEnumWorkItemsVtbl;
  struct IEnumWorkItems {
    CONST_VTBL struct IEnumWorkItemsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumWorkItems_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumWorkItems_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumWorkItems_Release(This) (This)->lpVtbl->Release(This)
#define IEnumWorkItems_Next(This,celt,rgpwszNames,pceltFetched) (This)->lpVtbl->Next(This,celt,rgpwszNames,pceltFetched)
#define IEnumWorkItems_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumWorkItems_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumWorkItems_Clone(This,ppEnumWorkItems) (This)->lpVtbl->Clone(This,ppEnumWorkItems)
#endif
#endif
  HRESULT WINAPI IEnumWorkItems_Next_Proxy(IEnumWorkItems *This,ULONG celt,LPWSTR **rgpwszNames,ULONG *pceltFetched);
  void __RPC_STUB IEnumWorkItems_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWorkItems_Skip_Proxy(IEnumWorkItems *This,ULONG celt);
  void __RPC_STUB IEnumWorkItems_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWorkItems_Reset_Proxy(IEnumWorkItems *This);
  void __RPC_STUB IEnumWorkItems_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumWorkItems_Clone_Proxy(IEnumWorkItems *This,IEnumWorkItems **ppEnumWorkItems);
  void __RPC_STUB IEnumWorkItems_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(IID_ITaskScheduler,0x148BD527,0xA2AB,0x11CE,0xB1,0x1F,0x00,0xAA,0x00,0x53,0x05,0x03);

  extern RPC_IF_HANDLE __MIDL_itf_mstask_0143_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mstask_0143_v0_0_s_ifspec;

#ifndef __ITaskScheduler_INTERFACE_DEFINED__
#define __ITaskScheduler_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITaskScheduler;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITaskScheduler : public IUnknown {
  public:
    virtual HRESULT WINAPI SetTargetComputer(LPCWSTR pwszComputer) = 0;
    virtual HRESULT WINAPI GetTargetComputer(LPWSTR *ppwszComputer) = 0;
    virtual HRESULT WINAPI Enum(IEnumWorkItems **ppEnumWorkItems) = 0;
    virtual HRESULT WINAPI Activate(LPCWSTR pwszName,REFIID riid,IUnknown **ppUnk) = 0;
    virtual HRESULT WINAPI Delete(LPCWSTR pwszName) = 0;
    virtual HRESULT WINAPI NewWorkItem(LPCWSTR pwszTaskName,REFCLSID rclsid,REFIID riid,IUnknown **ppUnk) = 0;
    virtual HRESULT WINAPI AddWorkItem(LPCWSTR pwszTaskName,IScheduledWorkItem *pWorkItem) = 0;
    virtual HRESULT WINAPI IsOfType(LPCWSTR pwszName,REFIID riid) = 0;
  };
#else
  typedef struct ITaskSchedulerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITaskScheduler *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITaskScheduler *This);
      ULONG (WINAPI *Release)(ITaskScheduler *This);
      HRESULT (WINAPI *SetTargetComputer)(ITaskScheduler *This,LPCWSTR pwszComputer);
      HRESULT (WINAPI *GetTargetComputer)(ITaskScheduler *This,LPWSTR *ppwszComputer);
      HRESULT (WINAPI *Enum)(ITaskScheduler *This,IEnumWorkItems **ppEnumWorkItems);
      HRESULT (WINAPI *Activate)(ITaskScheduler *This,LPCWSTR pwszName,REFIID riid,IUnknown **ppUnk);
      HRESULT (WINAPI *Delete)(ITaskScheduler *This,LPCWSTR pwszName);
      HRESULT (WINAPI *NewWorkItem)(ITaskScheduler *This,LPCWSTR pwszTaskName,REFCLSID rclsid,REFIID riid,IUnknown **ppUnk);
      HRESULT (WINAPI *AddWorkItem)(ITaskScheduler *This,LPCWSTR pwszTaskName,IScheduledWorkItem *pWorkItem);
      HRESULT (WINAPI *IsOfType)(ITaskScheduler *This,LPCWSTR pwszName,REFIID riid);
    END_INTERFACE
  } ITaskSchedulerVtbl;
  struct ITaskScheduler {
    CONST_VTBL struct ITaskSchedulerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITaskScheduler_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITaskScheduler_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITaskScheduler_Release(This) (This)->lpVtbl->Release(This)
#define ITaskScheduler_SetTargetComputer(This,pwszComputer) (This)->lpVtbl->SetTargetComputer(This,pwszComputer)
#define ITaskScheduler_GetTargetComputer(This,ppwszComputer) (This)->lpVtbl->GetTargetComputer(This,ppwszComputer)
#define ITaskScheduler_Enum(This,ppEnumWorkItems) (This)->lpVtbl->Enum(This,ppEnumWorkItems)
#define ITaskScheduler_Activate(This,pwszName,riid,ppUnk) (This)->lpVtbl->Activate(This,pwszName,riid,ppUnk)
#define ITaskScheduler_Delete(This,pwszName) (This)->lpVtbl->Delete(This,pwszName)
#define ITaskScheduler_NewWorkItem(This,pwszTaskName,rclsid,riid,ppUnk) (This)->lpVtbl->NewWorkItem(This,pwszTaskName,rclsid,riid,ppUnk)
#define ITaskScheduler_AddWorkItem(This,pwszTaskName,pWorkItem) (This)->lpVtbl->AddWorkItem(This,pwszTaskName,pWorkItem)
#define ITaskScheduler_IsOfType(This,pwszName,riid) (This)->lpVtbl->IsOfType(This,pwszName,riid)
#endif
#endif
  HRESULT WINAPI ITaskScheduler_SetTargetComputer_Proxy(ITaskScheduler *This,LPCWSTR pwszComputer);
  void __RPC_STUB ITaskScheduler_SetTargetComputer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITaskScheduler_GetTargetComputer_Proxy(ITaskScheduler *This,LPWSTR *ppwszComputer);
  void __RPC_STUB ITaskScheduler_GetTargetComputer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITaskScheduler_Enum_Proxy(ITaskScheduler *This,IEnumWorkItems **ppEnumWorkItems);
  void __RPC_STUB ITaskScheduler_Enum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITaskScheduler_Activate_Proxy(ITaskScheduler *This,LPCWSTR pwszName,REFIID riid,IUnknown **ppUnk);
  void __RPC_STUB ITaskScheduler_Activate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITaskScheduler_Delete_Proxy(ITaskScheduler *This,LPCWSTR pwszName);
  void __RPC_STUB ITaskScheduler_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITaskScheduler_NewWorkItem_Proxy(ITaskScheduler *This,LPCWSTR pwszTaskName,REFCLSID rclsid,REFIID riid,IUnknown **ppUnk);
  void __RPC_STUB ITaskScheduler_NewWorkItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITaskScheduler_AddWorkItem_Proxy(ITaskScheduler *This,LPCWSTR pwszTaskName,IScheduledWorkItem *pWorkItem);
  void __RPC_STUB ITaskScheduler_AddWorkItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITaskScheduler_IsOfType_Proxy(ITaskScheduler *This,LPCWSTR pwszName,REFIID riid);
  void __RPC_STUB ITaskScheduler_IsOfType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_CTask;
  EXTERN_C const CLSID CLSID_CTaskScheduler;

  DEFINE_GUID(CLSID_CTask,0x148BD520,0xA2AB,0x11CE,0xB1,0x1F,0x00,0xAA,0x00,0x53,0x05,0x03);
  DEFINE_GUID(CLSID_CTaskScheduler,0x148BD52A,0xA2AB,0x11CE,0xB1,0x1F,0x00,0xAA,0x00,0x53,0x05,0x03);

  typedef struct _PSP *HPROPSHEETPAGE;

  typedef enum _TASKPAGE {
    TASKPAGE_TASK = 0,TASKPAGE_SCHEDULE = 1,TASKPAGE_SETTINGS = 2
  } TASKPAGE;

  DEFINE_GUID(IID_IProvideTaskPage,0x4086658a,0xcbbb,0x11cf,0xb6,0x04,0x00,0xc0,0x4f,0xd8,0xd5,0x65);

  extern RPC_IF_HANDLE __MIDL_itf_mstask_0144_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mstask_0144_v0_0_s_ifspec;

#ifndef __IProvideTaskPage_INTERFACE_DEFINED__
#define __IProvideTaskPage_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IProvideTaskPage;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IProvideTaskPage : public IUnknown {
  public:
    virtual HRESULT WINAPI GetPage(TASKPAGE tpType,WINBOOL fPersistChanges,HPROPSHEETPAGE *phPage) = 0;
  };
#else
  typedef struct IProvideTaskPageVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IProvideTaskPage *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IProvideTaskPage *This);
      ULONG (WINAPI *Release)(IProvideTaskPage *This);
      HRESULT (WINAPI *GetPage)(IProvideTaskPage *This,TASKPAGE tpType,WINBOOL fPersistChanges,HPROPSHEETPAGE *phPage);
    END_INTERFACE
  } IProvideTaskPageVtbl;
  struct IProvideTaskPage {
    CONST_VTBL struct IProvideTaskPageVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IProvideTaskPage_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IProvideTaskPage_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IProvideTaskPage_Release(This) (This)->lpVtbl->Release(This)
#define IProvideTaskPage_GetPage(This,tpType,fPersistChanges,phPage) (This)->lpVtbl->GetPage(This,tpType,fPersistChanges,phPage)
#endif
#endif
  HRESULT WINAPI IProvideTaskPage_GetPage_Proxy(IProvideTaskPage *This,TASKPAGE tpType,WINBOOL fPersistChanges,HPROPSHEETPAGE *phPage);
  void __RPC_STUB IProvideTaskPage_GetPage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define ISchedulingAgent ITaskScheduler
#define IEnumTasks IEnumWorkItems
#define IID_ISchedulingAgent IID_ITaskScheduler
#define CLSID_CSchedulingAgent CLSID_CTaskScheduler

  extern RPC_IF_HANDLE __MIDL_itf_mstask_0145_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mstask_0145_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
