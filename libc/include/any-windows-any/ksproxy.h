/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __KSPROXY__
#define __KSPROXY__

#ifdef __cplusplus
extern "C" {
#endif

#undef KSDDKAPI
#ifdef _KSDDK_
#define KSDDKAPI
#else
#define KSDDKAPI DECLSPEC_IMPORT
#endif

#define STATIC_IID_IKsObject						\
	0x423c13a2,0x2070,0x11d0,0x9e,0xf7,0x00,0xaa,0x00,0xa2,0x16,0xa1

#define STATIC_IID_IKsPinEx						\
	0x7bb38260,0xd19c,0x11d2,0xb3,0x8a,0x00,0xa0,0xc9,0x5e,0xc2,0x2e

#define STATIC_IID_IKsPin						\
	0xb61178d1,0xa2d9,0x11cf,0x9e,0x53,0x00,0xaa,0x00,0xa2,0x16,0xa1

#define STATIC_IID_IKsPinPipe						\
	0xe539cd90,0xa8b4,0x11d1,0x81,0x89,0x00,0xa0,0xc9,0x06,0x28,0x02

#define STATIC_IID_IKsDataTypeHandler					\
	0x5ffbaa02,0x49a3,0x11d0,0x9f,0x36,0x00,0xaa,0x00,0xa2,0x16,0xa1

#define STATIC_IID_IKsDataTypeCompletion				\
	0x827D1A0E,0x0F73,0x11D2,0xB2,0x7A,0x00,0xA0,0xC9,0x22,0x31,0x96

#define STATIC_IID_IKsInterfaceHandler					\
	0xD3ABC7E0,0x9A61,0x11D0,0xA4,0x0D,0x00,0xA0,0xC9,0x22,0x31,0x96

#define STATIC_IID_IKsClockPropertySet					\
	0x5C5CBD84,0xE755,0x11D0,0xAC,0x18,0x00,0xA0,0xC9,0x22,0x31,0x96

#define STATIC_IID_IKsAllocator						\
	0x8da64899,0xc0d9,0x11d0,0x84,0x13,0x00,0x00,0xf8,0x22,0xfe,0x8a

#define STATIC_IID_IKsAllocatorEx					\
	0x091bb63a,0x603f,0x11d1,0xb0,0x67,0x00,0xa0,0xc9,0x06,0x28,0x02

#ifndef STATIC_IID_IKsPropertySet
#define STATIC_IID_IKsPropertySet					\
	0x31EFAC30,0x515C,0x11d0,0xA9,0xAA,0x00,0xAA,0x00,0x61,0xBE,0x93
#endif

#define STATIC_IID_IKsTopology						\
	0x28F54683,0x06FD,0x11D2,0xB2,0x7A,0x00,0xA0,0xC9,0x22,0x31,0x96

#ifndef STATIC_IID_IKsControl
#define STATIC_IID_IKsControl						\
	0x28F54685,0x06FD,0x11D2,0xB2,0x7A,0x00,0xA0,0xC9,0x22,0x31,0x96
#endif

#define STATIC_IID_IKsAggregateControl					\
	0x7F40EAC0,0x3947,0x11D2,0x87,0x4E,0x00,0xA0,0xC9,0x22,0x31,0x96

#define STATIC_CLSID_Proxy						\
	0x17CCA71B,0xECD7,0x11D0,0xB9,0x08,0x00,0xA0,0xC9,0x22,0x31,0x96

#ifdef _KS_

DEFINE_GUIDEX(IID_IKsObject);

DEFINE_GUIDEX(IID_IKsPin);

DEFINE_GUIDEX(IID_IKsPinEx);

DEFINE_GUIDEX(IID_IKsPinPipe);

DEFINE_GUIDEX(IID_IKsDataTypeHandler);

DEFINE_GUIDEX(IID_IKsDataTypeCompletion);

DEFINE_GUIDEX(IID_IKsInterfaceHandler);

DEFINE_GUIDEX(IID_IKsClockPropertySet);

DEFINE_GUIDEX(IID_IKsAllocator);

DEFINE_GUIDEX(IID_IKsAllocatorEx);

#define IID_IKsQualityForwarder KSCATEGORY_QUALITY
#define STATIC_IID_IKsQualityForwarder STATIC_KSCATEGORY_QUALITY

typedef enum {
  KsAllocatorMode_User,
  KsAllocatorMode_Kernel
} KSALLOCATORMODE;

typedef enum {
  FramingProp_Uninitialized,
  FramingProp_None,
  FramingProp_Old,
  FramingProp_Ex
} FRAMING_PROP;

typedef FRAMING_PROP *PFRAMING_PROP;

typedef enum {
  Framing_Cache_Update,
  Framing_Cache_ReadLast,
  Framing_Cache_ReadOrig,
  Framing_Cache_Write
} FRAMING_CACHE_OPS;

typedef struct {
  LONGLONG MinTotalNominator;
  LONGLONG MaxTotalNominator;
  LONGLONG TotalDenominator;
} OPTIMAL_WEIGHT_TOTALS;

typedef struct IPin IPin;
typedef struct IKsPin IKsPin;
typedef struct IKsAllocator IKsAllocator;
typedef struct IKsAllocatorEx IKsAllocatorEx;

#define AllocatorStrategy_DontCare			0
#define AllocatorStrategy_MinimizeNumberOfFrames	0x00000001
#define AllocatorStrategy_MinimizeFrameSize		0x00000002
#define AllocatorStrategy_MinimizeNumberOfAllocators	0x00000004
#define AllocatorStrategy_MaximizeSpeed			0x00000008

#define PipeFactor_None					0
#define PipeFactor_UserModeUpstream			0x00000001
#define PipeFactor_UserModeDownstream			0x00000002
#define PipeFactor_MemoryTypes				0x00000004
#define PipeFactor_Flags				0x00000008
#define PipeFactor_PhysicalRanges			0x00000010
#define PipeFactor_OptimalRanges			0x00000020
#define PipeFactor_FixedCompression			0x00000040
#define PipeFactor_UnknownCompression			0x00000080

#define PipeFactor_Buffers				0x00000100
#define PipeFactor_Align				0x00000200
#define PipeFactor_PhysicalEnd				0x00000400
#define PipeFactor_LogicalEnd				0x00000800

typedef enum {
  PipeState_DontCare,
  PipeState_RangeNotFixed,
  PipeState_RangeFixed,
  PipeState_CompressionUnknown,
  PipeState_Finalized
} PIPE_STATE;

typedef struct _PIPE_DIMENSIONS {
  KS_COMPRESSION AllocatorPin;
  KS_COMPRESSION MaxExpansionPin;
  KS_COMPRESSION EndPin;
} PIPE_DIMENSIONS,*PPIPE_DIMENSIONS;

typedef enum {
  Pipe_Allocator_None,
  Pipe_Allocator_FirstPin,
  Pipe_Allocator_LastPin,
  Pipe_Allocator_MiddlePin
} PIPE_ALLOCATOR_PLACE;

typedef PIPE_ALLOCATOR_PLACE *PPIPE_ALLOCATOR_PLACE;

typedef enum {
  KS_MemoryTypeDontCare = 0,
  KS_MemoryTypeKernelPaged,
  KS_MemoryTypeKernelNonPaged,
  KS_MemoryTypeDeviceHostMapped,
  KS_MemoryTypeDeviceSpecific,
  KS_MemoryTypeUser,
  KS_MemoryTypeAnyHost
} KS_LogicalMemoryType;

typedef KS_LogicalMemoryType *PKS_LogicalMemoryType;

typedef struct _PIPE_TERMINATION {
  ULONG Flags;
  ULONG OutsideFactors;
  ULONG Weigth;
  KS_FRAMING_RANGE PhysicalRange;
  KS_FRAMING_RANGE_WEIGHTED OptimalRange;
  KS_COMPRESSION Compression;
} PIPE_TERMINATION;

typedef struct _ALLOCATOR_PROPERTIES_EX
{
  __LONG32 cBuffers;
  __LONG32 cbBuffer;
  __LONG32 cbAlign;
  __LONG32 cbPrefix;

  GUID MemoryType;
  GUID BusType;
  PIPE_STATE State;
  PIPE_TERMINATION Input;
  PIPE_TERMINATION Output;
  ULONG Strategy;
  ULONG Flags;
  ULONG Weight;
  KS_LogicalMemoryType LogicalMemoryType;
  PIPE_ALLOCATOR_PLACE AllocatorPlace;
  PIPE_DIMENSIONS Dimensions;
  KS_FRAMING_RANGE PhysicalRange;
  IKsAllocatorEx *PrevSegment;
  ULONG CountNextSegments;
  IKsAllocatorEx **NextSegments;
  ULONG InsideFactors;
  ULONG NumberPins;
} ALLOCATOR_PROPERTIES_EX;

typedef ALLOCATOR_PROPERTIES_EX *PALLOCATOR_PROPERTIES_EX;

#ifdef __STREAMS__

struct IKsClockPropertySet;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsClockPropertySet,0x5c5cbd84,0xe755,0x11d0,0xac,0x18,0x00,0xa0,0xc9,0x22,0x31,0x96);
#endif

