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
#ifndef __INCLUDE_UAPI_SOUND_SOF_ABI_H__
#define __INCLUDE_UAPI_SOUND_SOF_ABI_H__
#define SOF_ABI_MAJOR 3
#define SOF_ABI_MINOR 17
#define SOF_ABI_PATCH 0
#define SOF_ABI_MAJOR_SHIFT 24
#define SOF_ABI_MAJOR_MASK 0xff
#define SOF_ABI_MINOR_SHIFT 12
#define SOF_ABI_MINOR_MASK 0xfff
#define SOF_ABI_PATCH_SHIFT 0
#define SOF_ABI_PATCH_MASK 0xfff
#define SOF_ABI_VER(major,minor,patch) (((major) << SOF_ABI_MAJOR_SHIFT) | ((minor) << SOF_ABI_MINOR_SHIFT) | ((patch) << SOF_ABI_PATCH_SHIFT))
#define SOF_ABI_VERSION_MAJOR(version) (((version) >> SOF_ABI_MAJOR_SHIFT) & SOF_ABI_MAJOR_MASK)
#define SOF_ABI_VERSION_MINOR(version) (((version) >> SOF_ABI_MINOR_SHIFT) & SOF_ABI_MINOR_MASK)
#define SOF_ABI_VERSION_PATCH(version) (((version) >> SOF_ABI_PATCH_SHIFT) & SOF_ABI_PATCH_MASK)
#define SOF_ABI_VERSION_INCOMPATIBLE(sof_ver,client_ver) (SOF_ABI_VERSION_MAJOR((sof_ver)) != SOF_ABI_VERSION_MAJOR((client_ver)))
#define SOF_ABI_VERSION SOF_ABI_VER(SOF_ABI_MAJOR, SOF_ABI_MINOR, SOF_ABI_PATCH)
#define SOF_ABI_MAGIC 0x00464F53
#endif