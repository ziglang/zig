/*
    ReactOS Kernel Streaming
    Port Class

    This file is in the public domain.

    Andrew Greenwood

    NOTES:
    Does not support PC_OLD_NAMES (which is required for backwards-compatibility
    with older code)

    Obsolete macros are not implemented. For more info:
    http://www.osronline.com/ddkx/stream/audpc-struct_167n.htm


    == EXPORTS ==
    DRM (new in XP):
    * PcAddContentHandlers
    * PcCreateContentMixed
    * PcDestroyContent
    * PcForwardContentToDeviceObject
    * PcForwardContentToFileObject
    * PcForwardContentToInterface
    * PcGetContentRights

    IRP HANDLING:
    * PcCompleteIrp
    * PcDispatchIrp
    * PcForwardIrpSynchronous

    ADAPTER:
    * PcAddAdapterDevice
    * PcInitializeAdapterDriver

    FACTORIES:
    * PcNewDmaChannel
    * PcNewInterruptSync
    * PcNewMiniport
    * PcNewPort
    * PcNewRegistryKey
    * PcNewResourceList
    * PcNewResourceSublist
    * PcNewServiceGroup

    POWER MANAGEMENT:
    * PcRegisterAdapterPowerManagement
    * PcRequestNewPowerState

    PROPERTIES:
    * PcCompletePendingPropertyRequest
    * PcGetDeviceProperty

    IO TIMEOUTS:
    * PcRegisterIoTimeout
    * PcUnregisterIoTimeout

    PHYSICAL CONNECTIONS:
    * PcRegisterPhysicalConnection
    * PcRegisterPhysicalConnectionFromExternal
    * PcRegisterPhysicalConnectionToExternal

    MISC:
    * PcGetTimeInterval
    * PcRegisterSubdevice


    == AUDIO HELPER OBJECT INTERFACES ==
    IDmaChannel
    IDmaChannelSlave
    IDmaOperations
    IDrmPort                        (XP)
    IDrmPort2                       (XP)
    IInterruptSync
    IMasterClock
    IPortClsVersion                 (XP)
    IPortEvents
    IPreFetchOffset                 (XP)
    IRegistryKey
    IResourceList
    IServiceGroup
    IServiceSink
    IUnregisterPhysicalConnection   (Vista)
    IUnregisterSubdevice            (Vista)

    == AUDIO PORT OBJECT INTERFACES ==
    IPort
    IPortDMus
    IPortMidi
    IPortTopology
    IPortWaveCyclic
    IPortWavePci

    == AUDIO MINIPORT OBJECT INTERFACES ==
    IMiniport
    IMiniportDMus
    IMiniportMidi
    IMiniportTopology
    IMiniportWaveCyclic
    IMiniportWavePci

    == AUDIO MINIPORT AUXILIARY INTERFACES ==
    IMusicTechnology                (XP)
    IPinCount                       (XP)

    == AUDIO STREAM OBJECT INTERFACES ==
    IAllocatorMXF
    IDrmAudioStream                 (XP)
    IMiniportMidiStream
    IMiniportWaveCyclicStream
    IMiniportWavePciStream
    IMXF
    IPortWavePciStream
    ISynthSinkDMus

    == DIRECTMUSIC USERMODE SYNTH AND SYNTH SINK INTERFACES ==
    IDirectMusicSynth
    IDirectMusicSynthSink

    == AUDIO POWER MANAGEMENT INTERFACES ==
    IAdapterPowerManagement
    IPowerNotify
*/

#ifndef PORTCLS_H
#define PORTCLS_H

#ifdef __cplusplus
extern "C"
{
# include <wdm.h>
}
#else
# include <wdm.h>
#endif

#include <windef.h>

#define NOBITMAP
#include <mmreg.h>
#undef NOBITMAP

#include <punknown.h>
#include <ks.h>
#include <ksmedia.h>
#include <drmk.h>

#ifdef __cplusplus
extern "C"
{
# include <wdm.h>
}
#else
# include <wdm.h>
#endif

#ifndef PC_NO_IMPORTS
#define PORTCLASSAPI EXTERN_C __declspec(dllimport)
#else
#define PORTCLASSAPI EXTERN_C
#endif

/* TODO */
#define PCFILTER_NODE ((ULONG) -1)

/* HACK */
/* typedef PVOID CM_RESOURCE_TYPE; */

#define _100NS_UNITS_PER_SECOND 10000000L
#define PORT_CLASS_DEVICE_EXTENSION_SIZE ( 64 * sizeof(ULONG_PTR) )


DEFINE_GUID(CLSID_MiniportDriverFmSynth, 0xb4c90ae0L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);
DEFINE_GUID(CLSID_MiniportDriverFmSynthWithVol, 0xe5a3c139L, 0xf0f2, 0x11d1, 0x81, 0xaf, 0x00, 0x60, 0x08, 0x33, 0x16, 0xc1);

/* ===============================================================
    Event Item Flags - TODO
*/
#define PCEVENT_ITEM_FLAG_ENABLE            KSEVENT_TYPE_ENABLE
#define PCEVENT_ITEM_FLAG_ONESHOT           KSEVENT_TYPE_ONESHOT
#define PCEVENT_ITEM_FLAG_BASICSUPPORT      KSEVENT_TYPE_BASICSUPPORT


/* ===============================================================
    Event Verbs - TODO
*/
#define PCEVENT_VERB_NONE       0
#define PCEVENT_VERB_ADD        1
#define PCEVENT_VERB_REMOVE     2
#define PCEVENT_VERB_SUPPORT    4


/* ===============================================================
    Method Item Flags - TODO
*/
#define PCMETHOD_ITEM_FLAG_NONE             KSMETHOD_TYPE_NONE
#define PCMETHOD_ITEM_FLAG_READ             KSMETHOD_TYPE_READ
#define PCMETHOD_ITEM_FLAG_WRITE            KSMETHOD_TYPE_WRITE
#define PCMETHOD_ITEM_FLAG_MODIFY           KSMETHOD_TYPE_MODIFY
#define PCMETHOD_ITEM_FLAG_SOURCE           KSMETHOD_TYPE_SOURCE


/* ===============================================================
    Method Verbs - TODO
*/
#define PCMETHOD_ITEM_FLAG_BASICSUPPORT     KSMETHOD_TYPE_BASICSUPPORT
#define PCMETHOD_ITEM_FLAG_SEND
#define PCMETHOD_ITEM_FLAG_SETSUPPORT


/* ===============================================================
    Versions
    IoIsWdmVersionAvailable may also be used by older drivers.
*/

enum
{
    kVersionInvalid = -1,

    kVersionWin98,
    kVersionWin98SE,
    kVersionWin2K,
    kVersionWin98SE_QFE2,
    kVersionWin2K_SP2,
    kVersionWinME,
    kVersionWin98SE_QFE3,
    kVersionWinME_QFE1,
    kVersionWinXP,
    kVersionWinXPSP1,
    kVersionWinServer2003,
    kVersionWin2K_UAAQFE,           /* These support IUnregister* interface */
    kVersionWinXP_UAAQFE,
    kVersionWinServer2003_UAAQFE
};

/* ===============================================================
    Properties
*/

struct _PCPROPERTY_REQUEST;

typedef struct _PCPROPERTY_REQUEST PCPROPERTY_REQUEST, *PPCPROPERTY_REQUEST;

typedef NTSTATUS (NTAPI *PCPFNPROPERTY_HANDLER)(
    IN  PPCPROPERTY_REQUEST PropertyRequest);

typedef struct
{
    const GUID *            Set;
    ULONG                   Id;
    ULONG                   Flags;
#define PCPROPERTY_ITEM_FLAG_GET            KSPROPERTY_TYPE_GET
#define PCPROPERTY_ITEM_FLAG_SET            KSPROPERTY_TYPE_SET
#define PCPROPERTY_ITEM_FLAG_BASICSUPPORT   KSPROPERTY_TYPE_BASICSUPPORT
//not supported #define PCPROPERTY_ITEM_FLAG_RELATIONS      KSPROPERTY_TYPE_RELATIONS
#define PCPROPERTY_ITEM_FLAG_SERIALIZERAW   KSPROPERTY_TYPE_SERIALIZERAW
#define PCPROPERTY_ITEM_FLAG_UNSERIALIZERAW KSPROPERTY_TYPE_UNSERIALIZERAW
#define PCPROPERTY_ITEM_FLAG_SERIALIZESIZE  KSPROPERTY_TYPE_SERIALIZESIZE
#define PCPROPERTY_ITEM_FLAG_SERIALIZE\
        (PCPROPERTY_ITEM_FLAG_SERIALIZERAW\
        |PCPROPERTY_ITEM_FLAG_UNSERIALIZERAW\
        |PCPROPERTY_ITEM_FLAG_SERIALIZESIZE\
        )
#define PCPROPERTY_ITEM_FLAG_DEFAULTVALUES  KSPROPERTY_TYPE_DEFAULTVALUES
    PCPFNPROPERTY_HANDLER   Handler;
}
PCPROPERTY_ITEM, *PPCPROPERTY_ITEM;


struct _PCPROPERTY_REQUEST
{
    PUNKNOWN                MajorTarget;
    PUNKNOWN                MinorTarget;
    ULONG                   Node;
    const PCPROPERTY_ITEM * PropertyItem;
    ULONG                   Verb;
    ULONG                   InstanceSize;
    PVOID                   Instance;
    ULONG                   ValueSize;
    PVOID                   Value;
    PIRP                    Irp;
};

struct _PCEVENT_REQUEST;

typedef NTSTATUS (NTAPI *PCPFNEVENT_HANDLER)(
    IN  struct _PCEVENT_REQUEST* EventRequest);

typedef struct _PCEVENT_ITEM
{
    const GUID* Set;
    ULONG Id;
    ULONG Flags;
    PCPFNEVENT_HANDLER Handler;
} PCEVENT_ITEM, *PPCEVENT_ITEM;

typedef struct _PCEVENT_REQUEST
{
    PUNKNOWN MajorTarget;
    PUNKNOWN MinorTarget;
    ULONG Node;
    const PCEVENT_ITEM* EventItem;
    PKSEVENT_ENTRY EventEntry;
    ULONG Verb;
    PIRP Irp;
} PCEVENT_REQUEST, *PPCEVENT_REQUEST;



struct _PCMETHOD_REQUEST;

typedef NTSTATUS (NTAPI *PCPFNMETHOD_HANDLER)(
    IN  struct _PCMETHOD_REQUEST* MethodRequest);

typedef struct _PCMETHOD_ITEM
{
    const GUID* Set;
    ULONG Id;
    ULONG Flags;
    PCPFNMETHOD_HANDLER Handler;
} PCMETHOD_ITEM, *PPCMETHOD_ITEM;

typedef struct _PCMETHOD_REQUEST
{
    PUNKNOWN MajorTarget;
    PUNKNOWN MinorTarget;
    ULONG Node;
    const PCMETHOD_ITEM* MethodItem;
    ULONG Verb;
} PCMETHOD_REQUEST, *PPCMETHOD_REQUEST;


/* ===============================================================
    Structures (unsorted)
*/

typedef struct
{
    ULONG PropertyItemSize;
    ULONG PropertyCount;
    const PCPROPERTY_ITEM* Properties;
    ULONG MethodItemSize;
    ULONG MethodCount;
    const PCMETHOD_ITEM* Methods;
    ULONG EventItemSize;
    ULONG EventCount;
    const PCEVENT_ITEM* Events;
    ULONG Reserved;
} PCAUTOMATION_TABLE, *PPCAUTOMATION_TABLE;

typedef struct
{
    ULONG FromNode;
    ULONG FromNodePin;
    ULONG ToNode;
    ULONG ToNodePin;
} PCCONNECTION_DESCRIPTOR, *PPCCONNECTIONDESCRIPTOR;

