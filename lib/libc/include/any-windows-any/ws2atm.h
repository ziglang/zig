/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WS2ATM_H_
#define _WS2ATM_H_

#include <pshpack4.h>

#define ATMPROTO_AALUSER 0x00
#define ATMPROTO_AAL1 0x01
#define ATMPROTO_AAL2 0x02
#define ATMPROTO_AAL34 0x03
#define ATMPROTO_AAL5 0x05

#define SAP_FIELD_ABSENT 0xFFFFFFFE
#define SAP_FIELD_ANY 0xFFFFFFFF
#define SAP_FIELD_ANY_AESA_SEL 0xFFFFFFFA
#define SAP_FIELD_ANY_AESA_REST 0xFFFFFFFB

#define ATM_E164 0x01
#define ATM_NSAP 0x02
#define ATM_AESA 0x02

#define ATM_ADDR_SIZE 20
typedef struct {
  DWORD AddressType;
  DWORD NumofDigits;
  UCHAR Addr[ATM_ADDR_SIZE];
} ATM_ADDRESS;

#define BLLI_L2_ISO_1745 0x01
#define BLLI_L2_Q921 0x02
#define BLLI_L2_X25L 0x06
#define BLLI_L2_X25M 0x07
#define BLLI_L2_ELAPB 0x08
#define BLLI_L2_HDLC_ARM 0x09
#define BLLI_L2_HDLC_NRM 0x0A
#define BLLI_L2_HDLC_ABM 0x0B
#define BLLI_L2_LLC 0x0C
#define BLLI_L2_X75 0x0D
#define BLLI_L2_Q922 0x0E
#define BLLI_L2_USER_SPECIFIED 0x10
#define BLLI_L2_ISO_7776 0x11

#define BLLI_L3_X25 0x06
#define BLLI_L3_ISO_8208 0x07
#define BLLI_L3_X223 0x08
#define BLLI_L3_SIO_8473 0x09
#define BLLI_L3_T70 0x0A
#define BLLI_L3_ISO_TR9577 0x0B
#define BLLI_L3_USER_SPECIFIED 0x10

#define BLLI_L3_IPI_SNAP 0x80
#define BLLI_L3_IPI_IP 0xCC

typedef struct {
  DWORD Layer2Protocol;
  DWORD Layer2UserSpecifiedProtocol;
  DWORD Layer3Protocol;
  DWORD Layer3UserSpecifiedProtocol;
  DWORD Layer3IPI;
  UCHAR SnapID[5];
} ATM_BLLI;

#define BHLI_ISO 0x00
#define BHLI_UserSpecific 0x01
#define BHLI_HighLayerProfile 0x02
#define BHLI_VendorSpecificAppId 0x03

typedef struct {
  DWORD HighLayerInfoType;
  DWORD HighLayerInfoLength;
  UCHAR HighLayerInfo[8];
} ATM_BHLI;

typedef struct sockaddr_atm {
  u_short satm_family;
  ATM_ADDRESS satm_number;
  ATM_BLLI satm_blli;
  ATM_BHLI satm_bhli;
} sockaddr_atm,SOCKADDR_ATM,*PSOCKADDR_ATM,*LPSOCKADDR_ATM;

typedef enum {
  IE_AALParameters,IE_TrafficDescriptor,IE_BroadbandBearerCapability,IE_BHLI,IE_BLLI,IE_CalledPartyNumber,IE_CalledPartySubaddress,
  IE_CallingPartyNumber,IE_CallingPartySubaddress,IE_Cause,IE_QOSClass,IE_TransitNetworkSelection
} Q2931_IE_TYPE;

typedef struct {
  Q2931_IE_TYPE IEType;
  ULONG IELength;
  UCHAR IE[1];
} Q2931_IE;

typedef enum {
  AALTYPE_5 = 5,AALTYPE_USER = 16
} AAL_TYPE;

#define AAL5_MODE_MESSAGE 0x01
#define AAL5_MODE_STREAMING 0x02

#define AAL5_SSCS_NULL 0x00
#define AAL5_SSCS_SSCOP_ASSURED 0x01
#define AAL5_SSCS_SSCOP_NON_ASSURED 0x02
#define AAL5_SSCS_FRAME_RELAY 0x04

typedef struct {
  ULONG ForwardMaxCPCSSDUSize;
  ULONG BackwardMaxCPCSSDUSize;
  UCHAR Mode;
  UCHAR SSCSType;
} AAL5_PARAMETERS;

typedef struct {
  ULONG UserDefined;
} AALUSER_PARAMETERS;

typedef struct {
  AAL_TYPE AALType;
  union {
    AAL5_PARAMETERS AAL5Parameters;
    AALUSER_PARAMETERS AALUserParameters;
  } AALSpecificParameters;
} AAL_PARAMETERS_IE;

