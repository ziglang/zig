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
#ifndef _UAPI_LINUX_CUDA_H
#define _UAPI_LINUX_CUDA_H
#define CUDA_WARM_START 0
#define CUDA_AUTOPOLL 1
#define CUDA_GET_6805_ADDR 2
#define CUDA_GET_TIME 3
#define CUDA_GET_PRAM 7
#define CUDA_SET_6805_ADDR 8
#define CUDA_SET_TIME 9
#define CUDA_POWERDOWN 0xa
#define CUDA_POWERUP_TIME 0xb
#define CUDA_SET_PRAM 0xc
#define CUDA_MS_RESET 0xd
#define CUDA_SEND_DFAC 0xe
#define CUDA_RESET_SYSTEM 0x11
#define CUDA_SET_IPL 0x12
#define CUDA_SET_AUTO_RATE 0x14
#define CUDA_GET_AUTO_RATE 0x16
#define CUDA_SET_DEVICE_LIST 0x19
#define CUDA_GET_DEVICE_LIST 0x1a
#define CUDA_GET_SET_IIC 0x22
#endif