/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _LINUX_HDREG_H
#define _LINUX_HDREG_H
#include <linux/types.h>
#define HDIO_DRIVE_CMD_HDR_SIZE (4 * sizeof(__u8))
#define HDIO_DRIVE_HOB_HDR_SIZE (8 * sizeof(__u8))
#define HDIO_DRIVE_TASK_HDR_SIZE (8 * sizeof(__u8))
#define IDE_DRIVE_TASK_NO_DATA 0
#define IDE_DRIVE_TASK_INVALID - 1
#define IDE_DRIVE_TASK_SET_XFER 1
#define IDE_DRIVE_TASK_IN 2
#define IDE_DRIVE_TASK_OUT 3
#define IDE_DRIVE_TASK_RAW_WRITE 4
#define IDE_TASKFILE_STD_IN_FLAGS 0xFE
#define IDE_HOB_STD_IN_FLAGS 0x3C
#define IDE_TASKFILE_STD_OUT_FLAGS 0xFE
#define IDE_HOB_STD_OUT_FLAGS 0x3C
typedef unsigned char task_ioreg_t;
typedef unsigned long sata_ioreg_t;
typedef union ide_reg_valid_s {
  unsigned all : 16;
  struct {
    unsigned data : 1;
    unsigned error_feature : 1;
    unsigned sector : 1;
    unsigned nsector : 1;
    unsigned lcyl : 1;
    unsigned hcyl : 1;
    unsigned select : 1;
    unsigned status_command : 1;
    unsigned data_hob : 1;
    unsigned error_feature_hob : 1;
    unsigned sector_hob : 1;
    unsigned nsector_hob : 1;
    unsigned lcyl_hob : 1;
    unsigned hcyl_hob : 1;
    unsigned select_hob : 1;
    unsigned control_hob : 1;
  } b;
} ide_reg_valid_t;
typedef struct ide_task_request_s {
  __u8 io_ports[8];
  __u8 hob_ports[8];
  ide_reg_valid_t out_flags;
  ide_reg_valid_t in_flags;
  int data_phase;
  int req_cmd;
  unsigned long out_size;
  unsigned long in_size;
} ide_task_request_t;
typedef struct ide_ioctl_request_s {
  ide_task_request_t * task_request;
  unsigned char * out_buffer;
  unsigned char * in_buffer;
} ide_ioctl_request_t;
struct hd_drive_cmd_hdr {
  __u8 command;
  __u8 sector_number;
  __u8 feature;
  __u8 sector_count;
};
typedef struct hd_drive_task_hdr {
  __u8 data;
  __u8 feature;
  __u8 sector_count;
  __u8 sector_number;
  __u8 low_cylinder;
  __u8 high_cylinder;
  __u8 device_head;
  __u8 command;
} task_struct_t;
typedef struct hd_drive_hob_hdr {
  __u8 data;
  __u8 feature;
  __u8 sector_count;
  __u8 sector_number;
  __u8 low_cylinder;
  __u8 high_cylinder;
  __u8 device_head;
  __u8 control;
} hob_struct_t;
#define TASKFILE_NO_DATA 0x0000
#define TASKFILE_IN 0x0001
#define TASKFILE_MULTI_IN 0x0002
#define TASKFILE_OUT 0x0004
#define TASKFILE_MULTI_OUT 0x0008
#define TASKFILE_IN_OUT 0x0010
#define TASKFILE_IN_DMA 0x0020
#define TASKFILE_OUT_DMA 0x0040
#define TASKFILE_IN_DMAQ 0x0080
#define TASKFILE_OUT_DMAQ 0x0100
#define TASKFILE_P_IN 0x0200
#define TASKFILE_P_OUT 0x0400
#define TASKFILE_P_IN_DMA 0x0800
#define TASKFILE_P_OUT_DMA 0x1000
#define TASKFILE_P_IN_DMAQ 0x2000
#define TASKFILE_P_OUT_DMAQ 0x4000
#define TASKFILE_48 0x8000
#define TASKFILE_INVALID 0x7fff
#define WIN_NOP 0x00
#define CFA_REQ_EXT_ERROR_CODE 0x03
#define WIN_SRST 0x08
#define WIN_DEVICE_RESET 0x08
#define WIN_RECAL 0x10
#define WIN_RESTORE WIN_RECAL
#define WIN_READ 0x20
#define WIN_READ_ONCE 0x21
#define WIN_READ_LONG 0x22
#define WIN_READ_LONG_ONCE 0x23
#define WIN_READ_EXT 0x24
#define WIN_READDMA_EXT 0x25
#define WIN_READDMA_QUEUED_EXT 0x26
#define WIN_READ_NATIVE_MAX_EXT 0x27
#define WIN_MULTREAD_EXT 0x29
#define WIN_WRITE 0x30
#define WIN_WRITE_ONCE 0x31
#define WIN_WRITE_LONG 0x32
#define WIN_WRITE_LONG_ONCE 0x33
#define WIN_WRITE_EXT 0x34
#define WIN_WRITEDMA_EXT 0x35
#define WIN_WRITEDMA_QUEUED_EXT 0x36
#define WIN_SET_MAX_EXT 0x37
#define CFA_WRITE_SECT_WO_ERASE 0x38
#define WIN_MULTWRITE_EXT 0x39
#define WIN_WRITE_VERIFY 0x3C
#define WIN_VERIFY 0x40
#define WIN_VERIFY_ONCE 0x41
#define WIN_VERIFY_EXT 0x42
#define WIN_FORMAT 0x50
#define WIN_INIT 0x60
#define WIN_SEEK 0x70
#define CFA_TRANSLATE_SECTOR 0x87
#define WIN_DIAGNOSE 0x90
#define WIN_SPECIFY 0x91
#define WIN_DOWNLOAD_MICROCODE 0x92
#define WIN_STANDBYNOW2 0x94
#define WIN_STANDBY2 0x96
#define WIN_SETIDLE2 0x97
#define WIN_CHECKPOWERMODE2 0x98
#define WIN_SLEEPNOW2 0x99
#define WIN_PACKETCMD 0xA0
#define WIN_PIDENTIFY 0xA1
#define WIN_QUEUED_SERVICE 0xA2
#define WIN_SMART 0xB0
#define CFA_ERASE_SECTORS 0xC0
#define WIN_MULTREAD 0xC4
#define WIN_MULTWRITE 0xC5
#define WIN_SETMULT 0xC6
#define WIN_READDMA_QUEUED 0xC7
#define WIN_READDMA 0xC8
#define WIN_READDMA_ONCE 0xC9
#define WIN_WRITEDMA 0xCA
#define WIN_WRITEDMA_ONCE 0xCB
#define WIN_WRITEDMA_QUEUED 0xCC
#define CFA_WRITE_MULTI_WO_ERASE 0xCD
#define WIN_GETMEDIASTATUS 0xDA
#define WIN_ACKMEDIACHANGE 0xDB
#define WIN_POSTBOOT 0xDC
#define WIN_PREBOOT 0xDD
#define WIN_DOORLOCK 0xDE
#define WIN_DOORUNLOCK 0xDF
#define WIN_STANDBYNOW1 0xE0
#define WIN_IDLEIMMEDIATE 0xE1
#define WIN_STANDBY 0xE2
#define WIN_SETIDLE1 0xE3
#define WIN_READ_BUFFER 0xE4
#define WIN_CHECKPOWERMODE1 0xE5
#define WIN_SLEEPNOW1 0xE6
#define WIN_FLUSH_CACHE 0xE7
#define WIN_WRITE_BUFFER 0xE8
#define WIN_WRITE_SAME 0xE9
#define WIN_FLUSH_CACHE_EXT 0xEA
#define WIN_IDENTIFY 0xEC
#define WIN_MEDIAEJECT 0xED
#define WIN_IDENTIFY_DMA 0xEE
#define WIN_SETFEATURES 0xEF
#define EXABYTE_ENABLE_NEST 0xF0
#define WIN_SECURITY_SET_PASS 0xF1
#define WIN_SECURITY_UNLOCK 0xF2
#define WIN_SECURITY_ERASE_PREPARE 0xF3
#define WIN_SECURITY_ERASE_UNIT 0xF4
#define WIN_SECURITY_FREEZE_LOCK 0xF5
#define WIN_SECURITY_DISABLE 0xF6
#define WIN_READ_NATIVE_MAX 0xF8
#define WIN_SET_MAX 0xF9
#define DISABLE_SEAGATE 0xFB
#define SMART_READ_VALUES 0xD0
#define SMART_READ_THRESHOLDS 0xD1
#define SMART_AUTOSAVE 0xD2
#define SMART_SAVE 0xD3
#define SMART_IMMEDIATE_OFFLINE 0xD4
#define SMART_READ_LOG_SECTOR 0xD5
#define SMART_WRITE_LOG_SECTOR 0xD6
#define SMART_WRITE_THRESHOLDS 0xD7
#define SMART_ENABLE 0xD8
#define SMART_DISABLE 0xD9
#define SMART_STATUS 0xDA
#define SMART_AUTO_OFFLINE 0xDB
#define SMART_LCYL_PASS 0x4F
#define SMART_HCYL_PASS 0xC2
#define SETFEATURES_EN_8BIT 0x01
#define SETFEATURES_EN_WCACHE 0x02
#define SETFEATURES_DIS_DEFECT 0x04
#define SETFEATURES_EN_APM 0x05
#define SETFEATURES_EN_SAME_R 0x22
#define SETFEATURES_DIS_MSN 0x31
#define SETFEATURES_DIS_RETRY 0x33
#define SETFEATURES_EN_AAM 0x42
#define SETFEATURES_RW_LONG 0x44
#define SETFEATURES_SET_CACHE 0x54
#define SETFEATURES_DIS_RLA 0x55
#define SETFEATURES_EN_RI 0x5D
#define SETFEATURES_EN_SI 0x5E
#define SETFEATURES_DIS_RPOD 0x66
#define SETFEATURES_DIS_ECC 0x77
#define SETFEATURES_DIS_8BIT 0x81
#define SETFEATURES_DIS_WCACHE 0x82
#define SETFEATURES_EN_DEFECT 0x84
#define SETFEATURES_DIS_APM 0x85
#define SETFEATURES_EN_ECC 0x88
#define SETFEATURES_EN_MSN 0x95
#define SETFEATURES_EN_RETRY 0x99
#define SETFEATURES_EN_RLA 0xAA
#define SETFEATURES_PREFETCH 0xAB
#define SETFEATURES_EN_REST 0xAC
#define SETFEATURES_4B_RW_LONG 0xBB
#define SETFEATURES_DIS_AAM 0xC2
#define SETFEATURES_EN_RPOD 0xCC
#define SETFEATURES_DIS_RI 0xDD
#define SETFEATURES_EN_SAME_M 0xDD
#define SETFEATURES_DIS_SI 0xDE
#define SECURITY_SET_PASSWORD 0xBA
#define SECURITY_UNLOCK 0xBB
#define SECURITY_ERASE_PREPARE 0xBC
#define SECURITY_ERASE_UNIT 0xBD
#define SECURITY_FREEZE_LOCK 0xBE
#define SECURITY_DISABLE_PASSWORD 0xBF
struct hd_geometry {
  unsigned char heads;
  unsigned char sectors;
  unsigned short cylinders;
  unsigned long start;
};
#define HDIO_GETGEO 0x0301
#define HDIO_GET_UNMASKINTR 0x0302
#define HDIO_GET_MULTCOUNT 0x0304
#define HDIO_GET_QDMA 0x0305
#define HDIO_SET_XFER 0x0306
#define HDIO_OBSOLETE_IDENTITY 0x0307
#define HDIO_GET_KEEPSETTINGS 0x0308
#define HDIO_GET_32BIT 0x0309
#define HDIO_GET_NOWERR 0x030a
#define HDIO_GET_DMA 0x030b
#define HDIO_GET_NICE 0x030c
#define HDIO_GET_IDENTITY 0x030d
#define HDIO_GET_WCACHE 0x030e
#define HDIO_GET_ACOUSTIC 0x030f
#define HDIO_GET_ADDRESS 0x0310
#define HDIO_GET_BUSSTATE 0x031a
#define HDIO_TRISTATE_HWIF 0x031b
#define HDIO_DRIVE_RESET 0x031c
#define HDIO_DRIVE_TASKFILE 0x031d
#define HDIO_DRIVE_TASK 0x031e
#define HDIO_DRIVE_CMD 0x031f
#define HDIO_DRIVE_CMD_AEB HDIO_DRIVE_TASK
#define HDIO_SET_MULTCOUNT 0x0321
#define HDIO_SET_UNMASKINTR 0x0322
#define HDIO_SET_KEEPSETTINGS 0x0323
#define HDIO_SET_32BIT 0x0324
#define HDIO_SET_NOWERR 0x0325
#define HDIO_SET_DMA 0x0326
#define HDIO_SET_PIO_MODE 0x0327
#define HDIO_SCAN_HWIF 0x0328
#define HDIO_UNREGISTER_HWIF 0x032a
#define HDIO_SET_NICE 0x0329
#define HDIO_SET_WCACHE 0x032b
#define HDIO_SET_ACOUSTIC 0x032c
#define HDIO_SET_BUSSTATE 0x032d
#define HDIO_SET_QDMA 0x032e
#define HDIO_SET_ADDRESS 0x032f
enum {
  BUSSTATE_OFF = 0,
  BUSSTATE_ON,
  BUSSTATE_TRISTATE
};
#define __NEW_HD_DRIVE_ID
struct hd_driveid {
  unsigned short config;
  unsigned short cyls;
  unsigned short reserved2;
  unsigned short heads;
  unsigned short track_bytes;
  unsigned short sector_bytes;
  unsigned short sectors;
  unsigned short vendor0;
  unsigned short vendor1;
  unsigned short vendor2;
  unsigned char serial_no[20];
  unsigned short buf_type;
  unsigned short buf_size;
  unsigned short ecc_bytes;
  unsigned char fw_rev[8];
  unsigned char model[40];
  unsigned char max_multsect;
  unsigned char vendor3;
  unsigned short dword_io;
  unsigned char vendor4;
  unsigned char capability;
  unsigned short reserved50;
  unsigned char vendor5;
  unsigned char tPIO;
  unsigned char vendor6;
  unsigned char tDMA;
  unsigned short field_valid;
  unsigned short cur_cyls;
  unsigned short cur_heads;
  unsigned short cur_sectors;
  unsigned short cur_capacity0;
  unsigned short cur_capacity1;
  unsigned char multsect;
  unsigned char multsect_valid;
  unsigned int lba_capacity;
  unsigned short dma_1word;
  unsigned short dma_mword;
  unsigned short eide_pio_modes;
  unsigned short eide_dma_min;
  unsigned short eide_dma_time;
  unsigned short eide_pio;
  unsigned short eide_pio_iordy;
  unsigned short words69_70[2];
  unsigned short words71_74[4];
  unsigned short queue_depth;
  unsigned short words76_79[4];
  unsigned short major_rev_num;
  unsigned short minor_rev_num;
  unsigned short command_set_1;
  unsigned short command_set_2;
  unsigned short cfsse;
  unsigned short cfs_enable_1;
  unsigned short cfs_enable_2;
  unsigned short csf_default;
  unsigned short dma_ultra;
  unsigned short trseuc;
  unsigned short trsEuc;
  unsigned short CurAPMvalues;
  unsigned short mprc;
  unsigned short hw_config;
  unsigned short acoustic;
  unsigned short msrqs;
  unsigned short sxfert;
  unsigned short sal;
  unsigned int spg;
  unsigned long long lba_capacity_2;
  unsigned short words104_125[22];
  unsigned short last_lun;
  unsigned short word127;
  unsigned short dlf;
  unsigned short csfo;
  unsigned short words130_155[26];
  unsigned short word156;
  unsigned short words157_159[3];
  unsigned short cfa_power;
  unsigned short words161_175[15];
  unsigned short words176_205[30];
  unsigned short words206_254[49];
  unsigned short integrity_word;
};
#define IDE_NICE_DSC_OVERLAP (0)
#define IDE_NICE_ATAPI_OVERLAP (1)
#define IDE_NICE_1 (3)
#define IDE_NICE_0 (2)
#define IDE_NICE_2 (4)
#endif