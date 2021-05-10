// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");

pub const SOCKET = *opaque {};
pub const INVALID_SOCKET = @intToPtr(SOCKET, ~@as(usize, 0));

pub const GROUP = u32;
pub const ADDRESS_FAMILY = u16;
pub const WSAEVENT = HANDLE;

// Microsoft use the signed c_int for this, but it should never be negative
pub const socklen_t = u32;

pub const LM_HB_Extension = 128;
pub const LM_HB1_PnP = 1;
pub const LM_HB1_PDA_Palmtop = 2;
pub const LM_HB1_Computer = 4;
pub const LM_HB1_Printer = 8;
pub const LM_HB1_Modem = 16;
pub const LM_HB1_Fax = 32;
pub const LM_HB1_LANAccess = 64;
pub const LM_HB2_Telephony = 1;
pub const LM_HB2_FileServer = 2;
pub const ATMPROTO_AALUSER = 0;
pub const ATMPROTO_AAL1 = 1;
pub const ATMPROTO_AAL2 = 2;
pub const ATMPROTO_AAL34 = 3;
pub const ATMPROTO_AAL5 = 5;
pub const SAP_FIELD_ABSENT = 4294967294;
pub const SAP_FIELD_ANY = 4294967295;
pub const SAP_FIELD_ANY_AESA_SEL = 4294967290;
pub const SAP_FIELD_ANY_AESA_REST = 4294967291;
pub const ATM_E164 = 1;
pub const ATM_NSAP = 2;
pub const ATM_AESA = 2;
pub const ATM_ADDR_SIZE = 20;
pub const BLLI_L2_ISO_1745 = 1;
pub const BLLI_L2_Q921 = 2;
pub const BLLI_L2_X25L = 6;
pub const BLLI_L2_X25M = 7;
pub const BLLI_L2_ELAPB = 8;
pub const BLLI_L2_HDLC_ARM = 9;
pub const BLLI_L2_HDLC_NRM = 10;
pub const BLLI_L2_HDLC_ABM = 11;
pub const BLLI_L2_LLC = 12;
pub const BLLI_L2_X75 = 13;
pub const BLLI_L2_Q922 = 14;
pub const BLLI_L2_USER_SPECIFIED = 16;
pub const BLLI_L2_ISO_7776 = 17;
pub const BLLI_L3_X25 = 6;
pub const BLLI_L3_ISO_8208 = 7;
pub const BLLI_L3_X223 = 8;
pub const BLLI_L3_SIO_8473 = 9;
pub const BLLI_L3_T70 = 10;
pub const BLLI_L3_ISO_TR9577 = 11;
pub const BLLI_L3_USER_SPECIFIED = 16;
pub const BLLI_L3_IPI_SNAP = 128;
pub const BLLI_L3_IPI_IP = 204;
pub const BHLI_ISO = 0;
pub const BHLI_UserSpecific = 1;
pub const BHLI_HighLayerProfile = 2;
pub const BHLI_VendorSpecificAppId = 3;
pub const AAL5_MODE_MESSAGE = 1;
pub const AAL5_MODE_STREAMING = 2;
pub const AAL5_SSCS_NULL = 0;
pub const AAL5_SSCS_SSCOP_ASSURED = 1;
pub const AAL5_SSCS_SSCOP_NON_ASSURED = 2;
pub const AAL5_SSCS_FRAME_RELAY = 4;
pub const BCOB_A = 1;
pub const BCOB_C = 3;
pub const BCOB_X = 16;
pub const TT_NOIND = 0;
pub const TT_CBR = 4;
pub const TT_VBR = 8;
pub const TR_NOIND = 0;
pub const TR_END_TO_END = 1;
pub const TR_NO_END_TO_END = 2;
pub const CLIP_NOT = 0;
pub const CLIP_SUS = 32;
pub const UP_P2P = 0;
pub const UP_P2MP = 1;
pub const BLLI_L2_MODE_NORMAL = 64;
pub const BLLI_L2_MODE_EXT = 128;
pub const BLLI_L3_MODE_NORMAL = 64;
pub const BLLI_L3_MODE_EXT = 128;
pub const BLLI_L3_PACKET_16 = 4;
pub const BLLI_L3_PACKET_32 = 5;
pub const BLLI_L3_PACKET_64 = 6;
pub const BLLI_L3_PACKET_128 = 7;
pub const BLLI_L3_PACKET_256 = 8;
pub const BLLI_L3_PACKET_512 = 9;
pub const BLLI_L3_PACKET_1024 = 10;
pub const BLLI_L3_PACKET_2048 = 11;
pub const BLLI_L3_PACKET_4096 = 12;
pub const PI_ALLOWED = 0;
pub const PI_RESTRICTED = 64;
pub const PI_NUMBER_NOT_AVAILABLE = 128;
pub const SI_USER_NOT_SCREENED = 0;
pub const SI_USER_PASSED = 1;
pub const SI_USER_FAILED = 2;
pub const SI_NETWORK = 3;
pub const CAUSE_LOC_USER = 0;
pub const CAUSE_LOC_PRIVATE_LOCAL = 1;
pub const CAUSE_LOC_PUBLIC_LOCAL = 2;
pub const CAUSE_LOC_TRANSIT_NETWORK = 3;
pub const CAUSE_LOC_PUBLIC_REMOTE = 4;
pub const CAUSE_LOC_PRIVATE_REMOTE = 5;
pub const CAUSE_LOC_INTERNATIONAL_NETWORK = 7;
pub const CAUSE_LOC_BEYOND_INTERWORKING = 10;
pub const CAUSE_UNALLOCATED_NUMBER = 1;
pub const CAUSE_NO_ROUTE_TO_TRANSIT_NETWORK = 2;
pub const CAUSE_NO_ROUTE_TO_DESTINATION = 3;
pub const CAUSE_VPI_VCI_UNACCEPTABLE = 10;
pub const CAUSE_NORMAL_CALL_CLEARING = 16;
pub const CAUSE_USER_BUSY = 17;
pub const CAUSE_NO_USER_RESPONDING = 18;
pub const CAUSE_CALL_REJECTED = 21;
pub const CAUSE_NUMBER_CHANGED = 22;
pub const CAUSE_USER_REJECTS_CLIR = 23;
pub const CAUSE_DESTINATION_OUT_OF_ORDER = 27;
pub const CAUSE_INVALID_NUMBER_FORMAT = 28;
pub const CAUSE_STATUS_ENQUIRY_RESPONSE = 30;
pub const CAUSE_NORMAL_UNSPECIFIED = 31;
pub const CAUSE_VPI_VCI_UNAVAILABLE = 35;
pub const CAUSE_NETWORK_OUT_OF_ORDER = 38;
pub const CAUSE_TEMPORARY_FAILURE = 41;
pub const CAUSE_ACCESS_INFORMAION_DISCARDED = 43;
pub const CAUSE_NO_VPI_VCI_AVAILABLE = 45;
pub const CAUSE_RESOURCE_UNAVAILABLE = 47;
pub const CAUSE_QOS_UNAVAILABLE = 49;
pub const CAUSE_USER_CELL_RATE_UNAVAILABLE = 51;
pub const CAUSE_BEARER_CAPABILITY_UNAUTHORIZED = 57;
pub const CAUSE_BEARER_CAPABILITY_UNAVAILABLE = 58;
pub const CAUSE_OPTION_UNAVAILABLE = 63;
pub const CAUSE_BEARER_CAPABILITY_UNIMPLEMENTED = 65;
pub const CAUSE_UNSUPPORTED_TRAFFIC_PARAMETERS = 73;
pub const CAUSE_INVALID_CALL_REFERENCE = 81;
pub const CAUSE_CHANNEL_NONEXISTENT = 82;
pub const CAUSE_INCOMPATIBLE_DESTINATION = 88;
pub const CAUSE_INVALID_ENDPOINT_REFERENCE = 89;
pub const CAUSE_INVALID_TRANSIT_NETWORK_SELECTION = 91;
pub const CAUSE_TOO_MANY_PENDING_ADD_PARTY = 92;
pub const CAUSE_AAL_PARAMETERS_UNSUPPORTED = 93;
pub const CAUSE_MANDATORY_IE_MISSING = 96;
pub const CAUSE_UNIMPLEMENTED_MESSAGE_TYPE = 97;
pub const CAUSE_UNIMPLEMENTED_IE = 99;
pub const CAUSE_INVALID_IE_CONTENTS = 100;
pub const CAUSE_INVALID_STATE_FOR_MESSAGE = 101;
pub const CAUSE_RECOVERY_ON_TIMEOUT = 102;
pub const CAUSE_INCORRECT_MESSAGE_LENGTH = 104;
pub const CAUSE_PROTOCOL_ERROR = 111;
pub const CAUSE_COND_UNKNOWN = 0;
pub const CAUSE_COND_PERMANENT = 1;
pub const CAUSE_COND_TRANSIENT = 2;
pub const CAUSE_REASON_USER = 0;
pub const CAUSE_REASON_IE_MISSING = 4;
pub const CAUSE_REASON_IE_INSUFFICIENT = 8;
pub const CAUSE_PU_PROVIDER = 0;
pub const CAUSE_PU_USER = 8;
pub const CAUSE_NA_NORMAL = 0;
pub const CAUSE_NA_ABNORMAL = 4;
pub const QOS_CLASS0 = 0;
pub const QOS_CLASS1 = 1;
pub const QOS_CLASS2 = 2;
pub const QOS_CLASS3 = 3;
pub const QOS_CLASS4 = 4;
pub const TNS_TYPE_NATIONAL = 64;
pub const TNS_PLAN_CARRIER_ID_CODE = 1;
pub const SIO_GET_NUMBER_OF_ATM_DEVICES = 1343619073;
pub const SIO_GET_ATM_ADDRESS = 3491102722;
pub const SIO_ASSOCIATE_PVC = 2417360899;
pub const SIO_GET_ATM_CONNECTION_ID = 1343619076;
pub const RIO_MSG_DONT_NOTIFY = 1;
pub const RIO_MSG_DEFER = 2;
pub const RIO_MSG_WAITALL = 4;
pub const RIO_MSG_COMMIT_ONLY = 8;
pub const RIO_MAX_CQ_SIZE = 134217728;
pub const RIO_CORRUPT_CQ = 4294967295;
pub const WINDOWS_AF_IRDA = 26;
pub const WCE_AF_IRDA = 22;
pub const IRDA_PROTO_SOCK_STREAM = 1;
pub const SOL_IRLMP = 255;
pub const IRLMP_ENUMDEVICES = 16;
pub const IRLMP_IAS_SET = 17;
pub const IRLMP_IAS_QUERY = 18;
pub const IRLMP_SEND_PDU_LEN = 19;
pub const IRLMP_EXCLUSIVE_MODE = 20;
pub const IRLMP_IRLPT_MODE = 21;
pub const IRLMP_9WIRE_MODE = 22;
pub const IRLMP_TINYTP_MODE = 23;
pub const IRLMP_PARAMETERS = 24;
pub const IRLMP_DISCOVERY_MODE = 25;
pub const IRLMP_SHARP_MODE = 32;
pub const IAS_ATTRIB_NO_CLASS = 16;
pub const IAS_ATTRIB_NO_ATTRIB = 0;
pub const IAS_ATTRIB_INT = 1;
pub const IAS_ATTRIB_OCTETSEQ = 2;
pub const IAS_ATTRIB_STR = 3;
pub const IAS_MAX_USER_STRING = 256;
pub const IAS_MAX_OCTET_STRING = 1024;
pub const IAS_MAX_CLASSNAME = 64;
pub const IAS_MAX_ATTRIBNAME = 256;
pub const LmCharSetASCII = 0;
pub const LmCharSetISO_8859_1 = 1;
pub const LmCharSetISO_8859_2 = 2;
pub const LmCharSetISO_8859_3 = 3;
pub const LmCharSetISO_8859_4 = 4;
pub const LmCharSetISO_8859_5 = 5;
pub const LmCharSetISO_8859_6 = 6;
pub const LmCharSetISO_8859_7 = 7;
pub const LmCharSetISO_8859_8 = 8;
pub const LmCharSetISO_8859_9 = 9;
pub const LmCharSetUNICODE = 255;
pub const LM_BAUD_1200 = 1200;
pub const LM_BAUD_2400 = 2400;
pub const LM_BAUD_9600 = 9600;
pub const LM_BAUD_19200 = 19200;
pub const LM_BAUD_38400 = 38400;
pub const LM_BAUD_57600 = 57600;
pub const LM_BAUD_115200 = 115200;
pub const LM_BAUD_576K = 576000;
pub const LM_BAUD_1152K = 1152000;
pub const LM_BAUD_4M = 4000000;
pub const LM_BAUD_16M = 16000000;
pub const IPX_PTYPE = 16384;
pub const IPX_FILTERPTYPE = 16385;
pub const IPX_STOPFILTERPTYPE = 16387;
pub const IPX_DSTYPE = 16386;
pub const IPX_EXTENDED_ADDRESS = 16388;
pub const IPX_RECVHDR = 16389;
pub const IPX_MAXSIZE = 16390;
pub const IPX_ADDRESS = 16391;
pub const IPX_GETNETINFO = 16392;
pub const IPX_GETNETINFO_NORIP = 16393;
pub const IPX_SPXGETCONNECTIONSTATUS = 16395;
pub const IPX_ADDRESS_NOTIFY = 16396;
pub const IPX_MAX_ADAPTER_NUM = 16397;
pub const IPX_RERIPNETNUMBER = 16398;
pub const IPX_RECEIVE_BROADCAST = 16399;
pub const IPX_IMMEDIATESPXACK = 16400;
pub const IPPROTO_RM = 113;
pub const MAX_MCAST_TTL = 255;
pub const RM_OPTIONSBASE = 1000;
pub const RM_RATE_WINDOW_SIZE = 1001;
pub const RM_SET_MESSAGE_BOUNDARY = 1002;
pub const RM_FLUSHCACHE = 1003;
pub const RM_SENDER_WINDOW_ADVANCE_METHOD = 1004;
pub const RM_SENDER_STATISTICS = 1005;
pub const RM_LATEJOIN = 1006;
pub const RM_SET_SEND_IF = 1007;
pub const RM_ADD_RECEIVE_IF = 1008;
pub const RM_DEL_RECEIVE_IF = 1009;
pub const RM_SEND_WINDOW_ADV_RATE = 1010;
pub const RM_USE_FEC = 1011;
pub const RM_SET_MCAST_TTL = 1012;
pub const RM_RECEIVER_STATISTICS = 1013;
pub const RM_HIGH_SPEED_INTRANET_OPT = 1014;
pub const SENDER_DEFAULT_RATE_KBITS_PER_SEC = 56;
pub const SENDER_DEFAULT_WINDOW_ADV_PERCENTAGE = 15;
pub const MAX_WINDOW_INCREMENT_PERCENTAGE = 25;
pub const SENDER_DEFAULT_LATE_JOINER_PERCENTAGE = 0;
pub const SENDER_MAX_LATE_JOINER_PERCENTAGE = 75;
pub const BITS_PER_BYTE = 8;
pub const LOG2_BITS_PER_BYTE = 3;

