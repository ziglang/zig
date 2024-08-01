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
#ifndef _UAPI_LINUX_FB_H
#define _UAPI_LINUX_FB_H
#include <linux/types.h>
#include <linux/i2c.h>
#define FB_MAX 32
#define FBIOGET_VSCREENINFO 0x4600
#define FBIOPUT_VSCREENINFO 0x4601
#define FBIOGET_FSCREENINFO 0x4602
#define FBIOGETCMAP 0x4604
#define FBIOPUTCMAP 0x4605
#define FBIOPAN_DISPLAY 0x4606
#define FBIO_CURSOR _IOWR('F', 0x08, struct fb_cursor)
#define FBIOGET_CON2FBMAP 0x460F
#define FBIOPUT_CON2FBMAP 0x4610
#define FBIOBLANK 0x4611
#define FBIOGET_VBLANK _IOR('F', 0x12, struct fb_vblank)
#define FBIO_ALLOC 0x4613
#define FBIO_FREE 0x4614
#define FBIOGET_GLYPH 0x4615
#define FBIOGET_HWCINFO 0x4616
#define FBIOPUT_MODEINFO 0x4617
#define FBIOGET_DISPINFO 0x4618
#define FBIO_WAITFORVSYNC _IOW('F', 0x20, __u32)
#define FB_TYPE_PACKED_PIXELS 0
#define FB_TYPE_PLANES 1
#define FB_TYPE_INTERLEAVED_PLANES 2
#define FB_TYPE_TEXT 3
#define FB_TYPE_VGA_PLANES 4
#define FB_TYPE_FOURCC 5
#define FB_AUX_TEXT_MDA 0
#define FB_AUX_TEXT_CGA 1
#define FB_AUX_TEXT_S3_MMIO 2
#define FB_AUX_TEXT_MGA_STEP16 3
#define FB_AUX_TEXT_MGA_STEP8 4
#define FB_AUX_TEXT_SVGA_GROUP 8
#define FB_AUX_TEXT_SVGA_MASK 7
#define FB_AUX_TEXT_SVGA_STEP2 8
#define FB_AUX_TEXT_SVGA_STEP4 9
#define FB_AUX_TEXT_SVGA_STEP8 10
#define FB_AUX_TEXT_SVGA_STEP16 11
#define FB_AUX_TEXT_SVGA_LAST 15
#define FB_AUX_VGA_PLANES_VGA4 0
#define FB_AUX_VGA_PLANES_CFB4 1
#define FB_AUX_VGA_PLANES_CFB8 2
#define FB_VISUAL_MONO01 0
#define FB_VISUAL_MONO10 1
#define FB_VISUAL_TRUECOLOR 2
#define FB_VISUAL_PSEUDOCOLOR 3
#define FB_VISUAL_DIRECTCOLOR 4
#define FB_VISUAL_STATIC_PSEUDOCOLOR 5
#define FB_VISUAL_FOURCC 6
#define FB_ACCEL_NONE 0
#define FB_ACCEL_ATARIBLITT 1
#define FB_ACCEL_AMIGABLITT 2
#define FB_ACCEL_S3_TRIO64 3
#define FB_ACCEL_NCR_77C32BLT 4
#define FB_ACCEL_S3_VIRGE 5
#define FB_ACCEL_ATI_MACH64GX 6
#define FB_ACCEL_DEC_TGA 7
#define FB_ACCEL_ATI_MACH64CT 8
#define FB_ACCEL_ATI_MACH64VT 9
#define FB_ACCEL_ATI_MACH64GT 10
#define FB_ACCEL_SUN_CREATOR 11
#define FB_ACCEL_SUN_CGSIX 12
#define FB_ACCEL_SUN_LEO 13
#define FB_ACCEL_IMS_TWINTURBO 14
#define FB_ACCEL_3DLABS_PERMEDIA2 15
#define FB_ACCEL_MATROX_MGA2064W 16
#define FB_ACCEL_MATROX_MGA1064SG 17
#define FB_ACCEL_MATROX_MGA2164W 18
#define FB_ACCEL_MATROX_MGA2164W_AGP 19
#define FB_ACCEL_MATROX_MGAG100 20
#define FB_ACCEL_MATROX_MGAG200 21
#define FB_ACCEL_SUN_CG14 22
#define FB_ACCEL_SUN_BWTWO 23
#define FB_ACCEL_SUN_CGTHREE 24
#define FB_ACCEL_SUN_TCX 25
#define FB_ACCEL_MATROX_MGAG400 26
#define FB_ACCEL_NV3 27
#define FB_ACCEL_NV4 28
#define FB_ACCEL_NV5 29
#define FB_ACCEL_CT_6555x 30
#define FB_ACCEL_3DFX_BANSHEE 31
#define FB_ACCEL_ATI_RAGE128 32
#define FB_ACCEL_IGS_CYBER2000 33
#define FB_ACCEL_IGS_CYBER2010 34
#define FB_ACCEL_IGS_CYBER5000 35
#define FB_ACCEL_SIS_GLAMOUR 36
#define FB_ACCEL_3DLABS_PERMEDIA3 37
#define FB_ACCEL_ATI_RADEON 38
#define FB_ACCEL_I810 39
#define FB_ACCEL_SIS_GLAMOUR_2 40
#define FB_ACCEL_SIS_XABRE 41
#define FB_ACCEL_I830 42
#define FB_ACCEL_NV_10 43
#define FB_ACCEL_NV_20 44
#define FB_ACCEL_NV_30 45
#define FB_ACCEL_NV_40 46
#define FB_ACCEL_XGI_VOLARI_V 47
#define FB_ACCEL_XGI_VOLARI_Z 48
#define FB_ACCEL_OMAP1610 49
#define FB_ACCEL_TRIDENT_TGUI 50
#define FB_ACCEL_TRIDENT_3DIMAGE 51
#define FB_ACCEL_TRIDENT_BLADE3D 52
#define FB_ACCEL_TRIDENT_BLADEXP 53
#define FB_ACCEL_CIRRUS_ALPINE 53
#define FB_ACCEL_NEOMAGIC_NM2070 90
#define FB_ACCEL_NEOMAGIC_NM2090 91
#define FB_ACCEL_NEOMAGIC_NM2093 92
#define FB_ACCEL_NEOMAGIC_NM2097 93
#define FB_ACCEL_NEOMAGIC_NM2160 94
#define FB_ACCEL_NEOMAGIC_NM2200 95
#define FB_ACCEL_NEOMAGIC_NM2230 96
#define FB_ACCEL_NEOMAGIC_NM2360 97
#define FB_ACCEL_NEOMAGIC_NM2380 98
#define FB_ACCEL_PXA3XX 99
#define FB_ACCEL_SAVAGE4 0x80
#define FB_ACCEL_SAVAGE3D 0x81
#define FB_ACCEL_SAVAGE3D_MV 0x82
#define FB_ACCEL_SAVAGE2000 0x83
#define FB_ACCEL_SAVAGE_MX_MV 0x84
#define FB_ACCEL_SAVAGE_MX 0x85
#define FB_ACCEL_SAVAGE_IX_MV 0x86
#define FB_ACCEL_SAVAGE_IX 0x87
#define FB_ACCEL_PROSAVAGE_PM 0x88
#define FB_ACCEL_PROSAVAGE_KM 0x89
#define FB_ACCEL_S3TWISTER_P 0x8a
#define FB_ACCEL_S3TWISTER_K 0x8b
#define FB_ACCEL_SUPERSAVAGE 0x8c
#define FB_ACCEL_PROSAVAGE_DDR 0x8d
#define FB_ACCEL_PROSAVAGE_DDRK 0x8e
#define FB_ACCEL_PUV3_UNIGFX 0xa0
#define FB_CAP_FOURCC 1
struct fb_fix_screeninfo {
  char id[16];
  unsigned long smem_start;
  __u32 smem_len;
  __u32 type;
  __u32 type_aux;
  __u32 visual;
  __u16 xpanstep;
  __u16 ypanstep;
  __u16 ywrapstep;
  __u32 line_length;
  unsigned long mmio_start;
  __u32 mmio_len;
  __u32 accel;
  __u16 capabilities;
  __u16 reserved[2];
};
struct fb_bitfield {
  __u32 offset;
  __u32 length;
  __u32 msb_right;
};
#define FB_NONSTD_HAM 1
#define FB_NONSTD_REV_PIX_IN_B 2
#define FB_ACTIVATE_NOW 0
#define FB_ACTIVATE_NXTOPEN 1
#define FB_ACTIVATE_TEST 2
#define FB_ACTIVATE_MASK 15
#define FB_ACTIVATE_VBL 16
#define FB_CHANGE_CMAP_VBL 32
#define FB_ACTIVATE_ALL 64
#define FB_ACTIVATE_FORCE 128
#define FB_ACTIVATE_INV_MODE 256
#define FB_ACTIVATE_KD_TEXT 512
#define FB_ACCELF_TEXT 1
#define FB_SYNC_HOR_HIGH_ACT 1
#define FB_SYNC_VERT_HIGH_ACT 2
#define FB_SYNC_EXT 4
#define FB_SYNC_COMP_HIGH_ACT 8
#define FB_SYNC_BROADCAST 16
#define FB_SYNC_ON_GREEN 32
#define FB_VMODE_NONINTERLACED 0
#define FB_VMODE_INTERLACED 1
#define FB_VMODE_DOUBLE 2
#define FB_VMODE_ODD_FLD_FIRST 4
#define FB_VMODE_MASK 255
#define FB_VMODE_YWRAP 256
#define FB_VMODE_SMOOTH_XPAN 512
#define FB_VMODE_CONUPDATE 512
#define FB_ROTATE_UR 0
#define FB_ROTATE_CW 1
#define FB_ROTATE_UD 2
#define FB_ROTATE_CCW 3
#define PICOS2KHZ(a) (1000000000UL / (a))
#define KHZ2PICOS(a) (1000000000UL / (a))
struct fb_var_screeninfo {
  __u32 xres;
  __u32 yres;
  __u32 xres_virtual;
  __u32 yres_virtual;
  __u32 xoffset;
  __u32 yoffset;
  __u32 bits_per_pixel;
  __u32 grayscale;
  struct fb_bitfield red;
  struct fb_bitfield green;
  struct fb_bitfield blue;
  struct fb_bitfield transp;
  __u32 nonstd;
  __u32 activate;
  __u32 height;
  __u32 width;
  __u32 accel_flags;
  __u32 pixclock;
  __u32 left_margin;
  __u32 right_margin;
  __u32 upper_margin;
  __u32 lower_margin;
  __u32 hsync_len;
  __u32 vsync_len;
  __u32 sync;
  __u32 vmode;
  __u32 rotate;
  __u32 colorspace;
  __u32 reserved[4];
};
struct fb_cmap {
  __u32 start;
  __u32 len;
  __u16 * red;
  __u16 * green;
  __u16 * blue;
  __u16 * transp;
};
struct fb_con2fbmap {
  __u32 console;
  __u32 framebuffer;
};
#define VESA_NO_BLANKING 0
#define VESA_VSYNC_SUSPEND 1
#define VESA_HSYNC_SUSPEND 2
#define VESA_POWERDOWN 3
enum {
  FB_BLANK_UNBLANK = VESA_NO_BLANKING,
  FB_BLANK_NORMAL = VESA_NO_BLANKING + 1,
  FB_BLANK_VSYNC_SUSPEND = VESA_VSYNC_SUSPEND + 1,
  FB_BLANK_HSYNC_SUSPEND = VESA_HSYNC_SUSPEND + 1,
  FB_BLANK_POWERDOWN = VESA_POWERDOWN + 1
};
#define FB_VBLANK_VBLANKING 0x001
#define FB_VBLANK_HBLANKING 0x002
#define FB_VBLANK_HAVE_VBLANK 0x004
#define FB_VBLANK_HAVE_HBLANK 0x008
#define FB_VBLANK_HAVE_COUNT 0x010
#define FB_VBLANK_HAVE_VCOUNT 0x020
#define FB_VBLANK_HAVE_HCOUNT 0x040
#define FB_VBLANK_VSYNCING 0x080
#define FB_VBLANK_HAVE_VSYNC 0x100
struct fb_vblank {
  __u32 flags;
  __u32 count;
  __u32 vcount;
  __u32 hcount;
  __u32 reserved[4];
};
#define ROP_COPY 0
#define ROP_XOR 1
struct fb_copyarea {
  __u32 dx;
  __u32 dy;
  __u32 width;
  __u32 height;
  __u32 sx;
  __u32 sy;
};
struct fb_fillrect {
  __u32 dx;
  __u32 dy;
  __u32 width;
  __u32 height;
  __u32 color;
  __u32 rop;
};
struct fb_image {
  __u32 dx;
  __u32 dy;
  __u32 width;
  __u32 height;
  __u32 fg_color;
  __u32 bg_color;
  __u8 depth;
  const char * data;
  struct fb_cmap cmap;
};
#define FB_CUR_SETIMAGE 0x01
#define FB_CUR_SETPOS 0x02
#define FB_CUR_SETHOT 0x04
#define FB_CUR_SETCMAP 0x08
#define FB_CUR_SETSHAPE 0x10
#define FB_CUR_SETSIZE 0x20
#define FB_CUR_SETALL 0xFF
struct fbcurpos {
  __u16 x, y;
};
struct fb_cursor {
  __u16 set;
  __u16 enable;
  __u16 rop;
  const char * mask;
  struct fbcurpos hot;
  struct fb_image image;
};
#define FB_BACKLIGHT_LEVELS 128
#define FB_BACKLIGHT_MAX 0xFF
#endif