/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifdef DEFINE_GUID

#ifndef FAR
#define FAR
#endif

DEFINE_GUID(ScsiRawInterfaceGuid,0x53f56309,0xb6bf,0x11d0,0x94,0xf2,0x00,0xa0,0xc9,0x1e,0xfb,0x8b);
DEFINE_GUID(WmiScsiAddressGuid,0x53f5630f,0xb6bf,0x11d0,0x94,0xf2,0x00,0xa0,0xc9,0x1e,0xfb,0x8b);
#endif /* DEFINE_GUID */

#ifndef _NTDDSCSIH_
#define _NTDDSCSIH_

#ifdef __cplusplus
extern "C" {
#endif

#define IOCTL_SCSI_BASE		FILE_DEVICE_CONTROLLER

#define DD_SCSI_DEVICE_NAME	"\\Device\\ScsiPort"
#define DD_SCSI_DEVICE_NAME_U  L"\\Device\\ScsiPort"

#define IOCTL_SCSI_PASS_THROUGH CTL_CODE(IOCTL_SCSI_BASE,0x0401,METHOD_BUFFERED,FILE_READ_ACCESS | FILE_WRITE_ACCESS)
#define IOCTL_SCSI_MINIPORT CTL_CODE(IOCTL_SCSI_BASE,0x0402,METHOD_BUFFERED,FILE_READ_ACCESS | FILE_WRITE_ACCESS)
#define IOCTL_SCSI_GET_INQUIRY_DATA CTL_CODE(IOCTL_SCSI_BASE,0x0403,METHOD_BUFFERED,FILE_ANY_ACCESS)
#define IOCTL_SCSI_GET_CAPABILITIES CTL_CODE(IOCTL_SCSI_BASE,0x0404,METHOD_BUFFERED,FILE_ANY_ACCESS)
#define IOCTL_SCSI_PASS_THROUGH_DIRECT CTL_CODE(IOCTL_SCSI_BASE,0x0405,METHOD_BUFFERED,FILE_READ_ACCESS | FILE_WRITE_ACCESS)
#define IOCTL_SCSI_GET_ADDRESS CTL_CODE(IOCTL_SCSI_BASE,0x0406,METHOD_BUFFERED,FILE_ANY_ACCESS)
#define IOCTL_SCSI_RESCAN_BUS CTL_CODE(IOCTL_SCSI_BASE,0x0407,METHOD_BUFFERED,FILE_ANY_ACCESS)
#define IOCTL_SCSI_GET_DUMP_POINTERS CTL_CODE(IOCTL_SCSI_BASE,0x0408,METHOD_BUFFERED,FILE_ANY_ACCESS)
#define IOCTL_SCSI_FREE_DUMP_POINTERS CTL_CODE(IOCTL_SCSI_BASE,0x0409,METHOD_BUFFERED,FILE_ANY_ACCESS)
#define IOCTL_IDE_PASS_THROUGH CTL_CODE(IOCTL_SCSI_BASE,0x040a,METHOD_BUFFERED,FILE_READ_ACCESS | FILE_WRITE_ACCESS)
#define IOCTL_ATA_PASS_THROUGH CTL_CODE(IOCTL_SCSI_BASE,0x040b,METHOD_BUFFERED,FILE_READ_ACCESS | FILE_WRITE_ACCESS)
#define IOCTL_ATA_PASS_THROUGH_DIRECT CTL_CODE(IOCTL_SCSI_BASE,0x040c,METHOD_BUFFERED,FILE_READ_ACCESS | FILE_WRITE_ACCESS)

  typedef struct _SCSI_PASS_THROUGH {
    USHORT Length;
    UCHAR ScsiStatus;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    UCHAR CdbLength;
    UCHAR SenseInfoLength;
    UCHAR DataIn;
    ULONG DataTransferLength;
    ULONG TimeOutValue;
    ULONG_PTR DataBufferOffset;
    ULONG SenseInfoOffset;
    UCHAR Cdb[16];
  }SCSI_PASS_THROUGH,*PSCSI_PASS_THROUGH;

  typedef struct _SCSI_PASS_THROUGH_DIRECT {
    USHORT Length;
    UCHAR ScsiStatus;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    UCHAR CdbLength;
    UCHAR SenseInfoLength;
    UCHAR DataIn;
    ULONG DataTransferLength;
    ULONG TimeOutValue;
    PVOID DataBuffer;
    ULONG SenseInfoOffset;
    UCHAR Cdb[16];
  }SCSI_PASS_THROUGH_DIRECT,*PSCSI_PASS_THROUGH_DIRECT;

#if defined(_WIN64)
  typedef struct _SCSI_PASS_THROUGH32 {
    USHORT Length;
    UCHAR ScsiStatus;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    UCHAR CdbLength;
    UCHAR SenseInfoLength;
    UCHAR DataIn;
    ULONG DataTransferLength;
    ULONG TimeOutValue;
    ULONG32 DataBufferOffset;
    ULONG SenseInfoOffset;
    UCHAR Cdb[16];
  } SCSI_PASS_THROUGH32,*PSCSI_PASS_THROUGH32;

  typedef struct _SCSI_PASS_THROUGH_DIRECT32 {
    USHORT Length;
    UCHAR ScsiStatus;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    UCHAR CdbLength;
    UCHAR SenseInfoLength;
    UCHAR DataIn;
    ULONG DataTransferLength;
    ULONG TimeOutValue;
    VOID *DataBuffer;
    ULONG SenseInfoOffset;
    UCHAR Cdb[16];
  } SCSI_PASS_THROUGH_DIRECT32,*PSCSI_PASS_THROUGH_DIRECT32;
#endif /* _WIN64 */

  typedef struct _ATA_PASS_THROUGH_EX {
    USHORT Length;
    USHORT AtaFlags;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    UCHAR ReservedAsUchar;
    ULONG DataTransferLength;
    ULONG TimeOutValue;
    ULONG ReservedAsUlong;
    ULONG_PTR DataBufferOffset;
    UCHAR PreviousTaskFile[8];
    UCHAR CurrentTaskFile[8];
  } ATA_PASS_THROUGH_EX,*PATA_PASS_THROUGH_EX;

  typedef struct _ATA_PASS_THROUGH_DIRECT {
    USHORT Length;
    USHORT AtaFlags;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    UCHAR ReservedAsUchar;
    ULONG DataTransferLength;
    ULONG TimeOutValue;
    ULONG ReservedAsUlong;
    PVOID DataBuffer;
    UCHAR PreviousTaskFile[8];
    UCHAR CurrentTaskFile[8];
  } ATA_PASS_THROUGH_DIRECT,*PATA_PASS_THROUGH_DIRECT;

#if defined(_WIN64)

  typedef struct _ATA_PASS_THROUGH_EX32 {
    USHORT Length;
    USHORT AtaFlags;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    UCHAR ReservedAsUchar;
    ULONG DataTransferLength;
    ULONG TimeOutValue;
    ULONG ReservedAsUlong;
    ULONG32 DataBufferOffset;
    UCHAR PreviousTaskFile[8];
    UCHAR CurrentTaskFile[8];
  } ATA_PASS_THROUGH_EX32,*PATA_PASS_THROUGH_EX32;

  typedef struct _ATA_PASS_THROUGH_DIRECT32 {
    USHORT Length;
    USHORT AtaFlags;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    UCHAR ReservedAsUchar;
    ULONG DataTransferLength;
    ULONG TimeOutValue;
    ULONG ReservedAsUlong;
    VOID *DataBuffer;
    UCHAR PreviousTaskFile[8];
    UCHAR CurrentTaskFile[8];
  } ATA_PASS_THROUGH_DIRECT32,*PATA_PASS_THROUGH_DIRECT32;
#endif /* _WIN64 */

#define ATA_FLAGS_DRDY_REQUIRED (1 << 0)
#define ATA_FLAGS_DATA_IN (1 << 1)
#define ATA_FLAGS_DATA_OUT (1 << 2)
#define ATA_FLAGS_48BIT_COMMAND (1 << 3)
#define ATA_FLAGS_USE_DMA (1 << 4)

  typedef struct _SCSI_BUS_DATA {
    UCHAR NumberOfLogicalUnits;
    UCHAR InitiatorBusId;
    ULONG InquiryDataOffset;
  }SCSI_BUS_DATA,*PSCSI_BUS_DATA;

  typedef struct _SCSI_ADAPTER_BUS_INFO {
    UCHAR NumberOfBuses;
    SCSI_BUS_DATA BusData[1];
  } SCSI_ADAPTER_BUS_INFO,*PSCSI_ADAPTER_BUS_INFO;

  typedef struct _SCSI_INQUIRY_DATA {
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
    BOOLEAN DeviceClaimed;
    ULONG InquiryDataLength;
    ULONG NextInquiryDataOffset;
    UCHAR InquiryData[1];
  }SCSI_INQUIRY_DATA,*PSCSI_INQUIRY_DATA;

  typedef struct _SRB_IO_CONTROL {
    ULONG HeaderLength;
    UCHAR Signature[8];
    ULONG Timeout;
    ULONG ControlCode;
    ULONG ReturnCode;
    ULONG Length;
  } SRB_IO_CONTROL,*PSRB_IO_CONTROL;

  typedef struct _IO_SCSI_CAPABILITIES {
    ULONG Length;
    ULONG MaximumTransferLength;
    ULONG MaximumPhysicalPages;
    ULONG SupportedAsynchronousEvents;
    ULONG AlignmentMask;
    BOOLEAN TaggedQueuing;
    BOOLEAN AdapterScansDown;
    BOOLEAN AdapterUsesPio;
  } IO_SCSI_CAPABILITIES,*PIO_SCSI_CAPABILITIES;

  typedef struct _SCSI_ADDRESS {
    ULONG Length;
    UCHAR PortNumber;
    UCHAR PathId;
    UCHAR TargetId;
    UCHAR Lun;
  } SCSI_ADDRESS,*PSCSI_ADDRESS;

  struct _ADAPTER_OBJECT;

  typedef struct _DUMP_POINTERS {
    struct _ADAPTER_OBJECT *AdapterObject;
    PVOID MappedRegisterBase;
    PVOID DumpData;
    PVOID CommonBufferVa;
    LARGE_INTEGER CommonBufferPa;
    ULONG CommonBufferSize;
    BOOLEAN AllocateCommonBuffers;
    BOOLEAN UseDiskDump;
    UCHAR Spare1[2];
    PVOID DeviceObject;
  } DUMP_POINTERS,*PDUMP_POINTERS;

#define SCSI_IOCTL_DATA_OUT 0
#define SCSI_IOCTL_DATA_IN 1
#define SCSI_IOCTL_DATA_UNSPECIFIED 2

#ifdef __cplusplus
}
#endif

#endif /* _NTDDSCSIH_ */