pub const SOCKET_DEFAULT2_QM_POLICY = GUID.parse("{aec2ef9c-3a4d-4d3e-8842-239942e39a47}");
pub const REAL_TIME_NOTIFICATION_CAPABILITY = GUID.parse("{6b59819a-5cae-492d-a901-2a3c2c50164f}");
pub const REAL_TIME_NOTIFICATION_CAPABILITY_EX = GUID.parse("{6843da03-154a-4616-a508-44371295f96b}");
pub const ASSOCIATE_NAMERES_CONTEXT = GUID.parse("{59a38b67-d4fe-46e1-ba3c-87ea74ca3049}");

pub const WSAID_CONNECTEX = GUID{
    .Data1 = 0x25a207b9,
    .Data2 = 0xddf3,
    .Data3 = 0x4660,
    .Data4 = [8]u8{ 0x8e, 0xe9, 0x76, 0xe5, 0x8c, 0x74, 0x06, 0x3e },
};

pub const WSAID_ACCEPTEX = GUID{
    .Data1 = 0xb5367df1,
    .Data2 = 0xcbac,
    .Data3 = 0x11cf,
    .Data4 = [8]u8{ 0x95, 0xca, 0x00, 0x80, 0x5f, 0x48, 0xa1, 0x92 },
};

pub const WSAID_GETACCEPTEXSOCKADDRS = GUID{
    .Data1 = 0xb5367df2,
    .Data2 = 0xcbac,
    .Data3 = 0x11cf,
    .Data4 = [8]u8{ 0x95, 0xca, 0x00, 0x80, 0x5f, 0x48, 0xa1, 0x92 },
};

pub const WSAID_WSARECVMSG = GUID{
    .Data1 = 0xf689d7c8,
    .Data2 = 0x6f1f,
    .Data3 = 0x436b,
    .Data4 = [8]u8{ 0x8a, 0x53, 0xe5, 0x4f, 0xe3, 0x51, 0xc3, 0x22 },
};

pub const WSAID_WSAPOLL = GUID{
    .Data1 = 0x18C76F85,
    .Data2 = 0xDC66,
    .Data3 = 0x4964,
    .Data4 = [8]u8{ 0x97, 0x2E, 0x23, 0xC2, 0x72, 0x38, 0x31, 0x2B },
};

pub const WSAID_WSASENDMSG = GUID{
    .Data1 = 0xa441e712,
    .Data2 = 0x754f,
    .Data3 = 0x43ca,
    .Data4 = [8]u8{ 0x84, 0xa7, 0x0d, 0xee, 0x44, 0xcf, 0x60, 0x6d },
};

