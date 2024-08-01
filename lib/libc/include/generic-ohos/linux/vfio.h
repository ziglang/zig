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
#ifndef _UAPIVFIO_H
#define _UAPIVFIO_H
#include <linux/types.h>
#include <linux/ioctl.h>
#define VFIO_API_VERSION 0
#define VFIO_TYPE1_IOMMU 1
#define VFIO_SPAPR_TCE_IOMMU 2
#define VFIO_TYPE1v2_IOMMU 3
#define VFIO_DMA_CC_IOMMU 4
#define VFIO_EEH 5
#define VFIO_TYPE1_NESTING_IOMMU 6
#define VFIO_SPAPR_TCE_v2_IOMMU 7
#define VFIO_NOIOMMU_IOMMU 8
#define VFIO_TYPE (';')
#define VFIO_BASE 100
struct vfio_info_cap_header {
  __u16 id;
  __u16 version;
  __u32 next;
};
#define VFIO_GET_API_VERSION _IO(VFIO_TYPE, VFIO_BASE + 0)
#define VFIO_CHECK_EXTENSION _IO(VFIO_TYPE, VFIO_BASE + 1)
#define VFIO_SET_IOMMU _IO(VFIO_TYPE, VFIO_BASE + 2)
struct vfio_group_status {
  __u32 argsz;
  __u32 flags;
#define VFIO_GROUP_FLAGS_VIABLE (1 << 0)
#define VFIO_GROUP_FLAGS_CONTAINER_SET (1 << 1)
};
#define VFIO_GROUP_GET_STATUS _IO(VFIO_TYPE, VFIO_BASE + 3)
#define VFIO_GROUP_SET_CONTAINER _IO(VFIO_TYPE, VFIO_BASE + 4)
#define VFIO_GROUP_UNSET_CONTAINER _IO(VFIO_TYPE, VFIO_BASE + 5)
#define VFIO_GROUP_GET_DEVICE_FD _IO(VFIO_TYPE, VFIO_BASE + 6)
struct vfio_device_info {
  __u32 argsz;
  __u32 flags;
#define VFIO_DEVICE_FLAGS_RESET (1 << 0)
#define VFIO_DEVICE_FLAGS_PCI (1 << 1)
#define VFIO_DEVICE_FLAGS_PLATFORM (1 << 2)
#define VFIO_DEVICE_FLAGS_AMBA (1 << 3)
#define VFIO_DEVICE_FLAGS_CCW (1 << 4)
#define VFIO_DEVICE_FLAGS_AP (1 << 5)
#define VFIO_DEVICE_FLAGS_FSL_MC (1 << 6)
#define VFIO_DEVICE_FLAGS_CAPS (1 << 7)
  __u32 num_regions;
  __u32 num_irqs;
  __u32 cap_offset;
};
#define VFIO_DEVICE_GET_INFO _IO(VFIO_TYPE, VFIO_BASE + 7)
#define VFIO_DEVICE_API_PCI_STRING "vfio-pci"
#define VFIO_DEVICE_API_PLATFORM_STRING "vfio-platform"
#define VFIO_DEVICE_API_AMBA_STRING "vfio-amba"
#define VFIO_DEVICE_API_CCW_STRING "vfio-ccw"
#define VFIO_DEVICE_API_AP_STRING "vfio-ap"
#define VFIO_DEVICE_INFO_CAP_ZPCI_BASE 1
#define VFIO_DEVICE_INFO_CAP_ZPCI_GROUP 2
#define VFIO_DEVICE_INFO_CAP_ZPCI_UTIL 3
#define VFIO_DEVICE_INFO_CAP_ZPCI_PFIP 4
struct vfio_region_info {
  __u32 argsz;
  __u32 flags;
#define VFIO_REGION_INFO_FLAG_READ (1 << 0)
#define VFIO_REGION_INFO_FLAG_WRITE (1 << 1)
#define VFIO_REGION_INFO_FLAG_MMAP (1 << 2)
#define VFIO_REGION_INFO_FLAG_CAPS (1 << 3)
  __u32 index;
  __u32 cap_offset;
  __u64 size;
  __u64 offset;
};
#define VFIO_DEVICE_GET_REGION_INFO _IO(VFIO_TYPE, VFIO_BASE + 8)
#define VFIO_REGION_INFO_CAP_SPARSE_MMAP 1
struct vfio_region_sparse_mmap_area {
  __u64 offset;
  __u64 size;
};
struct vfio_region_info_cap_sparse_mmap {
  struct vfio_info_cap_header header;
  __u32 nr_areas;
  __u32 reserved;
  struct vfio_region_sparse_mmap_area areas[];
};
#define VFIO_REGION_INFO_CAP_TYPE 2
struct vfio_region_info_cap_type {
  struct vfio_info_cap_header header;
  __u32 type;
  __u32 subtype;
};
#define VFIO_REGION_TYPE_PCI_VENDOR_TYPE (1 << 31)
#define VFIO_REGION_TYPE_PCI_VENDOR_MASK (0xffff)
#define VFIO_REGION_TYPE_GFX (1)
#define VFIO_REGION_TYPE_CCW (2)
#define VFIO_REGION_TYPE_MIGRATION (3)
#define VFIO_REGION_SUBTYPE_INTEL_IGD_OPREGION (1)
#define VFIO_REGION_SUBTYPE_INTEL_IGD_HOST_CFG (2)
#define VFIO_REGION_SUBTYPE_INTEL_IGD_LPC_CFG (3)
#define VFIO_REGION_SUBTYPE_NVIDIA_NVLINK2_RAM (1)
#define VFIO_REGION_SUBTYPE_IBM_NVLINK2_ATSD (1)
#define VFIO_REGION_SUBTYPE_GFX_EDID (1)
struct vfio_region_gfx_edid {
  __u32 edid_offset;
  __u32 edid_max_size;
  __u32 edid_size;
  __u32 max_xres;
  __u32 max_yres;
  __u32 link_state;
#define VFIO_DEVICE_GFX_LINK_STATE_UP 1
#define VFIO_DEVICE_GFX_LINK_STATE_DOWN 2
};
#define VFIO_REGION_SUBTYPE_CCW_ASYNC_CMD (1)
#define VFIO_REGION_SUBTYPE_CCW_SCHIB (2)
#define VFIO_REGION_SUBTYPE_CCW_CRW (3)
#define VFIO_REGION_SUBTYPE_MIGRATION (1)
struct vfio_device_migration_info {
  __u32 device_state;
#define VFIO_DEVICE_STATE_STOP (0)
#define VFIO_DEVICE_STATE_RUNNING (1 << 0)
#define VFIO_DEVICE_STATE_SAVING (1 << 1)
#define VFIO_DEVICE_STATE_RESUMING (1 << 2)
#define VFIO_DEVICE_STATE_MASK (VFIO_DEVICE_STATE_RUNNING | VFIO_DEVICE_STATE_SAVING | VFIO_DEVICE_STATE_RESUMING)
#define VFIO_DEVICE_STATE_VALID(state) (state & VFIO_DEVICE_STATE_RESUMING ? (state & VFIO_DEVICE_STATE_MASK) == VFIO_DEVICE_STATE_RESUMING : 1)
#define VFIO_DEVICE_STATE_IS_ERROR(state) ((state & VFIO_DEVICE_STATE_MASK) == (VFIO_DEVICE_STATE_SAVING | VFIO_DEVICE_STATE_RESUMING))
#define VFIO_DEVICE_STATE_SET_ERROR(state) ((state & ~VFIO_DEVICE_STATE_MASK) | VFIO_DEVICE_SATE_SAVING | VFIO_DEVICE_STATE_RESUMING)
  __u32 reserved;
  __u64 pending_bytes;
  __u64 data_offset;
  __u64 data_size;
};
#define VFIO_REGION_INFO_CAP_MSIX_MAPPABLE 3
#define VFIO_REGION_INFO_CAP_NVLINK2_SSATGT 4
struct vfio_region_info_cap_nvlink2_ssatgt {
  struct vfio_info_cap_header header;
  __u64 tgt;
};
#define VFIO_REGION_INFO_CAP_NVLINK2_LNKSPD 5
struct vfio_region_info_cap_nvlink2_lnkspd {
  struct vfio_info_cap_header header;
  __u32 link_speed;
  __u32 __pad;
};
struct vfio_irq_info {
  __u32 argsz;
  __u32 flags;
#define VFIO_IRQ_INFO_EVENTFD (1 << 0)
#define VFIO_IRQ_INFO_MASKABLE (1 << 1)
#define VFIO_IRQ_INFO_AUTOMASKED (1 << 2)
#define VFIO_IRQ_INFO_NORESIZE (1 << 3)
  __u32 index;
  __u32 count;
};
#define VFIO_DEVICE_GET_IRQ_INFO _IO(VFIO_TYPE, VFIO_BASE + 9)
struct vfio_irq_set {
  __u32 argsz;
  __u32 flags;
#define VFIO_IRQ_SET_DATA_NONE (1 << 0)
#define VFIO_IRQ_SET_DATA_BOOL (1 << 1)
#define VFIO_IRQ_SET_DATA_EVENTFD (1 << 2)
#define VFIO_IRQ_SET_ACTION_MASK (1 << 3)
#define VFIO_IRQ_SET_ACTION_UNMASK (1 << 4)
#define VFIO_IRQ_SET_ACTION_TRIGGER (1 << 5)
  __u32 index;
  __u32 start;
  __u32 count;
  __u8 data[];
};
#define VFIO_DEVICE_SET_IRQS _IO(VFIO_TYPE, VFIO_BASE + 10)
#define VFIO_IRQ_SET_DATA_TYPE_MASK (VFIO_IRQ_SET_DATA_NONE | VFIO_IRQ_SET_DATA_BOOL | VFIO_IRQ_SET_DATA_EVENTFD)
#define VFIO_IRQ_SET_ACTION_TYPE_MASK (VFIO_IRQ_SET_ACTION_MASK | VFIO_IRQ_SET_ACTION_UNMASK | VFIO_IRQ_SET_ACTION_TRIGGER)
#define VFIO_DEVICE_RESET _IO(VFIO_TYPE, VFIO_BASE + 11)
enum {
  VFIO_PCI_BAR0_REGION_INDEX,
  VFIO_PCI_BAR1_REGION_INDEX,
  VFIO_PCI_BAR2_REGION_INDEX,
  VFIO_PCI_BAR3_REGION_INDEX,
  VFIO_PCI_BAR4_REGION_INDEX,
  VFIO_PCI_BAR5_REGION_INDEX,
  VFIO_PCI_ROM_REGION_INDEX,
  VFIO_PCI_CONFIG_REGION_INDEX,
  VFIO_PCI_VGA_REGION_INDEX,
  VFIO_PCI_NUM_REGIONS = 9
};
enum {
  VFIO_PCI_INTX_IRQ_INDEX,
  VFIO_PCI_MSI_IRQ_INDEX,
  VFIO_PCI_MSIX_IRQ_INDEX,
  VFIO_PCI_ERR_IRQ_INDEX,
  VFIO_PCI_REQ_IRQ_INDEX,
  VFIO_PCI_NUM_IRQS
};
enum {
  VFIO_CCW_CONFIG_REGION_INDEX,
  VFIO_CCW_NUM_REGIONS
};
enum {
  VFIO_CCW_IO_IRQ_INDEX,
  VFIO_CCW_CRW_IRQ_INDEX,
  VFIO_CCW_NUM_IRQS
};
struct vfio_pci_dependent_device {
  __u32 group_id;
  __u16 segment;
  __u8 bus;
  __u8 devfn;
};
struct vfio_pci_hot_reset_info {
  __u32 argsz;
  __u32 flags;
  __u32 count;
  struct vfio_pci_dependent_device devices[];
};
#define VFIO_DEVICE_GET_PCI_HOT_RESET_INFO _IO(VFIO_TYPE, VFIO_BASE + 12)
struct vfio_pci_hot_reset {
  __u32 argsz;
  __u32 flags;
  __u32 count;
  __s32 group_fds[];
};
#define VFIO_DEVICE_PCI_HOT_RESET _IO(VFIO_TYPE, VFIO_BASE + 13)
struct vfio_device_gfx_plane_info {
  __u32 argsz;
  __u32 flags;
#define VFIO_GFX_PLANE_TYPE_PROBE (1 << 0)
#define VFIO_GFX_PLANE_TYPE_DMABUF (1 << 1)
#define VFIO_GFX_PLANE_TYPE_REGION (1 << 2)
  __u32 drm_plane_type;
  __u32 drm_format;
  __u64 drm_format_mod;
  __u32 width;
  __u32 height;
  __u32 stride;
  __u32 size;
  __u32 x_pos;
  __u32 y_pos;
  __u32 x_hot;
  __u32 y_hot;
  union {
    __u32 region_index;
    __u32 dmabuf_id;
  };
};
#define VFIO_DEVICE_QUERY_GFX_PLANE _IO(VFIO_TYPE, VFIO_BASE + 14)
#define VFIO_DEVICE_GET_GFX_DMABUF _IO(VFIO_TYPE, VFIO_BASE + 15)
struct vfio_device_ioeventfd {
  __u32 argsz;
  __u32 flags;
#define VFIO_DEVICE_IOEVENTFD_8 (1 << 0)
#define VFIO_DEVICE_IOEVENTFD_16 (1 << 1)
#define VFIO_DEVICE_IOEVENTFD_32 (1 << 2)
#define VFIO_DEVICE_IOEVENTFD_64 (1 << 3)
#define VFIO_DEVICE_IOEVENTFD_SIZE_MASK (0xf)
  __u64 offset;
  __u64 data;
  __s32 fd;
};
#define VFIO_DEVICE_IOEVENTFD _IO(VFIO_TYPE, VFIO_BASE + 16)
struct vfio_device_feature {
  __u32 argsz;
  __u32 flags;
#define VFIO_DEVICE_FEATURE_MASK (0xffff)
#define VFIO_DEVICE_FEATURE_GET (1 << 16)
#define VFIO_DEVICE_FEATURE_SET (1 << 17)
#define VFIO_DEVICE_FEATURE_PROBE (1 << 18)
  __u8 data[];
};
#define VFIO_DEVICE_FEATURE _IO(VFIO_TYPE, VFIO_BASE + 17)
#define VFIO_DEVICE_FEATURE_PCI_VF_TOKEN (0)
struct vfio_iommu_type1_info {
  __u32 argsz;
  __u32 flags;
#define VFIO_IOMMU_INFO_PGSIZES (1 << 0)
#define VFIO_IOMMU_INFO_CAPS (1 << 1)
  __u64 iova_pgsizes;
  __u32 cap_offset;
};
#define VFIO_IOMMU_TYPE1_INFO_CAP_IOVA_RANGE 1
struct vfio_iova_range {
  __u64 start;
  __u64 end;
};
struct vfio_iommu_type1_info_cap_iova_range {
  struct vfio_info_cap_header header;
  __u32 nr_iovas;
  __u32 reserved;
  struct vfio_iova_range iova_ranges[];
};
#define VFIO_IOMMU_TYPE1_INFO_CAP_MIGRATION 2
struct vfio_iommu_type1_info_cap_migration {
  struct vfio_info_cap_header header;
  __u32 flags;
  __u64 pgsize_bitmap;
  __u64 max_dirty_bitmap_size;
};
#define VFIO_IOMMU_TYPE1_INFO_DMA_AVAIL 3
struct vfio_iommu_type1_info_dma_avail {
  struct vfio_info_cap_header header;
  __u32 avail;
};
#define VFIO_IOMMU_GET_INFO _IO(VFIO_TYPE, VFIO_BASE + 12)
struct vfio_iommu_type1_dma_map {
  __u32 argsz;
  __u32 flags;
#define VFIO_DMA_MAP_FLAG_READ (1 << 0)
#define VFIO_DMA_MAP_FLAG_WRITE (1 << 1)
  __u64 vaddr;
  __u64 iova;
  __u64 size;
};
#define VFIO_IOMMU_MAP_DMA _IO(VFIO_TYPE, VFIO_BASE + 13)
struct vfio_bitmap {
  __u64 pgsize;
  __u64 size;
  __u64 __user * data;
};
struct vfio_iommu_type1_dma_unmap {
  __u32 argsz;
  __u32 flags;
#define VFIO_DMA_UNMAP_FLAG_GET_DIRTY_BITMAP (1 << 0)
  __u64 iova;
  __u64 size;
  __u8 data[];
};
#define VFIO_IOMMU_UNMAP_DMA _IO(VFIO_TYPE, VFIO_BASE + 14)
#define VFIO_IOMMU_ENABLE _IO(VFIO_TYPE, VFIO_BASE + 15)
#define VFIO_IOMMU_DISABLE _IO(VFIO_TYPE, VFIO_BASE + 16)
struct vfio_iommu_type1_dirty_bitmap {
  __u32 argsz;
  __u32 flags;
#define VFIO_IOMMU_DIRTY_PAGES_FLAG_START (1 << 0)
#define VFIO_IOMMU_DIRTY_PAGES_FLAG_STOP (1 << 1)
#define VFIO_IOMMU_DIRTY_PAGES_FLAG_GET_BITMAP (1 << 2)
  __u8 data[];
};
struct vfio_iommu_type1_dirty_bitmap_get {
  __u64 iova;
  __u64 size;
  struct vfio_bitmap bitmap;
};
#define VFIO_IOMMU_DIRTY_PAGES _IO(VFIO_TYPE, VFIO_BASE + 17)
struct vfio_iommu_spapr_tce_ddw_info {
  __u64 pgsizes;
  __u32 max_dynamic_windows_supported;
  __u32 levels;
};
struct vfio_iommu_spapr_tce_info {
  __u32 argsz;
  __u32 flags;
#define VFIO_IOMMU_SPAPR_INFO_DDW (1 << 0)
  __u32 dma32_window_start;
  __u32 dma32_window_size;
  struct vfio_iommu_spapr_tce_ddw_info ddw;
};
#define VFIO_IOMMU_SPAPR_TCE_GET_INFO _IO(VFIO_TYPE, VFIO_BASE + 12)
struct vfio_eeh_pe_err {
  __u32 type;
  __u32 func;
  __u64 addr;
  __u64 mask;
};
struct vfio_eeh_pe_op {
  __u32 argsz;
  __u32 flags;
  __u32 op;
  union {
    struct vfio_eeh_pe_err err;
  };
};
#define VFIO_EEH_PE_DISABLE 0
#define VFIO_EEH_PE_ENABLE 1
#define VFIO_EEH_PE_UNFREEZE_IO 2
#define VFIO_EEH_PE_UNFREEZE_DMA 3
#define VFIO_EEH_PE_GET_STATE 4
#define VFIO_EEH_PE_STATE_NORMAL 0
#define VFIO_EEH_PE_STATE_RESET 1
#define VFIO_EEH_PE_STATE_STOPPED 2
#define VFIO_EEH_PE_STATE_STOPPED_DMA 4
#define VFIO_EEH_PE_STATE_UNAVAIL 5
#define VFIO_EEH_PE_RESET_DEACTIVATE 5
#define VFIO_EEH_PE_RESET_HOT 6
#define VFIO_EEH_PE_RESET_FUNDAMENTAL 7
#define VFIO_EEH_PE_CONFIGURE 8
#define VFIO_EEH_PE_INJECT_ERR 9
#define VFIO_EEH_PE_OP _IO(VFIO_TYPE, VFIO_BASE + 21)
struct vfio_iommu_spapr_register_memory {
  __u32 argsz;
  __u32 flags;
  __u64 vaddr;
  __u64 size;
};
#define VFIO_IOMMU_SPAPR_REGISTER_MEMORY _IO(VFIO_TYPE, VFIO_BASE + 17)
#define VFIO_IOMMU_SPAPR_UNREGISTER_MEMORY _IO(VFIO_TYPE, VFIO_BASE + 18)
struct vfio_iommu_spapr_tce_create {
  __u32 argsz;
  __u32 flags;
  __u32 page_shift;
  __u32 __resv1;
  __u64 window_size;
  __u32 levels;
  __u32 __resv2;
  __u64 start_addr;
};
#define VFIO_IOMMU_SPAPR_TCE_CREATE _IO(VFIO_TYPE, VFIO_BASE + 19)
struct vfio_iommu_spapr_tce_remove {
  __u32 argsz;
  __u32 flags;
  __u64 start_addr;
};
#define VFIO_IOMMU_SPAPR_TCE_REMOVE _IO(VFIO_TYPE, VFIO_BASE + 20)
#endif