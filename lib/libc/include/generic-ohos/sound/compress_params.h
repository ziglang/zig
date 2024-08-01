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
#ifndef __SND_COMPRESS_PARAMS_H
#define __SND_COMPRESS_PARAMS_H
#include <linux/types.h>
#define MAX_NUM_CODECS 32
#define MAX_NUM_CODEC_DESCRIPTORS 32
#define MAX_NUM_BITRATES 32
#define MAX_NUM_SAMPLE_RATES 32
#define SND_AUDIOCODEC_PCM ((__u32) 0x00000001)
#define SND_AUDIOCODEC_MP3 ((__u32) 0x00000002)
#define SND_AUDIOCODEC_AMR ((__u32) 0x00000003)
#define SND_AUDIOCODEC_AMRWB ((__u32) 0x00000004)
#define SND_AUDIOCODEC_AMRWBPLUS ((__u32) 0x00000005)
#define SND_AUDIOCODEC_AAC ((__u32) 0x00000006)
#define SND_AUDIOCODEC_WMA ((__u32) 0x00000007)
#define SND_AUDIOCODEC_REAL ((__u32) 0x00000008)
#define SND_AUDIOCODEC_VORBIS ((__u32) 0x00000009)
#define SND_AUDIOCODEC_FLAC ((__u32) 0x0000000A)
#define SND_AUDIOCODEC_IEC61937 ((__u32) 0x0000000B)
#define SND_AUDIOCODEC_G723_1 ((__u32) 0x0000000C)
#define SND_AUDIOCODEC_G729 ((__u32) 0x0000000D)
#define SND_AUDIOCODEC_BESPOKE ((__u32) 0x0000000E)
#define SND_AUDIOCODEC_ALAC ((__u32) 0x0000000F)
#define SND_AUDIOCODEC_APE ((__u32) 0x00000010)
#define SND_AUDIOCODEC_MAX SND_AUDIOCODEC_APE
#define SND_AUDIOPROFILE_PCM ((__u32) 0x00000001)
#define SND_AUDIOCHANMODE_MP3_MONO ((__u32) 0x00000001)
#define SND_AUDIOCHANMODE_MP3_STEREO ((__u32) 0x00000002)
#define SND_AUDIOCHANMODE_MP3_JOINTSTEREO ((__u32) 0x00000004)
#define SND_AUDIOCHANMODE_MP3_DUAL ((__u32) 0x00000008)
#define SND_AUDIOPROFILE_AMR ((__u32) 0x00000001)
#define SND_AUDIOMODE_AMR_DTX_OFF ((__u32) 0x00000001)
#define SND_AUDIOMODE_AMR_VAD1 ((__u32) 0x00000002)
#define SND_AUDIOMODE_AMR_VAD2 ((__u32) 0x00000004)
#define SND_AUDIOSTREAMFORMAT_UNDEFINED ((__u32) 0x00000000)
#define SND_AUDIOSTREAMFORMAT_CONFORMANCE ((__u32) 0x00000001)
#define SND_AUDIOSTREAMFORMAT_IF1 ((__u32) 0x00000002)
#define SND_AUDIOSTREAMFORMAT_IF2 ((__u32) 0x00000004)
#define SND_AUDIOSTREAMFORMAT_FSF ((__u32) 0x00000008)
#define SND_AUDIOSTREAMFORMAT_RTPPAYLOAD ((__u32) 0x00000010)
#define SND_AUDIOSTREAMFORMAT_ITU ((__u32) 0x00000020)
#define SND_AUDIOPROFILE_AMRWB ((__u32) 0x00000001)
#define SND_AUDIOMODE_AMRWB_DTX_OFF ((__u32) 0x00000001)
#define SND_AUDIOMODE_AMRWB_VAD1 ((__u32) 0x00000002)
#define SND_AUDIOMODE_AMRWB_VAD2 ((__u32) 0x00000004)
#define SND_AUDIOPROFILE_AMRWBPLUS ((__u32) 0x00000001)
#define SND_AUDIOPROFILE_AAC ((__u32) 0x00000001)
#define SND_AUDIOMODE_AAC_MAIN ((__u32) 0x00000001)
#define SND_AUDIOMODE_AAC_LC ((__u32) 0x00000002)
#define SND_AUDIOMODE_AAC_SSR ((__u32) 0x00000004)
#define SND_AUDIOMODE_AAC_LTP ((__u32) 0x00000008)
#define SND_AUDIOMODE_AAC_HE ((__u32) 0x00000010)
#define SND_AUDIOMODE_AAC_SCALABLE ((__u32) 0x00000020)
#define SND_AUDIOMODE_AAC_ERLC ((__u32) 0x00000040)
#define SND_AUDIOMODE_AAC_LD ((__u32) 0x00000080)
#define SND_AUDIOMODE_AAC_HE_PS ((__u32) 0x00000100)
#define SND_AUDIOMODE_AAC_HE_MPS ((__u32) 0x00000200)
#define SND_AUDIOSTREAMFORMAT_MP2ADTS ((__u32) 0x00000001)
#define SND_AUDIOSTREAMFORMAT_MP4ADTS ((__u32) 0x00000002)
#define SND_AUDIOSTREAMFORMAT_MP4LOAS ((__u32) 0x00000004)
#define SND_AUDIOSTREAMFORMAT_MP4LATM ((__u32) 0x00000008)
#define SND_AUDIOSTREAMFORMAT_ADIF ((__u32) 0x00000010)
#define SND_AUDIOSTREAMFORMAT_MP4FF ((__u32) 0x00000020)
#define SND_AUDIOSTREAMFORMAT_RAW ((__u32) 0x00000040)
#define SND_AUDIOPROFILE_WMA7 ((__u32) 0x00000001)
#define SND_AUDIOPROFILE_WMA8 ((__u32) 0x00000002)
#define SND_AUDIOPROFILE_WMA9 ((__u32) 0x00000004)
#define SND_AUDIOPROFILE_WMA10 ((__u32) 0x00000008)
#define SND_AUDIOPROFILE_WMA9_PRO ((__u32) 0x00000010)
#define SND_AUDIOPROFILE_WMA9_LOSSLESS ((__u32) 0x00000020)
#define SND_AUDIOPROFILE_WMA10_LOSSLESS ((__u32) 0x00000040)
#define SND_AUDIOMODE_WMA_LEVEL1 ((__u32) 0x00000001)
#define SND_AUDIOMODE_WMA_LEVEL2 ((__u32) 0x00000002)
#define SND_AUDIOMODE_WMA_LEVEL3 ((__u32) 0x00000004)
#define SND_AUDIOMODE_WMA_LEVEL4 ((__u32) 0x00000008)
#define SND_AUDIOMODE_WMAPRO_LEVELM0 ((__u32) 0x00000010)
#define SND_AUDIOMODE_WMAPRO_LEVELM1 ((__u32) 0x00000020)
#define SND_AUDIOMODE_WMAPRO_LEVELM2 ((__u32) 0x00000040)
#define SND_AUDIOMODE_WMAPRO_LEVELM3 ((__u32) 0x00000080)
#define SND_AUDIOSTREAMFORMAT_WMA_ASF ((__u32) 0x00000001)
#define SND_AUDIOSTREAMFORMAT_WMA_NOASF_HDR ((__u32) 0x00000002)
#define SND_AUDIOPROFILE_REALAUDIO ((__u32) 0x00000001)
#define SND_AUDIOMODE_REALAUDIO_G2 ((__u32) 0x00000001)
#define SND_AUDIOMODE_REALAUDIO_8 ((__u32) 0x00000002)
#define SND_AUDIOMODE_REALAUDIO_10 ((__u32) 0x00000004)
#define SND_AUDIOMODE_REALAUDIO_SURROUND ((__u32) 0x00000008)
#define SND_AUDIOPROFILE_VORBIS ((__u32) 0x00000001)
#define SND_AUDIOMODE_VORBIS ((__u32) 0x00000001)
#define SND_AUDIOPROFILE_FLAC ((__u32) 0x00000001)
#define SND_AUDIOMODE_FLAC_LEVEL0 ((__u32) 0x00000001)
#define SND_AUDIOMODE_FLAC_LEVEL1 ((__u32) 0x00000002)
#define SND_AUDIOMODE_FLAC_LEVEL2 ((__u32) 0x00000004)
#define SND_AUDIOMODE_FLAC_LEVEL3 ((__u32) 0x00000008)
#define SND_AUDIOMODE_FLAC_LEVEL4 ((__u32) 0x00000010)
#define SND_AUDIOMODE_FLAC_LEVEL5 ((__u32) 0x00000020)
#define SND_AUDIOMODE_FLAC_LEVEL6 ((__u32) 0x00000040)
#define SND_AUDIOMODE_FLAC_LEVEL7 ((__u32) 0x00000080)
#define SND_AUDIOMODE_FLAC_LEVEL8 ((__u32) 0x00000100)
#define SND_AUDIOSTREAMFORMAT_FLAC ((__u32) 0x00000001)
#define SND_AUDIOSTREAMFORMAT_FLAC_OGG ((__u32) 0x00000002)
#define SND_AUDIOPROFILE_IEC61937 ((__u32) 0x00000001)
#define SND_AUDIOPROFILE_IEC61937_SPDIF ((__u32) 0x00000002)
#define SND_AUDIOMODE_IEC_REF_STREAM_HEADER ((__u32) 0x00000000)
#define SND_AUDIOMODE_IEC_LPCM ((__u32) 0x00000001)
#define SND_AUDIOMODE_IEC_AC3 ((__u32) 0x00000002)
#define SND_AUDIOMODE_IEC_MPEG1 ((__u32) 0x00000004)
#define SND_AUDIOMODE_IEC_MP3 ((__u32) 0x00000008)
#define SND_AUDIOMODE_IEC_MPEG2 ((__u32) 0x00000010)
#define SND_AUDIOMODE_IEC_AACLC ((__u32) 0x00000020)
#define SND_AUDIOMODE_IEC_DTS ((__u32) 0x00000040)
#define SND_AUDIOMODE_IEC_ATRAC ((__u32) 0x00000080)
#define SND_AUDIOMODE_IEC_SACD ((__u32) 0x00000100)
#define SND_AUDIOMODE_IEC_EAC3 ((__u32) 0x00000200)
#define SND_AUDIOMODE_IEC_DTS_HD ((__u32) 0x00000400)
#define SND_AUDIOMODE_IEC_MLP ((__u32) 0x00000800)
#define SND_AUDIOMODE_IEC_DST ((__u32) 0x00001000)
#define SND_AUDIOMODE_IEC_WMAPRO ((__u32) 0x00002000)
#define SND_AUDIOMODE_IEC_REF_CXT ((__u32) 0x00004000)
#define SND_AUDIOMODE_IEC_HE_AAC ((__u32) 0x00008000)
#define SND_AUDIOMODE_IEC_HE_AAC2 ((__u32) 0x00010000)
#define SND_AUDIOMODE_IEC_MPEG_SURROUND ((__u32) 0x00020000)
#define SND_AUDIOPROFILE_G723_1 ((__u32) 0x00000001)
#define SND_AUDIOMODE_G723_1_ANNEX_A ((__u32) 0x00000001)
#define SND_AUDIOMODE_G723_1_ANNEX_B ((__u32) 0x00000002)
#define SND_AUDIOMODE_G723_1_ANNEX_C ((__u32) 0x00000004)
#define SND_AUDIOPROFILE_G729 ((__u32) 0x00000001)
#define SND_AUDIOMODE_G729_ANNEX_A ((__u32) 0x00000001)
#define SND_AUDIOMODE_G729_ANNEX_B ((__u32) 0x00000002)
#define SND_RATECONTROLMODE_CONSTANTBITRATE ((__u32) 0x00000001)
#define SND_RATECONTROLMODE_VARIABLEBITRATE ((__u32) 0x00000002)
struct snd_enc_wma {
  __u32 super_block_align;
};
struct snd_enc_vorbis {
  __s32 quality;
  __u32 managed;
  __u32 max_bit_rate;
  __u32 min_bit_rate;
  __u32 downmix;
} __attribute__((packed, aligned(4)));
struct snd_enc_real {
  __u32 quant_bits;
  __u32 start_region;
  __u32 num_regions;
} __attribute__((packed, aligned(4)));
struct snd_enc_flac {
  __u32 num;
  __u32 gain;
} __attribute__((packed, aligned(4)));
struct snd_enc_generic {
  __u32 bw;
  __s32 reserved[15];
} __attribute__((packed, aligned(4)));
struct snd_dec_flac {
  __u16 sample_size;
  __u16 min_blk_size;
  __u16 max_blk_size;
  __u16 min_frame_size;
  __u16 max_frame_size;
  __u16 reserved;
} __attribute__((packed, aligned(4)));
struct snd_dec_wma {
  __u32 encoder_option;
  __u32 adv_encoder_option;
  __u32 adv_encoder_option2;
  __u32 reserved;
} __attribute__((packed, aligned(4)));
struct snd_dec_alac {
  __u32 frame_length;
  __u8 compatible_version;
  __u8 pb;
  __u8 mb;
  __u8 kb;
  __u32 max_run;
  __u32 max_frame_bytes;
} __attribute__((packed, aligned(4)));
struct snd_dec_ape {
  __u16 compatible_version;
  __u16 compression_level;
  __u32 format_flags;
  __u32 blocks_per_frame;
  __u32 final_frame_blocks;
  __u32 total_frames;
  __u32 seek_table_present;
} __attribute__((packed, aligned(4)));
union snd_codec_options {
  struct snd_enc_wma wma;
  struct snd_enc_vorbis vorbis;
  struct snd_enc_real real;
  struct snd_enc_flac flac;
  struct snd_enc_generic generic;
  struct snd_dec_flac flac_d;
  struct snd_dec_wma wma_d;
  struct snd_dec_alac alac_d;
  struct snd_dec_ape ape_d;
} __attribute__((packed, aligned(4)));
struct snd_codec_desc {
  __u32 max_ch;
  __u32 sample_rates[MAX_NUM_SAMPLE_RATES];
  __u32 num_sample_rates;
  __u32 bit_rate[MAX_NUM_BITRATES];
  __u32 num_bitrates;
  __u32 rate_control;
  __u32 profiles;
  __u32 modes;
  __u32 formats;
  __u32 min_buffer;
  __u32 reserved[15];
} __attribute__((packed, aligned(4)));
struct snd_codec {
  __u32 id;
  __u32 ch_in;
  __u32 ch_out;
  __u32 sample_rate;
  __u32 bit_rate;
  __u32 rate_control;
  __u32 profile;
  __u32 level;
  __u32 ch_mode;
  __u32 format;
  __u32 align;
  union snd_codec_options options;
  __u32 reserved[3];
} __attribute__((packed, aligned(4)));
#endif