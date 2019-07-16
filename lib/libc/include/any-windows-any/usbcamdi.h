/*
 * usbcamdi.h
 *
 * USB Camera driver interface.
 *
 * This file is part of the ReactOS PSDK package.
 *
 * Contributors:
 *   Created by Casper S. Hornstrup <chorns@users.sourceforge.net>
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#if !defined(__USB_H) && !defined(__USBDI_H)

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_BATTERYCLASS_)
# define USBCAMAPI
#else
# define USBCAMAPI DECLSPEC_IMPORT
#endif

typedef struct _pipe_config_descriptor {
  CHAR StreamAssociation;
  UCHAR PipeConfigFlags;
} USBCAMD_Pipe_Config_Descriptor, *PUSBCAMD_Pipe_Config_Descriptor;

#define USBCAMD_DATA_PIPE                 0x0001
#define USBCAMD_MULTIPLEX_PIPE            0x0002
#define USBCAMD_SYNC_PIPE                 0x0004
#define USBCAMD_DONT_CARE_PIPE            0x0008

#define USBCAMD_VIDEO_STREAM              0x1
#define USBCAMD_STILL_STREAM              0x2
#define USBCAMD_VIDEO_STILL_STREAM        (USBCAMD_VIDEO_STREAM | USBCAMD_STILL_STREAM)

#define USBCAMD_PROCESSPACKETEX_DropFrame             0x0002
#define USBCAMD_PROCESSPACKETEX_NextFrameIsStill      0x0004
#define USBCAMD_PROCESSPACKETEX_CurrentFrameIsStill   0x0008

#define USBCAMD_STOP_STREAM               0x00000001
#define USBCAMD_START_STREAM              0x00000000

typedef enum {
  USBCAMD_CamControlFlag_NoVideoRawProcessing = 1,
  USBCAMD_CamControlFlag_NoStillRawProcessing = 2,
  USBCAMD_CamControlFlag_AssociatedFormat = 4,
  USBCAMD_CamControlFlag_EnableDeviceEvents = 8
} USBCAMD_CamControlFlags;

typedef NTSTATUS
(NTAPI *PCOMMAND_COMPLETE_FUNCTION)(
  PVOID DeviceContext,
  PVOID CommandContext,
  NTSTATUS NtStatus);

typedef VOID
(NTAPI *PSTREAM_RECEIVE_PACKET)(
  PVOID Srb,
  PVOID DeviceContext,
  PBOOLEAN Completed);

typedef NTSTATUS
(NTAPI *PCAM_INITIALIZE_ROUTINE)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext);

typedef NTSTATUS
(NTAPI *PCAM_CONFIGURE_ROUTINE)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  PUSBD_INTERFACE_INFORMATION Interface,
  PUSB_CONFIGURATION_DESCRIPTOR ConfigurationDescriptor,
  PLONG DataPipeIndex,
  PLONG SyncPipeIndex);

typedef NTSTATUS
(NTAPI *PCAM_CONFIGURE_ROUTINE_EX)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  PUSBD_INTERFACE_INFORMATION Interface,
  PUSB_CONFIGURATION_DESCRIPTOR ConfigurationDescriptor,
  ULONG PipeConfigListSize,
  PUSBCAMD_Pipe_Config_Descriptor PipeConfig,
  PUSB_DEVICE_DESCRIPTOR DeviceDescriptor);

typedef NTSTATUS
(NTAPI *PCAM_START_CAPTURE_ROUTINE)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext);

typedef NTSTATUS
(NTAPI *PCAM_START_CAPTURE_ROUTINE_EX)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  ULONG StreamNumber);

typedef NTSTATUS
(NTAPI *PCAM_ALLOCATE_BW_ROUTINE)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  PULONG RawFrameLength,
  PVOID Format);

typedef NTSTATUS
(NTAPI *PCAM_ALLOCATE_BW_ROUTINE_EX)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  PULONG RawFrameLength,
  PVOID Format,
  ULONG StreamNumber);

typedef NTSTATUS
(NTAPI *PCAM_FREE_BW_ROUTINE)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext);

typedef NTSTATUS
(NTAPI *PCAM_FREE_BW_ROUTINE_EX)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  ULONG StreamNumber);

typedef VOID
(NTAPI *PADAPTER_RECEIVE_PACKET_ROUTINE)(
  PHW_STREAM_REQUEST_BLOCK Srb);

typedef NTSTATUS
(NTAPI *PCAM_STOP_CAPTURE_ROUTINE)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext);

typedef NTSTATUS
(NTAPI *PCAM_STOP_CAPTURE_ROUTINE_EX)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  ULONG StreamNumber);

typedef ULONG
(NTAPI *PCAM_PROCESS_PACKET_ROUTINE)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  PVOID CurrentFrameContext,
  PUSBD_ISO_PACKET_DESCRIPTOR SyncPacket,
  PVOID SyncBuffer,
  PUSBD_ISO_PACKET_DESCRIPTOR DataPacket,
  PVOID DataBuffer,
  PBOOLEAN FrameComplete,
  PBOOLEAN NextFrameIsStill);

typedef ULONG
(NTAPI *PCAM_PROCESS_PACKET_ROUTINE_EX)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  PVOID CurrentFrameContext,
  PUSBD_ISO_PACKET_DESCRIPTOR SyncPacket,
  PVOID SyncBuffer,
  PUSBD_ISO_PACKET_DESCRIPTOR DataPacket,
  PVOID DataBuffer,
  PBOOLEAN FrameComplete,
  PULONG PacketFlag,
  PULONG ValidDataOffset);

typedef VOID
(NTAPI *PCAM_NEW_FRAME_ROUTINE)(
  PVOID DeviceContext,
  PVOID FrameContext);

typedef VOID
(NTAPI *PCAM_NEW_FRAME_ROUTINE_EX)(
  PVOID DeviceContext,
  PVOID FrameContext,
  ULONG StreamNumber,
  PULONG FrameLength);

typedef NTSTATUS
(NTAPI *PCAM_PROCESS_RAW_FRAME_ROUTINE)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  PVOID FrameContext,
  PVOID FrameBuffer,
  ULONG FrameLength,
  PVOID RawFrameBuffer,
  ULONG RawFrameLength,
  ULONG NumberOfPackets,
  PULONG BytesReturned);

typedef NTSTATUS
(NTAPI *PCAM_PROCESS_RAW_FRAME_ROUTINE_EX)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext,
  PVOID FrameContext,
  PVOID FrameBuffer,
  ULONG FrameLength,
  PVOID RawFrameBuffer,
  ULONG RawFrameLength,
  ULONG NumberOfPackets,
  PULONG BytesReturned,
  ULONG ActualRawFrameLength,
  ULONG StreamNumber);

typedef NTSTATUS
(NTAPI *PCAM_STATE_ROUTINE)(
  PDEVICE_OBJECT BusDeviceObject,
  PVOID DeviceContext);

#if defined(DEBUG_LOG)

USBCAMAPI
VOID
NTAPI
USBCAMD_Debug_LogEntry(
  CHAR *Name,
  ULONG Info1,
  ULONG Info2,
  ULONG Info3);

#define ILOGENTRY(sig, info1, info2, info3) \
  USBCAMD_Debug_LogEntry(sig, (ULONG)info1, (ULONG)info2, (ULONG)info3)

#else

#define ILOGENTRY(sig, info1, info2, info3)

#endif /* DEBUG_LOG */

