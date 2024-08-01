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
#ifndef _UAPISOUNDCARD_H
#define _UAPISOUNDCARD_H
#define SOUND_VERSION 0x030802
#define OPEN_SOUND_SYSTEM
#include <linux/ioctl.h>
#include <endian.h>
#define SNDCARD_ADLIB 1
#define SNDCARD_SB 2
#define SNDCARD_PAS 3
#define SNDCARD_GUS 4
#define SNDCARD_MPU401 5
#define SNDCARD_SB16 6
#define SNDCARD_SB16MIDI 7
#define SNDCARD_UART6850 8
#define SNDCARD_GUS16 9
#define SNDCARD_MSS 10
#define SNDCARD_PSS 11
#define SNDCARD_SSCAPE 12
#define SNDCARD_PSS_MPU 13
#define SNDCARD_PSS_MSS 14
#define SNDCARD_SSCAPE_MSS 15
#define SNDCARD_TRXPRO 16
#define SNDCARD_TRXPRO_SB 17
#define SNDCARD_TRXPRO_MPU 18
#define SNDCARD_MAD16 19
#define SNDCARD_MAD16_MPU 20
#define SNDCARD_CS4232 21
#define SNDCARD_CS4232_MPU 22
#define SNDCARD_MAUI 23
#define SNDCARD_PSEUDO_MSS 24
#define SNDCARD_GUSPNP 25
#define SNDCARD_UART401 26
#ifndef _SIOWR
#if defined(_IOWR) && (defined(_AIX) || !defined(sun) && !defined(sparc) && !defined(__sparc__) && !defined(__INCioctlh) && !defined(__Lynx__))
#define SIOCPARM_MASK IOCPARM_MASK
#define SIOC_VOID IOC_VOID
#define SIOC_OUT IOC_OUT
#define SIOC_IN IOC_IN
#define SIOC_INOUT IOC_INOUT
#define _SIOC_SIZE _IOC_SIZE
#define _SIOC_DIR _IOC_DIR
#define _SIOC_NONE _IOC_NONE
#define _SIOC_READ _IOC_READ
#define _SIOC_WRITE _IOC_WRITE
#define _SIO _IO
#define _SIOR _IOR
#define _SIOW _IOW
#define _SIOWR _IOWR
#else
#define SIOCPARM_MASK 0x1fff
#define SIOC_VOID 0x00000000
#define SIOC_OUT 0x20000000
#define SIOC_IN 0x40000000
#define SIOC_INOUT (SIOC_IN | SIOC_OUT)
#define _SIO(x,y) ((int) (SIOC_VOID | (x << 8) | y))
#define _SIOR(x,y,t) ((int) (SIOC_OUT | ((sizeof(t) & SIOCPARM_MASK) << 16) | (x << 8) | y))
#define _SIOW(x,y,t) ((int) (SIOC_IN | ((sizeof(t) & SIOCPARM_MASK) << 16) | (x << 8) | y))
#define _SIOWR(x,y,t) ((int) (SIOC_INOUT | ((sizeof(t) & SIOCPARM_MASK) << 16) | (x << 8) | y))
#define _SIOC_SIZE(x) ((x >> 16) & SIOCPARM_MASK)
#define _SIOC_DIR(x) (x & 0xf0000000)
#define _SIOC_NONE SIOC_VOID
#define _SIOC_READ SIOC_OUT
#define _SIOC_WRITE SIOC_IN
#endif
#endif
#define SNDCTL_SEQ_RESET _SIO('Q', 0)
#define SNDCTL_SEQ_SYNC _SIO('Q', 1)
#define SNDCTL_SYNTH_INFO _SIOWR('Q', 2, struct synth_info)
#define SNDCTL_SEQ_CTRLRATE _SIOWR('Q', 3, int)
#define SNDCTL_SEQ_GETOUTCOUNT _SIOR('Q', 4, int)
#define SNDCTL_SEQ_GETINCOUNT _SIOR('Q', 5, int)
#define SNDCTL_SEQ_PERCMODE _SIOW('Q', 6, int)
#define SNDCTL_FM_LOAD_INSTR _SIOW('Q', 7, struct sbi_instrument)
#define SNDCTL_SEQ_TESTMIDI _SIOW('Q', 8, int)
#define SNDCTL_SEQ_RESETSAMPLES _SIOW('Q', 9, int)
#define SNDCTL_SEQ_NRSYNTHS _SIOR('Q', 10, int)
#define SNDCTL_SEQ_NRMIDIS _SIOR('Q', 11, int)
#define SNDCTL_MIDI_INFO _SIOWR('Q', 12, struct midi_info)
#define SNDCTL_SEQ_THRESHOLD _SIOW('Q', 13, int)
#define SNDCTL_SYNTH_MEMAVL _SIOWR('Q', 14, int)
#define SNDCTL_FM_4OP_ENABLE _SIOW('Q', 15, int)
#define SNDCTL_SEQ_PANIC _SIO('Q', 17)
#define SNDCTL_SEQ_OUTOFBAND _SIOW('Q', 18, struct seq_event_rec)
#define SNDCTL_SEQ_GETTIME _SIOR('Q', 19, int)
#define SNDCTL_SYNTH_ID _SIOWR('Q', 20, struct synth_info)
#define SNDCTL_SYNTH_CONTROL _SIOWR('Q', 21, struct synth_control)
#define SNDCTL_SYNTH_REMOVESAMPLE _SIOWR('Q', 22, struct remove_sample)
typedef struct synth_control {
  int devno;
  char data[4000];
} synth_control;
typedef struct remove_sample {
  int devno;
  int bankno;
  int instrno;
} remove_sample;
typedef struct seq_event_rec {
  unsigned char arr[8];
} seq_event_rec;
#define SNDCTL_TMR_TIMEBASE _SIOWR('T', 1, int)
#define SNDCTL_TMR_START _SIO('T', 2)
#define SNDCTL_TMR_STOP _SIO('T', 3)
#define SNDCTL_TMR_CONTINUE _SIO('T', 4)
#define SNDCTL_TMR_TEMPO _SIOWR('T', 5, int)
#define SNDCTL_TMR_SOURCE _SIOWR('T', 6, int)
#define TMR_INTERNAL 0x00000001
#define TMR_EXTERNAL 0x00000002
#define TMR_MODE_MIDI 0x00000010
#define TMR_MODE_FSK 0x00000020
#define TMR_MODE_CLS 0x00000040
#define TMR_MODE_SMPTE 0x00000080
#define SNDCTL_TMR_METRONOME _SIOW('T', 7, int)
#define SNDCTL_TMR_SELECT _SIOW('T', 8, int)
#define _LINUX_PATCHKEY_H_INDIRECT
#include <linux/patchkey.h>
#undef _LINUX_PATCHKEY_H_INDIRECT
#ifdef __BYTE_ORDER
#if __BYTE_ORDER == __BIG_ENDIAN
#define AFMT_S16_NE AFMT_S16_BE
#elif __BYTE_ORDER==__LITTLE_ENDIAN
#define AFMT_S16_NE AFMT_S16_LE
#else
#error "could not determine byte order"
#endif
#endif
struct patch_info {
  unsigned short key;
#define WAVE_PATCH _PATCHKEY(0x04)
#define GUS_PATCH WAVE_PATCH
#define WAVEFRONT_PATCH _PATCHKEY(0x06)
  short device_no;
  short instr_no;
  unsigned int mode;
#define WAVE_16_BITS 0x01
#define WAVE_UNSIGNED 0x02
#define WAVE_LOOPING 0x04
#define WAVE_BIDIR_LOOP 0x08
#define WAVE_LOOP_BACK 0x10
#define WAVE_SUSTAIN_ON 0x20
#define WAVE_ENVELOPES 0x40
#define WAVE_FAST_RELEASE 0x80
#define WAVE_VIBRATO 0x00010000
#define WAVE_TREMOLO 0x00020000
#define WAVE_SCALE 0x00040000
#define WAVE_FRACTIONS 0x00080000
#define WAVE_ROM 0x40000000
#define WAVE_MULAW 0x20000000
  int len;
  int loop_start, loop_end;
  unsigned int base_freq;
  unsigned int base_note;
  unsigned int high_note;
  unsigned int low_note;
  int panning;
  int detuning;
  unsigned char env_rate[6];
  unsigned char env_offset[6];
  unsigned char tremolo_sweep;
  unsigned char tremolo_rate;
  unsigned char tremolo_depth;
  unsigned char vibrato_sweep;
  unsigned char vibrato_rate;
  unsigned char vibrato_depth;
  int scale_frequency;
  unsigned int scale_factor;
  int volume;
  int fractions;
  int reserved1;
  int spare[2];
  char data[1];
};
struct sysex_info {
  short key;
#define SYSEX_PATCH _PATCHKEY(0x05)
#define MAUI_PATCH _PATCHKEY(0x06)
  short device_no;
  int len;
  unsigned char data[1];
};
#define SEQ_NOTEOFF 0
#define SEQ_FMNOTEOFF SEQ_NOTEOFF
#define SEQ_NOTEON 1
#define SEQ_FMNOTEON SEQ_NOTEON
#define SEQ_WAIT TMR_WAIT_ABS
#define SEQ_PGMCHANGE 3
#define SEQ_FMPGMCHANGE SEQ_PGMCHANGE
#define SEQ_SYNCTIMER TMR_START
#define SEQ_MIDIPUTC 5
#define SEQ_DRUMON 6
#define SEQ_DRUMOFF 7
#define SEQ_ECHO TMR_ECHO
#define SEQ_AFTERTOUCH 9
#define SEQ_CONTROLLER 10
#define CTL_BANK_SELECT 0x00
#define CTL_MODWHEEL 0x01
#define CTL_BREATH 0x02
#define CTL_FOOT 0x04
#define CTL_PORTAMENTO_TIME 0x05
#define CTL_DATA_ENTRY 0x06
#define CTL_MAIN_VOLUME 0x07
#define CTL_BALANCE 0x08
#define CTL_PAN 0x0a
#define CTL_EXPRESSION 0x0b
#define CTL_GENERAL_PURPOSE1 0x10
#define CTL_GENERAL_PURPOSE2 0x11
#define CTL_GENERAL_PURPOSE3 0x12
#define CTL_GENERAL_PURPOSE4 0x13
#define CTL_DAMPER_PEDAL 0x40
#define CTL_SUSTAIN 0x40
#define CTL_HOLD 0x40
#define CTL_PORTAMENTO 0x41
#define CTL_SOSTENUTO 0x42
#define CTL_SOFT_PEDAL 0x43
#define CTL_HOLD2 0x45
#define CTL_GENERAL_PURPOSE5 0x50
#define CTL_GENERAL_PURPOSE6 0x51
#define CTL_GENERAL_PURPOSE7 0x52
#define CTL_GENERAL_PURPOSE8 0x53
#define CTL_EXT_EFF_DEPTH 0x5b
#define CTL_TREMOLO_DEPTH 0x5c
#define CTL_CHORUS_DEPTH 0x5d
#define CTL_DETUNE_DEPTH 0x5e
#define CTL_CELESTE_DEPTH 0x5e
#define CTL_PHASER_DEPTH 0x5f
#define CTL_DATA_INCREMENT 0x60
#define CTL_DATA_DECREMENT 0x61
#define CTL_NONREG_PARM_NUM_LSB 0x62
#define CTL_NONREG_PARM_NUM_MSB 0x63
#define CTL_REGIST_PARM_NUM_LSB 0x64
#define CTL_REGIST_PARM_NUM_MSB 0x65
#define CTRL_PITCH_BENDER 255
#define CTRL_PITCH_BENDER_RANGE 254
#define CTRL_EXPRESSION 253
#define CTRL_MAIN_VOLUME 252
#define SEQ_BALANCE 11
#define SEQ_VOLMODE 12
#define VOL_METHOD_ADAGIO 1
#define VOL_METHOD_LINEAR 2
#define SEQ_FULLSIZE 0xfd
#define SEQ_PRIVATE 0xfe
#define SEQ_EXTENDED 0xff
typedef unsigned char sbi_instr_data[32];
struct sbi_instrument {
  unsigned short key;
#define FM_PATCH _PATCHKEY(0x01)
#define OPL3_PATCH _PATCHKEY(0x03)
  short device;
  int channel;
  sbi_instr_data operators;
};
struct synth_info {
  char name[30];
  int device;
  int synth_type;
#define SYNTH_TYPE_FM 0
#define SYNTH_TYPE_SAMPLE 1
#define SYNTH_TYPE_MIDI 2
  int synth_subtype;
#define FM_TYPE_ADLIB 0x00
#define FM_TYPE_OPL3 0x01
#define MIDI_TYPE_MPU401 0x401
#define SAMPLE_TYPE_BASIC 0x10
#define SAMPLE_TYPE_GUS SAMPLE_TYPE_BASIC
#define SAMPLE_TYPE_WAVEFRONT 0x11
  int perc_mode;
  int nr_voices;
  int nr_drums;
  int instr_bank_size;
  unsigned int capabilities;
#define SYNTH_CAP_PERCMODE 0x00000001
#define SYNTH_CAP_OPL3 0x00000002
#define SYNTH_CAP_INPUT 0x00000004
  int dummies[19];
};
struct sound_timer_info {
  char name[32];
  int caps;
};
#define MIDI_CAP_MPU401 1
struct midi_info {
  char name[30];
  int device;
  unsigned int capabilities;
  int dev_type;
  int dummies[18];
};
typedef struct {
  unsigned char cmd;
  char nr_args, nr_returns;
  unsigned char data[30];
} mpu_command_rec;
#define SNDCTL_MIDI_PRETIME _SIOWR('m', 0, int)
#define SNDCTL_MIDI_MPUMODE _SIOWR('m', 1, int)
#define SNDCTL_MIDI_MPUCMD _SIOWR('m', 2, mpu_command_rec)
#define SNDCTL_DSP_RESET _SIO('P', 0)
#define SNDCTL_DSP_SYNC _SIO('P', 1)
#define SNDCTL_DSP_SPEED _SIOWR('P', 2, int)
#define SNDCTL_DSP_STEREO _SIOWR('P', 3, int)
#define SNDCTL_DSP_GETBLKSIZE _SIOWR('P', 4, int)
#define SNDCTL_DSP_SAMPLESIZE SNDCTL_DSP_SETFMT
#define SNDCTL_DSP_CHANNELS _SIOWR('P', 6, int)
#define SOUND_PCM_WRITE_CHANNELS SNDCTL_DSP_CHANNELS
#define SOUND_PCM_WRITE_FILTER _SIOWR('P', 7, int)
#define SNDCTL_DSP_POST _SIO('P', 8)
#define SNDCTL_DSP_SUBDIVIDE _SIOWR('P', 9, int)
#define SNDCTL_DSP_SETFRAGMENT _SIOWR('P', 10, int)
#define SNDCTL_DSP_GETFMTS _SIOR('P', 11, int)
#define SNDCTL_DSP_SETFMT _SIOWR('P', 5, int)
#define AFMT_QUERY 0x00000000
#define AFMT_MU_LAW 0x00000001
#define AFMT_A_LAW 0x00000002
#define AFMT_IMA_ADPCM 0x00000004
#define AFMT_U8 0x00000008
#define AFMT_S16_LE 0x00000010
#define AFMT_S16_BE 0x00000020
#define AFMT_S8 0x00000040
#define AFMT_U16_LE 0x00000080
#define AFMT_U16_BE 0x00000100
#define AFMT_MPEG 0x00000200
#define AFMT_AC3 0x00000400
typedef struct audio_buf_info {
  int fragments;
  int fragstotal;
  int fragsize;
  int bytes;
} audio_buf_info;
#define SNDCTL_DSP_GETOSPACE _SIOR('P', 12, audio_buf_info)
#define SNDCTL_DSP_GETISPACE _SIOR('P', 13, audio_buf_info)
#define SNDCTL_DSP_NONBLOCK _SIO('P', 14)
#define SNDCTL_DSP_GETCAPS _SIOR('P', 15, int)
#define DSP_CAP_REVISION 0x000000ff
#define DSP_CAP_DUPLEX 0x00000100
#define DSP_CAP_REALTIME 0x00000200
#define DSP_CAP_BATCH 0x00000400
#define DSP_CAP_COPROC 0x00000800
#define DSP_CAP_TRIGGER 0x00001000
#define DSP_CAP_MMAP 0x00002000
#define DSP_CAP_MULTI 0x00004000
#define DSP_CAP_BIND 0x00008000
#define SNDCTL_DSP_GETTRIGGER _SIOR('P', 16, int)
#define SNDCTL_DSP_SETTRIGGER _SIOW('P', 16, int)
#define PCM_ENABLE_INPUT 0x00000001
#define PCM_ENABLE_OUTPUT 0x00000002
typedef struct count_info {
  int bytes;
  int blocks;
  int ptr;
} count_info;
#define SNDCTL_DSP_GETIPTR _SIOR('P', 17, count_info)
#define SNDCTL_DSP_GETOPTR _SIOR('P', 18, count_info)
typedef struct buffmem_desc {
  unsigned * buffer;
  int size;
} buffmem_desc;
#define SNDCTL_DSP_MAPINBUF _SIOR('P', 19, buffmem_desc)
#define SNDCTL_DSP_MAPOUTBUF _SIOR('P', 20, buffmem_desc)
#define SNDCTL_DSP_SETSYNCRO _SIO('P', 21)
#define SNDCTL_DSP_SETDUPLEX _SIO('P', 22)
#define SNDCTL_DSP_GETODELAY _SIOR('P', 23, int)
#define SNDCTL_DSP_GETCHANNELMASK _SIOWR('P', 64, int)
#define SNDCTL_DSP_BIND_CHANNEL _SIOWR('P', 65, int)
#define DSP_BIND_QUERY 0x00000000
#define DSP_BIND_FRONT 0x00000001
#define DSP_BIND_SURR 0x00000002
#define DSP_BIND_CENTER_LFE 0x00000004
#define DSP_BIND_HANDSET 0x00000008
#define DSP_BIND_MIC 0x00000010
#define DSP_BIND_MODEM1 0x00000020
#define DSP_BIND_MODEM2 0x00000040
#define DSP_BIND_I2S 0x00000080
#define DSP_BIND_SPDIF 0x00000100
#define SNDCTL_DSP_SETSPDIF _SIOW('P', 66, int)
#define SNDCTL_DSP_GETSPDIF _SIOR('P', 67, int)
#define SPDIF_PRO 0x0001
#define SPDIF_N_AUD 0x0002
#define SPDIF_COPY 0x0004
#define SPDIF_PRE 0x0008
#define SPDIF_CC 0x07f0
#define SPDIF_L 0x0800
#define SPDIF_DRS 0x4000
#define SPDIF_V 0x8000
#define SNDCTL_DSP_PROFILE _SIOW('P', 23, int)
#define APF_NORMAL 0
#define APF_NETWORK 1
#define APF_CPUINTENS 2
#define SOUND_PCM_READ_RATE _SIOR('P', 2, int)
#define SOUND_PCM_READ_CHANNELS _SIOR('P', 6, int)
#define SOUND_PCM_READ_BITS _SIOR('P', 5, int)
#define SOUND_PCM_READ_FILTER _SIOR('P', 7, int)
#define SOUND_PCM_WRITE_BITS SNDCTL_DSP_SETFMT
#define SOUND_PCM_WRITE_RATE SNDCTL_DSP_SPEED
#define SOUND_PCM_POST SNDCTL_DSP_POST
#define SOUND_PCM_RESET SNDCTL_DSP_RESET
#define SOUND_PCM_SYNC SNDCTL_DSP_SYNC
#define SOUND_PCM_SUBDIVIDE SNDCTL_DSP_SUBDIVIDE
#define SOUND_PCM_SETFRAGMENT SNDCTL_DSP_SETFRAGMENT
#define SOUND_PCM_GETFMTS SNDCTL_DSP_GETFMTS
#define SOUND_PCM_SETFMT SNDCTL_DSP_SETFMT
#define SOUND_PCM_GETOSPACE SNDCTL_DSP_GETOSPACE
#define SOUND_PCM_GETISPACE SNDCTL_DSP_GETISPACE
#define SOUND_PCM_NONBLOCK SNDCTL_DSP_NONBLOCK
#define SOUND_PCM_GETCAPS SNDCTL_DSP_GETCAPS
#define SOUND_PCM_GETTRIGGER SNDCTL_DSP_GETTRIGGER
#define SOUND_PCM_SETTRIGGER SNDCTL_DSP_SETTRIGGER
#define SOUND_PCM_SETSYNCRO SNDCTL_DSP_SETSYNCRO
#define SOUND_PCM_GETIPTR SNDCTL_DSP_GETIPTR
#define SOUND_PCM_GETOPTR SNDCTL_DSP_GETOPTR
#define SOUND_PCM_MAPINBUF SNDCTL_DSP_MAPINBUF
#define SOUND_PCM_MAPOUTBUF SNDCTL_DSP_MAPOUTBUF
typedef struct copr_buffer {
  int command;
  int flags;
#define CPF_NONE 0x0000
#define CPF_FIRST 0x0001
#define CPF_LAST 0x0002
  int len;
  int offs;
  unsigned char data[4000];
} copr_buffer;
typedef struct copr_debug_buf {
  int command;
  int parm1;
  int parm2;
  int flags;
  int len;
} copr_debug_buf;
typedef struct copr_msg {
  int len;
  unsigned char data[4000];
} copr_msg;
#define SNDCTL_COPR_RESET _SIO('C', 0)
#define SNDCTL_COPR_LOAD _SIOWR('C', 1, copr_buffer)
#define SNDCTL_COPR_RDATA _SIOWR('C', 2, copr_debug_buf)
#define SNDCTL_COPR_RCODE _SIOWR('C', 3, copr_debug_buf)
#define SNDCTL_COPR_WDATA _SIOW('C', 4, copr_debug_buf)
#define SNDCTL_COPR_WCODE _SIOW('C', 5, copr_debug_buf)
#define SNDCTL_COPR_RUN _SIOWR('C', 6, copr_debug_buf)
#define SNDCTL_COPR_HALT _SIOWR('C', 7, copr_debug_buf)
#define SNDCTL_COPR_SENDMSG _SIOWR('C', 8, copr_msg)
#define SNDCTL_COPR_RCVMSG _SIOR('C', 9, copr_msg)
#define SOUND_MIXER_NRDEVICES 25
#define SOUND_MIXER_VOLUME 0
#define SOUND_MIXER_BASS 1
#define SOUND_MIXER_TREBLE 2
#define SOUND_MIXER_SYNTH 3
#define SOUND_MIXER_PCM 4
#define SOUND_MIXER_SPEAKER 5
#define SOUND_MIXER_LINE 6
#define SOUND_MIXER_MIC 7
#define SOUND_MIXER_CD 8
#define SOUND_MIXER_IMIX 9
#define SOUND_MIXER_ALTPCM 10
#define SOUND_MIXER_RECLEV 11
#define SOUND_MIXER_IGAIN 12
#define SOUND_MIXER_OGAIN 13
#define SOUND_MIXER_LINE1 14
#define SOUND_MIXER_LINE2 15
#define SOUND_MIXER_LINE3 16
#define SOUND_MIXER_DIGITAL1 17
#define SOUND_MIXER_DIGITAL2 18
#define SOUND_MIXER_DIGITAL3 19
#define SOUND_MIXER_PHONEIN 20
#define SOUND_MIXER_PHONEOUT 21
#define SOUND_MIXER_VIDEO 22
#define SOUND_MIXER_RADIO 23
#define SOUND_MIXER_MONITOR 24
#define SOUND_ONOFF_MIN 28
#define SOUND_ONOFF_MAX 30
#define SOUND_MIXER_NONE 31
#define SOUND_MIXER_ENHANCE SOUND_MIXER_NONE
#define SOUND_MIXER_MUTE SOUND_MIXER_NONE
#define SOUND_MIXER_LOUD SOUND_MIXER_NONE
#define SOUND_DEVICE_LABELS { "Vol  ", "Bass ", "Trebl", "Synth", "Pcm  ", "Spkr ", "Line ", "Mic  ", "CD   ", "Mix  ", "Pcm2 ", "Rec  ", "IGain", "OGain", "Line1", "Line2", "Line3", "Digital1", "Digital2", "Digital3", "PhoneIn", "PhoneOut", "Video", "Radio", "Monitor" }
#define SOUND_DEVICE_NAMES { "vol", "bass", "treble", "synth", "pcm", "speaker", "line", "mic", "cd", "mix", "pcm2", "rec", "igain", "ogain", "line1", "line2", "line3", "dig1", "dig2", "dig3", "phin", "phout", "video", "radio", "monitor" }
#define SOUND_MIXER_RECSRC 0xff
#define SOUND_MIXER_DEVMASK 0xfe
#define SOUND_MIXER_RECMASK 0xfd
#define SOUND_MIXER_CAPS 0xfc
#define SOUND_CAP_EXCL_INPUT 0x00000001
#define SOUND_MIXER_STEREODEVS 0xfb
#define SOUND_MIXER_OUTSRC 0xfa
#define SOUND_MIXER_OUTMASK 0xf9
#define SOUND_MASK_VOLUME (1 << SOUND_MIXER_VOLUME)
#define SOUND_MASK_BASS (1 << SOUND_MIXER_BASS)
#define SOUND_MASK_TREBLE (1 << SOUND_MIXER_TREBLE)
#define SOUND_MASK_SYNTH (1 << SOUND_MIXER_SYNTH)
#define SOUND_MASK_PCM (1 << SOUND_MIXER_PCM)
#define SOUND_MASK_SPEAKER (1 << SOUND_MIXER_SPEAKER)
#define SOUND_MASK_LINE (1 << SOUND_MIXER_LINE)
#define SOUND_MASK_MIC (1 << SOUND_MIXER_MIC)
#define SOUND_MASK_CD (1 << SOUND_MIXER_CD)
#define SOUND_MASK_IMIX (1 << SOUND_MIXER_IMIX)
#define SOUND_MASK_ALTPCM (1 << SOUND_MIXER_ALTPCM)
#define SOUND_MASK_RECLEV (1 << SOUND_MIXER_RECLEV)
#define SOUND_MASK_IGAIN (1 << SOUND_MIXER_IGAIN)
#define SOUND_MASK_OGAIN (1 << SOUND_MIXER_OGAIN)
#define SOUND_MASK_LINE1 (1 << SOUND_MIXER_LINE1)
#define SOUND_MASK_LINE2 (1 << SOUND_MIXER_LINE2)
#define SOUND_MASK_LINE3 (1 << SOUND_MIXER_LINE3)
#define SOUND_MASK_DIGITAL1 (1 << SOUND_MIXER_DIGITAL1)
#define SOUND_MASK_DIGITAL2 (1 << SOUND_MIXER_DIGITAL2)
#define SOUND_MASK_DIGITAL3 (1 << SOUND_MIXER_DIGITAL3)
#define SOUND_MASK_PHONEIN (1 << SOUND_MIXER_PHONEIN)
#define SOUND_MASK_PHONEOUT (1 << SOUND_MIXER_PHONEOUT)
#define SOUND_MASK_RADIO (1 << SOUND_MIXER_RADIO)
#define SOUND_MASK_VIDEO (1 << SOUND_MIXER_VIDEO)
#define SOUND_MASK_MONITOR (1 << SOUND_MIXER_MONITOR)
#define SOUND_MASK_MUTE (1 << SOUND_MIXER_MUTE)
#define SOUND_MASK_ENHANCE (1 << SOUND_MIXER_ENHANCE)
#define SOUND_MASK_LOUD (1 << SOUND_MIXER_LOUD)
#define MIXER_READ(dev) _SIOR('M', dev, int)
#define SOUND_MIXER_READ_VOLUME MIXER_READ(SOUND_MIXER_VOLUME)
#define SOUND_MIXER_READ_BASS MIXER_READ(SOUND_MIXER_BASS)
#define SOUND_MIXER_READ_TREBLE MIXER_READ(SOUND_MIXER_TREBLE)
#define SOUND_MIXER_READ_SYNTH MIXER_READ(SOUND_MIXER_SYNTH)
#define SOUND_MIXER_READ_PCM MIXER_READ(SOUND_MIXER_PCM)
#define SOUND_MIXER_READ_SPEAKER MIXER_READ(SOUND_MIXER_SPEAKER)
#define SOUND_MIXER_READ_LINE MIXER_READ(SOUND_MIXER_LINE)
#define SOUND_MIXER_READ_MIC MIXER_READ(SOUND_MIXER_MIC)
#define SOUND_MIXER_READ_CD MIXER_READ(SOUND_MIXER_CD)
#define SOUND_MIXER_READ_IMIX MIXER_READ(SOUND_MIXER_IMIX)
#define SOUND_MIXER_READ_ALTPCM MIXER_READ(SOUND_MIXER_ALTPCM)
#define SOUND_MIXER_READ_RECLEV MIXER_READ(SOUND_MIXER_RECLEV)
#define SOUND_MIXER_READ_IGAIN MIXER_READ(SOUND_MIXER_IGAIN)
#define SOUND_MIXER_READ_OGAIN MIXER_READ(SOUND_MIXER_OGAIN)
#define SOUND_MIXER_READ_LINE1 MIXER_READ(SOUND_MIXER_LINE1)
#define SOUND_MIXER_READ_LINE2 MIXER_READ(SOUND_MIXER_LINE2)
#define SOUND_MIXER_READ_LINE3 MIXER_READ(SOUND_MIXER_LINE3)
#define SOUND_MIXER_READ_MUTE MIXER_READ(SOUND_MIXER_MUTE)
#define SOUND_MIXER_READ_ENHANCE MIXER_READ(SOUND_MIXER_ENHANCE)
#define SOUND_MIXER_READ_LOUD MIXER_READ(SOUND_MIXER_LOUD)
#define SOUND_MIXER_READ_RECSRC MIXER_READ(SOUND_MIXER_RECSRC)
#define SOUND_MIXER_READ_DEVMASK MIXER_READ(SOUND_MIXER_DEVMASK)
#define SOUND_MIXER_READ_RECMASK MIXER_READ(SOUND_MIXER_RECMASK)
#define SOUND_MIXER_READ_STEREODEVS MIXER_READ(SOUND_MIXER_STEREODEVS)
#define SOUND_MIXER_READ_CAPS MIXER_READ(SOUND_MIXER_CAPS)
#define MIXER_WRITE(dev) _SIOWR('M', dev, int)
#define SOUND_MIXER_WRITE_VOLUME MIXER_WRITE(SOUND_MIXER_VOLUME)
#define SOUND_MIXER_WRITE_BASS MIXER_WRITE(SOUND_MIXER_BASS)
#define SOUND_MIXER_WRITE_TREBLE MIXER_WRITE(SOUND_MIXER_TREBLE)
#define SOUND_MIXER_WRITE_SYNTH MIXER_WRITE(SOUND_MIXER_SYNTH)
#define SOUND_MIXER_WRITE_PCM MIXER_WRITE(SOUND_MIXER_PCM)
#define SOUND_MIXER_WRITE_SPEAKER MIXER_WRITE(SOUND_MIXER_SPEAKER)
#define SOUND_MIXER_WRITE_LINE MIXER_WRITE(SOUND_MIXER_LINE)
#define SOUND_MIXER_WRITE_MIC MIXER_WRITE(SOUND_MIXER_MIC)
#define SOUND_MIXER_WRITE_CD MIXER_WRITE(SOUND_MIXER_CD)
#define SOUND_MIXER_WRITE_IMIX MIXER_WRITE(SOUND_MIXER_IMIX)
#define SOUND_MIXER_WRITE_ALTPCM MIXER_WRITE(SOUND_MIXER_ALTPCM)
#define SOUND_MIXER_WRITE_RECLEV MIXER_WRITE(SOUND_MIXER_RECLEV)
#define SOUND_MIXER_WRITE_IGAIN MIXER_WRITE(SOUND_MIXER_IGAIN)
#define SOUND_MIXER_WRITE_OGAIN MIXER_WRITE(SOUND_MIXER_OGAIN)
#define SOUND_MIXER_WRITE_LINE1 MIXER_WRITE(SOUND_MIXER_LINE1)
#define SOUND_MIXER_WRITE_LINE2 MIXER_WRITE(SOUND_MIXER_LINE2)
#define SOUND_MIXER_WRITE_LINE3 MIXER_WRITE(SOUND_MIXER_LINE3)
#define SOUND_MIXER_WRITE_MUTE MIXER_WRITE(SOUND_MIXER_MUTE)
#define SOUND_MIXER_WRITE_ENHANCE MIXER_WRITE(SOUND_MIXER_ENHANCE)
#define SOUND_MIXER_WRITE_LOUD MIXER_WRITE(SOUND_MIXER_LOUD)
#define SOUND_MIXER_WRITE_RECSRC MIXER_WRITE(SOUND_MIXER_RECSRC)
typedef struct mixer_info {
  char id[16];
  char name[32];
  int modify_counter;
  int fillers[10];
} mixer_info;
typedef struct _old_mixer_info {
  char id[16];
  char name[32];
} _old_mixer_info;
#define SOUND_MIXER_INFO _SIOR('M', 101, mixer_info)
#define SOUND_OLD_MIXER_INFO _SIOR('M', 101, _old_mixer_info)
typedef unsigned char mixer_record[128];
#define SOUND_MIXER_ACCESS _SIOWR('M', 102, mixer_record)
#define SOUND_MIXER_AGC _SIOWR('M', 103, int)
#define SOUND_MIXER_3DSE _SIOWR('M', 104, int)
#define SOUND_MIXER_PRIVATE1 _SIOWR('M', 111, int)
#define SOUND_MIXER_PRIVATE2 _SIOWR('M', 112, int)
#define SOUND_MIXER_PRIVATE3 _SIOWR('M', 113, int)
#define SOUND_MIXER_PRIVATE4 _SIOWR('M', 114, int)
#define SOUND_MIXER_PRIVATE5 _SIOWR('M', 115, int)
typedef struct mixer_vol_table {
  int num;
  char name[32];
  int levels[32];
} mixer_vol_table;
#define SOUND_MIXER_GETLEVELS _SIOWR('M', 116, mixer_vol_table)
#define SOUND_MIXER_SETLEVELS _SIOWR('M', 117, mixer_vol_table)
#define OSS_GETVERSION _SIOR('M', 118, int)
#define EV_SEQ_LOCAL 0x80
#define EV_TIMING 0x81
#define EV_CHN_COMMON 0x92
#define EV_CHN_VOICE 0x93
#define EV_SYSEX 0x94
#define MIDI_NOTEOFF 0x80
#define MIDI_NOTEON 0x90
#define MIDI_KEY_PRESSURE 0xA0
#define MIDI_CTL_CHANGE 0xB0
#define MIDI_PGM_CHANGE 0xC0
#define MIDI_CHN_PRESSURE 0xD0
#define MIDI_PITCH_BEND 0xE0
#define MIDI_SYSTEM_PREFIX 0xF0
#define TMR_WAIT_REL 1
#define TMR_WAIT_ABS 2
#define TMR_STOP 3
#define TMR_START 4
#define TMR_CONTINUE 5
#define TMR_TEMPO 6
#define TMR_ECHO 8
#define TMR_CLOCK 9
#define TMR_SPP 10
#define TMR_TIMESIG 11
#define LOCL_STARTAUDIO 1
#define SEQ_DECLAREBUF() SEQ_USE_EXTBUF()
#define SEQ_PM_DEFINES int __foo_bar___
#define SEQ_LOAD_GMINSTR(dev,instr)
#define SEQ_LOAD_GMDRUM(dev,drum)
#define _SEQ_EXTERN extern
#define SEQ_USE_EXTBUF() _SEQ_EXTERN unsigned char _seqbuf[]; _SEQ_EXTERN int _seqbuflen; _SEQ_EXTERN int _seqbufptr
#ifndef USE_SIMPLE_MACROS
#define SEQ_DEFINEBUF(len) unsigned char _seqbuf[len]; int _seqbuflen = len; int _seqbufptr = 0
#define _SEQ_NEEDBUF(len) if((_seqbufptr + (len)) > _seqbuflen) seqbuf_dump()
#define _SEQ_ADVBUF(len) _seqbufptr += len
#define SEQ_DUMPBUF seqbuf_dump
#else
#define _SEQ_NEEDBUF(len)
#endif
#define SEQ_VOLUME_MODE(dev,mode) { _SEQ_NEEDBUF(8); _seqbuf[_seqbufptr] = SEQ_EXTENDED; _seqbuf[_seqbufptr + 1] = SEQ_VOLMODE; _seqbuf[_seqbufptr + 2] = (dev); _seqbuf[_seqbufptr + 3] = (mode); _seqbuf[_seqbufptr + 4] = 0; _seqbuf[_seqbufptr + 5] = 0; _seqbuf[_seqbufptr + 6] = 0; _seqbuf[_seqbufptr + 7] = 0; _SEQ_ADVBUF(8); }
#define _CHN_VOICE(dev,event,chn,note,parm) { _SEQ_NEEDBUF(8); _seqbuf[_seqbufptr] = EV_CHN_VOICE; _seqbuf[_seqbufptr + 1] = (dev); _seqbuf[_seqbufptr + 2] = (event); _seqbuf[_seqbufptr + 3] = (chn); _seqbuf[_seqbufptr + 4] = (note); _seqbuf[_seqbufptr + 5] = (parm); _seqbuf[_seqbufptr + 6] = (0); _seqbuf[_seqbufptr + 7] = 0; _SEQ_ADVBUF(8); }
#define SEQ_START_NOTE(dev,chn,note,vol) _CHN_VOICE(dev, MIDI_NOTEON, chn, note, vol)
#define SEQ_STOP_NOTE(dev,chn,note,vol) _CHN_VOICE(dev, MIDI_NOTEOFF, chn, note, vol)
#define SEQ_KEY_PRESSURE(dev,chn,note,pressure) _CHN_VOICE(dev, MIDI_KEY_PRESSURE, chn, note, pressure)
#define _CHN_COMMON(dev,event,chn,p1,p2,w14) { _SEQ_NEEDBUF(8); _seqbuf[_seqbufptr] = EV_CHN_COMMON; _seqbuf[_seqbufptr + 1] = (dev); _seqbuf[_seqbufptr + 2] = (event); _seqbuf[_seqbufptr + 3] = (chn); _seqbuf[_seqbufptr + 4] = (p1); _seqbuf[_seqbufptr + 5] = (p2); * (short *) & _seqbuf[_seqbufptr + 6] = (w14); _SEQ_ADVBUF(8); }
#define SEQ_SYSEX(dev,buf,len) { int ii, ll = (len); unsigned char * bufp = buf; if(ll > 6) ll = 6; _SEQ_NEEDBUF(8); _seqbuf[_seqbufptr] = EV_SYSEX; _seqbuf[_seqbufptr + 1] = (dev); for(ii = 0; ii < ll; ii ++) _seqbuf[_seqbufptr + ii + 2] = bufp[ii]; for(ii = ll; ii < 6; ii ++) _seqbuf[_seqbufptr + ii + 2] = 0xff; _SEQ_ADVBUF(8); }
#define SEQ_CHN_PRESSURE(dev,chn,pressure) _CHN_COMMON(dev, MIDI_CHN_PRESSURE, chn, pressure, 0, 0)
#define SEQ_SET_PATCH SEQ_PGM_CHANGE
#define SEQ_PGM_CHANGE(dev,chn,patch) _CHN_COMMON(dev, MIDI_PGM_CHANGE, chn, patch, 0, 0)
#define SEQ_CONTROL(dev,chn,controller,value) _CHN_COMMON(dev, MIDI_CTL_CHANGE, chn, controller, 0, value)
#define SEQ_BENDER(dev,chn,value) _CHN_COMMON(dev, MIDI_PITCH_BEND, chn, 0, 0, value)
#define SEQ_V2_X_CONTROL(dev,voice,controller,value) { _SEQ_NEEDBUF(8); _seqbuf[_seqbufptr] = SEQ_EXTENDED; _seqbuf[_seqbufptr + 1] = SEQ_CONTROLLER; _seqbuf[_seqbufptr + 2] = (dev); _seqbuf[_seqbufptr + 3] = (voice); _seqbuf[_seqbufptr + 4] = (controller); _seqbuf[_seqbufptr + 5] = ((value) & 0xff); _seqbuf[_seqbufptr + 6] = ((value >> 8) & 0xff); _seqbuf[_seqbufptr + 7] = 0; _SEQ_ADVBUF(8); }
#define SEQ_PITCHBEND(dev,voice,value) SEQ_V2_X_CONTROL(dev, voice, CTRL_PITCH_BENDER, value)
#define SEQ_BENDER_RANGE(dev,voice,value) SEQ_V2_X_CONTROL(dev, voice, CTRL_PITCH_BENDER_RANGE, value)
#define SEQ_EXPRESSION(dev,voice,value) SEQ_CONTROL(dev, voice, CTL_EXPRESSION, value * 128)
#define SEQ_MAIN_VOLUME(dev,voice,value) SEQ_CONTROL(dev, voice, CTL_MAIN_VOLUME, (value * 16383) / 100)
#define SEQ_PANNING(dev,voice,pos) SEQ_CONTROL(dev, voice, CTL_PAN, (pos + 128) / 2)
#define _TIMER_EVENT(ev,parm) { _SEQ_NEEDBUF(8); _seqbuf[_seqbufptr + 0] = EV_TIMING; _seqbuf[_seqbufptr + 1] = (ev); _seqbuf[_seqbufptr + 2] = 0; _seqbuf[_seqbufptr + 3] = 0; * (unsigned int *) & _seqbuf[_seqbufptr + 4] = (parm); _SEQ_ADVBUF(8); }
#define SEQ_START_TIMER() _TIMER_EVENT(TMR_START, 0)
#define SEQ_STOP_TIMER() _TIMER_EVENT(TMR_STOP, 0)
#define SEQ_CONTINUE_TIMER() _TIMER_EVENT(TMR_CONTINUE, 0)
#define SEQ_WAIT_TIME(ticks) _TIMER_EVENT(TMR_WAIT_ABS, ticks)
#define SEQ_DELTA_TIME(ticks) _TIMER_EVENT(TMR_WAIT_REL, ticks)
#define SEQ_ECHO_BACK(key) _TIMER_EVENT(TMR_ECHO, key)
#define SEQ_SET_TEMPO(value) _TIMER_EVENT(TMR_TEMPO, value)
#define SEQ_SONGPOS(pos) _TIMER_EVENT(TMR_SPP, pos)
#define SEQ_TIME_SIGNATURE(sig) _TIMER_EVENT(TMR_TIMESIG, sig)
#define _LOCAL_EVENT(ev,parm) { _SEQ_NEEDBUF(8); _seqbuf[_seqbufptr + 0] = EV_SEQ_LOCAL; _seqbuf[_seqbufptr + 1] = (ev); _seqbuf[_seqbufptr + 2] = 0; _seqbuf[_seqbufptr + 3] = 0; * (unsigned int *) & _seqbuf[_seqbufptr + 4] = (parm); _SEQ_ADVBUF(8); }
#define SEQ_PLAYAUDIO(devmask) _LOCAL_EVENT(LOCL_STARTAUDIO, devmask)
#define SEQ_MIDIOUT(device,byte) { _SEQ_NEEDBUF(4); _seqbuf[_seqbufptr] = SEQ_MIDIPUTC; _seqbuf[_seqbufptr + 1] = (byte); _seqbuf[_seqbufptr + 2] = (device); _seqbuf[_seqbufptr + 3] = 0; _SEQ_ADVBUF(4); }
#define SEQ_WRPATCH(patchx,len) { if(_seqbufptr) SEQ_DUMPBUF(); if(write(seqfd, (char *) (patchx), len) == - 1) perror("Write patch: /dev/sequencer"); }
#define SEQ_WRPATCH2(patchx,len) (SEQ_DUMPBUF(), write(seqfd, (char *) (patchx), len))
#endif