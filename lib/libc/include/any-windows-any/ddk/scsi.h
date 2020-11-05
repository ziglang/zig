/*
 * scsi.h
 *
 * SCSI port and class interface.
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

#ifndef _NTSCSI_
#define _NTSCSI_

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _NTSCSI_USER_MODE_
#include "srb.h"
#endif

#define NOTIFICATION_OPERATIONAL_CHANGE_CLASS_MASK    0x02
#define NOTIFICATION_POWER_MANAGEMENT_CLASS_MASK      0x04
#define NOTIFICATION_EXTERNAL_REQUEST_CLASS_MASK      0x08
#define NOTIFICATION_MEDIA_STATUS_CLASS_MASK          0x10
#define NOTIFICATION_MULTI_HOST_CLASS_MASK            0x20
#define NOTIFICATION_DEVICE_BUSY_CLASS_MASK           0x40


#define NOTIFICATION_NO_CLASS_EVENTS                  0x0
#define NOTIFICATION_OPERATIONAL_CHANGE_CLASS_EVENTS  0x1
#define NOTIFICATION_POWER_MANAGEMENT_CLASS_EVENTS    0x2
#define NOTIFICATION_EXTERNAL_REQUEST_CLASS_EVENTS    0x3
#define NOTIFICATION_MEDIA_STATUS_CLASS_EVENTS        0x4
#define NOTIFICATION_MULTI_HOST_CLASS_EVENTS          0x5
#define NOTIFICATION_DEVICE_BUSY_CLASS_EVENTS         0x6

#define NOTIFICATION_OPERATIONAL_EVENT_NO_CHANGE         0x0
#define NOTIFICATION_OPERATIONAL_EVENT_CHANGE_REQUESTED  0x1
#define NOTIFICATION_OPERATIONAL_EVENT_CHANGE_OCCURRED   0x2

#define NOTIFICATION_OPERATIONAL_STATUS_AVAILABLE        0x0
#define NOTIFICATION_OPERATIONAL_STATUS_TEMPORARY_BUSY   0x1
#define NOTIFICATION_OPERATIONAL_STATUS_EXTENDED_BUSY    0x2

#define NOTIFICATION_OPERATIONAL_OPCODE_NONE             0x0
#define NOTIFICATION_OPERATIONAL_OPCODE_FEATURE_CHANGE   0x1
#define NOTIFICATION_OPERATIONAL_OPCODE_FEATURE_ADDED    0x2
#define NOTIFICATION_OPERATIONAL_OPCODE_UNIT_RESET       0x3
#define NOTIFICATION_OPERATIONAL_OPCODE_FIRMWARE_CHANGED 0x4
#define NOTIFICATION_OPERATIONAL_OPCODE_INQUIRY_CHANGED  0x5

#define NOTIFICATION_POWER_EVENT_NO_CHANGE          0x0
#define NOTIFICATION_POWER_EVENT_CHANGE_SUCCEEDED   0x1
#define NOTIFICATION_POWER_EVENT_CHANGE_FAILED      0x2

#define NOTIFICATION_POWER_STATUS_ACTIVE            0x1
#define NOTIFICATION_POWER_STATUS_IDLE              0x2
#define NOTIFICATION_POWER_STATUS_STANDBY           0x3
#define NOTIFICATION_POWER_STATUS_SLEEP             0x4

#define NOTIFICATION_MEDIA_EVENT_NO_EVENT           0x0
#define NOTIFICATION_EXTERNAL_EVENT_NO_CHANGE       0x0
#define NOTIFICATION_EXTERNAL_EVENT_BUTTON_DOWN     0x1
#define NOTIFICATION_EXTERNAL_EVENT_BUTTON_UP       0x2
#define NOTIFICATION_EXTERNAL_EVENT_EXTERNAL        0x3

#define NOTIFICATION_EXTERNAL_STATUS_READY          0x0
#define NOTIFICATION_EXTERNAL_STATUS_PREVENT        0x1

#define NOTIFICATION_EXTERNAL_REQUEST_NONE          0x0000
#define NOTIFICATION_EXTERNAL_REQUEST_QUEUE_OVERRUN 0x0001
#define NOTIFICATION_EXTERNAL_REQUEST_PLAY          0x0101
#define NOTIFICATION_EXTERNAL_REQUEST_REWIND_BACK   0x0102
#define NOTIFICATION_EXTERNAL_REQUEST_FAST_FORWARD  0x0103
#define NOTIFICATION_EXTERNAL_REQUEST_PAUSE         0x0104
#define NOTIFICATION_EXTERNAL_REQUEST_STOP          0x0106
#define NOTIFICATION_EXTERNAL_REQUEST_ASCII_LOW     0x0200
#define NOTIFICATION_EXTERNAL_REQUEST_ASCII_HIGH    0x02ff

#define NOTIFICATION_MEDIA_EVENT_NO_CHANGE          0x0
#define NOTIFICATION_MEDIA_EVENT_EJECT_REQUEST      0x1
#define NOTIFICATION_MEDIA_EVENT_NEW_MEDIA          0x2
#define NOTIFICATION_MEDIA_EVENT_MEDIA_REMOVAL      0x3
#define NOTIFICATION_MEDIA_EVENT_MEDIA_CHANGE       0x4

#define NOTIFICATION_BUSY_EVENT_NO_EVENT               0x0
#define NOTIFICATION_MULTI_HOST_EVENT_NO_CHANGE        0x0
#define NOTIFICATION_MULTI_HOST_EVENT_CONTROL_REQUEST  0x1
#define NOTIFICATION_MULTI_HOST_EVENT_CONTROL_GRANT    0x2
#define NOTIFICATION_MULTI_HOST_EVENT_CONTROL_RELEASE  0x3

#define NOTIFICATION_MULTI_HOST_STATUS_READY           0x0
#define NOTIFICATION_MULTI_HOST_STATUS_PREVENT         0x1

#define NOTIFICATION_MULTI_HOST_PRIORITY_NO_REQUESTS   0x0
#define NOTIFICATION_MULTI_HOST_PRIORITY_LOW           0x1
#define NOTIFICATION_MULTI_HOST_PRIORITY_MEDIUM        0x2
#define NOTIFICATION_MULTI_HOST_PRIORITY_HIGH          0x3

#define NOTIFICATION_BUSY_EVENT_NO_EVENT            0x0
#define NOTIFICATION_BUSY_EVENT_NO_CHANGE           0x0
#define NOTIFICATION_BUSY_EVENT_BUSY                0x1
#define NOTIFICATION_BUSY_EVENT_LO_CHANGE           0x2

#define NOTIFICATION_BUSY_STATUS_NO_EVENT           0x0
#define NOTIFICATION_BUSY_STATUS_POWER              0x1
#define NOTIFICATION_BUSY_STATUS_IMMEDIATE          0x2
#define NOTIFICATION_BUSY_STATUS_DEFERRED           0x3

#define SECURITY_PROTOCOL_IEEE1667  0xEE

#define DVD_FORMAT_LEAD_IN          0x00
#define DVD_FORMAT_COPYRIGHT        0x01
#define DVD_FORMAT_DISK_KEY         0x02
#define DVD_FORMAT_BCA              0x03
#define DVD_FORMAT_MANUFACTURING    0x04

#define DVD_REPORT_AGID            0x00
#define DVD_CHALLENGE_KEY          0x01
#define DVD_KEY_1                  0x02
#define DVD_KEY_2                  0x03
#define DVD_TITLE_KEY              0x04
#define DVD_REPORT_ASF             0x05
#define DVD_INVALIDATE_AGID        0x3F

#define BLANK_FULL              0x0
#define BLANK_MINIMAL           0x1
#define BLANK_TRACK             0x2
#define BLANK_UNRESERVE_TRACK   0x3
#define BLANK_TAIL              0x4
#define BLANK_UNCLOSE_SESSION   0x5
#define BLANK_SESSION           0x6

#define CD_EXPECTED_SECTOR_ANY          0x0
#define CD_EXPECTED_SECTOR_CDDA         0x1
#define CD_EXPECTED_SECTOR_MODE1        0x2
#define CD_EXPECTED_SECTOR_MODE2        0x3
#define CD_EXPECTED_SECTOR_MODE2_FORM1  0x4
#define CD_EXPECTED_SECTOR_MODE2_FORM2  0x5

#define DISK_STATUS_EMPTY       0x00
#define DISK_STATUS_INCOMPLETE  0x01
#define DISK_STATUS_COMPLETE    0x02
#define DISK_STATUS_OTHERS      0x03

#define LAST_SESSION_EMPTY              0x00
#define LAST_SESSION_INCOMPLETE         0x01
#define LAST_SESSION_RESERVED_DAMAGED   0x02
#define LAST_SESSION_COMPLETE           0x03

#define DISK_TYPE_CDDA          0x00
#define DISK_TYPE_CDI           0x10
#define DISK_TYPE_XA            0x20
#define DISK_TYPE_UNDEFINED     0xFF

#define DISC_BGFORMAT_STATE_NONE        0x0
#define DISC_BGFORMAT_STATE_INCOMPLETE  0x1
#define DISC_BGFORMAT_STATE_RUNNING     0x2
#define DISC_BGFORMAT_STATE_COMPLETE    0x3

#define DATA_BLOCK_MODE0    0x0
#define DATA_BLOCK_MODE1    0x1
#define DATA_BLOCK_MODE2    0x2

/* READ_TOC formats */
#define READ_TOC_FORMAT_TOC         0x00
#define READ_TOC_FORMAT_SESSION     0x01
#define READ_TOC_FORMAT_FULL_TOC    0x02
#define READ_TOC_FORMAT_PMA         0x03
#define READ_TOC_FORMAT_ATIP        0x04

#define CDB6GENERIC_LENGTH                   6
#define CDB10GENERIC_LENGTH                  10
#define CDB12GENERIC_LENGTH                  12

#define SETBITON                             1
#define SETBITOFF                            0

/* Mode Sense/Select page constants */
#define MODE_PAGE_VENDOR_SPECIFIC       0x00
#define MODE_PAGE_ERROR_RECOVERY        0x01
#define MODE_PAGE_DISCONNECT            0x02
#define MODE_PAGE_FORMAT_DEVICE         0x03
#define MODE_PAGE_MRW                   0x03
#define MODE_PAGE_RIGID_GEOMETRY        0x04
#define MODE_PAGE_FLEXIBILE             0x05
#define MODE_PAGE_WRITE_PARAMETERS      0x05
#define MODE_PAGE_VERIFY_ERROR          0x07
#define MODE_PAGE_CACHING               0x08
#define MODE_PAGE_PERIPHERAL            0x09
#define MODE_PAGE_CONTROL               0x0A
#define MODE_PAGE_MEDIUM_TYPES          0x0B
#define MODE_PAGE_NOTCH_PARTITION       0x0C
#define MODE_PAGE_CD_AUDIO_CONTROL      0x0E
#define MODE_PAGE_DATA_COMPRESS         0x0F
#define MODE_PAGE_DEVICE_CONFIG         0x10
#define MODE_PAGE_XOR_CONTROL           0x10
#define MODE_PAGE_MEDIUM_PARTITION      0x11
#define MODE_PAGE_ENCLOSURE_SERVICES_MANAGEMENT 0x14
#define MODE_PAGE_EXTENDED              0x15
#define MODE_PAGE_EXTENDED_DEVICE_SPECIFIC 0x16
#define MODE_PAGE_CDVD_FEATURE_SET      0x18
#define MODE_PAGE_PROTOCOL_SPECIFIC_LUN 0x18
#define MODE_PAGE_PROTOCOL_SPECIFIC_PORT 0x19
#define MODE_PAGE_POWER_CONDITION       0x1A
#define MODE_PAGE_LUN_MAPPING           0x1B
#define MODE_PAGE_FAULT_REPORTING       0x1C
#define MODE_PAGE_CDVD_INACTIVITY       0x1D
#define MODE_PAGE_ELEMENT_ADDRESS       0x1D
#define MODE_PAGE_TRANSPORT_GEOMETRY    0x1E
#define MODE_PAGE_DEVICE_CAPABILITIES   0x1F
#define MODE_PAGE_CAPABILITIES          0x2A

#define MODE_SENSE_RETURN_ALL           0x3f

#define MODE_SENSE_CURRENT_VALUES       0x00
#define MODE_SENSE_CHANGEABLE_VALUES    0x40
#define MODE_SENSE_DEFAULT_VAULES       0x80
#define MODE_SENSE_SAVED_VALUES         0xc0

/* SCSI CDB operation codes */
#define SCSIOP_TEST_UNIT_READY          0x00
#define SCSIOP_REZERO_UNIT              0x01
#define SCSIOP_REWIND                   0x01
#define SCSIOP_REQUEST_BLOCK_ADDR       0x02
#define SCSIOP_REQUEST_SENSE            0x03
#define SCSIOP_FORMAT_UNIT              0x04
#define SCSIOP_READ_BLOCK_LIMITS        0x05
#define SCSIOP_REASSIGN_BLOCKS          0x07
#define SCSIOP_INIT_ELEMENT_STATUS      0x07
#define SCSIOP_READ6                    0x08
#define SCSIOP_RECEIVE                  0x08
#define SCSIOP_WRITE6                   0x0A
#define SCSIOP_PRINT                    0x0A
#define SCSIOP_SEND                     0x0A
#define SCSIOP_SEEK6                    0x0B
#define SCSIOP_TRACK_SELECT             0x0B
#define SCSIOP_SLEW_PRINT               0x0B
#define SCSIOP_SET_CAPACITY             0x0B
#define SCSIOP_SEEK_BLOCK               0x0C
#define SCSIOP_PARTITION                0x0D
#define SCSIOP_READ_REVERSE             0x0F
#define SCSIOP_WRITE_FILEMARKS          0x10
#define SCSIOP_FLUSH_BUFFER             0x10
#define SCSIOP_SPACE                    0x11
#define SCSIOP_INQUIRY                  0x12
#define SCSIOP_VERIFY6                  0x13
#define SCSIOP_RECOVER_BUF_DATA         0x14
#define SCSIOP_MODE_SELECT              0x15
#define SCSIOP_RESERVE_UNIT             0x16
#define SCSIOP_RELEASE_UNIT             0x17
#define SCSIOP_COPY                     0x18
#define SCSIOP_ERASE                    0x19
#define SCSIOP_MODE_SENSE               0x1A
#define SCSIOP_START_STOP_UNIT          0x1B
#define SCSIOP_STOP_PRINT               0x1B
#define SCSIOP_LOAD_UNLOAD              0x1B
#define SCSIOP_RECEIVE_DIAGNOSTIC       0x1C
#define SCSIOP_SEND_DIAGNOSTIC          0x1D
#define SCSIOP_MEDIUM_REMOVAL           0x1E

#define SCSIOP_READ_FORMATTED_CAPACITY  0x23
#define SCSIOP_READ_CAPACITY            0x25
#define SCSIOP_READ                     0x28
#define SCSIOP_WRITE                    0x2A
#define SCSIOP_SEEK                     0x2B
#define SCSIOP_LOCATE                   0x2B
#define SCSIOP_POSITION_TO_ELEMENT      0x2B
#define SCSIOP_WRITE_VERIFY             0x2E
#define SCSIOP_VERIFY                   0x2F
#define SCSIOP_SEARCH_DATA_HIGH         0x30
#define SCSIOP_SEARCH_DATA_EQUAL        0x31
#define SCSIOP_SEARCH_DATA_LOW          0x32
#define SCSIOP_SET_LIMITS               0x33
#define SCSIOP_READ_POSITION            0x34
#define SCSIOP_SYNCHRONIZE_CACHE        0x35
#define SCSIOP_COMPARE                  0x39
#define SCSIOP_COPY_COMPARE             0x3A
#define SCSIOP_WRITE_DATA_BUFF          0x3B
#define SCSIOP_READ_DATA_BUFF           0x3C
#define SCSIOP_WRITE_LONG               0x3F
#define SCSIOP_CHANGE_DEFINITION        0x40
#define SCSIOP_WRITE_SAME               0x41
#define SCSIOP_READ_SUB_CHANNEL         0x42
#define SCSIOP_UNMAP                    0x42
#define SCSIOP_READ_TOC                 0x43
#define SCSIOP_READ_HEADER              0x44
#define SCSIOP_REPORT_DENSITY_SUPPORT   0x44
#define SCSIOP_PLAY_AUDIO               0x45
#define SCSIOP_GET_CONFIGURATION        0x46
#define SCSIOP_PLAY_AUDIO_MSF           0x47
#define SCSIOP_PLAY_TRACK_INDEX         0x48
#define SCSIOP_SANITIZE                 0x48
#define SCSIOP_PLAY_TRACK_RELATIVE      0x49
#define SCSIOP_GET_EVENT_STATUS         0x4A
#define SCSIOP_PAUSE_RESUME             0x4B
#define SCSIOP_LOG_SELECT               0x4C
#define SCSIOP_LOG_SENSE                0x4D
#define SCSIOP_STOP_PLAY_SCAN           0x4E
#define SCSIOP_XDWRITE                  0x50
#define SCSIOP_XPWRITE                  0x51
#define SCSIOP_READ_DISK_INFORMATION    0x51
#define SCSIOP_READ_DISC_INFORMATION    0x51
#define SCSIOP_READ_TRACK_INFORMATION   0x52
#define SCSIOP_XDWRITE_READ             0x53
#define SCSIOP_RESERVE_TRACK_RZONE      0x53
#define SCSIOP_SEND_OPC_INFORMATION     0x54
#define SCSIOP_MODE_SELECT10            0x55
#define SCSIOP_RESERVE_UNIT10           0x56
#define SCSIOP_RESERVE_ELEMENT          0x56
#define SCSIOP_RELEASE_UNIT10           0x57
#define SCSIOP_RELEASE_ELEMENT          0x57
#define SCSIOP_REPAIR_TRACK             0x58
#define SCSIOP_MODE_SENSE10             0x5A
#define SCSIOP_CLOSE_TRACK_SESSION      0x5B
#define SCSIOP_READ_BUFFER_CAPACITY     0x5C
#define SCSIOP_SEND_CUE_SHEET           0x5D
#define SCSIOP_PERSISTENT_RESERVE_IN    0x5E
#define SCSIOP_PERSISTENT_RESERVE_OUT   0x5F

