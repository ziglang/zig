#ifndef _STREAM_H
#define _STREAM_H

#include <ntddk.h>
#include <windef.h>
#include <ks.h>

#if defined(_ARM_)
#define STREAMAPI
#else
#define STREAMAPI __stdcall
#endif

#define STREAM_SYSTEM_TIME_MASK   ((STREAM_SYSTEM_TIME)0x00000001FFFFFFFF)

typedef enum {
  DebugLevelFatal = 0,
  DebugLevelError,
  DebugLevelWarning,
  DebugLevelInfo,
  DebugLevelTrace,
  DebugLevelVerbose,
  DebugLevelMaximum
} STREAM_DEBUG_LEVEL;


#if DBG

#define DebugPrint(x) StreamClassDebugPrint x
#define DEBUG_BREAKPOINT() DbgBreakPoint()
#define DEBUG_ASSERT(exp) \
            if ( !(exp) ) { \
                StreamClassDebugAssert( __FILE__, __LINE__, #exp, exp); \
            }
#else

#define DebugPrint(x)
#define DEBUG_BREAKPOINT()
#define DEBUG_ASSERT(exp)

#endif

typedef PHYSICAL_ADDRESS STREAM_PHYSICAL_ADDRESS, *PSTREAM_PHYSICAL_ADDRESS;
__GNU_EXTENSION typedef unsigned __int64 STREAM_SYSTEM_TIME, *PSTREAM_SYSTEM_TIME;
__GNU_EXTENSION typedef unsigned __int64 STREAM_TIMESTAMP, *PSTREAM_TIMESTAMP;

typedef enum {
  TIME_GET_STREAM_TIME,
  TIME_READ_ONBOARD_CLOCK,
  TIME_SET_ONBOARD_CLOCK
} TIME_FUNCTION;

typedef struct _HW_TIME_CONTEXT {
  struct _HW_DEVICE_EXTENSION *HwDeviceExtension;
  struct _HW_STREAM_OBJECT *HwStreamObject;
  TIME_FUNCTION Function;
  ULONGLONG Time;
  ULONGLONG SystemTime;
} HW_TIME_CONTEXT, *PHW_TIME_CONTEXT;

typedef struct _HW_EVENT_DESCRIPTOR {
  BOOLEAN Enable;
  PKSEVENT_ENTRY EventEntry;
  PKSEVENTDATA EventData;
  __GNU_EXTENSION union {
    struct _HW_STREAM_OBJECT * StreamObject;
    struct _HW_DEVICE_EXTENSION *DeviceExtension;
  };
  ULONG EnableEventSetIndex;
  PVOID HwInstanceExtension;
  ULONG Reserved;
} HW_EVENT_DESCRIPTOR, *PHW_EVENT_DESCRIPTOR;

struct _HW_STREAM_REQUEST_BLOCK;

typedef VOID (STREAMAPI * PHW_RECEIVE_STREAM_DATA_SRB) (IN struct _HW_STREAM_REQUEST_BLOCK * SRB);
typedef VOID (STREAMAPI * PHW_RECEIVE_STREAM_CONTROL_SRB) (IN struct _HW_STREAM_REQUEST_BLOCK  * SRB);
typedef NTSTATUS (STREAMAPI * PHW_EVENT_ROUTINE) (IN PHW_EVENT_DESCRIPTOR EventDescriptor);
typedef VOID (STREAMAPI * PHW_CLOCK_FUNCTION) (IN PHW_TIME_CONTEXT HwTimeContext);

typedef struct _HW_CLOCK_OBJECT {
  PHW_CLOCK_FUNCTION HwClockFunction;
  ULONG ClockSupportFlags;
  ULONG Reserved[2];
} HW_CLOCK_OBJECT, *PHW_CLOCK_OBJECT;

#define CLOCK_SUPPORT_CAN_SET_ONBOARD_CLOCK 0x1
#define CLOCK_SUPPORT_CAN_READ_ONBOARD_CLOCK 0x2
#define CLOCK_SUPPORT_CAN_RETURN_STREAM_TIME 0x4

typedef struct _HW_STREAM_OBJECT {
  ULONG           SizeOfThisPacket;
  ULONG           StreamNumber;
  PVOID           HwStreamExtension;
  PHW_RECEIVE_STREAM_DATA_SRB ReceiveDataPacket;
  PHW_RECEIVE_STREAM_CONTROL_SRB ReceiveControlPacket;
  HW_CLOCK_OBJECT HwClockObject;
  BOOLEAN         Dma;
  BOOLEAN         Pio;
  PVOID           HwDeviceExtension;
  ULONG    StreamHeaderMediaSpecific;
  ULONG    StreamHeaderWorkspace;
  BOOLEAN Allocator;
  PHW_EVENT_ROUTINE HwEventRoutine;
  ULONG Reserved[2];
} HW_STREAM_OBJECT, *PHW_STREAM_OBJECT;

typedef struct _HW_STREAM_HEADER {
  ULONG           NumberOfStreams;
  ULONG           SizeOfHwStreamInformation;
  ULONG           NumDevPropArrayEntries;
  PKSPROPERTY_SET DevicePropertiesArray;
  ULONG           NumDevEventArrayEntries;
  PKSEVENT_SET    DeviceEventsArray;
  PKSTOPOLOGY     Topology;
  PHW_EVENT_ROUTINE DeviceEventRoutine;
  LONG            NumDevMethodArrayEntries;
  PKSMETHOD_SET   DeviceMethodsArray;
} HW_STREAM_HEADER, *PHW_STREAM_HEADER;

typedef struct _HW_STREAM_INFORMATION {
  ULONG           NumberOfPossibleInstances;
  KSPIN_DATAFLOW  DataFlow;
  BOOLEAN         DataAccessible;
  ULONG           NumberOfFormatArrayEntries;
  PKSDATAFORMAT*  StreamFormatsArray;
  PVOID           ClassReserved[4];
  ULONG           NumStreamPropArrayEntries;
  PKSPROPERTY_SET StreamPropertiesArray;
  ULONG           NumStreamEventArrayEntries;
  PKSEVENT_SET    StreamEventsArray;
  GUID*                   Category;
  GUID*                   Name;
  ULONG                   MediumsCount;
  const KSPIN_MEDIUM*     Mediums;
  BOOLEAN         BridgeStream;
  ULONG Reserved[2];
} HW_STREAM_INFORMATION, *PHW_STREAM_INFORMATION;


typedef struct _HW_STREAM_DESCRIPTOR {
  HW_STREAM_HEADER StreamHeader;
  HW_STREAM_INFORMATION StreamInfo;
} HW_STREAM_DESCRIPTOR, *PHW_STREAM_DESCRIPTOR;

typedef struct _STREAM_TIME_REFERENCE {
  STREAM_TIMESTAMP CurrentOnboardClockValue;
  LARGE_INTEGER    OnboardClockFrequency;
  LARGE_INTEGER    CurrentSystemTime;
  ULONG Reserved[2];
} STREAM_TIME_REFERENCE, *PSTREAM_TIME_REFERENCE;

typedef struct _STREAM_DATA_INTERSECT_INFO {
  ULONG StreamNumber;
  PKSDATARANGE DataRange;
  PVOID   DataFormatBuffer;
  ULONG  SizeOfDataFormatBuffer;
} STREAM_DATA_INTERSECT_INFO, *PSTREAM_DATA_INTERSECT_INFO;

typedef struct _STREAM_PROPERTY_DESCRIPTOR {
  PKSPROPERTY     Property;
  ULONG           PropertySetID;
  PVOID           PropertyInfo;
  ULONG           PropertyInputSize;
  ULONG           PropertyOutputSize;
} STREAM_PROPERTY_DESCRIPTOR, *PSTREAM_PROPERTY_DESCRIPTOR;

typedef struct _STREAM_METHOD_DESCRIPTOR {
  ULONG		MethodSetID;
  PKSMETHOD	Method;
  PVOID		MethodInfo;
  LONG		MethodInputSize;
  LONG		MethodOutputSize;
} STREAM_METHOD_DESCRIPTOR, *PSTREAM_METHOD_DESCRIPTOR;

#define STREAM_REQUEST_BLOCK_SIZE sizeof(STREAM_REQUEST_BLOCK)

typedef enum _SRB_COMMAND {
  SRB_READ_DATA,
  SRB_WRITE_DATA, 
  SRB_GET_STREAM_STATE,
  SRB_SET_STREAM_STATE,
  SRB_SET_STREAM_PROPERTY,
  SRB_GET_STREAM_PROPERTY,
  SRB_OPEN_MASTER_CLOCK,

  SRB_INDICATE_MASTER_CLOCK,
  SRB_UNKNOWN_STREAM_COMMAND,
  SRB_SET_STREAM_RATE,
  SRB_PROPOSE_DATA_FORMAT,
  SRB_CLOSE_MASTER_CLOCK,
  SRB_PROPOSE_STREAM_RATE,
  SRB_SET_DATA_FORMAT,
  SRB_GET_DATA_FORMAT,
  SRB_BEGIN_FLUSH,
  SRB_END_FLUSH,

  SRB_GET_STREAM_INFO = 0x100,
  SRB_OPEN_STREAM,
  SRB_CLOSE_STREAM,
  SRB_OPEN_DEVICE_INSTANCE,
  SRB_CLOSE_DEVICE_INSTANCE,
  SRB_GET_DEVICE_PROPERTY,
  SRB_SET_DEVICE_PROPERTY,
  SRB_INITIALIZE_DEVICE,
  SRB_CHANGE_POWER_STATE,
  SRB_UNINITIALIZE_DEVICE,
  SRB_UNKNOWN_DEVICE_COMMAND,
  SRB_PAGING_OUT_DRIVER,
  SRB_GET_DATA_INTERSECTION,
  SRB_INITIALIZATION_COMPLETE,
  SRB_SURPRISE_REMOVAL

#if (NTDDI_VERSION >= NTDDI_WINXP)
 ,SRB_DEVICE_METHOD
 ,SRB_STREAM_METHOD
#if ( (NTDDI_VERSION >= NTDDI_WINXPSP2) && (NTDDI_VERSION < NTDDI_WS03) ) || (NTDDI_VERSION >= NTDDI_WS03SP1)
 ,SRB_NOTIFY_IDLE_STATE
#endif
#endif
} SRB_COMMAND;

typedef struct {
  PHYSICAL_ADDRESS    PhysicalAddress;
  ULONG               Length;
} KSSCATTER_GATHER, *PKSSCATTER_GATHER;


typedef struct _HW_STREAM_REQUEST_BLOCK {
  ULONG           SizeOfThisPacket;
  SRB_COMMAND     Command;
  NTSTATUS        Status;
  PHW_STREAM_OBJECT StreamObject;
  PVOID           HwDeviceExtension;
  PVOID           SRBExtension;

  union _CommandData {
    PKSSTREAM_HEADER DataBufferArray;
    PHW_STREAM_DESCRIPTOR StreamBuffer;
    KSSTATE         StreamState;
    PSTREAM_TIME_REFERENCE TimeReference;
    PSTREAM_PROPERTY_DESCRIPTOR PropertyInfo;
    PKSDATAFORMAT   OpenFormat;
    struct _PORT_CONFIGURATION_INFORMATION *ConfigInfo;
    HANDLE          MasterClockHandle;
    DEVICE_POWER_STATE DeviceState;
    PSTREAM_DATA_INTERSECT_INFO IntersectInfo;

#if (NTDDI_VERSION >= NTDDI_WINXP)
    PVOID	MethodInfo;
    LONG	FilterTypeIndex;
#if ( (NTDDI_VERSION >= NTDDI_WINXPSP2) && (NTDDI_VERSION < NTDDI_WS03) ) || (NTDDI_VERSION >= NTDDI_WS03SP1)
    BOOLEAN Idle;
#endif
#endif
  } CommandData;

  ULONG NumberOfBuffers;
  ULONG           TimeoutCounter;
  ULONG           TimeoutOriginal;
  struct _HW_STREAM_REQUEST_BLOCK *NextSRB;

  PIRP            Irp;
  ULONG           Flags;
  PVOID       HwInstanceExtension;

  __GNU_EXTENSION union {
    ULONG         NumberOfBytesToTransfer;
    ULONG         ActualBytesTransferred;
  };

  PKSSCATTER_GATHER ScatterGatherBuffer;
  ULONG           NumberOfPhysicalPages;
  ULONG           NumberOfScatterGatherElements;
  ULONG Reserved[1];
} HW_STREAM_REQUEST_BLOCK, *PHW_STREAM_REQUEST_BLOCK;

#define SRB_HW_FLAGS_DATA_TRANSFER  0x01
#define SRB_HW_FLAGS_STREAM_REQUEST 0x2

typedef enum {
  PerRequestExtension,
  DmaBuffer,
  SRBDataBuffer
} STREAM_BUFFER_TYPE;

typedef struct _ACCESS_RANGE {
  STREAM_PHYSICAL_ADDRESS RangeStart;
  ULONG           RangeLength;
  BOOLEAN         RangeInMemory;
  ULONG           Reserved;
} ACCESS_RANGE, *PACCESS_RANGE;

typedef struct _PORT_CONFIGURATION_INFORMATION {
  ULONG           SizeOfThisPacket;
  PVOID           HwDeviceExtension;
  PDEVICE_OBJECT  ClassDeviceObject;
  PDEVICE_OBJECT  PhysicalDeviceObject;
  ULONG           SystemIoBusNumber;
  INTERFACE_TYPE  AdapterInterfaceType;
  ULONG           BusInterruptLevel;
  ULONG           BusInterruptVector;
  KINTERRUPT_MODE InterruptMode;
  ULONG           DmaChannel;
  ULONG           NumberOfAccessRanges;
  PACCESS_RANGE   AccessRanges;
  ULONG           StreamDescriptorSize;
  PIRP            Irp;
  PKINTERRUPT  InterruptObject;
  PADAPTER_OBJECT  DmaAdapterObject;
  PDEVICE_OBJECT  RealPhysicalDeviceObject;
  ULONG Reserved[1];
} PORT_CONFIGURATION_INFORMATION, *PPORT_CONFIGURATION_INFORMATION;

typedef VOID (STREAMAPI * PHW_RECEIVE_DEVICE_SRB) (IN PHW_STREAM_REQUEST_BLOCK SRB);
typedef VOID (STREAMAPI * PHW_CANCEL_SRB) (IN PHW_STREAM_REQUEST_BLOCK SRB);
typedef VOID (STREAMAPI * PHW_REQUEST_TIMEOUT_HANDLER) (IN PHW_STREAM_REQUEST_BLOCK SRB);
typedef BOOLEAN (STREAMAPI * PHW_INTERRUPT) (IN PVOID DeviceExtension);
typedef VOID (STREAMAPI * PHW_TIMER_ROUTINE) (IN PVOID Context);
typedef VOID (STREAMAPI * PHW_PRIORITY_ROUTINE) (IN PVOID Context);
typedef VOID (STREAMAPI * PHW_QUERY_CLOCK_ROUTINE) (IN PHW_TIME_CONTEXT TimeContext);
typedef BOOLEAN (STREAMAPI * PHW_RESET_ADAPTER) (IN PVOID DeviceExtension);

typedef enum _STREAM_MINIDRIVER_STREAM_NOTIFICATION_TYPE {
  ReadyForNextStreamDataRequest,
  ReadyForNextStreamControlRequest,
  HardwareStarved,
  StreamRequestComplete,
  SignalMultipleStreamEvents,
  SignalStreamEvent,
  DeleteStreamEvent,
  StreamNotificationMaximum
} STREAM_MINIDRIVER_STREAM_NOTIFICATION_TYPE, *PSTREAM_MINIDRIVER_STREAM_NOTIFICATION_TYPE;

typedef enum _STREAM_MINIDRIVER_DEVICE_NOTIFICATION_TYPE {
  ReadyForNextDeviceRequest,
  DeviceRequestComplete,
  SignalMultipleDeviceEvents,
  SignalDeviceEvent,
  DeleteDeviceEvent,
#if (NTDDI_VERSION >= NTDDI_WINXP)
  SignalMultipleDeviceInstanceEvents,
#endif
  DeviceNotificationMaximum
} STREAM_MINIDRIVER_DEVICE_NOTIFICATION_TYPE, *PSTREAM_MINIDRIVER_DEVICE_NOTIFICATION_TYPE;

#define STREAM_CLASS_VERSION_20 0x0200

typedef struct _HW_INITIALIZATION_DATA {
#if (NTDDI_VERSION >= NTDDI_WINXP)
  __GNU_EXTENSION union {
    ULONG         HwInitializationDataSize;
    __GNU_EXTENSION struct {
      USHORT      SizeOfThisPacket;
      USHORT      StreamClassVersion;
    };
  };
#else
  ULONG           HwInitializationDataSize;
#endif /* NTDDI_VERSION >= NTDDI_WINXP */

  PHW_INTERRUPT   HwInterrupt;
  PHW_RECEIVE_DEVICE_SRB HwReceivePacket;
  PHW_CANCEL_SRB  HwCancelPacket;
  PHW_REQUEST_TIMEOUT_HANDLER HwRequestTimeoutHandler;
  ULONG           DeviceExtensionSize;
  ULONG           PerRequestExtensionSize;
  ULONG           PerStreamExtensionSize;
  ULONG           FilterInstanceExtensionSize;
  BOOLEAN         BusMasterDMA;
  BOOLEAN         Dma24BitAddresses;
  ULONG           BufferAlignment;
  BOOLEAN         TurnOffSynchronization;
  ULONG           DmaBufferSize;

#if (NTDDI_VERSION >= NTDDI_WINXP)
  ULONG		NumNameExtensions;
  PWCHAR	*NameExtensionArray;
#else
  ULONG Reserved[2];
#endif
} HW_INITIALIZATION_DATA, *PHW_INITIALIZATION_DATA;

typedef enum _STREAM_PRIORITY {
  High,
  Dispatch,
  Low,
  LowToHigh
} STREAM_PRIORITY, *PSTREAM_PRIORITY;


VOID
StreamClassAbortOutstandingRequests(
    IN PVOID HwDeviceExtension,
    IN PHW_STREAM_OBJECT HwStreamObject,
    IN NTSTATUS Status
);

VOID
STREAMAPI 
StreamClassCallAtNewPriority(
    IN PHW_STREAM_OBJECT  StreamObject,
    IN PVOID  HwDeviceExtension,
    IN STREAM_PRIORITY  Priority,
    IN PHW_PRIORITY_ROUTINE  PriorityRoutine,
    IN PVOID  Context
    );

VOID
STREAMAPI
StreamClassCompleteRequestAndMarkQueueReady(
    IN PHW_STREAM_REQUEST_BLOCK Srb
);

VOID
STREAMAPI
StreamClassDebugAssert(
    IN PCHAR File,
    IN ULONG Line,
    IN PCHAR AssertText,
    IN ULONG AssertValue
);

VOID
__cdecl
StreamClassDebugPrint(
    IN STREAM_DEBUG_LEVEL DebugPrintLevel,
    IN PCCHAR DebugMessage,
    ...
);

VOID
__cdecl
StreamClassDeviceNotification(
    IN STREAM_MINIDRIVER_DEVICE_NOTIFICATION_TYPE NotificationType,
    IN PVOID HwDeviceExtension,
    IN PHW_STREAM_REQUEST_BLOCK  pSrb,
    IN PKSEVENT_ENTRY  EventEntry,
    IN GUID  *EventSet,
    IN ULONG  EventId
);

VOID
STREAMAPI
StreamClassFilterReenumerateStreams(
    IN PVOID HwInstanceExtension,
    IN ULONG StreamDescriptorSize
);

PVOID
STREAMAPI
StreamClassGetDmaBuffer(
    IN PVOID HwDeviceExtension
);


PKSEVENT_ENTRY
StreamClassGetNextEvent(
    IN PVOID HwInstanceExtension_OR_HwDeviceExtension,
    IN PHW_STREAM_OBJECT HwStreamObject,
    IN GUID * EventGuid,
    IN ULONG EventItem,
    IN PKSEVENT_ENTRY CurrentEvent
);

STREAM_PHYSICAL_ADDRESS
STREAMAPI
StreamClassGetPhysicalAddress(
    IN PVOID HwDeviceExtension,
    IN PHW_STREAM_REQUEST_BLOCK HwSRB,
    IN PVOID VirtualAddress,
    IN STREAM_BUFFER_TYPE Type,
    IN ULONG * Length
);

VOID
StreamClassQueryMasterClock(
    IN PHW_STREAM_OBJECT HwStreamObject,
    IN HANDLE MasterClockHandle,
    IN TIME_FUNCTION TimeFunction,
    IN PHW_QUERY_CLOCK_ROUTINE ClockCallbackRoutine
);

VOID
STREAMAPI
StreamClassQueryMasterClockSync(
    IN HANDLE MasterClockHandle,
    IN PHW_TIME_CONTEXT TimeContext
);

BOOLEAN
STREAMAPI
StreamClassReadWriteConfig( 
    IN PVOID HwDeviceExtension,
    IN BOOLEAN Read,
    IN PVOID Buffer,
    IN ULONG Offset,
    IN ULONG Length
);

VOID
STREAMAPI
StreamClassReenumerateStreams(
    IN PVOID HwDeviceExtension,
    IN ULONG StreamDescriptorSize
);

NTSTATUS
STREAMAPI
StreamClassRegisterAdapter(
    IN PVOID Argument1,
    IN PVOID Argument2,
    IN PHW_INITIALIZATION_DATA HwInitializationData
);

#define StreamClassRegisterMinidriver StreamClassRegisterAdapter

NTSTATUS
StreamClassRegisterFilterWithNoKSPins( 
    IN PDEVICE_OBJECT   DeviceObject,
    IN const GUID     * InterfaceClassGUID,
    IN ULONG            PinCount,
    IN BOOLEAN * PinDirection,
    IN KSPIN_MEDIUM * MediumList,
    IN GUID * CategoryList
);

VOID
STREAMAPI
StreamClassScheduleTimer(
    IN PHW_STREAM_OBJECT StreamObject,
    IN PVOID HwDeviceExtension,
    IN ULONG NumberOfMicroseconds,
    IN PHW_TIMER_ROUTINE TimerRoutine,
    IN PVOID Context
);

VOID
__cdecl
StreamClassStreamNotification(
    IN STREAM_MINIDRIVER_STREAM_NOTIFICATION_TYPE NotificationType,
    IN PHW_STREAM_OBJECT StreamObject,
    IN ...
);

#endif /* _STREAM_H */