pub const TCP_INITIAL_RTO_DEFAULT_RTT = 0;
pub const TCP_INITIAL_RTO_DEFAULT_MAX_SYN_RETRANSMISSIONS = 0;
pub const SOCKET_SETTINGS_GUARANTEE_ENCRYPTION = 1;
pub const SOCKET_SETTINGS_ALLOW_INSECURE = 2;
pub const SOCKET_SETTINGS_IPSEC_SKIP_FILTER_INSTANTIATION = 1;
pub const SOCKET_SETTINGS_IPSEC_OPTIONAL_PEER_NAME_VERIFICATION = 2;
pub const SOCKET_SETTINGS_IPSEC_ALLOW_FIRST_INBOUND_PKT_UNENCRYPTED = 4;
pub const SOCKET_SETTINGS_IPSEC_PEER_NAME_IS_RAW_FORMAT = 8;
pub const SOCKET_QUERY_IPSEC2_ABORT_CONNECTION_ON_FIELD_CHANGE = 1;
pub const SOCKET_QUERY_IPSEC2_FIELD_MASK_MM_SA_ID = 1;
pub const SOCKET_QUERY_IPSEC2_FIELD_MASK_QM_SA_ID = 2;
pub const SOCKET_INFO_CONNECTION_SECURED = 1;
pub const SOCKET_INFO_CONNECTION_ENCRYPTED = 2;
pub const SOCKET_INFO_CONNECTION_IMPERSONATED = 4;
pub const IN4ADDR_LOOPBACK = 16777343;
pub const IN4ADDR_LOOPBACKPREFIX_LENGTH = 8;
pub const IN4ADDR_LINKLOCALPREFIX_LENGTH = 16;
pub const IN4ADDR_MULTICASTPREFIX_LENGTH = 4;
pub const IFF_UP = 1;
pub const IFF_BROADCAST = 2;
pub const IFF_LOOPBACK = 4;
pub const IFF_POINTTOPOINT = 8;
pub const IFF_MULTICAST = 16;
pub const IP_OPTIONS = 1;
pub const IP_HDRINCL = 2;
pub const IP_TOS = 3;
pub const IP_TTL = 4;
pub const IP_MULTICAST_IF = 9;
pub const IP_MULTICAST_TTL = 10;
pub const IP_MULTICAST_LOOP = 11;
pub const IP_ADD_MEMBERSHIP = 12;
pub const IP_DROP_MEMBERSHIP = 13;
pub const IP_DONTFRAGMENT = 14;
pub const IP_ADD_SOURCE_MEMBERSHIP = 15;
pub const IP_DROP_SOURCE_MEMBERSHIP = 16;
pub const IP_BLOCK_SOURCE = 17;
pub const IP_UNBLOCK_SOURCE = 18;
pub const IP_PKTINFO = 19;
pub const IP_HOPLIMIT = 21;
pub const IP_RECVTTL = 21;
pub const IP_RECEIVE_BROADCAST = 22;
pub const IP_RECVIF = 24;
pub const IP_RECVDSTADDR = 25;
pub const IP_IFLIST = 28;
pub const IP_ADD_IFLIST = 29;
pub const IP_DEL_IFLIST = 30;
pub const IP_UNICAST_IF = 31;
pub const IP_RTHDR = 32;
pub const IP_GET_IFLIST = 33;
pub const IP_RECVRTHDR = 38;
pub const IP_TCLASS = 39;
pub const IP_RECVTCLASS = 40;
pub const IP_RECVTOS = 40;
pub const IP_ORIGINAL_ARRIVAL_IF = 47;
pub const IP_ECN = 50;
pub const IP_PKTINFO_EX = 51;
pub const IP_WFP_REDIRECT_RECORDS = 60;
pub const IP_WFP_REDIRECT_CONTEXT = 70;
pub const IP_MTU_DISCOVER = 71;
pub const IP_MTU = 73;
pub const IP_NRT_INTERFACE = 74;
pub const IP_RECVERR = 75;
pub const IP_USER_MTU = 76;
pub const IP_UNSPECIFIED_TYPE_OF_SERVICE = -1;
pub const IN6ADDR_LINKLOCALPREFIX_LENGTH = 64;
pub const IN6ADDR_MULTICASTPREFIX_LENGTH = 8;
pub const IN6ADDR_SOLICITEDNODEMULTICASTPREFIX_LENGTH = 104;
pub const IN6ADDR_V4MAPPEDPREFIX_LENGTH = 96;
pub const IN6ADDR_6TO4PREFIX_LENGTH = 16;
pub const IN6ADDR_TEREDOPREFIX_LENGTH = 32;
pub const MCAST_JOIN_GROUP = 41;
pub const MCAST_LEAVE_GROUP = 42;
pub const MCAST_BLOCK_SOURCE = 43;
pub const MCAST_UNBLOCK_SOURCE = 44;
pub const MCAST_JOIN_SOURCE_GROUP = 45;
pub const MCAST_LEAVE_SOURCE_GROUP = 46;
pub const IPV6_HOPOPTS = 1;
pub const IPV6_HDRINCL = 2;
pub const IPV6_UNICAST_HOPS = 4;
pub const IPV6_MULTICAST_IF = 9;
pub const IPV6_MULTICAST_HOPS = 10;
pub const IPV6_MULTICAST_LOOP = 11;
pub const IPV6_ADD_MEMBERSHIP = 12;
pub const IPV6_DROP_MEMBERSHIP = 13;
pub const IPV6_DONTFRAG = 14;
pub const IPV6_PKTINFO = 19;
pub const IPV6_HOPLIMIT = 21;
pub const IPV6_PROTECTION_LEVEL = 23;
pub const IPV6_RECVIF = 24;
pub const IPV6_RECVDSTADDR = 25;
pub const IPV6_CHECKSUM = 26;
pub const IPV6_V6ONLY = 27;
pub const IPV6_IFLIST = 28;
pub const IPV6_ADD_IFLIST = 29;
pub const IPV6_DEL_IFLIST = 30;
pub const IPV6_UNICAST_IF = 31;
pub const IPV6_RTHDR = 32;
pub const IPV6_GET_IFLIST = 33;
pub const IPV6_RECVRTHDR = 38;
pub const IPV6_TCLASS = 39;
pub const IPV6_RECVTCLASS = 40;
pub const IPV6_ECN = 50;
pub const IPV6_PKTINFO_EX = 51;
pub const IPV6_WFP_REDIRECT_RECORDS = 60;
pub const IPV6_WFP_REDIRECT_CONTEXT = 70;
pub const IPV6_MTU_DISCOVER = 71;
pub const IPV6_MTU = 72;
pub const IPV6_NRT_INTERFACE = 74;
pub const IPV6_RECVERR = 75;
pub const IPV6_USER_MTU = 76;
pub const IP_UNSPECIFIED_HOP_LIMIT = -1;
pub const PROTECTION_LEVEL_UNRESTRICTED = 10;
pub const PROTECTION_LEVEL_EDGERESTRICTED = 20;
pub const PROTECTION_LEVEL_RESTRICTED = 30;
pub const INET_ADDRSTRLEN = 22;
pub const INET6_ADDRSTRLEN = 65;
pub const TCP_OFFLOAD_NO_PREFERENCE = 0;
pub const TCP_OFFLOAD_NOT_PREFERRED = 1;
pub const TCP_OFFLOAD_PREFERRED = 2;
pub const TCP_EXPEDITED_1122 = 2;
pub const TCP_KEEPALIVE = 3;
pub const TCP_MAXSEG = 4;
pub const TCP_MAXRT = 5;
pub const TCP_STDURG = 6;
pub const TCP_NOURG = 7;
pub const TCP_ATMARK = 8;
pub const TCP_NOSYNRETRIES = 9;
pub const TCP_TIMESTAMPS = 10;
pub const TCP_OFFLOAD_PREFERENCE = 11;
pub const TCP_CONGESTION_ALGORITHM = 12;
pub const TCP_DELAY_FIN_ACK = 13;
pub const TCP_MAXRTMS = 14;
pub const TCP_FASTOPEN = 15;
pub const TCP_KEEPCNT = 16;
pub const TCP_KEEPINTVL = 17;
pub const TCP_FAIL_CONNECT_ON_ICMP_ERROR = 18;
pub const TCP_ICMP_ERROR_INFO = 19;
pub const UDP_SEND_MSG_SIZE = 2;
pub const UDP_RECV_MAX_COALESCED_SIZE = 3;
pub const UDP_COALESCED_INFO = 3;
pub const AF_UNSPEC = 0;
pub const AF_UNIX = 1;
pub const AF_INET = 2;
pub const AF_IMPLINK = 3;
pub const AF_PUP = 4;
pub const AF_CHAOS = 5;
pub const AF_NS = 6;
pub const AF_ISO = 7;
pub const AF_ECMA = 8;
pub const AF_DATAKIT = 9;
pub const AF_CCITT = 10;
pub const AF_SNA = 11;
pub const AF_DECnet = 12;
pub const AF_DLI = 13;
pub const AF_LAT = 14;
pub const AF_HYLINK = 15;
pub const AF_APPLETALK = 16;
pub const AF_NETBIOS = 17;
pub const AF_VOICEVIEW = 18;
pub const AF_FIREFOX = 19;
pub const AF_UNKNOWN1 = 20;
pub const AF_BAN = 21;
pub const AF_ATM = 22;
pub const AF_INET6 = 23;
pub const AF_CLUSTER = 24;
pub const AF_12844 = 25;
pub const AF_IRDA = 26;
pub const AF_NETDES = 28;
pub const AF_MAX = 29;
pub const AF_TCNPROCESS = 29;
pub const AF_TCNMESSAGE = 30;
pub const AF_ICLFXBM = 31;
pub const AF_LINK = 33;
pub const AF_HYPERV = 34;
pub const SOCK_STREAM = 1;
pub const SOCK_DGRAM = 2;
pub const SOCK_RAW = 3;
pub const SOCK_RDM = 4;
pub const SOCK_SEQPACKET = 5;
pub const SOL_SOCKET = 65535;
pub const SO_DEBUG = 1;
pub const SO_ACCEPTCONN = 2;
pub const SO_REUSEADDR = 4;
pub const SO_KEEPALIVE = 8;
pub const SO_DONTROUTE = 16;
pub const SO_BROADCAST = 32;
pub const SO_USELOOPBACK = 64;
pub const SO_LINGER = 128;
pub const SO_OOBINLINE = 256;
pub const SO_SNDBUF = 4097;
pub const SO_RCVBUF = 4098;
pub const SO_SNDLOWAT = 4099;
pub const SO_RCVLOWAT = 4100;
pub const SO_SNDTIMEO = 4101;
pub const SO_RCVTIMEO = 4102;
pub const SO_ERROR = 4103;
pub const SO_TYPE = 4104;
pub const SO_BSP_STATE = 4105;
pub const SO_GROUP_ID = 8193;
pub const SO_GROUP_PRIORITY = 8194;
pub const SO_MAX_MSG_SIZE = 8195;
pub const SO_CONDITIONAL_ACCEPT = 12290;
pub const SO_PAUSE_ACCEPT = 12291;
pub const SO_COMPARTMENT_ID = 12292;
pub const SO_RANDOMIZE_PORT = 12293;
pub const SO_PORT_SCALABILITY = 12294;
pub const SO_REUSE_UNICASTPORT = 12295;
pub const SO_REUSE_MULTICASTPORT = 12296;
pub const SO_ORIGINAL_DST = 12303;
pub const WSK_SO_BASE = 16384;
pub const TCP_NODELAY = 1;
pub const IOC_UNIX = 0;
pub const IOC_WS2 = 134217728;
pub const IOC_PROTOCOL = 268435456;
pub const IOC_VENDOR = 402653184;
pub const SIO_GET_EXTENSION_FUNCTION_POINTER = IOC_OUT | IOC_IN | IOC_WS2 | 6;
pub const SIO_BSP_HANDLE = IOC_OUT | IOC_WS2 | 27;
pub const SIO_BSP_HANDLE_SELECT = IOC_OUT | IOC_WS2 | 28;
pub const SIO_BSP_HANDLE_POLL = IOC_OUT | IOC_WS2 | 29;
pub const SIO_BASE_HANDLE = IOC_OUT | IOC_WS2 | 34;
pub const IPPROTO_IP = 0;
pub const IPPORT_TCPMUX = 1;
pub const IPPORT_ECHO = 7;
pub const IPPORT_DISCARD = 9;
pub const IPPORT_SYSTAT = 11;
pub const IPPORT_DAYTIME = 13;
pub const IPPORT_NETSTAT = 15;
pub const IPPORT_QOTD = 17;
pub const IPPORT_MSP = 18;
pub const IPPORT_CHARGEN = 19;
pub const IPPORT_FTP_DATA = 20;
pub const IPPORT_FTP = 21;
pub const IPPORT_TELNET = 23;
pub const IPPORT_SMTP = 25;
pub const IPPORT_TIMESERVER = 37;
pub const IPPORT_NAMESERVER = 42;
pub const IPPORT_WHOIS = 43;
pub const IPPORT_MTP = 57;
pub const IPPORT_TFTP = 69;
pub const IPPORT_RJE = 77;
pub const IPPORT_FINGER = 79;
pub const IPPORT_TTYLINK = 87;
pub const IPPORT_SUPDUP = 95;
pub const IPPORT_POP3 = 110;
pub const IPPORT_NTP = 123;
pub const IPPORT_EPMAP = 135;
pub const IPPORT_NETBIOS_NS = 137;
pub const IPPORT_NETBIOS_DGM = 138;
pub const IPPORT_NETBIOS_SSN = 139;
pub const IPPORT_IMAP = 143;
pub const IPPORT_SNMP = 161;
pub const IPPORT_SNMP_TRAP = 162;
pub const IPPORT_IMAP3 = 220;
pub const IPPORT_LDAP = 389;
pub const IPPORT_HTTPS = 443;
pub const IPPORT_MICROSOFT_DS = 445;
pub const IPPORT_EXECSERVER = 512;
pub const IPPORT_LOGINSERVER = 513;
pub const IPPORT_CMDSERVER = 514;
pub const IPPORT_EFSSERVER = 520;
pub const IPPORT_BIFFUDP = 512;
pub const IPPORT_WHOSERVER = 513;
pub const IPPORT_ROUTESERVER = 520;
pub const IPPORT_RESERVED = 1024;
pub const IPPORT_REGISTERED_MAX = 49151;
pub const IPPORT_DYNAMIC_MIN = 49152;
pub const IPPORT_DYNAMIC_MAX = 65535;
pub const IN_CLASSA_NET = 4278190080;
pub const IN_CLASSA_NSHIFT = 24;
pub const IN_CLASSA_HOST = 16777215;
pub const IN_CLASSA_MAX = 128;
pub const IN_CLASSB_NET = 4294901760;
pub const IN_CLASSB_NSHIFT = 16;
pub const IN_CLASSB_HOST = 65535;
pub const IN_CLASSB_MAX = 65536;
pub const IN_CLASSC_NET = 4294967040;
pub const IN_CLASSC_NSHIFT = 8;
pub const IN_CLASSC_HOST = 255;
pub const IN_CLASSD_NET = 4026531840;
pub const IN_CLASSD_NSHIFT = 28;
pub const IN_CLASSD_HOST = 268435455;
pub const INADDR_LOOPBACK = 2130706433;
pub const INADDR_NONE = 4294967295;
pub const IOCPARM_MASK = 127;
pub const IOC_VOID = 536870912;
pub const IOC_OUT = 1073741824;
pub const IOC_IN = 2147483648;
pub const MSG_TRUNC = 256;
pub const MSG_CTRUNC = 512;
pub const MSG_BCAST = 1024;
pub const MSG_MCAST = 2048;
pub const MSG_ERRQUEUE = 4096;
pub const AI_PASSIVE = 1;
pub const AI_CANONNAME = 2;
pub const AI_NUMERICHOST = 4;
pub const AI_NUMERICSERV = 8;
pub const AI_DNS_ONLY = 16;
pub const AI_ALL = 256;
pub const AI_ADDRCONFIG = 1024;
pub const AI_V4MAPPED = 2048;
pub const AI_NON_AUTHORITATIVE = 16384;
pub const AI_SECURE = 32768;
pub const AI_RETURN_PREFERRED_NAMES = 65536;
pub const AI_FQDN = 131072;
pub const AI_FILESERVER = 262144;
pub const AI_DISABLE_IDN_ENCODING = 524288;
pub const AI_EXTENDED = 2147483648;
pub const AI_RESOLUTION_HANDLE = 1073741824;
pub const FIONBIO = -2147195266;
pub const ADDRINFOEX_VERSION_2 = 2;
pub const ADDRINFOEX_VERSION_3 = 3;
pub const ADDRINFOEX_VERSION_4 = 4;
pub const NS_ALL = 0;
pub const NS_SAP = 1;
pub const NS_NDS = 2;
pub const NS_PEER_BROWSE = 3;
pub const NS_SLP = 5;
pub const NS_DHCP = 6;
pub const NS_TCPIP_LOCAL = 10;
pub const NS_TCPIP_HOSTS = 11;
pub const NS_DNS = 12;
pub const NS_NETBT = 13;
pub const NS_WINS = 14;
pub const NS_NLA = 15;
pub const NS_NBP = 20;
pub const NS_MS = 30;
pub const NS_STDA = 31;
pub const NS_NTDS = 32;
pub const NS_EMAIL = 37;
pub const NS_X500 = 40;
pub const NS_NIS = 41;
pub const NS_NISPLUS = 42;
pub const NS_WRQ = 50;
pub const NS_NETDES = 60;
pub const NI_NOFQDN = 1;
pub const NI_NUMERICHOST = 2;
pub const NI_NAMEREQD = 4;
pub const NI_NUMERICSERV = 8;
pub const NI_DGRAM = 16;
pub const NI_MAXHOST = 1025;
pub const NI_MAXSERV = 32;
pub const INCL_WINSOCK_API_PROTOTYPES = 1;
pub const INCL_WINSOCK_API_TYPEDEFS = 0;
pub const FD_SETSIZE = 64;
pub const IMPLINK_IP = 155;
pub const IMPLINK_LOWEXPER = 156;
pub const IMPLINK_HIGHEXPER = 158;
pub const WSADESCRIPTION_LEN = 256;
pub const WSASYS_STATUS_LEN = 128;
pub const SOCKET_ERROR = -1;
pub const FROM_PROTOCOL_INFO = -1;
pub const SO_PROTOCOL_INFOA = 8196;
pub const SO_PROTOCOL_INFOW = 8197;
pub const PVD_CONFIG = 12289;
pub const SOMAXCONN = 2147483647;
pub const MSG_PEEK = 2;
pub const MSG_WAITALL = 8;
pub const MSG_PUSH_IMMEDIATE = 32;
pub const MSG_PARTIAL = 32768;
pub const MSG_INTERRUPT = 16;
pub const MSG_MAXIOVLEN = 16;
pub const MAXGETHOSTSTRUCT = 1024;
pub const FD_READ_BIT = 0;
pub const FD_WRITE_BIT = 1;
pub const FD_OOB_BIT = 2;
pub const FD_ACCEPT_BIT = 3;
pub const FD_CONNECT_BIT = 4;
pub const FD_CLOSE_BIT = 5;
pub const FD_QOS_BIT = 6;
pub const FD_GROUP_QOS_BIT = 7;
pub const FD_ROUTING_INTERFACE_CHANGE_BIT = 8;
pub const FD_ADDRESS_LIST_CHANGE_BIT = 9;
pub const FD_MAX_EVENTS = 10;
pub const CF_ACCEPT = 0;
pub const CF_REJECT = 1;
pub const CF_DEFER = 2;
pub const SD_RECEIVE = 0;
pub const SD_SEND = 1;
pub const SD_BOTH = 2;
pub const SG_UNCONSTRAINED_GROUP = 1;
pub const SG_CONSTRAINED_GROUP = 2;
pub const MAX_PROTOCOL_CHAIN = 7;
pub const BASE_PROTOCOL = 1;
pub const LAYERED_PROTOCOL = 0;
pub const WSAPROTOCOL_LEN = 255;
pub const PFL_MULTIPLE_PROTO_ENTRIES = 1;
pub const PFL_RECOMMENDED_PROTO_ENTRY = 2;
pub const PFL_HIDDEN = 4;
pub const PFL_MATCHES_PROTOCOL_ZERO = 8;
pub const PFL_NETWORKDIRECT_PROVIDER = 16;
pub const XP1_CONNECTIONLESS = 1;
pub const XP1_GUARANTEED_DELIVERY = 2;
pub const XP1_GUARANTEED_ORDER = 4;
pub const XP1_MESSAGE_ORIENTED = 8;
pub const XP1_PSEUDO_STREAM = 16;
pub const XP1_GRACEFUL_CLOSE = 32;
pub const XP1_EXPEDITED_DATA = 64;
pub const XP1_CONNECT_DATA = 128;
pub const XP1_DISCONNECT_DATA = 256;
pub const XP1_SUPPORT_BROADCAST = 512;
pub const XP1_SUPPORT_MULTIPOINT = 1024;
pub const XP1_MULTIPOINT_CONTROL_PLANE = 2048;
pub const XP1_MULTIPOINT_DATA_PLANE = 4096;
pub const XP1_QOS_SUPPORTED = 8192;
pub const XP1_INTERRUPT = 16384;
pub const XP1_UNI_SEND = 32768;
pub const XP1_UNI_RECV = 65536;
pub const XP1_IFS_HANDLES = 131072;
pub const XP1_PARTIAL_MESSAGE = 262144;
pub const XP1_SAN_SUPPORT_SDP = 524288;
pub const BIGENDIAN = 0;
pub const LITTLEENDIAN = 1;
pub const SECURITY_PROTOCOL_NONE = 0;
pub const JL_SENDER_ONLY = 1;
pub const JL_RECEIVER_ONLY = 2;
pub const JL_BOTH = 4;
pub const WSA_FLAG_OVERLAPPED = 1;
pub const WSA_FLAG_MULTIPOINT_C_ROOT = 2;
pub const WSA_FLAG_MULTIPOINT_C_LEAF = 4;
pub const WSA_FLAG_MULTIPOINT_D_ROOT = 8;
pub const WSA_FLAG_MULTIPOINT_D_LEAF = 16;
pub const WSA_FLAG_ACCESS_SYSTEM_SECURITY = 64;
pub const WSA_FLAG_NO_HANDLE_INHERIT = 128;
pub const WSA_FLAG_REGISTERED_IO = 256;
pub const TH_NETDEV = 1;
pub const TH_TAPI = 2;
pub const SERVICE_MULTIPLE = 1;
pub const NS_LOCALNAME = 19;
pub const RES_UNUSED_1 = 1;
pub const RES_FLUSH_CACHE = 2;
pub const RES_SERVICE = 4;
pub const LUP_DEEP = 1;
pub const LUP_CONTAINERS = 2;
pub const LUP_NOCONTAINERS = 4;
pub const LUP_NEAREST = 8;
pub const LUP_RETURN_NAME = 16;
pub const LUP_RETURN_TYPE = 32;
pub const LUP_RETURN_VERSION = 64;
pub const LUP_RETURN_COMMENT = 128;
pub const LUP_RETURN_ADDR = 256;
pub const LUP_RETURN_BLOB = 512;
pub const LUP_RETURN_ALIASES = 1024;
pub const LUP_RETURN_QUERY_STRING = 2048;
pub const LUP_RETURN_ALL = 4080;
pub const LUP_RES_SERVICE = 32768;
pub const LUP_FLUSHCACHE = 4096;
pub const LUP_FLUSHPREVIOUS = 8192;
pub const LUP_NON_AUTHORITATIVE = 16384;
pub const LUP_SECURE = 32768;
pub const LUP_RETURN_PREFERRED_NAMES = 65536;
pub const LUP_DNS_ONLY = 131072;
pub const LUP_ADDRCONFIG = 1048576;
pub const LUP_DUAL_ADDR = 2097152;
pub const LUP_FILESERVER = 4194304;
pub const LUP_DISABLE_IDN_ENCODING = 8388608;
pub const LUP_API_ANSI = 16777216;
pub const LUP_RESOLUTION_HANDLE = 2147483648;
pub const RESULT_IS_ALIAS = 1;
pub const RESULT_IS_ADDED = 16;
pub const RESULT_IS_CHANGED = 32;
pub const RESULT_IS_DELETED = 64;
pub const POLLRDNORM = 256;
pub const POLLRDBAND = 512;
pub const POLLPRI = 1024;
pub const POLLWRNORM = 16;
pub const POLLWRBAND = 32;
pub const POLLERR = 1;
pub const POLLHUP = 2;
pub const POLLNVAL = 4;
pub const SO_CONNDATA = 28672;
pub const SO_CONNOPT = 28673;
pub const SO_DISCDATA = 28674;
pub const SO_DISCOPT = 28675;
pub const SO_CONNDATALEN = 28676;
pub const SO_CONNOPTLEN = 28677;
pub const SO_DISCDATALEN = 28678;
pub const SO_DISCOPTLEN = 28679;
pub const SO_OPENTYPE = 28680;
pub const SO_SYNCHRONOUS_ALERT = 16;
pub const SO_SYNCHRONOUS_NONALERT = 32;
pub const SO_MAXDG = 28681;
pub const SO_MAXPATHDG = 28682;
pub const SO_UPDATE_ACCEPT_CONTEXT = 28683;
pub const SO_CONNECT_TIME = 28684;
pub const SO_UPDATE_CONNECT_CONTEXT = 28688;
pub const TCP_BSDURGENT = 28672;
pub const TF_DISCONNECT = 1;
pub const TF_REUSE_SOCKET = 2;
pub const TF_WRITE_BEHIND = 4;
pub const TF_USE_DEFAULT_WORKER = 0;
pub const TF_USE_SYSTEM_THREAD = 16;
pub const TF_USE_KERNEL_APC = 32;
pub const TP_ELEMENT_MEMORY = 1;
pub const TP_ELEMENT_FILE = 2;
pub const TP_ELEMENT_EOP = 4;
pub const NLA_ALLUSERS_NETWORK = 1;
pub const NLA_FRIENDLY_NAME = 2;
pub const WSPDESCRIPTION_LEN = 255;
pub const WSS_OPERATION_IN_PROGRESS = 259;
pub const LSP_SYSTEM = 2147483648;
pub const LSP_INSPECTOR = 1;
pub const LSP_REDIRECTOR = 2;
pub const LSP_PROXY = 4;
pub const LSP_FIREWALL = 8;
pub const LSP_INBOUND_MODIFY = 16;
pub const LSP_OUTBOUND_MODIFY = 32;
pub const LSP_CRYPTO_COMPRESS = 64;
pub const LSP_LOCAL_CACHE = 128;
pub const IPPROTO_ICMP = 1;
pub const IPPROTO_IGMP = 2;
pub const IPPROTO_GGP = 3;
pub const IPPROTO_TCP = 6;
pub const IPPROTO_PUP = 12;
pub const IPPROTO_UDP = 17;
pub const IPPROTO_IDP = 22;
pub const IPPROTO_ND = 77;
pub const IPPROTO_RAW = 255;
pub const IPPROTO_MAX = 256;
pub const IP_DEFAULT_MULTICAST_TTL = 1;
pub const IP_DEFAULT_MULTICAST_LOOP = 1;
pub const IP_MAX_MEMBERSHIPS = 20;
pub const AF_IPX = 6;
pub const FD_READ = 1;
pub const FD_WRITE = 2;
pub const FD_OOB = 4;
pub const FD_ACCEPT = 8;
pub const FD_CONNECT = 16;
pub const FD_CLOSE = 32;
pub const SERVICE_RESOURCE = 1;
pub const SERVICE_SERVICE = 2;
pub const SERVICE_LOCAL = 4;
pub const SERVICE_FLAG_DEFER = 1;
pub const SERVICE_FLAG_HARD = 2;
pub const PROP_COMMENT = 1;
pub const PROP_LOCALE = 2;
pub const PROP_DISPLAY_HINT = 4;
pub const PROP_VERSION = 8;
pub const PROP_START_TIME = 16;
pub const PROP_MACHINE = 32;
pub const PROP_ADDRESSES = 256;
pub const PROP_SD = 512;
pub const PROP_ALL = 2147483648;
pub const SERVICE_ADDRESS_FLAG_RPC_CN = 1;
pub const SERVICE_ADDRESS_FLAG_RPC_DG = 2;
pub const SERVICE_ADDRESS_FLAG_RPC_NB = 4;
pub const NS_DEFAULT = 0;
pub const NS_VNS = 50;
pub const NSTYPE_HIERARCHICAL = 1;
pub const NSTYPE_DYNAMIC = 2;
pub const NSTYPE_ENUMERABLE = 4;
pub const NSTYPE_WORKGROUP = 8;
pub const XP_CONNECTIONLESS = 1;
pub const XP_GUARANTEED_DELIVERY = 2;
pub const XP_GUARANTEED_ORDER = 4;
pub const XP_MESSAGE_ORIENTED = 8;
pub const XP_PSEUDO_STREAM = 16;
pub const XP_GRACEFUL_CLOSE = 32;
pub const XP_EXPEDITED_DATA = 64;
pub const XP_CONNECT_DATA = 128;
pub const XP_DISCONNECT_DATA = 256;
pub const XP_SUPPORTS_BROADCAST = 512;
pub const XP_SUPPORTS_MULTICAST = 1024;
pub const XP_BANDWIDTH_ALLOCATION = 2048;
pub const XP_FRAGMENTATION = 4096;
pub const XP_ENCRYPTS = 8192;
pub const RES_SOFT_SEARCH = 1;
pub const RES_FIND_MULTIPLE = 2;
pub const SET_SERVICE_PARTIAL_SUCCESS = 1;
pub const UDP_NOCHECKSUM = 1;
pub const UDP_CHECKSUM_COVERAGE = 20;
pub const GAI_STRERROR_BUFFER_SIZE = 1024;

