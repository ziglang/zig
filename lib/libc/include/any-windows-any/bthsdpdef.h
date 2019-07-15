/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_BTHSDPDEF
#define _INC_BTHSDPDEF

#ifdef __cplusplus
extern "C" {
#endif

typedef union SdpQueryUuidUnion {
  GUID   uuid128;
  ULONG  uuid32;
  USHORT uuid16;
} SdpQueryUuidUnion;

typedef struct _SdpAttributeRange {
  USHORT minAttribute;
  USHORT maxAttribute;
} SdpAttributeRange;

typedef struct _SdpQueryUuid {
  SdpQueryUuidUnion u;
  USHORT            uuidType;
} SdpQueryUuid;

typedef enum _SDP_TYPE {
  SDP_TYPE_NIL = 0x00,
  SDP_TYPE_UINT = 0x01,
  SDP_TYPE_INT = 0x02,
  SDP_TYPE_UUID = 0x03,
  SDP_TYPE_STRING = 0x04,
  SDP_TYPE_BOOLEAN = 0x05,
  SDP_TYPE_SEQUENCE = 0x06,
  SDP_TYPE_ALTERNATIVE = 0x07,
  SDP_TYPE_URL = 0x08,
  SDP_TYPE_CONTAINER = 0x20
} SDP_TYPE;

typedef enum _SDP_SPECIFICTYPE {
  SDP_ST_NONE = 0x0000,
  SDP_ST_UINT8 = 0x0010,
  SDP_ST_UINT16 = 0x0110,
  SDP_ST_UINT32 = 0x0210,
  SDP_ST_UINT64 = 0x0310,
  SDP_ST_UINT128 = 0x0410,
  SDP_ST_INT8 = 0x0020,
  SDP_ST_INT16 = 0x0120,
  SDP_ST_INT32 = 0x0220,
  SDP_ST_INT64 = 0x0320,
  SDP_ST_INT128 = 0x0420,
  SDP_ST_UUID16 = 0x0130,
  SDP_ST_UUID32 = 0x0220,
  SDP_ST_UUID128 = 0x0430
} SDP_SPECIFICTYPE;

typedef struct _SDP_LARGE_INTEGER_16 {
  ULONGLONG LowPart;
  LONGLONG HighPart;
} SDP_LARGE_INTEGER_16;

typedef struct _SDP_ULARGE_INTEGER_16 {
  ULONGLONG LowPart;
  ULONGLONG HighPart;
} SDP_ULARGE_INTEGER_16;

typedef struct _SPD_ELEMENT_DATA {
  SDP_TYPE         type;
  SDP_SPECIFICTYPE specificType;
  __C89_NAMELESS union {
    SDP_LARGE_INTEGER_16  int128;
    LONGLONG              int64;
    LONG                  int32;
    SHORT                 int16;
    CHAR                  int8;
    SDP_ULARGE_INTEGER_16 uint128;
    ULONGLONG             uint64;
    ULONG                 uint32;
    USHORT                uint16;
    UCHAR                 uint8;
    UCHAR                 booleanVal;
    GUID                  uuid128;
    ULONG                 uuid32;
    USHORT                uuid16;
    struct {
      LPBYTE value;
      ULONG  length;
    } string;
    struct {
      LPBYTE value;
      ULONG  length;
    } url;
    struct {
      LPBYTE value;
      ULONG  length;
    } sequence;
    struct {
      LPBYTE value;
      ULONG  length;
    } alternative;
  } data;
} SDP_ELEMENT_DATA, *PSDP_ELEMENT_DATA;

typedef struct _SDP_STRING_TYPE_DATA {
  USHORT encoding;
  USHORT mibeNum;
  USHORT attributeID;
} SDP_STRING_TYPE_DATA, *PSDP_STRING_TYPE_DATA;

#ifdef __cplusplus
}
#endif
#endif /*_INC_BTHSDPDEF*/
