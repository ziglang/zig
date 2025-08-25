/*
 * bdamedia.h
 *
 * This file is part of the ReactOS DXSDK package.
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

#ifndef _BDAMEDIA_
#define _BDAMEDIA_

#include <ksmedia.h>
#include <bdatypes.h>

typedef struct _KSP_BDA_NODE_PIN {
  KSPROPERTY Property;
  ULONG ulNodeType;
  ULONG ulInputPinId;
  ULONG ulOutputPinId;
} KSP_BDA_NODE_PIN, *PKSP_BDA_NODE_PIN;

typedef struct _KSM_BDA_PIN {
  KSMETHOD Method;
  __C89_NAMELESS union {
    ULONG PinId;
    ULONG PinType;
  };
  ULONG Reserved;
} KSM_BDA_PIN, *PKSM_BDA_PIN;

typedef struct _KSM_BDA_PIN_PAIR {
  KSMETHOD Method;
  __C89_NAMELESS union {
    ULONG InputPinId;
    ULONG InputPinType;
  };
  __C89_NAMELESS union {
    ULONG OutputPinId;
    ULONG OutputPinType;
  };
} KSM_BDA_PIN_PAIR, *PKSM_BDA_PIN_PAIR;


/* ------------------------------------------------------------
    BDA Topology Property Set {A14EE835-0A23-11d3-9CC7-00C04F7971E0}
*/

#define STATIC_KSPROPSETID_BdaTopology						\
	0xa14ee835, 0x0a23, 0x11d3, 0x9c, 0xc7, 0x0, 0xc0, 0x4f, 0x79, 0x71, 0xe0
DEFINE_GUIDSTRUCT("A14EE835-0A23-11d3-9CC7-00C04F7971E0", KSPROPSETID_BdaTopology);
#define KSPROPSETID_BdaTopology		DEFINE_GUIDNAMED(KSPROPSETID_BdaTopology)

typedef enum {
  KSPROPERTY_BDA_NODE_TYPES,
  KSPROPERTY_BDA_PIN_TYPES,
  KSPROPERTY_BDA_TEMPLATE_CONNECTIONS,
  KSPROPERTY_BDA_NODE_METHODS,
  KSPROPERTY_BDA_NODE_PROPERTIES,
  KSPROPERTY_BDA_NODE_EVENTS,
  KSPROPERTY_BDA_CONTROLLING_PIN_ID,
  KSPROPERTY_BDA_NODE_DESCRIPTORS
} KSPROPERTY_BDA_TOPOLOGY;

#define DEFINE_KSPROPERTY_ITEM_BDA_NODE_TYPES(GetHandler, SetHandler)		\
	DEFINE_KSPROPERTY_ITEM(							\
				KSPROPERTY_BDA_NODE_TYPES,			\
				(GetHandler),					\
				sizeof(KSPROPERTY),				\
				0,						\
				FALSE,						\
				NULL, 0, NULL, NULL, 0)

#define DEFINE_KSPROPERTY_ITEM_BDA_PIN_TYPES(GetHandler, SetHandler)		\
	DEFINE_KSPROPERTY_ITEM(							\
				KSPROPERTY_BDA_PIN_TYPES,			\
				(GetHandler),					\
				sizeof(KSPROPERTY),				\
				0,						\
				FALSE,						\
				NULL, 0, NULL, NULL, 0)

#define DEFINE_KSPROPERTY_ITEM_BDA_TEMPLATE_CONNECTIONS(GetHandler, SetHandler)	\
	DEFINE_KSPROPERTY_ITEM(							\
				KSPROPERTY_BDA_TEMPLATE_CONNECTIONS,		\
				(GetHandler),					\
				sizeof(KSPROPERTY),				\
				sizeof(BDA_TEMPLATE_CONNECTION),		\
				FALSE,						\
				NULL, 0, NULL, NULL, 0)

#define DEFINE_KSPROPERTY_ITEM_BDA_NODE_METHODS(GetHandler, SetHandler)		\
	DEFINE_KSPROPERTY_ITEM(							\
				KSPROPERTY_BDA_NODE_METHODS,			\
				(GetHandler),					\
				sizeof(KSP_NODE),				\
				0,						\
				FALSE,						\
				NULL, 0, NULL, NULL, 0)