pub const LPCONDITIONPROC = fn (
    lpCallerId: *WSABUF,
    lpCallerData: *WSABUF,
    lpSQOS: *QOS,
    lpGQOS: *QOS,
    lpCalleeId: *WSABUF,
    lpCalleeData: *WSABUF,
    g: *u32,
    dwCallbackData: usize,
) callconv(WINAPI) i32;

pub const LPWSAOVERLAPPED_COMPLETION_ROUTINE = fn (
    dwError: u32,
    cbTransferred: u32,
    lpOverlapped: *OVERLAPPED,
    dwFlags: u32,
) callconv(WINAPI) void;

pub const FLOWSPEC = extern struct {
    TokenRate: u32,
    TokenBucketSize: u32,
    PeakBandwidth: u32,
    Latency: u32,
    DelayVariation: u32,
    ServiceType: u32,
    MaxSduSize: u32,
    MinimumPolicedSize: u32,
};

pub const QOS = extern struct {
    SendingFlowspec: FLOWSPEC,
    ReceivingFlowspec: FLOWSPEC,
    ProviderSpecific: WSABUF,
};

pub const SOCKET_ADDRESS = extern struct {
    lpSockaddr: *sockaddr,
    iSockaddrLength: i32,
};

pub const SOCKET_ADDRESS_LIST = extern struct {
    iAddressCount: i32,
    Address: [1]SOCKET_ADDRESS,
};

