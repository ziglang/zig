/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_OPMAPI
#define _INC_OPMAPI

#include <dxva2api.h>

#define OPM_OMAC_SIZE                                16
#define OPM_CONFIGURE_SETTING_DATA_SIZE              4056
#define OPM_REQUESTED_INFORMATION_SIZE               4076
#define OPM_ENCRYPTED_INITIALIZATION_PARAMETERS_SIZE 256
#define OPM_GET_INFORMATION_PARAMETERS_SIZE          4056
#define OPM_HDCP_KEY_SELECTION_VECTOR_SIZE           5
#define OPM_128_BIT_RANDOM_NUMBER_SIZE               16

#define OPM_CGMSA_OFF 0x00
#define OPM_CGMSA_COPY_FREELY 0x01
#define OPM_CGMSA_COPY_NO_MORE 0x02
#define OPM_CGMSA_COPY_ONE_GENERATION 0x03
#define OPM_CGMSA_COPY_NEVER 0x04
#define OPM_CGMSA_REDISTRIBUTION_CONTROL_REQUIRED 0x08

#define OPM_PROTECTION_STANDARD_OTHER 0x80000000
#define OPM_PROTECTION_STANDARD_NONE 0x00000000
#define OPM_PROTECTION_STANDARD_IEC61880_525I 0x00000001
#define OPM_PROTECTION_STANDARD_IEC61880_2_525I 0x00000002
#define OPM_PROTECTION_STANDARD_IEC62375_625P 0x00000004
#define OPM_PROTECTION_STANDARD_EIA608B_525 0x00000008
#define OPM_PROTECTION_STANDARD_EN300294_625I 0x00000010
#define OPM_PROTECTION_STANDARD_CEA805A_TYPEA_525P 0x00000020
#define OPM_PROTECTION_STANDARD_CEA805A_TYPEA_750P 0x00000040
#define OPM_PROTECTION_STANDARD_CEA805A_TYPEA_1125I 0x00000080
#define OPM_PROTECTION_STANDARD_CEA805A_TYPEB_525P 0x00000100
#define OPM_PROTECTION_STANDARD_CEA805A_TYPEB_750P 0x00000200
#define OPM_PROTECTION_STANDARD_CEA805A_TYPEB_1125I 0x00000400
#define OPM_PROTECTION_STANDARD_ARIBTRB15_525I 0x00000800
#define OPM_PROTECTION_STANDARD_ARIBTRB15_525P 0x00001000
#define OPM_PROTECTION_STANDARD_ARIBTRB15_750P 0x00002000
#define OPM_PROTECTION_STANDARD_ARIBTRB15_1125I 0x00004000

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _OPM_VIDEO_OUTPUT_SEMANTICS {
  OPM_VOS_COPP_SEMANTICS   = 0,
  OPM_VOS_OPM_SEMANTICS    = 1
} OPM_VIDEO_OUTPUT_SEMANTICS;

typedef enum _OPM_ACP_PROTECTION_LEVEL {
  OPM_ACP_OFF           = 0,
  OPM_ACP_LEVEL_ONE     = 1,
  OPM_ACP_LEVEL_TWO     = 2,
  OPM_ACP_LEVEL_THREE   = 3,
  OPM_ACP_FORCE_ULONG   = 0x7fffffff
} OPM_ACP_PROTECTION_LEVEL;

typedef enum _OPM_DPCP_PROTECTION_LEVEL {
  OPM_DPCP_OFF           = 0,
  OPM_DPCP_ON            = 1,
  OPM_DPCP_FORCE_ULONG   = 0x7fffffff
} OPM_DPCP_PROTECTION_LEVEL;

typedef enum _OPM_HDCP_PROTECTION_LEVEL {
  OPM_HDCP_OFF           = 0,
  OPM_HDCP_ON            = 1,
  OPM_HDCP_FORCE_ULONG   = 0x7fffffff
} OPM_HDCP_PROTECTION_LEVEL;

