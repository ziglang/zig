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
#ifndef _MD_P_H
#define _MD_P_H
#include <linux/types.h>
#include <asm/byteorder.h>
#define MD_RESERVED_BYTES (64 * 1024)
#define MD_RESERVED_SECTORS (MD_RESERVED_BYTES / 512)
#define MD_NEW_SIZE_SECTORS(x) ((x & ~(MD_RESERVED_SECTORS - 1)) - MD_RESERVED_SECTORS)
#define MD_SB_BYTES 4096
#define MD_SB_WORDS (MD_SB_BYTES / 4)
#define MD_SB_SECTORS (MD_SB_BYTES / 512)
#define MD_SB_GENERIC_OFFSET 0
#define MD_SB_PERSONALITY_OFFSET 64
#define MD_SB_DISKS_OFFSET 128
#define MD_SB_DESCRIPTOR_OFFSET 992
#define MD_SB_GENERIC_CONSTANT_WORDS 32
#define MD_SB_GENERIC_STATE_WORDS 32
#define MD_SB_GENERIC_WORDS (MD_SB_GENERIC_CONSTANT_WORDS + MD_SB_GENERIC_STATE_WORDS)
#define MD_SB_PERSONALITY_WORDS 64
#define MD_SB_DESCRIPTOR_WORDS 32
#define MD_SB_DISKS 27
#define MD_SB_DISKS_WORDS (MD_SB_DISKS * MD_SB_DESCRIPTOR_WORDS)
#define MD_SB_RESERVED_WORDS (1024 - MD_SB_GENERIC_WORDS - MD_SB_PERSONALITY_WORDS - MD_SB_DISKS_WORDS - MD_SB_DESCRIPTOR_WORDS)
#define MD_SB_EQUAL_WORDS (MD_SB_GENERIC_WORDS + MD_SB_PERSONALITY_WORDS + MD_SB_DISKS_WORDS)
#define MD_DISK_FAULTY 0
#define MD_DISK_ACTIVE 1
#define MD_DISK_SYNC 2
#define MD_DISK_REMOVED 3
#define MD_DISK_CLUSTER_ADD 4
#define MD_DISK_CANDIDATE 5
#define MD_DISK_FAILFAST 10
#define MD_DISK_WRITEMOSTLY 9
#define MD_DISK_JOURNAL 18
#define MD_DISK_ROLE_SPARE 0xffff
#define MD_DISK_ROLE_FAULTY 0xfffe
#define MD_DISK_ROLE_JOURNAL 0xfffd
#define MD_DISK_ROLE_MAX 0xff00
typedef struct mdp_device_descriptor_s {
  __u32 number;
  __u32 major;
  __u32 minor;
  __u32 raid_disk;
  __u32 state;
  __u32 reserved[MD_SB_DESCRIPTOR_WORDS - 5];
} mdp_disk_t;
#define MD_SB_MAGIC 0xa92b4efc
#define MD_SB_CLEAN 0
#define MD_SB_ERRORS 1
#define MD_SB_CLUSTERED 5
#define MD_SB_BITMAP_PRESENT 8
typedef struct mdp_superblock_s {
  __u32 md_magic;
  __u32 major_version;
  __u32 minor_version;
  __u32 patch_version;
  __u32 gvalid_words;
  __u32 set_uuid0;
  __u32 ctime;
  __u32 level;
  __u32 size;
  __u32 nr_disks;
  __u32 raid_disks;
  __u32 md_minor;
  __u32 not_persistent;
  __u32 set_uuid1;
  __u32 set_uuid2;
  __u32 set_uuid3;
  __u32 gstate_creserved[MD_SB_GENERIC_CONSTANT_WORDS - 16];
  __u32 utime;
  __u32 state;
  __u32 active_disks;
  __u32 working_disks;
  __u32 failed_disks;
  __u32 spare_disks;
  __u32 sb_csum;
#if defined(__BYTE_ORDER) ? __BYTE_ORDER == __BIG_ENDIAN : defined(__BIG_ENDIAN)
  __u32 events_hi;
  __u32 events_lo;
  __u32 cp_events_hi;
  __u32 cp_events_lo;
#elif defined(__BYTE_ORDER)?__BYTE_ORDER==__LITTLE_ENDIAN:defined(__LITTLE_ENDIAN)
  __u32 events_lo;
  __u32 events_hi;
  __u32 cp_events_lo;
  __u32 cp_events_hi;
#else
#error unspecified endianness
#endif
  __u32 recovery_cp;
  __u64 reshape_position;
  __u32 new_level;
  __u32 delta_disks;
  __u32 new_layout;
  __u32 new_chunk;
  __u32 gstate_sreserved[MD_SB_GENERIC_STATE_WORDS - 18];
  __u32 layout;
  __u32 chunk_size;
  __u32 root_pv;
  __u32 root_block;
  __u32 pstate_reserved[MD_SB_PERSONALITY_WORDS - 4];
  mdp_disk_t disks[MD_SB_DISKS];
  __u32 reserved[MD_SB_RESERVED_WORDS];
  mdp_disk_t this_disk;
} mdp_super_t;
#define MD_SUPERBLOCK_1_TIME_SEC_MASK ((1ULL << 40) - 1)
struct mdp_superblock_1 {
  __le32 magic;
  __le32 major_version;
  __le32 feature_map;
  __le32 pad0;
  __u8 set_uuid[16];
  char set_name[32];
  __le64 ctime;
  __le32 level;
  __le32 layout;
  __le64 size;
  __le32 chunksize;
  __le32 raid_disks;
  union {
    __le32 bitmap_offset;
    struct {
      __le16 offset;
      __le16 size;
    } ppl;
  };
  __le32 new_level;
  __le64 reshape_position;
  __le32 delta_disks;
  __le32 new_layout;
  __le32 new_chunk;
  __le32 new_offset;
  __le64 data_offset;
  __le64 data_size;
  __le64 super_offset;
  union {
    __le64 recovery_offset;
    __le64 journal_tail;
  };
  __le32 dev_number;
  __le32 cnt_corrected_read;
  __u8 device_uuid[16];
  __u8 devflags;
#define WriteMostly1 1
#define FailFast1 2
  __u8 bblog_shift;
  __le16 bblog_size;
  __le32 bblog_offset;
  __le64 utime;
  __le64 events;
  __le64 resync_offset;
  __le32 sb_csum;
  __le32 max_dev;
  __u8 pad3[64 - 32];
  __le16 dev_roles[0];
};
#define MD_FEATURE_BITMAP_OFFSET 1
#define MD_FEATURE_RECOVERY_OFFSET 2
#define MD_FEATURE_RESHAPE_ACTIVE 4
#define MD_FEATURE_BAD_BLOCKS 8
#define MD_FEATURE_REPLACEMENT 16
#define MD_FEATURE_RESHAPE_BACKWARDS 32
#define MD_FEATURE_NEW_OFFSET 64
#define MD_FEATURE_RECOVERY_BITMAP 128
#define MD_FEATURE_CLUSTERED 256
#define MD_FEATURE_JOURNAL 512
#define MD_FEATURE_PPL 1024
#define MD_FEATURE_MULTIPLE_PPLS 2048
#define MD_FEATURE_RAID0_LAYOUT 4096
#define MD_FEATURE_ALL (MD_FEATURE_BITMAP_OFFSET | MD_FEATURE_RECOVERY_OFFSET | MD_FEATURE_RESHAPE_ACTIVE | MD_FEATURE_BAD_BLOCKS | MD_FEATURE_REPLACEMENT | MD_FEATURE_RESHAPE_BACKWARDS | MD_FEATURE_NEW_OFFSET | MD_FEATURE_RECOVERY_BITMAP | MD_FEATURE_CLUSTERED | MD_FEATURE_JOURNAL | MD_FEATURE_PPL | MD_FEATURE_MULTIPLE_PPLS | MD_FEATURE_RAID0_LAYOUT)
struct r5l_payload_header {
  __le16 type;
  __le16 flags;
} __attribute__((__packed__));
enum r5l_payload_type {
  R5LOG_PAYLOAD_DATA = 0,
  R5LOG_PAYLOAD_PARITY = 1,
  R5LOG_PAYLOAD_FLUSH = 2,
};
struct r5l_payload_data_parity {
  struct r5l_payload_header header;
  __le32 size;
  __le64 location;
  __le32 checksum[];
} __attribute__((__packed__));
enum r5l_payload_data_parity_flag {
  R5LOG_PAYLOAD_FLAG_DISCARD = 1,
  R5LOG_PAYLOAD_FLAG_RESHAPED = 2,
  R5LOG_PAYLOAD_FLAG_RESHAPING = 3,
};
struct r5l_payload_flush {
  struct r5l_payload_header header;
  __le32 size;
  __le64 flush_stripes[];
} __attribute__((__packed__));
enum r5l_payload_flush_flag {
  R5LOG_PAYLOAD_FLAG_FLUSH_STRIPE = 1,
};
struct r5l_meta_block {
  __le32 magic;
  __le32 checksum;
  __u8 version;
  __u8 __zero_pading_1;
  __le16 __zero_pading_2;
  __le32 meta_size;
  __le64 seq;
  __le64 position;
  struct r5l_payload_header payloads[];
} __attribute__((__packed__));
#define R5LOG_VERSION 0x1
#define R5LOG_MAGIC 0x6433c509
struct ppl_header_entry {
  __le64 data_sector;
  __le32 pp_size;
  __le32 data_size;
  __le32 parity_disk;
  __le32 checksum;
} __attribute__((__packed__));
#define PPL_HEADER_SIZE 4096
#define PPL_HDR_RESERVED 512
#define PPL_HDR_ENTRY_SPACE (PPL_HEADER_SIZE - PPL_HDR_RESERVED - 4 * sizeof(__le32) - sizeof(__le64))
#define PPL_HDR_MAX_ENTRIES (PPL_HDR_ENTRY_SPACE / sizeof(struct ppl_header_entry))
struct ppl_header {
  __u8 reserved[PPL_HDR_RESERVED];
  __le32 signature;
  __le32 padding;
  __le64 generation;
  __le32 entries_count;
  __le32 checksum;
  struct ppl_header_entry entries[PPL_HDR_MAX_ENTRIES];
} __attribute__((__packed__));
#endif