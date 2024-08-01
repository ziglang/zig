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
#ifndef __GENWQE_CARD_H__
#define __GENWQE_CARD_H__
#include <linux/types.h>
#include <linux/ioctl.h>
#define GENWQE_DEVNAME "genwqe"
#define GENWQE_TYPE_ALTERA_230 0x00
#define GENWQE_TYPE_ALTERA_530 0x01
#define GENWQE_TYPE_ALTERA_A4 0x02
#define GENWQE_TYPE_ALTERA_A7 0x03
#define GENWQE_UID_OFFS(uid) ((uid) << 24)
#define GENWQE_SLU_OFFS GENWQE_UID_OFFS(0)
#define GENWQE_HSU_OFFS GENWQE_UID_OFFS(1)
#define GENWQE_APP_OFFS GENWQE_UID_OFFS(2)
#define GENWQE_MAX_UNITS 3
#define IO_EXTENDED_ERROR_POINTER 0x00000048
#define IO_ERROR_INJECT_SELECTOR 0x00000060
#define IO_EXTENDED_DIAG_SELECTOR 0x00000070
#define IO_EXTENDED_DIAG_READ_MBX 0x00000078
#define IO_EXTENDED_DIAG_MAP(ring) (0x00000500 | ((ring) << 3))
#define GENWQE_EXTENDED_DIAG_SELECTOR(ring,trace) (((ring) << 8) | (trace))
#define IO_SLU_UNITCFG 0x00000000
#define IO_SLU_UNITCFG_TYPE_MASK 0x000000000ff00000
#define IO_SLU_FIR 0x00000008
#define IO_SLU_FIR_CLR 0x00000010
#define IO_SLU_FEC 0x00000018
#define IO_SLU_ERR_ACT_MASK 0x00000020
#define IO_SLU_ERR_ATTN_MASK 0x00000028
#define IO_SLU_FIRX1_ACT_MASK 0x00000030
#define IO_SLU_FIRX0_ACT_MASK 0x00000038
#define IO_SLU_SEC_LEM_DEBUG_OVR 0x00000040
#define IO_SLU_EXTENDED_ERR_PTR 0x00000048
#define IO_SLU_COMMON_CONFIG 0x00000060
#define IO_SLU_FLASH_FIR 0x00000108
#define IO_SLU_SLC_FIR 0x00000110
#define IO_SLU_RIU_TRAP 0x00000280
#define IO_SLU_FLASH_FEC 0x00000308
#define IO_SLU_SLC_FEC 0x00000310
#define IO_SLC_QUEUE_SEGMENT 0x00010000
#define IO_SLC_VF_QUEUE_SEGMENT 0x00050000
#define IO_SLC_QUEUE_OFFSET 0x00010008
#define IO_SLC_VF_QUEUE_OFFSET 0x00050008
#define IO_SLC_QUEUE_CONFIG 0x00010010
#define IO_SLC_VF_QUEUE_CONFIG 0x00050010
#define IO_SLC_APPJOB_TIMEOUT 0x00010018
#define IO_SLC_VF_APPJOB_TIMEOUT 0x00050018
#define TIMEOUT_250MS 0x0000000f
#define HEARTBEAT_DISABLE 0x0000ff00
#define IO_SLC_QUEUE_INITSQN 0x00010020
#define IO_SLC_VF_QUEUE_INITSQN 0x00050020
#define IO_SLC_QUEUE_WRAP 0x00010028
#define IO_SLC_VF_QUEUE_WRAP 0x00050028
#define IO_SLC_QUEUE_STATUS 0x00010100
#define IO_SLC_VF_QUEUE_STATUS 0x00050100
#define IO_SLC_QUEUE_WTIME 0x00010030
#define IO_SLC_VF_QUEUE_WTIME 0x00050030
#define IO_SLC_QUEUE_ERRCNTS 0x00010038
#define IO_SLC_VF_QUEUE_ERRCNTS 0x00050038
#define IO_SLC_QUEUE_LRW 0x00010040
#define IO_SLC_VF_QUEUE_LRW 0x00050040
#define IO_SLC_FREE_RUNNING_TIMER 0x00010108
#define IO_SLC_VF_FREE_RUNNING_TIMER 0x00050108
#define IO_PF_SLC_VIRTUAL_REGION 0x00050000
#define IO_PF_SLC_VIRTUAL_WINDOW 0x00060000
#define IO_PF_SLC_JOBPEND(n) (0x00061000 + 8 * (n))
#define IO_SLC_JOBPEND(n) IO_PF_SLC_JOBPEND(n)
#define IO_SLU_SLC_PARSE_TRAP(n) (0x00011000 + 8 * (n))
#define IO_SLU_SLC_DISP_TRAP(n) (0x00011200 + 8 * (n))
#define IO_SLC_CFGREG_GFIR 0x00020000
#define GFIR_ERR_TRIGGER 0x0000ffff
#define IO_SLC_CFGREG_SOFTRESET 0x00020018
#define IO_SLC_MISC_DEBUG 0x00020060
#define IO_SLC_MISC_DEBUG_CLR 0x00020068
#define IO_SLC_MISC_DEBUG_SET 0x00020070
#define IO_SLU_TEMPERATURE_SENSOR 0x00030000
#define IO_SLU_TEMPERATURE_CONFIG 0x00030008
#define IO_SLU_VOLTAGE_CONTROL 0x00030080
#define IO_SLU_VOLTAGE_NOMINAL 0x00000000
#define IO_SLU_VOLTAGE_DOWN5 0x00000006
#define IO_SLU_VOLTAGE_UP5 0x00000007
#define IO_SLU_LEDCONTROL 0x00030100
#define IO_SLU_FLASH_DIRECTACCESS 0x00040010
#define IO_SLU_FLASH_DIRECTACCESS2 0x00040020
#define IO_SLU_FLASH_CMDINTF 0x00040030
#define IO_SLU_BITSTREAM 0x00040040
#define IO_HSU_ERR_BEHAVIOR 0x01001010
#define IO_SLC2_SQB_TRAP 0x00062000
#define IO_SLC2_QUEUE_MANAGER_TRAP 0x00062008
#define IO_SLC2_FLS_MASTER_TRAP 0x00062010
#define IO_HSU_UNITCFG 0x01000000
#define IO_HSU_FIR 0x01000008
#define IO_HSU_FIR_CLR 0x01000010
#define IO_HSU_FEC 0x01000018
#define IO_HSU_ERR_ACT_MASK 0x01000020
#define IO_HSU_ERR_ATTN_MASK 0x01000028
#define IO_HSU_FIRX1_ACT_MASK 0x01000030
#define IO_HSU_FIRX0_ACT_MASK 0x01000038
#define IO_HSU_SEC_LEM_DEBUG_OVR 0x01000040
#define IO_HSU_EXTENDED_ERR_PTR 0x01000048
#define IO_HSU_COMMON_CONFIG 0x01000060
#define IO_APP_UNITCFG 0x02000000
#define IO_APP_FIR 0x02000008
#define IO_APP_FIR_CLR 0x02000010
#define IO_APP_FEC 0x02000018
#define IO_APP_ERR_ACT_MASK 0x02000020
#define IO_APP_ERR_ATTN_MASK 0x02000028
#define IO_APP_FIRX1_ACT_MASK 0x02000030
#define IO_APP_FIRX0_ACT_MASK 0x02000038
#define IO_APP_SEC_LEM_DEBUG_OVR 0x02000040
#define IO_APP_EXTENDED_ERR_PTR 0x02000048
#define IO_APP_COMMON_CONFIG 0x02000060
#define IO_APP_DEBUG_REG_01 0x02010000
#define IO_APP_DEBUG_REG_02 0x02010008
#define IO_APP_DEBUG_REG_03 0x02010010
#define IO_APP_DEBUG_REG_04 0x02010018
#define IO_APP_DEBUG_REG_05 0x02010020
#define IO_APP_DEBUG_REG_06 0x02010028
#define IO_APP_DEBUG_REG_07 0x02010030
#define IO_APP_DEBUG_REG_08 0x02010038
#define IO_APP_DEBUG_REG_09 0x02010040
#define IO_APP_DEBUG_REG_10 0x02010048
#define IO_APP_DEBUG_REG_11 0x02010050
#define IO_APP_DEBUG_REG_12 0x02010058
#define IO_APP_DEBUG_REG_13 0x02010060
#define IO_APP_DEBUG_REG_14 0x02010068
#define IO_APP_DEBUG_REG_15 0x02010070
#define IO_APP_DEBUG_REG_16 0x02010078
#define IO_APP_DEBUG_REG_17 0x02010080
#define IO_APP_DEBUG_REG_18 0x02010088
struct genwqe_reg_io {
  __u64 num;
  __u64 val64;
};
#define IO_ILLEGAL_VALUE 0xffffffffffffffffull
#define DDCB_ACFUNC_SLU 0x00
#define DDCB_ACFUNC_APP 0x01
#define DDCB_RETC_IDLE 0x0000
#define DDCB_RETC_PENDING 0x0101
#define DDCB_RETC_COMPLETE 0x0102
#define DDCB_RETC_FAULT 0x0104
#define DDCB_RETC_ERROR 0x0108
#define DDCB_RETC_FORCED_ERROR 0x01ff
#define DDCB_RETC_UNEXEC 0x0110
#define DDCB_RETC_TERM 0x0120
#define DDCB_RETC_RES0 0x0140
#define DDCB_RETC_RES1 0x0180
#define DDCB_OPT_ECHO_FORCE_NO 0x0000
#define DDCB_OPT_ECHO_FORCE_102 0x0001
#define DDCB_OPT_ECHO_FORCE_104 0x0002
#define DDCB_OPT_ECHO_FORCE_108 0x0003
#define DDCB_OPT_ECHO_FORCE_110 0x0004
#define DDCB_OPT_ECHO_FORCE_120 0x0005
#define DDCB_OPT_ECHO_FORCE_140 0x0006
#define DDCB_OPT_ECHO_FORCE_180 0x0007
#define DDCB_OPT_ECHO_COPY_NONE (0 << 5)
#define DDCB_OPT_ECHO_COPY_ALL (1 << 5)
#define SLCMD_ECHO_SYNC 0x00
#define SLCMD_MOVE_FLASH 0x06
#define SLCMD_MOVE_FLASH_FLAGS_MODE 0x03
#define SLCMD_MOVE_FLASH_FLAGS_DLOAD 0
#define SLCMD_MOVE_FLASH_FLAGS_EMUL 1
#define SLCMD_MOVE_FLASH_FLAGS_UPLOAD 2
#define SLCMD_MOVE_FLASH_FLAGS_VERIFY 3
#define SLCMD_MOVE_FLASH_FLAG_NOTAP (1 << 2)
#define SLCMD_MOVE_FLASH_FLAG_POLL (1 << 3)
#define SLCMD_MOVE_FLASH_FLAG_PARTITION (1 << 4)
#define SLCMD_MOVE_FLASH_FLAG_ERASE (1 << 5)
enum genwqe_card_state {
  GENWQE_CARD_UNUSED = 0,
  GENWQE_CARD_USED = 1,
  GENWQE_CARD_FATAL_ERROR = 2,
  GENWQE_CARD_RELOAD_BITSTREAM = 3,
  GENWQE_CARD_STATE_MAX,
};
struct genwqe_bitstream {
  __u64 data_addr;
  __u32 size;
  __u32 crc;
  __u64 target_addr;
  __u32 partition;
  __u32 uid;
  __u64 slu_id;
  __u64 app_id;
  __u16 retc;
  __u16 attn;
  __u32 progress;
};
#define DDCB_LENGTH 256
#define DDCB_ASIV_LENGTH 104
#define DDCB_ASIV_LENGTH_ATS 96
#define DDCB_ASV_LENGTH 64
#define DDCB_FIXUPS 12
struct genwqe_debug_data {
  char driver_version[64];
  __u64 slu_unitcfg;
  __u64 app_unitcfg;
  __u8 ddcb_before[DDCB_LENGTH];
  __u8 ddcb_prev[DDCB_LENGTH];
  __u8 ddcb_finished[DDCB_LENGTH];
};
#define ATS_TYPE_DATA 0x0ull
#define ATS_TYPE_FLAT_RD 0x4ull
#define ATS_TYPE_FLAT_RDWR 0x5ull
#define ATS_TYPE_SGL_RD 0x6ull
#define ATS_TYPE_SGL_RDWR 0x7ull
#define ATS_SET_FLAGS(_struct,_field,_flags) (((_flags) & 0xf) << (44 - (4 * (offsetof(_struct, _field) / 8))))
#define ATS_GET_FLAGS(_ats,_byte_offs) (((_ats) >> (44 - (4 * ((_byte_offs) / 8)))) & 0xf)
struct genwqe_ddcb_cmd {
  __u64 next_addr;
  __u64 flags;
  __u8 acfunc;
  __u8 cmd;
  __u8 asiv_length;
  __u8 asv_length;
  __u16 cmdopts;
  __u16 retc;
  __u16 attn;
  __u16 vcrc;
  __u32 progress;
  __u64 deque_ts;
  __u64 cmplt_ts;
  __u64 disp_ts;
  __u64 ddata_addr;
  __u8 asv[DDCB_ASV_LENGTH];
  union {
    struct {
      __u64 ats;
      __u8 asiv[DDCB_ASIV_LENGTH_ATS];
    };
    __u8 __asiv[DDCB_ASIV_LENGTH];
  };
};
#define GENWQE_IOC_CODE 0xa5
#define GENWQE_READ_REG64 _IOR(GENWQE_IOC_CODE, 30, struct genwqe_reg_io)
#define GENWQE_WRITE_REG64 _IOW(GENWQE_IOC_CODE, 31, struct genwqe_reg_io)
#define GENWQE_READ_REG32 _IOR(GENWQE_IOC_CODE, 32, struct genwqe_reg_io)
#define GENWQE_WRITE_REG32 _IOW(GENWQE_IOC_CODE, 33, struct genwqe_reg_io)
#define GENWQE_READ_REG16 _IOR(GENWQE_IOC_CODE, 34, struct genwqe_reg_io)
#define GENWQE_WRITE_REG16 _IOW(GENWQE_IOC_CODE, 35, struct genwqe_reg_io)
#define GENWQE_GET_CARD_STATE _IOR(GENWQE_IOC_CODE, 36, enum genwqe_card_state)
struct genwqe_mem {
  __u64 addr;
  __u64 size;
  __u64 direction;
  __u64 flags;
};
#define GENWQE_PIN_MEM _IOWR(GENWQE_IOC_CODE, 40, struct genwqe_mem)
#define GENWQE_UNPIN_MEM _IOWR(GENWQE_IOC_CODE, 41, struct genwqe_mem)
#define GENWQE_EXECUTE_DDCB _IOWR(GENWQE_IOC_CODE, 50, struct genwqe_ddcb_cmd)
#define GENWQE_EXECUTE_RAW_DDCB _IOWR(GENWQE_IOC_CODE, 51, struct genwqe_ddcb_cmd)
#define GENWQE_SLU_UPDATE _IOWR(GENWQE_IOC_CODE, 80, struct genwqe_bitstream)
#define GENWQE_SLU_READ _IOWR(GENWQE_IOC_CODE, 81, struct genwqe_bitstream)
#endif