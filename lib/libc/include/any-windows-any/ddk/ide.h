/*
 * ide.h
 *
 * IDE driver interface
 *
 * This file is part of the w32api package.
 *
 * Contributors:
 *   Created by Hervé Poussineau <hpoussin@reactos.org>
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

#ifndef __IDE_H
#define __IDE_H

#ifdef __cplusplus
extern "C" {
#endif

#define MAX_IDE_CHANNEL   2
#define MAX_IDE_LINE      2
#define MAX_IDE_DEVICE    2

#include <pshpack1.h>
typedef struct _IDENTIFY_DATA {
  USHORT GeneralConfiguration;       /* 00 */
  USHORT NumCylinders;               /* 02 */
  USHORT Reserved1;                  /* 04 */
  USHORT NumHeads;                   /* 06 */
  USHORT UnformattedBytesPerTrack;   /* 08 */
  USHORT UnformattedBytesPerSector;  /* 10 */
  USHORT NumSectorsPerTrack;         /* 12 */
  USHORT VendorUnique1[3];           /* 14 */
  UCHAR  SerialNumber[20];           /* 20 */
  USHORT BufferType;                 /* 40 */
  USHORT BufferSectorSize;           /* 42 */
  USHORT NumberOfEccBytes;           /* 44 */
  UCHAR  FirmwareRevision[8];        /* 46 */
  UCHAR  ModelNumber[40];            /* 54 */
  UCHAR  MaximumBlockTransfer;       /* 94 */
  UCHAR  VendorUnique2;              /* 95 */
  USHORT DoubleWordIo;               /* 96 */
  USHORT Capabilities;               /* 98 */
  USHORT Reserved2;                  /* 100 */
  UCHAR  VendorUnique3;              /* 102 */
  UCHAR  PioCycleTimingMode;         /* 103 */
  UCHAR  VendorUnique4;              /* 104 */
  UCHAR  DmaCycleTimingMode;         /* 105 */
  USHORT TranslationFieldsValid:3;   /* 106 */
  USHORT Reserved3:13;               /*  -  */
  USHORT NumberOfCurrentCylinders;   /* 108 */
  USHORT NumberOfCurrentHeads;       /* 110 */
  USHORT CurrentSectorsPerTrack;     /* 112 */
  ULONG  CurrentSectorCapacity;      /* 114 */
  USHORT CurrentMultiSectorSetting;  /* 118 */
  ULONG  UserAddressableSectors;     /* 120 */
  USHORT SingleWordDMASupport:8;     /* 124 */
  USHORT SingleWordDMAActive:8;      /*  -  */
  USHORT MultiWordDMASupport:8;      /* 126 */
  USHORT MultiWordDMAActive:8;       /*  -  */
  USHORT AdvancedPIOModes:8;         /* 128 */
  USHORT Reserved4:8;                /*  -  */
  USHORT MinimumMWXferCycleTime;     /* 130 */
  USHORT RecommendedMWXferCycleTime; /* 132 */
  USHORT MinimumPIOCycleTime;        /* 134 */
  USHORT MinimumPIOCycleTimeIORDY;   /* 136 */
  USHORT Reserved5[11];              /* 138 */
  USHORT MajorRevision;              /* 160 */
  USHORT MinorRevision;              /* 162 */
  USHORT Reserved6;                  /* 164 */
  USHORT CommandSetSupport;          /* 166 */
  USHORT Reserved6a[2];              /* 168 */
  USHORT CommandSetActive;           /* 172 */
  USHORT Reserved6b;                 /* 174 */
  USHORT UltraDMASupport:8;          /* 176 */
  USHORT UltraDMAActive:8;           /*  -  */
  USHORT Reserved7[11];              /* 178 */
  ULONG  Max48BitLBA[2];             /* 200 */
  USHORT Reserved7a[22];             /* 208 */
  USHORT LastLun:3;                  /* 252 */
  USHORT Reserved8:13;               /*  -  */
  USHORT MediaStatusNotification:2;  /* 254 */
  USHORT Reserved9:6;                /*  -  */
  USHORT DeviceWriteProtect:1;       /*  -  */
  USHORT Reserved10:7;               /*  -  */
  USHORT Reserved11[128];            /* 256 */
} IDENTIFY_DATA, *PIDENTIFY_DATA;