#define SCSIOP_REPORT_LUNS              0xA0
#define SCSIOP_BLANK                    0xA1
#define SCSIOP_ATA_PASSTHROUGH12        0xA1
#define SCSIOP_SEND_EVENT               0xA2
#define SCSIOP_SECURITY_PROTOCOL_IN     0xA2
#define SCSIOP_SEND_KEY                 0xA3
#define SCSIOP_MAINTENANCE_IN           0xA3
#define SCSIOP_REPORT_KEY               0xA4
#define SCSIOP_MAINTENANCE_OUT          0xA4
#define SCSIOP_MOVE_MEDIUM              0xA5
#define SCSIOP_LOAD_UNLOAD_SLOT         0xA6
#define SCSIOP_EXCHANGE_MEDIUM          0xA6
#define SCSIOP_SET_READ_AHEAD           0xA7
#define SCSIOP_MOVE_MEDIUM_ATTACHED     0xA7
#define SCSIOP_READ12                   0xA8
#define SCSIOP_GET_MESSAGE              0xA8
#define SCSIOP_SERVICE_ACTION_OUT12     0xA9
#define SCSIOP_WRITE12                  0xAA
#define SCSIOP_SEND_MESSAGE             0xAB
#define SCSIOP_SERVICE_ACTION_IN12      0xAB
#define SCSIOP_GET_PERFORMANCE          0xAC
#define SCSIOP_READ_DVD_STRUCTURE       0xAD
#define SCSIOP_WRITE_VERIFY12           0xAE
#define SCSIOP_VERIFY12                 0xAF
#define SCSIOP_SEARCH_DATA_HIGH12       0xB0
#define SCSIOP_SEARCH_DATA_EQUAL12      0xB1
#define SCSIOP_SEARCH_DATA_LOW12        0xB2
#define SCSIOP_SET_LIMITS12             0xB3
#define SCSIOP_READ_ELEMENT_STATUS_ATTACHED 0xB4
#define SCSIOP_REQUEST_VOL_ELEMENT      0xB5
#define SCSIOP_SECURITY_PROTOCOL_OUT    0xB5
#define SCSIOP_SEND_VOLUME_TAG          0xB6
#define SCSIOP_SET_STREAMING            0xB6
#define SCSIOP_READ_DEFECT_DATA         0xB7
#define SCSIOP_READ_ELEMENT_STATUS      0xB8
#define SCSIOP_READ_CD_MSF              0xB9
#define SCSIOP_SCAN_CD                  0xBA
#define SCSIOP_REDUNDANCY_GROUP_IN      0xBA
#define SCSIOP_SET_CD_SPEED             0xBB
#define SCSIOP_REDUNDANCY_GROUP_OUT     0xBB
#define SCSIOP_PLAY_CD                  0xBC
#define SCSIOP_SPARE_IN                 0xBC
#define SCSIOP_MECHANISM_STATUS         0xBD
#define SCSIOP_SPARE_OUT                0xBD
#define SCSIOP_READ_CD                  0xBE
#define SCSIOP_VOLUME_SET_IN            0xBE
#define SCSIOP_SEND_DVD_STRUCTURE       0xBF
#define SCSIOP_VOLUME_SET_OUT           0xBF
#define SCSIOP_INIT_ELEMENT_RANGE       0xE7

#define SCSIOP_XDWRITE_EXTENDED16       0x80
#define SCSIOP_WRITE_FILEMARKS16        0x80
#define SCSIOP_REBUILD16                0x81
#define SCSIOP_READ_REVERSE16           0x81
#define SCSIOP_REGENERATE16             0x82
#define SCSIOP_EXTENDED_COPY            0x83
#define SCSIOP_POPULATE_TOKEN           0x83
#define SCSIOP_WRITE_USING_TOKEN        0x83
#define SCSIOP_RECEIVE_COPY_RESULTS     0x84
#define SCSIOP_RECEIVE_ROD_TOKEN_INFORMATION 0x84
#define SCSIOP_ATA_PASSTHROUGH16        0x85
#define SCSIOP_ACCESS_CONTROL_IN        0x86
#define SCSIOP_ACCESS_CONTROL_OUT       0x87
#define SCSIOP_READ16                   0x88
#define SCSIOP_COMPARE_AND_WRITE        0x89
#define SCSIOP_WRITE16                  0x8A
#define SCSIOP_READ_ATTRIBUTES          0x8C
#define SCSIOP_WRITE_ATTRIBUTES         0x8D
#define SCSIOP_WRITE_VERIFY16           0x8E
#define SCSIOP_VERIFY16                 0x8F
#define SCSIOP_PREFETCH16               0x90
#define SCSIOP_SYNCHRONIZE_CACHE16      0x91
#define SCSIOP_SPACE16                  0x91
#define SCSIOP_LOCK_UNLOCK_CACHE16      0x92
#define SCSIOP_LOCATE16                 0x92
#define SCSIOP_WRITE_SAME16             0x93
#define SCSIOP_ERASE16                  0x93
#define SCSIOP_ZBC_OUT                  0x94
#define SCSIOP_ZBC_IN                   0x95
#define SCSIOP_READ_DATA_BUFF16         0x9B
#define SCSIOP_READ_CAPACITY16          0x9E
#define SCSIOP_GET_LBA_STATUS           0x9E
#define SCSIOP_GET_PHYSICAL_ELEMENT_STATUS 0x9E
#define SCSIOP_REMOVE_ELEMENT_AND_TRUNCATE 0x9E
#define SCSIOP_SERVICE_ACTION_IN16      0x9E
#define SCSIOP_SERVICE_ACTION_OUT16     0x9F

#define SCSIOP_OPERATION32              0x7F

#define SERVICE_ACTION_OVERWRITE        0x01
#define SERVICE_ACTION_BLOCK_ERASE      0x02
#define SERVICE_ACTION_CRYPTO_ERASE     0x03
#define SERVICE_ACTION_EXIT_FAILURE     0x1f

#define SERVICE_ACTION_XDWRITE          0x0004
#define SERVICE_ACTION_XPWRITE          0x0006
#define SERVICE_ACTION_XDWRITEREAD      0x0007
#define SERVICE_ACTION_WRITE            0x000B
#define SERVICE_ACTION_WRITE_VERIFY     0x000C
#define SERVICE_ACTION_WRITE_SAME       0x000D
#define SERVICE_ACTION_ORWRITE          0x000E

#define SERVICE_ACTION_POPULATE_TOKEN     0x10
#define SERVICE_ACTION_WRITE_USING_TOKEN 0x11

#define SERVICE_ACTION_RECEIVE_TOKEN_INFORMATION 0x07

#define SERVICE_ACTION_CLOSE_ZONE           0x01
#define SERVICE_ACTION_FINISH_ZONE          0x02
#define SERVICE_ACTION_OPEN_ZONE            0x03
#define SERVICE_ACTION_RESET_WRITE_POINTER  0x04

#define SERVICE_ACTION_REPORT_ZONES         0x00

#define REPORT_ZONES_OPTION_LIST_ALL_ZONES               0x00
#define REPORT_ZONES_OPTION_LIST_EMPTY_ZONES             0x01
#define REPORT_ZONES_OPTION_LIST_IMPLICITLY_OPENED_ZONES 0x02
#define REPORT_ZONES_OPTION_LIST_EXPLICITLY_OPENED_ZONES 0x03
#define REPORT_ZONES_OPTION_LIST_CLOSED_ZONES            0x04
#define REPORT_ZONES_OPTION_LIST_FULL_ZONES              0x05
#define REPORT_ZONES_OPTION_LIST_READ_ONLY_ZONES         0x06
#define REPORT_ZONES_OPTION_LIST_OFFLINE_ZONES           0x07
#define REPORT_ZONES_OPTION_LIST_RWP_ZONES               0x10
#define REPORT_ZONES_OPTION_LIST_NON_SEQUENTIAL_WRITE_RESOURCES_ACTIVE_ZONES 0x11
#define REPORT_ZONES_OPTION_LIST_NOT_WRITE_POINTER_ZONES 0x3F

#define SERVICE_ACTION_READ_CAPACITY16              0x10
#define SERVICE_ACTION_GET_LBA_STATUS               0x12
#define SERVICE_ACTION_GET_PHYSICAL_ELEMENT_STATUS  0x17
#define SERVICE_ACTION_REMOVE_ELEMENT_AND_TRUNCATE  0x18
#define SERVICE_ACTION_REPORT_TIMESTAMP             0x0F
#define SERVICE_ACTION_SET_TIMESTAMP                0x0F

#define CDB_RETURN_ON_COMPLETION   0
#define CDB_RETURN_IMMEDIATE       1

#define CDB_FORCE_MEDIA_ACCESS 0x08

#define SCSIOP_DENON_EJECT_DISC    0xE6
#define SCSIOP_DENON_STOP_AUDIO    0xE7
#define SCSIOP_DENON_PLAY_AUDIO    0xE8
#define SCSIOP_DENON_READ_TOC      0xE9
#define SCSIOP_DENON_READ_SUBCODE  0xEB

#define SCSIMESS_ABORT                0x06
#define SCSIMESS_ABORT_WITH_TAG       0x0D
#define SCSIMESS_BUS_DEVICE_RESET     0X0C
#define SCSIMESS_CLEAR_QUEUE          0X0E
#define SCSIMESS_COMMAND_COMPLETE     0X00
#define SCSIMESS_DISCONNECT           0X04
#define SCSIMESS_EXTENDED_MESSAGE     0X01
#define SCSIMESS_IDENTIFY             0X80
#define SCSIMESS_IDENTIFY_WITH_DISCON 0XC0
#define SCSIMESS_IGNORE_WIDE_RESIDUE  0X23
#define SCSIMESS_INITIATE_RECOVERY    0X0F
#define SCSIMESS_INIT_DETECTED_ERROR  0X05
#define SCSIMESS_LINK_CMD_COMP        0X0A
#define SCSIMESS_LINK_CMD_COMP_W_FLAG 0X0B
#define SCSIMESS_MESS_PARITY_ERROR    0X09
#define SCSIMESS_MESSAGE_REJECT       0X07
#define SCSIMESS_NO_OPERATION         0X08
#define SCSIMESS_HEAD_OF_QUEUE_TAG    0X21
#define SCSIMESS_ORDERED_QUEUE_TAG    0X22
#define SCSIMESS_SIMPLE_QUEUE_TAG     0X20
#define SCSIMESS_RELEASE_RECOVERY     0X10
#define SCSIMESS_RESTORE_POINTERS     0X03
#define SCSIMESS_SAVE_DATA_POINTER    0X02
#define SCSIMESS_TERMINATE_IO_PROCESS 0X11

#define SCSIMESS_MODIFY_DATA_POINTER  0X00
#define SCSIMESS_SYNCHRONOUS_DATA_REQ 0X01
#define SCSIMESS_WIDE_DATA_REQUEST    0X03

#define SCSIMESS_MODIFY_DATA_LENGTH   5
#define SCSIMESS_SYNCH_DATA_LENGTH    3
#define SCSIMESS_WIDE_DATA_LENGTH     2

#define CDB_INQUIRY_EVPD           0x01

#define LUN0_FORMAT_SAVING_DEFECT_LIST 0
#define USE_DEFAULTMSB 0
#define USE_DEFAULTLSB 0

#define START_UNIT_CODE 0x01
#define STOP_UNIT_CODE 0x00

#define OFFSET_VER_DESCRIPTOR_ONE (FIELD_OFFSET(INQUIRYDATA, VersionDescriptors[0]))
#define OFFSET_VER_DESCRIPTOR_EIGHT (FIELD_OFFSET(INQUIRYDATA, VersionDescriptors[8]))

/* INQUIRYDATA.DeviceType constants */
#define DIRECT_ACCESS_DEVICE              0x00
#define SEQUENTIAL_ACCESS_DEVICE          0x01
#define PRINTER_DEVICE                    0x02
#define PROCESSOR_DEVICE                  0x03
#define WRITE_ONCE_READ_MULTIPLE_DEVICE   0x04
#define READ_ONLY_DIRECT_ACCESS_DEVICE    0x05
#define SCANNER_DEVICE                    0x06
#define OPTICAL_DEVICE                    0x07
#define MEDIUM_CHANGER                    0x08
#define COMMUNICATION_DEVICE              0x09
#define ARRAY_CONTROLLER_DEVICE           0x0C
#define SCSI_ENCLOSURE_DEVICE             0x0D
#define REDUCED_BLOCK_DEVICE              0x0E
#define OPTICAL_CARD_READER_WRITER_DEVICE 0x0F
#define BRIDGE_CONTROLLER_DEVICE          0x10
#define OBJECT_BASED_STORAGE_DEVICE       0x11
#define HOST_MANAGED_ZONED_BLOCK_DEVICE   0x14
#define UNKNOWN_OR_NO_DEVICE              0x1F
#define LOGICAL_UNIT_NOT_PRESENT_DEVICE   0x7F

#define DEVICE_QUALIFIER_ACTIVE           0x00
#define DEVICE_QUALIFIER_NOT_ACTIVE       0x01
#define DEVICE_QUALIFIER_NOT_SUPPORTED    0x03

/* INQUIRYDATA.DeviceTypeQualifier constants */
#define DEVICE_CONNECTED 0x00

#define SCSISTAT_GOOD                     0x00
#define SCSISTAT_CHECK_CONDITION          0x02
#define SCSISTAT_CONDITION_MET            0x04
#define SCSISTAT_BUSY                     0x08
#define SCSISTAT_INTERMEDIATE             0x10
#define SCSISTAT_INTERMEDIATE_COND_MET    0x14
#define SCSISTAT_RESERVATION_CONFLICT     0x18
#define SCSISTAT_COMMAND_TERMINATED       0x22
#define SCSISTAT_QUEUE_FULL               0x28

#define VPD_MAX_BUFFER_SIZE                 0xff

#define VPD_SUPPORTED_PAGES                 0x00
#define VPD_SERIAL_NUMBER                   0x80
#define VPD_DEVICE_IDENTIFIERS              0x83
#define VPD_MEDIA_SERIAL_NUMBER             0x84
#define VPD_SOFTWARE_INTERFACE_IDENTIFIERS  0x84
#define VPD_NETWORK_MANAGEMENT_ADDRESSES    0x85
#define VPD_EXTENDED_INQUIRY_DATA           0x86
#define VPD_MODE_PAGE_POLICY                0x87
#define VPD_SCSI_PORTS                      0x88

#define RESERVATION_ACTION_READ_KEYS                    0x00
#define RESERVATION_ACTION_READ_RESERVATIONS            0x01

#define RESERVATION_ACTION_REGISTER                     0x00
#define RESERVATION_ACTION_RESERVE                      0x01
#define RESERVATION_ACTION_RELEASE                      0x02
#define RESERVATION_ACTION_CLEAR                        0x03
#define RESERVATION_ACTION_PREEMPT                      0x04
#define RESERVATION_ACTION_PREEMPT_ABORT                0x05
#define RESERVATION_ACTION_REGISTER_IGNORE_EXISTING     0x06

#define RESERVATION_SCOPE_LU                            0x00
#define RESERVATION_SCOPE_ELEMENT                       0x02