#undef INTERFACE
#define INTERFACE IKsClockPropertySet
DECLARE_INTERFACE_(IKsClockPropertySet,IUnknown)
{
  STDMETHOD(KsGetTime)			(THIS_
						LONGLONG *Time
					) PURE;
  STDMETHOD(KsSetTime)			(THIS_
						LONGLONG Time
					) PURE;
  STDMETHOD(KsGetPhysicalTime)		(THIS_
						LONGLONG *Time
					) PURE;
  STDMETHOD(KsSetPhysicalTime)		(THIS_
						LONGLONG Time
					) PURE;
  STDMETHOD(KsGetCorrelatedTime)	(THIS_
						KSCORRELATED_TIME *CorrelatedTime
					) PURE;
  STDMETHOD(KsSetCorrelatedTime)	(THIS_
						KSCORRELATED_TIME *CorrelatedTime
					) PURE;
  STDMETHOD(KsGetCorrelatedPhysicalTime)(THIS_
						KSCORRELATED_TIME *CorrelatedTime
					) PURE;
  STDMETHOD(KsSetCorrelatedPhysicalTime)(THIS_
						KSCORRELATED_TIME *CorrelatedTime
					) PURE;
  STDMETHOD(KsGetResolution)		(THIS_
						KSRESOLUTION *Resolution
					) PURE;
  STDMETHOD(KsGetState)			(THIS_
						KSSTATE *State
					) PURE;
};