typedef struct _EXTENDED_IDENTIFY_DATA {
  USHORT GeneralConfiguration;       /* 00 */
  USHORT NumCylinders;               /* 02 */
  USHORT Reserved1;                  /* 04 */
  USHORT NumHeads;                   /* 06 */
  USHORT UnformattedBytesPerTrack;   /* 08 */
  USHORT UnformattedBytesPerSector;  /* 10 */
  USHORT NumSectorsPerTrack;         /* 12 */
  __GNU_EXTENSION union
  {
    USHORT VendorUnique1[3];         /* 14 */
    struct
    {
      UCHAR InterSectorGap;          /* 14 */
      UCHAR InterSectorGapSize;      /* -  */
      UCHAR Reserved16;              /* 16 */
      UCHAR BytesInPLO;              /* -  */
      USHORT VendorUniqueCnt;        /* 18 */
    } u;
  };
  UCHAR  SerialNumber[20];           /* 20 */
  USHORT BufferType;                 /* 40 */
  USHORT BufferSectorSize;           /* 42 */
  USHORT NumberOfEccBytes;           /* 44 */
  UCHAR  FirmwareRevision[8];        /* 46 */
  UCHAR  ModelNumber[40];            /* 54 */
  UCHAR  MaximumBlockTransfer;       /* 94 */
  UCHAR  VendorUnique2;              /* 95 */
  USHORT DoubleWordIo;               /* 96 */
  USHORT Capabilities;               /* 98 */
  USHORT Reserved2;                  /* 100 */
  UCHAR  VendorUnique3;              /* 102 */
  UCHAR  PioCycleTimingMode;         /* 103 */
  UCHAR  VendorUnique4;              /* 104 */
  UCHAR  DmaCycleTimingMode;         /* 105 */
  USHORT TranslationFieldsValid:3;   /* 106 */
  USHORT Reserved3:13;               /*  -  */
  USHORT NumberOfCurrentCylinders;   /* 108 */
  USHORT NumberOfCurrentHeads;       /* 110 */
  USHORT CurrentSectorsPerTrack;     /* 112 */
  ULONG  CurrentSectorCapacity;      /* 114 */
  USHORT CurrentMultiSectorSetting;  /* 118 */
  ULONG  UserAddressableSectors;     /* 120 */
  USHORT SingleWordDMASupport:8;     /* 124 */
  USHORT SingleWordDMAActive:8;      /*  -  */
  USHORT MultiWordDMASupport:8;      /* 126 */
  USHORT MultiWordDMAActive:8;       /*  -  */
  USHORT AdvancedPIOModes:8;         /* 128 */
  USHORT Reserved4:8;                /*  -  */
  USHORT MinimumMWXferCycleTime;     /* 130 */
  USHORT RecommendedMWXferCycleTime; /* 132 */
  USHORT MinimumPIOCycleTime;        /* 134 */
  USHORT MinimumPIOCycleTimeIORDY;   /* 136 */
  USHORT Reserved5[11];              /* 138 */
  USHORT MajorRevision;              /* 160 */
  USHORT MinorRevision;              /* 162 */
  USHORT Reserved6;                  /* 164 */
  USHORT CommandSetSupport;          /* 166 */
  USHORT Reserved6a[2];              /* 168 */
  USHORT CommandSetActive;           /* 172 */
  USHORT Reserved6b;                 /* 174 */
  USHORT UltraDMASupport:8;          /* 176 */
  USHORT UltraDMAActive:8;           /*  -  */
  USHORT Reserved7[11];              /* 178 */
  ULONG  Max48BitLBA[2];             /* 200 */
  USHORT Reserved7a[22];             /* 208 */
  USHORT LastLun:3;                  /* 252 */
  USHORT Reserved8:13;               /*  -  */
  USHORT MediaStatusNotification:2;  /* 254 */
  USHORT Reserved9:6;                /*  -  */
  USHORT DeviceWriteProtect:1;       /*  -  */
  USHORT Reserved10:7;               /*  -  */
  USHORT Reserved11[128];            /* 256 */
} EXTENDED_IDENTIFY_DATA, *PEXTENDED_IDENTIFY_DATA;
#include <poppack.h>

typedef struct _PCIIDE_TRANSFER_MODE_SELECT
{
  ULONG Channel;
  BOOLEAN DevicePresent[MAX_IDE_DEVICE * MAX_IDE_LINE];
  BOOLEAN FixedDisk[MAX_IDE_DEVICE * MAX_IDE_LINE];
  BOOLEAN IoReadySupported[MAX_IDE_DEVICE * MAX_IDE_LINE];
  ULONG DeviceTransferModeSupported[MAX_IDE_DEVICE * MAX_IDE_LINE];
  ULONG BestPioCycleTime[MAX_IDE_DEVICE * MAX_IDE_LINE];
  ULONG BestSwDmaCycleTime[MAX_IDE_DEVICE * MAX_IDE_LINE];
  ULONG BestMwDmaCycleTime[MAX_IDE_DEVICE * MAX_IDE_LINE];
  ULONG BestUDmaCycleTime[MAX_IDE_DEVICE * MAX_IDE_LINE];
  ULONG DeviceTransferModeCurrent[MAX_IDE_DEVICE * MAX_IDE_LINE];
  ULONG UserChoiceTransferMode[MAX_IDE_DEVICE * MAX_IDE_LINE];
  ULONG EnableUDMA66;
  IDENTIFY_DATA IdentifyData[MAX_IDE_DEVICE];
  ULONG DeviceTransferModeSelected[MAX_IDE_DEVICE * MAX_IDE_LINE];
  PULONG TransferModeTimingTable;
  ULONG TransferModeTableLength;
} PCIIDE_TRANSFER_MODE_SELECT, *PPCIIDE_TRANSFER_MODE_SELECT;