#define RESERVATION_TYPE_WRITE_EXCLUSIVE                0x01
#define RESERVATION_TYPE_EXCLUSIVE                      0x03
#define RESERVATION_TYPE_WRITE_EXCLUSIVE_REGISTRANTS    0x05
#define RESERVATION_TYPE_EXCLUSIVE_REGISTRANTS          0x06

#define SENSE_BUFFER_SIZE              18

#define MAX_SENSE_BUFFER_SIZE          255

#define MAX_ADDITIONAL_SENSE_BYTES (MAX_SENSE_BUFFER_SIZE - SENSE_BUFFER_SIZE)

/* Sense codes */
#define SCSI_SENSE_NO_SENSE               0x00
#define SCSI_SENSE_RECOVERED_ERROR        0x01
#define SCSI_SENSE_NOT_READY              0x02
#define SCSI_SENSE_MEDIUM_ERROR           0x03
#define SCSI_SENSE_HARDWARE_ERROR         0x04
#define SCSI_SENSE_ILLEGAL_REQUEST        0x05
#define SCSI_SENSE_UNIT_ATTENTION         0x06
#define SCSI_SENSE_DATA_PROTECT           0x07
#define SCSI_SENSE_BLANK_CHECK            0x08
#define SCSI_SENSE_UNIQUE                 0x09
#define SCSI_SENSE_COPY_ABORTED           0x0A
#define SCSI_SENSE_ABORTED_COMMAND        0x0B
#define SCSI_SENSE_EQUAL                  0x0C
#define SCSI_SENSE_VOL_OVERFLOW           0x0D
#define SCSI_SENSE_MISCOMPARE             0x0E
#define SCSI_SENSE_RESERVED               0x0F

/* Additional tape bit */
#define SCSI_ILLEGAL_LENGTH               0x20
#define SCSI_EOM                          0x40
#define SCSI_FILE_MARK                    0x80

/* Additional Sense codes */
#define SCSI_ADSENSE_NO_SENSE                              0x00
#define SCSI_ADSENSE_NO_SEEK_COMPLETE                      0x02
#define SCSI_ADSENSE_LUN_NOT_READY                         0x04
#define SCSI_ADSENSE_LUN_COMMUNICATION                     0x08
#define SCSI_ADSENSE_WRITE_ERROR                           0x0C
#define SCSI_ADSENSE_TRACK_ERROR                           0x14
#define SCSI_ADSENSE_SEEK_ERROR                            0x15
#define SCSI_ADSENSE_REC_DATA_NOECC                        0x17
#define SCSI_ADSENSE_REC_DATA_ECC                          0x18
#define SCSI_ADSENSE_PARAMETER_LIST_LENGTH                 0x1A
#define SCSI_ADSENSE_ILLEGAL_COMMAND                       0x20
#define SCSI_ADSENSE_ILLEGAL_BLOCK                         0x21
#define SCSI_ADSENSE_INVALID_CDB                           0x24
#define SCSI_ADSENSE_INVALID_LUN                           0x25
#define SCSI_ADSENSE_INVALID_FIELD_PARAMETER_LIST          0x26
#define SCSI_ADSENSE_WRITE_PROTECT                         0x27
#define SCSI_ADSENSE_MEDIUM_CHANGED                        0x28
#define SCSI_ADSENSE_BUS_RESET                             0x29
#define SCSI_ADSENSE_PARAMETERS_CHANGED                    0x2A
#define SCSI_ADSENSE_INSUFFICIENT_TIME_FOR_OPERATION       0x2E
#define SCSI_ADSENSE_INVALID_MEDIA                         0x30
#define SCSI_ADSENSE_NO_MEDIA_IN_DEVICE                    0x3a
#define SCSI_ADSENSE_POSITION_ERROR                        0x3b
#define SCSI_ADSENSE_OPERATING_CONDITIONS_CHANGED          0x3f
#define SCSI_ADSENSE_OPERATOR_REQUEST                      0x5a
#define SCSI_ADSENSE_FAILURE_PREDICTION_THRESHOLD_EXCEEDED 0x5d
#define SCSI_ADSENSE_ILLEGAL_MODE_FOR_THIS_TRACK           0x64
#define SCSI_ADSENSE_COPY_PROTECTION_FAILURE               0x6f
#define SCSI_ADSENSE_POWER_CALIBRATION_ERROR               0x73
#define SCSI_ADSENSE_VENDOR_UNIQUE                         0x80
#define SCSI_ADSENSE_MUSIC_AREA                            0xA0
#define SCSI_ADSENSE_DATA_AREA                             0xA1
#define SCSI_ADSENSE_VOLUME_OVERFLOW                       0xA7

#define SCSI_ADWRITE_PROTECT                        SCSI_ADSENSE_WRITE_PROTECT
#define SCSI_FAILURE_PREDICTION_THRESHOLD_EXCEEDED  SCSI_ADSENSE_FAILURE_PREDICTION_THRESHOLD_EXCEEDED

#define SCSI_SENSEQ_CAUSE_NOT_REPORTABLE                   0x00
#define SCSI_SENSEQ_BECOMING_READY                         0x01
#define SCSI_SENSEQ_INIT_COMMAND_REQUIRED                  0x02
#define SCSI_SENSEQ_MANUAL_INTERVENTION_REQUIRED           0x03
#define SCSI_SENSEQ_FORMAT_IN_PROGRESS                     0x04
#define SCSI_SENSEQ_REBUILD_IN_PROGRESS                    0x05
#define SCSI_SENSEQ_RECALCULATION_IN_PROGRESS              0x06
#define SCSI_SENSEQ_OPERATION_IN_PROGRESS                  0x07
#define SCSI_SENSEQ_LONG_WRITE_IN_PROGRESS                 0x08
#define SCSI_SENSEQ_LOSS_OF_STREAMING                      0x09
#define SCSI_SENSEQ_PADDING_BLOCKS_ADDED                   0x0A

#define SCSI_SENSEQ_COMM_FAILURE                 0x00
#define SCSI_SENSEQ_COMM_TIMEOUT                 0x01
#define SCSI_SENSEQ_COMM_PARITY_ERROR            0x02
#define SCSI_SESNEQ_COMM_CRC_ERROR               0x03
#define SCSI_SENSEQ_UNREACHABLE_TARGET           0x04

#define SCSI_SENSEQ_FILEMARK_DETECTED 0x01
#define SCSI_SENSEQ_END_OF_MEDIA_DETECTED 0x02
#define SCSI_SENSEQ_SETMARK_DETECTED 0x03
#define SCSI_SENSEQ_BEGINNING_OF_MEDIA_DETECTED 0x04

#define SCSI_SENSEQ_ILLEGAL_ELEMENT_ADDR 0x01

#define SCSI_SENSEQ_DESTINATION_FULL 0x0d
#define SCSI_SENSEQ_SOURCE_EMPTY     0x0e

#define SCSI_SENSEQ_INCOMPATIBLE_MEDIA_INSTALLED 0x00
#define SCSI_SENSEQ_UNKNOWN_FORMAT 0x01
#define SCSI_SENSEQ_INCOMPATIBLE_FORMAT 0x02
#define SCSI_SENSEQ_CLEANING_CARTRIDGE_INSTALLED 0x03

#define SCSI_SENSEQ_TARGET_OPERATING_CONDITIONS_CHANGED 0x00
#define SCSI_SENSEQ_MICROCODE_CHANGED                   0x01
#define SCSI_SENSEQ_OPERATING_DEFINITION_CHANGED        0x02
#define SCSI_SENSEQ_INQUIRY_DATA_CHANGED                0x03
#define SCSI_SENSEQ_COMPONENT_DEVICE_ATTACHED           0x04
#define SCSI_SENSEQ_DEVICE_IDENTIFIER_CHANGED           0x05
#define SCSI_SENSEQ_REDUNDANCY_GROUP_MODIFIED           0x06
#define SCSI_SENSEQ_REDUNDANCY_GROUP_DELETED            0x07
#define SCSI_SENSEQ_SPARE_MODIFIED                      0x08
#define SCSI_SENSEQ_SPARE_DELETED                       0x09
#define SCSI_SENSEQ_VOLUME_SET_MODIFIED                 0x0A
#define SCSI_SENSEQ_VOLUME_SET_DELETED                  0x0B
#define SCSI_SENSEQ_VOLUME_SET_DEASSIGNED               0x0C
#define SCSI_SENSEQ_VOLUME_SET_REASSIGNED               0x0D
#define SCSI_SENSEQ_REPORTED_LUNS_DATA_CHANGED          0x0E
#define SCSI_SENSEQ_ECHO_BUFFER_OVERWRITTEN             0x0F
#define SCSI_SENSEQ_MEDIUM_LOADABLE                     0x10
#define SCSI_SENSEQ_MEDIUM_AUXILIARY_MEMORY_ACCESSIBLE  0x11

#define SCSI_SENSEQ_STATE_CHANGE_INPUT     0x00
#define SCSI_SENSEQ_MEDIUM_REMOVAL         0x01
#define SCSI_SENSEQ_WRITE_PROTECT_ENABLE   0x02
#define SCSI_SENSEQ_WRITE_PROTECT_DISABLE  0x03

#define SCSI_SENSEQ_AUTHENTICATION_FAILURE                          0x00
#define SCSI_SENSEQ_KEY_NOT_PRESENT                                 0x01
#define SCSI_SENSEQ_KEY_NOT_ESTABLISHED                             0x02
#define SCSI_SENSEQ_READ_OF_SCRAMBLED_SECTOR_WITHOUT_AUTHENTICATION 0x03
#define SCSI_SENSEQ_MEDIA_CODE_MISMATCHED_TO_LOGICAL_UNIT           0x04
#define SCSI_SENSEQ_LOGICAL_UNIT_RESET_COUNT_ERROR                  0x05

#define SCSI_SENSEQ_POWER_CALIBRATION_AREA_ALMOST_FULL 0x01
#define SCSI_SENSEQ_POWER_CALIBRATION_AREA_FULL        0x02
#define SCSI_SENSEQ_POWER_CALIBRATION_AREA_ERROR       0x03
#define SCSI_SENSEQ_PMA_RMA_UPDATE_FAILURE             0x04
#define SCSI_SENSEQ_PMA_RMA_IS_FULL                    0x05
#define SCSI_SENSEQ_PMA_RMA_ALMOST_FULL                0x06

#define FILE_DEVICE_SCSI 0x0000001b

#define IOCTL_SCSI_EXECUTE_IN ((FILE_DEVICE_SCSI << 16) + 0x0011)
#define IOCTL_SCSI_EXECUTE_OUT ((FILE_DEVICE_SCSI << 16) + 0x0012)
#define IOCTL_SCSI_EXECUTE_NONE ((FILE_DEVICE_SCSI << 16) + 0x0013)

/* SMART support in ATAPI */
#define IOCTL_SCSI_MINIPORT_SMART_VERSION               ((FILE_DEVICE_SCSI << 16) + 0x0500)
#define IOCTL_SCSI_MINIPORT_IDENTIFY                    ((FILE_DEVICE_SCSI << 16) + 0x0501)
#define IOCTL_SCSI_MINIPORT_READ_SMART_ATTRIBS          ((FILE_DEVICE_SCSI << 16) + 0x0502)
#define IOCTL_SCSI_MINIPORT_READ_SMART_THRESHOLDS       ((FILE_DEVICE_SCSI << 16) + 0x0503)
#define IOCTL_SCSI_MINIPORT_ENABLE_SMART                ((FILE_DEVICE_SCSI << 16) + 0x0504)
#define IOCTL_SCSI_MINIPORT_DISABLE_SMART               ((FILE_DEVICE_SCSI << 16) + 0x0505)
#define IOCTL_SCSI_MINIPORT_RETURN_STATUS               ((FILE_DEVICE_SCSI << 16) + 0x0506)
#define IOCTL_SCSI_MINIPORT_ENABLE_DISABLE_AUTOSAVE     ((FILE_DEVICE_SCSI << 16) + 0x0507)
#define IOCTL_SCSI_MINIPORT_SAVE_ATTRIBUTE_VALUES       ((FILE_DEVICE_SCSI << 16) + 0x0508)
#define IOCTL_SCSI_MINIPORT_EXECUTE_OFFLINE_DIAGS       ((FILE_DEVICE_SCSI << 16) + 0x0509)
#define IOCTL_SCSI_MINIPORT_ENABLE_DISABLE_AUTO_OFFLINE ((FILE_DEVICE_SCSI << 16) + 0x050a)
#define IOCTL_SCSI_MINIPORT_READ_SMART_LOG              ((FILE_DEVICE_SCSI << 16) + 0x050b)
#define IOCTL_SCSI_MINIPORT_WRITE_SMART_LOG             ((FILE_DEVICE_SCSI << 16) + 0x050c)

/* CLUSTER support */
#define IOCTL_SCSI_MINIPORT_NOT_QUORUM_CAPABLE ((FILE_DEVICE_SCSI << 16) + 0x0520)
#define IOCTL_SCSI_MINIPORT_NOT_CLUSTER_CAPABLE ((FILE_DEVICE_SCSI << 16) + 0x0521)

#define MODE_FD_SINGLE_SIDE               0x01
#define MODE_FD_DOUBLE_SIDE               0x02
#define MODE_FD_MAXIMUM_TYPE              0x1E
#define MODE_DSP_FUA_SUPPORTED            0x10
#define MODE_DSP_WRITE_PROTECT            0x80

#define CDDA_CHANNEL_MUTED      0x0
#define CDDA_CHANNEL_ZERO       0x1
#define CDDA_CHANNEL_ONE        0x2
#define CDDA_CHANNEL_TWO        0x4
#define CDDA_CHANNEL_THREE      0x8

#define CDVD_LMT_CADDY              0
#define CDVD_LMT_TRAY               1
#define CDVD_LMT_POPUP              2
#define CDVD_LMT_RESERVED1          3
#define CDVD_LMT_CHANGER_INDIVIDUAL 4
#define CDVD_LMT_CHANGER_CARTRIDGE  5
#define CDVD_LMT_RESERVED2          6
#define CDVD_LMT_RESERVED3          7

#define LOADING_MECHANISM_CADDY                 0x00
#define LOADING_MECHANISM_TRAY                  0x01
#define LOADING_MECHANISM_POPUP                 0x02
#define LOADING_MECHANISM_INDIVIDUAL_CHANGER    0x04
#define LOADING_MECHANISM_CARTRIDGE_CHANGER     0x05

#define MODE_BLOCK_DESC_LENGTH        8
#define MODE_HEADER_LENGTH            4
#define MODE_HEADER_LENGTH10          8

/* CDROM audio control */
#define CDB_AUDIO_PAUSE                   0x00
#define CDB_AUDIO_RESUME                  0x01
#define CDB_DEVICE_START                  0x11
#define CDB_DEVICE_STOP                   0x10
#define CDB_EJECT_MEDIA                   0x10
#define CDB_LOAD_MEDIA                    0x01
#define CDB_SUBCHANNEL_HEADER             0x00
#define CDB_SUBCHANNEL_BLOCK              0x01

#define CDROM_AUDIO_CONTROL_PAGE          0x0E
#define MODE_SELECT_IMMEDIATE             0x04
#define MODE_SELECT_PFBIT                 0x10

#define CDB_USE_MSF                       0x01

/* Multisession CDROMs */
#define GET_LAST_SESSION 0x01
#define GET_SESSION_DATA 0x02