typedef struct {
  ULONG PeakCellRate_CLP0;
  ULONG PeakCellRate_CLP01;
  ULONG SustainableCellRate_CLP0;
  ULONG SustainableCellRate_CLP01;
  ULONG MaxBurstSize_CLP0;
  ULONG MaxBurstSize_CLP01;
  WINBOOL Tagging;
} ATM_TD;

typedef struct {
  ATM_TD Forward;
  ATM_TD Backward;
  WINBOOL BestEffort;
} ATM_TRAFFIC_DESCRIPTOR_IE;

#define BCOB_A 0x01
#define BCOB_C 0x03
#define BCOB_X 0x10

#define TT_NOIND 0x00
#define TT_CBR 0x04
#define TT_VBR 0x08

#define TR_NOIND 0x00
#define TR_END_TO_END 0x01
#define TR_NO_END_TO_END 0x02

#define CLIP_NOT 0x00
#define CLIP_SUS 0x20

#define UP_P2P 0x00
#define UP_P2MP 0x01

typedef struct {
  UCHAR BearerClass;
  UCHAR TrafficType;
  UCHAR TimingRequirements;
  UCHAR ClippingSusceptability;
  UCHAR UserPlaneConnectionConfig;
} ATM_BROADBAND_BEARER_CAPABILITY_IE;

typedef ATM_BHLI ATM_BHLI_IE;

#define BLLI_L2_MODE_NORMAL 0x40
#define BLLI_L2_MODE_EXT 0x80

#define BLLI_L3_MODE_NORMAL 0x40
#define BLLI_L3_MODE_EXT 0x80

#define BLLI_L3_PACKET_16 0x04
#define BLLI_L3_PACKET_32 0x05
#define BLLI_L3_PACKET_64 0x06
#define BLLI_L3_PACKET_128 0x07
#define BLLI_L3_PACKET_256 0x08
#define BLLI_L3_PACKET_512 0x09
#define BLLI_L3_PACKET_1024 0x0A
#define BLLI_L3_PACKET_2048 0x0B
#define BLLI_L3_PACKET_4096 0x0C

typedef struct {
  DWORD Layer2Protocol;
  UCHAR Layer2Mode;
  UCHAR Layer2WindowSize;
  DWORD Layer2UserSpecifiedProtocol;
  DWORD Layer3Protocol;
  UCHAR Layer3Mode;
  UCHAR Layer3DefaultPacketSize;
  UCHAR Layer3PacketWindowSize;
  DWORD Layer3UserSpecifiedProtocol;
  DWORD Layer3IPI;
  UCHAR SnapID[5];
} ATM_BLLI_IE;

typedef ATM_ADDRESS ATM_CALLED_PARTY_NUMBER_IE;
typedef ATM_ADDRESS ATM_CALLED_PARTY_SUBADDRESS_IE;

#define PI_ALLOWED 0x00
#define PI_RESTRICTED 0x40
#define PI_NUMBER_NOT_AVAILABLE 0x80

#define SI_USER_NOT_SCREENED 0x00
#define SI_USER_PASSED 0x01
#define SI_USER_FAILED 0x02
#define SI_NETWORK 0x03

typedef struct {
  ATM_ADDRESS ATM_Number;
  UCHAR Presentation_Indication;
  UCHAR Screening_Indicator;
} ATM_CALLING_PARTY_NUMBER_IE;

typedef ATM_ADDRESS ATM_CALLING_PARTY_SUBADDRESS_IE;

#define CAUSE_LOC_USER 0x00
#define CAUSE_LOC_PRIVATE_LOCAL 0x01
#define CAUSE_LOC_PUBLIC_LOCAL 0x02
#define CAUSE_LOC_TRANSIT_NETWORK 0x03
#define CAUSE_LOC_PUBLIC_REMOTE 0x04
#define CAUSE_LOC_PRIVATE_REMOTE 0x05
#define CAUSE_LOC_INTERNATIONAL_NETWORK 0x07
#define CAUSE_LOC_BEYOND_INTERWORKING 0x0A