struct IKsAllocator;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsAllocator,0x8da64899,0xc0d9,0x11d0,0x84,0x13,0x00,0x00,0xf8,0x22,0xfe,0x8a);
#endif

#undef INTERFACE
#define INTERFACE IKsAllocator
DECLARE_INTERFACE_(IKsAllocator,IUnknown)
{
  STDMETHOD_(HANDLE,KsGetAllocatorHandle)(THIS) PURE;
  STDMETHOD_(KSALLOCATORMODE,KsGetAllocatorMode)(THIS) PURE;
  STDMETHOD(KsGetAllocatorStatus)	(THIS_
						PKSSTREAMALLOCATOR_STATUS AllocatorStatus
					) PURE;
  STDMETHOD_(VOID,KsSetAllocatorMode)	(THIS_
						KSALLOCATORMODE Mode
					) PURE;
};

struct IKsAllocatorEx;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsAllocatorEx,0x091bb63a,0x603f,0x11d1,0xb0,0x67,0x00,0xa0,0xc9,0x06,0x28,0x02);
#endif

#undef INTERFACE
#define INTERFACE IKsAllocatorEx
DECLARE_INTERFACE_(IKsAllocatorEx,IKsAllocator)
{
  STDMETHOD_(PALLOCATOR_PROPERTIES_EX,KsGetProperties)(THIS) PURE;
  STDMETHOD_(VOID,KsSetProperties)	(THIS_
						PALLOCATOR_PROPERTIES_EX
					) PURE;
  STDMETHOD_(VOID,KsSetAllocatorHandle)	(THIS_
						HANDLE AllocatorHandle
					) PURE;
  STDMETHOD_(HANDLE,KsCreateAllocatorAndGetHandle)(THIS_
						IKsPin *KsPin
					) PURE;
};