typedef union _CDB {
  struct _CDB6GENERIC {
    UCHAR OperationCode;
    UCHAR Immediate:1;
    UCHAR CommandUniqueBits:4;
    UCHAR LogicalUnitNumber:3;
    UCHAR CommandUniqueBytes[3];
    UCHAR Link:1;
    UCHAR Flag:1;
    UCHAR Reserved:4;
    UCHAR VendorUnique:2;
  } CDB6GENERIC;
  struct _CDB6READWRITE {
    UCHAR OperationCode;
    UCHAR LogicalBlockMsb1:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR LogicalBlockMsb0;
    UCHAR LogicalBlockLsb;
    UCHAR TransferBlocks;
    UCHAR Control;
  } CDB6READWRITE;
  struct _CDB6INQUIRY {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR PageCode;
    UCHAR IReserved;
    UCHAR AllocationLength;
    UCHAR Control;
  } CDB6INQUIRY;
  struct _CDB6INQUIRY3 {
    UCHAR OperationCode;
    UCHAR EnableVitalProductData:1;
    UCHAR CommandSupportData:1;
    UCHAR Reserved1:6;
    UCHAR PageCode;
    UCHAR Reserved2;
    UCHAR AllocationLength;
    UCHAR Control;
  } CDB6INQUIRY3;
  struct _CDB6VERIFY {
    UCHAR OperationCode;
    UCHAR Fixed:1;
    UCHAR ByteCompare:1;
    UCHAR Immediate:1;
    UCHAR Reserved:2;
    UCHAR LogicalUnitNumber:3;
    UCHAR VerificationLength[3];
    UCHAR Control;
  } CDB6VERIFY;
  struct _RECEIVE_DIAGNOSTIC {
    UCHAR OperationCode;
    UCHAR PageCodeValid:1;
    UCHAR Reserved:7;
    UCHAR PageCode;
    UCHAR AllocationLength[2];
    UCHAR Control;
  } RECEIVE_DIAGNOSTIC;
  struct _SEND_DIAGNOSTIC {
    UCHAR OperationCode;
    UCHAR UnitOffline:1;
    UCHAR DeviceOffline:1;
    UCHAR SelfTest:1;
    UCHAR Reserved1:1;
    UCHAR PageFormat:1;
    UCHAR SelfTestCode:3;
    UCHAR Reserved2;
    UCHAR ParameterListLength[2];
    UCHAR Control;
  } SEND_DIAGNOSTIC;
  struct _CDB6FORMAT {
    UCHAR OperationCode;
    UCHAR FormatControl:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR FReserved1;
    UCHAR InterleaveMsb;
    UCHAR InterleaveLsb;
    UCHAR FReserved2;
  } CDB6FORMAT;
  struct _CDB10 {
    UCHAR OperationCode;
    UCHAR RelativeAddress:1;
    UCHAR Reserved1:2;
    UCHAR ForceUnitAccess:1;
    UCHAR DisablePageOut:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR LogicalBlockByte0;
    UCHAR LogicalBlockByte1;
    UCHAR LogicalBlockByte2;
    UCHAR LogicalBlockByte3;
    UCHAR Reserved2;
    UCHAR TransferBlocksMsb;
    UCHAR TransferBlocksLsb;
    UCHAR Control;
  } CDB10;
  struct _CDB12 {
    UCHAR OperationCode;
    UCHAR RelativeAddress:1;
    UCHAR Reserved1:2;
    UCHAR ForceUnitAccess:1;
    UCHAR DisablePageOut:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR LogicalBlock[4];
    UCHAR TransferLength[4];
    UCHAR Reserved2;
    UCHAR Control;
  } CDB12;
  struct _CDB16 {
     UCHAR OperationCode;
     UCHAR Reserved1:3;
     UCHAR ForceUnitAccess:1;
     UCHAR DisablePageOut:1;
     UCHAR Protection:3;
     UCHAR LogicalBlock[8];
     UCHAR TransferLength[4];
     UCHAR Reserved2;
     UCHAR Control;
  } CDB16;
  struct _READ_BUFFER_10 {
    UCHAR OperationCode;
    UCHAR Mode:5;
    UCHAR ModeSpecific:3;
    UCHAR BufferId;
    UCHAR BufferOffset[3];
    UCHAR AllocationLength[3];
    UCHAR Control;
  } READ_BUFFER_10;
  struct _READ_BUFFER_16 {
    UCHAR OperationCode;
    UCHAR Mode:5;
    UCHAR ModeSpecific:3;
    UCHAR BufferOffset[8];
    UCHAR AllocationLength[4];
    UCHAR BufferId;
    UCHAR Control;
  } READ_BUFFER_16;
  struct _SECURITY_PROTOCOL_IN {
    UCHAR OperationCode;
    UCHAR SecurityProtocol;
    UCHAR SecurityProtocolSpecific[2];
    UCHAR Reserved1:7;
    UCHAR INC_512:1;
    UCHAR Reserved2;
    UCHAR AllocationLength[4];
    UCHAR Reserved3;
    UCHAR Control;
  } SECURITY_PROTOCOL_IN;
  struct _SECURITY_PROTOCOL_OUT {
    UCHAR OperationCode;
    UCHAR SecurityProtocol;
    UCHAR SecurityProtocolSpecific[2];
    UCHAR Reserved1:7;
    UCHAR INC_512:1;
    UCHAR Reserved2;
    UCHAR AllocationLength[4];
    UCHAR Reserved3;
    UCHAR Control;
  } SECURITY_PROTOCOL_OUT;
  struct _UNMAP {
    UCHAR OperationCode;
    UCHAR Anchor:1;
    UCHAR Reserved1:7;
    UCHAR Reserved2[4];
    UCHAR GroupNumber:5;
    UCHAR Reserved3:3;
    UCHAR AllocationLength[2];
    UCHAR Control;
  } UNMAP;
  struct _SANITIZE {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR AUSE:1;
    UCHAR Reserved1:1;
    UCHAR Immediate:1;
    UCHAR Reserved2[5];
    UCHAR ParameterListLength[2];
    UCHAR Control;
  } SANITIZE;
  struct _PAUSE_RESUME {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR Reserved2[6];
    UCHAR Action;
    UCHAR Control;
  } PAUSE_RESUME;
  struct _READ_TOC {
    UCHAR OperationCode;
    UCHAR Reserved0:1;
    UCHAR Msf:1;
    UCHAR Reserved1:3;
    UCHAR LogicalUnitNumber:3;
    UCHAR Format2:4;
    UCHAR Reserved2:4;
    UCHAR Reserved3[3];
    UCHAR StartingTrack;
    UCHAR AllocationLength[2];
    UCHAR Control:6;
    UCHAR Format:2;
  } READ_TOC;
  struct _READ_DISK_INFORMATION {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR Lun:3;
    UCHAR Reserved2[5];
    UCHAR AllocationLength[2];
    UCHAR Control;
  } READ_DISK_INFORMATION;
  struct _READ_TRACK_INFORMATION {
    UCHAR OperationCode;
    UCHAR Track:2;
    UCHAR Reserved4:3;
    UCHAR Lun:3;
    UCHAR BlockAddress[4];
    UCHAR Reserved3;
    UCHAR AllocationLength[2];
    UCHAR Control;
  } READ_TRACK_INFORMATION;
  struct _RESERVE_TRACK_RZONE {
    UCHAR OperationCode;
    UCHAR Reserved1[4];
    UCHAR ReservationSize[4];
    UCHAR Control;
  } RESERVE_TRACK_RZONE;
  struct _SEND_OPC_INFORMATION {
    UCHAR OperationCode;
    UCHAR DoOpc:1;
    UCHAR Reserved1:7;
    UCHAR Exclude0:1;
    UCHAR Exclude1:1;
    UCHAR Reserved2:6;
    UCHAR Reserved3[4];
    UCHAR ParameterListLength[2];
    UCHAR Reserved4;
  } SEND_OPC_INFORMATION;
  struct _REPAIR_TRACK {
    UCHAR OperationCode;
    UCHAR Immediate:1;
    UCHAR Reserved1:7;
    UCHAR Reserved2[2];
    UCHAR TrackNumber[2];
    UCHAR Reserved3[3];
    UCHAR Control;
  } REPAIR_TRACK;
  struct _CLOSE_TRACK {
    UCHAR OperationCode;
    UCHAR Immediate:1;
    UCHAR Reserved1:7;
    UCHAR Track:1;
    UCHAR Session:1;
    UCHAR Reserved2:6;
    UCHAR Reserved3;
    UCHAR TrackNumber[2];
    UCHAR Reserved4[3];
    UCHAR Control;
  } CLOSE_TRACK;
  struct _READ_BUFFER_CAPACITY {
    UCHAR OperationCode;
    UCHAR BlockInfo:1;
    UCHAR Reserved1:7;
    UCHAR Reserved2[5];
    UCHAR AllocationLength[2];
    UCHAR Control;
  } READ_BUFFER_CAPACITY;
  struct _SEND_CUE_SHEET {
    UCHAR OperationCode;
    UCHAR Reserved[5];
    UCHAR CueSheetSize[3];
    UCHAR Control;
  } SEND_CUE_SHEET;
  struct _READ_HEADER {
    UCHAR OperationCode;
    UCHAR Reserved1:1;
    UCHAR Msf:1;
    UCHAR Reserved2:3;
    UCHAR Lun:3;
    UCHAR LogicalBlockAddress[4];
    UCHAR Reserved3;
    UCHAR AllocationLength[2];
    UCHAR Control;
  } READ_HEADER;
  struct _PLAY_AUDIO {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR StartingBlockAddress[4];
    UCHAR Reserved2;
    UCHAR PlayLength[2];
    UCHAR Control;
  } PLAY_AUDIO;
  struct _PLAY_AUDIO_MSF {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR Reserved2;
    UCHAR StartingM;
    UCHAR StartingS;
    UCHAR StartingF;
    UCHAR EndingM;
    UCHAR EndingS;
    UCHAR EndingF;
    UCHAR Control;
  } PLAY_AUDIO_MSF;
  struct _BLANK_MEDIA {
    UCHAR OperationCode;
    UCHAR BlankType:3;
    UCHAR Reserved1:1;
    UCHAR Immediate:1;
    UCHAR Reserved2:3;
    UCHAR AddressOrTrack[4];
    UCHAR Reserved3[5];
    UCHAR Control;
  } BLANK_MEDIA;
  struct _PLAY_CD {
    UCHAR OperationCode;
    UCHAR Reserved1:1;
    UCHAR CMSF:1;
    UCHAR ExpectedSectorType:3;
    UCHAR Lun:3;
    _ANONYMOUS_UNION union {
      struct {
        UCHAR StartingBlockAddress[4];
        UCHAR PlayLength[4];
      } LBA;
      struct {
        UCHAR Reserved1;
        UCHAR StartingM;
        UCHAR StartingS;
        UCHAR StartingF;
        UCHAR EndingM;
        UCHAR EndingS;
        UCHAR EndingF;
        UCHAR Reserved2;
      } MSF;
    };
    UCHAR Audio:1;
    UCHAR Composite:1;
    UCHAR Port1:1;
    UCHAR Port2:1;
    UCHAR Reserved2:3;
    UCHAR Speed:1;
    UCHAR Control;
  } PLAY_CD;
  struct _SCAN_CD {
    UCHAR OperationCode;
    UCHAR RelativeAddress:1;
    UCHAR Reserved1:3;
    UCHAR Direct:1;
    UCHAR Lun:3;
    UCHAR StartingAddress[4];
    UCHAR Reserved2[3];
    UCHAR Reserved3:6;
    UCHAR Type:2;
    UCHAR Reserved4;
    UCHAR Control;
  } SCAN_CD;
  struct _STOP_PLAY_SCAN {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR Lun:3;
    UCHAR Reserved2[7];
    UCHAR Control;
  } STOP_PLAY_SCAN;
  struct _SUBCHANNEL {
    UCHAR OperationCode;
    UCHAR Reserved0:1;
    UCHAR Msf:1;
    UCHAR Reserved1:3;
    UCHAR LogicalUnitNumber:3;
    UCHAR Reserved2:6;
    UCHAR SubQ:1;
    UCHAR Reserved3:1;
    UCHAR Format;
    UCHAR Reserved4[2];
    UCHAR TrackNumber;
    UCHAR AllocationLength[2];
    UCHAR Control;
  } SUBCHANNEL;
  struct _READ_CD {
    UCHAR OperationCode;
    UCHAR RelativeAddress:1;
    UCHAR Reserved0:1;
    UCHAR ExpectedSectorType:3;
    UCHAR Lun:3;
    UCHAR StartingLBA[4];
    UCHAR TransferBlocks[3];
    UCHAR Reserved2:1;
    UCHAR ErrorFlags:2;
    UCHAR IncludeEDC:1;
    UCHAR IncludeUserData:1;
    UCHAR HeaderCode:2;
    UCHAR IncludeSyncData:1;
    UCHAR SubChannelSelection:3;
    UCHAR Reserved3:5;
    UCHAR Control;
  } READ_CD;
  struct _READ_CD_MSF {
    UCHAR OperationCode;
    UCHAR RelativeAddress:1;
    UCHAR Reserved1:1;
    UCHAR ExpectedSectorType:3;
    UCHAR Lun:3;
    UCHAR Reserved2;
    UCHAR StartingM;
    UCHAR StartingS;
    UCHAR StartingF;
    UCHAR EndingM;
    UCHAR EndingS;
    UCHAR EndingF;
    UCHAR Reserved3;
    UCHAR Reserved4:1;
    UCHAR ErrorFlags:2;
    UCHAR IncludeEDC:1;
    UCHAR IncludeUserData:1;
    UCHAR HeaderCode:2;
    UCHAR IncludeSyncData:1;
    UCHAR SubChannelSelection:3;
    UCHAR Reserved5:5;
    UCHAR Control;
  } READ_CD_MSF;
  struct _PLXTR_READ_CDDA {
    UCHAR OperationCode;
    UCHAR Reserved0:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR LogicalBlockByte0;
    UCHAR LogicalBlockByte1;
    UCHAR LogicalBlockByte2;
    UCHAR LogicalBlockByte3;
    UCHAR TransferBlockByte0;
    UCHAR TransferBlockByte1;
    UCHAR TransferBlockByte2;
    UCHAR TransferBlockByte3;
    UCHAR SubCode;
    UCHAR Control;
  } PLXTR_READ_CDDA;
  struct _NEC_READ_CDDA {
    UCHAR OperationCode;
    UCHAR Reserved0;
    UCHAR LogicalBlockByte0;
    UCHAR LogicalBlockByte1;
    UCHAR LogicalBlockByte2;
    UCHAR LogicalBlockByte3;
    UCHAR Reserved1;
    UCHAR TransferBlockByte0;
    UCHAR TransferBlockByte1;
    UCHAR Control;
  } NEC_READ_CDDA;
#if NTDDI_VERSION >= NTDDI_WIN8
  struct _MODE_SENSE {
    UCHAR OperationCode;
    UCHAR Reserved1:3;
    UCHAR Dbd:1;
    UCHAR Reserved2:4;
    UCHAR PageCode:6;
    UCHAR Pc:2;
    UCHAR SubPageCode;
    UCHAR AllocationLength;
    UCHAR Control;
  } MODE_SENSE;
  struct _MODE_SENSE10 {
    UCHAR OperationCode;
    UCHAR Reserved1:3;
    UCHAR Dbd:1;
    UCHAR LongLBAAccepted:1;
    UCHAR Reserved2:3;
    UCHAR PageCode:6;
    UCHAR Pc:2;
    UCHAR SubPageCode;
    UCHAR Reserved3[3];
    UCHAR AllocationLength[2];
    UCHAR Control;
  } MODE_SENSE10;
#else
    struct _MODE_SENSE {
    UCHAR OperationCode;
    UCHAR Reserved1:3;
    UCHAR Dbd:1;
    UCHAR Reserved2:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR PageCode:6;
    UCHAR Pc:2;
    UCHAR Reserved3;
    UCHAR AllocationLength;
    UCHAR Control;
  } MODE_SENSE;
  struct _MODE_SENSE10 {
    UCHAR OperationCode;
    UCHAR Reserved1:3;
    UCHAR Dbd:1;
    UCHAR Reserved2:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR PageCode:6;
    UCHAR Pc:2;
    UCHAR Reserved3[4];
    UCHAR AllocationLength[2];
    UCHAR Control;
  } MODE_SENSE10;
#endif /* NTDDI_VERSION >= NTDDI_WIN8 */
  struct _MODE_SELECT {
    UCHAR OperationCode;
    UCHAR SPBit:1;
    UCHAR Reserved1:3;
    UCHAR PFBit:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR Reserved2[2];
    UCHAR ParameterListLength;
    UCHAR Control;
  } MODE_SELECT;
  struct _MODE_SELECT10 {
    UCHAR OperationCode;
    UCHAR SPBit:1;
    UCHAR Reserved1:3;
    UCHAR PFBit:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR Reserved2[5];
    UCHAR ParameterListLength[2];
    UCHAR Control;
  } MODE_SELECT10;
  struct _LOCATE {
    UCHAR OperationCode;
    UCHAR Immediate:1;
    UCHAR CPBit:1;
    UCHAR BTBit:1;
    UCHAR Reserved1:2;
    UCHAR LogicalUnitNumber:3;
    UCHAR Reserved3;
    UCHAR LogicalBlockAddress[4];
    UCHAR Reserved4;
    UCHAR Partition;
    UCHAR Control;
  } LOCATE;
  struct _LOGSENSE {
    UCHAR OperationCode;
    UCHAR SPBit:1;
    UCHAR PPCBit:1;
    UCHAR Reserved1:3;
    UCHAR LogicalUnitNumber:3;
    UCHAR PageCode:6;
    UCHAR PCBit:2;
    _ANONYMOUS_UNION union {
      UCHAR SubPageCode;
      UCHAR Reserved2;
    };
    UCHAR Reserved3;
    UCHAR ParameterPointer[2];
    UCHAR AllocationLength[2];
    UCHAR Control;
  } LOGSENSE;
  struct _LOGSELECT {
    UCHAR OperationCode;
    UCHAR SPBit:1;
    UCHAR PCRBit:1;
    UCHAR Reserved1:3;
    UCHAR LogicalUnitNumber:3;
    UCHAR Reserved:6;
    UCHAR PCBit:2;
    UCHAR Reserved2[4];
    UCHAR ParameterListLength[2];
    UCHAR Control;
  } LOGSELECT;
  struct _PRINT {
    UCHAR OperationCode;
    UCHAR Reserved:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR TransferLength[3];
    UCHAR Control;
  } PRINT;
  struct _SEEK {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR LogicalBlockAddress[4];
    UCHAR Reserved2[3];
    UCHAR Control;
  } SEEK;
  struct _ERASE {
    UCHAR OperationCode;
    UCHAR Long:1;
    UCHAR Immediate:1;
    UCHAR Reserved1:3;
    UCHAR LogicalUnitNumber:3;
    UCHAR Reserved2[3];
    UCHAR Control;
  } ERASE;
  struct _START_STOP {
    UCHAR OperationCode;
    UCHAR Immediate:1;
    UCHAR Reserved1:4;
    UCHAR LogicalUnitNumber:3;
    UCHAR Reserved2[2];
    UCHAR Start:1;
    UCHAR LoadEject:1;
    UCHAR Reserved3:6;
    UCHAR Control;
  } START_STOP;
  struct _MEDIA_REMOVAL {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR Reserved2[2];
    UCHAR Prevent:1;
    UCHAR Persistant:1;
    UCHAR Reserved3:6;
    UCHAR Control;
  } MEDIA_REMOVAL;
  struct _SEEK_BLOCK {
    UCHAR OperationCode;
    UCHAR Immediate:1;
    UCHAR Reserved1:7;
    UCHAR BlockAddress[3];
    UCHAR Link:1;
    UCHAR Flag:1;
    UCHAR Reserved2:4;
    UCHAR VendorUnique:2;
  } SEEK_BLOCK;
  struct _REQUEST_BLOCK_ADDRESS {
    UCHAR OperationCode;
    UCHAR Reserved1[3];
    UCHAR AllocationLength;
    UCHAR Link:1;
    UCHAR Flag:1;
    UCHAR Reserved2:4;
    UCHAR VendorUnique:2;
  } REQUEST_BLOCK_ADDRESS;
  struct _PARTITION {
    UCHAR OperationCode;
    UCHAR Immediate:1;
    UCHAR Sel:1;
    UCHAR PartitionSelect:6;
    UCHAR Reserved1[3];
    UCHAR Control;
  } PARTITION;
  struct _WRITE_TAPE_MARKS {
    UCHAR OperationCode;
    UCHAR Immediate:1;
    UCHAR WriteSetMarks:1;
    UCHAR Reserved:3;
    UCHAR LogicalUnitNumber:3;
    UCHAR TransferLength[3];
    UCHAR Control;
  } WRITE_TAPE_MARKS;
  struct _SPACE_TAPE_MARKS {
    UCHAR OperationCode;
    UCHAR Code:3;
    UCHAR Reserved:2;
    UCHAR LogicalUnitNumber:3;
    UCHAR NumMarksMSB;
    UCHAR NumMarks;
    UCHAR NumMarksLSB;
  union {
    UCHAR value;
    struct {
      UCHAR Link:1;
      UCHAR Flag:1;
      UCHAR Reserved:4;
      UCHAR VendorUnique:2;
    } Fields;
  } Byte6;
  } SPACE_TAPE_MARKS;
  struct _READ_POSITION {
    UCHAR Operation;
    UCHAR BlockType:1;
    UCHAR Reserved1:4;
    UCHAR Lun:3;
    UCHAR Reserved2[7];
    UCHAR Control;
  } READ_POSITION;
  struct _CDB6READWRITETAPE {
    UCHAR OperationCode;
    UCHAR VendorSpecific:5;
    UCHAR Reserved:3;
    UCHAR TransferLenMSB;
    UCHAR TransferLen;
    UCHAR TransferLenLSB;
    UCHAR Link:1;
    UCHAR Flag:1;
    UCHAR Reserved1:4;
    UCHAR VendorUnique:2;
  } CDB6READWRITETAPE;
  struct _INIT_ELEMENT_STATUS {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR LogicalUnitNubmer:3;
    UCHAR Reserved2[3];
    UCHAR Reserved3:7;
    UCHAR NoBarCode:1;
  } INIT_ELEMENT_STATUS;
  struct _INITIALIZE_ELEMENT_RANGE {
    UCHAR OperationCode;
    UCHAR Range:1;
    UCHAR Reserved1:4;
    UCHAR LogicalUnitNubmer:3;
    UCHAR FirstElementAddress[2];
    UCHAR Reserved2[2];
    UCHAR NumberOfElements[2];
    UCHAR Reserved3;
    UCHAR Reserved4:7;
    UCHAR NoBarCode:1;
  } INITIALIZE_ELEMENT_RANGE;
  struct _POSITION_TO_ELEMENT {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR TransportElementAddress[2];
    UCHAR DestinationElementAddress[2];
    UCHAR Reserved2[2];
    UCHAR Flip:1;
    UCHAR Reserved3:7;
    UCHAR Control;
  } POSITION_TO_ELEMENT;
  struct _MOVE_MEDIUM {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR TransportElementAddress[2];
    UCHAR SourceElementAddress[2];
    UCHAR DestinationElementAddress[2];
    UCHAR Reserved2[2];
    UCHAR Flip:1;
    UCHAR Reserved3:7;
    UCHAR Control;
  } MOVE_MEDIUM;
  struct _EXCHANGE_MEDIUM {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR LogicalUnitNumber:3;
    UCHAR TransportElementAddress[2];
    UCHAR SourceElementAddress[2];
    UCHAR Destination1ElementAddress[2];
    UCHAR Destination2ElementAddress[2];
    UCHAR Flip1:1;
    UCHAR Flip2:1;
    UCHAR Reserved3:6;
    UCHAR Control;
  } EXCHANGE_MEDIUM;
  struct _READ_ELEMENT_STATUS {
    UCHAR OperationCode;
    UCHAR ElementType:4;
    UCHAR VolTag:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR StartingElementAddress[2];
    UCHAR NumberOfElements[2];
    UCHAR Reserved1;
    UCHAR AllocationLength[3];
    UCHAR Reserved2;
    UCHAR Control;
  } READ_ELEMENT_STATUS;
  struct _SEND_VOLUME_TAG {
    UCHAR OperationCode;
    UCHAR ElementType:4;
    UCHAR Reserved1:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR StartingElementAddress[2];
    UCHAR Reserved2;
    UCHAR ActionCode:5;
    UCHAR Reserved3:3;
    UCHAR Reserved4[2];
    UCHAR ParameterListLength[2];
    UCHAR Reserved5;
    UCHAR Control;
  } SEND_VOLUME_TAG;
  struct _REQUEST_VOLUME_ELEMENT_ADDRESS {
    UCHAR OperationCode;
    UCHAR ElementType:4;
    UCHAR VolTag:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR StartingElementAddress[2];
    UCHAR NumberElements[2];
    UCHAR Reserved1;
    UCHAR AllocationLength[3];
    UCHAR Reserved2;
    UCHAR Control;
  } REQUEST_VOLUME_ELEMENT_ADDRESS;
  struct _LOAD_UNLOAD {
    UCHAR OperationCode;
    UCHAR Immediate:1;
    UCHAR Reserved1:4;
    UCHAR Lun:3;
    UCHAR Reserved2[2];
    UCHAR Start:1;
    UCHAR LoadEject:1;
    UCHAR Reserved3:6;
    UCHAR Reserved4[3];
    UCHAR Slot;
    UCHAR Reserved5[3];
  } LOAD_UNLOAD;
  struct _MECH_STATUS {
    UCHAR OperationCode;
    UCHAR Reserved:5;
    UCHAR Lun:3;
    UCHAR Reserved1[6];
    UCHAR AllocationLength[2];
    UCHAR Reserved2[1];
    UCHAR Control;
  } MECH_STATUS;
  struct _SYNCHRONIZE_CACHE10 {
    UCHAR OperationCode;
    UCHAR RelAddr:1;
    UCHAR Immediate:1;
    UCHAR Reserved:3;
    UCHAR Lun:3;
    UCHAR LogicalBlockAddress[4];
    UCHAR Reserved2;
    UCHAR BlockCount[2];
    UCHAR Control;
  } SYNCHRONIZE_CACHE10;
  struct _GET_EVENT_STATUS_NOTIFICATION {
    UCHAR OperationCode;
    UCHAR Immediate:1;
    UCHAR Reserved:4;
    UCHAR Lun:3;
    UCHAR Reserved2[2];
    UCHAR NotificationClassRequest;
    UCHAR Reserved3[2];
    UCHAR EventListLength[2];
    UCHAR Control;
  } GET_EVENT_STATUS_NOTIFICATION;
  struct _GET_PERFORMANCE {
    UCHAR OperationCode;
    UCHAR Except:2;
    UCHAR Write:1;
    UCHAR Tolerance:2;
    UCHAR Reserved0:3;
    UCHAR StartingLBA[4];
    UCHAR Reserved1[2];
    UCHAR MaximumNumberOfDescriptors[2];
    UCHAR Type;
    UCHAR Control;
  } GET_PERFORMANCE;
  struct _READ_DVD_STRUCTURE {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR Lun:3;
    UCHAR RMDBlockNumber[4];
    UCHAR LayerNumber;
    UCHAR Format;
    UCHAR AllocationLength[2];
    UCHAR Reserved3:6;
    UCHAR AGID:2;
    UCHAR Control;
  } READ_DVD_STRUCTURE;
  struct _SET_STREAMING {
    UCHAR OperationCode;
    UCHAR Reserved[8];
    UCHAR ParameterListLength[2];
    UCHAR Control;
  } SET_STREAMING;
  struct _SEND_DVD_STRUCTURE {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR Lun:3;
    UCHAR Reserved2[5];
    UCHAR Format;
    UCHAR ParameterListLength[2];
    UCHAR Reserved3;
    UCHAR Control;
  } SEND_DVD_STRUCTURE;
  struct _SEND_KEY {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR Lun:3;
    UCHAR Reserved2[6];
    UCHAR ParameterListLength[2];
    UCHAR KeyFormat:6;
    UCHAR AGID:2;
    UCHAR Control;
  } SEND_KEY;
  struct _REPORT_KEY {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR Lun:3;
    UCHAR LogicalBlockAddress[4];
    UCHAR Reserved2[2];
    UCHAR AllocationLength[2];
    UCHAR KeyFormat:6;
    UCHAR AGID:2;
    UCHAR Control;
  } REPORT_KEY;
  struct _SET_READ_AHEAD {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR Lun:3;
    UCHAR TriggerLBA[4];
    UCHAR ReadAheadLBA[4];
    UCHAR Reserved2;
    UCHAR Control;
  } SET_READ_AHEAD;
  struct _READ_FORMATTED_CAPACITIES {
    UCHAR OperationCode;
    UCHAR Reserved1:5;
    UCHAR Lun:3;
    UCHAR Reserved2[5];
    UCHAR AllocationLength[2];
    UCHAR Control;
  } READ_FORMATTED_CAPACITIES;
  struct _REPORT_LUNS {
    UCHAR OperationCode;
    UCHAR Reserved1[5];
    UCHAR AllocationLength[4];
    UCHAR Reserved2[1];
    UCHAR Control;
  } REPORT_LUNS;
  struct _PERSISTENT_RESERVE_IN {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR Reserved2[5];
    UCHAR AllocationLength[2];
    UCHAR Control;
  } PERSISTENT_RESERVE_IN;
  struct _PERSISTENT_RESERVE_OUT {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR Type:4;
    UCHAR Scope:4;
    UCHAR Reserved2[4];
    UCHAR ParameterListLength[2];
    UCHAR Control;
  } PERSISTENT_RESERVE_OUT;
  struct _REPORT_TIMESTAMP {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR Reserved2[4];
    UCHAR AllocationLength[4];
    UCHAR Reserved3;
    UCHAR Control;
  } REPORT_TIMESTAMP;
  struct _SET_TIMESTAMP {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR Reserved2[4];
    UCHAR ParameterListLength[4];
    UCHAR Reserved3;
    UCHAR Control;
  } SET_TIMESTAMP;
  struct _GET_CONFIGURATION {
    UCHAR OperationCode;
    UCHAR RequestType:2;
    UCHAR Reserved1:6;
    UCHAR StartingFeature[2];
    UCHAR Reserved2[3];
    UCHAR AllocationLength[2];
    UCHAR Control;
  } GET_CONFIGURATION;
  struct _SET_CD_SPEED {
    UCHAR OperationCode;
    _ANONYMOUS_UNION union {
      UCHAR Reserved1;
      _ANONYMOUS_STRUCT struct {
        UCHAR RotationControl:2;
        UCHAR Reserved3:6;
      } DUMMYSTRUCTNAME;
    } DUMMYUNIONNAME;
    UCHAR ReadSpeed[2];
    UCHAR WriteSpeed[2];
    UCHAR Reserved2[5];
    UCHAR Control;
  } SET_CD_SPEED;
  struct _READ12 {
    UCHAR OperationCode;
    UCHAR RelativeAddress:1;
    UCHAR Reserved1:2;
    UCHAR ForceUnitAccess:1;
    UCHAR DisablePageOut:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR LogicalBlock[4];
    UCHAR TransferLength[4];
    UCHAR Reserved2:7;
    UCHAR Streaming:1;
    UCHAR Control;
  } READ12;
  struct _WRITE12 {
    UCHAR OperationCode;
    UCHAR RelativeAddress:1;
    UCHAR Reserved1:1;
    UCHAR EBP:1;
    UCHAR ForceUnitAccess:1;
    UCHAR DisablePageOut:1;
    UCHAR LogicalUnitNumber:3;
    UCHAR LogicalBlock[4];
    UCHAR TransferLength[4];
    UCHAR Reserved2:7;
    UCHAR Streaming:1;
    UCHAR Control;
  } WRITE12;
  struct _ATA_PASSTHROUGH12 {
    UCHAR OperationCode;
    UCHAR Reserved1:1;
    UCHAR Protocol:4;
    UCHAR MultipleCount:3;
    UCHAR TLength:2;
    UCHAR ByteBlock:1;
    UCHAR TDir:1;
    UCHAR Reserved2:1;
    UCHAR CkCond:1;
    UCHAR Offline:2;
    UCHAR Features;
    UCHAR SectorCount;
    UCHAR LbaLow;
    UCHAR LbaMid;
    UCHAR LbaHigh;
    UCHAR Device;
    UCHAR Command;
    UCHAR Reserved3;
    UCHAR Control;
  } ATA_PASSTHROUGH12;
  struct _READ16 {
    UCHAR OperationCode;
    UCHAR Reserved1:3;
    UCHAR ForceUnitAccess:1;
    UCHAR DisablePageOut:1;
    UCHAR ReadProtect:3;
    UCHAR LogicalBlock[8];
    UCHAR TransferLength[4];
    UCHAR Reserved2:7;
    UCHAR Streaming:1;
    UCHAR Control;
  } READ16;
  struct _WRITE16 {
    UCHAR OperationCode;
    UCHAR Reserved1:3;
    UCHAR ForceUnitAccess:1;
    UCHAR DisablePageOut:1;
    UCHAR WriteProtect:3;
    UCHAR LogicalBlock[8];
    UCHAR TransferLength[4];
    UCHAR Reserved2:7;
    UCHAR Streaming:1;
    UCHAR Control;
  } WRITE16;
  struct _VERIFY16 {
    UCHAR OperationCode;
    UCHAR Reserved1:1;
    UCHAR ByteCheck:1;
    UCHAR BlockVerify:1;
    UCHAR Reserved2: 1;
    UCHAR DisablePageOut:1;
    UCHAR VerifyProtect:3;
    UCHAR LogicalBlock[8];
    UCHAR VerificationLength[4];
    UCHAR Reserved3:7;
    UCHAR Streaming:1;
    UCHAR Control;
  } VERIFY16;
  struct _SYNCHRONIZE_CACHE16 {
    UCHAR OperationCode;
    UCHAR Reserved1:1;
    UCHAR Immediate:1;
    UCHAR Reserved2:6;
    UCHAR LogicalBlock[8];
    UCHAR BlockCount[4];
    UCHAR Reserved3;
    UCHAR Control;
  } SYNCHRONIZE_CACHE16;
  struct _READ_CAPACITY16 {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR LogicalBlock[8];
    UCHAR BlockCount[4];
    UCHAR PMI:1;
    UCHAR Reserved2:7;
    UCHAR Control;
  } READ_CAPACITY16;
  struct _ATA_PASSTHROUGH16 {
    UCHAR OperationCode;
    UCHAR Extend:1;
    UCHAR Protocol:4;
    UCHAR MultipleCount:3;
    UCHAR TLength:2;
    UCHAR ByteBlock:1;
    UCHAR TDir:1;
    UCHAR Reserved1:1;
    UCHAR CkCond:1;
    UCHAR Offline:2;
    UCHAR Features15_8;
    UCHAR Features7_0;
    UCHAR SectorCount15_8;
    UCHAR SectorCount7_0;
    UCHAR LbaLow15_8;
    UCHAR LbaLow7_0;
    UCHAR LbaMid15_8;
    UCHAR LbaMid7_0;
    UCHAR LbaHigh15_8;
    UCHAR LbaHigh7_0;
    UCHAR Device;
    UCHAR Command;
    UCHAR Control;
  } ATA_PASSTHROUGH16;
  struct _GET_LBA_STATUS {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR StartingLBA[8];
    UCHAR AllocationLength[4];
    UCHAR Reserved2;
    UCHAR Control;
  } GET_LBA_STATUS;
  struct _TOKEN_OPERATION {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR Reserved2[4];
    UCHAR ListIdentifier[4];
    UCHAR ParameterListLength[4];
    UCHAR GroupNumber: 5;
    UCHAR Reserved3: 3;
    UCHAR Control;
  } TOKEN_OPERATION;
  struct _RECEIVE_TOKEN_INFORMATION {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR ListIdentifier[4];
    UCHAR Reserved2[4];
    UCHAR AllocationLength[4];
    UCHAR Reserved3;
    UCHAR Control;
  } RECEIVE_TOKEN_INFORMATION;
  struct _WRITE_BUFFER {
    UCHAR OperationCode;
    UCHAR Mode:5;
    UCHAR ModeSpecific:3;
    UCHAR BufferID;
    UCHAR BufferOffset[3];
    UCHAR ParameterListLength[3];
    UCHAR Control;
  } WRITE_BUFFER;
  struct _CLOSE_ZONE {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR ZoneId[8];
    UCHAR Reserved2[4];
    UCHAR All:1;
    UCHAR Reserved3:7;
    UCHAR Control;
  } CLOSE_ZONE;
  struct _FINISH_ZONE {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR ZoneId[8];
    UCHAR Reserved2[4];
    UCHAR All:1;
    UCHAR Reserved3:7;
    UCHAR Control;
  } FINISH_ZONE;
  struct _OPEN_ZONE {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR ZoneId[8];
    UCHAR Reserved2[4];
    UCHAR All:1;
    UCHAR Reserved3:7;
    UCHAR Control;
  } OPEN_ZONE;
  struct _RESET_WRITE_POINTER {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR ZoneId[8];
    UCHAR Reserved2[4];
    UCHAR All:1;
    UCHAR Reserved3:7;
    UCHAR Control;
  } RESET_WRITE_POINTER;
  struct _REPORT_ZONES {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR ZoneStartLBA[8];
    UCHAR AllocationLength[4];
    UCHAR ReportingOptions:6;
    UCHAR Reserved3:1;
    UCHAR Partial:1;
    UCHAR Control;
  } REPORT_ZONES;
  struct _GET_PHYSICAL_ELEMENT_STATUS {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR Reserved2[4];
    UCHAR StartingElement[4];
    UCHAR AllocationLength[4];
    UCHAR ReportType:4;
    UCHAR Reserved3:2;
    UCHAR Filter:2;
    UCHAR Control;
  } GET_PHYSICAL_ELEMENT_STATUS;
  struct _REMOVE_ELEMENT_AND_TRUNCATE {
    UCHAR OperationCode;
    UCHAR ServiceAction:5;
    UCHAR Reserved1:3;
    UCHAR RequestedCapacity[8];
    UCHAR ElementIdentifier[4];
    UCHAR Reserved2;
    UCHAR Control;
  } REMOVE_ELEMENT_AND_TRUNCATE;
  ULONG AsUlong[4];
  UCHAR AsByte[16];
} CDB, *PCDB;