#define DEFINE_KSPROPERTY_ITEM_BDA_NODE_PROPERTIES(GetHandler, SetHandler)	\
	DEFINE_KSPROPERTY_ITEM(							\
				KSPROPERTY_BDA_NODE_PROPERTIES,			\
				(GetHandler),					\
				sizeof(KSP_NODE),				\
				0,						\
				FALSE,						\
				NULL, 0, NULL, NULL, 0)

#define DEFINE_KSPROPERTY_ITEM_BDA_NODE_EVENTS(GetHandler, SetHandler)		\
	DEFINE_KSPROPERTY_ITEM(							\
				KSPROPERTY_BDA_NODE_EVENTS,			\
				(GetHandler),					\
				sizeof(KSP_NODE),				\
				0,						\
				FALSE,						\
				NULL, 0, NULL, NULL, 0)

#define DEFINE_KSPROPERTY_ITEM_BDA_CONTROLLING_PIN_ID(GetHandler, SetHandler)	\
	DEFINE_KSPROPERTY_ITEM(							\
				KSPROPERTY_BDA_CONTROLLING_PIN_ID,		\
				(GetHandler),					\
				sizeof(KSP_BDA_NODE_PIN),			\
				sizeof(ULONG),					\
				FALSE,						\
				NULL, 0, NULL, NULL, 0)

#define DEFINE_KSPROPERTY_ITEM_BDA_NODE_DESCRIPTORS(GetHandler, SetHandler)	\
	DEFINE_KSPROPERTY_ITEM(							\
				KSPROPERTY_BDA_NODE_DESCRIPTORS,		\
				(GetHandler),					\
				sizeof(KSPROPERTY),				\
				0,						\
				FALSE,						\
				NULL, 0, NULL, NULL, 0)


/* ------------------------------------------------------------
    BDA Device Configuration Method Set {71985F45-1CA1-11d3-9CC8-00C04F7971E0}
*/

#define STATIC_KSMETHODSETID_BdaDeviceConfiguration				\
	0x71985f45, 0x1ca1, 0x11d3, 0x9c, 0xc8, 0x0, 0xc0, 0x4f, 0x79, 0x71, 0xe0
DEFINE_GUIDSTRUCT("71985F45-1CA1-11d3-9CC8-00C04F7971E0", KSMETHODSETID_BdaDeviceConfiguration);
#define KSMETHODSETID_BdaDeviceConfiguration DEFINE_GUIDNAMED(KSMETHODSETID_BdaDeviceConfiguration)

typedef enum {
  KSMETHOD_BDA_CREATE_PIN_FACTORY = 0,
  KSMETHOD_BDA_DELETE_PIN_FACTORY,
  KSMETHOD_BDA_CREATE_TOPOLOGY
} KSMETHOD_BDA_DEVICE_CONFIGURATION;

#define DEFINE_KSMETHOD_ITEM_BDA_CREATE_PIN_FACTORY(MethodHandler, SupportHandler) \
	DEFINE_KSMETHOD_ITEM(							\
				KSMETHOD_BDA_CREATE_PIN_FACTORY,		\
				KSMETHOD_TYPE_READ,				\
				(MethodHandler),				\
				sizeof(KSM_BDA_PIN),				\
				sizeof(ULONG),					\
				SupportHandler)

#define DEFINE_KSMETHOD_ITEM_BDA_DELETE_PIN_FACTORY(MethodHandler, SupportHandler) \
	DEFINE_KSMETHOD_ITEM(							\
				KSMETHOD_BDA_DELETE_PIN_FACTORY,		\
				KSMETHOD_TYPE_NONE,				\
				(MethodHandler),				\
				sizeof(KSM_BDA_PIN),				\
				0,						\
				SupportHandler)

#define DEFINE_KSMETHOD_ITEM_BDA_CREATE_TOPOLOGY(MethodHandler, SupportHandler)	\
	DEFINE_KSMETHOD_ITEM(							\
				KSMETHOD_BDA_CREATE_TOPOLOGY,			\
				KSMETHOD_TYPE_WRITE,				\
				(MethodHandler),				\
				sizeof(KSM_BDA_PIN_PAIR),			\
				0,						\
				SupportHandler)