typedef struct _USBCAMD_DEVICE_DATA {
  ULONG Sig;
  PCAM_INITIALIZE_ROUTINE CamInitialize;
  PCAM_INITIALIZE_ROUTINE CamUnInitialize;
  PCAM_PROCESS_PACKET_ROUTINE CamProcessUSBPacket;
  PCAM_NEW_FRAME_ROUTINE CamNewVideoFrame;
  PCAM_PROCESS_RAW_FRAME_ROUTINE CamProcessRawVideoFrame;
  PCAM_START_CAPTURE_ROUTINE CamStartCapture;
  PCAM_STOP_CAPTURE_ROUTINE CamStopCapture;
  PCAM_CONFIGURE_ROUTINE CamConfigure;
  PCAM_STATE_ROUTINE CamSaveState;
  PCAM_STATE_ROUTINE CamRestoreState;
  PCAM_ALLOCATE_BW_ROUTINE CamAllocateBandwidth;
  PCAM_FREE_BW_ROUTINE CamFreeBandwidth;
} USBCAMD_DEVICE_DATA, *PUSBCAMD_DEVICE_DATA;

typedef struct _USBCAMD_DEVICE_DATA2 {
  ULONG Sig;
  PCAM_INITIALIZE_ROUTINE CamInitialize;
  PCAM_INITIALIZE_ROUTINE CamUnInitialize;
  PCAM_PROCESS_PACKET_ROUTINE_EX CamProcessUSBPacketEx;
  PCAM_NEW_FRAME_ROUTINE_EX CamNewVideoFrameEx;
  PCAM_PROCESS_RAW_FRAME_ROUTINE_EX CamProcessRawVideoFrameEx;
  PCAM_START_CAPTURE_ROUTINE_EX CamStartCaptureEx;
  PCAM_STOP_CAPTURE_ROUTINE_EX CamStopCaptureEx;
  PCAM_CONFIGURE_ROUTINE_EX CamConfigureEx;
  PCAM_STATE_ROUTINE CamSaveState;
  PCAM_STATE_ROUTINE CamRestoreState;
  PCAM_ALLOCATE_BW_ROUTINE_EX CamAllocateBandwidthEx;
  PCAM_FREE_BW_ROUTINE_EX CamFreeBandwidthEx;
} USBCAMD_DEVICE_DATA2, *PUSBCAMD_DEVICE_DATA2;