pub const WSADATA = if (@sizeOf(usize) == @sizeOf(u64))
    extern struct {
        wVersion: WORD,
        wHighVersion: WORD,
        iMaxSockets: u16,
        iMaxUdpDg: u16,
        lpVendorInfo: *u8,
        szDescription: [WSADESCRIPTION_LEN + 1]u8,
        szSystemStatus: [WSASYS_STATUS_LEN + 1]u8,
    }
else
    extern struct {
        wVersion: WORD,
        wHighVersion: WORD,
        szDescription: [WSADESCRIPTION_LEN + 1]u8,
        szSystemStatus: [WSASYS_STATUS_LEN + 1]u8,
        iMaxSockets: u16,
        iMaxUdpDg: u16,
        lpVendorInfo: *u8,
    };

pub const WSAPROTOCOLCHAIN = extern struct {
    ChainLen: c_int,
    ChainEntries: [MAX_PROTOCOL_CHAIN]DWORD,
};

pub const WSAPROTOCOL_INFOA = extern struct {
    dwServiceFlags1: DWORD,
    dwServiceFlags2: DWORD,
    dwServiceFlags3: DWORD,
    dwServiceFlags4: DWORD,
    dwProviderFlags: DWORD,
    ProviderId: GUID,
    dwCatalogEntryId: DWORD,
    ProtocolChain: WSAPROTOCOLCHAIN,
    iVersion: c_int,
    iAddressFamily: c_int,
    iMaxSockAddr: c_int,
    iMinSockAddr: c_int,
    iSocketType: c_int,
    iProtocol: c_int,
    iProtocolMaxOffset: c_int,
    iNetworkByteOrder: c_int,
    iSecurityScheme: c_int,
    dwMessageSize: DWORD,
    dwProviderReserved: DWORD,
    szProtocol: [WSAPROTOCOL_LEN + 1]CHAR,
};

pub const WSAPROTOCOL_INFOW = extern struct {
    dwServiceFlags1: DWORD,
    dwServiceFlags2: DWORD,
    dwServiceFlags3: DWORD,
    dwServiceFlags4: DWORD,
    dwProviderFlags: DWORD,
    ProviderId: GUID,
    dwCatalogEntryId: DWORD,
    ProtocolChain: WSAPROTOCOLCHAIN,
    iVersion: c_int,
    iAddressFamily: c_int,
    iMaxSockAddr: c_int,
    iMinSockAddr: c_int,
    iSocketType: c_int,
    iProtocol: c_int,
    iProtocolMaxOffset: c_int,
    iNetworkByteOrder: c_int,
    iSecurityScheme: c_int,
    dwMessageSize: DWORD,
    dwProviderReserved: DWORD,
    szProtocol: [WSAPROTOCOL_LEN + 1]WCHAR,
};

pub const sockproto = extern struct {
    sp_family: u16,
    sp_protocol: u16,
};

pub const linger = extern struct {
    l_onoff: u16,
    l_linger: u16,
};

pub const WSANETWORKEVENTS = extern struct {
    lNetworkEvents: i32,
    iErrorCode: [10]i32,
};

pub const WSAOVERLAPPED = extern struct {
    Internal: DWORD,
    InternalHigh: DWORD,
    Offset: DWORD,
    OffsetHigh: DWORD,
    hEvent: ?WSAEVENT,
};

pub const addrinfo = addrinfoa;

pub const addrinfoa = extern struct {
    flags: i32,
    family: i32,
    socktype: i32,
    protocol: i32,
    addrlen: usize,
    canonname: ?[*:0]u8,
    addr: ?*sockaddr,
    next: ?*addrinfo,
};

pub const addrinfoexA = extern struct {
    ai_flags: i32,
    ai_family: i32,
    ai_socktype: i32,
    ai_protocol: i32,
    ai_addrlen: usize,
    ai_canonname: [*:0]u8,
    ai_addr: *sockaddr,
    ai_blob: *c_void,
    ai_bloblen: usize,
    ai_provider: *GUID,
    ai_next: *addrinfoexA,
};

pub const sockaddr = extern struct {
    family: ADDRESS_FAMILY,
    data: [14]u8,
};

pub const sockaddr_storage = extern struct {
    family: ADDRESS_FAMILY,
    __pad1: [6]u8,
    __align: i64,
    __pad2: [112]u8,
};

/// IPv4 socket address
pub const sockaddr_in = extern struct {
    family: ADDRESS_FAMILY = AF_INET,
    port: USHORT,
    addr: u32,
    zero: [8]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
};

/// IPv6 socket address
pub const sockaddr_in6 = extern struct {
    family: ADDRESS_FAMILY = AF_INET6,
    port: USHORT,
    flowinfo: u32,
    addr: [16]u8,
    scope_id: u32,
};

/// UNIX domain socket address
pub const sockaddr_un = extern struct {
    family: ADDRESS_FAMILY = AF_UNIX,
    path: [108]u8,
};

pub const WSABUF = extern struct {
    len: ULONG,
    buf: [*]u8,
};

pub const msghdr = WSAMSG;
pub const msghdr_const = WSAMSG_const;

pub const WSAMSG_const = extern struct {
    name: *const sockaddr,
    namelen: INT,
    lpBuffers: [*]WSABUF,
    dwBufferCount: DWORD,
    Control: WSABUF,
    dwFlags: DWORD,
};

pub const WSAMSG = extern struct {
    name: *sockaddr,
    namelen: INT,
    lpBuffers: [*]WSABUF,
    dwBufferCount: DWORD,
    Control: WSABUF,
    dwFlags: DWORD,
};

pub const WSAPOLLFD = pollfd;

pub const pollfd = extern struct {
    fd: SOCKET,
    events: SHORT,
    revents: SHORT,
};

pub const TRANSMIT_FILE_BUFFERS = extern struct {
    Head: *c_void,
    HeadLength: u32,
    Tail: *c_void,
    TailLength: u32,
};

pub const LPFN_TRANSMITFILE = fn (
    hSocket: SOCKET,
    hFile: HANDLE,
    nNumberOfBytesToWrite: u32,
    nNumberOfBytesPerSend: u32,
    lpOverlapped: ?*OVERLAPPED,
    lpTransmitBuffers: ?*TRANSMIT_FILE_BUFFERS,
    dwReserved: u32,
) callconv(WINAPI) BOOL;

pub const LPFN_ACCEPTEX = fn (
    sListenSocket: SOCKET,
    sAcceptSocket: SOCKET,
    lpOutputBuffer: *c_void,
    dwReceiveDataLength: u32,
    dwLocalAddressLength: u32,
    dwRemoteAddressLength: u32,
    lpdwBytesReceived: *u32,
    lpOverlapped: *OVERLAPPED,
) callconv(WINAPI) BOOL;

pub const LPFN_GETACCEPTEXSOCKADDRS = fn (
    lpOutputBuffer: *c_void,
    dwReceiveDataLength: u32,
    dwLocalAddressLength: u32,
    dwRemoteAddressLength: u32,
    LocalSockaddr: **sockaddr,
    LocalSockaddrLength: *i32,
    RemoteSockaddr: **sockaddr,
    RemoteSockaddrLength: *i32,
) callconv(WINAPI) void;