typedef enum _OPM_IMAGE_ASPECT_RATIO_EN300294 {
  OPM_ASPECT_RATIO_EN300294_FULL_FORMAT_4_BY_3                    = 0,
  OPM_ASPECT_RATIO_EN300294_BOX_14_BY_9_CENTER                    = 1,
  OPM_ASPECT_RATIO_EN300294_BOX_14_BY_9_TOP                       = 2,
  OPM_ASPECT_RATIO_EN300294_BOX_16_BY_9_CENTER                    = 3,
  OPM_ASPECT_RATIO_EN300294_BOX_16_BY_9_TOP                       = 4,
  OPM_ASPECT_RATIO_EN300294_BOX_GT_16_BY_9_CENTER                 = 5,
  OPM_ASPECT_RATIO_EN300294_FULL_FORMAT_4_BY_3_PROTECTED_CENTER   = 6,
  OPM_ASPECT_RATIO_EN300294_FULL_FORMAT_16_BY_9_ANAMORPHIC        = 7,
  OPM_ASPECT_RATIO_FORCE_ULONG                                    = 0x7FFFFFFF
} OPM_IMAGE_ASPECT_RATIO_EN300294;

typedef struct _OPM_OMAC {
  BYTE abOMAC[OPM_OMAC_SIZE];
} OPM_OMAC;

typedef struct _OPM_REQUESTED_INFORMATION {
  OPM_OMAC omac;
  ULONG    cbRequestedInformationSize;
  BYTE     abRequestedInformation[OPM_REQUESTED_INFORMATION_SIZE];
} OPM_REQUESTED_INFORMATION;

typedef struct _OPM_ENCRYPTED_INITIALIZATION_PARAMETERS {
  BYTE abEncryptedInitializationParameters[OPM_ENCRYPTED_INITIALIZATION_PARAMETERS_SIZE];
} OPM_ENCRYPTED_INITIALIZATION_PARAMETERS;

typedef struct _OPM_RANDOM_NUMBER {
  BYTE abRandomNumber[OPM_128_BIT_RANDOM_NUMBER_SIZE];
} OPM_RANDOM_NUMBER;

typedef struct _OPM_GET_INFO_PARAMETERS {
  OPM_OMAC          omac;
  OPM_RANDOM_NUMBER rnRandomNumber;
  GUID              guidInformation;
  ULONG             ulSequenceNumber;
  ULONG             cbParametersSize;
  BYTE              abParameters[OPM_GET_INFORMATION_PARAMETERS_SIZE];
} OPM_GET_INFO_PARAMETERS;

typedef struct _OPM_COPP_COMPATIBLE_GET_INFO_PARAMETERS {
  OPM_RANDOM_NUMBER rnRandomNumber;
  GUID              guidInformation;
  ULONG             ulSequenceNumber;
  ULONG             cbParametersSize;
  BYTE              abParameters[OPM_GET_INFORMATION_PARAMETERS_SIZE];
} OPM_COPP_COMPATIBLE_GET_INFO_PARAMETERS;

typedef struct _OPM_ACP_AND_CGMSA_SIGNALING {
  OPM_RANDOM_NUMBER rnRandomNumber;
  ULONG             ulStatusFlags;
  ULONG             ulAvailableTVProtectionStandards;
  ULONG             ulActiveTVProtectionStandard;
  ULONG             ulReserved;
  ULONG             ulAspectRatioValidMask1;
  ULONG             ulAspectRatioData1;
  ULONG             ulAspectRatioValidMask2;
  ULONG             ulAspectRatioData2;
  ULONG             ulAspectRatioValidMask3;
  ULONG             ulAspectRatioData3;
  ULONG             ulReserved2[4];
  ULONG             ulReserved3[4];
} OPM_ACP_AND_CGMSA_SIGNALING;