/* ------------------------------------------------------------
  BDA Pin Control Property {0DED49D5-A8B7-4d5d-97A1-12B0C195874D}
*/

#define STATIC_KSPROPSETID_BdaPinControl					\
	0xded49d5, 0xa8b7, 0x4d5d, 0x97, 0xa1, 0x12, 0xb0, 0xc1, 0x95, 0x87, 0x4d
DEFINE_GUIDSTRUCT("0DED49D5-A8B7-4d5d-97A1-12B0C195874D", KSPROPSETID_BdaPinControl);
#define KSPROPSETID_BdaPinControl	DEFINE_GUIDNAMED(KSPROPSETID_BdaPinControl)

typedef enum {
  KSPROPERTY_BDA_PIN_ID = 0,
  KSPROPERTY_BDA_PIN_TYPE
} KSPROPERTY_BDA_PIN_CONTROL;

#define DEFINE_KSPROPERTY_ITEM_BDA_PIN_ID(GetHandler, SetHandler)		\
	DEFINE_KSPROPERTY_ITEM(							\
				KSPROPERTY_BDA_PIN_ID,				\
				(GetHandler),					\
				sizeof(KSPROPERTY),				\
				sizeof(ULONG),					\
				FALSE,						\
				NULL, 0, NULL, NULL, 0)

#define DEFINE_KSPROPERTY_ITEM_BDA_PIN_TYPE(GetHandler, SetHandler)		\
	DEFINE_KSPROPERTY_ITEM(							\
				KSPROPERTY_BDA_PIN_TYPE,			\
				(GetHandler),					\
				sizeof(KSPROPERTY),				\
				sizeof(ULONG),					\
				FALSE,						\
				NULL, 0, NULL, NULL, 0)


/* ------------------------------------------------------------
  BDA Change Sync Method Set {FD0A5AF3-B41D-11d2-9C95-00C04F7971E0}
*/

#define STATIC_KSMETHODSETID_BdaChangeSync					\
	0xfd0a5af3, 0xb41d, 0x11d2, 0x9c, 0x95, 0x0, 0xc0, 0x4f, 0x79, 0x71, 0xe0
DEFINE_GUIDSTRUCT("FD0A5AF3-B41D-11d2-9C95-00C04F7971E0", KSMETHODSETID_BdaChangeSync);
#define KSMETHODSETID_BdaChangeSync DEFINE_GUIDNAMED(KSMETHODSETID_BdaChangeSync)

typedef enum {
  KSMETHOD_BDA_START_CHANGES = 0,
  KSMETHOD_BDA_CHECK_CHANGES,
  KSMETHOD_BDA_COMMIT_CHANGES,
  KSMETHOD_BDA_GET_CHANGE_STATE
} KSMETHOD_BDA_CHANGE_SYNC;

#define DEFINE_KSMETHOD_ITEM_BDA_START_CHANGES(MethodHandler, SupportHandler)	\
	DEFINE_KSMETHOD_ITEM(							\
				KSMETHOD_BDA_START_CHANGES,			\
				KSMETHOD_TYPE_NONE,				\
				(MethodHandler),				\
				sizeof(KSMETHOD),				\
				0,						\
				SupportHandler)

#define DEFINE_KSMETHOD_ITEM_BDA_CHECK_CHANGES(MethodHandler, SupportHandler)	\
	DEFINE_KSMETHOD_ITEM(							\
				KSMETHOD_BDA_CHECK_CHANGES,			\
				KSMETHOD_TYPE_NONE,				\
				(MethodHandler),				\
				sizeof(KSMETHOD),				\
				0,						\
				SupportHandler)

#define DEFINE_KSMETHOD_ITEM_BDA_COMMIT_CHANGES(MethodHandler, SupportHandler)	\
	DEFINE_KSMETHOD_ITEM(							\
				KSMETHOD_BDA_COMMIT_CHANGES,			\
				KSMETHOD_TYPE_NONE,				\
				(MethodHandler),				\
				sizeof(KSMETHOD),				\
				0,						\
				SupportHandler)

