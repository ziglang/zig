/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _CFGMGR32_H_
#define _CFGMGR32_H_

#include <_mingw_unicode.h>
#include <cfg.h>
#include <guiddef.h>
#include <apisetcconv.h>

#ifdef __cplusplus
extern "C" {
#endif

  typedef CONST VOID *PCVOID;

#define MAX_DEVICE_ID_LEN 200
#define MAX_DEVNODE_ID_LEN MAX_DEVICE_ID_LEN
#define MAX_GUID_STRING_LEN 39
#define MAX_CLASS_NAME_LEN 32
#define MAX_PROFILE_LEN 80
#define MAX_CONFIG_VALUE 9999
#define MAX_INSTANCE_VALUE 9999
#define MAX_MEM_REGISTERS 9
#define MAX_IO_PORTS 20
#define MAX_IRQS 7
#define MAX_DMA_CHANNELS 7

#define DWORD_MAX 0xFFFFFFFF
#define DWORDLONG_MAX 0xFFFFFFFFFFFFFFFF

#define CONFIGMG_VERSION 0x0400

#ifdef NT_INCLUDED
  __MINGW_EXTENSION typedef unsigned __int64 DWORDLONG;
  typedef DWORDLONG *PDWORDLONG;
#endif

  typedef DWORD RETURN_TYPE;
  typedef RETURN_TYPE CONFIGRET;
  typedef DWORD DEVNODE,DEVINST;
  typedef DEVNODE *PDEVNODE,*PDEVINST;
  typedef CHAR *DEVNODEID_A,*DEVINSTID_A;
  typedef WCHAR *DEVNODEID_W,*DEVINSTID_W;

  __MINGW_TYPEDEF_UAW(DEVNODEID)
  __MINGW_TYPEDEF_UAW(DEVINSTID)

  typedef DWORD_PTR LOG_CONF;
  typedef LOG_CONF *PLOG_CONF;
  typedef DWORD_PTR RES_DES;
  typedef RES_DES *PRES_DES;
  typedef ULONG RESOURCEID;
  typedef RESOURCEID *PRESOURCEID;
  typedef ULONG PRIORITY;
  typedef PRIORITY *PPRIORITY;
  typedef DWORD_PTR RANGE_LIST;
  typedef RANGE_LIST *PRANGE_LIST;
  typedef DWORD_PTR RANGE_ELEMENT;
  typedef RANGE_ELEMENT *PRANGE_ELEMENT;
  typedef HANDLE HMACHINE;
  typedef HMACHINE *PHMACHINE;
  typedef ULONG_PTR CONFLICT_LIST;
  typedef CONFLICT_LIST *PCONFLICT_LIST;

  typedef struct _CONFLICT_DETAILS_A {
    ULONG CD_ulSize;
    ULONG CD_ulMask;
    DEVINST CD_dnDevInst;
    RES_DES CD_rdResDes;
    ULONG CD_ulFlags;
    CHAR CD_szDescription[MAX_PATH];
  } CONFLICT_DETAILS_A ,*PCONFLICT_DETAILS_A;

  typedef struct _CONFLICT_DETAILS_W {
    ULONG CD_ulSize;
    ULONG CD_ulMask;
    DEVINST CD_dnDevInst;
    RES_DES CD_rdResDes;
    ULONG CD_ulFlags;
    WCHAR CD_szDescription[MAX_PATH];
  } CONFLICT_DETAILS_W ,*PCONFLICT_DETAILS_W;

  __MINGW_TYPEDEF_UAW(CONFLICT_DETAILS)
  __MINGW_TYPEDEF_UAW(PCONFLICT_DETAILS)

#define CM_CDMASK_DEVINST (0x00000001)
#define CM_CDMASK_RESDES (0x00000002)
#define CM_CDMASK_FLAGS (0x00000004)
#define CM_CDMASK_DESCRIPTION (0x00000008)
#define CM_CDMASK_VALID (0x0000000F)

#define CM_CDFLAGS_DRIVER (0x00000001)
#define CM_CDFLAGS_ROOT_OWNED (0x00000002)
#define CM_CDFLAGS_RESERVED (0x00000004)

  typedef ULONG REGDISPOSITION;

#include "pshpack1.h"

#define mMD_MemoryType (0x1)
#define fMD_MemoryType mMD_MemoryType
#define fMD_ROM (0x0)
#define fMD_RAM (0x1)

#define mMD_32_24 (0x2)
#define fMD_32_24 mMD_32_24
#define fMD_24 (0x0)
#define fMD_32 (0x2)

#define mMD_Prefetchable (0x4)
#define fMD_Prefetchable mMD_Prefetchable
#define fMD_Pref mMD_Prefetchable
#define fMD_PrefetchDisallowed (0x0)
#define fMD_PrefetchAllowed (0x4)

#define mMD_Readable (0x8)
#define fMD_Readable mMD_Readable
#define fMD_ReadAllowed (0x0)
#define fMD_ReadDisallowed (0x8)

#define mMD_CombinedWrite (0x10)
#define fMD_CombinedWrite mMD_CombinedWrite
#define fMD_CombinedWriteDisallowed (0x0)
#define fMD_CombinedWriteAllowed (0x10)

#define mMD_Cacheable (0x20)
#define fMD_NonCacheable (0x0)
#define fMD_Cacheable (0x20)

  typedef struct Mem_Range_s {
    DWORDLONG MR_Align;
    ULONG MR_nBytes;
    DWORDLONG MR_Min;
    DWORDLONG MR_Max;
    DWORD MR_Flags;
    DWORD MR_Reserved;
  } MEM_RANGE,*PMEM_RANGE;

  typedef struct Mem_Des_s {
    DWORD MD_Count;
    DWORD MD_Type;
    DWORDLONG MD_Alloc_Base;
    DWORDLONG MD_Alloc_End;
    DWORD MD_Flags;
    DWORD MD_Reserved;
  } MEM_DES,*PMEM_DES;

  typedef struct Mem_Resource_s {
    MEM_DES MEM_Header;
    MEM_RANGE MEM_Data[ANYSIZE_ARRAY];
  } MEM_RESOURCE,*PMEM_RESOURCE;

#define MType_Range sizeof(struct Mem_Range_s)

#define fIOD_PortType (0x1)
#define fIOD_Memory (0x0)
#define fIOD_IO (0x1)
#define fIOD_DECODE (0x00fc)
#define fIOD_10_BIT_DECODE (0x0004)
#define fIOD_12_BIT_DECODE (0x0008)
#define fIOD_16_BIT_DECODE (0x0010)
#define fIOD_POSITIVE_DECODE (0x0020)
#define fIOD_PASSIVE_DECODE (0x0040)
#define fIOD_WINDOW_DECODE (0x0080)

#define IO_ALIAS_10_BIT_DECODE (0x00000004)
#define IO_ALIAS_12_BIT_DECODE (0x00000010)
#define IO_ALIAS_16_BIT_DECODE (0x00000000)
#define IO_ALIAS_POSITIVE_DECODE (0x000000FF)

  typedef struct IO_Range_s {
    DWORDLONG IOR_Align;
    DWORD IOR_nPorts;
    DWORDLONG IOR_Min;
    DWORDLONG IOR_Max;
    DWORD IOR_RangeFlags;
    DWORDLONG IOR_Alias;
  } IO_RANGE,*PIO_RANGE;

  typedef struct IO_Des_s {
    DWORD IOD_Count;
    DWORD IOD_Type;
    DWORDLONG IOD_Alloc_Base;
    DWORDLONG IOD_Alloc_End;
    DWORD IOD_DesFlags;
  } IO_DES,*PIO_DES;

  typedef struct IO_Resource_s {
    IO_DES IO_Header;
    IO_RANGE IO_Data[ANYSIZE_ARRAY];
  } IO_RESOURCE,*PIO_RESOURCE;

#define IOA_Local 0xff

#define IOType_Range sizeof(struct IO_Range_s)

#define mDD_Width (0x3)
#define fDD_BYTE (0x0)
#define fDD_WORD (0x1)
#define fDD_DWORD (0x2)
#define fDD_BYTE_AND_WORD (0x3)

#define mDD_BusMaster (0x4)
#define fDD_NoBusMaster (0x0)
#define fDD_BusMaster (0x4)

#define mDD_Type (0x18)
#define fDD_TypeStandard (0x00)
#define fDD_TypeA (0x08)
#define fDD_TypeB (0x10)
#define fDD_TypeF (0x18)

  typedef struct DMA_Range_s {
    ULONG DR_Min;
    ULONG DR_Max;
    ULONG DR_Flags;
  } DMA_RANGE,*PDMA_RANGE;

  typedef struct DMA_Des_s {
    DWORD DD_Count;
    DWORD DD_Type;
    DWORD DD_Flags;
    ULONG DD_Alloc_Chan;
  } DMA_DES,*PDMA_DES;

  typedef struct DMA_Resource_s {
    DMA_DES DMA_Header;
    DMA_RANGE DMA_Data[ANYSIZE_ARRAY];
  } DMA_RESOURCE,*PDMA_RESOURCE;

#define DType_Range sizeof(struct DMA_Range_s)

#define mIRQD_Share (0x1)
#define fIRQD_Exclusive (0x0)
#define fIRQD_Share (0x1)

#define fIRQD_Share_Bit 0
#define fIRQD_Level_Bit 1

#define mIRQD_Edge_Level (0x2)
#define fIRQD_Level (0x0)
#define fIRQD_Edge (0x2)

  typedef struct IRQ_Range_s {
    ULONG IRQR_Min;
    ULONG IRQR_Max;
    ULONG IRQR_Flags;
  } IRQ_RANGE,*PIRQ_RANGE;

  typedef struct IRQ_Des_32_s {
    DWORD IRQD_Count;
    DWORD IRQD_Type;
    DWORD IRQD_Flags;
    ULONG IRQD_Alloc_Num;
    ULONG32 IRQD_Affinity;
  } IRQ_DES_32,*PIRQ_DES_32;

  typedef struct IRQ_Des_64_s {
    DWORD IRQD_Count;
    DWORD IRQD_Type;
    DWORD IRQD_Flags;
    ULONG IRQD_Alloc_Num;
    ULONG64 IRQD_Affinity;
  } IRQ_DES_64,*PIRQ_DES_64;

#ifdef _WIN64
  typedef IRQ_DES_64 IRQ_DES;
  typedef PIRQ_DES_64 PIRQ_DES;
#else
  typedef IRQ_DES_32 IRQ_DES;
  typedef PIRQ_DES_32 PIRQ_DES;
#endif

  typedef struct IRQ_Resource_32_s {
    IRQ_DES_32 IRQ_Header;
    IRQ_RANGE IRQ_Data[ANYSIZE_ARRAY];
  } IRQ_RESOURCE_32,*PIRQ_RESOURCE_32;

  typedef struct IRQ_Resource_64_s {
    IRQ_DES_64 IRQ_Header;
    IRQ_RANGE IRQ_Data[ANYSIZE_ARRAY];
  } IRQ_RESOURCE_64,*PIRQ_RESOURCE_64;

#ifdef _WIN64
  typedef IRQ_RESOURCE_64 IRQ_RESOURCE;
  typedef PIRQ_RESOURCE_64 PIRQ_RESOURCE;
#else
  typedef IRQ_RESOURCE_32 IRQ_RESOURCE;
  typedef PIRQ_RESOURCE_32 PIRQ_RESOURCE;
#endif

#define IRQType_Range sizeof(struct IRQ_Range_s)

#define CM_RESDES_WIDTH_DEFAULT (0x00000000)
#define CM_RESDES_WIDTH_32 (0x00000001)
#define CM_RESDES_WIDTH_64 (0x00000002)
#define CM_RESDES_WIDTH_BITS (0x00000003)

  typedef struct DevPrivate_Range_s {
    DWORD PR_Data1;
    DWORD PR_Data2;
    DWORD PR_Data3;
  } DEVPRIVATE_RANGE,*PDEVPRIVATE_RANGE;

  typedef struct DevPrivate_Des_s {
    DWORD PD_Count;
    DWORD PD_Type;
    DWORD PD_Data1;
    DWORD PD_Data2;
    DWORD PD_Data3;
    DWORD PD_Flags;
  } DEVPRIVATE_DES,*PDEVPRIVATE_DES;

  typedef struct DevPrivate_Resource_s {
    DEVPRIVATE_DES PRV_Header;
    DEVPRIVATE_RANGE PRV_Data[ANYSIZE_ARRAY];
  } DEVPRIVATE_RESOURCE,*PDEVPRIVATE_RESOURCE;

#define PType_Range sizeof(struct DevPrivate_Range_s)

  typedef struct CS_Des_s {
    DWORD CSD_SignatureLength;
    DWORD CSD_LegacyDataOffset;
    DWORD CSD_LegacyDataSize;
    DWORD CSD_Flags;
    GUID CSD_ClassGuid;
    BYTE CSD_Signature[ANYSIZE_ARRAY];
  } CS_DES,*PCS_DES;

  typedef struct CS_Resource_s {
    CS_DES CS_Header;
  } CS_RESOURCE,*PCS_RESOURCE;

#define mPCD_IO_8_16 (0x1)
#define fPCD_IO_8 (0x0)
#define fPCD_IO_16 (0x1)
#define mPCD_MEM_8_16 (0x2)
#define fPCD_MEM_8 (0x0)
#define fPCD_MEM_16 (0x2)
#define mPCD_MEM_A_C (0xC)
#define fPCD_MEM1_A (0x4)
#define fPCD_MEM2_A (0x8)
#define fPCD_IO_ZW_8 (0x10)
#define fPCD_IO_SRC_16 (0x20)
#define fPCD_IO_WS_16 (0x40)
#define mPCD_MEM_WS (0x300)
#define fPCD_MEM_WS_ONE (0x100)
#define fPCD_MEM_WS_TWO (0x200)
#define fPCD_MEM_WS_THREE (0x300)

#define fPCD_MEM_A (0x4)

#define fPCD_ATTRIBUTES_PER_WINDOW (0x8000)

#define fPCD_IO1_16 (0x00010000)
#define fPCD_IO1_ZW_8 (0x00020000)
#define fPCD_IO1_SRC_16 (0x00040000)
#define fPCD_IO1_WS_16 (0x00080000)

#define fPCD_IO2_16 (0x00100000)
#define fPCD_IO2_ZW_8 (0x00200000)
#define fPCD_IO2_SRC_16 (0x00400000)
#define fPCD_IO2_WS_16 (0x00800000)

#define mPCD_MEM1_WS (0x03000000)
#define fPCD_MEM1_WS_ONE (0x01000000)
#define fPCD_MEM1_WS_TWO (0x02000000)
#define fPCD_MEM1_WS_THREE (0x03000000)
#define fPCD_MEM1_16 (0x04000000)

#define mPCD_MEM2_WS (0x30000000)
#define fPCD_MEM2_WS_ONE (0x10000000)
#define fPCD_MEM2_WS_TWO (0x20000000)
#define fPCD_MEM2_WS_THREE (0x30000000)
#define fPCD_MEM2_16 (0x40000000)

#define PCD_MAX_MEMORY 2
#define PCD_MAX_IO 2

  typedef struct PcCard_Des_s {
    DWORD PCD_Count;
    DWORD PCD_Type;
    DWORD PCD_Flags;
    BYTE PCD_ConfigIndex;
    BYTE PCD_Reserved[3];
    DWORD PCD_MemoryCardBase1;
    DWORD PCD_MemoryCardBase2;
    DWORD PCD_MemoryCardBase[PCD_MAX_MEMORY];
    WORD PCD_MemoryFlags[PCD_MAX_MEMORY];
    BYTE PCD_IoFlags[PCD_MAX_IO];
  } PCCARD_DES,*PPCCARD_DES;

  typedef struct PcCard_Resource_s {
    PCCARD_DES PcCard_Header;
  } PCCARD_RESOURCE,*PPCCARD_RESOURCE;

#define mPMF_AUDIO_ENABLE (0x8)
#define fPMF_AUDIO_ENABLE (0x8)

  typedef struct MfCard_Des_s {
    DWORD PMF_Count;
    DWORD PMF_Type;
    DWORD PMF_Flags;
    BYTE PMF_ConfigOptions;
    BYTE PMF_IoResourceIndex;
    BYTE PMF_Reserved[2];
    DWORD PMF_ConfigRegisterBase;
  } MFCARD_DES,*PMFCARD_DES;

  typedef struct MfCard_Resource_s {
    MFCARD_DES MfCard_Header;
  } MFCARD_RESOURCE,*PMFCARD_RESOURCE;

  typedef struct BusNumber_Range_s {
    ULONG BUSR_Min;
    ULONG BUSR_Max;
    ULONG BUSR_nBusNumbers;
    ULONG BUSR_Flags;
  } BUSNUMBER_RANGE,*PBUSNUMBER_RANGE;

  typedef struct BusNumber_Des_s {
    DWORD BUSD_Count;
    DWORD BUSD_Type;
    DWORD BUSD_Flags;
    ULONG BUSD_Alloc_Base;
    ULONG BUSD_Alloc_End;
  } BUSNUMBER_DES,*PBUSNUMBER_DES;

  typedef struct BusNumber_Resource_s {
    BUSNUMBER_DES BusNumber_Header;
    BUSNUMBER_RANGE BusNumber_Data[ANYSIZE_ARRAY];
  } BUSNUMBER_RESOURCE,*PBUSNUMBER_RESOURCE;

#define BusNumberType_Range sizeof(struct BusNumber_Range_s)

#define CM_HWPI_NOT_DOCKABLE (0x00000000)
#define CM_HWPI_UNDOCKED (0x00000001)
#define CM_HWPI_DOCKED (0x00000002)

  typedef struct HWProfileInfo_sA {
    ULONG HWPI_ulHWProfile;
    CHAR HWPI_szFriendlyName[MAX_PROFILE_LEN];
    DWORD HWPI_dwFlags;
  } HWPROFILEINFO_A,*PHWPROFILEINFO_A;

  typedef struct HWProfileInfo_sW {
    ULONG HWPI_ulHWProfile;
    WCHAR HWPI_szFriendlyName[MAX_PROFILE_LEN];
    DWORD HWPI_dwFlags;
  } HWPROFILEINFO_W,*PHWPROFILEINFO_W;

  __MINGW_TYPEDEF_UAW(HWPROFILEINFO)
  __MINGW_TYPEDEF_UAW(PHWPROFILEINFO)

#include "poppack.h"

#define ResType_All (0x00000000)
#define ResType_None (0x00000000)
#define ResType_Mem (0x00000001)
#define ResType_IO (0x00000002)
#define ResType_DMA (0x00000003)
#define ResType_IRQ (0x00000004)
#define ResType_DoNotUse (0x00000005)
#define ResType_BusNumber (0x00000006)
#define ResType_MAX (0x00000006)
#define ResType_Ignored_Bit (0x00008000)
#define ResType_ClassSpecific (0x0000FFFF)
#define ResType_Reserved (0x00008000)
#define ResType_DevicePrivate (0x00008001)
#define ResType_PcCardConfig (0x00008002)
#define ResType_MfCardConfig (0x00008003)

#define CM_ADD_RANGE_ADDIFCONFLICT (0x00000000)
#define CM_ADD_RANGE_DONOTADDIFCONFLICT (0x00000001)
#define CM_ADD_RANGE_BITS (0x00000001)

#define BASIC_LOG_CONF 0x00000000
#define FILTERED_LOG_CONF 0x00000001
#define ALLOC_LOG_CONF 0x00000002
#define BOOT_LOG_CONF 0x00000003
#define FORCED_LOG_CONF 0x00000004
#define OVERRIDE_LOG_CONF 0x00000005
#define NUM_LOG_CONF 0x00000006
#define LOG_CONF_BITS 0x00000007

#define PRIORITY_EQUAL_FIRST (0x00000008)
#define PRIORITY_EQUAL_LAST (0x00000000)
#define PRIORITY_BIT (0x00000008)

#define RegDisposition_OpenAlways (0x00000000)
#define RegDisposition_OpenExisting (0x00000001)
#define RegDisposition_Bits (0x00000001)

#define CM_ADD_ID_HARDWARE (0x00000000)
#define CM_ADD_ID_COMPATIBLE (0x00000001)
#define CM_ADD_ID_BITS (0x00000001)

#define CM_CREATE_DEVNODE_NORMAL (0x00000000)
#define CM_CREATE_DEVNODE_NO_WAIT_INSTALL (0x00000001)
#define CM_CREATE_DEVNODE_PHANTOM (0x00000002)
#define CM_CREATE_DEVNODE_GENERATE_ID (0x00000004)
#define CM_CREATE_DEVNODE_DO_NOT_INSTALL (0x00000008)
#define CM_CREATE_DEVNODE_BITS (0x0000000F)

#define CM_CREATE_DEVINST_NORMAL CM_CREATE_DEVNODE_NORMAL
#define CM_CREATE_DEVINST_NO_WAIT_INSTALL CM_CREATE_DEVNODE_NO_WAIT_INSTALL
#define CM_CREATE_DEVINST_PHANTOM CM_CREATE_DEVNODE_PHANTOM
#define CM_CREATE_DEVINST_GENERATE_ID CM_CREATE_DEVNODE_GENERATE_ID
#define CM_CREATE_DEVINST_DO_NOT_INSTALL CM_CREATE_DEVNODE_DO_NOT_INSTALL
#define CM_CREATE_DEVINST_BITS CM_CREATE_DEVNODE_BITS

#define CM_DELETE_CLASS_ONLY (0x00000000)
#define CM_DELETE_CLASS_SUBKEYS (0x00000001)
#define CM_DELETE_CLASS_BITS (0x00000001)

#define CM_DETECT_NEW_PROFILE (0x00000001)
#define CM_DETECT_CRASHED (0x00000002)
#define CM_DETECT_HWPROF_FIRST_BOOT (0x00000004)
#define CM_DETECT_RUN (0x80000000)
#define CM_DETECT_BITS (0x80000007)

#define CM_DISABLE_POLITE (0x00000000)
#define CM_DISABLE_ABSOLUTE (0x00000001)
#define CM_DISABLE_HARDWARE (0x00000002)
#define CM_DISABLE_UI_NOT_OK (0x00000004)
#define CM_DISABLE_BITS (0x00000007)

#define CM_GETIDLIST_FILTER_NONE (0x00000000)
#define CM_GETIDLIST_FILTER_ENUMERATOR (0x00000001)
#define CM_GETIDLIST_FILTER_SERVICE (0x00000002)
#define CM_GETIDLIST_FILTER_EJECTRELATIONS (0x00000004)
#define CM_GETIDLIST_FILTER_REMOVALRELATIONS (0x00000008)
#define CM_GETIDLIST_FILTER_POWERRELATIONS (0x00000010)
#define CM_GETIDLIST_FILTER_BUSRELATIONS (0x00000020)
#define CM_GETIDLIST_DONOTGENERATE (0x10000040)
#define CM_GETIDLIST_FILTER_BITS (0x1000007F)

#define CM_GET_DEVICE_INTERFACE_LIST_PRESENT (0x00000000)
#define CM_GET_DEVICE_INTERFACE_LIST_ALL_DEVICES (0x00000001)
#define CM_GET_DEVICE_INTERFACE_LIST_BITS (0x00000001)

#define CM_DRP_DEVICEDESC (0x00000001)
#define CM_DRP_HARDWAREID (0x00000002)
#define CM_DRP_COMPATIBLEIDS (0x00000003)
#define CM_DRP_UNUSED0 (0x00000004)
#define CM_DRP_SERVICE (0x00000005)
#define CM_DRP_UNUSED1 (0x00000006)
#define CM_DRP_UNUSED2 (0x00000007)
#define CM_DRP_CLASS (0x00000008)
#define CM_DRP_CLASSGUID (0x00000009)
#define CM_DRP_DRIVER (0x0000000A)
#define CM_DRP_CONFIGFLAGS (0x0000000B)
#define CM_DRP_MFG (0x0000000C)
#define CM_DRP_FRIENDLYNAME (0x0000000D)
#define CM_DRP_LOCATION_INFORMATION (0x0000000E)
#define CM_DRP_PHYSICAL_DEVICE_OBJECT_NAME (0x0000000F)
#define CM_DRP_CAPABILITIES (0x00000010)
#define CM_DRP_UI_NUMBER (0x00000011)
#define CM_DRP_UPPERFILTERS (0x00000012)
#define CM_DRP_LOWERFILTERS (0x00000013)
#define CM_DRP_BUSTYPEGUID (0x00000014)
#define CM_DRP_LEGACYBUSTYPE (0x00000015)
#define CM_DRP_BUSNUMBER (0x00000016)
#define CM_DRP_ENUMERATOR_NAME (0x00000017)
#define CM_DRP_SECURITY (0x00000018)
#define CM_CRP_SECURITY CM_DRP_SECURITY
#define CM_DRP_SECURITY_SDS (0x00000019)
#define CM_CRP_SECURITY_SDS CM_DRP_SECURITY_SDS
#define CM_DRP_DEVTYPE (0x0000001A)
#define CM_CRP_DEVTYPE CM_DRP_DEVTYPE
#define CM_DRP_EXCLUSIVE (0x0000001B)
#define CM_CRP_EXCLUSIVE CM_DRP_EXCLUSIVE
#define CM_DRP_CHARACTERISTICS (0x0000001C)
#define CM_CRP_CHARACTERISTICS CM_DRP_CHARACTERISTICS
#define CM_DRP_ADDRESS (0x0000001D)
#define CM_DRP_UI_NUMBER_DESC_FORMAT (0x0000001E)
#define CM_DRP_DEVICE_POWER_DATA (0x0000001F)
#define CM_DRP_REMOVAL_POLICY (0x00000020)
#define CM_DRP_REMOVAL_POLICY_HW_DEFAULT (0x00000021)
#define CM_DRP_REMOVAL_POLICY_OVERRIDE (0x00000022)
#define CM_DRP_INSTALL_STATE (0x00000023)

#define CM_DRP_MIN (0x00000001)
#define CM_CRP_MIN CM_DRP_MIN
#define CM_DRP_MAX (0x00000023)
#define CM_CRP_MAX CM_DRP_MAX

#define CM_DEVCAP_LOCKSUPPORTED (0x00000001)
#define CM_DEVCAP_EJECTSUPPORTED (0x00000002)
#define CM_DEVCAP_REMOVABLE (0x00000004)
#define CM_DEVCAP_DOCKDEVICE (0x00000008)
#define CM_DEVCAP_UNIQUEID (0x00000010)
#define CM_DEVCAP_SILENTINSTALL (0x00000020)
#define CM_DEVCAP_RAWDEVICEOK (0x00000040)
#define CM_DEVCAP_SURPRISEREMOVALOK (0x00000080)
#define CM_DEVCAP_HARDWAREDISABLED (0x00000100)
#define CM_DEVCAP_NONDYNAMIC (0x00000200)

#define CM_REMOVAL_POLICY_EXPECT_NO_REMOVAL 1
#define CM_REMOVAL_POLICY_EXPECT_ORDERLY_REMOVAL 2
#define CM_REMOVAL_POLICY_EXPECT_SURPRISE_REMOVAL 3

#define CM_INSTALL_STATE_INSTALLED 0
#define CM_INSTALL_STATE_NEEDS_REINSTALL 1
#define CM_INSTALL_STATE_FAILED_INSTALL 2
#define CM_INSTALL_STATE_FINISH_INSTALL 3

#define CM_LOCATE_DEVNODE_NORMAL 0x00000000
#define CM_LOCATE_DEVNODE_PHANTOM 0x00000001
#define CM_LOCATE_DEVNODE_CANCELREMOVE 0x00000002
#define CM_LOCATE_DEVNODE_NOVALIDATION 0x00000004
#define CM_LOCATE_DEVNODE_BITS 0x00000007

#define CM_LOCATE_DEVINST_NORMAL CM_LOCATE_DEVNODE_NORMAL
#define CM_LOCATE_DEVINST_PHANTOM CM_LOCATE_DEVNODE_PHANTOM
#define CM_LOCATE_DEVINST_CANCELREMOVE CM_LOCATE_DEVNODE_CANCELREMOVE
#define CM_LOCATE_DEVINST_NOVALIDATION CM_LOCATE_DEVNODE_NOVALIDATION
#define CM_LOCATE_DEVINST_BITS CM_LOCATE_DEVNODE_BITS

#define CM_OPEN_CLASS_KEY_INSTALLER (0x00000000)
#define CM_OPEN_CLASS_KEY_INTERFACE (0x00000001)
#define CM_OPEN_CLASS_KEY_BITS (0x00000001)

#define CM_REMOVE_UI_OK 0x00000000
#define CM_REMOVE_UI_NOT_OK 0x00000001
#define CM_REMOVE_NO_RESTART 0x00000002
#define CM_REMOVE_BITS 0x00000003

#define CM_QUERY_REMOVE_UI_OK (CM_REMOVE_UI_OK)
#define CM_QUERY_REMOVE_UI_NOT_OK (CM_REMOVE_UI_NOT_OK)
#define CM_QUERY_REMOVE_BITS (CM_QUERY_REMOVE_UI_OK|CM_QUERY_REMOVE_UI_NOT_OK)

#define CM_REENUMERATE_NORMAL 0x00000000
#define CM_REENUMERATE_SYNCHRONOUS 0x00000001
#define CM_REENUMERATE_RETRY_INSTALLATION 0x00000002
#define CM_REENUMERATE_ASYNCHRONOUS 0x00000004
#define CM_REENUMERATE_BITS 0x00000007

#define CM_REGISTER_DEVICE_DRIVER_STATIC (0x00000000)
#define CM_REGISTER_DEVICE_DRIVER_DISABLEABLE (0x00000001)
#define CM_REGISTER_DEVICE_DRIVER_REMOVABLE (0x00000002)
#define CM_REGISTER_DEVICE_DRIVER_BITS (0x00000003)

#define CM_REGISTRY_HARDWARE (0x00000000)
#define CM_REGISTRY_SOFTWARE (0x00000001)
#define CM_REGISTRY_USER (0x00000100)
#define CM_REGISTRY_CONFIG (0x00000200)
#define CM_REGISTRY_BITS (0x00000301)

#define CM_SET_DEVNODE_PROBLEM_NORMAL (0x00000000)
#define CM_SET_DEVNODE_PROBLEM_OVERRIDE (0x00000001)
#define CM_SET_DEVNODE_PROBLEM_BITS (0x00000001)

#define CM_SET_DEVINST_PROBLEM_NORMAL CM_SET_DEVNODE_PROBLEM_NORMAL
#define CM_SET_DEVINST_PROBLEM_OVERRIDE CM_SET_DEVNODE_PROBLEM_OVERRIDE
#define CM_SET_DEVINST_PROBLEM_BITS CM_SET_DEVNODE_PROBLEM_BITS

#define CM_SET_HW_PROF_FLAGS_UI_NOT_OK (0x00000001)
#define CM_SET_HW_PROF_FLAGS_BITS (0x00000001)

#define CM_SETUP_DEVNODE_READY (0x00000000)
#define CM_SETUP_DEVINST_READY CM_SETUP_DEVNODE_READY
#define CM_SETUP_DOWNLOAD (0x00000001)
#define CM_SETUP_WRITE_LOG_CONFS (0x00000002)
#define CM_SETUP_PROP_CHANGE (0x00000003)
#define CM_SETUP_DEVNODE_RESET (0x00000004)
#define CM_SETUP_DEVINST_RESET CM_SETUP_DEVNODE_RESET
#define CM_SETUP_BITS (0x00000007)

#define CM_QUERY_ARBITRATOR_RAW (0x00000000)
#define CM_QUERY_ARBITRATOR_TRANSLATED (0x00000001)
#define CM_QUERY_ARBITRATOR_BITS (0x00000001)

#define CM_CUSTOMDEVPROP_MERGE_MULTISZ (0x00000001)
#define CM_CUSTOMDEVPROP_BITS (0x00000001)

#define CM_Add_ID __MINGW_NAME_AW(CM_Add_ID)
#define CM_Add_ID_Ex __MINGW_NAME_AW(CM_Add_ID_Ex)
#define CM_Connect_Machine __MINGW_NAME_AW(CM_Connect_Machine)
#define CM_Create_DevNode __MINGW_NAME_AW(CM_Create_DevNode)
#define CM_Create_DevInst __MINGW_NAME_AW(CM_Create_DevNode)
#define CM_Create_DevNode_Ex __MINGW_NAME_AW(CM_Create_DevNode_Ex)
#define CM_Create_DevInst_Ex __MINGW_NAME_AW(CM_Create_DevInst_Ex)
#define CM_Enumerate_Enumerators __MINGW_NAME_AW(CM_Enumerate_Enumerators)
#define CM_Enumerate_Enumerators_Ex __MINGW_NAME_AW(CM_Enumerate_Enumerators_Ex)
#define CM_Get_Class_Name __MINGW_NAME_AW(CM_Get_Class_Name)
#define CM_Get_Class_Name_Ex __MINGW_NAME_AW(CM_Get_Class_Name_Ex)
#define CM_Get_Class_Key_Name __MINGW_NAME_AW(CM_Get_Class_Key_Name)
#define CM_Get_Class_Key_Name_Ex __MINGW_NAME_AW(CM_Get_Class_Key_Name_Ex)
#define CM_Get_Device_ID __MINGW_NAME_AW(CM_Get_Device_ID)
#define CM_Get_Device_ID_Ex __MINGW_NAME_AW(CM_Get_Device_ID_Ex)
#define CM_Get_Device_ID_List __MINGW_NAME_AW(CM_Get_Device_ID_List)
#define CM_Get_Device_ID_List_Ex __MINGW_NAME_AW(CM_Get_Device_ID_List_Ex)
#define CM_Get_Device_ID_List_Size __MINGW_NAME_AW(CM_Get_Device_ID_List_Size)
#define CM_Get_Device_ID_List_Size_Ex __MINGW_NAME_AW(CM_Get_Device_ID_List_Size_Ex)
#define CM_Get_DevInst_Registry_Property __MINGW_NAME_AW(CM_Get_DevNode_Registry_Property)
#define CM_Get_DevInst_Registry_Property_Ex __MINGW_NAME_AW(CM_Get_DevNode_Registry_Property_Ex)
#define CM_Get_DevNode_Registry_Property __MINGW_NAME_AW(CM_Get_DevNode_Registry_Property)
#define CM_Get_DevNode_Registry_Property_Ex __MINGW_NAME_AW(CM_Get_DevNode_Registry_Property_Ex)
#define CM_Get_DevInst_Custom_Property __MINGW_NAME_AW(CM_Get_DevNode_Custom_Property)
#define CM_Get_DevInst_Custom_Property_Ex __MINGW_NAME_AW(CM_Get_DevNode_Custom_Property_Ex)
#define CM_Get_DevNode_Custom_Property __MINGW_NAME_AW(CM_Get_DevNode_Custom_Property)
#define CM_Get_DevNode_Custom_Property_Ex __MINGW_NAME_AW(CM_Get_DevNode_Custom_Property_Ex)
#define CM_Get_Hardware_Profile_Info __MINGW_NAME_AW(CM_Get_Hardware_Profile_Info)
#define CM_Get_Hardware_Profile_Info_Ex __MINGW_NAME_AW(CM_Get_Hardware_Profile_Info_Ex)
#define CM_Get_HW_Prof_Flags __MINGW_NAME_AW(CM_Get_HW_Prof_Flags)
#define CM_Get_HW_Prof_Flags_Ex __MINGW_NAME_AW(CM_Get_HW_Prof_Flags_Ex)
#define CM_Get_Device_Interface_Alias __MINGW_NAME_AW(CM_Get_Device_Interface_Alias)
#define CM_Get_Device_Interface_Alias_Ex __MINGW_NAME_AW(CM_Get_Device_Interface_Alias_Ex)
#define CM_Get_Device_Interface_List __MINGW_NAME_AW(CM_Get_Device_Interface_List)
#define CM_Get_Device_Interface_List_Ex __MINGW_NAME_AW(CM_Get_Device_Interface_List_Ex)
#define CM_Get_Device_Interface_List_Size __MINGW_NAME_AW(CM_Get_Device_Interface_List_Size)
#define CM_Get_Device_Interface_List_Size_Ex __MINGW_NAME_AW(CM_Get_Device_Interface_List_Size_Ex)
#define CM_Locate_DevNode __MINGW_NAME_AW(CM_Locate_DevNode)
#define CM_Locate_DevInst __MINGW_NAME_AW(CM_Locate_DevNode)
#define CM_Locate_DevNode_Ex __MINGW_NAME_AW(CM_Locate_DevNode_Ex)
#define CM_Locate_DevInst_Ex __MINGW_NAME_AW(CM_Locate_DevNode_Ex)
#define CM_Open_Class_Key __MINGW_NAME_AW(CM_Open_Class_Key)
#define CM_Open_Class_Key_Ex __MINGW_NAME_AW(CM_Open_Class_Key_Ex)
#define CM_Query_And_Remove_SubTree __MINGW_NAME_AW(CM_Query_And_Remove_SubTree)
#define CM_Query_And_Remove_SubTree_Ex __MINGW_NAME_AW(CM_Query_And_Remove_SubTree_Ex)
#define CM_Request_Device_Eject __MINGW_NAME_AW(CM_Request_Device_Eject)
#define CM_Request_Device_Eject_Ex __MINGW_NAME_AW(CM_Request_Device_Eject_Ex)
#define CM_Register_Device_Interface __MINGW_NAME_AW(CM_Register_Device_Interface)
#define CM_Register_Device_Interface_Ex __MINGW_NAME_AW(CM_Register_Device_Interface_Ex)
#define CM_Unregister_Device_Interface __MINGW_NAME_AW(CM_Unregister_Device_Interface)
#define CM_Unregister_Device_Interface_Ex __MINGW_NAME_AW(CM_Unregister_Device_Interface_Ex)
#define CM_Set_DevInst_Registry_Property __MINGW_NAME_AW(CM_Set_DevNode_Registry_Property)
#define CM_Set_DevInst_Registry_Property_Ex __MINGW_NAME_AW(CM_Set_DevNode_Registry_Property_Ex)
#define CM_Set_DevNode_Registry_Property __MINGW_NAME_AW(CM_Set_DevNode_Registry_Property)
#define CM_Set_DevNode_Registry_Property_Ex __MINGW_NAME_AW(CM_Set_DevNode_Registry_Property_Ex)
#define CM_Set_HW_Prof_Flags __MINGW_NAME_AW(CM_Set_HW_Prof_Flags)
#define CM_Set_HW_Prof_Flags_Ex __MINGW_NAME_AW(CM_Set_HW_Prof_Flags_Ex)
#define CM_Get_Resource_Conflict_Details __MINGW_NAME_AW(CM_Get_Resource_Conflict_Details)
#define CM_Get_Class_Registry_Property __MINGW_NAME_AW(CM_Get_Class_Registry_Property)
#define CM_Set_Class_Registry_Property __MINGW_NAME_AW(CM_Set_Class_Registry_Property)

  CMAPI CONFIGRET WINAPI CM_Add_Empty_Log_Conf(PLOG_CONF plcLogConf,DEVINST dnDevInst,PRIORITY Priority,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Add_Empty_Log_Conf_Ex(PLOG_CONF plcLogConf,DEVINST dnDevInst,PRIORITY Priority,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Add_IDA(DEVINST dnDevInst,PSTR pszID,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Add_IDW(DEVINST dnDevInst,PWSTR pszID,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Add_ID_ExA(DEVINST dnDevInst,PSTR pszID,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Add_ID_ExW(DEVINST dnDevInst,PWSTR pszID,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Add_Range(DWORDLONG ullStartValue,DWORDLONG ullEndValue,RANGE_LIST rlh,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Add_Res_Des(PRES_DES prdResDes,LOG_CONF lcLogConf,RESOURCEID ResourceID,PCVOID ResourceData,ULONG ResourceLen,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Add_Res_Des_Ex(PRES_DES prdResDes,LOG_CONF lcLogConf,RESOURCEID ResourceID,PCVOID ResourceData,ULONG ResourceLen,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Connect_MachineA(PCSTR UNCServerName,PHMACHINE phMachine);
  CMAPI CONFIGRET WINAPI CM_Connect_MachineW(PCWSTR UNCServerName,PHMACHINE phMachine);
  CMAPI CONFIGRET WINAPI CM_Create_DevNodeA(PDEVINST pdnDevInst,DEVINSTID_A pDeviceID,DEVINST dnParent,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Create_DevNodeW(PDEVINST pdnDevInst,DEVINSTID_W pDeviceID,DEVINST dnParent,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Create_DevNode_ExA(PDEVINST pdnDevInst,DEVINSTID_A pDeviceID,DEVINST dnParent,ULONG ulFlags,HANDLE hMachine);
  CMAPI CONFIGRET WINAPI CM_Create_DevNode_ExW(PDEVINST pdnDevInst,DEVINSTID_W pDeviceID,DEVINST dnParent,ULONG ulFlags,HANDLE hMachine);
#define CM_Create_DevInstW CM_Create_DevNodeW
#define CM_Create_DevInstA CM_Create_DevNodeA
#define CM_Create_DevInst_ExW CM_Create_DevNode_ExW
#define CM_Create_DevInst_ExA CM_Create_DevNode_ExA
  CMAPI CONFIGRET WINAPI CM_Create_Range_List(PRANGE_LIST prlh,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Delete_Class_Key(LPGUID ClassGuid,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Delete_Class_Key_Ex(LPGUID ClassGuid,ULONG ulFlags,HANDLE hMachine);
  CMAPI CONFIGRET WINAPI CM_Delete_DevNode_Key(DEVNODE dnDevNode,ULONG ulHardwareProfile,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Delete_DevNode_Key_Ex(DEVNODE dnDevNode,ULONG ulHardwareProfile,ULONG ulFlags,HANDLE hMachine);
#define CM_Delete_DevInst_Key CM_Delete_DevNode_Key
#define CM_Delete_DevInst_Key_Ex CM_Delete_DevNode_Key_Ex
  CMAPI CONFIGRET WINAPI CM_Delete_Range(DWORDLONG ullStartValue,DWORDLONG ullEndValue,RANGE_LIST rlh,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Detect_Resource_Conflict(DEVINST dnDevInst,RESOURCEID ResourceID,PCVOID ResourceData,ULONG ResourceLen,PBOOL pbConflictDetected,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Detect_Resource_Conflict_Ex(DEVINST dnDevInst,RESOURCEID ResourceID,PCVOID ResourceData,ULONG ResourceLen,PBOOL pbConflictDetected,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Disable_DevNode(DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Disable_DevNode_Ex(DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
#define CM_Disable_DevInst CM_Disable_DevNode
#define CM_Disable_DevInst_Ex CM_Disable_DevNode_Ex
  CMAPI CONFIGRET WINAPI CM_Disconnect_Machine(HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Dup_Range_List(RANGE_LIST rlhOld,RANGE_LIST rlhNew,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Enable_DevNode(DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Enable_DevNode_Ex(DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
#define CM_Enable_DevInst CM_Enable_DevNode
#define CM_Enable_DevInst_Ex CM_Enable_DevNode_Ex
  CMAPI CONFIGRET WINAPI CM_Enumerate_Classes(ULONG ulClassIndex,LPGUID ClassGuid,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Enumerate_Classes_Ex(ULONG ulClassIndex,LPGUID ClassGuid,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Enumerate_EnumeratorsA(ULONG ulEnumIndex,PCHAR Buffer,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Enumerate_EnumeratorsW(ULONG ulEnumIndex,PWCHAR Buffer,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Enumerate_Enumerators_ExA(ULONG ulEnumIndex,PCHAR Buffer,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Enumerate_Enumerators_ExW(ULONG ulEnumIndex,PWCHAR Buffer,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Find_Range(PDWORDLONG pullStart,DWORDLONG ullStart,ULONG ulLength,DWORDLONG ullAlignment,DWORDLONG ullEnd,RANGE_LIST rlh,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_First_Range(RANGE_LIST rlh,PDWORDLONG pullStart,PDWORDLONG pullEnd,PRANGE_ELEMENT preElement,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Free_Log_Conf(LOG_CONF lcLogConfToBeFreed,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Free_Log_Conf_Ex(LOG_CONF lcLogConfToBeFreed,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Free_Log_Conf_Handle(LOG_CONF lcLogConf);
  CMAPI CONFIGRET WINAPI CM_Free_Range_List(RANGE_LIST rlh,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Free_Res_Des(PRES_DES prdResDes,RES_DES rdResDes,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Free_Res_Des_Ex(PRES_DES prdResDes,RES_DES rdResDes,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Free_Res_Des_Handle(RES_DES rdResDes);
  CMAPI CONFIGRET WINAPI CM_Get_Child(PDEVINST pdnDevInst,DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Child_Ex(PDEVINST pdnDevInst,DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Class_NameA(LPGUID ClassGuid,PCHAR Buffer,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Class_NameW(LPGUID ClassGuid,PWCHAR Buffer,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Class_Name_ExA(LPGUID ClassGuid,PCHAR Buffer,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Class_Name_ExW(LPGUID ClassGuid,PWCHAR Buffer,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Class_Key_NameA(LPGUID ClassGuid,LPSTR pszKeyName,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Class_Key_NameW(LPGUID ClassGuid,LPWSTR pszKeyName,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Class_Key_Name_ExA(LPGUID ClassGuid,LPSTR pszKeyName,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Class_Key_Name_ExW(LPGUID ClassGuid,LPWSTR pszKeyName,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Depth(PULONG pulDepth,DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Depth_Ex(PULONG pulDepth,DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_IDA(DEVINST dnDevInst,PCHAR Buffer,ULONG BufferLen,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_IDW(DEVINST dnDevInst,PWCHAR Buffer,ULONG BufferLen,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_ExA(DEVINST dnDevInst,PCHAR Buffer,ULONG BufferLen,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_ExW(DEVINST dnDevInst,PWCHAR Buffer,ULONG BufferLen,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_ListA(PCSTR pszFilter,PCHAR Buffer,ULONG BufferLen,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_ListW(PCWSTR pszFilter,PWCHAR Buffer,ULONG BufferLen,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_List_ExA(PCSTR pszFilter,PCHAR Buffer,ULONG BufferLen,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_List_ExW(PCWSTR pszFilter,PWCHAR Buffer,ULONG BufferLen,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_List_SizeA(PULONG pulLen,PCSTR pszFilter,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_List_SizeW(PULONG pulLen,PCWSTR pszFilter,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_List_Size_ExA(PULONG pulLen,PCSTR pszFilter,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_List_Size_ExW(PULONG pulLen,PCWSTR pszFilter,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_Size(PULONG pulLen,DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_ID_Size_Ex(PULONG pulLen,DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_DevNode_Registry_PropertyA(DEVINST dnDevInst,ULONG ulProperty,PULONG pulRegDataType,PVOID Buffer,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_DevNode_Registry_PropertyW(DEVINST dnDevInst,ULONG ulProperty,PULONG pulRegDataType,PVOID Buffer,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_DevNode_Registry_Property_ExA(DEVINST dnDevInst,ULONG ulProperty,PULONG pulRegDataType,PVOID Buffer,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_DevNode_Registry_Property_ExW(DEVINST dnDevInst,ULONG ulProperty,PULONG pulRegDataType,PVOID Buffer,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
#define CM_Get_DevInst_Registry_PropertyW CM_Get_DevNode_Registry_PropertyW
#define CM_Get_DevInst_Registry_PropertyA CM_Get_DevNode_Registry_PropertyA
#define CM_Get_DevInst_Registry_Property_ExW CM_Get_DevNode_Registry_Property_ExW
#define CM_Get_DevInst_Registry_Property_ExA CM_Get_DevNode_Registry_Property_ExA
  CMAPI CONFIGRET WINAPI CM_Get_DevNode_Custom_PropertyA(DEVINST dnDevInst,PCSTR pszCustomPropertyName,PULONG pulRegDataType,PVOID Buffer,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_DevNode_Custom_PropertyW(DEVINST dnDevInst,PCWSTR pszCustomPropertyName,PULONG pulRegDataType,PVOID Buffer,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_DevNode_Custom_Property_ExA(DEVINST dnDevInst,PCSTR pszCustomPropertyName,PULONG pulRegDataType,PVOID Buffer,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_DevNode_Custom_Property_ExW(DEVINST dnDevInst,PCWSTR pszCustomPropertyName,PULONG pulRegDataType,PVOID Buffer,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
#define CM_Get_DevInst_Custom_PropertyW CM_Get_DevNode_Custom_PropertyW
#define CM_Get_DevInst_Custom_PropertyA CM_Get_DevNode_Custom_PropertyA
#define CM_Get_DevInst_Custom_Property_ExW CM_Get_DevNode_Custom_Property_ExW
#define CM_Get_DevInst_Custom_Property_ExA CM_Get_DevNode_Custom_Property_ExA
  CMAPI CONFIGRET WINAPI CM_Get_DevNode_Status(PULONG pulStatus,PULONG pulProblemNumber,DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_DevNode_Status_Ex(PULONG pulStatus,PULONG pulProblemNumber,DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
#define CM_Get_DevInst_Status CM_Get_DevNode_Status
#define CM_Get_DevInst_Status_Ex CM_Get_DevNode_Status_Ex
  CMAPI CONFIGRET WINAPI CM_Get_First_Log_Conf(PLOG_CONF plcLogConf,DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_First_Log_Conf_Ex(PLOG_CONF plcLogConf,DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Global_State(PULONG pulState,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Global_State_Ex(PULONG pulState,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Hardware_Profile_InfoA(ULONG ulIndex,PHWPROFILEINFO_A pHWProfileInfo,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Hardware_Profile_Info_ExA(ULONG ulIndex,PHWPROFILEINFO_A pHWProfileInfo,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Hardware_Profile_InfoW(ULONG ulIndex,PHWPROFILEINFO_W pHWProfileInfo,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Hardware_Profile_Info_ExW(ULONG ulIndex,PHWPROFILEINFO_W pHWProfileInfo,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_HW_Prof_FlagsA(DEVINSTID_A szDevInstName,ULONG ulHardwareProfile,PULONG pulValue,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_HW_Prof_FlagsW(DEVINSTID_W szDevInstName,ULONG ulHardwareProfile,PULONG pulValue,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_HW_Prof_Flags_ExA(DEVINSTID_A szDevInstName,ULONG ulHardwareProfile,PULONG pulValue,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_HW_Prof_Flags_ExW(DEVINSTID_W szDevInstName,ULONG ulHardwareProfile,PULONG pulValue,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_AliasA(LPCSTR pszDeviceInterface,LPGUID AliasInterfaceGuid,LPSTR pszAliasDeviceInterface,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_AliasW(LPCWSTR pszDeviceInterface,LPGUID AliasInterfaceGuid,LPWSTR pszAliasDeviceInterface,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_Alias_ExA(LPCSTR pszDeviceInterface,LPGUID AliasInterfaceGuid,LPSTR pszAliasDeviceInterface,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_Alias_ExW(LPCWSTR pszDeviceInterface,LPGUID AliasInterfaceGuid,LPWSTR pszAliasDeviceInterface,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_ListA(LPGUID InterfaceClassGuid,DEVINSTID_A pDeviceID,PCHAR Buffer,ULONG BufferLen,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_ListW(LPGUID InterfaceClassGuid,DEVINSTID_W pDeviceID,PWCHAR Buffer,ULONG BufferLen,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_List_ExA(LPGUID InterfaceClassGuid,DEVINSTID_A pDeviceID,PCHAR Buffer,ULONG BufferLen,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_List_ExW(LPGUID InterfaceClassGuid,DEVINSTID_W pDeviceID,PWCHAR Buffer,ULONG BufferLen,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_List_SizeA(PULONG pulLen,LPGUID InterfaceClassGuid,DEVINSTID_A pDeviceID,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_List_SizeW(PULONG pulLen,LPGUID InterfaceClassGuid,DEVINSTID_W pDeviceID,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_List_Size_ExA(PULONG pulLen,LPGUID InterfaceClassGuid,DEVINSTID_A pDeviceID,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Device_Interface_List_Size_ExW(PULONG pulLen,LPGUID InterfaceClassGuid,DEVINSTID_W pDeviceID,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Log_Conf_Priority(LOG_CONF lcLogConf,PPRIORITY pPriority,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Log_Conf_Priority_Ex(LOG_CONF lcLogConf,PPRIORITY pPriority,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Next_Log_Conf(PLOG_CONF plcLogConf,LOG_CONF lcLogConf,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Next_Log_Conf_Ex(PLOG_CONF plcLogConf,LOG_CONF lcLogConf,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Parent(PDEVINST pdnDevInst,DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Parent_Ex(PDEVINST pdnDevInst,DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Res_Des_Data(RES_DES rdResDes,PVOID Buffer,ULONG BufferLen,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Res_Des_Data_Ex(RES_DES rdResDes,PVOID Buffer,ULONG BufferLen,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Res_Des_Data_Size(PULONG pulSize,RES_DES rdResDes,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Res_Des_Data_Size_Ex(PULONG pulSize,RES_DES rdResDes,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Sibling(PDEVINST pdnDevInst,DEVINST DevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Sibling_Ex(PDEVINST pdnDevInst,DEVINST DevInst,ULONG ulFlags,HMACHINE hMachine);
  CMAPI WORD WINAPI CM_Get_Version(VOID);
  CMAPI WORD WINAPI CM_Get_Version_Ex(HMACHINE hMachine);
  CMAPI WINBOOL WINAPI CM_Is_Version_Available(WORD wVersion);
  CMAPI WINBOOL WINAPI CM_Is_Version_Available_Ex(WORD wVersion,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Intersect_Range_List(RANGE_LIST rlhOld1,RANGE_LIST rlhOld2,RANGE_LIST rlhNew,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Invert_Range_List(RANGE_LIST rlhOld,RANGE_LIST rlhNew,DWORDLONG ullMaxValue,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Locate_DevNodeA(PDEVINST pdnDevInst,DEVINSTID_A pDeviceID,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Locate_DevNodeW(PDEVINST pdnDevInst,DEVINSTID_W pDeviceID,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Locate_DevNode_ExA(PDEVINST pdnDevInst,DEVINSTID_A pDeviceID,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Locate_DevNode_ExW(PDEVINST pdnDevInst,DEVINSTID_W pDeviceID,ULONG ulFlags,HMACHINE hMachine);
#define CM_Locate_DevInstA CM_Locate_DevNodeA
#define CM_Locate_DevInstW CM_Locate_DevNodeW
#define CM_Locate_DevInst_ExA CM_Locate_DevNode_ExA
#define CM_Locate_DevInst_ExW CM_Locate_DevNode_ExW
  CMAPI CONFIGRET WINAPI CM_Merge_Range_List(RANGE_LIST rlhOld1,RANGE_LIST rlhOld2,RANGE_LIST rlhNew,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Modify_Res_Des(PRES_DES prdResDes,RES_DES rdResDes,RESOURCEID ResourceID,PCVOID ResourceData,ULONG ResourceLen,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Modify_Res_Des_Ex(PRES_DES prdResDes,RES_DES rdResDes,RESOURCEID ResourceID,PCVOID ResourceData,ULONG ResourceLen,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Move_DevNode(DEVINST dnFromDevInst,DEVINST dnToDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Move_DevNode_Ex(DEVINST dnFromDevInst,DEVINST dnToDevInst,ULONG ulFlags,HMACHINE hMachine);
#define CM_Move_DevInst CM_Move_DevNode
#define CM_Move_DevInst_Ex CM_Move_DevNode_Ex
  CMAPI CONFIGRET WINAPI CM_Next_Range(PRANGE_ELEMENT preElement,PDWORDLONG pullStart,PDWORDLONG pullEnd,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Next_Res_Des(PRES_DES prdResDes,RES_DES rdResDes,RESOURCEID ForResource,PRESOURCEID pResourceID,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Get_Next_Res_Des_Ex(PRES_DES prdResDes,RES_DES rdResDes,RESOURCEID ForResource,PRESOURCEID pResourceID,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Open_Class_KeyA(LPGUID ClassGuid,LPCSTR pszClassName,REGSAM samDesired,REGDISPOSITION Disposition,PHKEY phkClass,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Open_Class_KeyW(LPGUID ClassGuid,LPCWSTR pszClassName,REGSAM samDesired,REGDISPOSITION Disposition,PHKEY phkClass,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Open_Class_Key_ExA(LPGUID pszClassGuid,LPCSTR pszClassName,REGSAM samDesired,REGDISPOSITION Disposition,PHKEY phkClass,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Open_Class_Key_ExW(LPGUID pszClassGuid,LPCWSTR pszClassName,REGSAM samDesired,REGDISPOSITION Disposition,PHKEY phkClass,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Open_DevNode_Key(DEVINST dnDevNode,REGSAM samDesired,ULONG ulHardwareProfile,REGDISPOSITION Disposition,PHKEY phkDevice,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Open_DevNode_Key_Ex(DEVINST dnDevNode,REGSAM samDesired,ULONG ulHardwareProfile,REGDISPOSITION Disposition,PHKEY phkDevice,ULONG ulFlags,HMACHINE hMachine);
#define CM_Open_DevInst_Key CM_Open_DevNode_Key
#define CM_Open_DevInst_Key_Ex CM_Open_DevNode_Key_Ex
  CMAPI CONFIGRET WINAPI CM_Query_Arbitrator_Free_Data(PVOID pData,ULONG DataLen,DEVINST dnDevInst,RESOURCEID ResourceID,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Query_Arbitrator_Free_Data_Ex(PVOID pData,ULONG DataLen,DEVINST dnDevInst,RESOURCEID ResourceID,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Query_Arbitrator_Free_Size(PULONG pulSize,DEVINST dnDevInst,RESOURCEID ResourceID,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Query_Arbitrator_Free_Size_Ex(PULONG pulSize,DEVINST dnDevInst,RESOURCEID ResourceID,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Query_Remove_SubTree(DEVINST dnAncestor,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Query_Remove_SubTree_Ex(DEVINST dnAncestor,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Query_And_Remove_SubTreeA(DEVINST dnAncestor,PPNP_VETO_TYPE pVetoType,LPSTR pszVetoName,ULONG ulNameLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Query_And_Remove_SubTree_ExA(DEVINST dnAncestor,PPNP_VETO_TYPE pVetoType,LPSTR pszVetoName,ULONG ulNameLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Query_And_Remove_SubTreeW(DEVINST dnAncestor,PPNP_VETO_TYPE pVetoType,LPWSTR pszVetoName,ULONG ulNameLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Query_And_Remove_SubTree_ExW(DEVINST dnAncestor,PPNP_VETO_TYPE pVetoType,LPWSTR pszVetoName,ULONG ulNameLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Request_Device_EjectA(DEVINST dnDevInst,PPNP_VETO_TYPE pVetoType,LPSTR pszVetoName,ULONG ulNameLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Request_Device_Eject_ExA(DEVINST dnDevInst,PPNP_VETO_TYPE pVetoType,LPSTR pszVetoName,ULONG ulNameLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Request_Device_EjectW(DEVINST dnDevInst,PPNP_VETO_TYPE pVetoType,LPWSTR pszVetoName,ULONG ulNameLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Request_Device_Eject_ExW(DEVINST dnDevInst,PPNP_VETO_TYPE pVetoType,LPWSTR pszVetoName,ULONG ulNameLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Reenumerate_DevNode(DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Reenumerate_DevNode_Ex(DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
#define CM_Reenumerate_DevInst CM_Reenumerate_DevNode
#define CM_Reenumerate_DevInst_Ex CM_Reenumerate_DevNode_Ex
  CMAPI CONFIGRET WINAPI CM_Register_Device_InterfaceA(DEVINST dnDevInst,LPGUID InterfaceClassGuid,LPCSTR pszReference,LPSTR pszDeviceInterface,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Register_Device_InterfaceW(DEVINST dnDevInst,LPGUID InterfaceClassGuid,LPCWSTR pszReference,LPWSTR pszDeviceInterface,PULONG pulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Register_Device_Interface_ExA(DEVINST dnDevInst,LPGUID InterfaceClassGuid,LPCSTR pszReference,LPSTR pszDeviceInterface,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Register_Device_Interface_ExW(DEVINST dnDevInst,LPGUID InterfaceClassGuid,LPCWSTR pszReference,LPWSTR pszDeviceInterface,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Set_DevNode_Problem_Ex(DEVINST dnDevInst,ULONG ulProblem,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Set_DevNode_Problem(DEVINST dnDevInst,ULONG ulProblem,ULONG ulFlags);
#define CM_Set_DevInst_Problem CM_Set_DevNode_Problem
#define CM_Set_DevInst_Problem_Ex CM_Set_DevNode_Problem_Ex
  CMAPI CONFIGRET WINAPI CM_Unregister_Device_InterfaceA(LPCSTR pszDeviceInterface,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Unregister_Device_InterfaceW(LPCWSTR pszDeviceInterface,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Unregister_Device_Interface_ExA(LPCSTR pszDeviceInterface,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Unregister_Device_Interface_ExW(LPCWSTR pszDeviceInterface,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Register_Device_Driver(DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Register_Device_Driver_Ex(DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Remove_SubTree(DEVINST dnAncestor,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Remove_SubTree_Ex(DEVINST dnAncestor,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Set_DevNode_Registry_PropertyA(DEVINST dnDevInst,ULONG ulProperty,PCVOID Buffer,ULONG ulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Set_DevNode_Registry_PropertyW(DEVINST dnDevInst,ULONG ulProperty,PCVOID Buffer,ULONG ulLength,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Set_DevNode_Registry_Property_ExA(DEVINST dnDevInst,ULONG ulProperty,PCVOID Buffer,ULONG ulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Set_DevNode_Registry_Property_ExW(DEVINST dnDevInst,ULONG ulProperty,PCVOID Buffer,ULONG ulLength,ULONG ulFlags,HMACHINE hMachine);
#define CM_Set_DevInst_Registry_PropertyW CM_Set_DevNode_Registry_PropertyW
#define CM_Set_DevInst_Registry_PropertyA CM_Set_DevNode_Registry_PropertyA
#define CM_Set_DevInst_Registry_Property_ExW CM_Set_DevNode_Registry_Property_ExW
#define CM_Set_DevInst_Registry_Property_ExA CM_Set_DevNode_Registry_Property_ExA
  CMAPI CONFIGRET WINAPI CM_Is_Dock_Station_Present(PBOOL pbPresent);
  CMAPI CONFIGRET WINAPI CM_Is_Dock_Station_Present_Ex(PBOOL pbPresent,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Request_Eject_PC(VOID);
  CMAPI CONFIGRET WINAPI CM_Request_Eject_PC_Ex(HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Set_HW_Prof_FlagsA(DEVINSTID_A szDevInstName,ULONG ulConfig,ULONG ulValue,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Set_HW_Prof_FlagsW(DEVINSTID_W szDevInstName,ULONG ulConfig,ULONG ulValue,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Set_HW_Prof_Flags_ExA(DEVINSTID_A szDevInstName,ULONG ulConfig,ULONG ulValue,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Set_HW_Prof_Flags_ExW(DEVINSTID_W szDevInstName,ULONG ulConfig,ULONG ulValue,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Setup_DevNode(DEVINST dnDevInst,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Setup_DevNode_Ex(DEVINST dnDevInst,ULONG ulFlags,HMACHINE hMachine);
#define CM_Setup_DevInst CM_Setup_DevNode
#define CM_Setup_DevInst_Ex CM_Setup_DevNode_Ex
  CMAPI CONFIGRET WINAPI CM_Test_Range_Available(DWORDLONG ullStartValue,DWORDLONG ullEndValue,RANGE_LIST rlh,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Uninstall_DevNode(DEVNODE dnPhantom,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Uninstall_DevNode_Ex(DEVNODE dnPhantom,ULONG ulFlags,HANDLE hMachine);
#define CM_Uninstall_DevInst CM_Uninstall_DevNode
#define CM_Uninstall_DevInst_Ex CM_Uninstall_DevNode_Ex
  CMAPI CONFIGRET WINAPI CM_Run_Detection(ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Run_Detection_Ex(ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Set_HW_Prof(ULONG ulHardwareProfile,ULONG ulFlags);
  CMAPI CONFIGRET WINAPI CM_Set_HW_Prof_Ex(ULONG ulHardwareProfile,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Query_Resource_Conflict_List(PCONFLICT_LIST pclConflictList,DEVINST dnDevInst,RESOURCEID ResourceID,PCVOID ResourceData,ULONG ResourceLen,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Free_Resource_Conflict_Handle(CONFLICT_LIST clConflictList);
  CMAPI CONFIGRET WINAPI CM_Get_Resource_Conflict_Count(CONFLICT_LIST clConflictList,PULONG pulCount);
  CMAPI CONFIGRET WINAPI CM_Get_Resource_Conflict_DetailsA(CONFLICT_LIST clConflictList,ULONG ulIndex,PCONFLICT_DETAILS_A pConflictDetails);
  CMAPI CONFIGRET WINAPI CM_Get_Resource_Conflict_DetailsW(CONFLICT_LIST clConflictList,ULONG ulIndex,PCONFLICT_DETAILS_W pConflictDetails);
  CMAPI CONFIGRET WINAPI CM_Get_Class_Registry_PropertyW(LPGUID ClassGUID,ULONG ulProperty,PULONG pulRegDataType,PVOID Buffer,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Set_Class_Registry_PropertyW(LPGUID ClassGUID,ULONG ulProperty,PCVOID Buffer,ULONG ulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Get_Class_Registry_PropertyA(LPGUID ClassGUID,ULONG ulProperty,PULONG pulRegDataType,PVOID Buffer,PULONG pulLength,ULONG ulFlags,HMACHINE hMachine);
  CMAPI CONFIGRET WINAPI CM_Set_Class_Registry_PropertyA(LPGUID ClassGUID,ULONG ulProperty,PCVOID Buffer,ULONG ulLength,ULONG ulFlags,HMACHINE hMachine);
#define CM_WaitNoPendingInstallEvents CMP_WaitNoPendingInstallEvents
  DWORD WINAPI CM_WaitNoPendingInstallEvents(DWORD dwTimeout);

#define CR_SUCCESS (0x00000000)
#define CR_DEFAULT (0x00000001)
#define CR_OUT_OF_MEMORY (0x00000002)
#define CR_INVALID_POINTER (0x00000003)
#define CR_INVALID_FLAG (0x00000004)
#define CR_INVALID_DEVNODE (0x00000005)
#define CR_INVALID_DEVINST CR_INVALID_DEVNODE
#define CR_INVALID_RES_DES (0x00000006)
#define CR_INVALID_LOG_CONF (0x00000007)
#define CR_INVALID_ARBITRATOR (0x00000008)
#define CR_INVALID_NODELIST (0x00000009)
#define CR_DEVNODE_HAS_REQS (0x0000000A)
#define CR_DEVINST_HAS_REQS CR_DEVNODE_HAS_REQS
#define CR_INVALID_RESOURCEID (0x0000000B)
#define CR_DLVXD_NOT_FOUND (0x0000000C)
#define CR_NO_SUCH_DEVNODE (0x0000000D)
#define CR_NO_SUCH_DEVINST CR_NO_SUCH_DEVNODE
#define CR_NO_MORE_LOG_CONF (0x0000000E)
#define CR_NO_MORE_RES_DES (0x0000000F)
#define CR_ALREADY_SUCH_DEVNODE (0x00000010)
#define CR_ALREADY_SUCH_DEVINST CR_ALREADY_SUCH_DEVNODE
#define CR_INVALID_RANGE_LIST (0x00000011)
#define CR_INVALID_RANGE (0x00000012)
#define CR_FAILURE (0x00000013)
#define CR_NO_SUCH_LOGICAL_DEV (0x00000014)
#define CR_CREATE_BLOCKED (0x00000015)
#define CR_NOT_SYSTEM_VM (0x00000016)
#define CR_REMOVE_VETOED (0x00000017)
#define CR_APM_VETOED (0x00000018)
#define CR_INVALID_LOAD_TYPE (0x00000019)
#define CR_BUFFER_SMALL (0x0000001A)
#define CR_NO_ARBITRATOR (0x0000001B)
#define CR_NO_REGISTRY_HANDLE (0x0000001C)
#define CR_REGISTRY_ERROR (0x0000001D)
#define CR_INVALID_DEVICE_ID (0x0000001E)
#define CR_INVALID_DATA (0x0000001F)
#define CR_INVALID_API (0x00000020)
#define CR_DEVLOADER_NOT_READY (0x00000021)
#define CR_NEED_RESTART (0x00000022)
#define CR_NO_MORE_HW_PROFILES (0x00000023)
#define CR_DEVICE_NOT_THERE (0x00000024)
#define CR_NO_SUCH_VALUE (0x00000025)
#define CR_WRONG_TYPE (0x00000026)
#define CR_INVALID_PRIORITY (0x00000027)
#define CR_NOT_DISABLEABLE (0x00000028)
#define CR_FREE_RESOURCES (0x00000029)
#define CR_QUERY_VETOED (0x0000002A)
#define CR_CANT_SHARE_IRQ (0x0000002B)
#define CR_NO_DEPENDENT (0x0000002C)
#define CR_SAME_RESOURCES (0x0000002D)
#define CR_NO_SUCH_REGISTRY_KEY (0x0000002E)
#define CR_INVALID_MACHINENAME (0x0000002F)
#define CR_REMOTE_COMM_FAILURE (0x00000030)
#define CR_MACHINE_UNAVAILABLE (0x00000031)
#define CR_NO_CM_SERVICES (0x00000032)
#define CR_ACCESS_DENIED (0x00000033)
#define CR_CALL_NOT_IMPLEMENTED (0x00000034)
#define CR_INVALID_PROPERTY (0x00000035)
#define CR_DEVICE_INTERFACE_ACTIVE (0x00000036)
#define CR_NO_SUCH_DEVICE_INTERFACE (0x00000037)
#define CR_INVALID_REFERENCE_STRING (0x00000038)
#define CR_INVALID_CONFLICT_LIST (0x00000039)
#define CR_INVALID_INDEX (0x0000003A)
#define CR_INVALID_STRUCTURE_SIZE (0x0000003B)
#define NUM_CR_RESULTS (0x0000003C)

#ifdef __cplusplus
}
#endif
#endif