typedef struct
{
    ULONG MaxGlobalInstanceCount;
    ULONG MaxFilterInstanceCount;
    ULONG MinFilterInstanceCount;
    const PCAUTOMATION_TABLE* AutomationTable;
    KSPIN_DESCRIPTOR KsPinDescriptor;
} PCPIN_DESCRIPTOR, *PPCPIN_DESCRIPTOR;

typedef struct
{
    ULONG Flags;
    const PCAUTOMATION_TABLE* AutomationTable;
    const GUID* Type;
    const GUID* Name;
} PCNODE_DESCRIPTOR, *PPCNODE_DESCRIPTOR;

typedef struct
{
    ULONG Version;
    const PCAUTOMATION_TABLE* AutomationTable;
    ULONG PinSize;
    ULONG PinCount;
    const PCPIN_DESCRIPTOR* Pins;
    ULONG NodeSize;
    ULONG NodeCount;
    const PCNODE_DESCRIPTOR* Nodes;
    ULONG ConnectionCount;
    const PCCONNECTION_DESCRIPTOR* Connections;
    ULONG CategoryCount;
    const GUID* Categories;
} PCFILTER_DESCRIPTOR, *PPCFILTER_DESCRIPTOR;

#define DEFINE_PCAUTOMATION_TABLE_PROP(AutomationTable,PropertyTable)\
const PCAUTOMATION_TABLE AutomationTable =\
{\
    sizeof(PropertyTable[0]),\
    SIZEOF_ARRAY(PropertyTable),\
    (const PCPROPERTY_ITEM *) PropertyTable,\
    0,0,NULL,\
    0,0,NULL,\
    0\
}

/* ===============================================================
    IResourceList Interface
*/

#undef INTERFACE
#define INTERFACE IResourceList

DEFINE_GUID(IID_IResourceList, 0x22C6AC60L, 0x851B, 0x11D0, 0x9A, 0x7F, 0x00, 0xAA, 0x00, 0x38, 0xAC, 0xFE);

DECLARE_INTERFACE_(IResourceList, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(ULONG, NumberOfEntries)( THIS ) PURE;

    STDMETHOD_(ULONG, NumberOfEntriesOfType)( THIS_
        IN  CM_RESOURCE_TYPE Type) PURE;

    STDMETHOD_(PCM_PARTIAL_RESOURCE_DESCRIPTOR, FindTranslatedEntry)( THIS_
        IN  CM_RESOURCE_TYPE Type,
        IN  ULONG Index) PURE;

    STDMETHOD_(PCM_PARTIAL_RESOURCE_DESCRIPTOR, FindUntranslatedEntry)( THIS_
        IN  CM_RESOURCE_TYPE Type,
        IN  ULONG Index) PURE;

    STDMETHOD_(NTSTATUS, AddEntry)( THIS_
        IN  PCM_PARTIAL_RESOURCE_DESCRIPTOR Translated,
        IN  PCM_PARTIAL_RESOURCE_DESCRIPTOR Untranslated) PURE;

    STDMETHOD_(NTSTATUS, AddEntryFromParent)( THIS_
        IN  IResourceList* Parent,
        IN  CM_RESOURCE_TYPE Type,
        IN  ULONG Index) PURE;

    STDMETHOD_(PCM_RESOURCE_LIST, TranslatedList)( THIS ) PURE;
    STDMETHOD_(PCM_RESOURCE_LIST, UntranslatedList)( THIS ) PURE;
};

#define IMP_IResourceList \
    STDMETHODIMP_(ULONG) NumberOfEntries(void); \
\
    STDMETHODIMP_(ULONG) NumberOfEntriesOfType( \
        IN  CM_RESOURCE_TYPE Type); \
\
    STDMETHODIMP_(PCM_PARTIAL_RESOURCE_DESCRIPTOR) FindTranslatedEntry( \
        IN  CM_RESOURCE_TYPE Type, \
        IN  ULONG Index); \
\
    STDMETHODIMP_(PCM_PARTIAL_RESOURCE_DESCRIPTOR) FindUntranslatedEntry( \
        IN  CM_RESOURCE_TYPE Type, \
        IN  ULONG Index); \
\
    STDMETHODIMP_(NTSTATUS) AddEntry( \
        IN  PCM_PARTIAL_RESOURCE_DESCRIPTOR Translated, \
        IN  PCM_PARTIAL_RESOURCE_DESCRIPTOR Untranslated); \
\
    STDMETHODIMP_(NTSTATUS) AddEntryFromParent( \
        IN  IResourceList* Parent, \
        IN  CM_RESOURCE_TYPE Type, \
        IN  ULONG Index); \
\
    STDMETHODIMP_(PCM_RESOURCE_LIST) TranslatedList(void); \
    STDMETHODIMP_(PCM_RESOURCE_LIST) UntranslatedList(void);

typedef IResourceList *PRESOURCELIST;

#define NumberOfPorts() \
    NumberOfEntriesOfType(CmResourceTypePort)

#define FindTranslatedPort(n) \
    FindTranslatedEntry(CmResourceTypePort, (n))

#define FindUntranslatedPort(n) \
    FindUntranslatedEntry(CmResourceTypePort, (n))

#define AddPortFromParent(p, n) \
    AddEntryFromParent((p), CmResourceTypePort, (n))

#define NumberOfInterrupts() \
    NumberOfEntriesOfType(CmResourceTypeInterrupt)

#define FindTranslatedInterrupt(n) \
    FindTranslatedEntry(CmResourceTypeInterrupt, (n))

#define FindUntranslatedInterrupt(n) \
    FindUntranslatedEntry(CmResourceTypeInterrupt, (n))

#define AddInterruptFromParent(p, n) \
    AddEntryFromParent((p), CmResourceTypeInterrupt, (n))

#define NumberOfMemories() \
    NumberOfEntriesOfType(CmResourceTypeMemory)

#define FindTranslatedMemory(n) \
    FindTranslatedEntry(CmResourceTypeMemory, (n))

#define FindUntranslatedMemory(n) \
    FindUntranslatedEntry(CmResourceTypeMemory, (n))

#define AddMemoryFromParent(p, n) \
    AddEntryFromParent((p), CmResourceTypeMemory, (n))

#define NumberOfDmas() \
    NumberOfEntriesOfType(CmResourceTypeDma)

#define FindTranslatedDma(n) \
    FindTranslatedEntry(CmResourceTypeDma, (n))

#define FindUntranslatedDma(n) \
    FindUntranslatedEntry(CmResourceTypeDma, (n))

#define AddDmaFromParent(p, n) \
    AddEntryFromParent((p), CmResourceTypeInterrupt, (n))

#define NumberOfDeviceSpecifics() \
    NumberOfEntriesOfType(CmResourceTypeDeviceSpecific)

#define FindTranslatedDeviceSpecific(n) \
    FindTranslatedEntry(CmResourceTypeDeviceSpecific, (n))

#define FindUntranslatedDeviceSpecific(n) \
    FindUntranslatedEntry(CmResourceTypeDeviceSpecific, (n))

#define AddDeviceSpecificFromParent(p, n) \
    AddEntryFromParent((p), CmResourceTypeDeviceSpecific, (n))

#define NumberOfBusNumbers() \
    NumberOfEntriesOfType(CmResourceTypeBusNumber)

#define FindTranslatedBusNumber(n) \
    FindTranslatedEntry(CmResourceTypeBusNumber, (n))

#define FindUntranslatedBusNumber(n) \
    FindUntranslatedEntry(CmResourceTypeBusNumber, (n))

#define AddBusNumberFromParent(p, n) \
    AddEntryFromParent((p), CmResourceTypeBusNumber, (n))

#define NumberOfDevicePrivates() \
    NumberOfEntriesOfType(CmResourceTypeDevicePrivate)

#define FindTranslatedDevicePrivate(n) \
    FindTranslatedEntry(CmResourceTypeDevicePrivate, (n))

#define FindUntranslatedDevicePrivate(n) \
    FindUntranslatedEntry(CmResourceTypeDevicePrivate, (n))

#define AddDevicePrivateFromParent(p, n) \
    AddEntryFromParent((p), CmResourceTypeDevicePrivate, (n))

#define NumberOfAssignedResources() \
    NumberOfEntriesOfType(CmResourceTypeAssignedResource)

#define FindTranslatedAssignedResource(n) \
    FindTranslatedEntry(CmResourceTypeAssignedResource, (n))

#define FindUntranslatedAssignedResource(n) \
    FindUntranslatedEntry(CmResourceTypeAssignedResource, (n))

#define AddAssignedResourceFromParent(p, n) \
    AddEntryFromParent((p), CmResourceTypeAssignedResource, (n))

#define NumberOfSubAllocateFroms() \
    NumberOfEntriesOfType(CmResourceTypeSubAllocateFrom)

#define FindTranslatedSubAllocateFrom(n) \
    FindTranslatedEntry(CmResourceTypeSubAllocateFrom, (n))

#define FindUntranslatedSubAllocateFrom(n) \
    FindUntranslatedEntry(CmResourceTypeSubAllocateFrom, (n))

#define AddSubAllocateFromFromParent(p, n) \
    AddEntryFromParent((p), CmResourceTypeSubAllocateFrom, (n))

#undef INTERFACE


/* ===============================================================
    IServiceSink Interface
*/
#define INTERFACE IServiceSink

DEFINE_GUID(IID_IServiceSink, 0x22C6AC64L, 0x851B, 0x11D0, 0x9A, 0x7F, 0x00, 0xAA, 0x00, 0x38, 0xAC, 0xFE);

DECLARE_INTERFACE_(IServiceSink, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()
    STDMETHOD_(void, RequestService)( THIS ) PURE;
};

#define IMP_IServiceSink \
    STDMETHODIMP_(void) RequestService(void);

typedef IServiceSink *PSERVICESINK;


/* ===============================================================
    IServiceGroup Interface
*/
#undef INTERFACE
#define INTERFACE IServiceGroup

DEFINE_GUID(IID_IServiceGroup, 0x22C6AC65L, 0x851B, 0x11D0, 0x9A, 0x7F, 0x00, 0xAA, 0x00, 0x38, 0xAC, 0xFE);

DECLARE_INTERFACE_(IServiceGroup, IServiceSink)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(void, RequestService)( THIS ) PURE;  /* IServiceSink */

    STDMETHOD_(NTSTATUS, AddMember)( THIS_
        IN  PSERVICESINK pServiceSink) PURE;

    STDMETHOD_(void, RemoveMember)( THIS_
        IN  PSERVICESINK pServiceSink) PURE;

    STDMETHOD_(void, SupportDelayedService)( THIS ) PURE;

    STDMETHOD_(void, RequestDelayedService)( THIS_
        IN  ULONGLONG ullDelay) PURE;

    STDMETHOD_(void, CancelDelayedService)( THIS ) PURE;
};

#define IMP_IServiceGroup \
    IMP_IServiceSink; \
\
    STDMETHODIMP_(NTSTATUS) AddMember( \
        IN  PSERVICESINK pServiceSink); \
\
    STDMETHODIMP_(void) RemoveMember( \
        IN  PSERVICESINK pServiceSink); \
\
    STDMETHODIMP_(void) SupportDelayedService(void); \
\
    STDMETHODIMP_(void) RequestDelayedService( \
        IN  ULONGLONG ullDelay); \
\
    STDMETHODIMP_(void) CancelDelayedService(void);

typedef IServiceGroup *PSERVICEGROUP;


#if (NTDDI_VERSION >= NTDDI_WS03)
/* ===============================================================
    IUnregisterSubdevice Interface
*/