typedef struct _NOTIFICATION_EVENT_STATUS_HEADER {
  UCHAR EventDataLength[2];
  UCHAR NotificationClass:3;
  UCHAR Reserved:4;
  UCHAR NEA:1;
  UCHAR SupportedEventClasses;
  UCHAR ClassEventData[0];
} NOTIFICATION_EVENT_STATUS_HEADER, *PNOTIFICATION_EVENT_STATUS_HEADER;

typedef struct _NOTIFICATION_OPERATIONAL_STATUS {
  UCHAR OperationalEvent:4;
  UCHAR Reserved1:4;
  UCHAR OperationalStatus:4;
  UCHAR Reserved2:3;
  UCHAR PersistentPrevented:1;
  UCHAR Operation[2];
} NOTIFICATION_OPERATIONAL_STATUS, *PNOTIFICATION_OPERATIONAL_STATUS;

typedef struct _NOTIFICATION_POWER_STATUS {
  UCHAR PowerEvent:4;
  UCHAR Reserved:4;
  UCHAR PowerStatus;
  UCHAR Reserved2[2];
} NOTIFICATION_POWER_STATUS, *PNOTIFICATION_POWER_STATUS;

typedef struct _NOTIFICATION_EXTERNAL_STATUS {
  UCHAR ExternalEvent:4;
  UCHAR Reserved1:4;
  UCHAR ExternalStatus:4;
  UCHAR Reserved2:3;
  UCHAR PersistentPrevented:1;
  UCHAR Request[2];
} NOTIFICATION_EXTERNAL_STATUS, *PNOTIFICATION_EXTERNAL_STATUS;

