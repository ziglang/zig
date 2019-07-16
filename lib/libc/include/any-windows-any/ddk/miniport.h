/*
 * miniport.h
 *
 * Type definitions for miniport drivers
 *
 * This file is part of the w32api package.
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

#ifndef _MINIPORT_
#define _MINIPORT_

#ifdef __cplusplus
extern "C" {
#endif

#define EMULATOR_READ_ACCESS              0x01
#define EMULATOR_WRITE_ACCESS             0x02

typedef enum _EMULATOR_PORT_ACCESS_TYPE {
	Uchar,
	Ushort,
	Ulong
} EMULATOR_PORT_ACCESS_TYPE, *PEMULATOR_PORT_ACCESS_TYPE;


typedef struct _EMULATOR_ACCESS_ENTRY {
  ULONG  BasePort;
  ULONG  NumConsecutivePorts;
  EMULATOR_PORT_ACCESS_TYPE  AccessType;
  UCHAR  AccessMode;
  UCHAR  StringSupport;
  PVOID  Routine;
} EMULATOR_ACCESS_ENTRY, *PEMULATOR_ACCESS_ENTRY;

typedef VOID
(NTAPI *PBANKED_SECTION_ROUTINE)(
  IN ULONG  ReadBank,
  IN ULONG  WriteBank,
  IN PVOID  Context);

#ifndef __BROKEN__

typedef enum _INTERFACE_TYPE {
    InterfaceTypeUndefined = -1,
    Internal,
    Isa,
    Eisa,
    MicroChannel,
    TurboChannel,
    PCIBus,
    VMEBus,
    NuBus,
    PCMCIABus,
    CBus,
    MPIBus,
    MPSABus,
    ProcessorInternal,
    InternalPowerBus,
    PNPISABus,
    PNPBus,
    Vmcs,
    MaximumInterfaceType
}INTERFACE_TYPE, *PINTERFACE_TYPE;

typedef enum _KINTERRUPT_MODE {
    LevelSensitive,
    Latched
} KINTERRUPT_MODE;

typedef VOID (*PINTERFACE_REFERENCE)(PVOID Context);
typedef VOID (*PINTERFACE_DEREFERENCE)(PVOID Context);

typedef enum _BUS_DATA_TYPE {
    ConfigurationSpaceUndefined = -1,
    Cmos,
    EisaConfiguration,
    Pos,
    CbusConfiguration,
    PCIConfiguration,
    VMEConfiguration,
    NuBusConfiguration,
    PCMCIAConfiguration,
    MPIConfiguration,
    MPSAConfiguration,
    PNPISAConfiguration,
    SgiInternalConfiguration,
    MaximumBusDataType
} BUS_DATA_TYPE, *PBUS_DATA_TYPE;

typedef enum _DMA_WIDTH {
    Width8Bits,
    Width16Bits,
    Width32Bits,
    MaximumDmaWidth
}DMA_WIDTH, *PDMA_WIDTH;

typedef enum _DMA_SPEED {
    Compatible,
    TypeA,
    TypeB,
    TypeC,
    TypeF,
    MaximumDmaSpeed
}DMA_SPEED, *PDMA_SPEED;

typedef struct _INTERFACE {
    USHORT Size;
    USHORT Version;
    PVOID Context;
    PINTERFACE_REFERENCE InterfaceReference;
    PINTERFACE_DEREFERENCE InterfaceDereference;
} INTERFACE, *PINTERFACE;

typedef enum _IRQ_DEVICE_POLICY {
    IrqPolicyMachineDefault = 0,
    IrqPolicyAllCloseProcessors,
    IrqPolicyOneCloseProcessor,
    IrqPolicyAllProcessorsInMachine,
    IrqPolicySpecifiedProcessors,
    IrqPolicySpreadMessagesAcrossAllProcessors
} IRQ_DEVICE_POLICY, *PIRQ_DEVICE_POLICY;

typedef enum _IRQ_PRIORITY {
    IrqPriorityUndefined = 0,
    IrqPriorityLow,
    IrqPriorityNormal,
    IrqPriorityHigh
} IRQ_PRIORITY, *PIRQ_PRIORITY;

typedef struct _IO_RESOURCE_DESCRIPTOR {
    UCHAR Option;
    UCHAR Type;                         // use CM_RESOURCE_TYPE
    UCHAR ShareDisposition;             // use CM_SHARE_DISPOSITION
    UCHAR Spare1;
    USHORT Flags;                       // use CM resource flag defines
    USHORT Spare2;                      // align

    union {
        struct {
            ULONG Length;
            ULONG Alignment;
            PHYSICAL_ADDRESS MinimumAddress;
            PHYSICAL_ADDRESS MaximumAddress;
        } Port;

        struct {
            ULONG Length;
            ULONG Alignment;
            PHYSICAL_ADDRESS MinimumAddress;
            PHYSICAL_ADDRESS MaximumAddress;
        } Memory;

        struct {
            ULONG MinimumVector;
            ULONG MaximumVector;
            IRQ_DEVICE_POLICY AffinityPolicy;
            IRQ_PRIORITY PriorityPolicy;
            KAFFINITY TargetedProcessors;
        } Interrupt;

        struct {
            ULONG MinimumChannel;
            ULONG MaximumChannel;
        } Dma;

        struct {
            ULONG Length;
            ULONG Alignment;
            PHYSICAL_ADDRESS MinimumAddress;
            PHYSICAL_ADDRESS MaximumAddress;
        } Generic;

        struct {
            ULONG Data[3];
        } DevicePrivate;

        //
        // Bus Number information.
        //

        struct {
            ULONG Length;
            ULONG MinBusNumber;
            ULONG MaxBusNumber;
            ULONG Reserved;
        } BusNumber;

        struct {
            ULONG Priority;   // use LCPRI_Xxx values in cfg.h
            ULONG Reserved1;
            ULONG Reserved2;
        } ConfigData;

        //
        // The following structures provide descriptions
        // for memory resource requirement greater than MAXULONG
        //

        struct {
            ULONG Length40;
            ULONG Alignment40;
            PHYSICAL_ADDRESS MinimumAddress;
            PHYSICAL_ADDRESS MaximumAddress;
        } Memory40;

        struct {
            ULONG Length48;
            ULONG Alignment48;
            PHYSICAL_ADDRESS MinimumAddress;
            PHYSICAL_ADDRESS MaximumAddress;
        } Memory48;

        struct {
            ULONG Length64;
            ULONG Alignment64;
            PHYSICAL_ADDRESS MinimumAddress;
            PHYSICAL_ADDRESS MaximumAddress;
        } Memory64;

    } u;

} IO_RESOURCE_DESCRIPTOR, *PIO_RESOURCE_DESCRIPTOR;

#include <guiddef.h>
#endif /* ! __BROKEN__ */

#ifdef __cplusplus
}
#endif

#endif /* __MINIPORT_H */