DEFINE_GUID(IID_IUnregisterSubdevice, 0x16738177L, 0xe199, 0x41f9, 0x9a, 0x87, 0xab, 0xb2, 0xa5, 0x43, 0x2f, 0x21);

#undef INTERFACE
#define INTERFACE IUnregisterSubdevice

DECLARE_INTERFACE_(IUnregisterSubdevice,IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(NTSTATUS,UnregisterSubdevice)(THIS_
        IN  PDEVICE_OBJECT  DeviceObject,
        IN  PUNKNOWN        Unknown)PURE;
};

typedef IUnregisterSubdevice *PUNREGISTERSUBDEVICE;

#define IMP_IUnregisterSubdevice                        \
    STDMETHODIMP_(NTSTATUS) UnregisterSubdevice(THIS_   \
        IN  PDEVICE_OBJECT  DeviceObject,               \
        IN  PUNKNOWN        Unknown)

/* ===============================================================
    IUnregisterPhysicalConnection Interface
*/

#undef INTERFACE
#define INTERFACE IUnregisterPhysicalConnection

DEFINE_GUID(IID_IUnregisterPhysicalConnection, 0x6c38e231L, 0x2a0d, 0x428d, 0x81, 0xf8, 0x07, 0xcc, 0x42, 0x8b, 0xb9, 0xa4);

DECLARE_INTERFACE_(IUnregisterPhysicalConnection,IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(NTSTATUS,UnregisterPhysicalConnection)(THIS_
        IN  PDEVICE_OBJECT  DeviceObject,
        IN  PUNKNOWN        FromUnknown,
        IN  ULONG           FromPin,
        IN  PUNKNOWN        ToUnknown,
        IN  ULONG           ToPin)PURE;

    STDMETHOD_(NTSTATUS,UnregisterPhysicalConnectionToExternal)(THIS_
        IN  PDEVICE_OBJECT  DeviceObject,
        IN  PUNKNOWN        FromUnknown,
        IN  ULONG           FromPin,
        IN  PUNICODE_STRING ToString,
        IN  ULONG           ToPin)PURE;

    STDMETHOD_(NTSTATUS,UnregisterPhysicalConnectionFromExternal)(THIS_
        IN  PDEVICE_OBJECT  DeviceObject,
        IN  PUNICODE_STRING FromString,
        IN  ULONG           FromPin,
        IN  PUNKNOWN        ToUnknown,
        IN  ULONG           ToPin)PURE;
};

typedef IUnregisterPhysicalConnection *PUNREGISTERPHYSICALCONNECTION;
#endif

#define IMP_IUnregisterPhysicalConnection                                    \
    STDMETHODIMP_(NTSTATUS) UnregisterPhysicalConnection(                    \
        IN  PDEVICE_OBJECT  DeviceObject,                                    \
        IN  PUNKNOWN        FromUnknown,                                     \
        IN  ULONG           FromPin,                                         \
        IN  PUNKNOWN        ToUnknown,                                       \
        IN  ULONG           ToPin);                                          \
                                                                             \
    STDMETHODIMP_(NTSTATUS) UnregisterPhysicalConnectionToExternal(          \
        IN  PDEVICE_OBJECT  DeviceObject,                                    \
        IN  PUNKNOWN        FromUnknown,                                     \
        IN  ULONG           FromPin,                                         \
        IN  PUNICODE_STRING ToString,                                        \
        IN  ULONG           ToPin);                                          \
                                                                             \
    STDMETHODIMP_(NTSTATUS) UnregisterPhysicalConnectionFromExternal(        \
        IN  PDEVICE_OBJECT  DeviceObject,                                    \
        IN  PUNICODE_STRING FromString,                                      \
        IN  ULONG           FromPin,                                         \
        IN  PUNKNOWN        ToUnknown,                                       \
        IN  ULONG           ToPin)


/* ===============================================================
    IDmaChannel Interface
*/

#define DEFINE_ABSTRACT_DMACHANNEL() \
    STDMETHOD_(NTSTATUS, AllocateBuffer)( THIS_ \
        IN  ULONG BufferSize, \
        IN  PPHYSICAL_ADDRESS PhysicalAddressConstraint OPTIONAL) PURE; \
\
    STDMETHOD_(void, FreeBuffer)( THIS ) PURE; \
    STDMETHOD_(ULONG, TransferCount)( THIS ) PURE; \
    STDMETHOD_(ULONG, MaximumBufferSize)( THIS ) PURE; \
    STDMETHOD_(ULONG, AllocatedBufferSize)( THIS ) PURE; \
    STDMETHOD_(ULONG, BufferSize)( THIS ) PURE; \
\
    STDMETHOD_(void, SetBufferSize)( THIS_ \
        IN  ULONG BufferSize) PURE; \
\
    STDMETHOD_(PVOID, SystemAddress)( THIS ) PURE; \
    STDMETHOD_(PHYSICAL_ADDRESS, PhysicalAddress)( THIS ) PURE; \
    STDMETHOD_(PADAPTER_OBJECT, GetAdapterObject)( THIS ) PURE; \
\
    STDMETHOD_(void, CopyTo)( THIS_ \
        IN  PVOID Destination, \
        IN  PVOID Source, \
        IN  ULONG ByteCount) PURE; \
\
    STDMETHOD_(void, CopyFrom)( THIS_ \
        IN  PVOID Destination, \
        IN  PVOID Source, \
        IN  ULONG ByteCount) PURE;

#define IMP_IDmaChannel                                                   \
    STDMETHODIMP_(NTSTATUS) AllocateBuffer(                               \
        IN  ULONG BufferSize,                                             \
        IN  PPHYSICAL_ADDRESS PhysicalAddressConstraint OPTIONAL);        \
                                                                          \
    STDMETHODIMP_(void) FreeBuffer(void);                                 \
    STDMETHODIMP_(ULONG) TransferCount(void);                             \
    STDMETHODIMP_(ULONG) MaximumBufferSize(void);                         \
    STDMETHODIMP_(ULONG) AllocatedBufferSize(void);                       \
    STDMETHODIMP_(ULONG) BufferSize(void);                                \
                                                                          \
    STDMETHODIMP_(void) SetBufferSize(                                    \
        IN  ULONG BufferSize);                                            \
                                                                          \
    STDMETHODIMP_(PVOID) SystemAddress(void);                             \
    STDMETHODIMP_(PHYSICAL_ADDRESS) PhysicalAddress(void);                \
    STDMETHODIMP_(PADAPTER_OBJECT) GetAdapterObject(void);                \
                                                                          \
    STDMETHODIMP_(void) CopyTo(                                           \
        IN  PVOID Destination,                                            \
        IN  PVOID Source,                                                 \
        IN  ULONG ByteCount);                                             \
                                                                          \
    STDMETHODIMP_(void) CopyFrom(                                         \
        IN  PVOID Destination,                                            \
        IN  PVOID Source,                                                 \
        IN  ULONG ByteCount)

#undef INTERFACE
#define INTERFACE IDmaChannel

DEFINE_GUID(IID_IDmaChannel, 0x22C6AC61L, 0x851B, 0x11D0, 0x9A, 0x7F, 0x00, 0xAA, 0x00, 0x38, 0xAC, 0xFE);

DECLARE_INTERFACE_(IDmaChannel, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_DMACHANNEL()
};

typedef IDmaChannel *PDMACHANNEL;


/* ===============================================================
    IDmaChannelSlave Interface
*/

#define DEFINE_ABSTRACT_DMACHANNELSLAVE() \
    STDMETHOD_(NTSTATUS, Start)( THIS_ \
        IN  ULONG MapSize, \
        IN  BOOLEAN WriteToDevice) PURE; \
\
    STDMETHOD_(NTSTATUS, Stop)( THIS ) PURE; \
    STDMETHOD_(ULONG, ReadCounter)( THIS ) PURE; \
\
    STDMETHOD_(NTSTATUS, WaitForTC)( THIS_ \
        ULONG Timeout) PURE;

#define IMP_IDmaChannelSlave                   \
    IMP_IDmaChannel;                           \
    STDMETHODIMP_(NTSTATUS) Start(             \
        IN  ULONG MapSize,                     \
        IN  BOOLEAN WriteToDevice);            \
                                               \
    STDMETHODIMP_(NTSTATUS) Stop(void);        \
    STDMETHODIMP_(ULONG) ReadCounter(void);    \
                                               \
    STDMETHODIMP_(NTSTATUS) WaitForTC(         \
        ULONG Timeout)

#undef INTERFACE
#define INTERFACE IDmaChannelSlave

#if (NTDDI_VERSION < NTDDI_LONGHORN)
DEFINE_GUID(IID_IDmaChannelSlave, 0x22C6AC62L, 0x851B, 0x11D0, 0x9A, 0x7F, 0x00, 0xAA, 0x00, 0x38, 0xAC, 0xFE);
#endif

#undef INTERFACE
#define INTERFACE IDmaChannelSlave

DECLARE_INTERFACE_(IDmaChannelSlave, IDmaChannel)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_DMACHANNEL()
    DEFINE_ABSTRACT_DMACHANNELSLAVE()
};

typedef IDmaChannelSlave *PDMACHANNELSLAVE;


/* ===============================================================
    IInterruptSync Interface
*/

typedef enum
{
    InterruptSyncModeNormal = 1,
    InterruptSyncModeAll,
    InterruptSyncModeRepeat
} INTERRUPTSYNCMODE;

struct IInterruptSync;

typedef NTSTATUS (NTAPI *PINTERRUPTSYNCROUTINE)(
    IN  struct IInterruptSync* InterruptSync,
    IN  PVOID DynamicContext);

#undef INTERFACE
#define INTERFACE IInterruptSync

DECLARE_INTERFACE_(IInterruptSync, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(NTSTATUS, CallSynchronizedRoutine)( THIS_
        IN  PINTERRUPTSYNCROUTINE Routine,
        IN  PVOID DynamicContext) PURE;

    STDMETHOD_(PKINTERRUPT, GetKInterrupt)( THIS ) PURE;
    STDMETHOD_(NTSTATUS, Connect)( THIS ) PURE;
    STDMETHOD_(void, Disconnect)( THIS ) PURE;

    STDMETHOD_(NTSTATUS, RegisterServiceRoutine)( THIS_
        IN  PINTERRUPTSYNCROUTINE Routine,
        IN  PVOID DynamicContext,
        IN  BOOLEAN First) PURE;
};

DEFINE_GUID(IID_IInterruptSync, 0x22C6AC63L, 0x851B, 0x11D0, 0x9A, 0x7F, 0x00, 0xAA, 0x00, 0x38, 0xAC, 0xFE);

#define IMP_IInterruptSync                           \
    STDMETHODIMP_(NTSTATUS) CallSynchronizedRoutine( \
        IN  PINTERRUPTSYNCROUTINE Routine,           \
        IN  PVOID DynamicContext);                   \
                                                     \
    STDMETHODIMP_(PKINTERRUPT) GetKInterrupt(void);  \
    STDMETHODIMP_(NTSTATUS) Connect(void);           \
    STDMETHODIMP_(void) Disconnect(void);            \
                                                     \
    STDMETHODIMP_(NTSTATUS) RegisterServiceRoutine(  \
        IN  PINTERRUPTSYNCROUTINE Routine,           \
        IN  PVOID DynamicContext,                    \
        IN  BOOLEAN First)

typedef IInterruptSync *PINTERRUPTSYNC;


/* ===============================================================
    IRegistryKey Interface
*/

#undef INTERFACE
#define INTERFACE IRegistryKey

enum
{
    GeneralRegistryKey,
    DeviceRegistryKey,
    DriverRegistryKey,
    HwProfileRegistryKey,
    DeviceInterfaceRegistryKey
};