typedef enum {
  KsPeekOperation_PeekOnly,
  KsPeekOperation_AddRef
} KSPEEKOPERATION;

typedef struct _KSSTREAM_SEGMENT *PKSSTREAM_SEGMENT;
struct IKsPin;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsPin,0xb61178d1,0xa2d9,0x11cf,0x9e,0x53,0x00,0xaa,0x00,0xa2,0x16,0xa1);
#endif

#undef INTERFACE
#define INTERFACE IKsPin
DECLARE_INTERFACE_(IKsPin,IUnknown)
{
  STDMETHOD(KsQueryMediums)		(THIS_
						PKSMULTIPLE_ITEM *MediumList
					) PURE;
  STDMETHOD(KsQueryInterfaces)		(THIS_
						PKSMULTIPLE_ITEM *InterfaceList
					) PURE;
  STDMETHOD(KsCreateSinkPinHandle)	(THIS_
						KSPIN_INTERFACE& Interface,
						KSPIN_MEDIUM& Medium
					) PURE;
  STDMETHOD(KsGetCurrentCommunication)	(THIS_
						KSPIN_COMMUNICATION *Communication,
						KSPIN_INTERFACE *Interface,
						KSPIN_MEDIUM *Medium
					) PURE;
  STDMETHOD(KsPropagateAcquire)		(THIS) PURE;
  STDMETHOD(KsDeliver)			(THIS_
						IMediaSample *Sample,
						ULONG Flags
					) PURE;
  STDMETHOD(KsMediaSamplesCompleted)	(THIS_
						PKSSTREAM_SEGMENT StreamSegment
					) PURE;
  STDMETHOD_(IMemAllocator *,KsPeekAllocator)(THIS_
						KSPEEKOPERATION Operation
					) PURE;
  STDMETHOD(KsReceiveAllocator)		(THIS_
						IMemAllocator *MemAllocator
					) PURE;
  STDMETHOD(KsRenegotiateAllocator)	(THIS) PURE;
  STDMETHOD_(LONG,KsIncrementPendingIoCount)(THIS) PURE;
  STDMETHOD_(LONG,KsDecrementPendingIoCount)(THIS) PURE;
  STDMETHOD(KsQualityNotify)		(THIS_
						ULONG Proportion,
						REFERENCE_TIME TimeDelta
					) PURE;
};

struct IKsPinEx;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsPinEx,0x7bb38260,0xd19c,0x11d2,0xb3,0x8a,0x00,0xa0,0xc9,0x5e,0xc2,0x2e);
#endif

#undef INTERFACE
#define INTERFACE IKsPinEx
DECLARE_INTERFACE_(IKsPinEx,IKsPin)
{
  STDMETHOD_(VOID,KsNotifyError)	(THIS_
						IMediaSample *Sample,
						HRESULT hr
					) PURE;
};

struct IKsPinPipe;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsPinPipe,0xe539cd90,0xa8b4,0x11d1,0x81,0x89,0x00,0xa0,0xc9,0x06,0x28,0x02);
#endif

