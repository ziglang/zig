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
#ifndef _UAPI_VM_SOCKETS_H
#define _UAPI_VM_SOCKETS_H
#include <linux/socket.h>
#define SO_VM_SOCKETS_BUFFER_SIZE 0
#define SO_VM_SOCKETS_BUFFER_MIN_SIZE 1
#define SO_VM_SOCKETS_BUFFER_MAX_SIZE 2
#define SO_VM_SOCKETS_PEER_HOST_VM_ID 3
#define SO_VM_SOCKETS_TRUSTED 5
#define SO_VM_SOCKETS_CONNECT_TIMEOUT 6
#define SO_VM_SOCKETS_NONBLOCK_TXRX 7
#define VMADDR_CID_ANY - 1U
#define VMADDR_PORT_ANY - 1U
#define VMADDR_CID_HYPERVISOR 0
#define VMADDR_CID_LOCAL 1
#define VMADDR_CID_HOST 2
#define VM_SOCKETS_INVALID_VERSION - 1U
#define VM_SOCKETS_VERSION_EPOCH(_v) (((_v) & 0xFF000000) >> 24)
#define VM_SOCKETS_VERSION_MAJOR(_v) (((_v) & 0x00FF0000) >> 16)
#define VM_SOCKETS_VERSION_MINOR(_v) (((_v) & 0x0000FFFF))
struct sockaddr_vm {
  __kernel_sa_family_t svm_family;
  unsigned short svm_reserved1;
  unsigned int svm_port;
  unsigned int svm_cid;
  unsigned char svm_zero[sizeof(struct sockaddr) - sizeof(sa_family_t) - sizeof(unsigned short) - sizeof(unsigned int) - sizeof(unsigned int)];
};
#define IOCTL_VM_SOCKETS_GET_LOCAL_CID _IO(7, 0xb9)
#endif