typedef struct _NOTIFICATION_MEDIA_STATUS {
  UCHAR MediaEvent:4;
  UCHAR Reserved:4;
  _ANONYMOUS_UNION union {
    UCHAR PowerStatus;
    UCHAR MediaStatus;
    _ANONYMOUS_STRUCT struct {
      UCHAR DoorTrayOpen:1;
      UCHAR MediaPresent:1;
      UCHAR ReservedX:6;
    } DUMMYSTRUCTNAME;
  } DUMMYUNIONNAME;
  UCHAR StartSlot;
  UCHAR EndSlot;
} NOTIFICATION_MEDIA_STATUS, *PNOTIFICATION_MEDIA_STATUS;

typedef struct _NOTIFICATION_MULTI_HOST_STATUS {
  UCHAR MultiHostEvent:4;
  UCHAR Reserved1:4;
  UCHAR MultiHostStatus:4;
  UCHAR Reserved2:3;
  UCHAR PersistentPrevented:1;
  UCHAR Priority[2];
} NOTIFICATION_MULTI_HOST_STATUS, *PNOTIFICATION_MULTI_HOST_STATUS;

typedef struct _NOTIFICATION_BUSY_STATUS {
  UCHAR DeviceBusyEvent:4;
  UCHAR Reserved:4;
  UCHAR DeviceBusyStatus;
  UCHAR Time[2];
} NOTIFICATION_BUSY_STATUS, *PNOTIFICATION_BUSY_STATUS;

typedef struct _SUPPORTED_SECURITY_PROTOCOLS_PARAMETER_DATA {
  UCHAR Reserved1[6];
  UCHAR SupportedSecurityListLength[2];
  UCHAR SupportedSecurityProtocol[0];
} SUPPORTED_SECURITY_PROTOCOLS_PARAMETER_DATA, *PSUPPORTED_SECURITY_PROTOCOLS_PARAMETER_DATA;

typedef struct _READ_DVD_STRUCTURES_HEADER {
  UCHAR Length[2];
  UCHAR Reserved[2];
  UCHAR Data[0];
} READ_DVD_STRUCTURES_HEADER, *PREAD_DVD_STRUCTURES_HEADER;

typedef struct _CDVD_KEY_HEADER {
  UCHAR DataLength[2];
  UCHAR Reserved[2];
  UCHAR Data[0];
} CDVD_KEY_HEADER, *PCDVD_KEY_HEADER;

typedef struct _CDVD_REPORT_AGID_DATA {
  UCHAR Reserved1[3];
  UCHAR Reserved2:6;
  UCHAR AGID:2;
} CDVD_REPORT_AGID_DATA, *PCDVD_REPORT_AGID_DATA;

typedef struct _CDVD_CHALLENGE_KEY_DATA {
  UCHAR ChallengeKeyValue[10];
  UCHAR Reserved[2];
} CDVD_CHALLENGE_KEY_DATA, *PCDVD_CHALLENGE_KEY_DATA;

typedef struct _CDVD_KEY_DATA {
  UCHAR Key[5];
  UCHAR Reserved[3];
} CDVD_KEY_DATA, *PCDVD_KEY_DATA;

typedef struct _CDVD_REPORT_ASF_DATA {
  UCHAR Reserved1[3];
  UCHAR Success:1;
  UCHAR Reserved2:7;
} CDVD_REPORT_ASF_DATA, *PCDVD_REPORT_ASF_DATA;

typedef struct _CDVD_TITLE_KEY_HEADER {
  UCHAR DataLength[2];
  UCHAR Reserved1[1];
  UCHAR Reserved2:3;
  UCHAR CGMS:2;
  UCHAR CP_SEC:1;
  UCHAR CPM:1;
  UCHAR Zero:1;
  CDVD_KEY_DATA TitleKey;
} CDVD_TITLE_KEY_HEADER, *PCDVD_TITLE_KEY_HEADER;

typedef struct _FORMAT_DESCRIPTOR {
  UCHAR NumberOfBlocks[4];
  UCHAR FormatSubType:2;
  UCHAR FormatType:6;
  UCHAR BlockLength[3];
} FORMAT_DESCRIPTOR, *PFORMAT_DESCRIPTOR;

typedef struct _FORMAT_LIST_HEADER {
  UCHAR Reserved;
  UCHAR VendorSpecific:1;
  UCHAR Immediate:1;
  UCHAR TryOut:1;
  UCHAR IP:1;
  UCHAR STPF:1;
  UCHAR DCRT:1;
  UCHAR DPRY:1;
  UCHAR FOV:1;
  UCHAR FormatDescriptorLength[2];
  FORMAT_DESCRIPTOR Descriptors[0];
} FORMAT_LIST_HEADER, *PFORMAT_LIST_HEADER;

typedef struct _FORMATTED_CAPACITY_DESCRIPTOR {
  UCHAR NumberOfBlocks[4];
  UCHAR Maximum:1;
  UCHAR Valid:1;
  UCHAR FormatType:6;
  UCHAR BlockLength[3];
} FORMATTED_CAPACITY_DESCRIPTOR, *PFORMATTED_CAPACITY_DESCRIPTOR;

typedef struct _FORMATTED_CAPACITY_LIST {
  UCHAR Reserved[3];
  UCHAR CapacityListLength;
  FORMATTED_CAPACITY_DESCRIPTOR Descriptors[0];
} FORMATTED_CAPACITY_LIST, *PFORMATTED_CAPACITY_LIST;

typedef struct _OPC_TABLE_ENTRY {
  UCHAR Speed[2];
  UCHAR OPCValue[6];
} OPC_TABLE_ENTRY, *POPC_TABLE_ENTRY;

typedef struct _DISC_INFORMATION {
  UCHAR Length[2];
  UCHAR DiscStatus:2;
  UCHAR LastSessionStatus:2;
  UCHAR Erasable:1;
  UCHAR Reserved1:3;
  UCHAR FirstTrackNumber;
  UCHAR NumberOfSessionsLsb;
  UCHAR LastSessionFirstTrackLsb;
  UCHAR LastSessionLastTrackLsb;
  UCHAR MrwStatus:2;
  UCHAR MrwDirtyBit:1;
  UCHAR Reserved2:2;
  UCHAR URU:1;
  UCHAR DBC_V:1;
  UCHAR DID_V:1;
  UCHAR DiscType;
  UCHAR NumberOfSessionsMsb;
  UCHAR LastSessionFirstTrackMsb;
  UCHAR LastSessionLastTrackMsb;
  UCHAR DiskIdentification[4];
  UCHAR LastSessionLeadIn[4];
  UCHAR LastPossibleLeadOutStartTime[4];
  UCHAR DiskBarCode[8];
  UCHAR Reserved4;
  UCHAR NumberOPCEntries;
  OPC_TABLE_ENTRY OPCTable[1];
} DISC_INFORMATION, *PDISC_INFORMATION;

typedef struct _DISK_INFORMATION {
  UCHAR Length[2];
  UCHAR DiskStatus:2;
  UCHAR LastSessionStatus:2;
  UCHAR Erasable:1;
  UCHAR Reserved1:3;
  UCHAR FirstTrackNumber;
  UCHAR NumberOfSessions;
  UCHAR LastSessionFirstTrack;
  UCHAR LastSessionLastTrack;
  UCHAR Reserved2:5;
  UCHAR GEN:1;
  UCHAR DBC_V:1;
  UCHAR DID_V:1;
  UCHAR DiskType;
  UCHAR Reserved3[3];
  UCHAR DiskIdentification[4];
  UCHAR LastSessionLeadIn[4];
  UCHAR LastPossibleStartTime[4];
  UCHAR DiskBarCode[8];
  UCHAR Reserved4;
  UCHAR NumberOPCEntries;
  OPC_TABLE_ENTRY OPCTable[0];
} DISK_INFORMATION, *PDISK_INFORMATION;

typedef struct _DATA_BLOCK_HEADER {
  UCHAR DataMode;
  UCHAR Reserved[4];
  _ANONYMOUS_UNION union {
    UCHAR LogicalBlockAddress[4];
    struct {
      UCHAR Reserved;
      UCHAR M;
      UCHAR S;
      UCHAR F;
    } MSF;
  } DUMMYUNIONNAME;
} DATA_BLOCK_HEADER, *PDATA_BLOCK_HEADER;

typedef struct _TRACK_INFORMATION {
  UCHAR Length[2];
  UCHAR TrackNumber;
  UCHAR SessionNumber;
  UCHAR Reserved1;
  UCHAR TrackMode:4;
  UCHAR Copy:1;
  UCHAR Damage:1;
  UCHAR Reserved2:2;
  UCHAR DataMode:4;
  UCHAR FP:1;
  UCHAR Packet:1;
  UCHAR Blank:1;
  UCHAR RT:1;
  UCHAR NWA_V:1;
  UCHAR Reserved3:7;
  UCHAR TrackStartAddress[4];
  UCHAR NextWritableAddress[4];
  UCHAR FreeBlocks[4];
  UCHAR FixedPacketSize[4];
} TRACK_INFORMATION, *PTRACK_INFORMATION;

typedef struct _TRACK_INFORMATION2 {
  UCHAR Length[2];
  UCHAR TrackNumberLsb;
  UCHAR SessionNumberLsb;
  UCHAR Reserved4;
  UCHAR TrackMode:4;
  UCHAR Copy:1;
  UCHAR Damage:1;
  UCHAR Reserved5:2;
  UCHAR DataMode:4;
  UCHAR FixedPacket:1;
  UCHAR Packet:1;
  UCHAR Blank:1;
  UCHAR ReservedTrack:1;
  UCHAR NWA_V:1;
  UCHAR LRA_V:1;
  UCHAR Reserved6:6;
  UCHAR TrackStartAddress[4];
  UCHAR NextWritableAddress[4];
  UCHAR FreeBlocks[4];
  UCHAR FixedPacketSize[4];
  UCHAR TrackSize[4];
  UCHAR LastRecordedAddress[4];
  UCHAR TrackNumberMsb;
  UCHAR SessionNumberMsb;
  UCHAR Reserved7[2];
} TRACK_INFORMATION2, *PTRACK_INFORMATION2;

typedef struct _TRACK_INFORMATION3 {
  UCHAR Length[2];
  UCHAR TrackNumberLsb;
  UCHAR SessionNumberLsb;
  UCHAR Reserved4;
  UCHAR TrackMode:4;
  UCHAR Copy:1;
  UCHAR Damage:1;
  UCHAR Reserved5:2;
  UCHAR DataMode:4;
  UCHAR FixedPacket:1;
  UCHAR Packet:1;
  UCHAR Blank:1;
  UCHAR ReservedTrack:1;
  UCHAR NWA_V:1;
  UCHAR LRA_V:1;
  UCHAR Reserved6:6;
  UCHAR TrackStartAddress[4];
  UCHAR NextWritableAddress[4];
  UCHAR FreeBlocks[4];
  UCHAR FixedPacketSize[4];
  UCHAR TrackSize[4];
  UCHAR LastRecordedAddress[4];
  UCHAR TrackNumberMsb;
  UCHAR SessionNumberMsb;
  UCHAR Reserved7[2];
  UCHAR ReadCompatibilityLba[4];
} TRACK_INFORMATION3, *PTRACK_INFORMATION3;