DEFINE_GUID(IID_IRegistryKey, 0xE8DA4302l, 0xF304, 0x11D0, 0x95, 0x8B, 0x00, 0xC0, 0x4F, 0xB9, 0x25, 0xD3);

DECLARE_INTERFACE_(IRegistryKey, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(NTSTATUS, QueryKey)( THIS_
        IN  KEY_INFORMATION_CLASS KeyInformationClass,
        OUT PVOID KeyInformation,
        IN  ULONG Length,
        OUT PULONG ResultLength) PURE;

    STDMETHOD_(NTSTATUS, EnumerateKey)( THIS_
        IN  ULONG Index,
        IN  KEY_INFORMATION_CLASS KeyInformationClass,
        OUT PVOID KeyInformation,
        IN  ULONG Length,
        OUT PULONG ResultLength) PURE;

    STDMETHOD_(NTSTATUS, QueryValueKey)( THIS_
        IN  PUNICODE_STRING ValueName,
        IN  KEY_VALUE_INFORMATION_CLASS KeyValueInformationClass,
        OUT PVOID KeyValueInformation,
        IN  ULONG Length,
        OUT PULONG ResultLength) PURE;

    STDMETHOD_(NTSTATUS, EnumerateValueKey)( THIS_
        IN  ULONG Index,
        IN  KEY_VALUE_INFORMATION_CLASS KeyValueInformationClass,
        OUT PVOID KeyValueInformation,
        IN  ULONG Length,
        OUT PULONG ResultLength) PURE;

    STDMETHOD_(NTSTATUS, SetValueKey)( THIS_
        IN  PUNICODE_STRING ValueName OPTIONAL,
        IN  ULONG Type,
        IN  PVOID Data,
        IN  ULONG DataSize) PURE;

    STDMETHOD_(NTSTATUS, QueryRegistryValues)( THIS_
        IN  PRTL_QUERY_REGISTRY_TABLE QueryTable,
        IN  PVOID Context OPTIONAL) PURE;

    STDMETHOD_(NTSTATUS, NewSubKey)( THIS_
        OUT IRegistryKey** RegistrySubKey,
        IN  PUNKNOWN OuterUnknown,
        IN  ACCESS_MASK DesiredAccess,
        IN  PUNICODE_STRING SubKeyName,
        IN  ULONG CreateOptions,
        OUT PULONG Disposition OPTIONAL) PURE;

    STDMETHOD_(NTSTATUS, DeleteKey)( THIS ) PURE;
};

#define IMP_IRegistryKey \
    STDMETHODIMP_(NTSTATUS) QueryKey( \
        IN  KEY_INFORMATION_CLASS KeyInformationClass, \
        OUT PVOID KeyInformation, \
        IN  ULONG Length, \
        OUT PULONG ResultLength); \
\
    STDMETHODIMP_(NTSTATUS) EnumerateKey( \
        IN  ULONG Index, \
        IN  KEY_INFORMATION_CLASS KeyInformationClass, \
        OUT PVOID KeyInformation, \
        IN  ULONG Length, \
        OUT PULONG ResultLength); \
\
    STDMETHODIMP_(NTSTATUS) QueryValueKey( \
        IN  PUNICODE_STRING ValueName, \
        IN  KEY_VALUE_INFORMATION_CLASS KeyValueInformationClass, \
        OUT PVOID KeyValueInformation, \
        IN  ULONG Length, \
        OUT PULONG ResultLength); \
\
    STDMETHODIMP_(NTSTATUS) EnumerateValueKey( \
        IN  ULONG Index, \
        IN  KEY_VALUE_INFORMATION_CLASS KeyValueInformationClass, \
        OUT PVOID KeyValueInformation, \
        IN  ULONG Length, \
        OUT PULONG ResultLength); \
\
    STDMETHODIMP_(NTSTATUS) SetValueKey( \
        IN  PUNICODE_STRING ValueName OPTIONAL, \
        IN  ULONG Type, \
        IN  PVOID Data, \
        IN  ULONG DataSize); \
\
    STDMETHODIMP_(NTSTATUS) QueryRegistryValues( \
        IN  PRTL_QUERY_REGISTRY_TABLE QueryTable, \
        IN  PVOID Context OPTIONAL); \
\
    STDMETHODIMP_(NTSTATUS) NewSubKey( \
        OUT IRegistryKey** RegistrySubKey, \
        IN  PUNKNOWN OuterUnknown, \
        IN  ACCESS_MASK DesiredAccess, \
        IN  PUNICODE_STRING SubKeyName, \
        IN  ULONG CreateOptions, \
        OUT PULONG Disposition OPTIONAL); \
\
    STDMETHODIMP_(NTSTATUS) DeleteKey(void);

typedef IRegistryKey *PREGISTRYKEY;


/* ===============================================================
    IMusicTechnology Interface
*/

DECLARE_INTERFACE_(IMusicTechnology, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(NTSTATUS, SetTechnology)( THIS_
        IN  const GUID* Technology) PURE;
};

#define IMP_IMusicTechnology \
    STDMETHODIMP_(NTSTATUS) SetTechnology( \
        IN  const GUID* Technology);

typedef IMusicTechnology *PMUSICTECHNOLOGY;


/* ===============================================================
    IPort Interface
*/

#if 0
#define STATIC_IPort 0xb4c90a25L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44
DEFINE_GUIDSTRUCT("0xB4C90A25-5791-11d0-86f9-00a0c911b544", IID_IPort);
#define IID_IPort DEFINE_GUIDNAMED(IID_IPort)
#endif

