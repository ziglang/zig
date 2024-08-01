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
#ifndef _UAPI_LINUX_FSCRYPT_H
#define _UAPI_LINUX_FSCRYPT_H
#include <linux/ioctl.h>
#include <linux/types.h>
#define FSCRYPT_POLICY_FLAGS_PAD_4 0x00
#define FSCRYPT_POLICY_FLAGS_PAD_8 0x01
#define FSCRYPT_POLICY_FLAGS_PAD_16 0x02
#define FSCRYPT_POLICY_FLAGS_PAD_32 0x03
#define FSCRYPT_POLICY_FLAGS_PAD_MASK 0x03
#define FSCRYPT_POLICY_FLAG_DIRECT_KEY 0x04
#define FSCRYPT_POLICY_FLAG_IV_INO_LBLK_64 0x08
#define FSCRYPT_POLICY_FLAG_IV_INO_LBLK_32 0x10
#define FSCRYPT_POLICY_FLAGS_VALID 0x1F
#define FSCRYPT_MODE_AES_256_XTS 1
#define FSCRYPT_MODE_AES_256_CTS 4
#define FSCRYPT_MODE_AES_128_CBC 5
#define FSCRYPT_MODE_AES_128_CTS 6
#define FSCRYPT_MODE_ADIANTUM 9
#define __FSCRYPT_MODE_MAX 9
#define FSCRYPT_POLICY_V1 0
#define FSCRYPT_KEY_DESCRIPTOR_SIZE 8
struct fscrypt_policy_v1 {
  __u8 version;
  __u8 contents_encryption_mode;
  __u8 filenames_encryption_mode;
  __u8 flags;
  __u8 master_key_descriptor[FSCRYPT_KEY_DESCRIPTOR_SIZE];
};
#define FSCRYPT_KEY_DESC_PREFIX "fscrypt:"
#define FSCRYPT_KEY_DESC_PREFIX_SIZE 8
#define FSCRYPT_MAX_KEY_SIZE 64
struct fscrypt_key {
  __u32 mode;
  __u8 raw[FSCRYPT_MAX_KEY_SIZE];
  __u32 size;
};
#define FSCRYPT_POLICY_V2 2
#define FSCRYPT_KEY_IDENTIFIER_SIZE 16
struct fscrypt_policy_v2 {
  __u8 version;
  __u8 contents_encryption_mode;
  __u8 filenames_encryption_mode;
  __u8 flags;
  __u8 __reserved[4];
  __u8 master_key_identifier[FSCRYPT_KEY_IDENTIFIER_SIZE];
};
struct fscrypt_get_policy_ex_arg {
  __u64 policy_size;
  union {
    __u8 version;
    struct fscrypt_policy_v1 v1;
    struct fscrypt_policy_v2 v2;
  } policy;
};
#define FSCRYPT_KEY_SPEC_TYPE_DESCRIPTOR 1
#define FSCRYPT_KEY_SPEC_TYPE_IDENTIFIER 2
struct fscrypt_key_specifier {
  __u32 type;
  __u32 __reserved;
  union {
    __u8 __reserved[32];
    __u8 descriptor[FSCRYPT_KEY_DESCRIPTOR_SIZE];
    __u8 identifier[FSCRYPT_KEY_IDENTIFIER_SIZE];
  } u;
};
struct fscrypt_provisioning_key_payload {
  __u32 type;
  __u32 __reserved;
  __u8 raw[];
};
struct fscrypt_add_key_arg {
  struct fscrypt_key_specifier key_spec;
  __u32 raw_size;
  __u32 key_id;
  __u32 __reserved[7];
#define __FSCRYPT_ADD_KEY_FLAG_HW_WRAPPED 0x00000001
  __u32 __flags;
  __u8 raw[];
};
struct fscrypt_remove_key_arg {
  struct fscrypt_key_specifier key_spec;
#define FSCRYPT_KEY_REMOVAL_STATUS_FLAG_FILES_BUSY 0x00000001
#define FSCRYPT_KEY_REMOVAL_STATUS_FLAG_OTHER_USERS 0x00000002
  __u32 removal_status_flags;
  __u32 __reserved[5];
};
struct fscrypt_get_key_status_arg {
  struct fscrypt_key_specifier key_spec;
  __u32 __reserved[6];
#define FSCRYPT_KEY_STATUS_ABSENT 1
#define FSCRYPT_KEY_STATUS_PRESENT 2
#define FSCRYPT_KEY_STATUS_INCOMPLETELY_REMOVED 3
  __u32 status;
#define FSCRYPT_KEY_STATUS_FLAG_ADDED_BY_SELF 0x00000001
  __u32 status_flags;
  __u32 user_count;
  __u32 __out_reserved[13];
};
#define FS_IOC_SET_ENCRYPTION_POLICY _IOR('f', 19, struct fscrypt_policy_v1)
#define FS_IOC_GET_ENCRYPTION_PWSALT _IOW('f', 20, __u8[16])
#define FS_IOC_GET_ENCRYPTION_POLICY _IOW('f', 21, struct fscrypt_policy_v1)
#define FS_IOC_GET_ENCRYPTION_POLICY_EX _IOWR('f', 22, __u8[9])
#define FS_IOC_ADD_ENCRYPTION_KEY _IOWR('f', 23, struct fscrypt_add_key_arg)
#define FS_IOC_REMOVE_ENCRYPTION_KEY _IOWR('f', 24, struct fscrypt_remove_key_arg)
#define FS_IOC_REMOVE_ENCRYPTION_KEY_ALL_USERS _IOWR('f', 25, struct fscrypt_remove_key_arg)
#define FS_IOC_GET_ENCRYPTION_KEY_STATUS _IOWR('f', 26, struct fscrypt_get_key_status_arg)
#define FS_IOC_GET_ENCRYPTION_NONCE _IOR('f', 27, __u8[16])
#define fscrypt_policy fscrypt_policy_v1
#define FS_KEY_DESCRIPTOR_SIZE FSCRYPT_KEY_DESCRIPTOR_SIZE
#define FS_POLICY_FLAGS_PAD_4 FSCRYPT_POLICY_FLAGS_PAD_4
#define FS_POLICY_FLAGS_PAD_8 FSCRYPT_POLICY_FLAGS_PAD_8
#define FS_POLICY_FLAGS_PAD_16 FSCRYPT_POLICY_FLAGS_PAD_16
#define FS_POLICY_FLAGS_PAD_32 FSCRYPT_POLICY_FLAGS_PAD_32
#define FS_POLICY_FLAGS_PAD_MASK FSCRYPT_POLICY_FLAGS_PAD_MASK
#define FS_POLICY_FLAG_DIRECT_KEY FSCRYPT_POLICY_FLAG_DIRECT_KEY
#define FS_POLICY_FLAGS_VALID FSCRYPT_POLICY_FLAGS_VALID
#define FS_ENCRYPTION_MODE_INVALID 0
#define FS_ENCRYPTION_MODE_AES_256_XTS FSCRYPT_MODE_AES_256_XTS
#define FS_ENCRYPTION_MODE_AES_256_GCM 2
#define FS_ENCRYPTION_MODE_AES_256_CBC 3
#define FS_ENCRYPTION_MODE_AES_256_CTS FSCRYPT_MODE_AES_256_CTS
#define FS_ENCRYPTION_MODE_AES_128_CBC FSCRYPT_MODE_AES_128_CBC
#define FS_ENCRYPTION_MODE_AES_128_CTS FSCRYPT_MODE_AES_128_CTS
#define FS_ENCRYPTION_MODE_SPECK128_256_XTS 7
#define FS_ENCRYPTION_MODE_SPECK128_256_CTS 8
#define FS_ENCRYPTION_MODE_ADIANTUM FSCRYPT_MODE_ADIANTUM
#define FS_KEY_DESC_PREFIX FSCRYPT_KEY_DESC_PREFIX
#define FS_KEY_DESC_PREFIX_SIZE FSCRYPT_KEY_DESC_PREFIX_SIZE
#define FS_MAX_KEY_SIZE FSCRYPT_MAX_KEY_SIZE
#endif