#define DEFINE_KSMETHOD_ITEM_BDA_GET_CHANGE_STATE(MethodHandler, SupportHandler) \
	DEFINE_KSMETHOD_ITEM(							\
				KSMETHOD_BDA_GET_CHANGE_STATE,			\
				KSMETHOD_TYPE_READ,				\
				(MethodHandler),				\
				sizeof(KSMETHOD),				\
				0,						\
				SupportHandler)

#define STATIC_KSPROPSETID_BdaFrequencyFilter					\
	0x71985f47, 0x1ca1, 0x11d3, 0x9c, 0xc8, 0x0, 0xc0, 0x4f, 0x79, 0x71, 0xe0
DEFINE_GUIDSTRUCT("71985F47-1CA1-11d3-9CC8-00C04F7971E0", KSPROPSETID_BdaFrequencyFilter);
#define KSPROPSETID_BdaFrequencyFilter DEFINE_GUIDNAMED(KSPROPSETID_BdaFrequencyFilter)

typedef enum {
  KSPROPERTY_BDA_RF_TUNER_FREQUENCY = 0,
  KSPROPERTY_BDA_RF_TUNER_POLARITY,
  KSPROPERTY_BDA_RF_TUNER_RANGE,
  KSPROPERTY_BDA_RF_TUNER_TRANSPONDER,
  KSPROPERTY_BDA_RF_TUNER_BANDWIDTH,
  KSPROPERTY_BDA_RF_TUNER_FREQUENCY_MULTIPLIER,
  KSPROPERTY_BDA_RF_TUNER_CAPS,
  KSPROPERTY_BDA_RF_TUNER_SCAN_STATUS,
  KSPROPERTY_BDA_RF_TUNER_STANDARD,
  KSPROPERTY_BDA_RF_TUNER_STANDARD_MODE
} KSPROPERTY_BDA_FREQUENCY_FILTER;

#define STATIC_KSPROPSETID_BdaDigitalDemodulator				\
	0xef30f379, 0x985b, 0x4d10, 0xb6, 0x40, 0xa7, 0x9d, 0x5e, 0x4, 0xe1, 0xe0
DEFINE_GUIDSTRUCT("EF30F379-985B-4d10-B640-A79D5E04E1E0", KSPROPSETID_BdaDigitalDemodulator);
#define KSPROPSETID_BdaDigitalDemodulator DEFINE_GUIDNAMED(KSPROPSETID_BdaDigitalDemodulator)

typedef enum {
  KSPROPERTY_BDA_MODULATION_TYPE = 0,
  KSPROPERTY_BDA_INNER_FEC_TYPE,
  KSPROPERTY_BDA_INNER_FEC_RATE,
  KSPROPERTY_BDA_OUTER_FEC_TYPE,
  KSPROPERTY_BDA_OUTER_FEC_RATE,
  KSPROPERTY_BDA_SYMBOL_RATE,
  KSPROPERTY_BDA_SPECTRAL_INVERSION,
  KSPROPERTY_BDA_GUARD_INTERVAL,
  KSPROPERTY_BDA_TRANSMISSION_MODE,
  KSPROPERTY_BDA_ROLL_OFF,
  KSPROPERTY_BDA_PILOT,
  KSPROPERTY_BDA_SIGNALTIMEOUTS
} KSPROPERTY_BDA_DIGITAL_DEMODULATOR;

#define STATIC_KSPROPSETID_BdaLNBInfo						\
	0x992cf102, 0x49f9, 0x4719, 0xa6, 0x64, 0xc4, 0xf2, 0x3e, 0x24, 0x8, 0xf4
DEFINE_GUIDSTRUCT("992CF102-49F9-4719-A664-C4F23E2408F4", KSPROPSETID_BdaLNBInfo);
#define KSPROPSETID_BdaLNBInfo		DEFINE_GUIDNAMED(KSPROPSETID_BdaLNBInfo)