typedef struct _PERFORMANCE_DESCRIPTOR {
  UCHAR RandomAccess:1;
  UCHAR Exact:1;
  UCHAR RestoreDefaults:1;
  UCHAR WriteRotationControl:2;
  UCHAR Reserved1:3;
  UCHAR Reserved[3];
  UCHAR StartLba[4];
  UCHAR EndLba[4];
  UCHAR ReadSize[4];
  UCHAR ReadTime[4];
  UCHAR WriteSize[4];
  UCHAR WriteTime[4];
} PERFORMANCE_DESCRIPTOR, *PPERFORMANCE_DESCRIPTOR;

typedef struct _SCSI_EXTENDED_MESSAGE {
  UCHAR InitialMessageCode;
  UCHAR MessageLength;
  UCHAR MessageType;
  union _EXTENDED_ARGUMENTS {
    struct {
      UCHAR Modifier[4];
    } Modify;
    struct {
      UCHAR TransferPeriod;
      UCHAR ReqAckOffset;
    } Synchronous;
    struct{
      UCHAR Width;
    } Wide;
  } ExtendedArguments;
}SCSI_EXTENDED_MESSAGE, *PSCSI_EXTENDED_MESSAGE;

#ifndef _INQUIRYDATA_DEFINED /* also in minitape.h */
#define _INQUIRYDATA_DEFINED

#define INQUIRYDATABUFFERSIZE 36

#if (NTDDI_VERSION < NTDDI_WINXP)
typedef struct _INQUIRYDATA {
  UCHAR DeviceType:5;
  UCHAR DeviceTypeQualifier:3;
  UCHAR DeviceTypeModifier:7;
  UCHAR RemovableMedia:1;
  UCHAR Versions;
  UCHAR ResponseDataFormat:4;
  UCHAR HiSupport:1;
  UCHAR NormACA:1;
  UCHAR ReservedBit:1;
  UCHAR AERC:1;
  UCHAR AdditionalLength;
  UCHAR Reserved[2];
  UCHAR SoftReset:1;
  UCHAR CommandQueue:1;
  UCHAR Reserved2:1;
  UCHAR LinkedCommands:1;
  UCHAR Synchronous:1;
  UCHAR Wide16Bit:1;
  UCHAR Wide32Bit:1;
  UCHAR RelativeAddressing:1;
  UCHAR VendorId[8];
  UCHAR ProductId[16];
  UCHAR ProductRevisionLevel[4];
  UCHAR VendorSpecific[20];
  UCHAR Reserved3[40];
} INQUIRYDATA, *PINQUIRYDATA;
#else
typedef struct _INQUIRYDATA {
  UCHAR DeviceType:5;
  UCHAR DeviceTypeQualifier:3;
  UCHAR DeviceTypeModifier:7;
  UCHAR RemovableMedia:1;
  _ANONYMOUS_UNION union {
    UCHAR Versions;
    _ANONYMOUS_STRUCT struct {
      UCHAR ANSIVersion:3;
      UCHAR ECMAVersion:3;
      UCHAR ISOVersion:2;
    } DUMMYSTRUCTNAME;
  } DUMMYUNIONNAME;
  UCHAR ResponseDataFormat:4;
  UCHAR HiSupport:1;
  UCHAR NormACA:1;
  UCHAR TerminateTask:1;
  UCHAR AERC:1;
  UCHAR AdditionalLength;
  UCHAR Reserved;
  UCHAR Addr16:1;
  UCHAR Addr32:1;
  UCHAR AckReqQ:1;
  UCHAR MediumChanger:1;
  UCHAR MultiPort:1;
  UCHAR ReservedBit2:1;
  UCHAR EnclosureServices:1;
  UCHAR ReservedBit3:1;
  UCHAR SoftReset:1;
  UCHAR CommandQueue:1;
  UCHAR TransferDisable:1;
  UCHAR LinkedCommands:1;
  UCHAR Synchronous:1;
  UCHAR Wide16Bit:1;
  UCHAR Wide32Bit:1;
  UCHAR RelativeAddressing:1;
  UCHAR VendorId[8];
  UCHAR ProductId[16];
  UCHAR ProductRevisionLevel[4];
  UCHAR VendorSpecific[20];
  UCHAR Reserved3[40];
} INQUIRYDATA, *PINQUIRYDATA;
#endif /* (NTDDI_VERSION < NTDDI_WINXP) */

#endif /* _INQUIRYDATA_DEFINED */

typedef struct _VPD_MEDIA_SERIAL_NUMBER_PAGE {
  UCHAR DeviceType:5;
  UCHAR DeviceTypeQualifier:3;
  UCHAR PageCode;
  UCHAR Reserved;
  UCHAR PageLength;
  UCHAR SerialNumber[0];
} VPD_MEDIA_SERIAL_NUMBER_PAGE, *PVPD_MEDIA_SERIAL_NUMBER_PAGE;

typedef struct _VPD_SERIAL_NUMBER_PAGE {
  UCHAR DeviceType:5;
  UCHAR DeviceTypeQualifier:3;
  UCHAR PageCode;
  UCHAR Reserved;
  UCHAR PageLength;
  UCHAR SerialNumber[0];
} VPD_SERIAL_NUMBER_PAGE, *PVPD_SERIAL_NUMBER_PAGE;

typedef enum _VPD_CODE_SET {
  VpdCodeSetReserved = 0,
  VpdCodeSetBinary = 1,
  VpdCodeSetAscii = 2,
  VpdCodeSetUTF8 = 3
} VPD_CODE_SET, *PVPD_CODE_SET;

typedef enum _VPD_ASSOCIATION {
  VpdAssocDevice = 0,
  VpdAssocPort = 1,
  VpdAssocTarget = 2,
  VpdAssocReserved1 = 3,
  VpdAssocReserved2 = 4
} VPD_ASSOCIATION, *PVPD_ASSOCIATION;

typedef enum _VPD_IDENTIFIER_TYPE {
  VpdIdentifierTypeVendorSpecific = 0,
  VpdIdentifierTypeVendorId = 1,
  VpdIdentifierTypeEUI64 = 2,
  VpdIdentifierTypeFCPHName = 3,
  VpdIdentifierTypePortRelative = 4,
  VpdIdentifierTypeTargetPortGroup = 5,
  VpdIdentifierTypeLogicalUnitGroup = 6,
  VpdIdentifierTypeMD5LogicalUnitId = 7,
  VpdIdentifierTypeSCSINameString = 8
} VPD_IDENTIFIER_TYPE, *PVPD_IDENTIFIER_TYPE;

typedef struct _VPD_IDENTIFICATION_DESCRIPTOR {
  UCHAR CodeSet:4;
  UCHAR Reserved:4;
  UCHAR IdentifierType:4;
  UCHAR Association:2;
  UCHAR Reserved2:2;
  UCHAR Reserved3;
  UCHAR IdentifierLength;
  UCHAR Identifier[0];
} VPD_IDENTIFICATION_DESCRIPTOR, *PVPD_IDENTIFICATION_DESCRIPTOR;

typedef struct _VPD_IDENTIFICATION_PAGE {
  UCHAR DeviceType:5;
  UCHAR DeviceTypeQualifier:3;
  UCHAR PageCode;
  UCHAR Reserved;
  UCHAR PageLength;
  UCHAR Descriptors[0];
} VPD_IDENTIFICATION_PAGE, *PVPD_IDENTIFICATION_PAGE;

typedef struct _VPD_SUPPORTED_PAGES_PAGE {
  UCHAR DeviceType:5;
  UCHAR DeviceTypeQualifier:3;
  UCHAR PageCode;
  UCHAR Reserved;
  UCHAR PageLength;
  UCHAR SupportedPageList[0];
} VPD_SUPPORTED_PAGES_PAGE, *PVPD_SUPPORTED_PAGES_PAGE;

typedef struct _PRI_REGISTRATION_LIST {
  UCHAR Generation[4];
  UCHAR AdditionalLength[4];
  UCHAR ReservationKeyList[0][8];
} PRI_REGISTRATION_LIST, *PPRI_REGISTRATION_LIST;

typedef struct _PRI_RESERVATION_DESCRIPTOR {
  UCHAR ReservationKey[8];
  UCHAR ScopeSpecificAddress[4];
  UCHAR Reserved;
  UCHAR Type:4;
  UCHAR Scope:4;
  UCHAR Obsolete[2];
} PRI_RESERVATION_DESCRIPTOR, *PPRI_RESERVATION_DESCRIPTOR;

typedef struct _PRI_RESERVATION_LIST {
  UCHAR Generation[4];
  UCHAR AdditionalLength[4];
  PRI_RESERVATION_DESCRIPTOR Reservations[0];
} PRI_RESERVATION_LIST, *PPRI_RESERVATION_LIST;

typedef struct _PRO_PARAMETER_LIST {
  UCHAR ReservationKey[8];
  UCHAR ServiceActionReservationKey[8];
  UCHAR ScopeSpecificAddress[4];
  UCHAR ActivatePersistThroughPowerLoss:1;
  UCHAR Reserved1:7;
  UCHAR Reserved2;
  UCHAR Obsolete[2];
} PRO_PARAMETER_LIST, *PPRO_PARAMETER_LIST;

typedef struct _SENSE_DATA {
  UCHAR ErrorCode:7;
  UCHAR Valid:1;
  UCHAR SegmentNumber;
  UCHAR SenseKey:4;
  UCHAR Reserved:1;
  UCHAR IncorrectLength:1;
  UCHAR EndOfMedia:1;
  UCHAR FileMark:1;
  UCHAR Information[4];
  UCHAR AdditionalSenseLength;
  UCHAR CommandSpecificInformation[4];
  UCHAR AdditionalSenseCode;
  UCHAR AdditionalSenseCodeQualifier;
  UCHAR FieldReplaceableUnitCode;
  UCHAR SenseKeySpecific[3];
} SENSE_DATA, *PSENSE_DATA;

/* Read Capacity Data. Returned in Big Endian format */
typedef struct _READ_CAPACITY_DATA {
  ULONG LogicalBlockAddress;
  ULONG BytesPerBlock;
} READ_CAPACITY_DATA, *PREAD_CAPACITY_DATA;

typedef struct _READ_CAPACITY_DATA_EX {
  LARGE_INTEGER LogicalBlockAddress;
  ULONG BytesPerBlock;
} READ_CAPACITY_DATA_EX, *PREAD_CAPACITY_DATA_EX;

/* Read Block Limits Data. Returned in Big Endian format */
typedef struct _READ_BLOCK_LIMITS {
  UCHAR Reserved;
  UCHAR BlockMaximumSize[3];
  UCHAR BlockMinimumSize[2];
} READ_BLOCK_LIMITS_DATA, *PREAD_BLOCK_LIMITS_DATA;

typedef struct _READ_BUFFER_CAPACITY_DATA {
  UCHAR DataLength[2];
  UCHAR Reserved1;
  UCHAR BlockDataReturned:1;
  UCHAR Reserved4:7;
  UCHAR TotalBufferSize[4];
  UCHAR AvailableBufferSize[4];
} READ_BUFFER_CAPACITY_DATA, *PREAD_BUFFER_CAPACITY_DATA;

typedef struct _MODE_PARAMETER_HEADER {
  UCHAR ModeDataLength;
  UCHAR MediumType;
  UCHAR DeviceSpecificParameter;
  UCHAR BlockDescriptorLength;
} MODE_PARAMETER_HEADER, *PMODE_PARAMETER_HEADER;

typedef struct _MODE_PARAMETER_HEADER10 {
  UCHAR ModeDataLength[2];
  UCHAR MediumType;
  UCHAR DeviceSpecificParameter;
  UCHAR Reserved[2];
  UCHAR BlockDescriptorLength[2];
} MODE_PARAMETER_HEADER10, *PMODE_PARAMETER_HEADER10;

typedef struct _MODE_PARAMETER_BLOCK {
  UCHAR DensityCode;
  UCHAR NumberOfBlocks[3];
  UCHAR Reserved;
  UCHAR BlockLength[3];
} MODE_PARAMETER_BLOCK, *PMODE_PARAMETER_BLOCK;

typedef struct _MODE_DISCONNECT_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PageSavable:1;
  UCHAR PageLength;
  UCHAR BufferFullRatio;
  UCHAR BufferEmptyRatio;
  UCHAR BusInactivityLimit[2];
  UCHAR BusDisconnectTime[2];
  UCHAR BusConnectTime[2];
  UCHAR MaximumBurstSize[2];
  UCHAR DataTransferDisconnect:2;
  UCHAR Reserved2[3];
} MODE_DISCONNECT_PAGE, *PMODE_DISCONNECT_PAGE;

typedef struct _MODE_CACHING_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PageSavable:1;
  UCHAR PageLength;
  UCHAR ReadDisableCache:1;
  UCHAR MultiplicationFactor:1;
  UCHAR WriteCacheEnable:1;
  UCHAR Reserved2:5;
  UCHAR WriteRetensionPriority:4;
  UCHAR ReadRetensionPriority:4;
  UCHAR DisablePrefetchTransfer[2];
  UCHAR MinimumPrefetch[2];
  UCHAR MaximumPrefetch[2];
  UCHAR MaximumPrefetchCeiling[2];
} MODE_CACHING_PAGE, *PMODE_CACHING_PAGE;

typedef struct _MODE_CDROM_WRITE_PARAMETERS_PAGE2 {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PageSavable:1;
  UCHAR PageLength;
  UCHAR WriteType:4;
  UCHAR TestWrite:1;
  UCHAR LinkSizeValid:1;
  UCHAR BufferUnderrunFreeEnabled:1;
  UCHAR Reserved2:1;
  UCHAR TrackMode:4;
  UCHAR Copy:1;
  UCHAR FixedPacket:1;
  UCHAR MultiSession:2;
  UCHAR DataBlockType:4;
  UCHAR Reserved3:4;
  UCHAR LinkSize;
  UCHAR Reserved4;
  UCHAR HostApplicationCode:6;
  UCHAR Reserved5:2;
  UCHAR SessionFormat;
  UCHAR Reserved6;
  UCHAR PacketSize[4];
  UCHAR AudioPauseLength[2];
  UCHAR MediaCatalogNumber[16];
  UCHAR ISRC[16];
  UCHAR SubHeaderData[4];
} MODE_CDROM_WRITE_PARAMETERS_PAGE2, *PMODE_CDROM_WRITE_PARAMETERS_PAGE2;

typedef struct _MODE_MRW_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PageSavable:1;
  UCHAR PageLength;
  UCHAR Reserved1;
  UCHAR LbaSpace:1;
  UCHAR Reserved2:7;
  UCHAR Reserved3[4];
} MODE_MRW_PAGE, *PMODE_MRW_PAGE;

typedef struct _MODE_FLEXIBLE_DISK_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PageSavable:1;
  UCHAR PageLength;
  UCHAR TransferRate[2];
  UCHAR NumberOfHeads;
  UCHAR SectorsPerTrack;
  UCHAR BytesPerSector[2];
  UCHAR NumberOfCylinders[2];
  UCHAR StartWritePrecom[2];
  UCHAR StartReducedCurrent[2];
  UCHAR StepRate[2];
  UCHAR StepPluseWidth;
  UCHAR HeadSettleDelay[2];
  UCHAR MotorOnDelay;
  UCHAR MotorOffDelay;
  UCHAR Reserved2:5;
  UCHAR MotorOnAsserted:1;
  UCHAR StartSectorNumber:1;
  UCHAR TrueReadySignal:1;
  UCHAR StepPlusePerCyclynder:4;
  UCHAR Reserved3:4;
  UCHAR WriteCompenstation;
  UCHAR HeadLoadDelay;
  UCHAR HeadUnloadDelay;
  UCHAR Pin2Usage:4;
  UCHAR Pin34Usage:4;
  UCHAR Pin1Usage:4;
  UCHAR Pin4Usage:4;
  UCHAR MediumRotationRate[2];
  UCHAR Reserved4[2];
} MODE_FLEXIBLE_DISK_PAGE, *PMODE_FLEXIBLE_DISK_PAGE;

typedef struct _MODE_FORMAT_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PageSavable:1;
  UCHAR PageLength;
  UCHAR TracksPerZone[2];
  UCHAR AlternateSectorsPerZone[2];
  UCHAR AlternateTracksPerZone[2];
  UCHAR AlternateTracksPerLogicalUnit[2];
  UCHAR SectorsPerTrack[2];
  UCHAR BytesPerPhysicalSector[2];
  UCHAR Interleave[2];
  UCHAR TrackSkewFactor[2];
  UCHAR CylinderSkewFactor[2];
  UCHAR Reserved2:4;
  UCHAR SurfaceFirst:1;
  UCHAR RemovableMedia:1;
  UCHAR HardSectorFormating:1;
  UCHAR SoftSectorFormating:1;
  UCHAR Reserved3[3];
} MODE_FORMAT_PAGE, *PMODE_FORMAT_PAGE;

