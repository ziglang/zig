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
#ifndef _DRM_MODE_H
#define _DRM_MODE_H
#include "drm.h"
#ifdef __cplusplus
extern "C" {
#endif
#define DRM_CONNECTOR_NAME_LEN 32
#define DRM_DISPLAY_MODE_LEN 32
#define DRM_PROP_NAME_LEN 32
#define DRM_MODE_TYPE_BUILTIN (1 << 0)
#define DRM_MODE_TYPE_CLOCK_C ((1 << 1) | DRM_MODE_TYPE_BUILTIN)
#define DRM_MODE_TYPE_CRTC_C ((1 << 2) | DRM_MODE_TYPE_BUILTIN)
#define DRM_MODE_TYPE_PREFERRED (1 << 3)
#define DRM_MODE_TYPE_DEFAULT (1 << 4)
#define DRM_MODE_TYPE_USERDEF (1 << 5)
#define DRM_MODE_TYPE_DRIVER (1 << 6)
#define DRM_MODE_TYPE_ALL (DRM_MODE_TYPE_PREFERRED | DRM_MODE_TYPE_USERDEF | DRM_MODE_TYPE_DRIVER)
#define DRM_MODE_FLAG_PHSYNC (1 << 0)
#define DRM_MODE_FLAG_NHSYNC (1 << 1)
#define DRM_MODE_FLAG_PVSYNC (1 << 2)
#define DRM_MODE_FLAG_NVSYNC (1 << 3)
#define DRM_MODE_FLAG_INTERLACE (1 << 4)
#define DRM_MODE_FLAG_DBLSCAN (1 << 5)
#define DRM_MODE_FLAG_CSYNC (1 << 6)
#define DRM_MODE_FLAG_PCSYNC (1 << 7)
#define DRM_MODE_FLAG_NCSYNC (1 << 8)
#define DRM_MODE_FLAG_HSKEW (1 << 9)
#define DRM_MODE_FLAG_BCAST (1 << 10)
#define DRM_MODE_FLAG_PIXMUX (1 << 11)
#define DRM_MODE_FLAG_DBLCLK (1 << 12)
#define DRM_MODE_FLAG_CLKDIV2 (1 << 13)
#define DRM_MODE_FLAG_3D_MASK (0x1f << 14)
#define DRM_MODE_FLAG_3D_NONE (0 << 14)
#define DRM_MODE_FLAG_3D_FRAME_PACKING (1 << 14)
#define DRM_MODE_FLAG_3D_FIELD_ALTERNATIVE (2 << 14)
#define DRM_MODE_FLAG_3D_LINE_ALTERNATIVE (3 << 14)
#define DRM_MODE_FLAG_3D_SIDE_BY_SIDE_FULL (4 << 14)
#define DRM_MODE_FLAG_3D_L_DEPTH (5 << 14)
#define DRM_MODE_FLAG_3D_L_DEPTH_GFX_GFX_DEPTH (6 << 14)
#define DRM_MODE_FLAG_3D_TOP_AND_BOTTOM (7 << 14)
#define DRM_MODE_FLAG_3D_SIDE_BY_SIDE_HALF (8 << 14)
#define DRM_MODE_PICTURE_ASPECT_NONE 0
#define DRM_MODE_PICTURE_ASPECT_4_3 1
#define DRM_MODE_PICTURE_ASPECT_16_9 2
#define DRM_MODE_PICTURE_ASPECT_64_27 3
#define DRM_MODE_PICTURE_ASPECT_256_135 4
#define DRM_MODE_CONTENT_TYPE_NO_DATA 0
#define DRM_MODE_CONTENT_TYPE_GRAPHICS 1
#define DRM_MODE_CONTENT_TYPE_PHOTO 2
#define DRM_MODE_CONTENT_TYPE_CINEMA 3
#define DRM_MODE_CONTENT_TYPE_GAME 4
#define DRM_MODE_FLAG_PIC_AR_MASK (0x0F << 19)
#define DRM_MODE_FLAG_PIC_AR_NONE (DRM_MODE_PICTURE_ASPECT_NONE << 19)
#define DRM_MODE_FLAG_PIC_AR_4_3 (DRM_MODE_PICTURE_ASPECT_4_3 << 19)
#define DRM_MODE_FLAG_PIC_AR_16_9 (DRM_MODE_PICTURE_ASPECT_16_9 << 19)
#define DRM_MODE_FLAG_PIC_AR_64_27 (DRM_MODE_PICTURE_ASPECT_64_27 << 19)
#define DRM_MODE_FLAG_PIC_AR_256_135 (DRM_MODE_PICTURE_ASPECT_256_135 << 19)
#define DRM_MODE_FLAG_ALL (DRM_MODE_FLAG_PHSYNC | DRM_MODE_FLAG_NHSYNC | DRM_MODE_FLAG_PVSYNC | DRM_MODE_FLAG_NVSYNC | DRM_MODE_FLAG_INTERLACE | DRM_MODE_FLAG_DBLSCAN | DRM_MODE_FLAG_CSYNC | DRM_MODE_FLAG_PCSYNC | DRM_MODE_FLAG_NCSYNC | DRM_MODE_FLAG_HSKEW | DRM_MODE_FLAG_DBLCLK | DRM_MODE_FLAG_CLKDIV2 | DRM_MODE_FLAG_3D_MASK)
#define DRM_MODE_DPMS_ON 0
#define DRM_MODE_DPMS_STANDBY 1
#define DRM_MODE_DPMS_SUSPEND 2
#define DRM_MODE_DPMS_OFF 3
#define DRM_MODE_SCALE_NONE 0
#define DRM_MODE_SCALE_FULLSCREEN 1
#define DRM_MODE_SCALE_CENTER 2
#define DRM_MODE_SCALE_ASPECT 3
#define DRM_MODE_DITHERING_OFF 0
#define DRM_MODE_DITHERING_ON 1
#define DRM_MODE_DITHERING_AUTO 2
#define DRM_MODE_DIRTY_OFF 0
#define DRM_MODE_DIRTY_ON 1
#define DRM_MODE_DIRTY_ANNOTATE 2
#define DRM_MODE_LINK_STATUS_GOOD 0
#define DRM_MODE_LINK_STATUS_BAD 1
#define DRM_MODE_ROTATE_0 (1 << 0)
#define DRM_MODE_ROTATE_90 (1 << 1)
#define DRM_MODE_ROTATE_180 (1 << 2)
#define DRM_MODE_ROTATE_270 (1 << 3)
#define DRM_MODE_ROTATE_MASK (DRM_MODE_ROTATE_0 | DRM_MODE_ROTATE_90 | DRM_MODE_ROTATE_180 | DRM_MODE_ROTATE_270)
#define DRM_MODE_REFLECT_X (1 << 4)
#define DRM_MODE_REFLECT_Y (1 << 5)
#define DRM_MODE_REFLECT_MASK (DRM_MODE_REFLECT_X | DRM_MODE_REFLECT_Y)
#define DRM_MODE_CONTENT_PROTECTION_UNDESIRED 0
#define DRM_MODE_CONTENT_PROTECTION_DESIRED 1
#define DRM_MODE_CONTENT_PROTECTION_ENABLED 2
struct drm_mode_modeinfo {
  __u32 clock;
  __u16 hdisplay;
  __u16 hsync_start;
  __u16 hsync_end;
  __u16 htotal;
  __u16 hskew;
  __u16 vdisplay;
  __u16 vsync_start;
  __u16 vsync_end;
  __u16 vtotal;
  __u16 vscan;
  __u32 vrefresh;
  __u32 flags;
  __u32 type;
  char name[DRM_DISPLAY_MODE_LEN];
};
struct drm_mode_card_res {
  __u64 fb_id_ptr;
  __u64 crtc_id_ptr;
  __u64 connector_id_ptr;
  __u64 encoder_id_ptr;
  __u32 count_fbs;
  __u32 count_crtcs;
  __u32 count_connectors;
  __u32 count_encoders;
  __u32 min_width;
  __u32 max_width;
  __u32 min_height;
  __u32 max_height;
};
struct drm_mode_crtc {
  __u64 set_connectors_ptr;
  __u32 count_connectors;
  __u32 crtc_id;
  __u32 fb_id;
  __u32 x;
  __u32 y;
  __u32 gamma_size;
  __u32 mode_valid;
  struct drm_mode_modeinfo mode;
};
#define DRM_MODE_PRESENT_TOP_FIELD (1 << 0)
#define DRM_MODE_PRESENT_BOTTOM_FIELD (1 << 1)
struct drm_mode_set_plane {
  __u32 plane_id;
  __u32 crtc_id;
  __u32 fb_id;
  __u32 flags;
  __s32 crtc_x;
  __s32 crtc_y;
  __u32 crtc_w;
  __u32 crtc_h;
  __u32 src_x;
  __u32 src_y;
  __u32 src_h;
  __u32 src_w;
};
struct drm_mode_get_plane {
  __u32 plane_id;
  __u32 crtc_id;
  __u32 fb_id;
  __u32 possible_crtcs;
  __u32 gamma_size;
  __u32 count_format_types;
  __u64 format_type_ptr;
};
struct drm_mode_get_plane_res {
  __u64 plane_id_ptr;
  __u32 count_planes;
};
#define DRM_MODE_ENCODER_NONE 0
#define DRM_MODE_ENCODER_DAC 1
#define DRM_MODE_ENCODER_TMDS 2
#define DRM_MODE_ENCODER_LVDS 3
#define DRM_MODE_ENCODER_TVDAC 4
#define DRM_MODE_ENCODER_VIRTUAL 5
#define DRM_MODE_ENCODER_DSI 6
#define DRM_MODE_ENCODER_DPMST 7
#define DRM_MODE_ENCODER_DPI 8
struct drm_mode_get_encoder {
  __u32 encoder_id;
  __u32 encoder_type;
  __u32 crtc_id;
  __u32 possible_crtcs;
  __u32 possible_clones;
};
enum drm_mode_subconnector {
  DRM_MODE_SUBCONNECTOR_Automatic = 0,
  DRM_MODE_SUBCONNECTOR_Unknown = 0,
  DRM_MODE_SUBCONNECTOR_VGA = 1,
  DRM_MODE_SUBCONNECTOR_DVID = 3,
  DRM_MODE_SUBCONNECTOR_DVIA = 4,
  DRM_MODE_SUBCONNECTOR_Composite = 5,
  DRM_MODE_SUBCONNECTOR_SVIDEO = 6,
  DRM_MODE_SUBCONNECTOR_Component = 8,
  DRM_MODE_SUBCONNECTOR_SCART = 9,
  DRM_MODE_SUBCONNECTOR_DisplayPort = 10,
  DRM_MODE_SUBCONNECTOR_HDMIA = 11,
  DRM_MODE_SUBCONNECTOR_Native = 15,
  DRM_MODE_SUBCONNECTOR_Wireless = 18,
};
#define DRM_MODE_CONNECTOR_Unknown 0
#define DRM_MODE_CONNECTOR_VGA 1
#define DRM_MODE_CONNECTOR_DVII 2
#define DRM_MODE_CONNECTOR_DVID 3
#define DRM_MODE_CONNECTOR_DVIA 4
#define DRM_MODE_CONNECTOR_Composite 5
#define DRM_MODE_CONNECTOR_SVIDEO 6
#define DRM_MODE_CONNECTOR_LVDS 7
#define DRM_MODE_CONNECTOR_Component 8
#define DRM_MODE_CONNECTOR_9PinDIN 9
#define DRM_MODE_CONNECTOR_DisplayPort 10
#define DRM_MODE_CONNECTOR_HDMIA 11
#define DRM_MODE_CONNECTOR_HDMIB 12
#define DRM_MODE_CONNECTOR_TV 13
#define DRM_MODE_CONNECTOR_eDP 14
#define DRM_MODE_CONNECTOR_VIRTUAL 15
#define DRM_MODE_CONNECTOR_DSI 16
#define DRM_MODE_CONNECTOR_DPI 17
#define DRM_MODE_CONNECTOR_WRITEBACK 18
#define DRM_MODE_CONNECTOR_SPI 19
struct drm_mode_get_connector {
  __u64 encoders_ptr;
  __u64 modes_ptr;
  __u64 props_ptr;
  __u64 prop_values_ptr;
  __u32 count_modes;
  __u32 count_props;
  __u32 count_encoders;
  __u32 encoder_id;
  __u32 connector_id;
  __u32 connector_type;
  __u32 connector_type_id;
  __u32 connection;
  __u32 mm_width;
  __u32 mm_height;
  __u32 subpixel;
  __u32 pad;
};
#define DRM_MODE_PROP_PENDING (1 << 0)
#define DRM_MODE_PROP_RANGE (1 << 1)
#define DRM_MODE_PROP_IMMUTABLE (1 << 2)
#define DRM_MODE_PROP_ENUM (1 << 3)
#define DRM_MODE_PROP_BLOB (1 << 4)
#define DRM_MODE_PROP_BITMASK (1 << 5)
#define DRM_MODE_PROP_LEGACY_TYPE (DRM_MODE_PROP_RANGE | DRM_MODE_PROP_ENUM | DRM_MODE_PROP_BLOB | DRM_MODE_PROP_BITMASK)
#define DRM_MODE_PROP_EXTENDED_TYPE 0x0000ffc0
#define DRM_MODE_PROP_TYPE(n) ((n) << 6)
#define DRM_MODE_PROP_OBJECT DRM_MODE_PROP_TYPE(1)
#define DRM_MODE_PROP_SIGNED_RANGE DRM_MODE_PROP_TYPE(2)
#define DRM_MODE_PROP_ATOMIC 0x80000000
struct drm_mode_property_enum {
  __u64 value;
  char name[DRM_PROP_NAME_LEN];
};
struct drm_mode_get_property {
  __u64 values_ptr;
  __u64 enum_blob_ptr;
  __u32 prop_id;
  __u32 flags;
  char name[DRM_PROP_NAME_LEN];
  __u32 count_values;
  __u32 count_enum_blobs;
};
struct drm_mode_connector_set_property {
  __u64 value;
  __u32 prop_id;
  __u32 connector_id;
};
#define DRM_MODE_OBJECT_CRTC 0xcccccccc
#define DRM_MODE_OBJECT_CONNECTOR 0xc0c0c0c0
#define DRM_MODE_OBJECT_ENCODER 0xe0e0e0e0
#define DRM_MODE_OBJECT_MODE 0xdededede
#define DRM_MODE_OBJECT_PROPERTY 0xb0b0b0b0
#define DRM_MODE_OBJECT_FB 0xfbfbfbfb
#define DRM_MODE_OBJECT_BLOB 0xbbbbbbbb
#define DRM_MODE_OBJECT_PLANE 0xeeeeeeee
#define DRM_MODE_OBJECT_ANY 0
struct drm_mode_obj_get_properties {
  __u64 props_ptr;
  __u64 prop_values_ptr;
  __u32 count_props;
  __u32 obj_id;
  __u32 obj_type;
};
struct drm_mode_obj_set_property {
  __u64 value;
  __u32 prop_id;
  __u32 obj_id;
  __u32 obj_type;
};
struct drm_mode_get_blob {
  __u32 blob_id;
  __u32 length;
  __u64 data;
};
struct drm_mode_fb_cmd {
  __u32 fb_id;
  __u32 width;
  __u32 height;
  __u32 pitch;
  __u32 bpp;
  __u32 depth;
  __u32 handle;
};
#define DRM_MODE_FB_INTERLACED (1 << 0)
#define DRM_MODE_FB_MODIFIERS (1 << 1)
struct drm_mode_fb_cmd2 {
  __u32 fb_id;
  __u32 width;
  __u32 height;
  __u32 pixel_format;
  __u32 flags;
  __u32 handles[4];
  __u32 pitches[4];
  __u32 offsets[4];
  __u64 modifier[4];
};
#define DRM_MODE_FB_DIRTY_ANNOTATE_COPY 0x01
#define DRM_MODE_FB_DIRTY_ANNOTATE_FILL 0x02
#define DRM_MODE_FB_DIRTY_FLAGS 0x03
#define DRM_MODE_FB_DIRTY_MAX_CLIPS 256
struct drm_mode_fb_dirty_cmd {
  __u32 fb_id;
  __u32 flags;
  __u32 color;
  __u32 num_clips;
  __u64 clips_ptr;
};
struct drm_mode_mode_cmd {
  __u32 connector_id;
  struct drm_mode_modeinfo mode;
};
#define DRM_MODE_CURSOR_BO 0x01
#define DRM_MODE_CURSOR_MOVE 0x02
#define DRM_MODE_CURSOR_FLAGS 0x03
struct drm_mode_cursor {
  __u32 flags;
  __u32 crtc_id;
  __s32 x;
  __s32 y;
  __u32 width;
  __u32 height;
  __u32 handle;
};
struct drm_mode_cursor2 {
  __u32 flags;
  __u32 crtc_id;
  __s32 x;
  __s32 y;
  __u32 width;
  __u32 height;
  __u32 handle;
  __s32 hot_x;
  __s32 hot_y;
};
struct drm_mode_crtc_lut {
  __u32 crtc_id;
  __u32 gamma_size;
  __u64 red;
  __u64 green;
  __u64 blue;
};
struct drm_color_ctm {
  __u64 matrix[9];
};
struct drm_color_lut {
  __u16 red;
  __u16 green;
  __u16 blue;
  __u16 reserved;
};
struct hdr_metadata_infoframe {
  __u8 eotf;
  __u8 metadata_type;
  struct {
    __u16 x, y;
  } display_primaries[3];
  struct {
    __u16 x, y;
  } white_point;
  __u16 max_display_mastering_luminance;
  __u16 min_display_mastering_luminance;
  __u16 max_cll;
  __u16 max_fall;
};
struct hdr_output_metadata {
  __u32 metadata_type;
  union {
    struct hdr_metadata_infoframe hdmi_metadata_type1;
  };
};
#define DRM_MODE_PAGE_FLIP_EVENT 0x01
#define DRM_MODE_PAGE_FLIP_ASYNC 0x02
#define DRM_MODE_PAGE_FLIP_TARGET_ABSOLUTE 0x4
#define DRM_MODE_PAGE_FLIP_TARGET_RELATIVE 0x8
#define DRM_MODE_PAGE_FLIP_TARGET (DRM_MODE_PAGE_FLIP_TARGET_ABSOLUTE | DRM_MODE_PAGE_FLIP_TARGET_RELATIVE)
#define DRM_MODE_PAGE_FLIP_FLAGS (DRM_MODE_PAGE_FLIP_EVENT | DRM_MODE_PAGE_FLIP_ASYNC | DRM_MODE_PAGE_FLIP_TARGET)
struct drm_mode_crtc_page_flip {
  __u32 crtc_id;
  __u32 fb_id;
  __u32 flags;
  __u32 reserved;
  __u64 user_data;
};
struct drm_mode_crtc_page_flip_target {
  __u32 crtc_id;
  __u32 fb_id;
  __u32 flags;
  __u32 sequence;
  __u64 user_data;
};
struct drm_mode_create_dumb {
  __u32 height;
  __u32 width;
  __u32 bpp;
  __u32 flags;
  __u32 handle;
  __u32 pitch;
  __u64 size;
};
struct drm_mode_map_dumb {
  __u32 handle;
  __u32 pad;
  __u64 offset;
};
struct drm_mode_destroy_dumb {
  __u32 handle;
};
#define DRM_MODE_ATOMIC_TEST_ONLY 0x0100
#define DRM_MODE_ATOMIC_NONBLOCK 0x0200
#define DRM_MODE_ATOMIC_ALLOW_MODESET 0x0400
#define DRM_MODE_ATOMIC_FLAGS (DRM_MODE_PAGE_FLIP_EVENT | DRM_MODE_PAGE_FLIP_ASYNC | DRM_MODE_ATOMIC_TEST_ONLY | DRM_MODE_ATOMIC_NONBLOCK | DRM_MODE_ATOMIC_ALLOW_MODESET)
struct drm_mode_atomic {
  __u32 flags;
  __u32 count_objs;
  __u64 objs_ptr;
  __u64 count_props_ptr;
  __u64 props_ptr;
  __u64 prop_values_ptr;
  __u64 reserved;
  __u64 user_data;
};
struct drm_format_modifier_blob {
#define FORMAT_BLOB_CURRENT 1
  __u32 version;
  __u32 flags;
  __u32 count_formats;
  __u32 formats_offset;
  __u32 count_modifiers;
  __u32 modifiers_offset;
};
struct drm_format_modifier {
  __u64 formats;
  __u32 offset;
  __u32 pad;
  __u64 modifier;
};
struct drm_mode_create_blob {
  __u64 data;
  __u32 length;
  __u32 blob_id;
};
struct drm_mode_destroy_blob {
  __u32 blob_id;
};
struct drm_mode_create_lease {
  __u64 object_ids;
  __u32 object_count;
  __u32 flags;
  __u32 lessee_id;
  __u32 fd;
};
struct drm_mode_list_lessees {
  __u32 count_lessees;
  __u32 pad;
  __u64 lessees_ptr;
};
struct drm_mode_get_lease {
  __u32 count_objects;
  __u32 pad;
  __u64 objects_ptr;
};
struct drm_mode_revoke_lease {
  __u32 lessee_id;
};
struct drm_mode_rect {
  __s32 x1;
  __s32 y1;
  __s32 x2;
  __s32 y2;
};
#ifdef __cplusplus
}
#endif
#endif