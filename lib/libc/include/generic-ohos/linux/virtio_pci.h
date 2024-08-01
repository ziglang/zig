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
#ifndef _LINUX_VIRTIO_PCI_H
#define _LINUX_VIRTIO_PCI_H
#include <linux/types.h>
#ifndef VIRTIO_PCI_NO_LEGACY
#define VIRTIO_PCI_HOST_FEATURES 0
#define VIRTIO_PCI_GUEST_FEATURES 4
#define VIRTIO_PCI_QUEUE_PFN 8
#define VIRTIO_PCI_QUEUE_NUM 12
#define VIRTIO_PCI_QUEUE_SEL 14
#define VIRTIO_PCI_QUEUE_NOTIFY 16
#define VIRTIO_PCI_STATUS 18
#define VIRTIO_PCI_ISR 19
#define VIRTIO_MSI_CONFIG_VECTOR 20
#define VIRTIO_MSI_QUEUE_VECTOR 22
#define VIRTIO_PCI_CONFIG_OFF(msix_enabled) ((msix_enabled) ? 24 : 20)
#define VIRTIO_PCI_CONFIG(dev) VIRTIO_PCI_CONFIG_OFF((dev)->msix_enabled)
#define VIRTIO_PCI_ABI_VERSION 0
#define VIRTIO_PCI_QUEUE_ADDR_SHIFT 12
#define VIRTIO_PCI_VRING_ALIGN 4096
#endif
#define VIRTIO_PCI_ISR_CONFIG 0x2
#define VIRTIO_MSI_NO_VECTOR 0xffff
#ifndef VIRTIO_PCI_NO_MODERN
#define VIRTIO_PCI_CAP_COMMON_CFG 1
#define VIRTIO_PCI_CAP_NOTIFY_CFG 2
#define VIRTIO_PCI_CAP_ISR_CFG 3
#define VIRTIO_PCI_CAP_DEVICE_CFG 4
#define VIRTIO_PCI_CAP_PCI_CFG 5
#define VIRTIO_PCI_CAP_SHARED_MEMORY_CFG 8
struct virtio_pci_cap {
  __u8 cap_vndr;
  __u8 cap_next;
  __u8 cap_len;
  __u8 cfg_type;
  __u8 bar;
  __u8 id;
  __u8 padding[2];
  __le32 offset;
  __le32 length;
};
struct virtio_pci_cap64 {
  struct virtio_pci_cap cap;
  __le32 offset_hi;
  __le32 length_hi;
};
struct virtio_pci_notify_cap {
  struct virtio_pci_cap cap;
  __le32 notify_off_multiplier;
};
struct virtio_pci_common_cfg {
  __le32 device_feature_select;
  __le32 device_feature;
  __le32 guest_feature_select;
  __le32 guest_feature;
  __le16 msix_config;
  __le16 num_queues;
  __u8 device_status;
  __u8 config_generation;
  __le16 queue_select;
  __le16 queue_size;
  __le16 queue_msix_vector;
  __le16 queue_enable;
  __le16 queue_notify_off;
  __le32 queue_desc_lo;
  __le32 queue_desc_hi;
  __le32 queue_avail_lo;
  __le32 queue_avail_hi;
  __le32 queue_used_lo;
  __le32 queue_used_hi;
};
struct virtio_pci_cfg_cap {
  struct virtio_pci_cap cap;
  __u8 pci_cfg_data[4];
};
#define VIRTIO_PCI_CAP_VNDR 0
#define VIRTIO_PCI_CAP_NEXT 1
#define VIRTIO_PCI_CAP_LEN 2
#define VIRTIO_PCI_CAP_CFG_TYPE 3
#define VIRTIO_PCI_CAP_BAR 4
#define VIRTIO_PCI_CAP_OFFSET 8
#define VIRTIO_PCI_CAP_LENGTH 12
#define VIRTIO_PCI_NOTIFY_CAP_MULT 16
#define VIRTIO_PCI_COMMON_DFSELECT 0
#define VIRTIO_PCI_COMMON_DF 4
#define VIRTIO_PCI_COMMON_GFSELECT 8
#define VIRTIO_PCI_COMMON_GF 12
#define VIRTIO_PCI_COMMON_MSIX 16
#define VIRTIO_PCI_COMMON_NUMQ 18
#define VIRTIO_PCI_COMMON_STATUS 20
#define VIRTIO_PCI_COMMON_CFGGENERATION 21
#define VIRTIO_PCI_COMMON_Q_SELECT 22
#define VIRTIO_PCI_COMMON_Q_SIZE 24
#define VIRTIO_PCI_COMMON_Q_MSIX 26
#define VIRTIO_PCI_COMMON_Q_ENABLE 28
#define VIRTIO_PCI_COMMON_Q_NOFF 30
#define VIRTIO_PCI_COMMON_Q_DESCLO 32
#define VIRTIO_PCI_COMMON_Q_DESCHI 36
#define VIRTIO_PCI_COMMON_Q_AVAILLO 40
#define VIRTIO_PCI_COMMON_Q_AVAILHI 44
#define VIRTIO_PCI_COMMON_Q_USEDLO 48
#define VIRTIO_PCI_COMMON_Q_USEDHI 52
#endif
#endif