#define CAUSE_UNALLOCATED_NUMBER 0x01
#define CAUSE_NO_ROUTE_TO_TRANSIT_NETWORK 0x02
#define CAUSE_NO_ROUTE_TO_DESTINATION 0x03
#define CAUSE_VPI_VCI_UNACCEPTABLE 0x0A
#define CAUSE_NORMAL_CALL_CLEARING 0x10
#define CAUSE_USER_BUSY 0x11
#define CAUSE_NO_USER_RESPONDING 0x12
#define CAUSE_CALL_REJECTED 0x15
#define CAUSE_NUMBER_CHANGED 0x16
#define CAUSE_USER_REJECTS_CLIR 0x17
#define CAUSE_DESTINATION_OUT_OF_ORDER 0x1B
#define CAUSE_INVALID_NUMBER_FORMAT 0x1C
#define CAUSE_STATUS_ENQUIRY_RESPONSE 0x1E
#define CAUSE_NORMAL_UNSPECIFIED 0x1F
#define CAUSE_VPI_VCI_UNAVAILABLE 0x23
#define CAUSE_NETWORK_OUT_OF_ORDER 0x26
#define CAUSE_TEMPORARY_FAILURE 0x29
#define CAUSE_ACCESS_INFORMAION_DISCARDED 0x2B
#define CAUSE_NO_VPI_VCI_AVAILABLE 0x2D
#define CAUSE_RESOURCE_UNAVAILABLE 0x2F
#define CAUSE_QOS_UNAVAILABLE 0x31
#define CAUSE_USER_CELL_RATE_UNAVAILABLE 0x33
#define CAUSE_BEARER_CAPABILITY_UNAUTHORIZED 0x39
#define CAUSE_BEARER_CAPABILITY_UNAVAILABLE 0x3A
#define CAUSE_OPTION_UNAVAILABLE 0x3F
#define CAUSE_BEARER_CAPABILITY_UNIMPLEMENTED 0x41
#define CAUSE_UNSUPPORTED_TRAFFIC_PARAMETERS 0x49
#define CAUSE_INVALID_CALL_REFERENCE 0x51
#define CAUSE_CHANNEL_NONEXISTENT 0x52
#define CAUSE_INCOMPATIBLE_DESTINATION 0x58
#define CAUSE_INVALID_ENDPOINT_REFERENCE 0x59
#define CAUSE_INVALID_TRANSIT_NETWORK_SELECTION 0x5B
#define CAUSE_TOO_MANY_PENDING_ADD_PARTY 0x5C
#define CAUSE_AAL_PARAMETERS_UNSUPPORTED 0x5D
#define CAUSE_MANDATORY_IE_MISSING 0x60
#define CAUSE_UNIMPLEMENTED_MESSAGE_TYPE 0x61
#define CAUSE_UNIMPLEMENTED_IE 0x63
#define CAUSE_INVALID_IE_CONTENTS 0x64
#define CAUSE_INVALID_STATE_FOR_MESSAGE 0x65
#define CAUSE_RECOVERY_ON_TIMEOUT 0x66
#define CAUSE_INCORRECT_MESSAGE_LENGTH 0x68
#define CAUSE_PROTOCOL_ERROR 0x6F

#define CAUSE_COND_UNKNOWN 0x00
#define CAUSE_COND_PERMANENT 0x01
#define CAUSE_COND_TRANSIENT 0x02

#define CAUSE_REASON_USER 0x00
#define CAUSE_REASON_IE_MISSING 0x04
#define CAUSE_REASON_IE_INSUFFICIENT 0x08

#define CAUSE_PU_PROVIDER 0x00
#define CAUSE_PU_USER 0x08

#define CAUSE_NA_NORMAL 0x00
#define CAUSE_NA_ABNORMAL 0x04

typedef struct {
  UCHAR Location;
  UCHAR Cause;
  UCHAR DiagnosticsLength;
  UCHAR Diagnostics[4];
} ATM_CAUSE_IE;

#define QOS_CLASS0 0x00
#define QOS_CLASS1 0x01
#define QOS_CLASS2 0x02
#define QOS_CLASS3 0x03
#define QOS_CLASS4 0x04

typedef struct {
  UCHAR QOSClassForward;
  UCHAR QOSClassBackward;
} ATM_QOS_CLASS_IE;

#define TNS_TYPE_NATIONAL 0x40

#define TNS_PLAN_CARRIER_ID_CODE 0x01

typedef struct {
  UCHAR TypeOfNetworkId;
  UCHAR NetworkIdPlan;
  UCHAR NetworkIdLength;
  UCHAR NetworkId[1];
} ATM_TRANSIT_NETWORK_SELECTION_IE;

#define SIO_GET_NUMBER_OF_ATM_DEVICES 0x50160001
#define SIO_GET_ATM_ADDRESS 0xd0160002
#define SIO_ASSOCIATE_PVC 0x90160003
#define SIO_GET_ATM_CONNECTION_ID 0x50160004

typedef struct {
  DWORD DeviceNumber;
  DWORD VPI;
  DWORD VCI;
} ATM_CONNECTION_ID;

typedef struct {
  ATM_CONNECTION_ID PvcConnectionId;
  QOS PvcQos;
} ATM_PVC_PARAMS;

#include <poppack.h>
#endif