typedef struct _OPM_ACTUAL_OUTPUT_FORMAT {
  OPM_RANDOM_NUMBER  rnRandomNumber;
  ULONG              ulStatusFlags;
  ULONG              ulDisplayWidth;
  ULONG              ulDisplayHeight;
  DXVA2_SampleFormat dsfSampleInterleaveFormat;
  D3DFORMAT          d3dFormat;
  ULONG              ulFrequencyNumerator;
  ULONG              ulFrequencyDenominator;
} OPM_ACTUAL_OUTPUT_FORMAT;

typedef struct _OPM_CONFIGURE_PARAMETERS {
  OPM_OMAC omac;
  GUID     guidSetting;
  ULONG    ulSequenceNumber;
  ULONG    cbParametersSize;
  BYTE     abParameters[OPM_CONFIGURE_SETTING_DATA_SIZE];
} OPM_CONFIGURE_PARAMETERS;

typedef struct _OPM_HDCP_KEY_SELECTION_VECTOR {
  BYTE abKeySelectionVector[OPM_HDCP_KEY_SELECTION_VECTOR_SIZE];
} OPM_HDCP_KEY_SELECTION_VECTOR;

#define OPM_HDCP_FLAG_NONE 0x00
#define OPM_HDCP_FLAG_REPEATER 0x01

typedef struct _OPM_CONNECTED_HDCP_DEVICE_INFORMATION {
  OPM_RANDOM_NUMBER             rnRandomNumber;
  ULONG                         ulStatusFlags;
  ULONG                         ulHDCPFlags;
  OPM_HDCP_KEY_SELECTION_VECTOR ksvB;
  BYTE                          Reserved[11];
  BYTE                          Reserved2[16];
  BYTE                          Reserved3[16];
} OPM_CONNECTED_HDCP_DEVICE_INFORMATION;

typedef struct _OPM_OUTPUT_ID_DATA {
  OPM_RANDOM_NUMBER rnRandomNumber;
  ULONG             ulStatusFlags;
  UINT64            OutputId;
} OPM_OUTPUT_ID_DATA;

typedef struct _OPM_SET_ACP_AND_CGMSA_SIGNALING_PARAMETERS {
  ULONG ulNewTVProtectionStandard;
  ULONG ulAspectRatioChangeMask1;
  ULONG ulAspectRatioData1;
  ULONG ulAspectRatioChangeMask2;
  ULONG ulAspectRatioData2;
  ULONG ulAspectRatioChangeMask3;
  ULONG ulAspectRatioData3;
  ULONG ulReserved[4];
  ULONG ulReserved2[4];
  ULONG ulReserved3;
} OPM_SET_ACP_AND_CGMSA_SIGNALING_PARAMETERS;

typedef struct _OPM_SET_HDCP_SRM_PARAMETERS {
  ULONG ulSRMVersion;
} OPM_SET_HDCP_SRM_PARAMETERS;

typedef struct _OPM_SET_PROTECTION_LEVEL_PARAMETERS {
  ULONG ulProtectionType;
  ULONG ulProtectionLevel;
  ULONG Reserved;
  ULONG Reserved2;
} OPM_SET_PROTECTION_LEVEL_PARAMETERS;

typedef struct _OPM_STANDARD_INFORMATION {
  OPM_RANDOM_NUMBER rnRandomNumber;
  ULONG             ulStatusFlags;
  ULONG             ulInformation;
  ULONG             ulReserved;
  ULONG             ulReserved2;
} OPM_STANDARD_INFORMATION;

#ifdef __cplusplus
}
#endif