DEFINE_GUID(IID_IMiniport,
    0xb4c90a24L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

DEFINE_GUID(IID_IPort,
    0xb4c90a25L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

#define DEFINE_ABSTRACT_PORT() \
    STDMETHOD_(NTSTATUS, Init)( THIS_ \
        IN  PDEVICE_OBJECT DeviceObject, \
        IN  PIRP Irp, \
        IN  PUNKNOWN UnknownMiniport, \
        IN  PUNKNOWN UnknownAdapter OPTIONAL, \
        IN  PRESOURCELIST ResourceList) PURE; \
\
    STDMETHOD_(NTSTATUS, GetDeviceProperty)( THIS_ \
        IN  DEVICE_REGISTRY_PROPERTY DeviceProperty, \
        IN  ULONG BufferLength, \
        OUT PVOID PropertyBuffer, \
        OUT PULONG ResultLength) PURE; \
\
    STDMETHOD_(NTSTATUS, NewRegistryKey)( THIS_ \
        OUT PREGISTRYKEY* OutRegistryKey, \
        IN  PUNKNOWN OuterUnknown OPTIONAL, \
        IN  ULONG RegistryKeyType, \
        IN  ACCESS_MASK DesiredAccess, \
        IN  POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL, \
        IN  ULONG CreateOptiona OPTIONAL, \
        OUT PULONG Disposition OPTIONAL) PURE;

#ifdef PC_IMPLEMENTATION
#define IMP_IPort\
    STDMETHODIMP_(NTSTATUS) Init\
    (   IN      PDEVICE_OBJECT  DeviceObject,\
        IN      PIRP            Irp,\
        IN      PUNKNOWN        UnknownMiniport,\
        IN      PUNKNOWN        UnknownAdapter      OPTIONAL,\
        IN      PRESOURCELIST   ResourceList\
    );\
    STDMETHODIMP_(NTSTATUS) GetDeviceProperty\
    (   IN      DEVICE_REGISTRY_PROPERTY    DeviceProperty,\
        IN      ULONG                       BufferLength,\
        OUT     PVOID                       PropertyBuffer,\
        OUT     PULONG                      ResultLength\
    );\
    STDMETHODIMP_(NTSTATUS) NewRegistryKey\
    (   OUT     PREGISTRYKEY *      OutRegistryKey,\
        IN      PUNKNOWN            OuterUnknown        OPTIONAL,\
        IN      ULONG               RegistryKeyType,\
        IN      ACCESS_MASK         DesiredAccess,\
        IN      POBJECT_ATTRIBUTES  ObjectAttributes    OPTIONAL,\
        IN      ULONG               CreateOptions       OPTIONAL,\
        OUT     PULONG              Disposition         OPTIONAL\
    )
#endif

#undef INTERFACE
#define INTERFACE IPort

DECLARE_INTERFACE_(IPort, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_PORT()
};

typedef IPort *PPORT;


/* ===============================================================
    IPortMidi Interface
*/

DEFINE_GUID(IID_IPortMidi,
    0xb4c90a40L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);
DEFINE_GUID(CLSID_PortMidi,
    0xb4c90a43L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

#undef INTERFACE
#define INTERFACE IPortMidi

DECLARE_INTERFACE_(IPortMidi, IPort)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_PORT()

    STDMETHOD_(VOID, Notify)(THIS_
        IN  PSERVICEGROUP ServiceGroup OPTIONAL) PURE;

    STDMETHOD_(NTSTATUS, RegisterServiceGroup)(THIS_
        IN  PSERVICEGROUP ServiceGroup) PURE;
};

typedef IPortMidi *PPORTMIDI;

#define IMP_IPortMidi() \
    STDMETHODIMP_(VOID) Notify( \
        IN  PSERVICEGROUP ServiceGroup OPTIONAL); \
\
    STDMETHODIMP_(NTSTATUS) RegisterServiceGroup( \
        IN  PSERVICEGROUP ServiceGroup);

#undef INTERFACE

/* ===============================================================
    IPortWaveCyclic Interface
*/

DEFINE_GUID(IID_IPortWaveCyclic,
    0xb4c90a26L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);
DEFINE_GUID(CLSID_PortWaveCyclic,
    0xb4c90a2aL, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

#define INTERFACE IPortWaveCyclic

DECLARE_INTERFACE_(IPortWaveCyclic, IPort)
{
    DEFINE_ABSTRACT_UNKNOWN()

    DEFINE_ABSTRACT_PORT()

    STDMETHOD_(VOID, Notify)(THIS_
        IN  PSERVICEGROUP ServiceGroup) PURE;

    STDMETHOD_(NTSTATUS, NewSlaveDmaChannel)(THIS_
        OUT PDMACHANNELSLAVE* DmaChannel,
        IN  PUNKNOWN OuterUnknown,
        IN  PRESOURCELIST ResourceList OPTIONAL,
        IN  ULONG DmaIndex,
        IN  ULONG MaximumLength,
        IN  BOOLEAN DemandMode,
        IN  DMA_SPEED DmaSpeed) PURE;

    STDMETHOD_(NTSTATUS, NewMasterDmaChannel)(THIS_
        OUT PDMACHANNEL* DmaChannel,
        IN  PUNKNOWN OuterUnknown,
        IN  PRESOURCELIST ResourceList OPTIONAL,
        IN  ULONG MaximumLength,
        IN  BOOLEAN Dma32BitAddresses,
        IN  BOOLEAN Dma64BitAddresses,
        IN  DMA_WIDTH DmaWidth,
        IN  DMA_SPEED DmaSpeed) PURE;

};

typedef IPortWaveCyclic *PPORTWAVECYCLIC;

#ifdef PC_IMPLEMENTATION
#define IMP_IPortWaveCyclic                           \
    IMP_IPort;                                        \
    STDMETHODIMP_(VOID) Notify(                       \
        IN  PSERVICEGROUP ServiceGroup);              \
                                                      \
    STDMETHODIMP_(NTSTATUS) NewSlaveDmaChannel(       \
        OUT PDMACHANNELSLAVE* DmaChannel,             \
        IN  PUNKNOWN OuterUnknown,                    \
        IN  PRESOURCELIST ResourceList OPTIONAL,      \
        IN  ULONG DmaIndex,                           \
        IN  ULONG MaximumLength,                      \
        IN  BOOLEAN DemandMode,                       \
        IN  DMA_SPEED DmaSpeed);                      \
                                                      \
    STDMETHODIMP_(NTSTATUS) NewMasterDmaChannel(      \
        OUT PDMACHANNEL* DmaChannel,                  \
        IN  PUNKNOWN OuterUnknown,                    \
        IN  PRESOURCELIST ResourceList OPTIONAL,      \
        IN  ULONG MaximumLength,                      \
        IN  BOOLEAN Dma32BitAddresses,                \
        IN  BOOLEAN Dma64BitAddresses,                \
        IN  DMA_WIDTH DmaWidth,                       \
        IN  DMA_SPEED DmaSpeed)
#endif


#undef INTERFACE
/* ===============================================================
    IPortWavePci Interface
*/
#undef INTERFACE
#define INTERFACE IPortWavePci

DEFINE_GUID(IID_IPortWavePci,
    0xb4c90a50L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);
DEFINE_GUID(CLSID_PortWavePci,
    0xb4c90a54L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

DECLARE_INTERFACE_(IPortWavePci, IPort)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_PORT()

    STDMETHOD_(VOID, Notify)(THIS_
        IN  PSERVICEGROUP ServiceGroup) PURE;

    STDMETHOD_(NTSTATUS, NewMasterDmaChannel)(THIS_
        OUT PDMACHANNEL* DmaChannel,
        IN  PUNKNOWN OuterUnknown,
        IN  POOL_TYPE PoolType,
        IN  PRESOURCELIST ResourceList OPTIONAL,
        IN  BOOLEAN ScatterGather,
        IN  BOOLEAN Dma32BitAddresses,
        IN  BOOLEAN Dma64BitAddresses,
        IN  BOOLEAN IgnoreCount,
        IN  DMA_WIDTH DmaWidth,
        IN  DMA_SPEED DmaSpeed,
        IN  ULONG MaximumLength,
        IN  ULONG DmaPort) PURE;
};

typedef IPortWavePci *PPORTWAVEPCI;
#undef INTERFACE

#ifdef PC_IMPLEMENTATION
#define IMP_IPortWavePci                                     \
    IMP_IPort;                                               \
    STDMETHODIMP_(VOID) Notify(                              \
        IN  PSERVICEGROUP ServiceGroup);                     \
                                                             \
    STDMETHODIMP_(NTSTATUS) NewMasterDmaChannel(             \
        OUT PDMACHANNEL* DmaChannel,                         \
        IN  PUNKNOWN OuterUnknown,                           \
        IN  POOL_TYPE PoolType,                              \
        IN  PRESOURCELIST ResourceList OPTIONAL,             \
        IN  BOOLEAN ScatterGather,                           \
        IN  BOOLEAN Dma32BitAddresses,                       \
        IN  BOOLEAN Dma64BitAddresses,                       \
        IN  BOOLEAN IgnoreCount,                             \
        IN  DMA_WIDTH DmaWidth,                              \
        IN  DMA_SPEED DmaSpeed,                              \
        IN  ULONG MaximumLength,                             \
        IN  ULONG DmaPort);
#endif

/* ===============================================================
    IMiniPort Interface
*/

DEFINE_GUID(IID_IMiniPort,
    0xb4c90a24L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

#define DEFINE_ABSTRACT_MINIPORT() \
    STDMETHOD_(NTSTATUS, GetDescription)( THIS_ \
        OUT  PPCFILTER_DESCRIPTOR* Description) PURE; \
\
    STDMETHOD_(NTSTATUS, DataRangeIntersection)( THIS_ \
        IN  ULONG PinId, \
        IN  PKSDATARANGE DataRange, \
        IN  PKSDATARANGE MatchingDataRange, \
        IN  ULONG OutputBufferLength, \
        OUT PVOID ResultantFormat OPTIONAL, \
        OUT PULONG ResultantFormatLength) PURE;

#define IMP_IMiniport                                        \
    STDMETHODIMP_(NTSTATUS) GetDescription(                  \
        OUT  PPCFILTER_DESCRIPTOR* Description);             \
                                                             \
    STDMETHODIMP_(NTSTATUS) DataRangeIntersection(           \
        IN  ULONG PinId,                                     \
        IN  PKSDATARANGE DataRange,                          \
        IN  PKSDATARANGE MatchingDataRange,                  \
        IN  ULONG OutputBufferLength,                        \
        OUT PVOID ResultantFormat OPTIONAL,                  \
        OUT PULONG ResultantFormatLength)

DECLARE_INTERFACE_(IMiniport, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_MINIPORT()
};

typedef IMiniport *PMINIPORT;


/* ===============================================================
    IMiniportMidiStream Interface
*/
#undef INTERFACE
#define INTERFACE IMiniportMidiStream

DEFINE_GUID(IID_IMiniportMidiStream,
    0xb4c90a42L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

DECLARE_INTERFACE_(IMiniportMidiStream, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(NTSTATUS,SetFormat)(THIS_
        IN PKSDATAFORMAT DataFormat)PURE;

    STDMETHOD_(NTSTATUS,SetState)(THIS_
        IN KSSTATE State)PURE;

    STDMETHOD_(NTSTATUS,Read)(THIS_
        IN PVOID BufferAddress,
        IN ULONG BufferLength,
        OUT PULONG BytesRead)PURE;

    STDMETHOD_(NTSTATUS,Write)(THIS_
        IN PVOID BufferAddress,
        IN ULONG BytesToWrite,
        OUT PULONG BytesWritten)PURE;
};

typedef IMiniportMidiStream* PMINIPORTMIDISTREAM;
#undef INTERFACE

/* ===============================================================
    IMiniportMidi Interface
*/
#undef INTERFACE
#define INTERFACE IMiniportMidi

DEFINE_GUID(IID_IMiniportMidi,
    0xb4c90a41L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

DECLARE_INTERFACE_(IMiniportMidi, IMiniport)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_MINIPORT()

    STDMETHOD_(NTSTATUS, Init)(THIS_
    IN  PUNKNOWN UnknownAdapter,
    IN  PRESOURCELIST ResourceList,
    IN  PPORTMIDI Port,
    OUT PSERVICEGROUP* ServiceGroup) PURE;

    STDMETHOD_(void, Service)(THIS) PURE;

    STDMETHOD_(NTSTATUS, NewStream)(THIS_
        OUT PMINIPORTMIDISTREAM *Stream,
        IN  PUNKNOWN OuterUnknown OPTIONAL,
        IN  POOL_TYPE PoolType,
        IN  ULONG Pin,
        IN  BOOLEAN Capture,
        IN  PKSDATAFORMAT DataFormat,
        OUT PSERVICEGROUP* ServiceGroup) PURE;

};

typedef IMiniportMidi *PMINIPORTMIDI;
#undef INTERFACE

/* ===============================================================
    IMiniportDriverUart Interface
*/

DEFINE_GUID(IID_MiniportDriverUart,
    0xb4c90ae1L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);
DEFINE_GUID(CLSID_MiniportDriverUart,
    0xb4c90ae1L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

/* ===============================================================
    IPortTopology Interface
*/
#if 0
#define STATIC_IPortTopology \
    0xb4c90a30L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44
DEFINE_GUIDSTRUCT("0xB4C90A30-5791-11d0-86f9-00a0c911b544", IID_IPortTopology);
#define IID_IPortTopology DEFINE_GUIDNAMED(IID_IPortTopology)
#endif

#undef INTERFACE
#define INTERFACE IPortTopology

DEFINE_GUID(IID_IPortTopology, 0xb4c90a30L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);
DEFINE_GUID(CLSID_PortTopology, 0xb4c90a32L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

#undef INTERFACE
#define INTERFACE IPortTopology

DECLARE_INTERFACE_(IPortTopology, IPort)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_PORT()
};

typedef IPortTopology *PPORTTOPOLOGY;

#define IMP_IPortTopology IMP_IPort


/* ===============================================================
    IMiniportTopology Interface
*/

#undef INTERFACE
#define INTERFACE IMiniportTopology

DEFINE_GUID(IID_IMiniportTopology, 0xb4c90a31L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

#undef INTERFACE
#define INTERFACE IMiniportTopology

DECLARE_INTERFACE_(IMiniportTopology,IMiniport)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_MINIPORT()

    STDMETHOD_(NTSTATUS,Init)(THIS_
        IN PUNKNOWN UnknownAdapter,
        IN PRESOURCELIST ResourceList,
        IN PPORTTOPOLOGY Port)PURE;
};

typedef IMiniportTopology *PMINIPORTTOPOLOGY;

/* ===============================================================
    IMiniportWaveCyclicStream Interface
*/

#undef INTERFACE
#define INTERFACE IMiniportWaveCyclicStream

DEFINE_GUID(IID_IMiniportWaveCyclicStream,
0xb4c90a28L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

DECLARE_INTERFACE_(IMiniportWaveCyclicStream,IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(NTSTATUS,SetFormat)(THIS_
        IN PKSDATAFORMAT DataFormat)PURE;

    STDMETHOD_(ULONG,SetNotificationFreq)(THIS_
        IN ULONG Interval,
        OUT PULONG FrameSize) PURE;

    STDMETHOD_(NTSTATUS,SetState)(THIS_
        IN KSSTATE State) PURE;

    STDMETHOD_(NTSTATUS,GetPosition)( THIS_
        OUT PULONG Position) PURE;

    STDMETHOD_(NTSTATUS,NormalizePhysicalPosition)(THIS_
        IN OUT PLONGLONG PhysicalPosition) PURE;

    STDMETHOD_(void, Silence)( THIS_
        IN PVOID Buffer,
        IN ULONG ByteCount) PURE;
};

typedef IMiniportWaveCyclicStream *PMINIPORTWAVECYCLICSTREAM;

#define IMP_IMiniportWaveCyclicStream\
    STDMETHODIMP_(NTSTATUS) SetFormat\
    (   IN      PKSDATAFORMAT   DataFormat\
    );\
    STDMETHODIMP_(ULONG) SetNotificationFreq\
    (   IN      ULONG           Interval,\
        OUT     PULONG          FrameSize\
    );\
    STDMETHODIMP_(NTSTATUS) SetState\
    (   IN      KSSTATE         State\
    );\
    STDMETHODIMP_(NTSTATUS) GetPosition\
    (   OUT     PULONG          Position\
    );\
    STDMETHODIMP_(NTSTATUS) NormalizePhysicalPosition\
    (   IN OUT PLONGLONG        PhysicalPosition\
    );\
    STDMETHODIMP_(void) Silence\
    (   IN      PVOID           Buffer,\
        IN      ULONG           ByteCount\
    )


/* ===============================================================
    IMiniportWaveCyclic Interface
*/
#undef INTERFACE

DEFINE_GUID(IID_IMiniportWaveCyclic,
    0xb4c90a27L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

#define INTERFACE IMiniportWaveCyclic

DECLARE_INTERFACE_(IMiniportWaveCyclic, IMiniport)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_MINIPORT()

    STDMETHOD_(NTSTATUS, Init)(THIS_
        IN PUNKNOWN  UnknownAdapter,
        IN PRESOURCELIST  ResourceList,
        IN PPORTWAVECYCLIC  Port) PURE;

    STDMETHOD_(NTSTATUS, NewStream)(THIS_
        OUT PMINIPORTWAVECYCLICSTREAM  *Stream,
        IN PUNKNOWN  OuterUnknown  OPTIONAL,
        IN POOL_TYPE  PoolType,
        IN ULONG  Pin,
        IN BOOLEAN  Capture,
        IN PKSDATAFORMAT  DataFormat,
        OUT PDMACHANNEL  *DmaChannel,
        OUT PSERVICEGROUP  *ServiceGroup) PURE;
};

typedef IMiniportWaveCyclic *PMINIPORTWAVECYCLIC;
#undef INTERFACE

#define IMP_IMiniportWaveCyclic\
    IMP_IMiniport;\
    STDMETHODIMP_(NTSTATUS) Init\
    (   IN      PUNKNOWN        UnknownAdapter,\
        IN      PRESOURCELIST   ResourceList,\
        IN      PPORTWAVECYCLIC Port\
    );\
    STDMETHODIMP_(NTSTATUS) NewStream\
    (   OUT     PMINIPORTWAVECYCLICSTREAM * Stream,\
        IN      PUNKNOWN                    OuterUnknown    OPTIONAL,\
        IN      POOL_TYPE                   PoolType,\
        IN      ULONG                       Pin,\
        IN      BOOLEAN                     Capture,\
        IN      PKSDATAFORMAT               DataFormat,\
        OUT     PDMACHANNEL *               DmaChannel,\
        OUT     PSERVICEGROUP *             ServiceGroup\
    )


/* ===============================================================
    IPortWavePciStream Interface
*/
#undef INTERFACE
#define INTERFACE IPortWavePciStream

DEFINE_GUID(IID_IPortWavePciStream, 0xb4c90a51L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

DECLARE_INTERFACE_(IPortWavePciStream,IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()   //  For IUnknown

    STDMETHOD_(NTSTATUS,GetMapping)(THIS_
        IN PVOID Tag,
        OUT PPHYSICAL_ADDRESS PhysicalAddress,
        OUT PVOID * VirtualAddress,
        OUT PULONG ByteCount,
        OUT PULONG Flags)PURE;

    STDMETHOD_(NTSTATUS,ReleaseMapping)(THIS_
        IN PVOID Tag)PURE;

    STDMETHOD_(NTSTATUS,TerminatePacket)(THIS)PURE;
};

typedef IPortWavePciStream *PPORTWAVEPCISTREAM;

#define IMP_IPortWavePciStream                             \
    STDMETHODIMP_(NTSTATUS) GetMapping(                    \
        IN PVOID Tag,                                      \
        OUT PPHYSICAL_ADDRESS PhysicalAddress,             \
        OUT PVOID * VirtualAddress,                        \
        OUT PULONG ByteCount,                              \
        OUT PULONG Flags);                                 \
                                                           \
    STDMETHODIMP_(NTSTATUS) ReleaseMapping(                \
        IN PVOID Tag);                                     \
                                                           \
    STDMETHODIMP_(NTSTATUS) TerminatePacket(THIS)


/* ===============================================================
    IMiniportWavePciStream Interface
*/
#undef INTERFACE
#define INTERFACE IMiniportWavePciStream

DEFINE_GUID(IID_IMiniportWavePciStream, 0xb4c90a53L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

DECLARE_INTERFACE_(IMiniportWavePciStream,IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(NTSTATUS,SetFormat)(THIS_
        IN PKSDATAFORMAT DataFormat)PURE;

    STDMETHOD_(NTSTATUS,SetState)(THIS_
        IN KSSTATE State)PURE;

    STDMETHOD_(NTSTATUS,GetPosition)(THIS_
        OUT PULONGLONG Position)PURE;

    STDMETHOD_(NTSTATUS,NormalizePhysicalPosition)(THIS_
        IN OUT PLONGLONG PhysicalPosition)PURE;

    STDMETHOD_(NTSTATUS,GetAllocatorFraming)(THIS_
        OUT PKSALLOCATOR_FRAMING AllocatorFraming) PURE;

    STDMETHOD_(NTSTATUS,RevokeMappings)(THIS_
        IN PVOID FirstTag,
        IN PVOID LastTag,
        OUT PULONG MappingsRevoked)PURE;

    STDMETHOD_(void,MappingAvailable)(THIS)PURE;

    STDMETHOD_(void,Service)(THIS)PURE;
};

typedef IMiniportWavePciStream *PMINIPORTWAVEPCISTREAM;

/* ===============================================================
    IMiniportWavePci Interface
*/
#undef INTERFACE
#define INTERFACE IMiniportWavePci

DEFINE_GUID(IID_IMiniportWavePci, 0xb4c90a52L, 0x5791, 0x11d0, 0x86, 0xf9, 0x00, 0xa0, 0xc9, 0x11, 0xb5, 0x44);

DECLARE_INTERFACE_(IMiniportWavePci,IMiniport)
{
    DEFINE_ABSTRACT_UNKNOWN()

    DEFINE_ABSTRACT_MINIPORT()

    STDMETHOD_(NTSTATUS,Init)(THIS_
        IN PUNKNOWN UnknownAdapter,
        IN PRESOURCELIST ResourceList,
        IN PPORTWAVEPCI Port,
        OUT PSERVICEGROUP * ServiceGroup)PURE;

    STDMETHOD_(NTSTATUS,NewStream)(THIS_
        OUT PMINIPORTWAVEPCISTREAM *    Stream,
        IN PUNKNOWN OuterUnknown    OPTIONAL,
        IN POOL_TYPE PoolType,
        IN PPORTWAVEPCISTREAM PortStream,
        IN ULONG Pin,
        IN BOOLEAN Capture,
        IN PKSDATAFORMAT DataFormat,
        OUT PDMACHANNEL * DmaChannel,
        OUT PSERVICEGROUP * ServiceGroup)PURE;

    STDMETHOD_(void,Service)(THIS)PURE;
};

typedef IMiniportWavePci *PMINIPORTWAVEPCI;


#if !defined(DEFINE_ABSTRACT_MINIPORTWAVERTSTREAM)

#define DEFINE_ABSTRACT_MINIPORTWAVERTSTREAM()                 \
    STDMETHOD_(NTSTATUS,SetFormat)                             \
    (   THIS_                                                  \
        IN      PKSDATAFORMAT   DataFormat                   \
    )   PURE;                                                  \
    STDMETHOD_(NTSTATUS,SetState)                              \
    (   THIS_                                                  \
        IN      KSSTATE         State                        \
    )   PURE;                                                  \
    STDMETHOD_(NTSTATUS,GetPosition)                           \
    (   THIS_                                                  \
        OUT     PKSAUDIO_POSITION   Position                 \
    )   PURE;                                                  \
    STDMETHOD_(NTSTATUS,AllocateAudioBuffer)                   \
    (   THIS_                                                  \
        IN  ULONG                   RequestedSize,           \
        OUT PMDL                    *AudioBufferMdl,         \
        OUT ULONG                   *ActualSize,             \
        OUT ULONG                   *OffsetFromFirstPage,    \
        OUT MEMORY_CACHING_TYPE     *CacheType               \
    ) PURE;                                                    \
    STDMETHOD_(VOID,FreeAudioBuffer)                           \
    (   THIS_                                                  \
        IN     PMDL                    AudioBufferMdl,          \
        IN     ULONG                   BufferSize               \
    ) PURE;                                                    \
    STDMETHOD_(VOID,GetHWLatency)                              \
    (   THIS_                                                  \
        OUT KSRTAUDIO_HWLATENCY     *hwLatency               \
    ) PURE;                                                    \
    STDMETHOD_(NTSTATUS,GetPositionRegister)                   \
    (   THIS_                                                  \
        OUT KSRTAUDIO_HWREGISTER    *Register                \
    ) PURE;                                                    \
    STDMETHOD_(NTSTATUS,GetClockRegister)                      \
    (   THIS_                                                  \
        OUT KSRTAUDIO_HWREGISTER    *Register                \
    ) PURE;

#endif


/* ===============================================================
    IAdapterPowerManagement Interface
*/

#if (NTDDI_VERSION >= NTDDI_VISTA)
/* ===============================================================
    IPortWaveRT Interface
*/

DEFINE_GUID(CLSID_PortWaveRT, 0xcc9be57a, 0xeb9e, 0x42b4, 0x94, 0xfc, 0xc, 0xad, 0x3d, 0xbc, 0xe7, 0xfa);
DEFINE_GUID(IID_IPortWaveRT, 0x339ff909, 0x68a9, 0x4310, 0xb0, 0x9b, 0x27, 0x4e, 0x96, 0xee, 0x4c, 0xbd);

#undef INTERFACE
#define INTERFACE IPortWaveRT

DECLARE_INTERFACE_(IPortWaveRT,IPort)
{
    DEFINE_ABSTRACT_UNKNOWN()   //  For IUnknown

    DEFINE_ABSTRACT_PORT()      //  For IPort
};

typedef IPortWaveRT *PPORTWAVERT;

#ifdef PC_IMPLEMENTATION
#define IMP_IPortWaveRT IMP_IPort
#endif


/* ===============================================================
    IPortWaveRTStream Interface
*/

#undef INTERFACE
#define INTERFACE IPortWaveRTStream

DEFINE_GUID(IID_IPortWaveRTStream, 0x1809ce5a, 0x64bc, 0x4e62, 0xbd, 0x7d, 0x95, 0xbc, 0xe4, 0x3d, 0xe3, 0x93);

DECLARE_INTERFACE_(IPortWaveRTStream, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(PMDL, AllocatePagesForMdl)
    (   THIS_
        IN      PHYSICAL_ADDRESS    HighAddress,
        IN      SIZE_T              TotalBytes
    )   PURE;

    STDMETHOD_(PMDL, AllocateContiguousPagesForMdl)
    (   THIS_
        IN      PHYSICAL_ADDRESS    LowAddress,
        IN      PHYSICAL_ADDRESS    HighAddress,
        IN      SIZE_T              TotalBytes
    )   PURE;

    STDMETHOD_(PVOID, MapAllocatedPages)
    (   THIS_
        IN      PMDL                    MemoryDescriptorList,
        IN      MEMORY_CACHING_TYPE     CacheType
    )   PURE;

    STDMETHOD_(VOID, UnmapAllocatedPages)
    (   THIS_
        IN      PVOID   BaseAddress,
        IN      PMDL    MemoryDescriptorList
    )   PURE;

    STDMETHOD_(VOID, FreePagesFromMdl)
    (   THIS_
        IN      PMDL    MemoryDescriptorList
    )   PURE;

    STDMETHOD_(ULONG, GetPhysicalPagesCount)
    (   THIS_
        IN      PMDL    MemoryDescriptorList
    )   PURE;

    STDMETHOD_(PHYSICAL_ADDRESS, GetPhysicalPageAddress)
    (   THIS_
        IN      PMDL    MemoryDescriptorList,
        IN      ULONG   Index
    )   PURE;
};

typedef IPortWaveRTStream *PPORTWAVERTSTREAM;


/* ===============================================================
    IMiniportWaveRTStream Interface
*/

#undef INTERFACE
#define INTERFACE IMiniportWaveRTStream

DEFINE_GUID(IID_IMiniportWaveRTStream, 0xac9ab, 0xfaab, 0x4f3d, 0x94, 0x55, 0x6f, 0xf8, 0x30, 0x6a, 0x74, 0xa0);

DECLARE_INTERFACE_(IMiniportWaveRTStream, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_MINIPORTWAVERTSTREAM()
};

typedef IMiniportWaveRTStream *PMINIPORTWAVERTSTREAM;

#define IMP_IMiniportWaveRTStream\
    STDMETHODIMP_(NTSTATUS) SetFormat\
    (   IN      PKSDATAFORMAT   DataFormat\
    );\
    STDMETHODIMP_(NTSTATUS) SetState\
    (   IN      KSSTATE         State\
    );\
    STDMETHODIMP_(NTSTATUS) GetPosition\
    (   OUT     PKSAUDIO_POSITION   Position\
    );\
    STDMETHODIMP_(NTSTATUS) AllocateAudioBuffer\
    (\
        IN      ULONG                   RequestedSize,\
        OUT     PMDL                    *AudioBufferMdl,\
        OUT     ULONG                   *ActualSize,\
        OUT     ULONG                   *OffsetFromFirstPage,\
        OUT     MEMORY_CACHING_TYPE     *CacheType\
    );\
    STDMETHODIMP_(VOID) FreeAudioBuffer\
    (\
        IN  PMDL                    AudioBufferMdl,\
        IN  ULONG                   BufferSize\
    );\
    STDMETHODIMP_(VOID) GetHWLatency\
    (\
        OUT KSRTAUDIO_HWLATENCY     *hwLatency\
    );\
    STDMETHODIMP_(NTSTATUS) GetPositionRegister\
    (\
        OUT KSRTAUDIO_HWREGISTER    *Register\
    );\
    STDMETHODIMP_(NTSTATUS) GetClockRegister\
    (\
        OUT KSRTAUDIO_HWREGISTER    *Register\
    )


/* ===============================================================
    IMiniportWaveRTStreamNotification Interface
*/

#undef INTERFACE
#define INTERFACE IMiniportWaveRTStreamNotification

DEFINE_GUID(IID_IMiniportWaveRTStreamNotification, 0x23759128, 0x96f1, 0x423b, 0xab, 0x4d, 0x81, 0x63, 0x5b, 0xcf, 0x8c, 0xa1);

DECLARE_INTERFACE_(IMiniportWaveRTStreamNotification, IMiniportWaveRTStream)
{
    DEFINE_ABSTRACT_UNKNOWN()

    DEFINE_ABSTRACT_MINIPORTWAVERTSTREAM()

    STDMETHOD_(NTSTATUS,AllocateBufferWithNotification)
    (   THIS_
        IN      ULONG                   NotificationCount,
        IN      ULONG                   RequestedSize,
        OUT     PMDL                    *AudioBufferMdl,
        OUT     ULONG                   *ActualSize,
        OUT     ULONG                   *OffsetFromFirstPage,
        OUT     MEMORY_CACHING_TYPE     *CacheType
    )   PURE;

    STDMETHOD_(VOID,FreeBufferWithNotification)
    (   THIS_
        IN      PMDL            AudioBufferMdl,
        IN      ULONG           BufferSize
    )   PURE;

    STDMETHOD_(NTSTATUS,RegisterNotificationEvent)
    (   THIS_
        IN      PKEVENT         NotificationEvent
    )   PURE;

    STDMETHOD_(NTSTATUS,UnregisterNotificationEvent)
    (   THIS_
        IN      PKEVENT         NotificationEvent
    )   PURE;
};

/* ===============================================================
    IMiniportWaveRT Interface
*/

#undef INTERFACE
#define INTERFACE IMiniportWaveRT

DEFINE_GUID(IID_IMiniportWaveRT, 0xf9fc4d6, 0x6061, 0x4f3c, 0xb1, 0xfc, 0x7, 0x5e, 0x35, 0xf7, 0x96, 0xa);

DECLARE_INTERFACE_(IMiniportWaveRT, IMiniport)
{
    DEFINE_ABSTRACT_UNKNOWN()

    DEFINE_ABSTRACT_MINIPORT()

    STDMETHOD_(NTSTATUS,Init)
    (   THIS_
        IN      PUNKNOWN            UnknownAdapter,
        IN      PRESOURCELIST       ResourceList,
        IN      PPORTWAVERT             Port
    )   PURE;

    STDMETHOD_(NTSTATUS,NewStream)
    (   THIS_
        OUT     PMINIPORTWAVERTSTREAM *         Stream,
        IN      PPORTWAVERTSTREAM               PortStream,
        IN      ULONG                       Pin,
        IN      BOOLEAN                     Capture,
        IN      PKSDATAFORMAT               DataFormat
    )   PURE;

    STDMETHOD_(NTSTATUS,GetDeviceDescription)
    (   THIS_
        OUT     PDEVICE_DESCRIPTION     DeviceDescription
    )   PURE;
};

typedef IMiniportWaveRT *PMINIPORTWAVERT;

#define IMP_IMiniportWaveRT\
    IMP_IMiniport;\
    STDMETHODIMP_(NTSTATUS) Init\
    (   IN      PUNKNOWN            UnknownAdapter,\
        IN      PRESOURCELIST       ResourceList,\
        IN      PPORTWAVERT             Port\
    );\
    STDMETHODIMP_(NTSTATUS) NewStream\
    (   OUT     PMINIPORTWAVERTSTREAM *         Stream,\
        IN      PPORTWAVERTSTREAM               PortStream,\
        IN      ULONG                       Pin,\
        IN      BOOLEAN                     Capture,\
        IN      PKSDATAFORMAT               DataFormat\
    );\
    STDMETHODIMP_(NTSTATUS) GetDeviceDescription\
    (   OUT     PDEVICE_DESCRIPTION     DeviceDescription\
    )

#endif

/* ===============================================================
    IAdapterPowerManagement Interface
*/

#undef INTERFACE
#define INTERFACE IAdapterPowerManagement

DEFINE_GUID(IID_IAdapterPowerManagement, 0x793417D0L, 0x35FE, 0x11D1, 0xAD, 0x08, 0x00, 0xA0, 0xC9, 0x0A, 0xB1, 0xB0);

DECLARE_INTERFACE_(IAdapterPowerManagement, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(void,PowerChangeState)(THIS_
        IN POWER_STATE NewState) PURE;

    STDMETHOD_(NTSTATUS,QueryPowerChangeState)(THIS_
        IN POWER_STATE NewStateQuery) PURE;

    STDMETHOD_(NTSTATUS,QueryDeviceCapabilities)(THIS_
        IN PDEVICE_CAPABILITIES PowerDeviceCaps) PURE;
};

#define IMP_IAdapterPowerManagement                       \
    STDMETHODIMP_(void) PowerChangeState                  \
    (   IN      POWER_STATE     NewState                  \
    );                                                    \
    STDMETHODIMP_(NTSTATUS) QueryPowerChangeState         \
    (   IN      POWER_STATE     NewStateQuery             \
    );                                                    \
    STDMETHODIMP_(NTSTATUS) QueryDeviceCapabilities       \
    (   IN      PDEVICE_CAPABILITIES    PowerDeviceCaps   \
    )

typedef IAdapterPowerManagement *PADAPTERPOWERMANAGEMENT;


/* ===============================================================
    IPowerNotify Interface
*/

#undef INTERFACE
#define INTERFACE IPowerNotify

DEFINE_GUID(IID_IPowerNotify, 0x3DD648B8L, 0x969F, 0x11D1, 0x95, 0xA9, 0x00, 0xC0, 0x4F, 0xB9, 0x25, 0xD3);

DECLARE_INTERFACE_(IPowerNotify, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(void, PowerChangeNotify)(THIS_
        IN POWER_STATE PowerState)PURE;
};

typedef IPowerNotify *PPOWERNOTIFY;

#undef INTERFACE

/* ===============================================================
    IPinCount Interface
*/
#if (NTDDI_VERSION >= NTDDI_WINXP)

#undef INTERFACE
#define INTERFACE IPinCount

DEFINE_GUID(IID_IPinCount, 0x5dadb7dcL, 0xa2cb, 0x4540, 0xa4, 0xa8, 0x42, 0x5e, 0xe4, 0xae, 0x90, 0x51);

DECLARE_INTERFACE_(IPinCount, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(void,PinCount)(THIS_
        IN ULONG PinId,
        IN OUT PULONG FilterNecessary,
        IN OUT PULONG FilterCurrent,
        IN OUT PULONG FilterPossible,
        IN OUT PULONG GlobalCurrent,
        IN OUT PULONG GlobalPossible) PURE;
};
typedef IPinCount *PPINCOUNT;

#undef INTERFACE
#endif


/* ===============================================================
    IPortEvents Interface
*/

#undef INTERFACE
#define INTERFACE IPortEvents

DEFINE_GUID(IID_IPortEvents, 0xA80F29C4L, 0x5498, 0x11D2, 0x95, 0xD9, 0x00, 0xC0, 0x4F, 0xB9, 0x25, 0xD3);
DECLARE_INTERFACE_(IPortEvents, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(void,AddEventToEventList)(THIS_
        IN  PKSEVENT_ENTRY EventEntry)PURE;

    STDMETHOD_(void,GenerateEventList)(THIS_
        IN  GUID* Set OPTIONAL,
        IN  ULONG EventId,
        IN  BOOL  PinEvent,
        IN  ULONG PinId,
        IN  BOOL  NodeEvent,
        IN  ULONG NodeId)PURE;
};

typedef IPortEvents *PPORTEVENTS;


#define IMP_IPortEvents                        \
    STDMETHODIMP_(void) AddEventToEventList(   \
        IN  PKSEVENT_ENTRY EventEntry);        \
                                               \
    STDMETHODIMP_(void) GenerateEventList(     \
        IN  GUID* Set OPTIONAL,                \
        IN  ULONG EventId,                     \
        IN  BOOL  PinEvent,                    \
        IN  ULONG PinId,                       \
        IN  BOOL  NodeEvent,                   \
        IN  ULONG NodeId)

/* ===============================================================
    IDrmPort / IDrmPort2 Interfaces
    These are almost identical, except for the addition of two extra methods.
*/

#undef INTERFACE
#define INTERFACE IDrmPort

#if (NTDDI_VERSION >= NTDDI_WINXP)
DEFINE_GUID(IID_IDrmPort, 0x286D3DF8L, 0xCA22, 0x4E2E, 0xB9, 0xBC, 0x20, 0xB4, 0xF0, 0xE2, 0x01, 0xCE);
#endif

#define DEFINE_ABSTRACT_DRMPORT()                          \
    STDMETHOD_(NTSTATUS,CreateContentMixed)(THIS_          \
        IN  PULONG paContentId,                            \
        IN  ULONG cContentId,                              \
        OUT PULONG pMixedContentId)PURE;                   \
                                                           \
    STDMETHOD_(NTSTATUS,DestroyContent)(THIS_              \
        IN ULONG ContentId)PURE;                           \
                                                           \
    STDMETHOD_(NTSTATUS,ForwardContentToFileObject)(THIS_  \
        IN ULONG        ContentId,                         \
        IN PFILE_OBJECT FileObject)PURE;                   \
                                                           \
    STDMETHOD_(NTSTATUS,ForwardContentToInterface)(THIS_   \
        IN ULONG ContentId,                                \
        IN PUNKNOWN pUnknown,                              \
        IN ULONG NumMethods)PURE;                          \
                                                           \
    STDMETHOD_(NTSTATUS,GetContentRights)(THIS_            \
        IN  ULONG ContentId,                               \
        OUT PDRMRIGHTS  DrmRights)PURE;

DECLARE_INTERFACE_(IDrmPort, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_DRMPORT()
};

typedef IDrmPort *PDRMPORT;

#define IMP_IDrmPort                                       \
    STDMETHODIMP_(NTSTATUS) CreateContentMixed(            \
        IN  PULONG paContentId,                            \
        IN  ULONG cContentId,                              \
        OUT PULONG pMixedContentId);                       \
                                                           \
    STDMETHODIMP_(NTSTATUS) DestroyContent(                \
        IN ULONG ContentId);                               \
                                                           \
    STDMETHODIMP_(NTSTATUS) ForwardContentToFileObject(    \
        IN ULONG        ContentId,                         \
        IN PFILE_OBJECT FileObject);                       \
                                                           \
    STDMETHODIMP_(NTSTATUS) ForwardContentToInterface(     \
        IN ULONG ContentId,                                \
        IN PUNKNOWN pUnknown,                              \
        IN ULONG NumMethods);                              \
                                                           \
    STDMETHODIMP_(NTSTATUS) GetContentRights(              \
        IN  ULONG ContentId,                               \
        OUT PDRMRIGHTS  DrmRights)


/* ===============================================================
    IDrmPort2 Interface
*/

#undef INTERFACE
#define INTERFACE IDrmPort2

#if (NTDDI_VERSION >= NTDDI_WINXP)
DEFINE_GUID(IID_IDrmPort2, 0x1ACCE59CL, 0x7311, 0x4B6B, 0x9F, 0xBA, 0xCC, 0x3B, 0xA5, 0x9A, 0xCD, 0xCE);
#endif

DECLARE_INTERFACE_(IDrmPort2, IDrmPort)
{
    DEFINE_ABSTRACT_UNKNOWN()
    DEFINE_ABSTRACT_DRMPORT()

    STDMETHOD_(NTSTATUS,AddContentHandlers)(THIS_
        IN ULONG ContentId,
        IN PVOID * paHandlers,
        IN ULONG NumHandlers)PURE;

    STDMETHOD_(NTSTATUS,ForwardContentToDeviceObject)(THIS_
        IN ULONG ContentId,
        IN PVOID Reserved,
        IN PCDRMFORWARD DrmForward)PURE;
};

typedef IDrmPort2 *PDRMPORT2;

#define IMP_IDrmPort2                                                \
    IMP_IDrmPort;                                                    \
    STDMETHODIMP_(NTSTATUS) AddContentHandlers(                      \
        IN ULONG ContentId,                                          \
        IN PVOID * paHandlers,                                       \
        IN ULONG NumHandlers);                                       \
                                                                     \
    STDMETHODIMP_(NTSTATUS) ForwardContentToDeviceObject(            \
        IN ULONG ContentId,                                          \
        IN PVOID Reserved,                                           \
        IN PCDRMFORWARD DrmForward)


/* ===============================================================
    IPortClsVersion Interface
*/
#undef INTERFACE
#define INTERFACE IPortClsVersion

#if (NTDDI_VERSION >= NTDDI_WINXP)
DEFINE_GUID(IID_IPortClsVersion, 0x7D89A7BBL, 0x869B, 0x4567, 0x8D, 0xBE, 0x1E, 0x16, 0x8C, 0xC8, 0x53, 0xDE);
#endif

DECLARE_INTERFACE_(IPortClsVersion, IUnknown)
{
    DEFINE_ABSTRACT_UNKNOWN()

    STDMETHOD_(DWORD, GetVersion)(THIS) PURE;
};

#define IMP_IPortClsVersion \
    STDMETHODIMP_(DWORD) GetVersion(void);

typedef IPortClsVersion *PPORTCLSVERSION;

#undef INTERFACE

/* ===============================================================
    IDmaOperations Interface
*/

/* ===============================================================
    IPreFetchOffset Interface
*/



/* ===============================================================
    PortCls API Functions
*/

typedef NTSTATUS (NTAPI *PCPFNSTARTDEVICE)(
    IN  PDEVICE_OBJECT DeviceObject,
    IN  PIRP Irp,
    IN  PRESOURCELIST ResourceList);

/* This is in NTDDK.H */
/*
typedef NTSTATUS (*PDRIVER_ADD_DEVICE)(
    IN struct _DRIVER_OBJECT* DriverObject,
    IN struct _DEVICE_OBJECT* PhysicalDeviceObject);
*/

PORTCLASSAPI NTSTATUS NTAPI
PcAddAdapterDevice(
    IN  PDRIVER_OBJECT DriverObject,
    IN  PDEVICE_OBJECT PhysicalDeviceObject,
    IN  PCPFNSTARTDEVICE StartDevice,
    IN  ULONG MaxObjects,
    IN  ULONG DeviceExtensionSize);

PORTCLASSAPI NTSTATUS NTAPI
PcInitializeAdapterDriver(
    IN  PDRIVER_OBJECT DriverObject,
    IN  PUNICODE_STRING RegistryPathName,
    IN  PDRIVER_ADD_DEVICE AddDevice);


/* ===============================================================
    Factories (TODO: Move elsewhere)
*/

PORTCLASSAPI NTSTATUS NTAPI
PcNewDmaChannel(
    OUT PDMACHANNEL* OutDmaChannel,
    IN  PUNKNOWN OuterUnknown OPTIONAL,
    IN  POOL_TYPE PoolType,
    IN  PDEVICE_DESCRIPTION DeviceDescription,
    IN  PDEVICE_OBJECT DeviceObject);

PORTCLASSAPI NTSTATUS NTAPI
PcNewInterruptSync(
    OUT PINTERRUPTSYNC* OUtInterruptSync,
    IN  PUNKNOWN OuterUnknown OPTIONAL,
    IN  PRESOURCELIST ResourceList,
    IN  ULONG ResourceIndex,
    IN  INTERRUPTSYNCMODE Mode);

PORTCLASSAPI NTSTATUS NTAPI
PcNewMiniport(
    OUT PMINIPORT* OutMiniport,
    IN  REFCLSID ClassId);

PORTCLASSAPI NTSTATUS NTAPI
PcNewPort(
    OUT PPORT* OutPort,
    IN  REFCLSID ClassId);

PORTCLASSAPI NTSTATUS NTAPI
PcNewRegistryKey(
    OUT PREGISTRYKEY* OutRegistryKey,
    IN  PUNKNOWN OuterUnknown OPTIONAL,
    IN  ULONG RegistryKeyType,
    IN  ACCESS_MASK DesiredAccess,
    IN  PVOID DeviceObject OPTIONAL,
    IN  PVOID SubDevice OPTIONAL,
    IN  POBJECT_ATTRIBUTES ObjectAttributes OPTIONAL,
    IN  ULONG CreateOptions OPTIONAL,
    OUT PULONG Disposition OPTIONAL);

PORTCLASSAPI NTSTATUS NTAPI
PcNewResourceList(
    OUT PRESOURCELIST* OutResourceList,
    IN  PUNKNOWN OuterUnknown OPTIONAL,
    IN  POOL_TYPE PoolType,
    IN  PCM_RESOURCE_LIST TranslatedResources,
    IN  PCM_RESOURCE_LIST UntranslatedResources);

PORTCLASSAPI NTSTATUS NTAPI
PcNewResourceSublist(
    OUT PRESOURCELIST* OutResourceList,
    IN  PUNKNOWN OuterUnknown OPTIONAL,
    IN  POOL_TYPE PoolType,
    IN  PRESOURCELIST ParentList,
    IN  ULONG MaximumEntries);

PORTCLASSAPI NTSTATUS NTAPI
PcNewServiceGroup(
    OUT PSERVICEGROUP* OutServiceGroup,
    IN  PUNKNOWN OuterUnknown OPTIONAL);


/* ===============================================================
    IRP Handling
*/

PORTCLASSAPI NTSTATUS NTAPI
PcDispatchIrp(
    IN  PDEVICE_OBJECT DeviceObject,
    IN  PIRP Irp);

PORTCLASSAPI NTSTATUS NTAPI
PcCompleteIrp(
    IN  PDEVICE_OBJECT DeviceObject,
    IN  PIRP Irp,
    IN  NTSTATUS Status);

PORTCLASSAPI NTSTATUS NTAPI
PcForwardIrpSynchronous(
    IN  PDEVICE_OBJECT DeviceObject,
    IN  PIRP Irp);


/* ===============================================================
    Power Management
*/

PORTCLASSAPI NTSTATUS NTAPI
PcRegisterAdapterPowerManagement(
    IN  PUNKNOWN pUnknown,
    IN  PVOID pvContext1);

PORTCLASSAPI NTSTATUS NTAPI
PcRequestNewPowerState(
    IN  PDEVICE_OBJECT pDeviceObject,
    IN  DEVICE_POWER_STATE RequestedNewState);


/* ===============================================================
    Properties
*/

PORTCLASSAPI NTSTATUS NTAPI
PcGetDeviceProperty(
    IN  PVOID DeviceObject,
    IN  DEVICE_REGISTRY_PROPERTY DeviceProperty,
    IN  ULONG BufferLength,
    OUT PVOID PropertyBuffer,
    OUT PULONG ResultLength);

PORTCLASSAPI NTSTATUS NTAPI
PcCompletePendingPropertyRequest(
    IN  PPCPROPERTY_REQUEST PropertyRequest,
    IN  NTSTATUS NtStatus);


/* ===============================================================
    I/O Timeouts
*/

PORTCLASSAPI NTSTATUS NTAPI
PcRegisterIoTimeout(
    IN  PDEVICE_OBJECT pDeviceObject,
    IN  PIO_TIMER_ROUTINE pTimerRoutine,
    IN  PVOID pContext);

PORTCLASSAPI NTSTATUS NTAPI
PcUnregisterIoTimeout(
    IN  PDEVICE_OBJECT pDeviceObject,
    IN  PIO_TIMER_ROUTINE pTimerRoutine,
    IN  PVOID pContext);


/* ===============================================================
    Physical Connections
*/

PORTCLASSAPI NTSTATUS NTAPI
PcRegisterPhysicalConnection(
    IN  PDEVICE_OBJECT DeviceObject,
    IN  PUNKNOWN FromUnknown,
    IN  ULONG FromPin,
    IN  PUNKNOWN ToUnknown,
    IN  ULONG ToPin);

PORTCLASSAPI NTSTATUS NTAPI
PcRegisterPhysicalConnectionFromExternal(
    IN  PDEVICE_OBJECT DeviceObject,
    IN  PUNICODE_STRING FromString,
    IN  ULONG FromPin,
    IN  PUNKNOWN ToUnknown,
    IN  ULONG ToPin);

PORTCLASSAPI NTSTATUS NTAPI
PcRegisterPhysicalConnectionToExternal(
    IN  PDEVICE_OBJECT DeviceObject,
    IN  PUNKNOWN FromUnknown,
    IN  ULONG FromPin,
    IN  PUNICODE_STRING ToString,
    IN  ULONG ToPin);


/* ===============================================================
    Misc
*/

PORTCLASSAPI ULONGLONG NTAPI
PcGetTimeInterval(
    IN  ULONGLONG Since);

PORTCLASSAPI NTSTATUS NTAPI
PcRegisterSubdevice(
    IN  PDEVICE_OBJECT DeviceObject,
    IN  PWCHAR Name,
    IN  PUNKNOWN Unknown);


/* ===============================================================
    Digital Rights Management Functions
    Implemented in XP and above
*/

PORTCLASSAPI NTSTATUS NTAPI
PcAddContentHandlers(
    IN  ULONG ContentId,
    IN  PVOID *paHandlers,
    IN  ULONG NumHandlers);

PORTCLASSAPI NTSTATUS NTAPI
PcCreateContentMixed(
    IN  PULONG paContentId,
    IN  ULONG cContentId,
    OUT PULONG pMixedContentId);

PORTCLASSAPI NTSTATUS NTAPI
PcDestroyContent(
    IN  ULONG ContentId);

PORTCLASSAPI NTSTATUS NTAPI
PcForwardContentToDeviceObject(
    IN  ULONG ContentId,
    IN  PVOID Reserved,
    IN  PCDRMFORWARD DrmForward);

PORTCLASSAPI NTSTATUS NTAPI
PcForwardContentToFileObject(
    IN  ULONG ContentId,
    IN  PFILE_OBJECT FileObject);

PORTCLASSAPI NTSTATUS NTAPI
PcForwardContentToInterface(
    IN  ULONG ContentId,
    IN  PUNKNOWN pUnknown,
    IN  ULONG NumMethods);

PORTCLASSAPI NTSTATUS NTAPI
PcGetContentRights(
    IN  ULONG ContentId,
    OUT PDRMRIGHTS DrmRights);


#endif /* PORTCLS_H */

