/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the ReactOS PSDK package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#pragma once

#define __NTDDMMC__

#ifdef __cplusplus
extern "C" {
#endif

#define SCSI_GET_CONFIGURATION_REQUEST_TYPE_ALL          0x0
#define SCSI_GET_CONFIGURATION_REQUEST_TYPE_CURRENT      0x1
#define SCSI_GET_CONFIGURATION_REQUEST_TYPE_ONE          0x2

typedef struct _GET_CONFIGURATION_HEADER {
  UCHAR DataLength[4];
  UCHAR Reserved[2];
  UCHAR CurrentProfile[2];
#if !defined(__midl) && !defined(__WIDL__)
  UCHAR Data[0];
#endif
} GET_CONFIGURATION_HEADER, *PGET_CONFIGURATION_HEADER;

typedef struct _FEATURE_HEADER {
  UCHAR FeatureCode[2];
  UCHAR Current:1;
  UCHAR Persistent:1;
  UCHAR Version:4;
  UCHAR Reserved0:2;
  UCHAR AdditionalLength;
} FEATURE_HEADER, *PFEATURE_HEADER;

typedef enum _FEATURE_PROFILE_TYPE {
  ProfileInvalid = 0x0000,
  ProfileNonRemovableDisk = 0x0001,
  ProfileRemovableDisk = 0x0002,
  ProfileMOErasable = 0x0003,
  ProfileMOWriteOnce = 0x0004,
  ProfileAS_MO = 0x0005,
  ProfileCdrom = 0x0008,
  ProfileCdRecordable = 0x0009,
  ProfileCdRewritable = 0x000a,
  ProfileDvdRom = 0x0010,
  ProfileDvdRecordable = 0x0011,
  ProfileDvdRam = 0x0012,
  ProfileDvdRewritable = 0x0013,
  ProfileDvdRWSequential = 0x0014,
  ProfileDvdDashRDualLayer = 0x0015,
  ProfileDvdDashRLayerJump = 0x0016,
  ProfileDvdPlusRW = 0x001A,
  ProfileDvdPlusR = 0x001B,
  ProfileDDCdrom = 0x0020,
  ProfileDDCdRecordable = 0x0021,
  ProfileDDCdRewritable = 0x0022,
  ProfileDvdPlusRWDualLayer = 0x002A,
  ProfileDvdPlusRDualLayer = 0x002B,
  ProfileBDRom = 0x0040,
  ProfileBDRSequentialWritable = 0x0041,
  ProfileBDRRandomWritable = 0x0042,
  ProfileBDRewritable = 0x0043,
  ProfileHDDVDRom = 0x0050,
  ProfileHDDVDRecordable = 0x0051,
  ProfileHDDVDRam = 0x0052,
  ProfileHDDVDRewritable = 0x0053,
  ProfileHDDVDRDualLayer = 0x0058,
  ProfileHDDVDRWDualLayer = 0x005A,
  ProfileNonStandard = 0xffff
} FEATURE_PROFILE_TYPE, *PFEATURE_PROFILE_TYPE;

typedef enum _FEATURE_NUMBER {
  FeatureProfileList = 0x0000,
  FeatureCore = 0x0001,
  FeatureMorphing = 0x0002,
  FeatureRemovableMedium = 0x0003,
  FeatureWriteProtect = 0x0004,
  FeatureRandomReadable = 0x0010,
  FeatureMultiRead = 0x001D,
  FeatureCdRead = 0x001E,
  FeatureDvdRead = 0x001F,
  FeatureRandomWritable = 0x0020,
  FeatureIncrementalStreamingWritable = 0x0021,
  FeatureSectorErasable = 0x0022,
  FeatureFormattable = 0x0023,
  FeatureDefectManagement = 0x0024,
  FeatureWriteOnce = 0x0025,
  FeatureRestrictedOverwrite = 0x0026,
  FeatureCdrwCAVWrite = 0x0027,
  FeatureMrw = 0x0028,
  FeatureEnhancedDefectReporting = 0x0029,
  FeatureDvdPlusRW = 0x002A,
  FeatureDvdPlusR = 0x002B,
  FeatureRigidRestrictedOverwrite = 0x002C,
  FeatureCdTrackAtOnce = 0x002D,
  FeatureCdMastering = 0x002E,
  FeatureDvdRecordableWrite = 0x002F,
  FeatureDDCDRead = 0x0030,
  FeatureDDCDRWrite = 0x0031,
  FeatureDDCDRWWrite = 0x0032,
  FeatureLayerJumpRecording = 0x0033,
  FeatureCDRWMediaWriteSupport = 0x0037,
  FeatureBDRPseudoOverwrite = 0x0038,
  FeatureDvdPlusRWDualLayer = 0x003A,
  FeatureDvdPlusRDualLayer = 0x003B,
  FeatureBDRead = 0x0040,
  FeatureBDWrite = 0x0041,
  FeatureTSR = 0x0042,
  FeatureHDDVDRead = 0x0050,
  FeatureHDDVDWrite = 0x0051,
  FeatureHybridDisc = 0x0080,
  FeaturePowerManagement = 0x0100,
  FeatureSMART = 0x0101,
  FeatureEmbeddedChanger = 0x0102,
  FeatureCDAudioAnalogPlay = 0x0103,
  FeatureMicrocodeUpgrade = 0x0104,
  FeatureTimeout = 0x0105,
  FeatureDvdCSS = 0x0106,
  FeatureRealTimeStreaming = 0x0107,
  FeatureLogicalUnitSerialNumber = 0x0108,
  FeatureMediaSerialNumber = 0x0109,
  FeatureDiscControlBlocks = 0x010A,
  FeatureDvdCPRM = 0x010B,
  FeatureFirmwareDate = 0x010C,
  FeatureAACS = 0x010D,
  FeatureVCPS = 0x0110,
} FEATURE_NUMBER, *PFEATURE_NUMBER;

typedef struct _FEATURE_DATA_PROFILE_LIST_EX {
  UCHAR ProfileNumber[2];
  UCHAR Current:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2;
} FEATURE_DATA_PROFILE_LIST_EX, *PFEATURE_DATA_PROFILE_LIST_EX;

typedef struct _FEATURE_DATA_PROFILE_LIST {
  FEATURE_HEADER Header;
#if !defined(__midl) && !defined(__WIDL__)
  FEATURE_DATA_PROFILE_LIST_EX Profiles[0];
#endif
} FEATURE_DATA_PROFILE_LIST, *PFEATURE_DATA_PROFILE_LIST;

typedef struct _FEATURE_DATA_CORE {
  FEATURE_HEADER Header;
  UCHAR PhysicalInterface[4];
  UCHAR DeviceBusyEvent:1;
  UCHAR INQUIRY2:1;
  UCHAR Reserved1:6;
  UCHAR Reserved2[3];
} FEATURE_DATA_CORE, *PFEATURE_DATA_CORE;

typedef struct _FEATURE_DATA_MORPHING {
  FEATURE_HEADER Header;
  UCHAR Asynchronous:1;
  UCHAR OCEvent:1;
  UCHAR Reserved01:6;
  UCHAR Reserved2[3];
} FEATURE_DATA_MORPHING, *PFEATURE_DATA_MORPHING;

typedef struct _FEATURE_DATA_REMOVABLE_MEDIUM {
  FEATURE_HEADER Header;
  UCHAR Lockable:1;
  UCHAR Reserved1:1;
  UCHAR DefaultToPrevent:1;
  UCHAR Eject:1;
  UCHAR Reserved2:1;
  UCHAR LoadingMechanism:3;
  UCHAR Reserved3[3];
} FEATURE_DATA_REMOVABLE_MEDIUM, *PFEATURE_DATA_REMOVABLE_MEDIUM;

typedef struct _FEATURE_DATA_WRITE_PROTECT {
  FEATURE_HEADER Header;
  UCHAR SupportsSWPPBit:1;
  UCHAR SupportsPersistentWriteProtect:1;
  UCHAR WriteInhibitDCB:1;
  UCHAR DiscWriteProtectPAC:1;
  UCHAR Reserved01:4;
  UCHAR Reserved2[3];
} FEATURE_DATA_WRITE_PROTECT, *PFEATURE_DATA_WRITE_PROTECT;

typedef struct _FEATURE_DATA_RANDOM_READABLE {
  FEATURE_HEADER Header;
  UCHAR LogicalBlockSize[4];
  UCHAR Blocking[2];
  UCHAR ErrorRecoveryPagePresent:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2;
} FEATURE_DATA_RANDOM_READABLE, *PFEATURE_DATA_RANDOM_READABLE;

typedef struct _FEATURE_DATA_MULTI_READ {
  FEATURE_HEADER Header;
} FEATURE_DATA_MULTI_READ, *PFEATURE_DATA_MULTI_READ;

typedef struct _FEATURE_DATA_CD_READ {
  FEATURE_HEADER Header;
  UCHAR CDText:1;
  UCHAR C2ErrorData:1;
  UCHAR Reserved01:5;
  UCHAR DigitalAudioPlay:1;
  UCHAR Reserved2[3];
} FEATURE_DATA_CD_READ, *PFEATURE_DATA_CD_READ;

typedef struct _FEATURE_DATA_DVD_READ {
  FEATURE_HEADER Header;
  UCHAR Multi110:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2;
  UCHAR DualDashR:1;
  UCHAR Reserved3:7;
  UCHAR Reserved4;
} FEATURE_DATA_DVD_READ, *PFEATURE_DATA_DVD_READ;

typedef struct _FEATURE_DATA_RANDOM_WRITABLE {
  FEATURE_HEADER Header;
  UCHAR LastLBA[4];
  UCHAR LogicalBlockSize[4];
  UCHAR Blocking[2];
  UCHAR ErrorRecoveryPagePresent:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2;
} FEATURE_DATA_RANDOM_WRITABLE, *PFEATURE_DATA_RANDOM_WRITABLE;

typedef struct _FEATURE_DATA_INCREMENTAL_STREAMING_WRITABLE {
  FEATURE_HEADER Header;
  UCHAR DataTypeSupported[2];
  UCHAR BufferUnderrunFree:1;
  UCHAR AddressModeReservation:1;
  UCHAR TrackRessourceInformation:1;
  UCHAR Reserved01:5;
  UCHAR NumberOfLinkSizes;
#if !defined(__midl) && !defined(__WIDL__)
  UCHAR LinkSize[0];
#endif
} FEATURE_DATA_INCREMENTAL_STREAMING_WRITABLE, *PFEATURE_DATA_INCREMENTAL_STREAMING_WRITABLE;

typedef struct _FEATURE_DATA_SECTOR_ERASABLE {
  FEATURE_HEADER Header;
} FEATURE_DATA_SECTOR_ERASABLE, *PFEATURE_DATA_SECTOR_ERASABLE;

typedef struct _FEATURE_DATA_FORMATTABLE {
  FEATURE_HEADER Header;
  UCHAR FullCertification:1;
  UCHAR QuickCertification:1;
  UCHAR SpareAreaExpansion:1;
  UCHAR RENoSpareAllocated:1;
  UCHAR Reserved1:4;
  UCHAR Reserved2[3];
  UCHAR RRandomWritable:1;
  UCHAR Reserved3:7;
  UCHAR Reserved4[3];
} FEATURE_DATA_FORMATTABLE, *PFEATURE_DATA_FORMATTABLE;

typedef struct _FEATURE_DATA_DEFECT_MANAGEMENT {
  FEATURE_HEADER Header;
  UCHAR Reserved1:7;
  UCHAR SupplimentalSpareArea:1;
  UCHAR Reserved2[3];
} FEATURE_DATA_DEFECT_MANAGEMENT, *PFEATURE_DATA_DEFECT_MANAGEMENT;

typedef struct _FEATURE_DATA_WRITE_ONCE {
  FEATURE_HEADER Header;
  UCHAR LogicalBlockSize[4];
  UCHAR Blocking[2];
  UCHAR ErrorRecoveryPagePresent:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2;
} FEATURE_DATA_WRITE_ONCE, *PFEATURE_DATA_WRITE_ONCE;

typedef struct _FEATURE_DATA_RESTRICTED_OVERWRITE {
  FEATURE_HEADER Header;
} FEATURE_DATA_RESTRICTED_OVERWRITE, *PFEATURE_DATA_RESTRICTED_OVERWRITE;

typedef struct _FEATURE_DATA_CDRW_CAV_WRITE {
  FEATURE_HEADER Header;
  UCHAR Reserved1[4];
} FEATURE_DATA_CDRW_CAV_WRITE, *PFEATURE_DATA_CDRW_CAV_WRITE;

typedef struct _FEATURE_DATA_MRW {
  FEATURE_HEADER Header;
  UCHAR Write:1;
  UCHAR DvdPlusRead:1;
  UCHAR DvdPlusWrite:1;
  UCHAR Reserved01:5;
  UCHAR Reserved2[3];
} FEATURE_DATA_MRW, *PFEATURE_DATA_MRW;

typedef struct _FEATURE_ENHANCED_DEFECT_REPORTING {
  FEATURE_HEADER Header;
  UCHAR DRTDMSupported:1;
  UCHAR Reserved0:7;
  UCHAR NumberOfDBICacheZones;
  UCHAR NumberOfEntries[2];
} FEATURE_ENHANCED_DEFECT_REPORTING, *PFEATURE_ENHANCED_DEFECT_REPORTING;

typedef struct _FEATURE_DATA_DVD_PLUS_RW {
  FEATURE_HEADER Header;
  UCHAR Write:1;
  UCHAR Reserved1:7;
  UCHAR CloseOnly:1;
  UCHAR QuickStart:1;
  UCHAR Reserved02:6;
  UCHAR Reserved03[2];
} FEATURE_DATA_DVD_PLUS_RW, *PFEATURE_DATA_DVD_PLUS_RW;

typedef struct _FEATURE_DATA_DVD_PLUS_R {
  FEATURE_HEADER Header;
  UCHAR Write:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2[3];
} FEATURE_DATA_DVD_PLUS_R, *PFEATURE_DATA_DVD_PLUS_R;

typedef struct _FEATURE_DATA_DVD_RW_RESTRICTED_OVERWRITE {
  FEATURE_HEADER Header;
  UCHAR Blank:1;
  UCHAR Intermediate:1;
  UCHAR DefectStatusDataRead:1;
  UCHAR DefectStatusDataGenerate:1;
  UCHAR Reserved0:4;
  UCHAR Reserved1[3];
} FEATURE_DATA_DVD_RW_RESTRICTED_OVERWRITE, *PFEATURE_DATA_DVD_RW_RESTRICTED_OVERWRITE;

typedef struct _FEATURE_DATA_CD_TRACK_AT_ONCE {
  FEATURE_HEADER Header;
  UCHAR RWSubchannelsRecordable:1;
  UCHAR CdRewritable:1;
  UCHAR TestWriteOk:1;
  UCHAR RWSubchannelPackedOk:1;
  UCHAR RWSubchannelRawOk:1;
  UCHAR Reserved1:1;
  UCHAR BufferUnderrunFree:1;
  UCHAR Reserved3:1;
  UCHAR Reserved2;
  UCHAR DataTypeSupported[2];
} FEATURE_DATA_CD_TRACK_AT_ONCE, *PFEATURE_DATA_CD_TRACK_AT_ONCE;

typedef struct _FEATURE_DATA_CD_MASTERING {
  FEATURE_HEADER Header;
  UCHAR RWSubchannelsRecordable:1;
  UCHAR CdRewritable:1;
  UCHAR TestWriteOk:1;
  UCHAR RawRecordingOk:1;
  UCHAR RawMultiSessionOk:1;
  UCHAR SessionAtOnceOk:1;
  UCHAR BufferUnderrunFree:1;
  UCHAR Reserved1:1;
  UCHAR MaximumCueSheetLength[3];
} FEATURE_DATA_CD_MASTERING, *PFEATURE_DATA_CD_MASTERING;

typedef struct _FEATURE_DATA_DVD_RECORDABLE_WRITE {
  FEATURE_HEADER Header;
  UCHAR Reserved1:1;
  UCHAR DVD_RW:1;
  UCHAR TestWrite:1;
  UCHAR RDualLayer:1;
  UCHAR Reserved02:2;
  UCHAR BufferUnderrunFree:1;
  UCHAR Reserved3:1;
  UCHAR Reserved4[3];
} FEATURE_DATA_DVD_RECORDABLE_WRITE, *PFEATURE_DATA_DVD_RECORDABLE_WRITE;

typedef struct _FEATURE_DATA_DDCD_READ {
  FEATURE_HEADER Header;
} FEATURE_DATA_DDCD_READ, *PFEATURE_DATA_DDCD_READ;

typedef struct _FEATURE_DATA_DDCD_R_WRITE {
  FEATURE_HEADER Header;
  UCHAR Reserved1:2;
  UCHAR TestWrite:1;
  UCHAR Reserved2:5;
  UCHAR Reserved3[3];
} FEATURE_DATA_DDCD_R_WRITE, *PFEATURE_DATA_DDCD_R_WRITE;

typedef struct _FEATURE_DATA_DDCD_RW_WRITE {
  FEATURE_HEADER Header;
  UCHAR Blank:1;
  UCHAR Intermediate:1;
  UCHAR Reserved1:6;
  UCHAR Reserved2[3];
} FEATURE_DATA_DDCD_RW_WRITE, *PFEATURE_DATA_DDCD_RW_WRITE;

typedef struct _FEATURE_DATA_LAYER_JUMP_RECORDING {
  FEATURE_HEADER Header;
  UCHAR Reserved0[3];
  UCHAR NumberOfLinkSizes;
#if !defined(__midl) && !defined(__WIDL__)
  UCHAR LinkSizes[0];
#endif
} FEATURE_DATA_LAYER_JUMP_RECORDING, *PFEATURE_DATA_LAYER_JUMP_RECORDING;

typedef struct _FEATURE_CD_RW_MEDIA_WRITE_SUPPORT {
  FEATURE_HEADER Header;
  UCHAR Reserved1;
  struct{
    UCHAR Subtype0:1;
    UCHAR Subtype1:1;
    UCHAR Subtype2:1;
    UCHAR Subtype3:1;
    UCHAR Subtype4:1;
    UCHAR Subtype5:1;
    UCHAR Subtype6:1;
    UCHAR Subtype7:1;
  } CDRWMediaSubtypeSupport;
  UCHAR Reserved2[2];
} FEATURE_CD_RW_MEDIA_WRITE_SUPPORT, *PFEATURE_CD_RW_MEDIA_WRITE_SUPPORT;

typedef struct _FEATURE_BD_R_PSEUDO_OVERWRITE {
  FEATURE_HEADER Header;
  UCHAR Reserved[4];
} FEATURE_BD_R_PSEUDO_OVERWRITE, *PFEATURE_BD_R_PSEUDO_OVERWRITE;

typedef struct _FEATURE_DATA_DVD_PLUS_RW_DUAL_LAYER {
  FEATURE_HEADER Header;
  UCHAR Write:1;
  UCHAR Reserved1:7;
  UCHAR CloseOnly:1;
  UCHAR QuickStart:1;
  UCHAR Reserved2:6;
  UCHAR Reserved3[2];
} FEATURE_DATA_DVD_PLUS_RW_DUAL_LAYER, *PFEATURE_DATA_DVD_PLUS_RW_DUAL_LAYER;

typedef struct _FEATURE_DATA_DVD_PLUS_R_DUAL_LAYER {
  FEATURE_HEADER Header;
  UCHAR Write:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2[3];
} FEATURE_DATA_DVD_PLUS_R_DUAL_LAYER, *PFEATURE_DATA_DVD_PLUS_R_DUAL_LAYER;

typedef struct _BD_CLASS_SUPPORT_BITMAP {
  UCHAR Version8:1;
  UCHAR Version9:1;
  UCHAR Version10:1;
  UCHAR Version11:1;
  UCHAR Version12:1;
  UCHAR Version13:1;
  UCHAR Version14:1;
  UCHAR Version15:1;
  UCHAR Version0:1;
  UCHAR Version1:1;
  UCHAR Version2:1;
  UCHAR Version3:1;
  UCHAR Version4:1;
  UCHAR Version5:1;
  UCHAR Version6:1;
  UCHAR Version7:1;
} BD_CLASS_SUPPORT_BITMAP, *PBD_CLASS_SUPPORT_BITMAP;

typedef struct _FEATURE_BD_READ {
  FEATURE_HEADER Header;
  UCHAR Reserved[4];
  BD_CLASS_SUPPORT_BITMAP Class0BitmapBDREReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class1BitmapBDREReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class2BitmapBDREReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class3BitmapBDREReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class0BitmapBDRReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class1BitmapBDRReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class2BitmapBDRReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class3BitmapBDRReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class0BitmapBDROMReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class1BitmapBDROMReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class2BitmapBDROMReadSupport;
  BD_CLASS_SUPPORT_BITMAP Class3BitmapBDROMReadSupport;
} FEATURE_BD_READ, *PFEATURE_BD_READ;

typedef struct _FEATURE_BD_WRITE {
  FEATURE_HEADER Header;
  UCHAR SupportsVerifyNotRequired:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2[3];
  BD_CLASS_SUPPORT_BITMAP Class0BitmapBDREWriteSupport;
  BD_CLASS_SUPPORT_BITMAP Class1BitmapBDREWriteSupport;
  BD_CLASS_SUPPORT_BITMAP Class2BitmapBDREWriteSupport;
  BD_CLASS_SUPPORT_BITMAP Class3BitmapBDREWriteSupport;
  BD_CLASS_SUPPORT_BITMAP Class0BitmapBDRWriteSupport;
  BD_CLASS_SUPPORT_BITMAP Class1BitmapBDRWriteSupport;
  BD_CLASS_SUPPORT_BITMAP Class2BitmapBDRWriteSupport;
  BD_CLASS_SUPPORT_BITMAP Class3BitmapBDRWriteSupport;
} FEATURE_BD_WRITE, *PFEATURE_BD_WRITE;

typedef struct _FEATURE_TSR {
  FEATURE_HEADER Header;
} FEATURE_TSR, *PFEATURE_TSR;

typedef struct _FEATURE_DATA_HDDVD_READ {
  FEATURE_HEADER Header;
  UCHAR Recordable:1;
  UCHAR Reserved0:7;
  UCHAR Reserved1;
  UCHAR Rewritable:1;
  UCHAR Reserved2:7;
  UCHAR Reserved3;
} FEATURE_DATA_HDDVD_READ, *PFEATURE_DATA_HDDVD_READ;

typedef struct _FEATURE_DATA_HDDVD_WRITE {
  FEATURE_HEADER Header;
  UCHAR Recordable:1;
  UCHAR Reserved0:7;
  UCHAR Reserved1;
  UCHAR Rewritable:1;
  UCHAR Reserved2:7;
  UCHAR Reserved3;
} FEATURE_DATA_HDDVD_WRITE, *PFEATURE_DATA_HDDVD_WRITE;

typedef struct _FEATURE_HYBRID_DISC {
  FEATURE_HEADER Header;
  UCHAR ResetImmunity:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2[3];
} FEATURE_HYBRID_DISC, *PFEATURE_HYBRID_DISC;

typedef struct _FEATURE_DATA_POWER_MANAGEMENT {
  FEATURE_HEADER Header;
} FEATURE_DATA_POWER_MANAGEMENT, *PFEATURE_DATA_POWER_MANAGEMENT;

typedef struct _FEATURE_DATA_SMART {
  FEATURE_HEADER Header;
  UCHAR FaultFailureReportingPagePresent:1;
  UCHAR Reserved1:7;
  UCHAR Reserved02[3];
} FEATURE_DATA_SMART, *PFEATURE_DATA_SMART;

typedef struct _FEATURE_DATA_EMBEDDED_CHANGER {
  FEATURE_HEADER Header;
  UCHAR Reserved1:2;
  UCHAR SupportsDiscPresent:1;
  UCHAR Reserved2:1;
  UCHAR SideChangeCapable:1;
  UCHAR Reserved3:3;
  UCHAR Reserved4[2];
  UCHAR HighestSlotNumber:5;
  UCHAR Reserved:3;
} FEATURE_DATA_EMBEDDED_CHANGER, *PFEATURE_DATA_EMBEDDED_CHANGER;

typedef struct _FEATURE_DATA_CD_AUDIO_ANALOG_PLAY {
  FEATURE_HEADER Header;
  UCHAR SeperateVolume:1;
  UCHAR SeperateChannelMute:1;
  UCHAR ScanSupported:1;
  UCHAR Reserved1:5;
  UCHAR Reserved2;
  UCHAR NumerOfVolumeLevels[2];
} FEATURE_DATA_CD_AUDIO_ANALOG_PLAY, *PFEATURE_DATA_CD_AUDIO_ANALOG_PLAY;

typedef struct _FEATURE_DATA_MICROCODE_UPDATE {
  FEATURE_HEADER Header;
  UCHAR M5:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2[3];
} FEATURE_DATA_MICROCODE_UPDATE, *PFEATURE_DATA_MICROCODE_UPDATE;

typedef struct _FEATURE_DATA_TIMEOUT {
  FEATURE_HEADER Header;
  UCHAR Group3:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2;
  UCHAR UnitLength[2];
} FEATURE_DATA_TIMEOUT, *PFEATURE_DATA_TIMEOUT;

typedef struct _FEATURE_DATA_DVD_CSS {
  FEATURE_HEADER Header;
  UCHAR Reserved1[3];
  UCHAR CssVersion;
} FEATURE_DATA_DVD_CSS, *PFEATURE_DATA_DVD_CSS;

typedef struct _FEATURE_DATA_REAL_TIME_STREAMING {
  FEATURE_HEADER Header;
  UCHAR StreamRecording:1;
  UCHAR WriteSpeedInGetPerf:1;
  UCHAR WriteSpeedInMP2A:1;
  UCHAR SetCDSpeed:1;
  UCHAR ReadBufferCapacityBlock:1;
  UCHAR Reserved1:3;
  UCHAR Reserved2[3];
} FEATURE_DATA_REAL_TIME_STREAMING, *PFEATURE_DATA_REAL_TIME_STREAMING;

typedef struct _FEATURE_DATA_LOGICAL_UNIT_SERIAL_NUMBER {
  FEATURE_HEADER Header;
#if !defined(__midl) && !defined(__WIDL__)
  UCHAR SerialNumber[0];
#endif
} FEATURE_DATA_LOGICAL_UNIT_SERIAL_NUMBER, *PFEATURE_DATA_LOGICAL_UNIT_SERIAL_NUMBER;

typedef struct _FEATURE_MEDIA_SERIAL_NUMBER {
  FEATURE_HEADER Header;
} FEATURE_MEDIA_SERIAL_NUMBER, *PFEATURE_MEDIA_SERIAL_NUMBER;

typedef struct _FEATURE_DATA_DISC_CONTROL_BLOCKS_EX {
  UCHAR ContentDescriptor[4];
} FEATURE_DATA_DISC_CONTROL_BLOCKS_EX, *PFEATURE_DATA_DISC_CONTROL_BLOCKS_EX;

typedef struct _FEATURE_DATA_DISC_CONTROL_BLOCKS {
  FEATURE_HEADER Header;
#if !defined(__midl) && !defined(__WIDL__)
  FEATURE_DATA_DISC_CONTROL_BLOCKS_EX Data[0];
#endif
} FEATURE_DATA_DISC_CONTROL_BLOCKS, *PFEATURE_DATA_DISC_CONTROL_BLOCKS;

typedef struct _FEATURE_DATA_DVD_CPRM {
  FEATURE_HEADER Header;
  UCHAR Reserved0[3];
  UCHAR CPRMVersion;
} FEATURE_DATA_DVD_CPRM, *PFEATURE_DATA_DVD_CPRM;

typedef struct _FEATURE_DATA_FIRMWARE_DATE {
  FEATURE_HEADER Header;
  UCHAR Year[4];
  UCHAR Month[2];
  UCHAR Day[2];
  UCHAR Hour[2];
  UCHAR Minute[2];
  UCHAR Seconds[2];
  UCHAR Reserved[2];
} FEATURE_DATA_FIRMWARE_DATE, *PFEATURE_DATA_FIRMWARE_DATE;

typedef struct _FEATURE_DATA_AACS {
  FEATURE_HEADER Header;
  UCHAR BindingNonceGeneration:1;
  UCHAR Reserved0:7;
  UCHAR BindingNonceBlockCount;
  UCHAR NumberOfAGIDs:4;
  UCHAR Reserved1:4;
  UCHAR AACSVersion;
} FEATURE_DATA_AACS, *PFEATURE_DATA_AACS;

typedef struct _FEATURE_VCPS {
  FEATURE_HEADER Header;
  UCHAR Reserved[4];
} FEATURE_VCPS, *PFEATURE_VCPS;

typedef struct _FEATURE_DATA_RESERVED {
  FEATURE_HEADER Header;
#if !defined(__midl) && !defined(__WIDL__)
  UCHAR Data[0];
#endif
} FEATURE_DATA_RESERVED, *PFEATURE_DATA_RESERVED;

typedef struct _FEATURE_DATA_VENDOR_SPECIFIC {
  FEATURE_HEADER Header;
#if !defined(__midl) && !defined(__WIDL__)
  UCHAR VendorSpecificData[0];
#endif
} FEATURE_DATA_VENDOR_SPECIFIC, *PFEATURE_DATA_VENDOR_SPECIFIC;

typedef struct _GET_CONFIGURATION_IOCTL_INPUT {
  FEATURE_NUMBER Feature;
  ULONG RequestType;
  PVOID Reserved[2];
} GET_CONFIGURATION_IOCTL_INPUT, *PGET_CONFIGURATION_IOCTL_INPUT;

#if defined(_WIN64)
typedef struct _GET_CONFIGURATION_IOCTL_INPUT32 {
  FEATURE_NUMBER Feature;
  ULONG RequestType;
  VOID* UPOINTER_32 Reserved[2];
} GET_CONFIGURATION_IOCTL_INPUT32, *PGET_CONFIGURATION_IOCTL_INPUT32;
#endif

#ifdef __cplusplus
}
#endif