typedef enum
{
  ChannelDisabled = 0,
  ChannelEnabled,
  ChannelStateUnknown
} IDE_CHANNEL_STATE;

typedef IDE_CHANNEL_STATE
(NTAPI *PCIIDE_CHANNEL_ENABLED)(
  IN PVOID DeviceExtension,
  IN ULONG Channel);

typedef BOOLEAN
(NTAPI *PCIIDE_SYNC_ACCESS_REQUIRED)(
  IN PVOID DeviceExtension);

typedef NTSTATUS
(NTAPI *PCIIDE_TRANSFER_MODE_SELECT_FUNC)(
  IN PVOID DeviceExtension,
  IN OUT PPCIIDE_TRANSFER_MODE_SELECT XferMode);

typedef ULONG
(NTAPI *PCIIDE_USEDMA_FUNC)(
  IN PVOID DeviceExtension,
  IN PUCHAR CdbCommand,
  IN PUCHAR Slave);

typedef NTSTATUS
(NTAPI *PCIIDE_UDMA_MODES_SUPPORTED)(
  IN IDENTIFY_DATA IdentifyData,
  OUT PULONG BestXferMode,
  OUT PULONG CurrentXferMode);

typedef struct _IDE_CONTROLLER_PROPERTIES
{
  ULONG Size;
  ULONG ExtensionSize;
  ULONG SupportedTransferMode[MAX_IDE_CHANNEL][MAX_IDE_DEVICE];
  PCIIDE_CHANNEL_ENABLED PciIdeChannelEnabled;
  PCIIDE_SYNC_ACCESS_REQUIRED PciIdeSyncAccessRequired;
  PCIIDE_TRANSFER_MODE_SELECT_FUNC PciIdeTransferModeSelect;
  BOOLEAN IgnoreActiveBitForAtaDevice;
  BOOLEAN AlwaysClearBusMasterInterrupt;
  PCIIDE_USEDMA_FUNC PciIdeUseDma;
  ULONG AlignmentRequirement;
  ULONG DefaultPIO;
  PCIIDE_UDMA_MODES_SUPPORTED PciIdeUdmaModesSupported;
} IDE_CONTROLLER_PROPERTIES, *PIDE_CONTROLLER_PROPERTIES;

typedef NTSTATUS
(NTAPI *PCONTROLLER_PROPERTIES)(
  IN PVOID DeviceExtension,
  IN PIDE_CONTROLLER_PROPERTIES ControllerProperties);

NTSTATUS NTAPI
PciIdeXInitialize(
  IN PDRIVER_OBJECT DriverObject,
  IN PUNICODE_STRING RegistryPath,
  IN PCONTROLLER_PROPERTIES HwGetControllerProperties,
  IN ULONG ExtensionSize);

NTSTATUS NTAPI
PciIdeXGetBusData(
  IN PVOID DeviceExtension,
  IN PVOID Buffer,
  IN ULONG ConfigDataOffset,
  IN ULONG BufferLength);

NTSTATUS NTAPI
PciIdeXSetBusData(
  IN PVOID DeviceExtension,
  IN PVOID Buffer,
  IN PVOID DataMask,
  IN ULONG ConfigDataOffset,
  IN ULONG BufferLength);

/* Bit field values for
 * PCIIDE_TRANSFER_MODE_SELECT.DeviceTransferModeSupported and
 * IDE_CONTROLLER_PROPERTIES.SupportedTransferMode
 */
// PIO Modes
#define PIO_MODE0   (1 << 0)
#define PIO_MODE1   (1 << 1)
#define PIO_MODE2   (1 << 2)
#define PIO_MODE3   (1 << 3)
#define PIO_MODE4   (1 << 4)
// Single-word DMA Modes
#define SWDMA_MODE0 (1 << 5)
#define SWDMA_MODE1 (1 << 6)
#define SWDMA_MODE2 (1 << 7)
// Multi-word DMA Modes
#define MWDMA_MODE0 (1 << 8)
#define MWDMA_MODE1 (1 << 9)
#define MWDMA_MODE2 (1 << 10)
// Ultra DMA Modes
#define UDMA_MODE0  (1 << 11)
#define UDMA_MODE1  (1 << 12)
#define UDMA_MODE2  (1 << 13)
#define UDMA_MODE3  (1 << 14)
#define UDMA_MODE4  (1 << 15)
#define UDMA_MODE5  (1 << 16)

#ifdef __cplusplus
}
#endif

#endif /* __IDE_H */
