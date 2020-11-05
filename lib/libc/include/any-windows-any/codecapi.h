/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_CODECAPI
#define _INC_CODECAPI

#ifdef UUID_GEN
#  define DEFINE_CODECAPI_GUID(name, guidstr, g1,g2,g3,g4,g5,g6,g7,g8,g9,g10,g11) \
    OUR_GUID_ENTRY(CODECAPI_##name, g1,g2,g3,g4,g5,g6,g7,g8,g9,g10,g11)
#else
#  ifndef DEFINE_GUIDSTRUCT
#    ifdef __cplusplus
#      define DEFINE_GUIDSTRUCT(g, n) struct n
#      define DEFINE_GUIDNAMED(n) __uuidof(struct n)
#    else
#      define DEFINE_GUIDSTRUCT(g, n) DEFINE_GUIDEX(n)
#      define DEFINE_GUIDNAMED(n) n
#    endif
#  endif
#  ifdef __CRT_UUID_DECL
#    define DEFINE_CODECAPI_GUID(name, guidstr, g1,g2,g3,g4,g5,g6,g7,g8,g9,g10,g11) \
       struct CODECAPI_##name; \
       __CRT_UUID_DECL(CODECAPI_##name, g1,g2,g3,g4,g5,g6,g7,g8,g9,g10,g11)
#    define DEFINE_CODECAPI_GUIDNAMED(name) __uuidof(CODECAPI_##name)
#  else
#    define DEFINE_CODECAPI_GUID(name, guidstr, g1,g2,g3,g4,g5,g6,g7,g8,g9,g10,g11) DEFINE_GUIDSTRUCT(guidstr, CODECAPI_##name);
#    define DEFINE_CODECAPI_GUIDNAMED(name) DEFINE_GUIDNAMED(CODECAPI_##name)
#  endif
#endif

  enum eAVEncCommonRateControlMode {
    eAVEncCommonRateControlMode_CBR = 0,
    eAVEncCommonRateControlMode_PeakConstrainedVBR = 1,
    eAVEncCommonRateControlMode_UnconstrainedVBR = 2,
    eAVEncCommonRateControlMode_Quality = 3,
    eAVEncCommonRateControlMode_LowDelayVBR = 4,
    eAVEncCommonRateControlMode_GlobalVBR = 5,
    eAVEncCommonRateControlMode_GlobalLowDelayVBR = 6
  };

  enum eAVEncCommonStreamEndHandling {
    eAVEncCommonStreamEndHandling_DiscardPartial = 0,
    eAVEncCommonStreamEndHandling_EnsureComplete = 1
  };

  enum eAVEncVideoOutputFrameRateConversion {
    eAVEncVideoOutputFrameRateConversion_Disable = 0,
    eAVEncVideoOutputFrameRateConversion_Enable = 1,
    eAVEncVideoOutputFrameRateConversion_Alias = 2
  };

  enum eAVDecVideoSoftwareDeinterlaceMode {
    eAVDecVideoSoftwareDeinterlaceMode_NoDeinterlacing = 0,
    eAVDecVideoSoftwareDeinterlaceMode_ProgressiveDeinterlacing = 1,
    eAVDecVideoSoftwareDeinterlaceMode_BOBDeinterlacing = 2,
    eAVDecVideoSoftwareDeinterlaceMode_SmartBOBDeinterlacing = 3
  };

  enum eAVFastDecodeMode {
    eVideoDecodeCompliant = 0,
    eVideoDecodeOptimalLF = 1,
    eVideoDecodeDisableLF = 2,
    eVideoDecodeFastest = 32
  };

  enum eAVDecVideoH264ErrorConcealment {
    eErrorConcealmentTypeDrop = 0,
    eErrorConcealmentTypeBasic = 1,
    eErrorConcealmentTypeAdvanced = 2,
    eErrorConcealmentTypeDXVASetBlack = 3
  };

  enum eAVDecVideoMPEG2ErrorConcealment {
    eErrorConcealmentOff = 0,
    eErrorConcealmentOn = 1
  };

  enum eAVDecVideoCodecType {
    eAVDecVideoCodecType_NOTPLAYING = 0,
    eAVDecVideoCodecType_MPEG2 = 1,
    eAVDecVideoCodecType_H264 = 2
  };

  enum eAVDecVideoDXVAMode {
    eAVDecVideoDXVAMode_NOTPLAYING = 0,
    eAVDecVideoDXVAMode_SW = 1,
    eAVDecVideoDXVAMode_MC = 2,
    eAVDecVideoDXVAMode_IDCT = 3,
    eAVDecVideoDXVAMode_VLD = 4
  };

  enum eAVDecVideoDXVABusEncryption {
    eAVDecVideoDXVABusEncryption_NONE = 0,
    eAVDecVideoDXVABusEncryption_PRIVATE = 1,
    eAVDecVideoDXVABusEncryption_AES = 2
  };

  enum eAVEncVideoSourceScanType {
    eAVEncVideoSourceScan_Automatic = 0,
    eAVEncVideoSourceScan_Interlaced = 1,
    eAVEncVideoSourceScan_Progressive = 2
  };

  enum eAVEncVideoOutputScanType {
    eAVEncVideoOutputScan_Progressive = 0,
    eAVEncVideoOutputScan_Interlaced = 1,
    eAVEncVideoOutputScan_SameAsInput = 2,
    eAVEncVideoOutputScan_Automatic = 3
  };

  enum eAVEncVideoFilmContent {
    eAVEncVideoFilmContent_VideoOnly = 0,
    eAVEncVideoFilmContent_FilmOnly = 1,
    eAVEncVideoFilmContent_Mixed = 2
  };

  enum eAVEncVideoChromaResolution {
    eAVEncVideoChromaResolution_SameAsSource = 0,
    eAVEncVideoChromaResolution_444 = 1,
    eAVEncVideoChromaResolution_422 = 2,
    eAVEncVideoChromaResolution_420 = 3,
    eAVEncVideoChromaResolution_411 = 4
  };

  enum eAVEncVideoChromaSubsampling {
    eAVEncVideoChromaSubsamplingFormat_SameAsSource = 0,
    eAVEncVideoChromaSubsamplingFormat_ProgressiveChroma = 0x8,
    eAVEncVideoChromaSubsamplingFormat_Horizontally_Cosited = 0x4,
    eAVEncVideoChromaSubsamplingFormat_Vertically_Cosited = 0x2,
    eAVEncVideoChromaSubsamplingFormat_Vertically_AlignedChromaPlanes = 0x1
  };

  enum eAVEncVideoColorPrimaries {
    eAVEncVideoColorPrimaries_SameAsSource = 0,
    eAVEncVideoColorPrimaries_Reserved = 1,
    eAVEncVideoColorPrimaries_BT709 = 2,
    eAVEncVideoColorPrimaries_BT470_2_SysM = 3,
    eAVEncVideoColorPrimaries_BT470_2_SysBG = 4,
    eAVEncVideoColorPrimaries_SMPTE170M = 5,
    eAVEncVideoColorPrimaries_SMPTE240M = 6,
    eAVEncVideoColorPrimaries_EBU3231 = 7,
    eAVEncVideoColorPrimaries_SMPTE_C = 8
  };

  enum eAVEncVideoColorTransferFunction {
    eAVEncVideoColorTransferFunction_SameAsSource = 0,
    eAVEncVideoColorTransferFunction_10 = 1,
    eAVEncVideoColorTransferFunction_18 = 2,
    eAVEncVideoColorTransferFunction_20 = 3,
    eAVEncVideoColorTransferFunction_22 = 4,
    eAVEncVideoColorTransferFunction_22_709 = 5,
    eAVEncVideoColorTransferFunction_22_240M = 6,
    eAVEncVideoColorTransferFunction_22_8bit_sRGB = 7,
    eAVEncVideoColorTransferFunction_28 = 8
  };

  enum eAVEncVideoColorTransferMatrix {
    eAVEncVideoColorTransferMatrix_SameAsSource = 0,
    eAVEncVideoColorTransferMatrix_BT709 = 1,
    eAVEncVideoColorTransferMatrix_BT601 = 2,
    eAVEncVideoColorTransferMatrix_SMPTE240M = 3
  };

  enum eAVEncVideoColorLighting {
    eAVEncVideoColorLighting_SameAsSource = 0,
    eAVEncVideoColorLighting_Unknown = 1,
    eAVEncVideoColorLighting_Bright = 2,
    eAVEncVideoColorLighting_Office = 3,
    eAVEncVideoColorLighting_Dim = 4,
    eAVEncVideoColorLighting_Dark = 5
  };

  enum eAVEncVideoColorNominalRange {
    eAVEncVideoColorNominalRange_SameAsSource = 0,
    eAVEncVideoColorNominalRange_0_255 = 1,
    eAVEncVideoColorNominalRange_16_235 = 2,
    eAVEncVideoColorNominalRange_48_208 = 3
  };

  enum eAVEncInputVideoSystem {
    eAVEncInputVideoSystem_Unspecified = 0,
    eAVEncInputVideoSystem_PAL = 1,
    eAVEncInputVideoSystem_NTSC = 2,
    eAVEncInputVideoSystem_SECAM = 3,
    eAVEncInputVideoSystem_MAC = 4,
    eAVEncInputVideoSystem_HDV = 5,
    eAVEncInputVideoSystem_Component = 6
  };

  enum eAVEncVideoContentType {
    eAVEncVideoContentType_Unknown = 0,
    eAVEncVideoContentType_FixedCameraAngle = 1
  };

  enum eAVEncAdaptiveMode {
    eAVEncAdaptiveMode_None = 0,
    eAVEncAdaptiveMode_Resolution = 1,
    eAVEncAdaptiveMode_FrameRate = 2
  };

  enum eAVScenarioInfo {
    eAVScenarioInfo_Unknown = 0,
    eAVScenarioInfo_DisplayRemoting = 1,
    eAVScenarioInfo_VideoConference = 2,
    eAVScenarioInfo_Archive = 3,
    eAVScenarioInfo_LiveStreaming = 4,
    eAVScenarioInfo_CameraRecord = 5,
    eAVScenarioInfo_DisplayRemotingWithFeatureMap = 6
  };

  enum eVideoEncoderDisplayContentType {
    eVideoEncoderDisplayContent_Unknown = 0,
    eVideoEncoderDisplayContent_FullScreenVideo = 1
  };

  enum eAVEncMuxOutput {
    eAVEncMuxOutputAuto = 0,
    eAVEncMuxOutputPS = 1,
    eAVEncMuxOutputTS = 2
  };

  enum eAVEncAudioDualMono {
    eAVEncAudioDualMono_SameAsInput = 0,
    eAVEncAudioDualMono_Off = 1,
    eAVEncAudioDualMono_On = 2
  };

  enum eAVEncAudioInputContent {
    AVEncAudioInputContent_Unknown =0,
    AVEncAudioInputContent_Voice = 1,
    AVEncAudioInputContent_Music = 2
  };

  enum eAVEncMPVProfile {
    eAVEncMPVProfile_unknown = 0,
    eAVEncMPVProfile_Simple = 1,
    eAVEncMPVProfile_Main = 2,
    eAVEncMPVProfile_High = 3,
    eAVEncMPVProfile_422 = 4
  };

  enum eAVEncMPVLevel {
    eAVEncMPVLevel_Low = 1,
    eAVEncMPVLevel_Main = 2,
    eAVEncMPVLevel_High1440 = 3,
    eAVEncMPVLevel_High = 4
  };

  enum eAVEncH263VProfile {
    eAVEncH263VProfile_Base = 0,
    eAVEncH263VProfile_CompatibilityV2 = 1,
    eAVEncH263VProfile_CompatibilityV1 = 2,
    eAVEncH263VProfile_WirelessV2 = 3,
    eAVEncH263VProfile_WirelessV3 = 4,
    eAVEncH263VProfile_HighCompression = 5,
    eAVEncH263VProfile_Internet = 6,
    eAVEncH263VProfile_Interlace = 7,
    eAVEncH263VProfile_HighLatency = 8
  };

  enum eAVEncH264VProfile {
   eAVEncH264VProfile_unknown = 0,
   eAVEncH264VProfile_Simple = 66,
   eAVEncH264VProfile_Base = 66,
   eAVEncH264VProfile_Main = 77,
   eAVEncH264VProfile_High = 100,
   eAVEncH264VProfile_422 = 122,
   eAVEncH264VProfile_High10 = 110,
   eAVEncH264VProfile_444 = 244,
   eAVEncH264VProfile_Extended = 88,
   eAVEncH264VProfile_ScalableBase = 83,
   eAVEncH264VProfile_ScalableHigh = 86,
   eAVEncH264VProfile_MultiviewHigh = 118,
   eAVEncH264VProfile_StereoHigh = 128,
   eAVEncH264VProfile_ConstrainedBase = 256,
   eAVEncH264VProfile_UCConstrainedHigh = 257,
   eAVEncH264VProfile_UCScalableConstrainedBase = 258,
   eAVEncH264VProfile_UCScalableConstrainedHigh = 259
  };

  enum eAVEncH265VProfile {
   eAVEncH265VProfile_unknown = 0,
   eAVEncH265VProfile_Main_420_8 = 1,
   eAVEncH265VProfile_Main_420_10 = 2,
   eAVEncH265VProfile_Main_420_12 = 3,
   eAVEncH265VProfile_Main_422_10 = 4,
   eAVEncH265VProfile_Main_422_12 = 5,
   eAVEncH265VProfile_Main_444_8 = 6,
   eAVEncH265VProfile_Main_444_10 = 7,
   eAVEncH265VProfile_Main_444_12 = 8,
   eAVEncH265VProfile_Monochrome_12 = 9,
   eAVEncH265VProfile_Monochrome_16 = 10,
   eAVEncH265VProfile_MainIntra_420_8 = 11,
   eAVEncH265VProfile_MainIntra_420_10 = 12,
   eAVEncH265VProfile_MainIntra_420_12 = 13,
   eAVEncH265VProfile_MainIntra_422_10 = 14,
   eAVEncH265VProfile_MainIntra_422_12 = 15,
   eAVEncH265VProfile_MainIntra_444_8 = 16,
   eAVEncH265VProfile_MainIntra_444_10 = 17,
   eAVEncH265VProfile_MainIntra_444_12 = 18,
   eAVEncH265VProfile_MainIntra_444_16 = 19,
   eAVEncH265VProfile_MainStill_420_8 = 20,
   eAVEncH265VProfile_MainStill_444_8 = 21,
   eAVEncH265VProfile_MainStill_444_16 = 22
  };

  enum eAVEncVP9VProfile {
    eAVEncVP9VProfile_unknown = 0,
    eAVEncVP9VProfile_420_8 = 1,
    eAVEncVP9VProfile_420_10 = 2,
    eAVEncVP9VProfile_420_12 = 3
  };

  enum eAVEncH263PictureType {
    eAVEncH263PictureType_I = 0,
    eAVEncH263PictureType_P,
    eAVEncH263PictureType_B
  };

  enum eAVEncH264PictureType {
    eAVEncH264PictureType_IDR = 0,
    eAVEncH264PictureType_P,
    eAVEncH264PictureType_B
  };

  enum eAVEncH263VLevel {
    eAVEncH263VLevel1 = 10,
    eAVEncH263VLevel2 = 20,
    eAVEncH263VLevel3 = 30,
    eAVEncH263VLevel4 = 40,
    eAVEncH263VLevel4_5 = 45,
    eAVEncH263VLevel5 = 50,
    eAVEncH263VLevel6 = 60,
    eAVEncH263VLevel7 = 70
  };

  enum eAVEncH264VLevel {
    eAVEncH264VLevel1 = 10,
    eAVEncH264VLevel1_b = 11,
    eAVEncH264VLevel1_1 = 11,
    eAVEncH264VLevel1_2 = 12,
    eAVEncH264VLevel1_3 = 13,
    eAVEncH264VLevel2 = 20,
    eAVEncH264VLevel2_1 = 21,
    eAVEncH264VLevel2_2 = 22,
    eAVEncH264VLevel3 = 30,
    eAVEncH264VLevel3_1 = 31,
    eAVEncH264VLevel3_2 = 32,
    eAVEncH264VLevel4 = 40,
    eAVEncH264VLevel4_1 = 41,
    eAVEncH264VLevel4_2 = 42,
    eAVEncH264VLevel5 = 50,
    eAVEncH264VLevel5_1 = 51,
    eAVEncH264VLevel5_2 = 52
  };

  enum eAVEncH265VLevel {
    eAVEncH265VLevel1 = 30,
    eAVEncH265VLevel2 = 60,
    eAVEncH265VLevel2_1 = 63,
    eAVEncH265VLevel3 = 90,
    eAVEncH265VLevel3_1 = 93,
    eAVEncH265VLevel4 = 120,
    eAVEncH265VLevel4_1 = 123,
    eAVEncH265VLevel5 = 150,
    eAVEncH265VLevel5_1 = 153,
    eAVEncH265VLevel5_2 = 156,
    eAVEncH265VLevel6 = 180,
    eAVEncH265VLevel6_1 = 183,
    eAVEncH265VLevel6_2 = 186
  };

  enum eAVEncMPVFrameFieldMode {
    eAVEncMPVFrameFieldMode_FieldMode = 0,
    eAVEncMPVFrameFieldMode_FrameMode = 1
  };

  enum eAVEncMPVSceneDetection {
    eAVEncMPVSceneDetection_None = 0,
    eAVEncMPVSceneDetection_InsertIPicture = 1,
    eAVEncMPVSceneDetection_StartNewGOP = 2,
    eAVEncMPVSceneDetection_StartNewLocatableGOP = 3
  };

  enum eAVEncMPVScanPattern {
    eAVEncMPVScanPattern_Auto = 0,
    eAVEncMPVScanPattern_ZigZagScan = 1,
    eAVEncMPVScanPattern_AlternateScan = 2
  };

  enum eAVEncMPVQScaleType {
    eAVEncMPVQScaleType_Auto = 0,
    eAVEncMPVQScaleType_Linear = 1,
    eAVEncMPVQScaleType_NonLinear = 2
  };

  enum eAVEncMPVIntraVLCTable {
    eAVEncMPVIntraVLCTable_Auto = 0,
    eAVEncMPVIntraVLCTable_MPEG1 = 1,
    eAVEncMPVIntraVLCTable_Alternate = 2
  };

  enum eAVEncMPALayer {
    eAVEncMPALayer_1 = 1,
    eAVEncMPALayer_2 = 2,
    eAVEncMPALayer_3 = 3
  };

  enum eAVEncMPACodingMode {
    eAVEncMPACodingMode_Mono = 0,
    eAVEncMPACodingMode_Stereo = 1,
    eAVEncMPACodingMode_DualChannel = 2,
    eAVEncMPACodingMode_JointStereo = 3,
    eAVEncMPACodingMode_Surround = 4
  };

  enum eAVEncMPAEmphasisType {
    eAVEncMPAEmphasisType_None = 0,
    eAVEncMPAEmphasisType_50_15 = 1,
    eAVEncMPAEmphasisType_Reserved = 2,
    eAVEncMPAEmphasisType_CCITT_J17 = 3
  };

  enum eAVEncDDService {
    eAVEncDDService_CM = 0,
    eAVEncDDService_ME = 1,
    eAVEncDDService_VI = 2,
    eAVEncDDService_HI = 3,
    eAVEncDDService_D = 4,
    eAVEncDDService_C = 5,
    eAVEncDDService_E = 6,
    eAVEncDDService_VO = 7
  };

  enum eAVEncDDProductionRoomType {
    eAVEncDDProductionRoomType_NotIndicated = 0,
    eAVEncDDProductionRoomType_Large = 1,
    eAVEncDDProductionRoomType_Small = 2
  };

  enum eAVEncDDDynamicRangeCompressionControl {
    eAVEncDDDynamicRangeCompressionControl_None = 0,
    eAVEncDDDynamicRangeCompressionControl_FilmStandard = 1,
    eAVEncDDDynamicRangeCompressionControl_FilmLight = 2,
    eAVEncDDDynamicRangeCompressionControl_MusicStandard = 3,
    eAVEncDDDynamicRangeCompressionControl_MusicLight = 4,
    eAVEncDDDynamicRangeCompressionControl_Speech = 5
  };

  enum eAVEncDDSurroundExMode {
    eAVEncDDSurroundExMode_NotIndicated = 0,
    eAVEncDDSurroundExMode_No = 1,
    eAVEncDDSurroundExMode_Yes = 2
  };

  enum eAVEncDDPreferredStereoDownMixMode {
    eAVEncDDPreferredStereoDownMixMode_LtRt = 0,
    eAVEncDDPreferredStereoDownMixMode_LoRo = 1
  };

  enum eAVEncDDAtoDConverterType {
    eAVEncDDAtoDConverterType_Standard = 0,
    eAVEncDDAtoDConverterType_HDCD = 1
  };

  enum eAVEncDDHeadphoneMode {
    eAVEncDDHeadphoneMode_NotIndicated = 0,
    eAVEncDDHeadphoneMode_NotEncoded = 1,
    eAVEncDDHeadphoneMode_Encoded = 2
  };

  enum eAVDecVideoInputScanType {
    eAVDecVideoInputScan_Unknown = 0,
    eAVDecVideoInputScan_Progressive = 1,
    eAVDecVideoInputScan_Interlaced_UpperFieldFirst = 2,
    eAVDecVideoInputScan_Interlaced_LowerFieldFirst = 3
  };

  enum eAVDecVideoSWPowerLevel {
    eAVDecVideoSWPowerLevel_BatteryLife = 0,
    eAVDecVideoSWPowerLevel_Balanced = 50,
    eAVDecVideoSWPowerLevel_VideoQuality = 100
  };

  enum eAVDecAACDownmixMode {
    eAVDecAACUseISODownmix = 0,
    eAVDecAACUseARIBDownmix = 1
  };

  enum eAVDecHEAACDynamicRangeControl {
    eAVDecHEAACDynamicRangeControl_OFF = 0,
    eAVDecHEAACDynamicRangeControl_ON = 1
  };

  enum eAVDecAudioDualMono {
    eAVDecAudioDualMono_IsNotDualMono = 0,
    eAVDecAudioDualMono_IsDualMono = 1,
    eAVDecAudioDualMono_UnSpecified = 2
  };

  enum eAVDecAudioDualMonoReproMode {
    eAVDecAudioDualMonoReproMode_STEREO = 0,
    eAVDecAudioDualMonoReproMode_LEFT_MONO = 1,
    eAVDecAudioDualMonoReproMode_RIGHT_MONO = 2,
    eAVDecAudioDualMonoReproMode_MIX_MONO = 3
  };

  enum eAVAudioChannelConfig {
    eAVAudioChannelConfig_FRONT_LEFT = 0x1,
    eAVAudioChannelConfig_FRONT_RIGHT = 0x2,
    eAVAudioChannelConfig_FRONT_CENTER = 0x4,
    eAVAudioChannelConfig_LOW_FREQUENCY = 0x8,
    eAVAudioChannelConfig_BACK_LEFT = 0x10,
    eAVAudioChannelConfig_BACK_RIGHT = 0x20,
    eAVAudioChannelConfig_FRONT_LEFT_OF_CENTER = 0x40,
    eAVAudioChannelConfig_FRONT_RIGHT_OF_CENTER = 0x80,
    eAVAudioChannelConfig_BACK_CENTER = 0x100,
    eAVAudioChannelConfig_SIDE_LEFT = 0x200,
    eAVAudioChannelConfig_SIDE_RIGHT = 0x400,
    eAVAudioChannelConfig_TOP_CENTER = 0x800,
    eAVAudioChannelConfig_TOP_FRONT_LEFT = 0x1000,
    eAVAudioChannelConfig_TOP_FRONT_CENTER = 0x2000,
    eAVAudioChannelConfig_TOP_FRONT_RIGHT = 0x4000,
    eAVAudioChannelConfig_TOP_BACK_LEFT = 0x8000,
    eAVAudioChannelConfig_TOP_BACK_CENTER = 0x10000,
    eAVAudioChannelConfig_TOP_BACK_RIGHT = 0x20000
  };

  enum eAVDDSurroundMode {
    eAVDDSurroundMode_NotIndicated = 0,
    eAVDDSurroundMode_No = 1,
    eAVDDSurroundMode_Yes = 2
  };

  enum eAVDecDDOperationalMode {
    eAVDecDDOperationalMode_NONE = 0,
    eAVDecDDOperationalMode_LINE = 1,
    eAVDecDDOperationalMode_RF = 2,
    eAVDecDDOperationalMode_CUSTOM0 = 3,
    eAVDecDDOperationalMode_CUSTOM1 = 4,
    eAVDecDDOperationalMode_PORTABLE8 = 5,
    eAVDecDDOperationalMode_PORTABLE11 = 6,
    eAVDecDDOperationalMode_PORTABLE14 = 7
  };

  enum eAVDecDDMatrixDecodingMode {
    eAVDecDDMatrixDecodingMode_OFF = 0,
    eAVDecDDMatrixDecodingMode_ON = 1,
    eAVDecDDMatrixDecodingMode_AUTO = 2
  };

  enum eAVDecDDStereoDownMixMode {
    eAVDecDDStereoDownMixMode_Auto = 0,
    eAVDecDDStereoDownMixMode_LtRt = 1,
    eAVDecDDStereoDownMixMode_LoRo = 2
  };

  enum eAVDSPLoudnessEqualization {
    eAVDSPLoudnessEqualization_OFF = 0,
    eAVDSPLoudnessEqualization_ON = 1,
    eAVDSPLoudnessEqualization_AUTO = 2
  };

  enum eAVDSPSpeakerFill {
    eAVDSPSpeakerFill_OFF = 0,
    eAVDSPSpeakerFill_ON = 1,
    eAVDSPSpeakerFill_AUTO = 2
  };

  enum eAVEncChromaEncodeMode {
    eAVEncChromaEncodeMode_420,
    eAVEncChromaEncodeMode_444,
    eAVEncChromaEncodeMode_444_v2
  };

#define STATIC_CODECAPI_AVDecVideoThumbnailGenerationMode  0x2efd8eee,0x1150,0x4328,0x9c,0xf5,0x66,0xdc,0xe9,0x33,0xfc,0xf4
DEFINE_CODECAPI_GUID(AVDecVideoThumbnailGenerationMode, "2efd8eee-1150-4328-9cf5-66dce933fcf4", 0x2efd8eee,
                     0x1150,0x4328,0x9c,0xf5,0x66,0xdc,0xe9,0x33,0xfc,0xf4)

#define STATIC_CODECAPI_AVDecVideoDropPicWithMissingRef  0xf8226383,0x14c2,0x4567,0x97,0x34,0x50,0x04,0xe9,0x6f,0xf8,0x87
DEFINE_CODECAPI_GUID(AVDecVideoDropPicWithMissingRef, "f8226383-14c2-4567-9734-5004e96ff887",
                     0xf8226383,0x14c2,0x4567,0x97,0x34,0x50,0x04,0xe9,0x6f,0xf8,0x87)

#define STATIC_CODECAPI_AVDecVideoSoftwareDeinterlaceMode  0x0c08d1ce,0x9ced,0x4540,0xba,0xe3,0xce,0xb3,0x80,0x14,0x11,0x09
DEFINE_CODECAPI_GUID(AVDecVideoSoftwareDeinterlaceMode, "0c08d1ce-9ced-4540-bae3-ceb380141109",
                     0x0c08d1ce,0x9ced,0x4540,0xba,0xe3,0xce,0xb3,0x80,0x14,0x11,0x09);

#define STATIC_CODECAPI_AVDecVideoFastDecodeMode  0x6b529f7d,0xd3b1,0x49c6,0xa9,0x99,0x9e,0xc6,0x91,0x1b,0xed,0xbf
DEFINE_CODECAPI_GUID(AVDecVideoFastDecodeMode, "6b529f7d-d3b1-49c6-a999-9ec6911bedbf",
                     0x6b529f7d,0xd3b1,0x49c6,0xa9,0x99,0x9e,0xc6,0x91,0x1b,0xed,0xbf);

#define STATIC_CODECAPI_AVLowLatencyMode  0x9c27891a,0xed7a,0x40e1,0x88,0xe8,0xb2,0x27,0x27,0xa0,0x24,0xee
DEFINE_CODECAPI_GUID(AVLowLatencyMode, "9c27891a-ed7a-40e1-88e8-b22727a024ee",
                     0x9c27891a,0xed7a,0x40e1,0x88,0xe8,0xb2,0x27,0x27,0xa0,0x24,0xee)

#define STATIC_CODECAPI_AVDecVideoH264ErrorConcealment  0xececace8,0x3436,0x462c,0x92,0x94,0xcd,0x7b,0xac,0xd7,0x58,0xa9
DEFINE_CODECAPI_GUID(AVDecVideoH264ErrorConcealment, "ececace8-3436-462c-9294-cd7bacd758a9",
                     0xececace8,0x3436,0x462c,0x92,0x94,0xcd,0x7b,0xac,0xd7,0x58,0xa9)

#define STATIC_CODECAPI_AVDecVideoMPEG2ErrorConcealment  0x9d2bfe18,0x728d,0x48d2,0xb3,0x58,0xbc,0x7e,0x43,0x6c,0x66,0x74
DEFINE_CODECAPI_GUID(AVDecVideoMPEG2ErrorConcealment, "9d2bfe18-728d-48d2-b358-bc7e436c6674",
                     0x9d2bfe18,0x728d,0x48d2,0xb3,0x58,0xbc,0x7e,0x43,0x6c,0x66,0x74)

#define STATIC_CODECAPI_AVDecVideoCodecType  0x434528e5,0x21f0,0x46b6,0xb6,0x2c,0x9b,0x1b,0x6b,0x65,0x8c,0xd1
DEFINE_CODECAPI_GUID(AVDecVideoCodecType, "434528e5-21f0-46b6-b62c-9b1b6b658cd1",
                     0x434528e5,0x21f0,0x46b6,0xb6,0x2c,0x9b,0x1b,0x6b,0x65,0x8c,0xd1);

#define STATIC_CODECAPI_AVDecVideoDXVAMode  0xf758f09e,0x7337,0x4ae7,0x83,0x87,0x73,0xdc,0x2d,0x54,0xe6,0x7d
DEFINE_CODECAPI_GUID(AVDecVideoDXVAMode, "f758f09e-7337-4ae7-8387-73dc2d54e67d",
                     0xf758f09e,0x7337,0x4ae7,0x83,0x87,0x73,0xdc,0x2d,0x54,0xe6,0x7d);

#define STATIC_CODECAPI_AVDecVideoDXVABusEncryption  0x42153c8b,0xfd0b,0x4765,0xa4,0x62,0xdd,0xd9,0xe8,0xbc,0xc3,0x88
DEFINE_CODECAPI_GUID(AVDecVideoDXVABusEncryption, "42153c8b-fd0b-4765-a462-ddd9e8bcc388",
                     0x42153c8b,0xfd0b,0x4765,0xa4,0x62,0xdd,0xd9,0xe8,0xbc,0xc3,0x88);

#define STATIC_CODECAPI_AVDecVideoSWPowerLevel  0xfb5d2347,0x4dd8,0x4509,0xae,0xd0,0xdb,0x5f,0xa9,0xaa,0x93,0xf4
DEFINE_CODECAPI_GUID(AVDecVideoSWPowerLevel,  "fb5d2347-4dd8-4509-aed0-db5fa9aa93f4",
                     0xfb5d2347,0x4dd8,0x4509,0xae,0xd0,0xdb,0x5f,0xa9,0xaa,0x93,0xf4)

#define STATIC_CODECAPI_AVDecVideoMaxCodedWidth  0x5ae557b8,0x77af,0x41f5,0x9f,0xa6,0x4d,0xb2,0xfe,0x1d,0x4b,0xca
DEFINE_CODECAPI_GUID(AVDecVideoMaxCodedWidth, "5ae557b8-77af-41f5-9fa6-4db2fe1d4bca",
                     0x5ae557b8,0x77af,0x41f5,0x9f,0xa6,0x4d,0xb2,0xfe,0x1d,0x4b,0xca)

#define STATIC_CODECAPI_AVDecVideoMaxCodedHeight  0x7262a16a,0xd2dc,0x4e75,0x9b,0xa8,0x65,0xc0,0xc6,0xd3,0x2b,0x13
DEFINE_CODECAPI_GUID(AVDecVideoMaxCodedHeight, "7262a16a-d2dc-4e75-9ba8-65c0c6d32b13",
                     0x7262a16a,0xd2dc,0x4e75,0x9b,0xa8,0x65,0xc0,0xc6,0xd3,0x2b,0x13)

#define STATIC_CODECAPI_AVDecNumWorkerThreads  0x9561c3e8,0xea9e,0x4435,0x9b,0x1e,0xa9,0x3e,0x69,0x18,0x94,0xd8
DEFINE_CODECAPI_GUID(AVDecNumWorkerThreads, "9561c3e8-ea9e-4435-9b1e-a93e691894d8",
                     0x9561c3e8,0xea9e,0x4435,0x9b,0x1e,0xa9,0x3e,0x69,0x18,0x94,0xd8)

#define STATIC_CODECAPI_AVDecSoftwareDynamicFormatChange  0x862e2f0a,0x507b,0x47ff,0xaf,0x47,0x01,0xe2,0x62,0x42,0x98,0xb7
DEFINE_CODECAPI_GUID(AVDecSoftwareDynamicFormatChange, "862e2f0a-507b-47ff-af47-01e2624298b7",
                     0x862e2f0a,0x507b,0x47ff,0xaf,0x47,0x01,0xe2,0x62,0x42,0x98,0xb7)

#define STATIC_CODECAPI_AVDecDisableVideoPostProcessing  0xf8749193,0x667a,0x4f2c,0xa9,0xe8,0x5d,0x4a,0xf9,0x24,0xf0,0x8f
DEFINE_CODECAPI_GUID(AVDecDisableVideoPostProcessing, "f8749193-667a-4f2c-a9e8-5d4af924f08f",
                     0xf8749193,0x667a,0x4f2c,0xa9,0xe8,0x5d,0x4a,0xf9,0x24,0xf0,0x8f);

#define STATIC_CODECAPI_AVEncCommonMeanBitRate  0xf7222374,0x2144,0x4815,0xb5,0x50,0xa3,0x7f,0x8e,0x12,0xee,0x52
DEFINE_CODECAPI_GUID(AVEncCommonMeanBitRate, "f7222374-2144-4815-b550-a37f8e12ee52",
                     0xf7222374,0x2144,0x4815,0xb5,0x50,0xa3,0x7f,0x8e,0x12,0xee,0x52)

#define STATIC_CODECAPI_AVEncCommonQuality  0xfcbf57a3,0x7ea5,0x4b0c,0x96,0x44,0x69,0xb4,0x0c,0x39,0xc3,0x91
DEFINE_CODECAPI_GUID(AVEncCommonQuality, "fcbf57a3-7ea5-4b0c-9644-69b40c39c391",
                     0xfcbf57a3,0x7ea5,0x4b0c,0x96,0x44,0x69,0xb4,0x0c,0x39,0xc3,0x91)

#define STATIC_CODECAPI_AVEncCommonRateControlMode  0x1c0608e9,0x370c,0x4710,0x8a,0x58,0xcb,0x61,0x81,0xc4,0x24,0x23
DEFINE_CODECAPI_GUID(AVEncCommonRateControlMode, "1c0608e9-370c-4710-8a58-cb6181c42423",
                     0x1c0608e9,0x370c,0x4710,0x8a,0x58,0xcb,0x61,0x81,0xc4,0x24,0x23)

#define STATIC_CODECAPI_AVEncVideoForceKeyFrame  0x398c1b98,0x8353,0x475a,0x9e,0xf2,0x8f,0x26,0x5d,0x26,0x3,0x45
DEFINE_CODECAPI_GUID(AVEncVideoForceKeyFrame, "398c1b98-8353-475a-9ef2-8f265d260345",
                     0x398c1b98,0x8353,0x475a,0x9e,0xf2,0x8f,0x26,0x5d,0x26,0x3,0x45)

#define STATIC_CODECAPI_AVEncMPVDefaultBPictureCount  0x8d390aac,0xdc5c,0x4200,0xb5,0x7f,0x81,0x4d,0x04,0xba,0xba,0xb2
DEFINE_CODECAPI_GUID(AVEncMPVDefaultBPictureCount, "8d390aac-dc5c-4200-b57f-814d04babab2",
                     0x8d390aac,0xdc5c,0x4200,0xb5,0x7f,0x81,0x4d,0x04,0xba,0xba,0xb2)

#define STATIC_CODECAPI_AVEncH264CABACEnable  0xee6cad62,0xd305,0x4248,0xa5,0xe,0xe1,0xb2,0x55,0xf7,0xca,0xf8
DEFINE_CODECAPI_GUID(AVEncH264CABACEnable, "ee6cad62-d305-4248-a50e-e1b255f7caf8",
                     0xee6cad62,0xd305,0x4248,0xa5,0xe,0xe1,0xb2,0x55,0xf7,0xca,0xf8)

#ifndef UUID_GEN

#define CODECAPI_AVDecVideoThumbnailGenerationMode  DEFINE_CODECAPI_GUIDNAMED(AVDecVideoThumbnailGenerationMode)
#define CODECAPI_AVDecVideoDropPicWithMissingRef    DEFINE_CODECAPI_GUIDNAMED(AVDecVideoDropPicWithMissingRef)
#define CODECAPI_AVDecVideoSoftwareDeinterlaceMode  DEFINE_CODECAPI_GUIDNAMED(AVDecVideoSoftwareDeinterlaceMode)
#define CODECAPI_AVDecVideoFastDecodeMode           DEFINE_CODECAPI_GUIDNAMED(AVDecVideoFastDecodeMode)
#define CODECAPI_AVLowLatencyMode                   DEFINE_CODECAPI_GUIDNAMED(AVLowLatencyMode)
#define CODECAPI_AVDecVideoH264ErrorConcealment     DEFINE_CODECAPI_GUIDNAMED(AVDecVideoH264ErrorConcealment)
#define CODECAPI_AVDecVideoMPEG2ErrorConcealment    DEFINE_CODECAPI_GUIDNAMED(AVDecVideoMPEG2ErrorConcealment)
#define CODECAPI_AVDecVideoCodecType                DEFINE_CODECAPI_GUIDNAMED(AVDecVideoCodecType)
#define CODECAPI_AVDecVideoDXVAMode                 DEFINE_CODECAPI_GUIDNAMED(AVDecVideoDXVAMode)
#define CODECAPI_AVDecVideoDXVABusEncryption        DEFINE_CODECAPI_GUIDNAMED(AVDecVideoDXVABusEncryption)
#define CODECAPI_AVDecVideoSWPowerLevel             DEFINE_CODECAPI_GUIDNAMED(AVDecVideoSWPowerLevel)
#define CODECAPI_AVDecVideoMaxCodedWidth            DEFINE_CODECAPI_GUIDNAMED(AVDecVideoMaxCodedWidth)
#define CODECAPI_AVDecVideoMaxCodedHeight           DEFINE_CODECAPI_GUIDNAMED(AVDecVideoMaxCodedHeight)
#define CODECAPI_AVDecNumWorkerThreads              DEFINE_CODECAPI_GUIDNAMED(AVDecNumWorkerThreads)
#define CODECAPI_AVDecSoftwareDynamicFormatChange   DEFINE_CODECAPI_GUIDNAMED(AVDecSoftwareDynamicFormatChange)
#define CODECAPI_AVDecDisableVideoPostProcessing    DEFINE_CODECAPI_GUIDNAMED(AVDecDisableVideoPostProcessing)
#define CODECAPI_AVEncCommonMeanBitRate             DEFINE_CODECAPI_GUIDNAMED(AVEncCommonMeanBitRate)
#define CODECAPI_AVEncCommonQuality                 DEFINE_CODECAPI_GUIDNAMED(AVEncCommonQuality)
#define CODECAPI_AVEncCommonRateControlMode         DEFINE_CODECAPI_GUIDNAMED(AVEncCommonRateControlMode)
#define CODECAPI_AVEncVideoForceKeyFrame            DEFINE_CODECAPI_GUIDNAMED(AVEncVideoForceKeyFrame)
#define CODECAPI_AVEncMPVDefaultBPictureCount       DEFINE_CODECAPI_GUIDNAMED(AVEncMPVDefaultBPictureCount)
#define CODECAPI_AVEncMPVDefaultBPictureCount       DEFINE_CODECAPI_GUIDNAMED(AVEncMPVDefaultBPictureCount)
#define CODECAPI_AVEncH264CABACEnable               DEFINE_CODECAPI_GUIDNAMED(AVEncH264CABACEnable)

#endif

#endif /*_INC_CODECAPI*/
