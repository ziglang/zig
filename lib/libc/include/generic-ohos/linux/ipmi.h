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
#ifndef _UAPI__LINUX_IPMI_H
#define _UAPI__LINUX_IPMI_H
#include <linux/ipmi_msgdefs.h>
#include <linux/compiler.h>
#define IPMI_MAX_ADDR_SIZE 32
struct ipmi_addr {
  int addr_type;
  short channel;
  char data[IPMI_MAX_ADDR_SIZE];
};
#define IPMI_SYSTEM_INTERFACE_ADDR_TYPE 0x0c
struct ipmi_system_interface_addr {
  int addr_type;
  short channel;
  unsigned char lun;
};
#define IPMI_IPMB_ADDR_TYPE 0x01
#define IPMI_IPMB_BROADCAST_ADDR_TYPE 0x41
struct ipmi_ipmb_addr {
  int addr_type;
  short channel;
  unsigned char slave_addr;
  unsigned char lun;
};
#define IPMI_LAN_ADDR_TYPE 0x04
struct ipmi_lan_addr {
  int addr_type;
  short channel;
  unsigned char privilege;
  unsigned char session_handle;
  unsigned char remote_SWID;
  unsigned char local_SWID;
  unsigned char lun;
};
#define IPMI_BMC_CHANNEL 0xf
#define IPMI_NUM_CHANNELS 0x10
#define IPMI_CHAN_ALL (~0)
struct ipmi_msg {
  unsigned char netfn;
  unsigned char cmd;
  unsigned short data_len;
  unsigned char __user * data;
};
struct kernel_ipmi_msg {
  unsigned char netfn;
  unsigned char cmd;
  unsigned short data_len;
  unsigned char * data;
};
#define IPMI_INVALID_CMD_COMPLETION_CODE 0xC1
#define IPMI_TIMEOUT_COMPLETION_CODE 0xC3
#define IPMI_UNKNOWN_ERR_COMPLETION_CODE 0xff
#define IPMI_RESPONSE_RECV_TYPE 1
#define IPMI_ASYNC_EVENT_RECV_TYPE 2
#define IPMI_CMD_RECV_TYPE 3
#define IPMI_RESPONSE_RESPONSE_TYPE 4
#define IPMI_OEM_RECV_TYPE 5
#define IPMI_MAINTENANCE_MODE_AUTO 0
#define IPMI_MAINTENANCE_MODE_OFF 1
#define IPMI_MAINTENANCE_MODE_ON 2
#define IPMI_IOC_MAGIC 'i'
struct ipmi_req {
  unsigned char __user * addr;
  unsigned int addr_len;
  long msgid;
  struct ipmi_msg msg;
};
#define IPMICTL_SEND_COMMAND _IOR(IPMI_IOC_MAGIC, 13, struct ipmi_req)
struct ipmi_req_settime {
  struct ipmi_req req;
  int retries;
  unsigned int retry_time_ms;
};
#define IPMICTL_SEND_COMMAND_SETTIME _IOR(IPMI_IOC_MAGIC, 21, struct ipmi_req_settime)
struct ipmi_recv {
  int recv_type;
  unsigned char __user * addr;
  unsigned int addr_len;
  long msgid;
  struct ipmi_msg msg;
};
#define IPMICTL_RECEIVE_MSG _IOWR(IPMI_IOC_MAGIC, 12, struct ipmi_recv)
#define IPMICTL_RECEIVE_MSG_TRUNC _IOWR(IPMI_IOC_MAGIC, 11, struct ipmi_recv)
struct ipmi_cmdspec {
  unsigned char netfn;
  unsigned char cmd;
};
#define IPMICTL_REGISTER_FOR_CMD _IOR(IPMI_IOC_MAGIC, 14, struct ipmi_cmdspec)
#define IPMICTL_UNREGISTER_FOR_CMD _IOR(IPMI_IOC_MAGIC, 15, struct ipmi_cmdspec)
struct ipmi_cmdspec_chans {
  unsigned int netfn;
  unsigned int cmd;
  unsigned int chans;
};
#define IPMICTL_REGISTER_FOR_CMD_CHANS _IOR(IPMI_IOC_MAGIC, 28, struct ipmi_cmdspec_chans)
#define IPMICTL_UNREGISTER_FOR_CMD_CHANS _IOR(IPMI_IOC_MAGIC, 29, struct ipmi_cmdspec_chans)
#define IPMICTL_SET_GETS_EVENTS_CMD _IOR(IPMI_IOC_MAGIC, 16, int)
struct ipmi_channel_lun_address_set {
  unsigned short channel;
  unsigned char value;
};
#define IPMICTL_SET_MY_CHANNEL_ADDRESS_CMD _IOR(IPMI_IOC_MAGIC, 24, struct ipmi_channel_lun_address_set)
#define IPMICTL_GET_MY_CHANNEL_ADDRESS_CMD _IOR(IPMI_IOC_MAGIC, 25, struct ipmi_channel_lun_address_set)
#define IPMICTL_SET_MY_CHANNEL_LUN_CMD _IOR(IPMI_IOC_MAGIC, 26, struct ipmi_channel_lun_address_set)
#define IPMICTL_GET_MY_CHANNEL_LUN_CMD _IOR(IPMI_IOC_MAGIC, 27, struct ipmi_channel_lun_address_set)
#define IPMICTL_SET_MY_ADDRESS_CMD _IOR(IPMI_IOC_MAGIC, 17, unsigned int)
#define IPMICTL_GET_MY_ADDRESS_CMD _IOR(IPMI_IOC_MAGIC, 18, unsigned int)
#define IPMICTL_SET_MY_LUN_CMD _IOR(IPMI_IOC_MAGIC, 19, unsigned int)
#define IPMICTL_GET_MY_LUN_CMD _IOR(IPMI_IOC_MAGIC, 20, unsigned int)
struct ipmi_timing_parms {
  int retries;
  unsigned int retry_time_ms;
};
#define IPMICTL_SET_TIMING_PARMS_CMD _IOR(IPMI_IOC_MAGIC, 22, struct ipmi_timing_parms)
#define IPMICTL_GET_TIMING_PARMS_CMD _IOR(IPMI_IOC_MAGIC, 23, struct ipmi_timing_parms)
#define IPMICTL_GET_MAINTENANCE_MODE_CMD _IOR(IPMI_IOC_MAGIC, 30, int)
#define IPMICTL_SET_MAINTENANCE_MODE_CMD _IOW(IPMI_IOC_MAGIC, 31, int)
#endif