#ifndef _DMUSICKS_
#define _DMUSICKS_

#define DONT_HOLD_FOR_SEQUENCING 0x8000000000000000

#ifndef REFERENCE_TIME
typedef LONGLONG REFERENCE_TIME;
#endif

typedef struct _DMUS_KERNEL_EVENT {
  BYTE bReserved;
  BYTE cbStruct;
  USHORT cbEvent;
  USHORT usChannelGroup;
  USHORT usFlags;
  REFERENCE_TIME ullPresTime100ns;
  ULONGLONG ullBytePosition;
  struct _DMUS_KERNEL_EVENT *pNextEvt;
  union {
    BYTE abData[sizeof(PBYTE)];
    PBYTE pbData;
    struct _DMUS_KERNEL_EVENT *pPackageEvt;
  } uData;
} DMUS_KERNEL_EVENT, *PDMUS_KERNEL_EVENT;

typedef enum {
  DMUS_STREAM_MIDI_INVALID = -1,
  DMUS_STREAM_MIDI_RENDER = 0,
  DMUS_STREAM_MIDI_CAPTURE,
  DMUS_STREAM_WAVE_SINK
} DMUS_STREAM_TYPE;

DEFINE_GUID(CLSID_MiniportDriverDMusUART,        0xd3f0ce1c, 0xFFFC, 0x11D1, 0x81, 0xB0, 0x00, 0x60, 0x08, 0x33, 0x16, 0xC1);
DEFINE_GUID(CLSID_MiniportDriverDMusUARTCapture, 0xD3F0CE1D, 0xFFFC, 0x11D1, 0x81, 0xB0, 0x00, 0x60, 0x08, 0x33, 0x16, 0xC1);

/* ===============================================================
    IMasterClock Interface
*/

#undef INTERFACE
#define INTERFACE IMasterClock

DECLARE_INTERFACE_(IMasterClock,IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(NTSTATUS,GetTime)( THIS_
        OUT     REFERENCE_TIME  * pTime
    ) PURE;
};

typedef IMasterClock *PMASTERCLOCK;

#define IMP_IMasterClock                    \
    STDMETHODIMP_(NTSTATUS) GetTime(        \
        OUT     REFERENCE_TIME  * pTime     \
    )

/* ===============================================================
    IMXF Interface
*/

#undef INTERFACE
#define INTERFACE IMXF

struct IMXF;
typedef struct IMXF *PMXF;

#define DEFINE_ABSTRACT_IMXF()                 \
    STDMETHOD_(NTSTATUS,SetState)(THIS_        \
        IN      KSSTATE State                  \
    ) PURE;                                    \
    STDMETHOD_(NTSTATUS,PutMessage)            \
    (   THIS_                                  \
        IN      PDMUS_KERNEL_EVENT  pDMKEvt    \
    ) PURE;                                    \
    STDMETHOD_(NTSTATUS,ConnectOutput)         \
    (   THIS_                                  \
        IN      PMXF    sinkMXF                \
    ) PURE;                                    \
    STDMETHOD_(NTSTATUS,DisconnectOutput)      \
    (   THIS_                                  \
        IN      PMXF    sinkMXF                \
    ) PURE;

#define IMP_IMXF                                \
    STDMETHODIMP_(NTSTATUS) SetState            \
    (                                           \
        IN      KSSTATE State                   \
    );                                          \
    STDMETHODIMP_(NTSTATUS) PutMessage          \
    (   THIS_                                   \
        IN      PDMUS_KERNEL_EVENT  pDMKEvt     \
    );                                          \
    STDMETHODIMP_(NTSTATUS) ConnectOutput       \
    (   THIS_                                   \
        IN      PMXF    sinkMXF                 \
    );                                          \
    STDMETHODIMP_(NTSTATUS) DisconnectOutput    \
    (   THIS_                                   \
        IN      PMXF    sinkMXF                 \
    )


DECLARE_INTERFACE_(IMXF,IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    DEFINE_ABSTRACT_IMXF()
};

/* ===============================================================
    IAllocatorMXF Interface
*/

#undef INTERFACE
#define INTERFACE IAllocatorMXF

struct  IAllocatorMXF;
typedef struct IAllocatorMXF *PAllocatorMXF;

#define STATIC_IID_IAllocatorMXF\
    0xa5f0d62c, 0xb30f, 0x11d2, 0xb7, 0xa3, 0x00, 0x60, 0x08, 0x33, 0x16, 0xc1
DEFINE_GUIDSTRUCT("a5f0d62c-b30f-11d2-b7a3-0060083316c1", IID_IAllocatorMXF);
#define IID_IAllocatorMXF DEFINE_GUIDNAMED(IID_IAllocatorMXF)


DECLARE_INTERFACE_(IAllocatorMXF, IMXF)
{
    DEFINE_ABSTRACT_UNKNOWN()

    DEFINE_ABSTRACT_IMXF()

    STDMETHOD_(NTSTATUS,GetMessage)(THIS_
        OUT     PDMUS_KERNEL_EVENT * ppDMKEvt
    ) PURE;

    STDMETHOD_(USHORT,GetBufferSize)(THIS) PURE;

    STDMETHOD_(NTSTATUS,GetBuffer)(THIS_
        OUT     PBYTE * ppBuffer
    )PURE;

    STDMETHOD_(NTSTATUS,PutBuffer)(THIS_
        IN      PBYTE   pBuffer
    )   PURE;
};