#undef INTERFACE
#define INTERFACE IKsPinPipe
DECLARE_INTERFACE_(IKsPinPipe,IUnknown)
{
  STDMETHOD(KsGetPinFramingCache)	(THIS_
						PKSALLOCATOR_FRAMING_EX *FramingEx,
						PFRAMING_PROP FramingProp,
						FRAMING_CACHE_OPS Option
					) PURE;
  STDMETHOD(KsSetPinFramingCache)	(THIS_
						PKSALLOCATOR_FRAMING_EX FramingEx,
						PFRAMING_PROP FramingProp,
						FRAMING_CACHE_OPS Option
					) PURE;
  STDMETHOD_(IPin*,KsGetConnectedPin)	(THIS) PURE;
  STDMETHOD_(IKsAllocatorEx*,KsGetPipe)	(THIS_
						KSPEEKOPERATION Operation
					) PURE;
  STDMETHOD(KsSetPipe)			(THIS_
						IKsAllocatorEx *KsAllocator
					) PURE;
  STDMETHOD_(ULONG,KsGetPipeAllocatorFlag)(THIS) PURE;
  STDMETHOD(KsSetPipeAllocatorFlag)	(THIS_
						ULONG Flag
					) PURE;
  STDMETHOD_(GUID,KsGetPinBusCache)	(THIS) PURE;
  STDMETHOD(KsSetPinBusCache)		(THIS_
						GUID Bus
					) PURE;
  STDMETHOD_(PWCHAR,KsGetPinName)	(THIS) PURE;
  STDMETHOD_(PWCHAR,KsGetFilterName)	(THIS) PURE;
};

struct IKsPinFactory;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsPinFactory,0xcd5ebe6b,0x8b6e,0x11d1,0x8a,0xe0,0x00,0xa0,0xc9,0x22,0x31,0x96);
#endif

#undef INTERFACE
#define INTERFACE IKsPinFactory
DECLARE_INTERFACE_(IKsPinFactory,IUnknown)
{
  STDMETHOD(KsPinFactory)		(THIS_
						ULONG *PinFactory
					) PURE;
};

typedef enum {
  KsIoOperation_Write,
  KsIoOperation_Read
} KSIOOPERATION;

struct IKsDataTypeHandler;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsDataTypeHandler,0x5ffbaa02,0x49a3,0x11d0,0x9f,0x36,0x00,0xaa,0x00,0xa2,0x16,0xa1);
#endif

#undef INTERFACE
#define INTERFACE IKsDataTypeHandler
DECLARE_INTERFACE_(IKsDataTypeHandler,IUnknown)
{
  STDMETHOD(KsCompleteIoOperation)	(THIS_
						IMediaSample *Sample,
						PVOID StreamHeader,
						KSIOOPERATION IoOperation,
						WINBOOL Cancelled
					) PURE;
  STDMETHOD(KsIsMediaTypeInRanges)	(THIS_
						PVOID DataRanges
					) PURE;
  STDMETHOD(KsPrepareIoOperation)	(THIS_
						IMediaSample *Sample,
						PVOID StreamHeader,
						KSIOOPERATION IoOperation
					) PURE;
  STDMETHOD(KsQueryExtendedSize)	(THIS_
						ULONG *ExtendedSize
					) PURE;
  STDMETHOD(KsSetMediaType)		(THIS_
						const AM_MEDIA_TYPE *AmMediaType
					) PURE;
};

struct IKsDataTypeCompletion;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsDataTypeCompletion,0x827d1a0e,0x0f73,0x11d2,0xb2,0x7a,0x00,0xa0,0xc9,0x22,0x31,0x96);
#endif

#undef INTERFACE
#define INTERFACE IKsDataTypeCompletion
DECLARE_INTERFACE_(IKsDataTypeCompletion,IUnknown)
{
  STDMETHOD(KsCompleteMediaType)	(THIS_
						HANDLE FilterHandle,
						ULONG PinFactoryId,
						AM_MEDIA_TYPE *AmMediaType
					) PURE;
};

struct IKsInterfaceHandler;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsInterfaceHandler,0xd3abc7e0,0x9a61,0x11d0,0xa4,0x0d,0x00,0xa0,0xc9,0x22,0x31,0x96);
#endif

