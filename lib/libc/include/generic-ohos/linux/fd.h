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
#ifndef _UAPI_LINUX_FD_H
#define _UAPI_LINUX_FD_H
#include <linux/ioctl.h>
#include <linux/compiler.h>
struct floppy_struct {
  unsigned int size, sect, head, track, stretch;
#define FD_STRETCH 1
#define FD_SWAPSIDES 2
#define FD_ZEROBASED 4
#define FD_SECTBASEMASK 0x3FC
#define FD_MKSECTBASE(s) (((s) ^ 1) << 2)
#define FD_SECTBASE(floppy) ((((floppy)->stretch & FD_SECTBASEMASK) >> 2) ^ 1)
  unsigned char gap, rate,
#define FD_2M 0x4
#define FD_SIZECODEMASK 0x38
#define FD_SIZECODE(floppy) (((((floppy)->rate & FD_SIZECODEMASK) >> 3) + 2) % 8)
#define FD_SECTSIZE(floppy) ((floppy)->rate & FD_2M ? 512 : 128 << FD_SIZECODE(floppy))
#define FD_PERP 0x40
  spec1, fmt_gap;
  const char * name;
};
#define FDCLRPRM _IO(2, 0x41)
#define FDSETPRM _IOW(2, 0x42, struct floppy_struct)
#define FDSETMEDIAPRM FDSETPRM
#define FDDEFPRM _IOW(2, 0x43, struct floppy_struct)
#define FDGETPRM _IOR(2, 0x04, struct floppy_struct)
#define FDDEFMEDIAPRM FDDEFPRM
#define FDGETMEDIAPRM FDGETPRM
#define FDMSGON _IO(2, 0x45)
#define FDMSGOFF _IO(2, 0x46)
#define FD_FILL_BYTE 0xF6
struct format_descr {
  unsigned int device, head, track;
};
#define FDFMTBEG _IO(2, 0x47)
#define FDFMTTRK _IOW(2, 0x48, struct format_descr)
#define FDFMTEND _IO(2, 0x49)
struct floppy_max_errors {
  unsigned int abort, read_track, reset, recal, reporting;
};
#define FDSETEMSGTRESH _IO(2, 0x4a)
#define FDFLUSH _IO(2, 0x4b)
#define FDSETMAXERRS _IOW(2, 0x4c, struct floppy_max_errors)
#define FDGETMAXERRS _IOR(2, 0x0e, struct floppy_max_errors)
typedef char floppy_drive_name[16];
#define FDGETDRVTYP _IOR(2, 0x0f, floppy_drive_name)
struct floppy_drive_params {
  signed char cmos;
  unsigned long max_dtr;
  unsigned long hlt;
  unsigned long hut;
  unsigned long srt;
  unsigned long spinup;
  unsigned long spindown;
  unsigned char spindown_offset;
  unsigned char select_delay;
  unsigned char rps;
  unsigned char tracks;
  unsigned long timeout;
  unsigned char interleave_sect;
  struct floppy_max_errors max_errors;
  char flags;
#define FTD_MSG 0x10
#define FD_BROKEN_DCL 0x20
#define FD_DEBUG 0x02
#define FD_SILENT_DCL_CLEAR 0x4
#define FD_INVERTED_DCL 0x80
  char read_track;
#define FD_AUTODETECT_SIZE 8
  short autodetect[FD_AUTODETECT_SIZE];
  int checkfreq;
  int native_format;
};
enum {
  FD_NEED_TWADDLE_BIT,
  FD_VERIFY_BIT,
  FD_DISK_NEWCHANGE_BIT,
  FD_UNUSED_BIT,
  FD_DISK_CHANGED_BIT,
  FD_DISK_WRITABLE_BIT,
  FD_OPEN_SHOULD_FAIL_BIT
};
#define FDSETDRVPRM _IOW(2, 0x90, struct floppy_drive_params)
#define FDGETDRVPRM _IOR(2, 0x11, struct floppy_drive_params)
struct floppy_drive_struct {
  unsigned long flags;
#define FD_NEED_TWADDLE (1 << FD_NEED_TWADDLE_BIT)
#define FD_VERIFY (1 << FD_VERIFY_BIT)
#define FD_DISK_NEWCHANGE (1 << FD_DISK_NEWCHANGE_BIT)
#define FD_DISK_CHANGED (1 << FD_DISK_CHANGED_BIT)
#define FD_DISK_WRITABLE (1 << FD_DISK_WRITABLE_BIT)
  unsigned long spinup_date;
  unsigned long select_date;
  unsigned long first_read_date;
  short probed_format;
  short track;
  short maxblock;
  short maxtrack;
  int generation;
  int keep_data;
  int fd_ref;
  int fd_device;
  unsigned long last_checked;
  char * dmabuf;
  int bufblocks;
};
#define FDGETDRVSTAT _IOR(2, 0x12, struct floppy_drive_struct)
#define FDPOLLDRVSTAT _IOR(2, 0x13, struct floppy_drive_struct)
enum reset_mode {
  FD_RESET_IF_NEEDED,
  FD_RESET_IF_RAWCMD,
  FD_RESET_ALWAYS
};
#define FDRESET _IO(2, 0x54)
struct floppy_fdc_state {
  int spec1;
  int spec2;
  int dtr;
  unsigned char version;
  unsigned char dor;
  unsigned long address;
  unsigned int rawcmd : 2;
  unsigned int reset : 1;
  unsigned int need_configure : 1;
  unsigned int perp_mode : 2;
  unsigned int has_fifo : 1;
  unsigned int driver_version;
#define FD_DRIVER_VERSION 0x100
  unsigned char track[4];
};
#define FDGETFDCSTAT _IOR(2, 0x15, struct floppy_fdc_state)
struct floppy_write_errors {
  unsigned int write_errors;
  unsigned long first_error_sector;
  int first_error_generation;
  unsigned long last_error_sector;
  int last_error_generation;
  unsigned int badness;
};
#define FDWERRORCLR _IO(2, 0x56)
#define FDWERRORGET _IOR(2, 0x17, struct floppy_write_errors)
#define FDHAVEBATCHEDRAWCMD
struct floppy_raw_cmd {
  unsigned int flags;
#define FD_RAW_READ 1
#define FD_RAW_WRITE 2
#define FD_RAW_NO_MOTOR 4
#define FD_RAW_DISK_CHANGE 4
#define FD_RAW_INTR 8
#define FD_RAW_SPIN 0x10
#define FD_RAW_NO_MOTOR_AFTER 0x20
#define FD_RAW_NEED_DISK 0x40
#define FD_RAW_NEED_SEEK 0x80
#define FD_RAW_MORE 0x100
#define FD_RAW_STOP_IF_FAILURE 0x200
#define FD_RAW_STOP_IF_SUCCESS 0x400
#define FD_RAW_SOFTFAILURE 0x800
#define FD_RAW_FAILURE 0x10000
#define FD_RAW_HARDFAILURE 0x20000
  void __user * data;
  char * kernel_data;
  struct floppy_raw_cmd * next;
  long length;
  long phys_length;
  int buffer_length;
  unsigned char rate;
#define FD_RAW_CMD_SIZE 16
#define FD_RAW_REPLY_SIZE 16
#define FD_RAW_CMD_FULLSIZE (FD_RAW_CMD_SIZE + 1 + FD_RAW_REPLY_SIZE)
  unsigned char cmd_count;
  union {
    struct {
      unsigned char cmd[FD_RAW_CMD_SIZE];
      unsigned char reply_count;
      unsigned char reply[FD_RAW_REPLY_SIZE];
    };
    unsigned char fullcmd[FD_RAW_CMD_FULLSIZE];
  };
  int track;
  int resultcode;
  int reserved1;
  int reserved2;
};
#define FDRAWCMD _IO(2, 0x58)
#define FDTWADDLE _IO(2, 0x59)
#define FDEJECT _IO(2, 0x5a)
#endif