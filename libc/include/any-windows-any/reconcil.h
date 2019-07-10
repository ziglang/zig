/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __RECONCIL_H__
#define __RECONCIL_H__

#include <recguids.h>

#ifdef __cplusplus
extern "C" {
#endif

#define STATEBITS_FLAT (0x0001)

#define REC_S_IDIDTHEUPDATES MAKE_SCODE(SEVERITY_SUCCESS,FACILITY_ITF,0x1000)
#define REC_S_NOTCOMPLETE MAKE_SCODE(SEVERITY_SUCCESS,FACILITY_ITF,0x1001)
#define REC_S_NOTCOMPLETEBUTPROPAGATE MAKE_SCODE(SEVERITY_SUCCESS,FACILITY_ITF,0x1002)

#define REC_E_ABORTED MAKE_SCODE(SEVERITY_ERROR,FACILITY_ITF,0x1000)
#define REC_E_NOCALLBACK MAKE_SCODE(SEVERITY_ERROR,FACILITY_ITF,0x1001)
#define REC_E_NORESIDUES MAKE_SCODE(SEVERITY_ERROR,FACILITY_ITF,0x1002)
#define REC_E_TOODIFFERENT MAKE_SCODE(SEVERITY_ERROR,FACILITY_ITF,0x1003)
#define REC_E_INEEDTODOTHEUPDATES MAKE_SCODE(SEVERITY_ERROR,FACILITY_ITF,0x1004)

#undef INTERFACE
#define INTERFACE INotifyReplica

  DECLARE_INTERFACE_(INotifyReplica,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID riid,PVOID *ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(YouAreAReplica)(THIS_ ULONG ulcOtherReplicas,IMoniker **rgpmkOtherReplicas) PURE;
  };

#undef INTERFACE
#define INTERFACE IReconcileInitiator
  DECLARE_INTERFACE_(IReconcileInitiator,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID riid,PVOID *ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(SetAbortCallback)(THIS_ IUnknown *punkForAbort) PURE;
    STDMETHOD(SetProgressFeedback)(THIS_ ULONG ulProgress,ULONG ulProgressMax) PURE;
  };

  typedef enum _reconcilef {
    RECONCILEF_MAYBOTHERUSER = 0x0001,RECONCILEF_FEEDBACKWINDOWVALID = 0x0002,RECONCILEF_NORESIDUESOK = 0x0004,RECONCILEF_OMITSELFRESIDUE = 0x0008,
    RECONCILEF_RESUMERECONCILIATION = 0x0010,RECONCILEF_YOUMAYDOTHEUPDATES = 0x0020,RECONCILEF_ONLYYOUWERECHANGED = 0x0040,
    ALL_RECONCILE_FLAGS = (RECONCILEF_MAYBOTHERUSER | RECONCILEF_FEEDBACKWINDOWVALID | RECONCILEF_NORESIDUESOK | RECONCILEF_OMITSELFRESIDUE | RECONCILEF_RESUMERECONCILIATION | RECONCILEF_YOUMAYDOTHEUPDATES | RECONCILEF_ONLYYOUWERECHANGED)
  } RECONCILEF;

#undef INTERFACE
#define INTERFACE IReconcilableObject
  DECLARE_INTERFACE_(IReconcilableObject,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID riid,PVOID *ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(Reconcile)(THIS_ IReconcileInitiator *pInitiator,DWORD dwFlags,HWND hwndOwner,HWND hwndProgressFeedback,ULONG ulcInput,IMoniker **rgpmkOtherInput,PLONG plOutIndex,IStorage *pstgNewResidues,PVOID pvReserved) PURE;
    STDMETHOD(GetProgressFeedbackMaxEstimate)(THIS_ PULONG pulProgressMax) PURE;
  };

#undef INTERFACE
#define INTERFACE IBriefcaseInitiator
  DECLARE_INTERFACE_(IBriefcaseInitiator,IUnknown) {
    STDMETHOD(QueryInterface)(THIS_ REFIID riid,PVOID *ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD(IsMonikerInBriefcase)(THIS_ IMoniker *pmk) PURE;
  };

#ifdef __cplusplus
}
#endif
#endif