#undef INTERFACE
#define INTERFACE IKsInterfaceHandler
DECLARE_INTERFACE_(IKsInterfaceHandler,IUnknown)
{
  STDMETHOD(KsSetPin)			(THIS_
						IKsPin *KsPin
					) PURE;
  STDMETHOD(KsProcessMediaSamples)	(THIS_
						IKsDataTypeHandler *KsDataTypeHandler,
						IMediaSample **SampleList,
						PLONG SampleCount,
						KSIOOPERATION IoOperation,
						PKSSTREAM_SEGMENT *StreamSegment
					) PURE;
  STDMETHOD(KsCompleteIo)		(THIS_
						PKSSTREAM_SEGMENT StreamSegment
					) PURE;
};

typedef struct _KSSTREAM_SEGMENT {
  IKsInterfaceHandler *KsInterfaceHandler;
  IKsDataTypeHandler *KsDataTypeHandler;
  KSIOOPERATION IoOperation;
  HANDLE CompletionEvent;
} KSSTREAM_SEGMENT;

struct IKsObject;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsObject,0x423c13a2,0x2070,0x11d0,0x9e,0xf7,0x00,0xaa,0x00,0xa2,0x16,0xa1);
#endif

#undef INTERFACE
#define INTERFACE IKsObject
DECLARE_INTERFACE_(IKsObject,IUnknown)
{
  STDMETHOD_(HANDLE,KsGetObjectHandle)	(THIS) PURE;
};

struct IKsQualityForwarder;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsQualityForwarder,0x97ebaacb,0x95bd,0x11d0,0xa3,0xea,0x00,0xa0,0xc9,0x22,0x31,0x96);
#endif

#undef INTERFACE
#define INTERFACE IKsQualityForwarder
DECLARE_INTERFACE_(IKsQualityForwarder,IKsObject)
{
  STDMETHOD_(VOID,KsFlushClient)	(THIS_
						IKsPin *Pin
					) PURE;
};

struct IKsNotifyEvent;

#ifdef __CRT_UUID_DECL
__CRT_UUID_DECL(IKsNotifyEvent,0x412bd695,0xf84b,0x46c1,0xac,0x73,0x54,0x19,0x6d,0xbc,0x8f,0xa7);
#endif

#undef INTERFACE
#define INTERFACE IKsNotifyEvent
DECLARE_INTERFACE_(IKsNotifyEvent,IUnknown)
{
  STDMETHOD(KsNotifyEvent)		(THIS_
						ULONG Event,
						ULONG_PTR lParam1,
						ULONG_PTR lParam2
					) PURE;
};

KSDDKAPI HRESULT WINAPI KsResolveRequiredAttributes(PKSDATARANGE DataRange,PKSMULTIPLE_ITEM Attributes);
KSDDKAPI HRESULT WINAPI KsOpenDefaultDevice(REFGUID Category,ACCESS_MASK Access,PHANDLE DeviceHandle);
KSDDKAPI HRESULT WINAPI KsSynchronousDeviceControl(HANDLE Handle,ULONG IoControl,PVOID InBuffer,ULONG InLength,PVOID OutBuffer,ULONG OutLength,PULONG BytesReturned);
KSDDKAPI HRESULT WINAPI KsGetMultiplePinFactoryItems(HANDLE FilterHandle,ULONG PinFactoryId,ULONG PropertyId,PVOID *Items);
KSDDKAPI HRESULT WINAPI KsGetMediaTypeCount(HANDLE FilterHandle,ULONG PinFactoryId,ULONG *MediaTypeCount);
KSDDKAPI HRESULT WINAPI KsGetMediaType(int Position,AM_MEDIA_TYPE *AmMediaType,HANDLE FilterHandle,ULONG PinFactoryId);
#endif /* __STREAMS__ */

#ifndef _IKsPropertySet_
DEFINE_GUIDEX(IID_IKsPropertySet);
#endif

#ifndef _IKsControl_
DEFINE_GUIDEX(IID_IKsControl);
#endif

DEFINE_GUIDEX(IID_IKsAggregateControl);
#ifndef _IKsTopology_
DEFINE_GUIDEX(IID_IKsTopology);
#endif
DEFINE_GUIDSTRUCT("17CCA71B-ECD7-11D0-B908-00A0C9223196",CLSID_Proxy);
#define CLSID_Proxy DEFINE_GUIDNAMED(CLSID_Proxy)