#define IMP_IAllocatorMXF                               \
    IMP_IMXF;                                           \
    STDMETHODIMP_(NTSTATUS) GetMessage(                 \
        OUT     PDMUS_KERNEL_EVENT * ppDMKEvt           \
    );                                                  \
                                                        \
    STDMETHODIMP_(USHORT) GetBufferSize(void);          \
                                                        \
    STDMETHODIMP_(NTSTATUS) GetBuffer(                  \
        OUT     PBYTE * ppBuffer                        \
    );                                                  \
                                                        \
    STDMETHODIMP_(NTSTATUS) PutBuffer(                  \
        IN      PBYTE   pBuffer                         \
    )

#undef INTERFACE
#define INTERFACE IPortDMus

DEFINE_GUID(IID_IPortDMus, 0xc096df9c, 0xfb09, 0x11d1, 0x81, 0xb0, 0x00, 0x60, 0x08, 0x33, 0x16, 0xc1);
DEFINE_GUID(CLSID_PortDMus, 0xb7902fe9, 0xfb0a, 0x11d1, 0x81, 0xb0, 0x00, 0x60, 0x08, 0x33, 0x16, 0xc1);

DECLARE_INTERFACE_(IPortDMus, IPort)
{
    DEFINE_ABSTRACT_UNKNOWN()

    DEFINE_ABSTRACT_PORT()

    STDMETHOD_(void,Notify)(THIS_
        IN PSERVICEGROUP ServiceGroup OPTIONAL
    )PURE;

    STDMETHOD_(void,RegisterServiceGroup)(THIS_
        IN PSERVICEGROUP ServiceGroup
    ) PURE;
};
typedef IPortDMus *PPORTDMUS;

#define IMP_IPortDMus                                 \
    IMP_IPort;                                        \
    STDMETHODIMP_(void) Notify(                       \
        IN PSERVICEGROUP ServiceGroup OPTIONAL        \
    );                                                \
                                                      \
    STDMETHODIMP_(void) RegisterServiceGroup(         \
        IN PSERVICEGROUP ServiceGroup                 \
    )

#undef INTERFACE
#define INTERFACE IMiniportDMus

DEFINE_GUID(IID_IMiniportDMus, 0xc096df9d, 0xfb09, 0x11d1, 0x81, 0xb0, 0x00, 0x60, 0x08, 0x33, 0x16, 0xc1);
DECLARE_INTERFACE_(IMiniportDMus, IMiniport)
{
    DEFINE_ABSTRACT_UNKNOWN()

    DEFINE_ABSTRACT_MINIPORT()

    STDMETHOD_(NTSTATUS,Init)(THIS_
        IN      PUNKNOWN        UnknownAdapter,
        IN      PRESOURCELIST   ResourceList,
        IN      PPORTDMUS       Port,
        OUT     PSERVICEGROUP * ServiceGroup
    )   PURE;

    STDMETHOD_(void,Service)(THIS) PURE;

    STDMETHOD_(NTSTATUS,NewStream)(THIS_
        OUT     PMXF                  * MXF,
        IN      PUNKNOWN                OuterUnknown    OPTIONAL,
        IN      POOL_TYPE               PoolType,
        IN      ULONG                   PinID,
        IN      DMUS_STREAM_TYPE        StreamType,
        IN      PKSDATAFORMAT           DataFormat,
        OUT     PSERVICEGROUP         * ServiceGroup,
        IN      PAllocatorMXF           AllocatorMXF,
        IN      PMASTERCLOCK            MasterClock,
        OUT     PULONGLONG              SchedulePreFetch
    ) PURE;
};

typedef IMiniportDMus *PMINIPORTDMUS;
#undef INTERFACE

#define IMP_IMiniportDMus                              \
    IMP_IMiniport;                                     \
    STDMETHODIMP_(NTSTATUS) Init(                      \
        IN      PUNKNOWN        UnknownAdapter,        \
        IN      PRESOURCELIST   ResourceList,          \
        IN      PPORTDMUS       Port,                  \
        OUT     PSERVICEGROUP * ServiceGroup           \
    );                                                 \
                                                       \
    STDMETHODIMP_(void) Service(THIS);                 \
                                                       \
    STDMETHODIMP_(NTSTATUS) NewStream(                 \
        OUT     PMXF              * MXF,               \
        IN      PUNKNOWN          OuterUnknown,        \
        IN      POOL_TYPE         PoolType,            \
        IN      ULONG             PinID,               \
        IN      DMUS_STREAM_TYPE  StreamType,          \
        IN      PKSDATAFORMAT     DataFormat,          \
        OUT     PSERVICEGROUP     * ServiceGroup,      \
        IN      PAllocatorMXF     AllocatorMXF,        \
        IN      PMASTERCLOCK      MasterClock,         \
        OUT     PULONGLONG        SchedulePreFetch     \
    )

#endif /* _DMUSICKS_ */

