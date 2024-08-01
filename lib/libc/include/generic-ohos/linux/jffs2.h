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
#ifndef __LINUX_JFFS2_H__
#define __LINUX_JFFS2_H__
#include <linux/types.h>
#include <linux/magic.h>
#define JFFS2_OLD_MAGIC_BITMASK 0x1984
#define JFFS2_MAGIC_BITMASK 0x1985
#define KSAMTIB_CIGAM_2SFFJ 0x8519
#define JFFS2_EMPTY_BITMASK 0xffff
#define JFFS2_DIRTY_BITMASK 0x0000
#define JFFS2_SUM_MAGIC 0x02851885
#define JFFS2_MAX_NAME_LEN 254
#define JFFS2_MIN_DATA_LEN 128
#define JFFS2_COMPR_NONE 0x00
#define JFFS2_COMPR_ZERO 0x01
#define JFFS2_COMPR_RTIME 0x02
#define JFFS2_COMPR_RUBINMIPS 0x03
#define JFFS2_COMPR_COPY 0x04
#define JFFS2_COMPR_DYNRUBIN 0x05
#define JFFS2_COMPR_ZLIB 0x06
#define JFFS2_COMPR_LZO 0x07
#define JFFS2_COMPAT_MASK 0xc000
#define JFFS2_NODE_ACCURATE 0x2000
#define JFFS2_FEATURE_INCOMPAT 0xc000
#define JFFS2_FEATURE_ROCOMPAT 0x8000
#define JFFS2_FEATURE_RWCOMPAT_COPY 0x4000
#define JFFS2_FEATURE_RWCOMPAT_DELETE 0x0000
#define JFFS2_NODETYPE_DIRENT (JFFS2_FEATURE_INCOMPAT | JFFS2_NODE_ACCURATE | 1)
#define JFFS2_NODETYPE_INODE (JFFS2_FEATURE_INCOMPAT | JFFS2_NODE_ACCURATE | 2)
#define JFFS2_NODETYPE_CLEANMARKER (JFFS2_FEATURE_RWCOMPAT_DELETE | JFFS2_NODE_ACCURATE | 3)
#define JFFS2_NODETYPE_PADDING (JFFS2_FEATURE_RWCOMPAT_DELETE | JFFS2_NODE_ACCURATE | 4)
#define JFFS2_NODETYPE_SUMMARY (JFFS2_FEATURE_RWCOMPAT_DELETE | JFFS2_NODE_ACCURATE | 6)
#define JFFS2_NODETYPE_XATTR (JFFS2_FEATURE_INCOMPAT | JFFS2_NODE_ACCURATE | 8)
#define JFFS2_NODETYPE_XREF (JFFS2_FEATURE_INCOMPAT | JFFS2_NODE_ACCURATE | 9)
#define JFFS2_XPREFIX_USER 1
#define JFFS2_XPREFIX_SECURITY 2
#define JFFS2_XPREFIX_ACL_ACCESS 3
#define JFFS2_XPREFIX_ACL_DEFAULT 4
#define JFFS2_XPREFIX_TRUSTED 5
#define JFFS2_ACL_VERSION 0x0001
#define JFFS2_INO_FLAG_PREREAD 1
#define JFFS2_INO_FLAG_USERCOMPR 2
typedef struct {
  __u32 v32;
} __attribute__((packed)) jint32_t;
typedef struct {
  __u32 m;
} __attribute__((packed)) jmode_t;
typedef struct {
  __u16 v16;
} __attribute__((packed)) jint16_t;
struct jffs2_unknown_node {
  jint16_t magic;
  jint16_t nodetype;
  jint32_t totlen;
  jint32_t hdr_crc;
};
struct jffs2_raw_dirent {
  jint16_t magic;
  jint16_t nodetype;
  jint32_t totlen;
  jint32_t hdr_crc;
  jint32_t pino;
  jint32_t version;
  jint32_t ino;
  jint32_t mctime;
  __u8 nsize;
  __u8 type;
  __u8 unused[2];
  jint32_t node_crc;
  jint32_t name_crc;
  __u8 name[0];
};
struct jffs2_raw_inode {
  jint16_t magic;
  jint16_t nodetype;
  jint32_t totlen;
  jint32_t hdr_crc;
  jint32_t ino;
  jint32_t version;
  jmode_t mode;
  jint16_t uid;
  jint16_t gid;
  jint32_t isize;
  jint32_t atime;
  jint32_t mtime;
  jint32_t ctime;
  jint32_t offset;
  jint32_t csize;
  jint32_t dsize;
  __u8 compr;
  __u8 usercompr;
  jint16_t flags;
  jint32_t data_crc;
  jint32_t node_crc;
  __u8 data[0];
};
struct jffs2_raw_xattr {
  jint16_t magic;
  jint16_t nodetype;
  jint32_t totlen;
  jint32_t hdr_crc;
  jint32_t xid;
  jint32_t version;
  __u8 xprefix;
  __u8 name_len;
  jint16_t value_len;
  jint32_t data_crc;
  jint32_t node_crc;
  __u8 data[0];
} __attribute__((packed));
struct jffs2_raw_xref {
  jint16_t magic;
  jint16_t nodetype;
  jint32_t totlen;
  jint32_t hdr_crc;
  jint32_t ino;
  jint32_t xid;
  jint32_t xseqno;
  jint32_t node_crc;
} __attribute__((packed));
struct jffs2_raw_summary {
  jint16_t magic;
  jint16_t nodetype;
  jint32_t totlen;
  jint32_t hdr_crc;
  jint32_t sum_num;
  jint32_t cln_mkr;
  jint32_t padded;
  jint32_t sum_crc;
  jint32_t node_crc;
  jint32_t sum[0];
};
union jffs2_node_union {
  struct jffs2_raw_inode i;
  struct jffs2_raw_dirent d;
  struct jffs2_raw_xattr x;
  struct jffs2_raw_xref r;
  struct jffs2_raw_summary s;
  struct jffs2_unknown_node u;
};
union jffs2_device_node {
  jint16_t old_id;
  jint32_t new_id;
};
#endif