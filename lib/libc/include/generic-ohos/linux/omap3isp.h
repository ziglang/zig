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
#ifndef OMAP3_ISP_USER_H
#define OMAP3_ISP_USER_H
#include <linux/types.h>
#include <linux/videodev2.h>
#define VIDIOC_OMAP3ISP_CCDC_CFG _IOWR('V', BASE_VIDIOC_PRIVATE + 1, struct omap3isp_ccdc_update_config)
#define VIDIOC_OMAP3ISP_PRV_CFG _IOWR('V', BASE_VIDIOC_PRIVATE + 2, struct omap3isp_prev_update_config)
#define VIDIOC_OMAP3ISP_AEWB_CFG _IOWR('V', BASE_VIDIOC_PRIVATE + 3, struct omap3isp_h3a_aewb_config)
#define VIDIOC_OMAP3ISP_HIST_CFG _IOWR('V', BASE_VIDIOC_PRIVATE + 4, struct omap3isp_hist_config)
#define VIDIOC_OMAP3ISP_AF_CFG _IOWR('V', BASE_VIDIOC_PRIVATE + 5, struct omap3isp_h3a_af_config)
#define VIDIOC_OMAP3ISP_STAT_REQ _IOWR('V', BASE_VIDIOC_PRIVATE + 6, struct omap3isp_stat_data)
#define VIDIOC_OMAP3ISP_STAT_REQ_TIME32 _IOWR('V', BASE_VIDIOC_PRIVATE + 6, struct omap3isp_stat_data_time32)
#define VIDIOC_OMAP3ISP_STAT_EN _IOWR('V', BASE_VIDIOC_PRIVATE + 7, unsigned long)
#define V4L2_EVENT_OMAP3ISP_CLASS (V4L2_EVENT_PRIVATE_START | 0x100)
#define V4L2_EVENT_OMAP3ISP_AEWB (V4L2_EVENT_OMAP3ISP_CLASS | 0x1)
#define V4L2_EVENT_OMAP3ISP_AF (V4L2_EVENT_OMAP3ISP_CLASS | 0x2)
#define V4L2_EVENT_OMAP3ISP_HIST (V4L2_EVENT_OMAP3ISP_CLASS | 0x3)
struct omap3isp_stat_event_status {
  __u32 frame_number;
  __u16 config_counter;
  __u8 buf_err;
};
#define OMAP3ISP_AEWB_MAX_SATURATION_LIM 1023
#define OMAP3ISP_AEWB_MIN_WIN_H 2
#define OMAP3ISP_AEWB_MAX_WIN_H 256
#define OMAP3ISP_AEWB_MIN_WIN_W 6
#define OMAP3ISP_AEWB_MAX_WIN_W 256
#define OMAP3ISP_AEWB_MIN_WINVC 1
#define OMAP3ISP_AEWB_MIN_WINHC 1
#define OMAP3ISP_AEWB_MAX_WINVC 128
#define OMAP3ISP_AEWB_MAX_WINHC 36
#define OMAP3ISP_AEWB_MAX_WINSTART 4095
#define OMAP3ISP_AEWB_MIN_SUB_INC 2
#define OMAP3ISP_AEWB_MAX_SUB_INC 32
#define OMAP3ISP_AEWB_MAX_BUF_SIZE 83600
#define OMAP3ISP_AF_IIRSH_MIN 0
#define OMAP3ISP_AF_IIRSH_MAX 4095
#define OMAP3ISP_AF_PAXEL_HORIZONTAL_COUNT_MIN 1
#define OMAP3ISP_AF_PAXEL_HORIZONTAL_COUNT_MAX 36
#define OMAP3ISP_AF_PAXEL_VERTICAL_COUNT_MIN 1
#define OMAP3ISP_AF_PAXEL_VERTICAL_COUNT_MAX 128
#define OMAP3ISP_AF_PAXEL_INCREMENT_MIN 2
#define OMAP3ISP_AF_PAXEL_INCREMENT_MAX 32
#define OMAP3ISP_AF_PAXEL_HEIGHT_MIN 2
#define OMAP3ISP_AF_PAXEL_HEIGHT_MAX 256
#define OMAP3ISP_AF_PAXEL_WIDTH_MIN 16
#define OMAP3ISP_AF_PAXEL_WIDTH_MAX 256
#define OMAP3ISP_AF_PAXEL_HZSTART_MIN 1
#define OMAP3ISP_AF_PAXEL_HZSTART_MAX 4095
#define OMAP3ISP_AF_PAXEL_VTSTART_MIN 0
#define OMAP3ISP_AF_PAXEL_VTSTART_MAX 4095
#define OMAP3ISP_AF_THRESHOLD_MAX 255
#define OMAP3ISP_AF_COEF_MAX 4095
#define OMAP3ISP_AF_PAXEL_SIZE 48
#define OMAP3ISP_AF_MAX_BUF_SIZE 221184
struct omap3isp_h3a_aewb_config {
  __u32 buf_size;
  __u16 config_counter;
  __u16 saturation_limit;
  __u16 win_height;
  __u16 win_width;
  __u16 ver_win_count;
  __u16 hor_win_count;
  __u16 ver_win_start;
  __u16 hor_win_start;
  __u16 blk_ver_win_start;
  __u16 blk_win_height;
  __u16 subsample_ver_inc;
  __u16 subsample_hor_inc;
  __u8 alaw_enable;
};
struct omap3isp_stat_data {
  struct timeval ts;
  void __user * buf;
  __u32 buf_size;
  __u16 frame_number;
  __u16 cur_frame;
  __u16 config_counter;
};
#define OMAP3ISP_HIST_BINS_32 0
#define OMAP3ISP_HIST_BINS_64 1
#define OMAP3ISP_HIST_BINS_128 2
#define OMAP3ISP_HIST_BINS_256 3
#define OMAP3ISP_HIST_MEM_SIZE_BINS(n) ((1 << ((n) + 5)) * 4 * 4)
#define OMAP3ISP_HIST_MEM_SIZE 1024
#define OMAP3ISP_HIST_MIN_REGIONS 1
#define OMAP3ISP_HIST_MAX_REGIONS 4
#define OMAP3ISP_HIST_MAX_WB_GAIN 255
#define OMAP3ISP_HIST_MIN_WB_GAIN 0
#define OMAP3ISP_HIST_MAX_BIT_WIDTH 14
#define OMAP3ISP_HIST_MIN_BIT_WIDTH 8
#define OMAP3ISP_HIST_MAX_WG 4
#define OMAP3ISP_HIST_MAX_BUF_SIZE 4096
#define OMAP3ISP_HIST_SOURCE_CCDC 0
#define OMAP3ISP_HIST_SOURCE_MEM 1
#define OMAP3ISP_HIST_CFA_BAYER 0
#define OMAP3ISP_HIST_CFA_FOVEONX3 1
struct omap3isp_hist_region {
  __u16 h_start;
  __u16 h_end;
  __u16 v_start;
  __u16 v_end;
};
struct omap3isp_hist_config {
  __u32 buf_size;
  __u16 config_counter;
  __u8 num_acc_frames;
  __u16 hist_bins;
  __u8 cfa;
  __u8 wg[OMAP3ISP_HIST_MAX_WG];
  __u8 num_regions;
  struct omap3isp_hist_region region[OMAP3ISP_HIST_MAX_REGIONS];
};
#define OMAP3ISP_AF_NUM_COEF 11
enum omap3isp_h3a_af_fvmode {
  OMAP3ISP_AF_MODE_SUMMED = 0,
  OMAP3ISP_AF_MODE_PEAK = 1
};
enum omap3isp_h3a_af_rgbpos {
  OMAP3ISP_AF_GR_GB_BAYER = 0,
  OMAP3ISP_AF_RG_GB_BAYER = 1,
  OMAP3ISP_AF_GR_BG_BAYER = 2,
  OMAP3ISP_AF_RG_BG_BAYER = 3,
  OMAP3ISP_AF_GG_RB_CUSTOM = 4,
  OMAP3ISP_AF_RB_GG_CUSTOM = 5
};
struct omap3isp_h3a_af_hmf {
  __u8 enable;
  __u8 threshold;
};
struct omap3isp_h3a_af_iir {
  __u16 h_start;
  __u16 coeff_set0[OMAP3ISP_AF_NUM_COEF];
  __u16 coeff_set1[OMAP3ISP_AF_NUM_COEF];
};
struct omap3isp_h3a_af_paxel {
  __u16 h_start;
  __u16 v_start;
  __u8 width;
  __u8 height;
  __u8 h_cnt;
  __u8 v_cnt;
  __u8 line_inc;
};
struct omap3isp_h3a_af_config {
  __u32 buf_size;
  __u16 config_counter;
  struct omap3isp_h3a_af_hmf hmf;
  struct omap3isp_h3a_af_iir iir;
  struct omap3isp_h3a_af_paxel paxel;
  enum omap3isp_h3a_af_rgbpos rgb_pos;
  enum omap3isp_h3a_af_fvmode fvmode;
  __u8 alaw_enable;
};
#define OMAP3ISP_CCDC_ALAW (1 << 0)
#define OMAP3ISP_CCDC_LPF (1 << 1)
#define OMAP3ISP_CCDC_BLCLAMP (1 << 2)
#define OMAP3ISP_CCDC_BCOMP (1 << 3)
#define OMAP3ISP_CCDC_FPC (1 << 4)
#define OMAP3ISP_CCDC_CULL (1 << 5)
#define OMAP3ISP_CCDC_CONFIG_LSC (1 << 7)
#define OMAP3ISP_CCDC_TBL_LSC (1 << 8)
#define OMAP3ISP_RGB_MAX 3
enum omap3isp_alaw_ipwidth {
  OMAP3ISP_ALAW_BIT12_3 = 0x3,
  OMAP3ISP_ALAW_BIT11_2 = 0x4,
  OMAP3ISP_ALAW_BIT10_1 = 0x5,
  OMAP3ISP_ALAW_BIT9_0 = 0x6
};
struct omap3isp_ccdc_lsc_config {
  __u16 offset;
  __u8 gain_mode_n;
  __u8 gain_mode_m;
  __u8 gain_format;
  __u16 fmtsph;
  __u16 fmtlnh;
  __u16 fmtslv;
  __u16 fmtlnv;
  __u8 initial_x;
  __u8 initial_y;
  __u32 size;
};
struct omap3isp_ccdc_bclamp {
  __u8 obgain;
  __u8 obstpixel;
  __u8 oblines;
  __u8 oblen;
  __u16 dcsubval;
};
struct omap3isp_ccdc_fpc {
  __u16 fpnum;
  __u32 fpcaddr;
};
struct omap3isp_ccdc_blcomp {
  __u8 b_mg;
  __u8 gb_g;
  __u8 gr_cy;
  __u8 r_ye;
};
struct omap3isp_ccdc_culling {
  __u8 v_pattern;
  __u16 h_odd;
  __u16 h_even;
};
struct omap3isp_ccdc_update_config {
  __u16 update;
  __u16 flag;
  enum omap3isp_alaw_ipwidth alawip;
  struct omap3isp_ccdc_bclamp __user * bclamp;
  struct omap3isp_ccdc_blcomp __user * blcomp;
  struct omap3isp_ccdc_fpc __user * fpc;
  struct omap3isp_ccdc_lsc_config __user * lsc_cfg;
  struct omap3isp_ccdc_culling __user * cull;
  __u8 __user * lsc;
};
#define OMAP3ISP_PREV_LUMAENH (1 << 0)
#define OMAP3ISP_PREV_INVALAW (1 << 1)
#define OMAP3ISP_PREV_HRZ_MED (1 << 2)
#define OMAP3ISP_PREV_CFA (1 << 3)
#define OMAP3ISP_PREV_CHROMA_SUPP (1 << 4)
#define OMAP3ISP_PREV_WB (1 << 5)
#define OMAP3ISP_PREV_BLKADJ (1 << 6)
#define OMAP3ISP_PREV_RGB2RGB (1 << 7)
#define OMAP3ISP_PREV_COLOR_CONV (1 << 8)
#define OMAP3ISP_PREV_YC_LIMIT (1 << 9)
#define OMAP3ISP_PREV_DEFECT_COR (1 << 10)
#define OMAP3ISP_PREV_DRK_FRM_CAPTURE (1 << 12)
#define OMAP3ISP_PREV_DRK_FRM_SUBTRACT (1 << 13)
#define OMAP3ISP_PREV_LENS_SHADING (1 << 14)
#define OMAP3ISP_PREV_NF (1 << 15)
#define OMAP3ISP_PREV_GAMMA (1 << 16)
#define OMAP3ISP_PREV_NF_TBL_SIZE 64
#define OMAP3ISP_PREV_CFA_TBL_SIZE 576
#define OMAP3ISP_PREV_CFA_BLK_SIZE (OMAP3ISP_PREV_CFA_TBL_SIZE / 4)
#define OMAP3ISP_PREV_GAMMA_TBL_SIZE 1024
#define OMAP3ISP_PREV_YENH_TBL_SIZE 128
#define OMAP3ISP_PREV_DETECT_CORRECT_CHANNELS 4
struct omap3isp_prev_hmed {
  __u8 odddist;
  __u8 evendist;
  __u8 thres;
};
enum omap3isp_cfa_fmt {
  OMAP3ISP_CFAFMT_BAYER,
  OMAP3ISP_CFAFMT_SONYVGA,
  OMAP3ISP_CFAFMT_RGBFOVEON,
  OMAP3ISP_CFAFMT_DNSPL,
  OMAP3ISP_CFAFMT_HONEYCOMB,
  OMAP3ISP_CFAFMT_RRGGBBFOVEON
};
struct omap3isp_prev_cfa {
  enum omap3isp_cfa_fmt format;
  __u8 gradthrs_vert;
  __u8 gradthrs_horz;
  __u32 table[4][OMAP3ISP_PREV_CFA_BLK_SIZE];
};
struct omap3isp_prev_csup {
  __u8 gain;
  __u8 thres;
  __u8 hypf_en;
};
struct omap3isp_prev_wbal {
  __u16 dgain;
  __u8 coef3;
  __u8 coef2;
  __u8 coef1;
  __u8 coef0;
};
struct omap3isp_prev_blkadj {
  __u8 red;
  __u8 green;
  __u8 blue;
};
struct omap3isp_prev_rgbtorgb {
  __u16 matrix[OMAP3ISP_RGB_MAX][OMAP3ISP_RGB_MAX];
  __u16 offset[OMAP3ISP_RGB_MAX];
};
struct omap3isp_prev_csc {
  __u16 matrix[OMAP3ISP_RGB_MAX][OMAP3ISP_RGB_MAX];
  __s16 offset[OMAP3ISP_RGB_MAX];
};
struct omap3isp_prev_yclimit {
  __u8 minC;
  __u8 maxC;
  __u8 minY;
  __u8 maxY;
};
struct omap3isp_prev_dcor {
  __u8 couplet_mode_en;
  __u32 detect_correct[OMAP3ISP_PREV_DETECT_CORRECT_CHANNELS];
};
struct omap3isp_prev_nf {
  __u8 spread;
  __u32 table[OMAP3ISP_PREV_NF_TBL_SIZE];
};
struct omap3isp_prev_gtables {
  __u32 red[OMAP3ISP_PREV_GAMMA_TBL_SIZE];
  __u32 green[OMAP3ISP_PREV_GAMMA_TBL_SIZE];
  __u32 blue[OMAP3ISP_PREV_GAMMA_TBL_SIZE];
};
struct omap3isp_prev_luma {
  __u32 table[OMAP3ISP_PREV_YENH_TBL_SIZE];
};
struct omap3isp_prev_update_config {
  __u32 update;
  __u32 flag;
  __u32 shading_shift;
  struct omap3isp_prev_luma __user * luma;
  struct omap3isp_prev_hmed __user * hmed;
  struct omap3isp_prev_cfa __user * cfa;
  struct omap3isp_prev_csup __user * csup;
  struct omap3isp_prev_wbal __user * wbal;
  struct omap3isp_prev_blkadj __user * blkadj;
  struct omap3isp_prev_rgbtorgb __user * rgb2rgb;
  struct omap3isp_prev_csc __user * csc;
  struct omap3isp_prev_yclimit __user * yclimit;
  struct omap3isp_prev_dcor __user * dcor;
  struct omap3isp_prev_nf __user * nf;
  struct omap3isp_prev_gtables __user * gamma;
};
#endif