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
#ifndef _LINUX_VIRTIO_SCSI_H
#define _LINUX_VIRTIO_SCSI_H
#include <linux/virtio_types.h>
#define VIRTIO_SCSI_CDB_DEFAULT_SIZE 32
#define VIRTIO_SCSI_SENSE_DEFAULT_SIZE 96
#ifndef VIRTIO_SCSI_CDB_SIZE
#define VIRTIO_SCSI_CDB_SIZE VIRTIO_SCSI_CDB_DEFAULT_SIZE
#endif
#ifndef VIRTIO_SCSI_SENSE_SIZE
#define VIRTIO_SCSI_SENSE_SIZE VIRTIO_SCSI_SENSE_DEFAULT_SIZE
#endif
struct virtio_scsi_cmd_req {
  __u8 lun[8];
  __virtio64 tag;
  __u8 task_attr;
  __u8 prio;
  __u8 crn;
  __u8 cdb[VIRTIO_SCSI_CDB_SIZE];
} __attribute__((packed));
struct virtio_scsi_cmd_req_pi {
  __u8 lun[8];
  __virtio64 tag;
  __u8 task_attr;
  __u8 prio;
  __u8 crn;
  __virtio32 pi_bytesout;
  __virtio32 pi_bytesin;
  __u8 cdb[VIRTIO_SCSI_CDB_SIZE];
} __attribute__((packed));
struct virtio_scsi_cmd_resp {
  __virtio32 sense_len;
  __virtio32 resid;
  __virtio16 status_qualifier;
  __u8 status;
  __u8 response;
  __u8 sense[VIRTIO_SCSI_SENSE_SIZE];
} __attribute__((packed));
struct virtio_scsi_ctrl_tmf_req {
  __virtio32 type;
  __virtio32 subtype;
  __u8 lun[8];
  __virtio64 tag;
} __attribute__((packed));
struct virtio_scsi_ctrl_tmf_resp {
  __u8 response;
} __attribute__((packed));
struct virtio_scsi_ctrl_an_req {
  __virtio32 type;
  __u8 lun[8];
  __virtio32 event_requested;
} __attribute__((packed));
struct virtio_scsi_ctrl_an_resp {
  __virtio32 event_actual;
  __u8 response;
} __attribute__((packed));
struct virtio_scsi_event {
  __virtio32 event;
  __u8 lun[8];
  __virtio32 reason;
} __attribute__((packed));
struct virtio_scsi_config {
  __virtio32 num_queues;
  __virtio32 seg_max;
  __virtio32 max_sectors;
  __virtio32 cmd_per_lun;
  __virtio32 event_info_size;
  __virtio32 sense_size;
  __virtio32 cdb_size;
  __virtio16 max_channel;
  __virtio16 max_target;
  __virtio32 max_lun;
} __attribute__((packed));
#define VIRTIO_SCSI_F_INOUT 0
#define VIRTIO_SCSI_F_HOTPLUG 1
#define VIRTIO_SCSI_F_CHANGE 2
#define VIRTIO_SCSI_F_T10_PI 3
#define VIRTIO_SCSI_S_OK 0
#define VIRTIO_SCSI_S_OVERRUN 1
#define VIRTIO_SCSI_S_ABORTED 2
#define VIRTIO_SCSI_S_BAD_TARGET 3
#define VIRTIO_SCSI_S_RESET 4
#define VIRTIO_SCSI_S_BUSY 5
#define VIRTIO_SCSI_S_TRANSPORT_FAILURE 6
#define VIRTIO_SCSI_S_TARGET_FAILURE 7
#define VIRTIO_SCSI_S_NEXUS_FAILURE 8
#define VIRTIO_SCSI_S_FAILURE 9
#define VIRTIO_SCSI_S_FUNCTION_SUCCEEDED 10
#define VIRTIO_SCSI_S_FUNCTION_REJECTED 11
#define VIRTIO_SCSI_S_INCORRECT_LUN 12
#define VIRTIO_SCSI_T_TMF 0
#define VIRTIO_SCSI_T_AN_QUERY 1
#define VIRTIO_SCSI_T_AN_SUBSCRIBE 2
#define VIRTIO_SCSI_T_TMF_ABORT_TASK 0
#define VIRTIO_SCSI_T_TMF_ABORT_TASK_SET 1
#define VIRTIO_SCSI_T_TMF_CLEAR_ACA 2
#define VIRTIO_SCSI_T_TMF_CLEAR_TASK_SET 3
#define VIRTIO_SCSI_T_TMF_I_T_NEXUS_RESET 4
#define VIRTIO_SCSI_T_TMF_LOGICAL_UNIT_RESET 5
#define VIRTIO_SCSI_T_TMF_QUERY_TASK 6
#define VIRTIO_SCSI_T_TMF_QUERY_TASK_SET 7
#define VIRTIO_SCSI_T_EVENTS_MISSED 0x80000000
#define VIRTIO_SCSI_T_NO_EVENT 0
#define VIRTIO_SCSI_T_TRANSPORT_RESET 1
#define VIRTIO_SCSI_T_ASYNC_NOTIFY 2
#define VIRTIO_SCSI_T_PARAM_CHANGE 3
#define VIRTIO_SCSI_EVT_RESET_HARD 0
#define VIRTIO_SCSI_EVT_RESET_RESCAN 1
#define VIRTIO_SCSI_EVT_RESET_REMOVED 2
#define VIRTIO_SCSI_S_SIMPLE 0
#define VIRTIO_SCSI_S_ORDERED 1
#define VIRTIO_SCSI_S_HEAD 2
#define VIRTIO_SCSI_S_ACA 3
#endif