#else /* _KS_ */

#ifndef _IKsPropertySet_
DEFINE_GUID(IID_IKsPropertySet,STATIC_IID_IKsPropertySet);
#endif

DEFINE_GUID(CLSID_Proxy,STATIC_CLSID_Proxy);

#endif /* _KS_ */

#ifndef _IKsPropertySet_
#define _IKsPropertySet_
#define KSPROPERTY_SUPPORT_GET 1
#define KSPROPERTY_SUPPORT_SET 2

#ifdef DECLARE_INTERFACE_
struct IKsPropertySet;
#undef INTERFACE
#define INTERFACE IKsPropertySet
DECLARE_INTERFACE_(IKsPropertySet,IUnknown)
{
  STDMETHOD(Set)			(THIS_
						REFGUID PropSet,
						ULONG Id,
						LPVOID InstanceData,
						ULONG InstanceLength,
						LPVOID PropertyData,
						ULONG DataLength
					) PURE;
  STDMETHOD(Get)			(THIS_
						REFGUID PropSet,
						ULONG Id,
						LPVOID InstanceData,
						ULONG InstanceLength,
						LPVOID PropertyData,
						ULONG DataLength,
						ULONG *BytesReturned
					) PURE;
  STDMETHOD(QuerySupported)		(THIS_
						REFGUID PropSet,
						ULONG Id,
						ULONG *TypeSupport
					) PURE;
};
#endif /* DECLARE_INTERFACE_ */
#endif /* _IKsPropertySet_ */

#ifndef _IKsControl_
#define _IKsControl_
#ifdef DECLARE_INTERFACE_
struct IKsControl;
#undef INTERFACE
#define INTERFACE IKsControl
DECLARE_INTERFACE_(IKsControl,IUnknown)
{
  STDMETHOD(KsProperty)			(THIS_
						PKSPROPERTY Property,
						ULONG PropertyLength,
						LPVOID PropertyData,
						ULONG DataLength,
						ULONG *BytesReturned
					) PURE;
  STDMETHOD(KsMethod)			(THIS_
						PKSMETHOD Method,
						ULONG MethodLength,
						LPVOID MethodData,
						ULONG DataLength,
						ULONG *BytesReturned
					) PURE;
  STDMETHOD(KsEvent)			(THIS_
						PKSEVENT Event,
						ULONG EventLength,
						LPVOID EventData,
						ULONG DataLength,
						ULONG *BytesReturned
					) PURE;
};
#endif /* DECLARE_INTERFACE_ */
#endif /* _IKsControl_ */

#ifdef DECLARE_INTERFACE_
struct IKsAggregateControl;
#undef INTERFACE
#define INTERFACE IKsAggregateControl
DECLARE_INTERFACE_(IKsAggregateControl,IUnknown)
{
  STDMETHOD(KsAddAggregate)		(THIS_
						REFGUID AggregateClass
					) PURE;
  STDMETHOD(KsRemoveAggregate)		(THIS_
						REFGUID AggregateClass
					) PURE;
};
#endif /* DECLARE_INTERFACE_ */

#ifndef _IKsTopology_
#define _IKsTopology_
#ifdef DECLARE_INTERFACE_
struct IKsTopology;
#undef INTERFACE
#define INTERFACE IKsTopology
DECLARE_INTERFACE_(IKsTopology,IUnknown)
{
  STDMETHOD(CreateNodeInstance)		(THIS_
						ULONG NodeId,
						ULONG Flags,
						ACCESS_MASK DesiredAccess,
						IUnknown *UnkOuter,
						REFGUID InterfaceId,
						LPVOID *Interface
					) PURE;
};
#endif /* DECLARE_INTERFACE_ */
#endif /* _IKsTopology_ */

#ifdef __cplusplus
}
#endif

#endif /* __KSPROXY__ */