typedef enum {
  KSPROPERTY_BDA_LNB_LOF_LOW_BAND = 0,
  KSPROPERTY_BDA_LNB_LOF_HIGH_BAND,
  KSPROPERTY_BDA_LNB_SWITCH_FREQUENCY
} KSPROPERTY_BDA_LNB_INFO;

#define STATIC_KSPROPSETID_BdaSignalStats					\
	0x1347d106, 0xcf3a, 0x428a, 0xa5, 0xcb, 0xac, 0xd, 0x9a, 0x2a, 0x43, 0x38
DEFINE_GUIDSTRUCT("1347D106-CF3A-428a-A5CB-AC0D9A2A4338", KSPROPSETID_BdaSignalStats);
#define KSPROPSETID_BdaSignalStats	DEFINE_GUIDNAMED(KSPROPSETID_BdaSignalStats)

typedef enum {
  KSPROPERTY_BDA_SIGNAL_STRENGTH = 0,
  KSPROPERTY_BDA_SIGNAL_QUALITY,
  KSPROPERTY_BDA_SIGNAL_PRESENT,
  KSPROPERTY_BDA_SIGNAL_LOCKED,
  KSPROPERTY_BDA_SAMPLE_TIME
} KSPROPERTY_BDA_SIGNAL_STATS;

typedef struct tagBDA_TRANSPORT_INFO {
  ULONG ulcbPhyiscalPacket;
  ULONG ulcbPhyiscalFrame;
  ULONG ulcbPhyiscalFrameAlignment;
  REFERENCE_TIME AvgTimePerFrame;
} BDA_TRANSPORT_INFO, *PBDA_TRANSPORT_INFO;

typedef struct tagKS_DATARANGE_BDA_TRANSPORT {
  KSDATARANGE DataRange;
  BDA_TRANSPORT_INFO BdaTransportInfo;
} KS_DATARANGE_BDA_TRANSPORT, *PKS_DATARANGE_BDA_TRANSPORT;

#if (_WIN32_WINNT >= 0x0601)
typedef enum tagChannelChangeSpanningEvent_State {
  ChannelChangeSpanningEvent_Start   = 0,
  ChannelChangeSpanningEvent_End     = 2 
} ChannelChangeSpanningEvent_State;

typedef struct _ChannelChangeInfo {
  ChannelChangeSpanningEvent_State state;
  ULONGLONG                        TimeStamp;
} ChannelChangeInfo;

typedef struct _ChannelInfo {
  LONG lFrequency;
  __C89_NAMELESS union {
     struct {
      LONG lONID;
      LONG lTSID;
      LONG lSID;
    } DVB;
    struct {
      LONG lProgNumber;
    } DC;
    struct {
      LONG lProgNumber;
    } ATSC;
  } ;
} ChannelInfo;

typedef enum _PBDAParentalControlPolicy {
  PBDAParentalControlGeneralPolicy    = 0,
  PBDAParentalControlLiveOnlyPolicy   = 1 
} PBDAParentalControlPolicy;

typedef enum _SignalAndServiceStatusSpanningEvent_State {
  SignalAndServiceStatusSpanningEvent_Clear           = 0,
  SignalAndServiceStatusSpanningEvent_NoTVSignal      = 1,
  SignalAndServiceStatusSpanningEvent_ServiceOffAir   = 2 
} SignalAndServiceStatusSpanningEvent_State;

typedef struct _DualMonoInfo {
  LANGID LangID1;
  LANGID LangID2;
  LONG   lISOLangCode1;
  LONG   lISOLangCode2;
} DualMonoInfo;

typedef struct _DVBScramblingControlSpanningEvent {
  ULONG ulPID;
  WINBOOL fScrambled;
} DVBScramblingControlSpanningEvent;

typedef struct _LanguageInfo {
  LANGID LangID;
  LONG   lISOLangCode;
} LanguageInfo;

typedef struct _PBDAParentalControl {
  ULONG ulStartTime;
  ULONG ulEndTime;
  ULONG ulPolicy;
} PBDAParentalControl;

typedef struct _PIDListSpanningEvent {
  WORD  wPIDCount;
  ULONG pulPIDs[1];
} PIDListSpanningEvent;

