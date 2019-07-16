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

  enum eAVEncH264VLevel {
    eAVEncH264VLevel1     = 10,
    eAVEncH264VLevel1_b   = 11,
    eAVEncH264VLevel1_1   = 11,
    eAVEncH264VLevel1_2   = 12,
    eAVEncH264VLevel1_3   = 13,
    eAVEncH264VLevel2     = 20,
    eAVEncH264VLevel2_1   = 21,
    eAVEncH264VLevel2_2   = 22,
    eAVEncH264VLevel3     = 30,
    eAVEncH264VLevel3_1   = 31,
    eAVEncH264VLevel3_2   = 32,
    eAVEncH264VLevel4     = 40,
    eAVEncH264VLevel4_1   = 41,
    eAVEncH264VLevel4_2   = 42,
    eAVEncH264VLevel5     = 50,
    eAVEncH264VLevel5_1   = 51 
  };

  enum eAVEncH264VProfile {
    eAVEncH264VProfile_unknown    = 0,
    eAVEncH264VProfile_Simple     = 66,
    eAVEncH264VProfile_Base       = 66,
    eAVEncH264VProfile_Main       = 77,
    eAVEncH264VProfile_High       = 100,
    eAVEncH264VProfile_422        = 122,
    eAVEncH264VProfile_High10     = 110,
    eAVEncH264VProfile_444        = 144,
    eAVEncH264VProfile_Extended   = 88 
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

#endif

#endif /*_INC_CODECAPI*/
