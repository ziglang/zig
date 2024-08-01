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
#ifndef __LINUX_UAPI_SND_ASOC_H
#define __LINUX_UAPI_SND_ASOC_H
#include <linux/types.h>
#include <sound/asound.h>
#define SND_SOC_TPLG_MAX_CHAN 8
#define SND_SOC_TPLG_MAX_FORMATS 16
#define SND_SOC_TPLG_STREAM_CONFIG_MAX 8
#define SND_SOC_TPLG_HW_CONFIG_MAX 8
#define SND_SOC_TPLG_CTL_VOLSW 1
#define SND_SOC_TPLG_CTL_VOLSW_SX 2
#define SND_SOC_TPLG_CTL_VOLSW_XR_SX 3
#define SND_SOC_TPLG_CTL_ENUM 4
#define SND_SOC_TPLG_CTL_BYTES 5
#define SND_SOC_TPLG_CTL_ENUM_VALUE 6
#define SND_SOC_TPLG_CTL_RANGE 7
#define SND_SOC_TPLG_CTL_STROBE 8
#define SND_SOC_TPLG_DAPM_CTL_VOLSW 64
#define SND_SOC_TPLG_DAPM_CTL_ENUM_DOUBLE 65
#define SND_SOC_TPLG_DAPM_CTL_ENUM_VIRT 66
#define SND_SOC_TPLG_DAPM_CTL_ENUM_VALUE 67
#define SND_SOC_TPLG_DAPM_CTL_PIN 68
#define SND_SOC_TPLG_DAPM_INPUT 0
#define SND_SOC_TPLG_DAPM_OUTPUT 1
#define SND_SOC_TPLG_DAPM_MUX 2
#define SND_SOC_TPLG_DAPM_MIXER 3
#define SND_SOC_TPLG_DAPM_PGA 4
#define SND_SOC_TPLG_DAPM_OUT_DRV 5
#define SND_SOC_TPLG_DAPM_ADC 6
#define SND_SOC_TPLG_DAPM_DAC 7
#define SND_SOC_TPLG_DAPM_SWITCH 8
#define SND_SOC_TPLG_DAPM_PRE 9
#define SND_SOC_TPLG_DAPM_POST 10
#define SND_SOC_TPLG_DAPM_AIF_IN 11
#define SND_SOC_TPLG_DAPM_AIF_OUT 12
#define SND_SOC_TPLG_DAPM_DAI_IN 13
#define SND_SOC_TPLG_DAPM_DAI_OUT 14
#define SND_SOC_TPLG_DAPM_DAI_LINK 15
#define SND_SOC_TPLG_DAPM_BUFFER 16
#define SND_SOC_TPLG_DAPM_SCHEDULER 17
#define SND_SOC_TPLG_DAPM_EFFECT 18
#define SND_SOC_TPLG_DAPM_SIGGEN 19
#define SND_SOC_TPLG_DAPM_SRC 20
#define SND_SOC_TPLG_DAPM_ASRC 21
#define SND_SOC_TPLG_DAPM_ENCODER 22
#define SND_SOC_TPLG_DAPM_DECODER 23
#define SND_SOC_TPLG_DAPM_LAST SND_SOC_TPLG_DAPM_DECODER
#define SND_SOC_TPLG_MAGIC 0x41536F43
#define SND_SOC_TPLG_NUM_TEXTS 16
#define SND_SOC_TPLG_ABI_VERSION 0x5
#define SND_SOC_TPLG_ABI_VERSION_MIN 0x4
#define SND_SOC_TPLG_TLV_SIZE 32
#define SND_SOC_TPLG_TYPE_MIXER 1
#define SND_SOC_TPLG_TYPE_BYTES 2
#define SND_SOC_TPLG_TYPE_ENUM 3
#define SND_SOC_TPLG_TYPE_DAPM_GRAPH 4
#define SND_SOC_TPLG_TYPE_DAPM_WIDGET 5
#define SND_SOC_TPLG_TYPE_DAI_LINK 6
#define SND_SOC_TPLG_TYPE_PCM 7
#define SND_SOC_TPLG_TYPE_MANIFEST 8
#define SND_SOC_TPLG_TYPE_CODEC_LINK 9
#define SND_SOC_TPLG_TYPE_BACKEND_LINK 10
#define SND_SOC_TPLG_TYPE_PDATA 11
#define SND_SOC_TPLG_TYPE_DAI 12
#define SND_SOC_TPLG_TYPE_MAX SND_SOC_TPLG_TYPE_DAI
#define SND_SOC_TPLG_TYPE_VENDOR_FW 1000
#define SND_SOC_TPLG_TYPE_VENDOR_CONFIG 1001
#define SND_SOC_TPLG_TYPE_VENDOR_COEFF 1002
#define SND_SOC_TPLG_TYPEVENDOR_CODEC 1003
#define SND_SOC_TPLG_STREAM_PLAYBACK 0
#define SND_SOC_TPLG_STREAM_CAPTURE 1
#define SND_SOC_TPLG_TUPLE_TYPE_UUID 0
#define SND_SOC_TPLG_TUPLE_TYPE_STRING 1
#define SND_SOC_TPLG_TUPLE_TYPE_BOOL 2
#define SND_SOC_TPLG_TUPLE_TYPE_BYTE 3
#define SND_SOC_TPLG_TUPLE_TYPE_WORD 4
#define SND_SOC_TPLG_TUPLE_TYPE_SHORT 5
#define SND_SOC_TPLG_DAI_FLGBIT_SYMMETRIC_RATES (1 << 0)
#define SND_SOC_TPLG_DAI_FLGBIT_SYMMETRIC_CHANNELS (1 << 1)
#define SND_SOC_TPLG_DAI_FLGBIT_SYMMETRIC_SAMPLEBITS (1 << 2)
#define SND_SOC_TPLG_DAI_CLK_GATE_UNDEFINED 0
#define SND_SOC_TPLG_DAI_CLK_GATE_GATED 1
#define SND_SOC_TPLG_DAI_CLK_GATE_CONT 2
#define SND_SOC_TPLG_MCLK_CO 0
#define SND_SOC_TPLG_MCLK_CI 1
#define SND_SOC_DAI_FORMAT_I2S 1
#define SND_SOC_DAI_FORMAT_RIGHT_J 2
#define SND_SOC_DAI_FORMAT_LEFT_J 3
#define SND_SOC_DAI_FORMAT_DSP_A 4
#define SND_SOC_DAI_FORMAT_DSP_B 5
#define SND_SOC_DAI_FORMAT_AC97 6
#define SND_SOC_DAI_FORMAT_PDM 7
#define SND_SOC_DAI_FORMAT_MSB SND_SOC_DAI_FORMAT_LEFT_J
#define SND_SOC_DAI_FORMAT_LSB SND_SOC_DAI_FORMAT_RIGHT_J
#define SND_SOC_TPLG_LNK_FLGBIT_SYMMETRIC_RATES (1 << 0)
#define SND_SOC_TPLG_LNK_FLGBIT_SYMMETRIC_CHANNELS (1 << 1)
#define SND_SOC_TPLG_LNK_FLGBIT_SYMMETRIC_SAMPLEBITS (1 << 2)
#define SND_SOC_TPLG_LNK_FLGBIT_VOICE_WAKEUP (1 << 3)
#define SND_SOC_TPLG_BCLK_CM 0
#define SND_SOC_TPLG_BCLK_CS 1
#define SND_SOC_TPLG_FSYNC_CM 0
#define SND_SOC_TPLG_FSYNC_CS 1
struct snd_soc_tplg_hdr {
  __le32 magic;
  __le32 abi;
  __le32 version;
  __le32 type;
  __le32 size;
  __le32 vendor_type;
  __le32 payload_size;
  __le32 index;
  __le32 count;
} __attribute__((packed));
struct snd_soc_tplg_vendor_uuid_elem {
  __le32 token;
  char uuid[16];
} __attribute__((packed));
struct snd_soc_tplg_vendor_value_elem {
  __le32 token;
  __le32 value;
} __attribute__((packed));
struct snd_soc_tplg_vendor_string_elem {
  __le32 token;
  char string[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
} __attribute__((packed));
struct snd_soc_tplg_vendor_array {
  __le32 size;
  __le32 type;
  __le32 num_elems;
  union {
    struct snd_soc_tplg_vendor_uuid_elem uuid[0];
    struct snd_soc_tplg_vendor_value_elem value[0];
    struct snd_soc_tplg_vendor_string_elem string[0];
  };
} __attribute__((packed));
struct snd_soc_tplg_private {
  __le32 size;
  union {
    char data[0];
    struct snd_soc_tplg_vendor_array array[0];
  };
} __attribute__((packed));
struct snd_soc_tplg_tlv_dbscale {
  __le32 min;
  __le32 step;
  __le32 mute;
} __attribute__((packed));
struct snd_soc_tplg_ctl_tlv {
  __le32 size;
  __le32 type;
  union {
    __le32 data[SND_SOC_TPLG_TLV_SIZE];
    struct snd_soc_tplg_tlv_dbscale scale;
  };
} __attribute__((packed));
struct snd_soc_tplg_channel {
  __le32 size;
  __le32 reg;
  __le32 shift;
  __le32 id;
} __attribute__((packed));
struct snd_soc_tplg_io_ops {
  __le32 get;
  __le32 put;
  __le32 info;
} __attribute__((packed));
struct snd_soc_tplg_ctl_hdr {
  __le32 size;
  __le32 type;
  char name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  __le32 access;
  struct snd_soc_tplg_io_ops ops;
  struct snd_soc_tplg_ctl_tlv tlv;
} __attribute__((packed));
struct snd_soc_tplg_stream_caps {
  __le32 size;
  char name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  __le64 formats;
  __le32 rates;
  __le32 rate_min;
  __le32 rate_max;
  __le32 channels_min;
  __le32 channels_max;
  __le32 periods_min;
  __le32 periods_max;
  __le32 period_size_min;
  __le32 period_size_max;
  __le32 buffer_size_min;
  __le32 buffer_size_max;
  __le32 sig_bits;
} __attribute__((packed));
struct snd_soc_tplg_stream {
  __le32 size;
  char name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  __le64 format;
  __le32 rate;
  __le32 period_bytes;
  __le32 buffer_bytes;
  __le32 channels;
} __attribute__((packed));
struct snd_soc_tplg_hw_config {
  __le32 size;
  __le32 id;
  __le32 fmt;
  __u8 clock_gated;
  __u8 invert_bclk;
  __u8 invert_fsync;
  __u8 bclk_master;
  __u8 fsync_master;
  __u8 mclk_direction;
  __le16 reserved;
  __le32 mclk_rate;
  __le32 bclk_rate;
  __le32 fsync_rate;
  __le32 tdm_slots;
  __le32 tdm_slot_width;
  __le32 tx_slots;
  __le32 rx_slots;
  __le32 tx_channels;
  __le32 tx_chanmap[SND_SOC_TPLG_MAX_CHAN];
  __le32 rx_channels;
  __le32 rx_chanmap[SND_SOC_TPLG_MAX_CHAN];
} __attribute__((packed));
struct snd_soc_tplg_manifest {
  __le32 size;
  __le32 control_elems;
  __le32 widget_elems;
  __le32 graph_elems;
  __le32 pcm_elems;
  __le32 dai_link_elems;
  __le32 dai_elems;
  __le32 reserved[20];
  struct snd_soc_tplg_private priv;
} __attribute__((packed));
struct snd_soc_tplg_mixer_control {
  struct snd_soc_tplg_ctl_hdr hdr;
  __le32 size;
  __le32 min;
  __le32 max;
  __le32 platform_max;
  __le32 invert;
  __le32 num_channels;
  struct snd_soc_tplg_channel channel[SND_SOC_TPLG_MAX_CHAN];
  struct snd_soc_tplg_private priv;
} __attribute__((packed));
struct snd_soc_tplg_enum_control {
  struct snd_soc_tplg_ctl_hdr hdr;
  __le32 size;
  __le32 num_channels;
  struct snd_soc_tplg_channel channel[SND_SOC_TPLG_MAX_CHAN];
  __le32 items;
  __le32 mask;
  __le32 count;
  char texts[SND_SOC_TPLG_NUM_TEXTS][SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  __le32 values[SND_SOC_TPLG_NUM_TEXTS * SNDRV_CTL_ELEM_ID_NAME_MAXLEN / 4];
  struct snd_soc_tplg_private priv;
} __attribute__((packed));
struct snd_soc_tplg_bytes_control {
  struct snd_soc_tplg_ctl_hdr hdr;
  __le32 size;
  __le32 max;
  __le32 mask;
  __le32 base;
  __le32 num_regs;
  struct snd_soc_tplg_io_ops ext_ops;
  struct snd_soc_tplg_private priv;
} __attribute__((packed));
struct snd_soc_tplg_dapm_graph_elem {
  char sink[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  char control[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  char source[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
} __attribute__((packed));
struct snd_soc_tplg_dapm_widget {
  __le32 size;
  __le32 id;
  char name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  char sname[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  __le32 reg;
  __le32 shift;
  __le32 mask;
  __le32 subseq;
  __le32 invert;
  __le32 ignore_suspend;
  __le16 event_flags;
  __le16 event_type;
  __le32 num_kcontrols;
  struct snd_soc_tplg_private priv;
} __attribute__((packed));
struct snd_soc_tplg_pcm {
  __le32 size;
  char pcm_name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  char dai_name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  __le32 pcm_id;
  __le32 dai_id;
  __le32 playback;
  __le32 capture;
  __le32 compress;
  struct snd_soc_tplg_stream stream[SND_SOC_TPLG_STREAM_CONFIG_MAX];
  __le32 num_streams;
  struct snd_soc_tplg_stream_caps caps[2];
  __le32 flag_mask;
  __le32 flags;
  struct snd_soc_tplg_private priv;
} __attribute__((packed));
struct snd_soc_tplg_link_config {
  __le32 size;
  __le32 id;
  char name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  char stream_name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  struct snd_soc_tplg_stream stream[SND_SOC_TPLG_STREAM_CONFIG_MAX];
  __le32 num_streams;
  struct snd_soc_tplg_hw_config hw_config[SND_SOC_TPLG_HW_CONFIG_MAX];
  __le32 num_hw_configs;
  __le32 default_hw_config_id;
  __le32 flag_mask;
  __le32 flags;
  struct snd_soc_tplg_private priv;
} __attribute__((packed));
struct snd_soc_tplg_dai {
  __le32 size;
  char dai_name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  __le32 dai_id;
  __le32 playback;
  __le32 capture;
  struct snd_soc_tplg_stream_caps caps[2];
  __le32 flag_mask;
  __le32 flags;
  struct snd_soc_tplg_private priv;
} __attribute__((packed));
struct snd_soc_tplg_manifest_v4 {
  __le32 size;
  __le32 control_elems;
  __le32 widget_elems;
  __le32 graph_elems;
  __le32 pcm_elems;
  __le32 dai_link_elems;
  struct snd_soc_tplg_private priv;
} __packed;
struct snd_soc_tplg_stream_caps_v4 {
  __le32 size;
  char name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  __le64 formats;
  __le32 rates;
  __le32 rate_min;
  __le32 rate_max;
  __le32 channels_min;
  __le32 channels_max;
  __le32 periods_min;
  __le32 periods_max;
  __le32 period_size_min;
  __le32 period_size_max;
  __le32 buffer_size_min;
  __le32 buffer_size_max;
} __packed;
struct snd_soc_tplg_pcm_v4 {
  __le32 size;
  char pcm_name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  char dai_name[SNDRV_CTL_ELEM_ID_NAME_MAXLEN];
  __le32 pcm_id;
  __le32 dai_id;
  __le32 playback;
  __le32 capture;
  __le32 compress;
  struct snd_soc_tplg_stream stream[SND_SOC_TPLG_STREAM_CONFIG_MAX];
  __le32 num_streams;
  struct snd_soc_tplg_stream_caps_v4 caps[2];
} __packed;
struct snd_soc_tplg_link_config_v4 {
  __le32 size;
  __le32 id;
  struct snd_soc_tplg_stream stream[SND_SOC_TPLG_STREAM_CONFIG_MAX];
  __le32 num_streams;
} __packed;
#endif