typedef struct _SpanningEventDescriptor {
  WORD wDataLen;
  WORD wProgNumber;
  WORD wSID;
  BYTE bDescriptor[1];
} SpanningEventDescriptor;

typedef struct _SpanningEventEmmMessage {
  BYTE  bCAbroadcasterGroupId;
  BYTE  bMessageControl;
  WORD  wServiceId;
  WORD  wTableIdExtension;
  BYTE  bDeletionStatus;
  BYTE  bDisplayingDuration1;
  BYTE  bDisplayingDuration2;
  BYTE  bDisplayingDuration3;
  BYTE  bDisplayingCycle;
  BYTE  bFormatVersion;
  BYTE  bDisplayPosition;
  WORD  wMessageLength;
  WCHAR szMessageArea[MIN_DIMENSION];
} SpanningEventEmmMessage;

#endif /*(_WIN32_WINNT >= 0x0601)*/

/* ------------------------------------------------------------
  BDA Stream Format GUIDs
*/

#define STATIC_KSDATAFORMAT_TYPE_BDA_ANTENNA					\
	0x71985f41, 0x1ca1, 0x11d3, 0x9c, 0xc8, 0x0, 0xc0, 0x4f, 0x79, 0x71, 0xe0
DEFINE_GUIDSTRUCT("71985F41-1CA1-11d3-9CC8-00C04F7971E0", KSDATAFORMAT_TYPE_BDA_ANTENNA);
#define KSDATAFORMAT_TYPE_BDA_ANTENNA DEFINE_GUIDNAMED(KSDATAFORMAT_TYPE_BDA_ANTENNA)

#define STATIC_KSDATAFORMAT_SUBTYPE_BDA_MPEG2_TRANSPORT				\
	0xf4aeb342, 0x0329, 0x4fdd, 0xa8, 0xfd, 0x4a, 0xff, 0x49, 0x26, 0xc9, 0x78
DEFINE_GUIDSTRUCT("F4AEB342-0329-4fdd-A8FD-4AFF4926C978", KSDATAFORMAT_SUBTYPE_BDA_MPEG2_TRANSPORT);
#define KSDATAFORMAT_SUBTYPE_BDA_MPEG2_TRANSPORT DEFINE_GUIDNAMED(KSDATAFORMAT_SUBTYPE_BDA_MPEG2_TRANSPORT)

#define STATIC_KSDATAFORMAT_SPECIFIER_BDA_TRANSPORT				\
	0x8deda6fd, 0xac5f, 0x4334, 0x8e, 0xcf, 0xa4, 0xba, 0x8f, 0xa7, 0xd0, 0xf0
DEFINE_GUIDSTRUCT("8DEDA6FD-AC5F-4334-8ECF-A4BA8FA7D0F0", KSDATAFORMAT_SPECIFIER_BDA_TRANSPORT);
#define KSDATAFORMAT_SPECIFIER_BDA_TRANSPORT DEFINE_GUIDNAMED(KSDATAFORMAT_SPECIFIER_BDA_TRANSPORT)

#define STATIC_KSDATAFORMAT_TYPE_BDA_IF_SIGNAL					\
	0x61be0b47, 0xa5eb, 0x499b, 0x9a, 0x85, 0x5b, 0x16, 0xc0, 0x7f, 0x12, 0x58
DEFINE_GUIDSTRUCT("61BE0B47-A5EB-499b-9A85-5B16C07F1258", KSDATAFORMAT_TYPE_BDA_IF_SIGNAL);
#define KSDATAFORMAT_TYPE_BDA_IF_SIGNAL DEFINE_GUIDNAMED(KSDATAFORMAT_TYPE_BDA_IF_SIGNAL)

#define STATIC_KSDATAFORMAT_TYPE_MPEG2_SECTIONS					\
	0x455f176c, 0x4b06, 0x47ce, 0x9a, 0xef, 0x8c, 0xae, 0xf7, 0x3d, 0xf7, 0xb5
DEFINE_GUIDSTRUCT("455F176C-4B06-47CE-9AEF-8CAEF73DF7B5", KSDATAFORMAT_TYPE_MPEG2_SECTIONS);
#define KSDATAFORMAT_TYPE_MPEG2_SECTIONS DEFINE_GUIDNAMED(KSDATAFORMAT_TYPE_MPEG2_SECTIONS)