#undef  INTERFACE
#define INTERFACE IOPMVideoOutput
DECLARE_INTERFACE_(IOPMVideoOutput,IUnknown)
{
    BEGIN_INTERFACE

    /* IUnknown methods */
    STDMETHOD(QueryInterface)(THIS_ REFIID riid, void **ppvObject) PURE;
    STDMETHOD_(ULONG, AddRef)(THIS) PURE;
    STDMETHOD_(ULONG, Release)(THIS) PURE;

    /* IOPMVideoOutput methods */
    STDMETHOD_(HRESULT,StartInitialization)(THIS_ OPM_RANDOM_NUMBER *prnRandomNumber,BYTE **ppbCertificate,ULONG *pulCertificateLength) PURE;
    STDMETHOD_(HRESULT,FinishInitialization)(THIS_ const OPM_ENCRYPTED_INITIALIZATION_PARAMETERS *pParameters) PURE;
    STDMETHOD_(HRESULT,GetInformation)(THIS_ const OPM_GET_INFO_PARAMETERS *pParameters,OPM_REQUESTED_INFORMATION *pRequestedInformation) PURE;
    STDMETHOD_(HRESULT,COPPCompatibleGetInformation)(THIS_ const OPM_COPP_COMPATIBLE_GET_INFO_PARAMETERS *pParameters,OPM_REQUESTED_INFORMATION *pRequestedInformation) PURE;
    STDMETHOD_(HRESULT,Configure)(THIS_ const OPM_CONFIGURE_PARAMETERS *pParameters,ULONG ulAdditionalParametersSize,const BYTE *pbAdditionalParameters) PURE;

    END_INTERFACE
};
#ifdef COBJMACROS
#define IOPMVideoOutput_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IOPMVideoOutput_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IOPMVideoOutput_Release(This) (This)->lpVtbl->Release(This)
#define IOPMVideoOutput_Configure(This,pParameters,ulAdditionalParametersSize,pbAdditionalParameters) (This)->lpVtbl->Configure(This,pParameters,ulAdditionalParametersSize,pbAdditionalParameters)
#define IOPMVideoOutput_COPPCompatibleGetInformation(This,pParameters,pRequestedInformation) (This)->lpVtbl->COPPCompatibleGetInformation(This,pParameters,pRequestedInformation)
#define IOPMVideoOutput_FinishInitialization(This,pParameters) (This)->lpVtbl->FinishInitialization(This,pParameters)
#define IOPMVideoOutput_GetInformation(This,pParameters,pRequestedInformation) (This)->lpVtbl->GetInformation(This,pParameters,pRequestedInformation)
#define IOPMVideoOutput_StartInitialization(This,prnRandomNumber,ppbCertificate,pulCertificateLength) (This)->lpVtbl->StartInitialization(This,prnRandomNumber,ppbCertificate,pulCertificateLength)
#endif /*COBJMACROS*/

#ifdef __cplusplus
extern "C" {
#endif

HRESULT WINAPI OPMGetVideoOutputsFromHMONITOR(
  HMONITOR hMonitor,
  OPM_VIDEO_OUTPUT_SEMANTICS vos,
  ULONG *pulNumVideoOutputs,
  IOPMVideoOutput ***pppOPMVideoOutputArray
);

HRESULT WINAPI OPMGetVideoOutputsFromIDirect3DDevice9Object(
  IDirect3DDevice9 *pDirect3DDevice9,
  OPM_VIDEO_OUTPUT_SEMANTICS vos,
  ULONG *pulNumVideoOutputs,
  IOPMVideoOutput ***pppOPMVideoOutputArray
);

typedef struct _OPM_GET_CODEC_INFO_INFORMATION {
  OPM_RANDOM_NUMBER rnRandomNumber;
  DWORD             Merit;
} OPM_GET_CODEC_INFO_INFORMATION;

typedef struct _OPM_GET_CODEC_INFO_PARAMETERS {
  DWORD cbVerifier;
  BYTE  Verifier[OPM_GET_INFORMATION_PARAMETERS_SIZE - 4];
} OPM_GET_CODEC_INFO_PARAMETERS;

#ifdef __cplusplus
}
#endif

#endif /*_INC_OPMAPI*/