typedef struct _MODE_RIGID_GEOMETRY_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PageSavable:1;
  UCHAR PageLength;
  UCHAR NumberOfCylinders[3];
  UCHAR NumberOfHeads;
  UCHAR StartWritePrecom[3];
  UCHAR StartReducedCurrent[3];
  UCHAR DriveStepRate[2];
  UCHAR LandZoneCyclinder[3];
  UCHAR RotationalPositionLock:2;
  UCHAR Reserved2:6;
  UCHAR RotationOffset;
  UCHAR Reserved3;
  UCHAR RoataionRate[2];
  UCHAR Reserved4[2];
} MODE_RIGID_GEOMETRY_PAGE, *PMODE_RIGID_GEOMETRY_PAGE;

typedef struct _MODE_READ_WRITE_RECOVERY_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved1:1;
  UCHAR PSBit:1;
  UCHAR PageLength;
  UCHAR DCRBit:1;
  UCHAR DTEBit:1;
  UCHAR PERBit:1;
  UCHAR EERBit:1;
  UCHAR RCBit:1;
  UCHAR TBBit:1;
  UCHAR ARRE:1;
  UCHAR AWRE:1;
  UCHAR ReadRetryCount;
  UCHAR Reserved4[4];
  UCHAR WriteRetryCount;
  UCHAR Reserved5[3];
} MODE_READ_WRITE_RECOVERY_PAGE, *PMODE_READ_WRITE_RECOVERY_PAGE;

typedef struct _MODE_READ_RECOVERY_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved1:1;
  UCHAR PSBit:1;
  UCHAR PageLength;
  UCHAR DCRBit:1;
  UCHAR DTEBit:1;
  UCHAR PERBit:1;
  UCHAR Reserved2:1;
  UCHAR RCBit:1;
  UCHAR TBBit:1;
  UCHAR Reserved3:2;
  UCHAR ReadRetryCount;
  UCHAR Reserved4[4];
} MODE_READ_RECOVERY_PAGE, *PMODE_READ_RECOVERY_PAGE;

typedef struct _MODE_INFO_EXCEPTIONS {
  UCHAR PageCode:6;
  UCHAR Reserved1:1;
  UCHAR PSBit:1;
  UCHAR PageLength;
  _ANONYMOUS_UNION union {
    UCHAR Flags;
    _ANONYMOUS_STRUCT struct {
      UCHAR LogErr:1;
      UCHAR Reserved2:1;
      UCHAR Test:1;
      UCHAR Dexcpt:1;
      UCHAR Reserved3:3;
      UCHAR Perf:1;
    } DUMMYSTRUCTNAME;
  } DUMMYUNIONNAME;
  UCHAR ReportMethod:4;
  UCHAR Reserved4:4;
  UCHAR IntervalTimer[4];
  UCHAR ReportCount[4];
} MODE_INFO_EXCEPTIONS, *PMODE_INFO_EXCEPTIONS;

typedef struct _POWER_CONDITION_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PSBit:1;
  UCHAR PageLength;
  UCHAR Reserved2;
  UCHAR Standby:1;
  UCHAR Idle:1;
  UCHAR Reserved3:6;
  UCHAR IdleTimer[4];
  UCHAR StandbyTimer[4];
} POWER_CONDITION_PAGE, *PPOWER_CONDITION_PAGE;

typedef struct _CDDA_OUTPUT_PORT {
  UCHAR ChannelSelection:4;
  UCHAR Reserved:4;
  UCHAR Volume;
} CDDA_OUTPUT_PORT, *PCDDA_OUTPUT_PORT;

typedef struct _CDAUDIO_CONTROL_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PSBit:1;
  UCHAR PageLength;
  UCHAR Reserved2:1;
  UCHAR StopOnTrackCrossing:1;
  UCHAR Immediate:1;
  UCHAR Reserved3:5;
  UCHAR Reserved4[3];
  UCHAR Obsolete[2];
  CDDA_OUTPUT_PORT CDDAOutputPorts[4];
} CDAUDIO_CONTROL_PAGE, *PCDAUDIO_CONTROL_PAGE;

typedef struct _CDVD_FEATURE_SET_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PSBit:1;
  UCHAR PageLength;
  UCHAR CDAudio[2];
  UCHAR EmbeddedChanger[2];
  UCHAR PacketSMART[2];
  UCHAR PersistantPrevent[2];
  UCHAR EventStatusNotification[2];
  UCHAR DigitalOutput[2];
  UCHAR CDSequentialRecordable[2];
  UCHAR DVDSequentialRecordable[2];
  UCHAR RandomRecordable[2];
  UCHAR KeyExchange[2];
  UCHAR Reserved2[2];
} CDVD_FEATURE_SET_PAGE, *PCDVD_FEATURE_SET_PAGE;

typedef struct _CDVD_INACTIVITY_TIMEOUT_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PSBit:1;
  UCHAR PageLength;
  UCHAR Reserved2[2];
  UCHAR SWPP:1;
  UCHAR DISP:1;
  UCHAR Reserved3:6;
  UCHAR Reserved4;
  UCHAR GroupOneMinimumTimeout[2];
  UCHAR GroupTwoMinimumTimeout[2];
} CDVD_INACTIVITY_TIMEOUT_PAGE, *PCDVD_INACTIVITY_TIMEOUT_PAGE;

typedef struct _CDVD_CAPABILITIES_PAGE {
  UCHAR PageCode:6;
  UCHAR Reserved:1;
  UCHAR PSBit:1;
  UCHAR PageLength;
  UCHAR CDRRead:1;
  UCHAR CDERead:1;
  UCHAR Method2:1;
  UCHAR DVDROMRead:1;
  UCHAR DVDRRead:1;
  UCHAR DVDRAMRead:1;
  UCHAR Reserved2:2;
  UCHAR CDRWrite:1;
  UCHAR CDEWrite:1;
  UCHAR TestWrite:1;
  UCHAR Reserved3:1;
  UCHAR DVDRWrite:1;
  UCHAR DVDRAMWrite:1;
  UCHAR Reserved4:2;
  UCHAR AudioPlay:1;
  UCHAR Composite:1;
  UCHAR DigitalPortOne:1;
  UCHAR DigitalPortTwo:1;
  UCHAR Mode2Form1:1;
  UCHAR Mode2Form2:1;
  UCHAR MultiSession:1;
  UCHAR BufferUnderrunFree:1;
  UCHAR CDDA:1;
  UCHAR CDDAAccurate:1;
  UCHAR RWSupported:1;
  UCHAR RWDeinterleaved:1;
  UCHAR C2Pointers:1;
  UCHAR ISRC:1;
  UCHAR UPC:1;
  UCHAR ReadBarCodeCapable:1;
  UCHAR Lock:1;
  UCHAR LockState:1;
  UCHAR PreventJumper:1;
  UCHAR Eject:1;
  UCHAR Reserved6:1;
  UCHAR LoadingMechanismType:3;
  UCHAR SeparateVolume:1;
  UCHAR SeperateChannelMute:1;
  UCHAR SupportsDiskPresent:1;
  UCHAR SWSlotSelection:1;
  UCHAR SideChangeCapable:1;
  UCHAR RWInLeadInReadable:1;
  UCHAR Reserved7:2;
  _ANONYMOUS_UNION union {
    UCHAR ReadSpeedMaximum[2];
    UCHAR ObsoleteReserved[2];
  } DUMMYUNIONNAME;
  UCHAR NumberVolumeLevels[2];
  UCHAR BufferSize[2];
  _ANONYMOUS_UNION union {
    UCHAR ReadSpeedCurrent[2];
    UCHAR ObsoleteReserved2[2];
  } DUMMYUNIONNAME2;
  UCHAR ObsoleteReserved3;
  UCHAR Reserved8:1;
  UCHAR BCK:1;
  UCHAR RCK:1;
  UCHAR LSBF:1;
  UCHAR Length:2;
  UCHAR Reserved9:2;
  _ANONYMOUS_UNION union {
    UCHAR WriteSpeedMaximum[2];
    UCHAR ObsoleteReserved4[2];
  } DUMMYUNIONNAME3;
  _ANONYMOUS_UNION union {
    UCHAR WriteSpeedCurrent[2];
    UCHAR ObsoleteReserved11[2];
  } DUMMYUNIONNAME4;
  _ANONYMOUS_UNION union {
    UCHAR CopyManagementRevision[2];
    UCHAR Reserved10[2];
  } DUMMYUNIONNAME5;
} CDVD_CAPABILITIES_PAGE, *PCDVD_CAPABILITIES_PAGE;

typedef struct _LUN_LIST {
  UCHAR LunListLength[4];
  UCHAR Reserved[4];
  UCHAR Lun[0][8];
} LUN_LIST, *PLUN_LIST;

typedef struct _MODE_PARM_READ_WRITE {
  MODE_PARAMETER_HEADER ParameterListHeader;
  MODE_PARAMETER_BLOCK ParameterListBlock;
} MODE_PARM_READ_WRITE_DATA, *PMODE_PARM_READ_WRITE_DATA;

typedef struct _PORT_OUTPUT {
  UCHAR ChannelSelection;
  UCHAR Volume;
} PORT_OUTPUT, *PPORT_OUTPUT;

typedef struct _AUDIO_OUTPUT {
  UCHAR CodePage;
  UCHAR ParameterLength;
  UCHAR Immediate;
  UCHAR Reserved[2];
  UCHAR LbaFormat;
  UCHAR LogicalBlocksPerSecond[2];
  PORT_OUTPUT PortOutput[4];
} AUDIO_OUTPUT, *PAUDIO_OUTPUT;

/* Atapi 2.5 changers */
typedef struct _MECHANICAL_STATUS_INFORMATION_HEADER {
  UCHAR CurrentSlot:5;
  UCHAR ChangerState:2;
  UCHAR Fault:1;
  UCHAR Reserved:5;
  UCHAR MechanismState:3;
  UCHAR CurrentLogicalBlockAddress[3];
  UCHAR NumberAvailableSlots;
  UCHAR SlotTableLength[2];
} MECHANICAL_STATUS_INFORMATION_HEADER, *PMECHANICAL_STATUS_INFORMATION_HEADER;

typedef struct _SLOT_TABLE_INFORMATION {
  UCHAR DiscChanged:1;
  UCHAR Reserved:6;
  UCHAR DiscPresent:1;
  UCHAR Reserved2[3];
} SLOT_TABLE_INFORMATION, *PSLOT_TABLE_INFORMATION;

typedef struct _MECHANICAL_STATUS {
  MECHANICAL_STATUS_INFORMATION_HEADER MechanicalStatusHeader;
  SLOT_TABLE_INFORMATION SlotTableInfo[1];
} MECHANICAL_STATUS, *PMECHANICAL_STATUS;

/* Tape definitions */
typedef struct _TAPE_POSITION_DATA {
  UCHAR Reserved1:2;
  UCHAR BlockPositionUnsupported:1;
  UCHAR Reserved2:3;
  UCHAR EndOfPartition:1;
  UCHAR BeginningOfPartition:1;
  UCHAR PartitionNumber;
  USHORT Reserved3;
  UCHAR FirstBlock[4];
  UCHAR LastBlock[4];
  UCHAR Reserved4;
  UCHAR NumberOfBlocks[3];
  UCHAR NumberOfBytes[4];
} TAPE_POSITION_DATA, *PTAPE_POSITION_DATA;

/* This structure is used to convert little endian ULONGs
   to SCSI CDB big endians values. */
typedef union _EIGHT_BYTE {
  _ANONYMOUS_STRUCT struct {
    UCHAR Byte0;
    UCHAR Byte1;
    UCHAR Byte2;
    UCHAR Byte3;
    UCHAR Byte4;
    UCHAR Byte5;
    UCHAR Byte6;
    UCHAR Byte7;
  } DUMMYSTRUCTNAME;
  ULONGLONG AsULongLong;
} EIGHT_BYTE, *PEIGHT_BYTE;

typedef union _FOUR_BYTE {
  _ANONYMOUS_STRUCT struct {
    UCHAR Byte0;
    UCHAR Byte1;
    UCHAR Byte2;
    UCHAR Byte3;
  } DUMMYSTRUCTNAME;
  ULONG AsULong;
} FOUR_BYTE, *PFOUR_BYTE;

typedef union _TWO_BYTE {
  _ANONYMOUS_STRUCT struct {
    UCHAR Byte0;
    UCHAR Byte1;
  } DUMMYSTRUCTNAME;
  USHORT AsUShort;
} TWO_BYTE, *PTWO_BYTE;

/* Byte reversing macro for converting between
   big- and little-endian formats */
#define REVERSE_BYTES_QUAD(Destination, Source) { \
  PEIGHT_BYTE _val1 = (PEIGHT_BYTE)(Destination); \
  PEIGHT_BYTE _val2 = (PEIGHT_BYTE)(Source); \
  _val1->Byte7 = _val2->Byte0; \
  _val1->Byte6 = _val2->Byte1; \
  _val1->Byte5 = _val2->Byte2; \
  _val1->Byte4 = _val2->Byte3; \
  _val1->Byte3 = _val2->Byte4; \
  _val1->Byte2 = _val2->Byte5; \
  _val1->Byte1 = _val2->Byte6; \
  _val1->Byte0 = _val2->Byte7; \
}

#define REVERSE_BYTES(Destination, Source) { \
  PFOUR_BYTE _val1 = (PFOUR_BYTE)(Destination); \
  PFOUR_BYTE _val2 = (PFOUR_BYTE)(Source); \
  _val1->Byte3 = _val2->Byte0; \
  _val1->Byte2 = _val2->Byte1; \
  _val1->Byte1 = _val2->Byte2; \
  _val1->Byte0 = _val2->Byte3; \
}

#define REVERSE_BYTES_SHORT(Destination, Source) { \
  PTWO_BYTE _val1 = (PTWO_BYTE)(Destination); \
  PTWO_BYTE _val2 = (PTWO_BYTE)(Source); \
  _val1->Byte1 = _val2->Byte0; \
  _val1->Byte0 = _val2->Byte1; \
}

#define REVERSE_SHORT(Short) { \
  UCHAR _val; \
  PTWO_BYTE _val2 = (PTWO_BYTE)(Short); \
  _val = _val2->Byte0; \
  _val2->Byte0 = _val2->Byte1; \
  _val2->Byte1 = _val; \
}

#define REVERSE_LONG(Long) { \
  UCHAR _val; \
  PFOUR_BYTE _val2 = (PFOUR_BYTE)(Long); \
  _val = _val2->Byte3; \
  _val2->Byte3 = _val2->Byte0; \
  _val2->Byte0 = _val; \
  _val = _val2->Byte2; \
  _val2->Byte2 = _val2->Byte1; \
  _val2->Byte1 = _val; \
}

#define WHICH_BIT(Data, Bit) { \
  UCHAR _val; \
  for (_val = 0; _val < 32; _val++) { \
    if (((Data) >> _val) == 1) { \
      break; \
    } \
  } \
  ASSERT(_val != 32); \
  (Bit) = _val; \
}

/* FIXME : This structure doesn't exist in the official header */
typedef struct _MODE_CDROM_WRITE_PARAMETERS_PAGE {
  UCHAR PageLength;
  UCHAR WriteType:4;
  UCHAR TestWrite:1;
  UCHAR LinkSizeValid:1;
  UCHAR BufferUnderrunFreeEnabled:1;
  UCHAR Reserved2:1;
  UCHAR TrackMode:4;
  UCHAR Copy:1;
  UCHAR FixedPacket:1;
  UCHAR MultiSession:2;
  UCHAR DataBlockType:4;
  UCHAR Reserved3:4;
  UCHAR LinkSize;
  UCHAR Reserved4;
  UCHAR HostApplicationCode:6;
  UCHAR Reserved5:2;
  UCHAR SessionFormat;
  UCHAR Reserved6;
  UCHAR PacketSize[4];
  UCHAR AudioPauseLength[2];
  UCHAR Reserved7:7;
  UCHAR MediaCatalogNumberValid:1;
  UCHAR MediaCatalogNumber[13];
  UCHAR MediaCatalogNumberZero;
  UCHAR MediaCatalogNumberAFrame;
  UCHAR Reserved8:7;
  UCHAR ISRCValid:1;
  UCHAR ISRCCountry[2];
  UCHAR ISRCOwner[3];
  UCHAR ISRCRecordingYear[2];
  UCHAR ISRCSerialNumber[5];
  UCHAR ISRCZero;
  UCHAR ISRCAFrame;
  UCHAR ISRCReserved;
  UCHAR SubHeaderData[4];
} MODE_CDROM_WRITE_PARAMETERS_PAGE, *PMODE_CDROM_WRITE_PARAMETERS_PAGE;

#ifdef __cplusplus
}
#endif

#endif /* _NTSCSI_ */