#define STATIC_KSDATAFORMAT_SUBTYPE_ATSC_SI					\
	0xb3c7397c, 0xd303, 0x414d, 0xb3, 0x3c, 0x4e, 0xd2, 0xc9, 0xd2, 0x97, 0x33
DEFINE_GUIDSTRUCT("B3C7397C-D303-414D-B33C-4ED2C9D29733", KSDATAFORMAT_SUBTYPE_ATSC_SI);
#define KSDATAFORMAT_SUBTYPE_ATSC_SI DEFINE_GUIDNAMED(KSDATAFORMAT_SUBTYPE_ATSC_SI)

#define STATIC_KSDATAFORMAT_SUBTYPE_DVB_SI					\
	0xe9dd31a3, 0x221d, 0x4adb, 0x85, 0x32, 0x9a, 0xf3, 0x9, 0xc1, 0xa4, 0x8
DEFINE_GUIDSTRUCT("e9dd31a3-221d-4adb-8532-9af309c1a408", KSDATAFORMAT_SUBTYPE_DVB_SI);
#define KSDATAFORMAT_SUBTYPE_DVB_SI DEFINE_GUIDNAMED(KSDATAFORMAT_SUBTYPE_DVB_SI)

#define STATIC_KSDATAFORMAT_SUBTYPE_BDA_OPENCABLE_PSIP				\
	0x762e3f66, 0x336f, 0x48d1, 0xbf, 0x83, 0x2b, 0x0, 0x35, 0x2c, 0x11, 0xf0
DEFINE_GUIDSTRUCT("762E3F66-336F-48d1-BF83-2B00352C11F0", KSDATAFORMAT_SUBTYPE_BDA_OPENCABLE_PSIP);
#define KSDATAFORMAT_SUBTYPE_BDA_OPENCABLE_PSIP DEFINE_GUIDNAMED(KSDATAFORMAT_SUBTYPE_BDA_OPENCABLE_PSIP)

#define STATIC_KSDATAFORMAT_SUBTYPE_BDA_OPENCABLE_OOB_PSIP			\
	0x951727db, 0xd2ce, 0x4528, 0x96, 0xf6, 0x33, 0x1, 0xfa, 0xbb, 0x2d, 0xe0
DEFINE_GUIDSTRUCT("951727DB-D2CE-4528-96F6-3301FABB2DE0", KSDATAFORMAT_SUBTYPE_BDA_OPENCABLE_OOB_PSIP);
#define KSDATAFORMAT_SUBTYPE_BDA_OPENCABLE_OOB_PSIP DEFINE_GUIDNAMED(KSDATAFORMAT_SUBTYPE_BDA_OPENCABLE_OOB_PSIP)

#define STATIC_KSDATAFORMAT_SUBTYPE_ISDB_SI					\
	0x4a2eeb99, 0x6458, 0x4538, 0xb1, 0x87, 0x04, 0x01, 0x7c, 0x41, 0x41, 0x3f
DEFINE_GUIDSTRUCT("4a2eeb99-6458-4538-b187-04017c41413f", KSDATAFORMAT_SUBTYPE_ISDB_SI);
#define KSDATAFORMAT_SUBTYPE_ISDB_SI DEFINE_GUIDNAMED(KSDATAFORMAT_SUBTYPE_ISDB_SI)

#define STATIC_KSDATAFORMAT_SUBTYPE_PBDA_TRANSPORT_RAW				\
	0x0d7aed42, 0xcb9a, 0x11db, 0x97, 0x05, 0x00, 0x50, 0x56, 0xc0, 0x00, 0x08
DEFINE_GUIDSTRUCT("0d7AED42-CB9A-11DB-9705-005056C00008", KSDATAFORMAT_SUBTYPE_PBDA_TRANSPORT_RAW);
#define KSDATAFORMAT_SUBTYPE_PBDA_TRANSPORT_RAW DEFINE_GUIDNAMED(KSDATAFORMAT_SUBTYPE_PBDA_TRANSPORT_RAW)

#endif /* _BDAMEDIA_ */