pub const LPFN_WSASENDMSG = fn (
    s: SOCKET,
    lpMsg: *const WSAMSG_const,
    dwFlags: u32,
    lpNumberOfBytesSent: ?*u32,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub const LPFN_WSARECVMSG = fn (
    s: SOCKET,
    lpMsg: *WSAMSG,
    lpdwNumberOfBytesRecv: ?*u32,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub const LPSERVICE_CALLBACK_PROC = fn (
    lParam: LPARAM,
    hAsyncTaskHandle: HANDLE,
) callconv(WINAPI) void;

pub const SERVICE_ASYNC_INFO = extern struct {
    lpServiceCallbackProc: LPSERVICE_CALLBACK_PROC,
    lParam: LPARAM,
    hAsyncTaskHandle: HANDLE,
};

pub const LPLOOKUPSERVICE_COMPLETION_ROUTINE = fn (
    dwError: u32,
    dwBytes: u32,
    lpOverlapped: *OVERLAPPED,
) callconv(WINAPI) void;

pub const fd_set = extern struct {
    fd_count: u32,
    fd_array: [64]SOCKET,
};

pub const hostent = extern struct {
    h_name: [*]u8,
    h_aliases: **i8,
    h_addrtype: i16,
    h_length: i16,
    h_addr_list: **i8,
};

// https://docs.microsoft.com/en-au/windows/win32/winsock/windows-sockets-error-codes-2
pub const WinsockError = extern enum(u16) {
    /// Specified event object handle is invalid.
    /// An application attempts to use an event object, but the specified handle is not valid.
    WSA_INVALID_HANDLE = 6,

    /// Insufficient memory available.
    /// An application used a Windows Sockets function that directly maps to a Windows function.
    /// The Windows function is indicating a lack of required memory resources.
    WSA_NOT_ENOUGH_MEMORY = 8,

    /// One or more parameters are invalid.
    /// An application used a Windows Sockets function which directly maps to a Windows function.
    /// The Windows function is indicating a problem with one or more parameters.
    WSA_INVALID_PARAMETER = 87,

    /// Overlapped operation aborted.
    /// An overlapped operation was canceled due to the closure of the socket, or the execution of the SIO_FLUSH command in WSAIoctl.
    WSA_OPERATION_ABORTED = 995,

    /// Overlapped I/O event object not in signaled state.
    /// The application has tried to determine the status of an overlapped operation which is not yet completed.
    /// Applications that use WSAGetOverlappedResult (with the fWait flag set to FALSE) in a polling mode to determine when an overlapped operation has completed, get this error code until the operation is complete.
    WSA_IO_INCOMPLETE = 996,

    /// The application has initiated an overlapped operation that cannot be completed immediately.
    /// A completion indication will be given later when the operation has been completed.
    WSA_IO_PENDING = 997,

    /// Interrupted function call.
    /// A blocking operation was interrupted by a call to WSACancelBlockingCall.
    WSAEINTR = 10004,

    /// File handle is not valid.
    /// The file handle supplied is not valid.
    WSAEBADF = 10009,

    /// Permission denied.
    /// An attempt was made to access a socket in a way forbidden by its access permissions.
    /// An example is using a broadcast address for sendto without broadcast permission being set using setsockopt(SO_BROADCAST).
    /// Another possible reason for the WSAEACCES error is that when the bind function is called (on Windows NT 4.0 with SP4 and later), another application, service, or kernel mode driver is bound to the same address with exclusive access.
    /// Such exclusive access is a new feature of Windows NT 4.0 with SP4 and later, and is implemented by using the SO_EXCLUSIVEADDRUSE option.
    WSAEACCES = 10013,

    /// Bad address.
    /// The system detected an invalid pointer address in attempting to use a pointer argument of a call.
    /// This error occurs if an application passes an invalid pointer value, or if the length of the buffer is too small.
    /// For instance, if the length of an argument, which is a sockaddr structure, is smaller than the sizeof(sockaddr).
    WSAEFAULT = 10014,

    /// Invalid argument.
    /// Some invalid argument was supplied (for example, specifying an invalid level to the setsockopt function).
    /// In some instances, it also refers to the current state of the socket—for instance, calling accept on a socket that is not listening.
    WSAEINVAL = 10022,

    /// Too many open files.
    /// Too many open sockets. Each implementation may have a maximum number of socket handles available, either globally, per process, or per thread.
    WSAEMFILE = 10024,

    /// Resource temporarily unavailable.
    /// This error is returned from operations on nonblocking sockets that cannot be completed immediately, for example recv when no data is queued to be read from the socket.
    /// It is a nonfatal error, and the operation should be retried later.
    /// It is normal for WSAEWOULDBLOCK to be reported as the result from calling connect on a nonblocking SOCK_STREAM socket, since some time must elapse for the connection to be established.
    WSAEWOULDBLOCK = 10035,

    /// Operation now in progress.
    /// A blocking operation is currently executing.
    /// Windows Sockets only allows a single blocking operation—per- task or thread—to be outstanding, and if any other function call is made (whether or not it references that or any other socket) the function fails with the WSAEINPROGRESS error.
    WSAEINPROGRESS = 10036,

    /// Operation already in progress.
    /// An operation was attempted on a nonblocking socket with an operation already in progress—that is, calling connect a second time on a nonblocking socket that is already connecting, or canceling an asynchronous request (WSAAsyncGetXbyY) that has already been canceled or completed.
    WSAEALREADY = 10037,

    /// Socket operation on nonsocket.
    /// An operation was attempted on something that is not a socket.
    /// Either the socket handle parameter did not reference a valid socket, or for select, a member of an fd_set was not valid.
    WSAENOTSOCK = 10038,

    /// Destination address required.
    /// A required address was omitted from an operation on a socket.
    /// For example, this error is returned if sendto is called with the remote address of ADDR_ANY.
    WSAEDESTADDRREQ = 10039,

    /// Message too long.
    /// A message sent on a datagram socket was larger than the internal message buffer or some other network limit, or the buffer used to receive a datagram was smaller than the datagram itself.
    WSAEMSGSIZE = 10040,

    /// Protocol wrong type for socket.
    /// A protocol was specified in the socket function call that does not support the semantics of the socket type requested.
    /// For example, the ARPA Internet UDP protocol cannot be specified with a socket type of SOCK_STREAM.
    WSAEPROTOTYPE = 10041,

    /// Bad protocol option.
    /// An unknown, invalid or unsupported option or level was specified in a getsockopt or setsockopt call.
    WSAENOPROTOOPT = 10042,

    /// Protocol not supported.
    /// The requested protocol has not been configured into the system, or no implementation for it exists.
    /// For example, a socket call requests a SOCK_DGRAM socket, but specifies a stream protocol.
    WSAEPROTONOSUPPORT = 10043,

    /// Socket type not supported.
    /// The support for the specified socket type does not exist in this address family.
    /// For example, the optional type SOCK_RAW might be selected in a socket call, and the implementation does not support SOCK_RAW sockets at all.
    WSAESOCKTNOSUPPORT = 10044,

    /// Operation not supported.
    /// The attempted operation is not supported for the type of object referenced.
    /// Usually this occurs when a socket descriptor to a socket that cannot support this operation is trying to accept a connection on a datagram socket.
    WSAEOPNOTSUPP = 10045,

    /// Protocol family not supported.
    /// The protocol family has not been configured into the system or no implementation for it exists.
    /// This message has a slightly different meaning from WSAEAFNOSUPPORT.
    /// However, it is interchangeable in most cases, and all Windows Sockets functions that return one of these messages also specify WSAEAFNOSUPPORT.
    WSAEPFNOSUPPORT = 10046,

    /// Address family not supported by protocol family.
    /// An address incompatible with the requested protocol was used.
    /// All sockets are created with an associated address family (that is, AF_INET for Internet Protocols) and a generic protocol type (that is, SOCK_STREAM).
    /// This error is returned if an incorrect protocol is explicitly requested in the socket call, or if an address of the wrong family is used for a socket, for example, in sendto.
    WSAEAFNOSUPPORT = 10047,

    /// Address already in use.
    /// Typically, only one usage of each socket address (protocol/IP address/port) is permitted.
    /// This error occurs if an application attempts to bind a socket to an IP address/port that has already been used for an existing socket, or a socket that was not closed properly, or one that is still in the process of closing.
    /// For server applications that need to bind multiple sockets to the same port number, consider using setsockopt (SO_REUSEADDR).
    /// Client applications usually need not call bind at all—connect chooses an unused port automatically.
    /// When bind is called with a wildcard address (involving ADDR_ANY), a WSAEADDRINUSE error could be delayed until the specific address is committed.
    /// This could happen with a call to another function later, including connect, listen, WSAConnect, or WSAJoinLeaf.
    WSAEADDRINUSE = 10048,

    /// Cannot assign requested address.
    /// The requested address is not valid in its context.
    /// This normally results from an attempt to bind to an address that is not valid for the local computer.
    /// This can also result from connect, sendto, WSAConnect, WSAJoinLeaf, or WSASendTo when the remote address or port is not valid for a remote computer (for example, address or port 0).
    WSAEADDRNOTAVAIL = 10049,

    /// Network is down.
    /// A socket operation encountered a dead network.
    /// This could indicate a serious failure of the network system (that is, the protocol stack that the Windows Sockets DLL runs over), the network interface, or the local network itself.
    WSAENETDOWN = 10050,

    /// Network is unreachable.
    /// A socket operation was attempted to an unreachable network.
    /// This usually means the local software knows no route to reach the remote host.
    WSAENETUNREACH = 10051,

    /// Network dropped connection on reset.
    /// The connection has been broken due to keep-alive activity detecting a failure while the operation was in progress.
    /// It can also be returned by setsockopt if an attempt is made to set SO_KEEPALIVE on a connection that has already failed.
    WSAENETRESET = 10052,

    /// Software caused connection abort.
    /// An established connection was aborted by the software in your host computer, possibly due to a data transmission time-out or protocol error.
    WSAECONNABORTED = 10053,

    /// Connection reset by peer.
    /// An existing connection was forcibly closed by the remote host.
    /// This normally results if the peer application on the remote host is suddenly stopped, the host is rebooted, the host or remote network interface is disabled, or the remote host uses a hard close (see setsockopt for more information on the SO_LINGER option on the remote socket).
    /// This error may also result if a connection was broken due to keep-alive activity detecting a failure while one or more operations are in progress.
    /// Operations that were in progress fail with WSAENETRESET. Subsequent operations fail with WSAECONNRESET.
    WSAECONNRESET = 10054,

    /// No buffer space available.
    /// An operation on a socket could not be performed because the system lacked sufficient buffer space or because a queue was full.
    WSAENOBUFS = 10055,

    /// Socket is already connected.
    /// A connect request was made on an already-connected socket.
    /// Some implementations also return this error if sendto is called on a connected SOCK_DGRAM socket (for SOCK_STREAM sockets, the to parameter in sendto is ignored) although other implementations treat this as a legal occurrence.
    WSAEISCONN = 10056,

    /// Socket is not connected.
    /// A request to send or receive data was disallowed because the socket is not connected and (when sending on a datagram socket using sendto) no address was supplied.
    /// Any other type of operation might also return this error—for example, setsockopt setting SO_KEEPALIVE if the connection has been reset.
    WSAENOTCONN = 10057,

    /// Cannot send after socket shutdown.
    /// A request to send or receive data was disallowed because the socket had already been shut down in that direction with a previous shutdown call.
    /// By calling shutdown a partial close of a socket is requested, which is a signal that sending or receiving, or both have been discontinued.
    WSAESHUTDOWN = 10058,

    /// Too many references.
    /// Too many references to some kernel object.
    WSAETOOMANYREFS = 10059,

    /// Connection timed out.
    /// A connection attempt failed because the connected party did not properly respond after a period of time, or the established connection failed because the connected host has failed to respond.
    WSAETIMEDOUT = 10060,

    /// Connection refused.
    /// No connection could be made because the target computer actively refused it.
    /// This usually results from trying to connect to a service that is inactive on the foreign host—that is, one with no server application running.
    WSAECONNREFUSED = 10061,

    /// Cannot translate name.
    /// Cannot translate a name.
    WSAELOOP = 10062,

    /// Name too long.
    /// A name component or a name was too long.
    WSAENAMETOOLONG = 10063,

    /// Host is down.
    /// A socket operation failed because the destination host is down. A socket operation encountered a dead host.
    /// Networking activity on the local host has not been initiated.
    /// These conditions are more likely to be indicated by the error WSAETIMEDOUT.
    WSAEHOSTDOWN = 10064,

    /// No route to host.
    /// A socket operation was attempted to an unreachable host. See WSAENETUNREACH.
    WSAEHOSTUNREACH = 10065,

    /// Directory not empty.
    /// Cannot remove a directory that is not empty.
    WSAENOTEMPTY = 10066,

    /// Too many processes.
    /// A Windows Sockets implementation may have a limit on the number of applications that can use it simultaneously.
    /// WSAStartup may fail with this error if the limit has been reached.
    WSAEPROCLIM = 10067,

    /// User quota exceeded.
    /// Ran out of user quota.
    WSAEUSERS = 10068,

    /// Disk quota exceeded.
    /// Ran out of disk quota.
    WSAEDQUOT = 10069,

    /// Stale file handle reference.
    /// The file handle reference is no longer available.
    WSAESTALE = 10070,

    /// Item is remote.
    /// The item is not available locally.
    WSAEREMOTE = 10071,

    /// Network subsystem is unavailable.
    /// This error is returned by WSAStartup if the Windows Sockets implementation cannot function at this time because the underlying system it uses to provide network services is currently unavailable.
    /// Users should check:
    ///   - That the appropriate Windows Sockets DLL file is in the current path.
    ///   - That they are not trying to use more than one Windows Sockets implementation simultaneously.
    ///   - If there is more than one Winsock DLL on your system, be sure the first one in the path is appropriate for the network subsystem currently loaded.
    ///   - The Windows Sockets implementation documentation to be sure all necessary components are currently installed and configured correctly.
    WSASYSNOTREADY = 10091,

    /// Winsock.dll version out of range.
    /// The current Windows Sockets implementation does not support the Windows Sockets specification version requested by the application.
    /// Check that no old Windows Sockets DLL files are being accessed.
    WSAVERNOTSUPPORTED = 10092,

    /// Successful WSAStartup not yet performed.
    /// Either the application has not called WSAStartup or WSAStartup failed.
    /// The application may be accessing a socket that the current active task does not own (that is, trying to share a socket between tasks), or WSACleanup has been called too many times.
    WSANOTINITIALISED = 10093,

    /// Graceful shutdown in progress.
    /// Returned by WSARecv and WSARecvFrom to indicate that the remote party has initiated a graceful shutdown sequence.
    WSAEDISCON = 10101,

    /// No more results.
    /// No more results can be returned by the WSALookupServiceNext function.
    WSAENOMORE = 10102,

    /// Call has been canceled.
    /// A call to the WSALookupServiceEnd function was made while this call was still processing. The call has been canceled.
    WSAECANCELLED = 10103,

    /// Procedure call table is invalid.
    /// The service provider procedure call table is invalid.
    /// A service provider returned a bogus procedure table to Ws2_32.dll.
    /// This is usually caused by one or more of the function pointers being NULL.
    WSAEINVALIDPROCTABLE = 10104,

    /// Service provider is invalid.
    /// The requested service provider is invalid.
    /// This error is returned by the WSCGetProviderInfo and WSCGetProviderInfo32 functions if the protocol entry specified could not be found.
    /// This error is also returned if the service provider returned a version number other than 2.0.
    WSAEINVALIDPROVIDER = 10105,

    /// Service provider failed to initialize.
    /// The requested service provider could not be loaded or initialized.
    /// This error is returned if either a service provider's DLL could not be loaded (LoadLibrary failed) or the provider's WSPStartup or NSPStartup function failed.
    WSAEPROVIDERFAILEDINIT = 10106,

    /// System call failure.
    /// A system call that should never fail has failed.
    /// This is a generic error code, returned under various conditions.
    /// Returned when a system call that should never fail does fail.
    /// For example, if a call to WaitForMultipleEvents fails or one of the registry functions fails trying to manipulate the protocol/namespace catalogs.
    /// Returned when a provider does not return SUCCESS and does not provide an extended error code.
    /// Can indicate a service provider implementation error.
    WSASYSCALLFAILURE = 10107,

    /// Service not found.
    /// No such service is known. The service cannot be found in the specified name space.
    WSASERVICE_NOT_FOUND = 10108,

    /// Class type not found.
    /// The specified class was not found.
    WSATYPE_NOT_FOUND = 10109,

    /// No more results.
    /// No more results can be returned by the WSALookupServiceNext function.
    WSA_E_NO_MORE = 10110,

    /// Call was canceled.
    /// A call to the WSALookupServiceEnd function was made while this call was still processing. The call has been canceled.
    WSA_E_CANCELLED = 10111,

    /// Database query was refused.
    /// A database query failed because it was actively refused.
    WSAEREFUSED = 10112,

    /// Host not found.
    /// No such host is known. The name is not an official host name or alias, or it cannot be found in the database(s) being queried.
    /// This error may also be returned for protocol and service queries, and means that the specified name could not be found in the relevant database.
    WSAHOST_NOT_FOUND = 11001,

    /// Nonauthoritative host not found.
    /// This is usually a temporary error during host name resolution and means that the local server did not receive a response from an authoritative server. A retry at some time later may be successful.
    WSATRY_AGAIN = 11002,

    /// This is a nonrecoverable error.
    /// This indicates that some sort of nonrecoverable error occurred during a database lookup.
    /// This may be because the database files (for example, BSD-compatible HOSTS, SERVICES, or PROTOCOLS files) could not be found, or a DNS request was returned by the server with a severe error.
    WSANO_RECOVERY = 11003,

    /// Valid name, no data record of requested type.
    /// The requested name is valid and was found in the database, but it does not have the correct associated data being resolved for.
    /// The usual example for this is a host name-to-address translation attempt (using gethostbyname or WSAAsyncGetHostByName) which uses the DNS (Domain Name Server).
    /// An MX record is returned but no A record—indicating the host itself exists, but is not directly reachable.
    WSANO_DATA = 11004,

    /// QoS receivers.
    /// At least one QoS reserve has arrived.
    WSA_QOS_RECEIVERS = 11005,

    /// QoS senders.
    /// At least one QoS send path has arrived.
    WSA_QOS_SENDERS = 11006,

    /// No QoS senders.
    /// There are no QoS senders.
    WSA_QOS_NO_SENDERS = 11007,

    /// QoS no receivers.
    /// There are no QoS receivers.
    WSA_QOS_NO_RECEIVERS = 11008,

    /// QoS request confirmed.
    /// The QoS reserve request has been confirmed.
    WSA_QOS_REQUEST_CONFIRMED = 11009,

    /// QoS admission error.
    /// A QoS error occurred due to lack of resources.
    WSA_QOS_ADMISSION_FAILURE = 11010,

    /// QoS policy failure.
    /// The QoS request was rejected because the policy system couldn't allocate the requested resource within the existing policy.
    WSA_QOS_POLICY_FAILURE = 11011,

    /// QoS bad style.
    /// An unknown or conflicting QoS style was encountered.
    WSA_QOS_BAD_STYLE = 11012,

    /// QoS bad object.
    /// A problem was encountered with some part of the filterspec or the provider-specific buffer in general.
    WSA_QOS_BAD_OBJECT = 11013,

    /// QoS traffic control error.
    /// An error with the underlying traffic control (TC) API as the generic QoS request was converted for local enforcement by the TC API.
    /// This could be due to an out of memory error or to an internal QoS provider error.
    WSA_QOS_TRAFFIC_CTRL_ERROR = 11014,

    /// QoS generic error.
    /// A general QoS error.
    WSA_QOS_GENERIC_ERROR = 11015,

    /// QoS service type error.
    /// An invalid or unrecognized service type was found in the QoS flowspec.
    WSA_QOS_ESERVICETYPE = 11016,

    /// QoS flowspec error.
    /// An invalid or inconsistent flowspec was found in the QOS structure.
    WSA_QOS_EFLOWSPEC = 11017,

    /// Invalid QoS provider buffer.
    /// An invalid QoS provider-specific buffer.
    WSA_QOS_EPROVSPECBUF = 11018,

    /// Invalid QoS filter style.
    /// An invalid QoS filter style was used.
    WSA_QOS_EFILTERSTYLE = 11019,

    /// Invalid QoS filter type.
    /// An invalid QoS filter type was used.
    WSA_QOS_EFILTERTYPE = 11020,

    /// Incorrect QoS filter count.
    /// An incorrect number of QoS FILTERSPECs were specified in the FLOWDESCRIPTOR.
    WSA_QOS_EFILTERCOUNT = 11021,

    /// Invalid QoS object length.
    /// An object with an invalid ObjectLength field was specified in the QoS provider-specific buffer.
    WSA_QOS_EOBJLENGTH = 11022,

    /// Incorrect QoS flow count.
    /// An incorrect number of flow descriptors was specified in the QoS structure.
    WSA_QOS_EFLOWCOUNT = 11023,

    /// Unrecognized QoS object.
    /// An unrecognized object was found in the QoS provider-specific buffer.
    WSA_QOS_EUNKOWNPSOBJ = 11024,

    /// Invalid QoS policy object.
    /// An invalid policy object was found in the QoS provider-specific buffer.
    WSA_QOS_EPOLICYOBJ = 11025,

    /// Invalid QoS flow descriptor.
    /// An invalid QoS flow descriptor was found in the flow descriptor list.
    WSA_QOS_EFLOWDESC = 11026,

    /// Invalid QoS provider-specific flowspec.
    /// An invalid or inconsistent flowspec was found in the QoS provider-specific buffer.
    WSA_QOS_EPSFLOWSPEC = 11027,

    /// Invalid QoS provider-specific filterspec.
    /// An invalid FILTERSPEC was found in the QoS provider-specific buffer.
    WSA_QOS_EPSFILTERSPEC = 11028,

    /// Invalid QoS shape discard mode object.
    /// An invalid shape discard mode object was found in the QoS provider-specific buffer.
    WSA_QOS_ESDMODEOBJ = 11029,

    /// Invalid QoS shaping rate object.
    /// An invalid shaping rate object was found in the QoS provider-specific buffer.
    WSA_QOS_ESHAPERATEOBJ = 11030,

    /// Reserved policy QoS element type.
    /// A reserved policy element was found in the QoS provider-specific buffer.
    WSA_QOS_RESERVED_PETYPE = 11031,

    _,
};

pub extern "ws2_32" fn accept(
    s: SOCKET,
    addr: ?*sockaddr,
    addrlen: ?*i32,
) callconv(WINAPI) SOCKET;

pub extern "ws2_32" fn bind(
    s: SOCKET,
    name: *const sockaddr,
    namelen: i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn closesocket(
    s: SOCKET,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn connect(
    s: SOCKET,
    name: *const sockaddr,
    namelen: i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn ioctlsocket(
    s: SOCKET,
    cmd: i32,
    argp: *u32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn getpeername(
    s: SOCKET,
    name: *sockaddr,
    namelen: *i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn getsockname(
    s: SOCKET,
    name: *sockaddr,
    namelen: *i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn getsockopt(
    s: SOCKET,
    level: i32,
    optname: i32,
    optval: [*]u8,
    optlen: *i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn htonl(
    hostlong: u32,
) callconv(WINAPI) u32;

pub extern "ws2_32" fn htons(
    hostshort: u16,
) callconv(WINAPI) u16;

pub extern "ws2_32" fn inet_addr(
    cp: ?[*]const u8,
) callconv(WINAPI) u32;

pub extern "ws2_32" fn listen(
    s: SOCKET,
    backlog: i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn ntohl(
    netlong: u32,
) callconv(WINAPI) u32;

pub extern "ws2_32" fn ntohs(
    netshort: u16,
) callconv(WINAPI) u16;

pub extern "ws2_32" fn recv(
    s: SOCKET,
    buf: [*]u8,
    len: i32,
    flags: i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn recvfrom(
    s: SOCKET,
    buf: [*]u8,
    len: i32,
    flags: i32,
    from: ?*sockaddr,
    fromlen: ?*i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn select(
    nfds: i32,
    readfds: ?*fd_set,
    writefds: ?*fd_set,
    exceptfds: ?*fd_set,
    timeout: ?*const timeval,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn send(
    s: SOCKET,
    buf: [*]const u8,
    len: i32,
    flags: u32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn sendto(
    s: SOCKET,
    buf: [*]const u8,
    len: i32,
    flags: i32,
    to: *const sockaddr,
    tolen: i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn setsockopt(
    s: SOCKET,
    level: i32,
    optname: i32,
    optval: ?[*]const u8,
    optlen: i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn shutdown(
    s: SOCKET,
    how: i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn socket(
    af: i32,
    @"type": i32,
    protocol: i32,
) callconv(WINAPI) SOCKET;

pub extern "ws2_32" fn WSAStartup(
    wVersionRequired: WORD,
    lpWSAData: *WSADATA,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSACleanup() callconv(WINAPI) i32;

pub extern "ws2_32" fn WSASetLastError(iError: i32) callconv(WINAPI) void;

pub extern "ws2_32" fn WSAGetLastError() callconv(WINAPI) WinsockError;

pub extern "ws2_32" fn WSAIsBlocking() callconv(WINAPI) BOOL;

pub extern "ws2_32" fn WSAUnhookBlockingHook() callconv(WINAPI) i32;

pub extern "ws2_32" fn WSASetBlockingHook(lpBlockFunc: FARPROC) callconv(WINAPI) FARPROC;

pub extern "ws2_32" fn WSACancelBlockingCall() callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAAsyncGetServByName(
    hWnd: HWND,
    wMsg: u32,
    name: [*:0]const u8,
    proto: ?[*:0]const u8,
    buf: [*]u8,
    buflen: i32,
) callconv(WINAPI) HANDLE;

pub extern "ws2_32" fn WSAAsyncGetServByPort(
    hWnd: HWND,
    wMsg: u32,
    port: i32,
    proto: ?[*:0]const u8,
    buf: [*]u8,
    buflen: i32,
) callconv(WINAPI) HANDLE;

pub extern "ws2_32" fn WSAAsyncGetProtoByName(
    hWnd: HWND,
    wMsg: u32,
    name: [*:0]const u8,
    buf: [*]u8,
    buflen: i32,
) callconv(WINAPI) HANDLE;

pub extern "ws2_32" fn WSAAsyncGetProtoByNumber(
    hWnd: HWND,
    wMsg: u32,
    number: i32,
    buf: [*]u8,
    buflen: i32,
) callconv(WINAPI) HANDLE;

pub extern "ws2_32" fn WSACancelAsyncRequest(hAsyncTaskHandle: HANDLE) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAAsyncSelect(
    s: SOCKET,
    hWnd: HWND,
    wMsg: u32,
    lEvent: i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAAccept(
    s: SOCKET,
    addr: ?*sockaddr,
    addrlen: ?*i32,
    lpfnCondition: ?LPCONDITIONPROC,
    dwCallbackData: usize,
) callconv(WINAPI) SOCKET;

pub extern "ws2_32" fn WSACloseEvent(hEvent: HANDLE) callconv(WINAPI) BOOL;

pub extern "ws2_32" fn WSAConnect(
    s: SOCKET,
    name: *const sockaddr,
    namelen: i32,
    lpCallerData: ?*WSABUF,
    lpCalleeData: ?*WSABUF,
    lpSQOS: ?*QOS,
    lpGQOS: ?*QOS,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAConnectByNameW(
    s: SOCKET,
    nodename: [*:0]const u16,
    servicename: [*:0]const u16,
    LocalAddressLength: ?*u32,
    LocalAddress: ?*sockaddr,
    RemoteAddressLength: ?*u32,
    RemoteAddress: ?*sockaddr,
    timeout: ?*const timeval,
    Reserved: *OVERLAPPED,
) callconv(WINAPI) BOOL;

pub extern "ws2_32" fn WSAConnectByNameA(
    s: SOCKET,
    nodename: [*:0]const u8,
    servicename: [*:0]const u8,
    LocalAddressLength: ?*u32,
    LocalAddress: ?*sockaddr,
    RemoteAddressLength: ?*u32,
    RemoteAddress: ?*sockaddr,
    timeout: ?*const timeval,
    Reserved: *OVERLAPPED,
) callconv(WINAPI) BOOL;

pub extern "ws2_32" fn WSAConnectByList(
    s: SOCKET,
    SocketAddress: *SOCKET_ADDRESS_LIST,
    LocalAddressLength: ?*u32,
    LocalAddress: ?*sockaddr,
    RemoteAddressLength: ?*u32,
    RemoteAddress: ?*sockaddr,
    timeout: ?*const timeval,
    Reserved: *OVERLAPPED,
) callconv(WINAPI) BOOL;

pub extern "ws2_32" fn WSACreateEvent() callconv(WINAPI) HANDLE;

pub extern "ws2_32" fn WSADuplicateSocketA(
    s: SOCKET,
    dwProcessId: u32,
    lpProtocolInfo: *WSAPROTOCOL_INFOA,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSADuplicateSocketW(
    s: SOCKET,
    dwProcessId: u32,
    lpProtocolInfo: *WSAPROTOCOL_INFOW,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAEnumNetworkEvents(
    s: SOCKET,
    hEventObject: HANDLE,
    lpNetworkEvents: *WSANETWORKEVENTS,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAEnumProtocolsA(
    lpiProtocols: ?*i32,
    lpProtocolBuffer: ?*WSAPROTOCOL_INFOA,
    lpdwBufferLength: *u32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAEnumProtocolsW(
    lpiProtocols: ?*i32,
    lpProtocolBuffer: ?*WSAPROTOCOL_INFOW,
    lpdwBufferLength: *u32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAEventSelect(
    s: SOCKET,
    hEventObject: HANDLE,
    lNetworkEvents: i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAGetOverlappedResult(
    s: SOCKET,
    lpOverlapped: *OVERLAPPED,
    lpcbTransfer: *u32,
    fWait: BOOL,
    lpdwFlags: *u32,
) callconv(WINAPI) BOOL;

pub extern "ws2_32" fn WSAGetQOSByName(
    s: SOCKET,
    lpQOSName: *WSABUF,
    lpQOS: *QOS,
) callconv(WINAPI) BOOL;

pub extern "ws2_32" fn WSAHtonl(
    s: SOCKET,
    hostlong: u32,
    lpnetlong: *u32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAHtons(
    s: SOCKET,
    hostshort: u16,
    lpnetshort: *u16,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAIoctl(
    s: SOCKET,
    dwIoControlCode: u32,
    lpvInBuffer: ?*const c_void,
    cbInBuffer: u32,
    lpvOutbuffer: ?*c_void,
    cbOutbuffer: u32,
    lpcbBytesReturned: *u32,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAJoinLeaf(
    s: SOCKET,
    name: *const sockaddr,
    namelen: i32,
    lpCallerdata: ?*WSABUF,
    lpCalleeData: ?*WSABUF,
    lpSQOS: ?*QOS,
    lpGQOS: ?*QOS,
    dwFlags: u32,
) callconv(WINAPI) SOCKET;

pub extern "ws2_32" fn WSANtohl(
    s: SOCKET,
    netlong: u32,
    lphostlong: *u32,
) callconv(WINAPI) u32;

pub extern "ws2_32" fn WSANtohs(
    s: SOCKET,
    netshort: u16,
    lphostshort: *u16,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSARecv(
    s: SOCKET,
    lpBuffers: [*]WSABUF,
    dwBufferCouynt: u32,
    lpNumberOfBytesRecv: ?*u32,
    lpFlags: *u32,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSARecvDisconnect(
    s: SOCKET,
    lpInboundDisconnectData: ?*WSABUF,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSARecvFrom(
    s: SOCKET,
    lpBuffers: [*]WSABUF,
    dwBuffercount: u32,
    lpNumberOfBytesRecvd: ?*u32,
    lpFlags: *u32,
    lpFrom: ?*sockaddr,
    lpFromlen: ?*i32,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAResetEvent(hEvent: HANDLE) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSASend(
    s: SOCKET,
    lpBuffers: [*]WSABUF,
    dwBufferCount: u32,
    lpNumberOfBytesSent: ?*u32,
    dwFlags: u32,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSASendMsg(
    s: SOCKET,
    lpMsg: *const WSAMSG_const,
    dwFlags: u32,
    lpNumberOfBytesSent: ?*u32,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSARecvMsg(
    s: SOCKET,
    lpMsg: *WSAMSG,
    lpdwNumberOfBytesRecv: ?*u32,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSASendDisconnect(
    s: SOCKET,
    lpOutboundDisconnectData: ?*WSABUF,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSASendTo(
    s: SOCKET,
    lpBuffers: [*]WSABUF,
    dwBufferCount: u32,
    lpNumberOfBytesSent: ?*u32,
    dwFlags: u32,
    lpTo: ?*const sockaddr,
    iToLen: i32,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRounte: ?LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSASetEvent(
    hEvent: HANDLE,
) callconv(WINAPI) BOOL;

pub extern "ws2_32" fn WSASocketA(
    af: i32,
    @"type": i32,
    protocol: i32,
    lpProtocolInfo: ?*WSAPROTOCOL_INFOA,
    g: u32,
    dwFlags: u32,
) callconv(WINAPI) SOCKET;

pub extern "ws2_32" fn WSASocketW(
    af: i32,
    @"type": i32,
    protocol: i32,
    lpProtocolInfo: ?*WSAPROTOCOL_INFOW,
    g: u32,
    dwFlags: u32,
) callconv(WINAPI) SOCKET;

pub extern "ws2_32" fn WSAWaitForMultipleEvents(
    cEvents: u32,
    lphEvents: [*]const HANDLE,
    fWaitAll: BOOL,
    dwTimeout: u32,
    fAlertable: BOOL,
) callconv(WINAPI) u32;

pub extern "ws2_32" fn WSAAddressToStringA(
    lpsaAddress: *sockaddr,
    dwAddressLength: u32,
    lpProtocolInfo: ?*WSAPROTOCOL_INFOA,
    lpszAddressString: [*]u8,
    lpdwAddressStringLength: *u32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAAddressToStringW(
    lpsaAddress: *sockaddr,
    dwAddressLength: u32,
    lpProtocolInfo: ?*WSAPROTOCOL_INFOW,
    lpszAddressString: [*]u16,
    lpdwAddressStringLength: *u32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAStringToAddressA(
    AddressString: [*:0]const u8,
    AddressFamily: i32,
    lpProtocolInfo: ?*WSAPROTOCOL_INFOA,
    lpAddress: *sockaddr,
    lpAddressLength: *i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAStringToAddressW(
    AddressString: [*:0]const u16,
    AddressFamily: i32,
    lpProtocolInfo: ?*WSAPROTOCOL_INFOW,
    lpAddrses: *sockaddr,
    lpAddressLength: *i32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAProviderConfigChange(
    lpNotificationHandle: *HANDLE,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn WSAPoll(
    fdArray: [*]WSAPOLLFD,
    fds: u32,
    timeout: i32,
) callconv(WINAPI) i32;

pub extern "mswsock" fn WSARecvEx(
    s: SOCKET,
    buf: [*]u8,
    len: i32,
    flags: *i32,
) callconv(WINAPI) i32;

pub extern "mswsock" fn TransmitFile(
    hSocket: SOCKET,
    hFile: HANDLE,
    nNumberOfBytesToWrite: u32,
    nNumberOfBytesPerSend: u32,
    lpOverlapped: ?*OVERLAPPED,
    lpTransmitBuffers: ?*TRANSMIT_FILE_BUFFERS,
    dwReserved: u32,
) callconv(WINAPI) BOOL;

pub extern "mswsock" fn AcceptEx(
    sListenSocket: SOCKET,
    sAcceptSocket: SOCKET,
    lpOutputBuffer: *c_void,
    dwReceiveDataLength: u32,
    dwLocalAddressLength: u32,
    dwRemoteAddressLength: u32,
    lpdwBytesReceived: *u32,
    lpOverlapped: *OVERLAPPED,
) callconv(WINAPI) BOOL;

pub extern "mswsock" fn GetAcceptExSockaddrs(
    lpOutputBuffer: *c_void,
    dwReceiveDataLength: u32,
    dwLocalAddressLength: u32,
    dwRemoteAddressLength: u32,
    LocalSockaddr: **sockaddr,
    LocalSockaddrLength: *i32,
    RemoteSockaddr: **sockaddr,
    RemoteSockaddrLength: *i32,
) callconv(WINAPI) void;

pub extern "ws2_32" fn WSAProviderCompleteAsyncCall(
    hAsyncCall: HANDLE,
    iRetCode: i32,
) callconv(WINAPI) i32;

pub extern "mswsock" fn EnumProtocolsA(
    lpiProtocols: ?*i32,
    lpProtocolBuffer: *c_void,
    lpdwBufferLength: *u32,
) callconv(WINAPI) i32;

pub extern "mswsock" fn EnumProtocolsW(
    lpiProtocols: ?*i32,
    lpProtocolBuffer: *c_void,
    lpdwBufferLength: *u32,
) callconv(WINAPI) i32;

pub extern "mswsock" fn GetAddressByNameA(
    dwNameSpace: u32,
    lpServiceType: *GUID,
    lpServiceName: ?[*:0]u8,
    lpiProtocols: ?*i32,
    dwResolution: u32,
    lpServiceAsyncInfo: ?*SERVICE_ASYNC_INFO,
    lpCsaddrBuffer: *c_void,
    lpAliasBuffer: ?[*:0]const u8,
    lpdwAliasBufferLength: *u32,
) callconv(WINAPI) i32;

pub extern "mswsock" fn GetAddressByNameW(
    dwNameSpace: u32,
    lpServiceType: *GUID,
    lpServiceName: ?[*:0]u16,
    lpiProtocols: ?*i32,
    dwResolution: u32,
    lpServiceAsyncInfo: ?*SERVICE_ASYNC_INFO,
    lpCsaddrBuffer: *c_void,
    ldwBufferLEngth: *u32,
    lpAliasBuffer: ?[*:0]u16,
    lpdwAliasBufferLength: *u32,
) callconv(WINAPI) i32;

pub extern "mswsock" fn GetTypeByNameA(
    lpServiceName: [*:0]u8,
    lpServiceType: *GUID,
) callconv(WINAPI) i32;

pub extern "mswsock" fn GetTypeByNameW(
    lpServiceName: [*:0]u16,
    lpServiceType: *GUID,
) callconv(WINAPI) i32;

pub extern "mswsock" fn GetNameByTypeA(
    lpServiceType: *GUID,
    lpServiceName: [*:0]u8,
    dwNameLength: u32,
) callconv(WINAPI) i32;

pub extern "mswsock" fn GetNameByTypeW(
    lpServiceType: *GUID,
    lpServiceName: [*:0]u16,
    dwNameLength: u32,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn getaddrinfo(
    pNodeName: ?[*:0]const u8,
    pServiceName: ?[*:0]const u8,
    pHints: ?*const addrinfoa,
    ppResult: **addrinfoa,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn GetAddrInfoExA(
    pName: ?[*:0]const u8,
    pServiceName: ?[*:0]const u8,
    dwNameSapce: u32,
    lpNspId: ?*GUID,
    hints: ?*const addrinfoexA,
    ppResult: **addrinfoexA,
    timeout: ?*timeval,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: ?LPLOOKUPSERVICE_COMPLETION_ROUTINE,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn GetAddrInfoExCancel(
    lpHandle: *HANDLE,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn GetAddrInfoExOverlappedResult(
    lpOverlapped: *OVERLAPPED,
) callconv(WINAPI) i32;

pub extern "ws2_32" fn freeaddrinfo(
    pAddrInfo: ?*addrinfoa,
) callconv(WINAPI) void;

pub extern "ws2_32" fn FreeAddrInfoEx(
    pAddrInfoEx: ?*addrinfoexA,
) callconv(WINAPI) void;

pub extern "ws2_32" fn getnameinfo(
    pSockaddr: *const sockaddr,
    SockaddrLength: i32,
    pNodeBuffer: ?[*]u8,
    NodeBufferSize: u32,
    pServiceBuffer: ?[*]u8,
    ServiceBufferName: u32,
    Flags: i32,
) callconv(WINAPI) i32;

pub extern "IPHLPAPI" fn if_nametoindex(
    InterfaceName: [*:0]const u8,
) callconv(WINAPI) u32;