DEFINE_GUID(GUID_USBCAMD_INTERFACE,
  0x2bcb75c0, 0xb27f, 0x11d1, 0xba, 0x41, 0x0, 0xa0, 0xc9, 0xd, 0x2b, 0x5);

typedef NTSTATUS
(NTAPI *PFNUSBCAMD_SetVideoFormat)(
  PVOID DeviceContext,
  PHW_STREAM_REQUEST_BLOCK pSrb);

typedef NTSTATUS
(NTAPI *PFNUSBCAMD_WaitOnDeviceEvent)(
  PVOID DeviceContext,
  ULONG PipeIndex,
  PVOID Buffer,
  ULONG BufferLength,
  PCOMMAND_COMPLETE_FUNCTION EventComplete,
  PVOID EventContext,
  BOOLEAN LoopBack);

typedef NTSTATUS
(NTAPI *PFNUSBCAMD_CancelBulkReadWrite)(
  PVOID DeviceContext,
  ULONG PipeIndex);

typedef NTSTATUS
(NTAPI *PFNUSBCAMD_SetIsoPipeState)(
  PVOID DeviceContext,
  ULONG PipeStateFlags);

typedef NTSTATUS
(NTAPI *PFNUSBCAMD_BulkReadWrite)(
  PVOID DeviceContext,
  USHORT PipeIndex,
  PVOID Buffer,
  ULONG BufferLength,
  PCOMMAND_COMPLETE_FUNCTION CommandComplete,
  PVOID CommandContext);

#define USBCAMD_VERSION_200               0x200

typedef struct _USBCAMD_INTERFACE {
  INTERFACE Interface;
  PFNUSBCAMD_WaitOnDeviceEvent USBCAMD_WaitOnDeviceEvent;
  PFNUSBCAMD_BulkReadWrite USBCAMD_BulkReadWrite;
  PFNUSBCAMD_SetVideoFormat USBCAMD_SetVideoFormat;
  PFNUSBCAMD_SetIsoPipeState USBCAMD_SetIsoPipeState;
  PFNUSBCAMD_CancelBulkReadWrite USBCAMD_CancelBulkReadWrite;
} USBCAMD_INTERFACE, *PUSBCAMD_INTERFACE;

/* FIXME : Do we need USBCAMAPI here ? */

USBCAMAPI
ULONG
NTAPI
USBCAMD_DriverEntry(
  PVOID Context1,
  PVOID Context2,
  ULONG DeviceContextSize,
  ULONG FrameContextSize,
  PADAPTER_RECEIVE_PACKET_ROUTINE ReceivePacket);

USBCAMAPI
PVOID
NTAPI
USBCAMD_AdapterReceivePacket(
  PHW_STREAM_REQUEST_BLOCK Srb,
  PUSBCAMD_DEVICE_DATA DeviceData,
  PDEVICE_OBJECT *DeviceObject,
  BOOLEAN NeedsCompletion);

USBCAMAPI
NTSTATUS
NTAPI
USBCAMD_ControlVendorCommand(
  PVOID DeviceContext,
  UCHAR Request,
  USHORT Value,
  USHORT Index,
  PVOID Buffer,
  PULONG BufferLength,
  BOOLEAN GetData,
  PCOMMAND_COMPLETE_FUNCTION CommandComplete,
  PVOID CommandContext);

USBCAMAPI
NTSTATUS
NTAPI
USBCAMD_SelectAlternateInterface(
  PVOID DeviceContext,
  PUSBD_INTERFACE_INFORMATION RequestInterface);

USBCAMAPI
NTSTATUS
NTAPI
USBCAMD_GetRegistryKeyValue(
  HANDLE Handle,
  PWCHAR KeyNameString,
  ULONG KeyNameStringLength,
  PVOID Data,
  ULONG DataLength);

USBCAMAPI
ULONG
NTAPI
USBCAMD_InitializeNewInterface(
  PVOID DeviceContext,
  PVOID DeviceData,
  ULONG Version,
  ULONG CamControlFlag);

#ifdef __cplusplus
}
#endif

#endif /* !defined(__USB_H) && !defined(__USBDI_H) */
