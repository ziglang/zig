/*	$NetBSD: midiio.h,v 1.16 2015/09/06 06:01:02 dholland Exp $	*/

/*-
 * Copyright (c) 1998 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Lennart Augustsson (augustss@NetBSD.org) and (native API structures
 * and macros) Chapman Flack (chap@NetBSD.org).
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _SYS_MIDIIO_H_
#define _SYS_MIDIIO_H_

/*
 * The API defined here produces events compatible with the OSS MIDI API at
 * the binary level.
 */

#include <machine/endian_machdep.h>
#include <sys/ioccom.h>

/*
 * ioctl() commands for /dev/midi##
 * XXX is directly frobbing an MPU401 even supported? isn't it just run
 * in UART mode?
 */
typedef struct {
	unsigned	char cmd;
	char		nr_args, nr_returns;
	unsigned char	data[30];
} mpu_command_rec;

#define MIDI_PRETIME		_IOWR('m', 0, int)
#define MIDI_MPUMODE		_IOWR('m', 1, int)
#define MIDI_MPUCMD		_IOWR('m', 2, mpu_command_rec)


/* The MPU401 command acknowledge and active sense command */
#define MIDI_ACK	0xfe


/* Sequencer */
#define SEQUENCER_RESET			_IO  ('Q', 0)
#define SEQUENCER_SYNC			_IO  ('Q', 1)
#define SEQUENCER_INFO			_IOWR('Q', 2, struct synth_info)
#define SEQUENCER_CTRLRATE		_IOWR('Q', 3, int)
#define SEQUENCER_GETOUTCOUNT		_IOR ('Q', 4, int)
#define SEQUENCER_GETINCOUNT		_IOR ('Q', 5, int)
/*#define SEQUENCER_PERCMODE		_IOW ('Q', 6, int)*/
/*#define SEQUENCER_TESTMIDI		_IOW ('Q', 8, int)*/
#define SEQUENCER_RESETSAMPLES		_IOW ('Q', 9, int)
/*
 * The sequencer at present makes no distinction between a 'synth' and a 'midi'.
 * This is actually a cleaner layering than OSS: devices that are onboard
 * synths just attach midi(4) via midisyn and present an ordinary MIDI face to
 * the system. At present the same number is returned for NRSYNTHS and NRMIDIS
 * but don't believe both, or you'll think you have twice as many devices as
 * you really have. The MIDI_INFO ioctl isn't implemented; use SEQUENCER_INFO
 * (which corresponds to OSS's SYNTH_INFO) to get information on any kind of
 * device, though the struct synth_info it uses has some members that only
 * pertain to synths (and get filled in with fixed, probably wrong values,
 * anyway).
 */
#define SEQUENCER_NRSYNTHS		_IOR ('Q',10, int)
#define SEQUENCER_NRMIDIS		_IOR ('Q',11, int)
/*#define SEQUENCER_MIDI_INFO		_IOWR('Q',12, struct midi_info)*/
#define SEQUENCER_THRESHOLD		_IOW ('Q',13, int)
#define SEQUENCER_MEMAVL		_IOWR('Q',14, int)
/*#define SEQUENCER_FM_4OP_ENABLE		_IOW ('Q',15, int)*/
#define SEQUENCER_PANIC			_IO  ('Q',17)
#define SEQUENCER_OUTOFBAND		_IOW ('Q',18, struct seq_event_rec)
#define SEQUENCER_GETTIME		_IOR ('Q',19, int)
/*#define SEQUENCER_ID			_IOWR('Q',20, struct synth_info)*/
/*#define SEQUENCER_CONTROL		_IOWR('Q',21, struct synth_control)*/
/*#define SEQUENCER_REMOVESAMPLE		_IOWR('Q',22, struct remove_sample)*/

#if 0
typedef struct synth_control {
	int	devno;		/* Synthesizer # */
	char	data[4000];	/* Device specific command/data record */
} synth_control;

typedef struct remove_sample {
	int	devno;		/* Synthesizer # */
	int	bankno;		/* MIDI bank # (0=General MIDI) */
	int	instrno;	/* MIDI instrument number */
} remove_sample;
#endif

#define CMDSIZE 8
typedef struct seq_event_rec {
	u_char	arr[CMDSIZE];
} seq_event_rec;

struct synth_info {
	char	name[30];
	int	device;
	int	synth_type;
#define SYNTH_TYPE_FM			0
#define SYNTH_TYPE_SAMPLE		1
#define SYNTH_TYPE_MIDI			2

	int	synth_subtype;
#define SYNTH_SUB_FM_TYPE_ADLIB		0x00
#define SYNTH_SUB_FM_TYPE_OPL3		0x01
#define SYNTH_SUB_MIDI_TYPE_MPU401	0x401

#define SYNTH_SUB_SAMPLE_TYPE_BASIC	0x10
#define SYNTH_SUB_SAMPLE_TYPE_GUS	SAMPLE_TYPE_BASIC

	int	nr_voices;
	int	instr_bank_size;
	u_int	capabilities;
#define SYNTH_CAP_OPL3			0x00000002
#define SYNTH_CAP_INPUT			0x00000004
};

/* Sequencer timer */
#define SEQUENCER_TMR_TIMEBASE		_IOWR('T', 1, int)
#define SEQUENCER_TMR_START		_IO  ('T', 2)
#define SEQUENCER_TMR_STOP		_IO  ('T', 3)
#define SEQUENCER_TMR_CONTINUE		_IO  ('T', 4)
#define SEQUENCER_TMR_TEMPO		_IOWR('T', 5, int)
#define SEQUENCER_TMR_SOURCE		_IOWR('T', 6, int)
#  define SEQUENCER_TMR_INTERNAL	0x00000001
#if 0
#  define SEQUENCER_TMR_EXTERNAL	0x00000002
#  define SEQUENCER_TMR_MODE_MIDI	0x00000010
#  define SEQUENCER_TMR_MODE_FSK	0x00000020
#  define SEQUENCER_TMR_MODE_CLS	0x00000040
#  define SEQUENCER_TMR_MODE_SMPTE	0x00000080
#endif
#define SEQUENCER_TMR_METRONOME		_IOW ('T', 7, int)
#define SEQUENCER_TMR_SELECT		_IOW ('T', 8, int)


#define MIDI_CTRL_BANK_SELECT_MSB	0
#define MIDI_CTRL_MODULATION_MSB	1
#define MIDI_CTRL_BREATH_MSB		2
#define MIDI_CTRL_FOOT_MSB		4
#define MIDI_CTRL_PORTAMENTO_TIME_MSB	5
#define MIDI_CTRL_DATA_ENTRY_MSB	6
#define MIDI_CTRL_CHANNEL_VOLUME_MSB	7
#define MIDI_CTRL_BALANCE_MSB		8
#define MIDI_CTRL_PAN_MSB		10
#define MIDI_CTRL_EXPRESSION_MSB	11
#define MIDI_CTRL_EFFECT_1_MSB		12
#define MIDI_CTRL_EFFECT_2_MSB		13
#define MIDI_CTRL_GENERAL_PURPOSE_1_MSB	16
#define MIDI_CTRL_GENERAL_PURPOSE_2_MSB	17
#define MIDI_CTRL_GENERAL_PURPOSE_3_MSB	18
#define MIDI_CTRL_GENERAL_PURPOSE_4_MSB	19
#define MIDI_CTRL_BANK_SELECT_LSB	32
#define MIDI_CTRL_MODULATION_LSB	33
#define MIDI_CTRL_BREATH_LSB		34
#define MIDI_CTRL_FOOT_LSB		36
#define MIDI_CTRL_PORTAMENTO_TIME_LSB	37
#define MIDI_CTRL_DATA_ENTRY_LSB	38
#define MIDI_CTRL_CHANNEL_VOLUME_LSB	39
#define MIDI_CTRL_BALANCE_LSB		40
#define MIDI_CTRL_PAN_LSB		42
#define MIDI_CTRL_EXPRESSION_LSB	43
#define MIDI_CTRL_EFFECT_1_LSB		44
#define MIDI_CTRL_EFFECT_2_LSB		45
#define MIDI_CTRL_GENERAL_PURPOSE_1_LSB	48
#define MIDI_CTRL_GENERAL_PURPOSE_2_LSB	49
#define MIDI_CTRL_GENERAL_PURPOSE_3_LSB	50
#define MIDI_CTRL_GENERAL_PURPOSE_4_LSB	51
#define MIDI_CTRL_HOLD_1		64
#define MIDI_CTRL_PORTAMENTO		65
#define MIDI_CTRL_SOSTENUTO		66
#define MIDI_CTRL_SOFT_PEDAL		67
#define MIDI_CTRL_LEGATO		68
#define MIDI_CTRL_HOLD_2		69
#define MIDI_CTRL_SOUND_VARIATION	70
#define MIDI_CTRL_HARMONIC_INTENSITY	71
#define MIDI_CTRL_RELEASE_TIME		72
#define MIDI_CTRL_ATTACK_TIME		73
#define MIDI_CTRL_BRIGHTNESS		74
#define MIDI_CTRL_DECAY_TIME		75
#define MIDI_CTRL_VIBRATO_RATE		76
#define MIDI_CTRL_VIBRATO_DEPTH		77
#define MIDI_CTRL_VIBRATO_DELAY		78
#define MIDI_CTRL_VIBRATO_DECAY		MIDI_CTRL_VIBRATO_DELAY /*deprecated*/
#define MIDI_CTRL_SOUND_10		79
#define MIDI_CTRL_GENERAL_PURPOSE_5	80
#define MIDI_CTRL_GENERAL_PURPOSE_6	81
#define MIDI_CTRL_GENERAL_PURPOSE_7	82
#define MIDI_CTRL_GENERAL_PURPOSE_8	83
#define MIDI_CTRL_PORTAMENTO_CONTROL	84
#define MIDI_CTRL_EFFECT_DEPTH_1	91
#define MIDI_CTRL_EFFECT_DEPTH_2	92
#define MIDI_CTRL_EFFECT_DEPTH_3	93
#define MIDI_CTRL_EFFECT_DEPTH_4	94
#define MIDI_CTRL_EFFECT_DEPTH_5	95
#define MIDI_CTRL_RPN_INCREMENT		96
#define MIDI_CTRL_RPN_DECREMENT		97
#define MIDI_CTRL_NRPN_LSB		98
#define MIDI_CTRL_NRPN_MSB		99
#define MIDI_CTRL_RPN_LSB		100
#define MIDI_CTRL_RPN_MSB		101
#define MIDI_CTRL_SOUND_OFF		120
#define MIDI_CTRL_RESET			121
#define MIDI_CTRL_LOCAL			122
#define MIDI_CTRL_NOTES_OFF		123
#define MIDI_CTRL_ALLOFF		MIDI_CTRL_NOTES_OFF /*deprecated*/
#define MIDI_CTRL_OMNI_OFF		124
#define MIDI_CTRL_OMNI_ON		125
#define MIDI_CTRL_POLY_OFF		126
#define MIDI_CTRL_POLY_ON		127

#define MIDI_BEND_NEUTRAL	(1<<13)

#define MIDI_RPN_PITCH_BEND_SENSITIVITY	0
#define MIDI_RPN_CHANNEL_FINE_TUNING	1
#define MIDI_RPN_CHANNEL_COARSE_TUNING	2
#define MIDI_RPN_TUNING_PROGRAM_CHANGE	3
#define MIDI_RPN_TUNING_BANK_SELECT	4
#define MIDI_RPN_MODULATION_DEPTH_RANGE	5

#define MIDI_NOTEOFF		0x80
#define MIDI_NOTEON		0x90
#define MIDI_KEY_PRESSURE	0xA0
#define MIDI_CTL_CHANGE		0xB0
#define MIDI_PGM_CHANGE		0xC0
#define MIDI_CHN_PRESSURE	0xD0
#define MIDI_PITCH_BEND		0xE0
#define MIDI_SYSTEM_PREFIX	0xF0

#define MIDI_IS_STATUS(d) ((d) >= 0x80)
#define MIDI_IS_COMMON(d) ((d) >= 0xf0)

#define MIDI_SYSEX_START	0xF0
#define MIDI_SYSEX_END		0xF7

#define MIDI_GET_STATUS(d) ((d) & 0xf0)
#define MIDI_GET_CHAN(d) ((d) & 0x0f)

#define MIDI_HALF_VEL 64

#define SEQ_LOCAL		0x80
#define SEQ_TIMING		0x81
#define SEQ_CHN_COMMON		0x92
#define SEQ_CHN_VOICE		0x93
#define SEQ_SYSEX		0x94
#define SEQ_FULLSIZE		0xfd

#define SEQ_MK_CHN_VOICE(e, unit, cmd, chan, key, vel) (\
    (e)->arr[0] = SEQ_CHN_VOICE, (e)->arr[1] = (unit), (e)->arr[2] = (cmd),\
    (e)->arr[3] = (chan), (e)->arr[4] = (key), (e)->arr[5] = (vel),\
    (e)->arr[6] = 0, (e)->arr[7] = 0)
#define SEQ_MK_CHN_COMMON(e, unit, cmd, chan, p1, p2, w14) (\
    (e)->arr[0] = SEQ_CHN_COMMON, (e)->arr[1] = (unit), (e)->arr[2] = (cmd),\
    (e)->arr[3] = (chan), (e)->arr[4] = (p1), (e)->arr[5] = (p2),\
    *(short*)&(e)->arr[6] = (w14))

#if _BYTE_ORDER == _BIG_ENDIAN
/* big endian */
#define SEQ_PATCHKEY(id) (0xfd00|id)
#else
/* little endian */
#define SEQ_PATCHKEY(id) ((id<<8)|0xfd)
#endif
struct sysex_info {
	uint16_t	key;	/* Use SYSEX_PATCH or MAUI_PATCH here */
#define SEQ_SYSEX_PATCH	SEQ_PATCHKEY(0x05)
#define SEQ_MAUI_PATCH	SEQ_PATCHKEY(0x06)
	int16_t	device_no;	/* Synthesizer number */
	int32_t	len;		/* Size of the sysex data in bytes */
	u_char	data[1];	/* Sysex data starts here */
};
#define SEQ_SYSEX_HDRSIZE ((u_long)((struct sysex_info *)0)->data)

typedef unsigned char sbi_instr_data[32];
struct sbi_instrument {
	uint16_t key;	/* FM_PATCH or OPL3_PATCH */
#define SBI_FM_PATCH	SEQ_PATCHKEY(0x01)
#define SBI_OPL3_PATCH	SEQ_PATCHKEY(0x03)
	int16_t		device;
	int32_t		channel;
	sbi_instr_data	operators;
};

#define TMR_RESET		0	/* beware: not an OSS event */
#define TMR_WAIT_REL		1	/* Time relative to the prev time */
#define TMR_WAIT_ABS		2	/* Absolute time since TMR_START */
#define TMR_STOP		3
#define TMR_START		4
#define TMR_CONTINUE		5
#define TMR_TEMPO		6
#define TMR_ECHO		8
#define TMR_CLOCK		9	/* MIDI clock */
#define TMR_SPP			10	/* Song position pointer */
#define TMR_TIMESIG		11	/* Time signature */

/* Old sequencer definitions */
#define SEQOLD_CMDSIZE 4

#define SEQOLD_NOTEOFF		0
#define SEQOLD_NOTEON		1
#define SEQOLD_WAIT		TMR_WAIT_ABS
#define SEQOLD_PGMCHANGE	3
#define SEQOLD_SYNCTIMER	TMR_START
#define SEQOLD_MIDIPUTC		5
#define SEQOLD_ECHO		TMR_ECHO
#define SEQOLD_AFTERTOUCH	9
#define SEQOLD_CONTROLLER	10
#define SEQOLD_PRIVATE		0xfe
#define SEQOLD_EXTENDED		0xff

/*
 * The 'midipitch' data type, used in the kernel between the midisyn layer and
 * onboard synth drivers, and in userland as parameters to the MIDI Tuning Spec
 * (RP-012) universal-system-exclusive messages. It is a MIDI key number shifted
 * left to accommodate 14 bit sub-semitone resolution. In this representation,
 * tuning and bending adjustments are simple addition and subtraction.
 */
typedef int32_t midipitch_t;

/*
 * Nominal conversions between midipitches and key numbers. (Beware that these
 * are the nominal, standard correspondences, but whole point of the MIDI Tuning
 * Spec is that you can set things up so the hardware might render key N at
 * actual pitch MIDIPITCH_FROM_KEY(N)+c for some correction c.)
 */
#define MIDIPITCH_FROM_KEY(k) ((k)<<14)
#define MIDIPITCH_TO_KEY(mp) (((mp)+(1<<13))>>14)

#define MIDIPITCH_MAX (MIDIPITCH_FROM_KEY(128)-2) /* ...(128)-1 is reserved */
#define MIDIPITCH_OCTAVE  196608
#define MIDIPITCH_SEMITONE 16384
#define MIDIPITCH_CENT       164 /* this, regrettably, is inexact. */

/*
 * For rendering, convert a midipitch (after all tuning adjustments) to Hz.
 * The conversion is DEFINED as MIDI key 69.00000 (A) === 440 Hz equal tempered
 * always. Alternate tunings are obtained by adjusting midipitches.
 *
 * The midihz18_t (Hz shifted left for 18-bit sub-Hz resolution) covers the
 * full midipitch range without losing 21-bit precision, as the lowest midipitch
 * is ~8 Hz (~3 bits left of radix point, 18 right) and for the highest the
 * result still fits in a uint32.
 */
typedef uint32_t midihz18_t;

#define MIDIHZ18_TO_HZ(h18) ((h18)>>18) /* truncates! ok for dbg msgs maybe */

#ifndef _KERNEL
/*
 * With floating point in userland, can also manipulate midipitches as
 * floating-point fractional MIDI key numbers (tuning adjustments are still
 * additive), and hz18 as fractional Hz (adjustments don't add in this form).
 */
#include <math.h>
#define MIDIPITCH_TO_FRKEY(mp) (scalbn((mp),-14))
#define MIDIPITCH_FROM_FRKEY(frk) ((midipitch_t)round(scalbn((frk),14)))
#define MIDIHZ18_TO_FRHZ(h18) (scalbn((h18),-18))
#define MIDIHZ18_FROM_FRHZ(frh) ((midihz18_t)round(scalbn((frh),18)))

#define MIDIPITCH_TO_FRHZ(mp) (440*pow(2,(MIDIPITCH_TO_FRKEY((mp))-69)/12))
#define MIDIPITCH_FROM_FRHZ(fhz) \
                               MIDIPITCH_FROM_FRKEY(69+12*log((fhz)/440)/log(2))
#define MIDIPITCH_TO_HZ18(mp) MIDIHZ18_FROM_FRHZ(MIDIPITCH_TO_FRHZ((mp)))
#define MIDIPITCH_FROM_HZ18(h18) MIDIPITCH_FROM_FRHZ(MIDIHZ18_TO_FRHZ((h18)))

#else /* no fp in kernel; only an accurate to-hz18 conversion is implemented */

extern midihz18_t midisyn_mp2hz18(midipitch_t);
#define MIDIPITCH_TO_HZ18(mp) (midisyn_mp2hz18((mp)))

#endif /* _KERNEL */


/*
 * A native API for the /dev/music sequencer device follows. The event
 * structures are OSS events at the level of bytes, but for developing or
 * porting applications some macros and documentation are needed to generate
 * and dissect the events; here they are. For porting existing OSS applications,
 * sys/soundcard.h can be extended to supply the usual OSS macros, defining them
 * in terms of these.
 */

/*
 * TODO: determine OSS compatible structures for TMR_RESET and TMR_CLOCK,
 *       OSS values of EV_SYSTEM, SNDCTL_SEQ_ACTSENSE_ENABLE,
 *       SNDCTL_SEQ_TIMING_ENABLE, and SNDCTL_SEQ_RT_ENABLE.
 * (TMR_RESET may be a NetBSD extension: it is generated in sequencer.c and
 * has no args. To be corrected if a different definition is found anywhere.)
 */
typedef union {

#define _EVT_HDR \
	uint8_t tag

	_EVT_HDR;

#define _LOCAL_HDR \
	_EVT_HDR; \
	uint8_t op

	struct { _LOCAL_HDR; } local;

	struct {
		_LOCAL_HDR;
		uint16_t _zero;
		uint32_t devmask;
	} l_startaudio;

/* define a constructor for local evts - someday when we support any */

#define _TIMING_HDR \
	_LOCAL_HDR; \
	uint16_t _zeroh
	struct { _TIMING_HDR; } timing;
	
	struct {
		_TIMING_HDR;
		uint32_t divisions;
	} t_WAIT_REL, t_WAIT_ABS;
	
	struct {
		_TIMING_HDR;
		uint32_t _zero;
	} t_STOP, t_START, t_CONTINUE, t_RESET;
	
	struct {
		_TIMING_HDR;
		uint32_t bpm; /* unambiguously, (MIDI clocks/minute)/24 */
	} t_TEMPO;
	
	struct {
		_TIMING_HDR;
		uint32_t cookie;
	} t_ECHO;
	
	struct {
		_TIMING_HDR;
		uint32_t midibeat; /* in low 14 bits; midibeat: 6 MIDI clocks */
	} t_SPP;
	
	struct {
		_TIMING_HDR;
#if _BYTE_ORDER == _BIG_ENDIAN
		uint8_t numerator;
		uint8_t lg2denom;
		uint8_t clks_per_click;
		uint8_t dsq_per_24clks;
#elif _BYTE_ORDER == _LITTLE_ENDIAN
		uint8_t dsq_per_24clks;
		uint8_t clks_per_click;
		uint8_t lg2denom;
		uint8_t numerator;
#else
#error "unexpected _BYTE_ORDER"
#endif
	} t_TIMESIG;
	
	struct { /* use this only to implement OSS compatibility macro */
		_TIMING_HDR;
		uint32_t signature;
	} t_osscompat_timesig;
	

#define _COMMON_HDR \
	_EVT_HDR; \
	uint8_t device; \
	uint8_t op; \
	uint8_t channel

	struct { _COMMON_HDR; } common;

	struct {
		_COMMON_HDR;
		uint8_t controller;
		uint8_t _zero;
		uint16_t value;
	} c_CTL_CHANGE;
	
	struct {
		_COMMON_HDR;
		uint8_t program;
		uint8_t _zero0;
		uint16_t _zero1;
	} c_PGM_CHANGE;
	
	struct {
		_COMMON_HDR;
		uint8_t pressure;
		uint8_t _zero0;
		uint16_t _zero1;
	} c_CHN_PRESSURE;
	
	struct {
		_COMMON_HDR;
		uint8_t _zero0;
		uint8_t _zero1;
		uint16_t value;
	} c_PITCH_BEND;

#define _VOICE_HDR \
	_COMMON_HDR; \
	uint8_t key

	struct { _VOICE_HDR; }  voice;

	struct {
		_VOICE_HDR;
		uint8_t velocity;
		uint16_t _zero;
	} c_NOTEOFF, c_NOTEON;

	struct {
		_VOICE_HDR;
		uint8_t pressure;
		uint16_t _zero;
	} c_KEY_PRESSURE;

	struct {
		_EVT_HDR;
		uint8_t device;
		uint8_t buffer[6];
	} sysex;

	struct {
		_EVT_HDR;
		uint8_t device;
		uint8_t status;
		uint8_t data[2];
	} system;
	
	struct {
		_EVT_HDR;
		uint8_t byte;
		uint8_t device;
		uint8_t _zero0;
		uint32_t _zero1;
	} putc; /* a seqold event that's still needed at times, ugly as 'tis */

	struct {
		_EVT_HDR;
		uint8_t byte[7];
	} unknown; /* for debug/display */

#undef _VOICE_HDR
#undef _COMMON_HDR
#undef _TIMING_HDR
#undef _LOCAL_HDR
#undef _EVT_HDR
	
} __packed seq_event_t;

#define _SEQ_TAG_NOTEOFF	SEQ_CHN_VOICE
#define _SEQ_TAG_NOTEON 	SEQ_CHN_VOICE
#define _SEQ_TAG_KEY_PRESSURE	SEQ_CHN_VOICE

#define _SEQ_TAG_CTL_CHANGE	SEQ_CHN_COMMON
#define _SEQ_TAG_PGM_CHANGE	SEQ_CHN_COMMON
#define _SEQ_TAG_CHN_PRESSURE	SEQ_CHN_COMMON
#define _SEQ_TAG_PITCH_BEND	SEQ_CHN_COMMON

#if __STDC_VERSION__ >= 199901L

#define SEQ_MK_EVENT(_member,_tag,...)					\
(seq_event_t){ ._member = { .tag = (_tag), __VA_ARGS__ } }

#define SEQ_MK_TIMING(_op,...)						\
SEQ_MK_EVENT(t_##_op, SEQ_TIMING, .op = TMR_##_op, __VA_ARGS__)

#define SEQ_MK_CHN(_op,...)						\
SEQ_MK_EVENT(c_##_op, _SEQ_TAG_##_op, .op = MIDI_##_op, __VA_ARGS__)

#define SEQ_MK_SYSEX(_dev,...)						\
SEQ_MK_EVENT(sysex, 0x94, .device=(_dev), 				\
             .buffer={0xff, 0xff, 0xff, 0xff, 0xff, 0xff, __VA_ARGS__})

#else /* assume gcc 2.95.3 */

#define SEQ_MK_EVENT(_member,_tag,_args...)				\
(seq_event_t){ ._member = { .tag = (_tag), _args } }

#define SEQ_MK_TIMING(_op,_args...)						\
SEQ_MK_EVENT(t_##_op, SEQ_TIMING, .op = TMR_##_op, _args)

#define SEQ_MK_CHN(_op,_args...)					\
SEQ_MK_EVENT(c_##_op, _SEQ_TAG_##_op, .op = MIDI_##_op, _args)

#define SEQ_MK_SYSEX(_dev,_args...)						\
SEQ_MK_EVENT(sysex, 0x94, .device=(_dev), 				\
             .buffer={0xff, 0xff, 0xff, 0xff, 0xff, 0xff, _args})

#endif /* c99 vs. gcc 2.95.3 */

#if 0
#include <fcntl.h>
#include <stdio.h>
int
main(int argc, char **argv)
{
	int i;
	int fd;
	seq_event_t e;
	
	/* simple usage example (add a buffer to reduce syscall overhead) */
	fd = open("/dev/music", O_RDWR);
	write(fd, &SEQ_MK_TIMING(START), sizeof (seq_event_t));
	
	read(fd, &e, sizeof e);
	switch ( e.tag ) {
	case SEQ_CHN_VOICE:
		switch ( e.voice.op ) {
		case MIDI_NOTEON:
			printf("Note on, dev=%d chn=%d key=%d vel=%d\n",
			    e.c_NOTEON.device, e.c_NOTEON.channel,
			    e.c_NOTEON.key, e.c_NOTEON.velocity);
		}
	}

	/* all the macros: */
	e = SEQ_MK_TIMING(START);
	e = SEQ_MK_TIMING(STOP);
	e = SEQ_MK_TIMING(CONTINUE);
	/*
	 * Wait until the specified number of divisions from the timer start
	 * (abs) or the preceding event (rel). The number of divisions to a
	 * beat or to a MIDI clock is determined by the timebase (set by
	 * ioctl). The tempo is expressed in beats per minute, where a beat
	 * is always 24 MIDI clocks (and usually equated to a quarter note,
	 * but that can be changed with timesig)--that is, tempo is
	 * (MIDI clocks per minute)/24. The timebase is the number of divisions
	 * in a beat--that is, the number of divisions that make up 24 MIDI
	 * clocks--so the timebase is 24*(divisions per MIDI clock). The MThd
	 * header in a SMF gives the 'natural' timebase for the file; if the
	 * timebase is set accordingly, then the delay values appearing in the
	 * tracks are in terms of divisions, and can be used as WAIT_REL
	 * arguments without modification.
	 */
	e = SEQ_MK_TIMING(WAIT_ABS, .divisions=192);
	e = SEQ_MK_TIMING(WAIT_REL, .divisions=192);
	/*
	 * The 'beat' in bpm is 24 MIDI clocks (usually a quarter note but
	 * changeable with timesig).
	 */
	e = SEQ_MK_TIMING(TEMPO, .bpm=84);
	/*
	 * An ECHO event on output appears on input at the appointed time; the
	 * cookie can be anything of interest to the application. Can be used
	 * in schemes to get some control over latency.
	 */
	e = SEQ_MK_TIMING(ECHO, .cookie=0xfeedface);
	/*
	 * A midibeat is smaller than a beat. It is six MIDI clocks, or a fourth
	 * of a beat, or a sixteenth note if the beat is a quarter. SPP is a
	 * request to position at the requested midibeat from the start of the
	 * sequence. [sequencer does not at present implement SPP]
	 */
	e = SEQ_MK_TIMING(SPP, .midibeat=128);
	/*
	 * numerator and lg2denom describe the time signature as it would
	 * appear on a staff, where lg2denom of 0,1,2,3... corresponds to
	 * denominator of 1,2,4,8... respectively. So the example below
	 * corresponds to 4/4. dsq_per_24clks defines the relationship of
	 * MIDI clocks to note values, by specifying the number of
	 * demisemiquavers (32nd notes) represented by 24 MIDI clocks.
	 * The default is 8 demisemiquavers, or a quarter note.
	 * clks_per_click can configure a metronome (for example, the MPU401
	 * had such a feature in intelligent mode) to click every so many
	 * MIDI clocks. The 24 in this example would give a click every quarter
	 * note. [sequencer does not at present implement TIMESIG]
	 */
	e = SEQ_MK_TIMING(TIMESIG, .numerator=4, .lg2denom=2,
	                           .clks_per_click=24, .dsq_per_24clks=8);
	/*
	 * This example declares 6/8 time where the beat (24 clocks) is the
	 * eighth note, but the metronome clicks every dotted quarter (twice
	 * per measure):
	 */
	e = SEQ_MK_TIMING(TIMESIG, .numerator=6, .lg2denom=3,
	                           .clks_per_click=72, .dsq_per_24clks=4);
	/*
	 * An alternate declaration for 6/8 where the beat (24 clocks) is now
	 * the dotted quarter and corresponds to the metronome click:
	 */
	e = SEQ_MK_TIMING(TIMESIG, .numerator=6, .lg2denom=3,
	                           .clks_per_click=24, .dsq_per_24clks=12);
	/*
	 * It would also be possible to keep the default correspondence of
	 * 24 clocks to the quarter note (8 dsq), and still click the metronome
	 * each dotted quarter:
	 */
	e = SEQ_MK_TIMING(TIMESIG, .numerator=6, .lg2denom=3,
	                           .clks_per_click=36, .dsq_per_24clks=8);

	e = SEQ_MK_CHN(NOTEON,  .device=1, .channel=0, .key=60, .velocity=64);
	e = SEQ_MK_CHN(NOTEOFF, .device=1, .channel=0, .key=60, .velocity=64);
	e = SEQ_MK_CHN(KEY_PRESSURE, .device=1, .channel=0, .key=60,
	                             .pressure=64);
	
	/*
	 * sequencer does not at present implement CTL_CHANGE well. The API
	 * provides for a 14-bit value where you give the controller index
	 * of the controller MSB and sequencer will split the 14-bit value to
	 * the controller MSB and LSB for you--but it doesn't; it ignores the
	 * high bits of value and writes the low bits whether you have specified
	 * MSB or LSB. That would not be hard to fix but for the fact that OSS
	 * itself seems to suffer from the same mixup (and its behavior differs
	 * with whether the underlying device is an onboard synth or a MIDI
	 * link!) so there is surely a lot of code that relies on it being
	 * broken :(.
	 * (Note: as the OSS developers have ceased development of the
	 * /dev/music API as of OSS4, it would be possible given a complete
	 * list of the events defined in OSS4 to add some new ones for native
	 * use without fear of future conflict, such as a better ctl_change.)
	 */
	e = SEQ_MK_CHN(CTL_CHANGE, .device=1, .channel=0,
	               .controller=MIDI_CTRL_EXPRESSION_MSB, .value=8192);/*XX*/
	/*
	 * The way you really have to do it:
	 */
	e = SEQ_MK_CHN(CTL_CHANGE, .device=1, .channel=0,
	               .controller=MIDI_CTRL_EXPRESSION_MSB, .value=8192>>7);
	e = SEQ_MK_CHN(CTL_CHANGE, .device=1, .channel=0,
	               .controller=MIDI_CTRL_EXPRESSION_LSB, .value=8192&0x7f);

	e = SEQ_MK_CHN(PGM_CHANGE,   .device=1, .channel=0, .program=51);
	e = SEQ_MK_CHN(CHN_PRESSURE, .device=1, .channel=0, .pressure=64);
	e = SEQ_MK_CHN(PITCH_BEND,   .device=1, .channel=0, .value=8192);
	
	/*
	 * A SYSEX event carries up to six bytes of a system exclusive message.
	 * The first such message must begin with MIDI_SYSEX_START (0xf0), the
	 * last must end with MIDI_SYSEX_END (0xf7), and only the last may carry
	 * fewer than 6 bytes. To supply message bytes in the macro, you must
	 * prefix the first with [0]= as shown. The macro's first argument is
	 * the device.
	 */
	e = SEQ_MK_SYSEX(1,[0]=MIDI_SYSEX_START,1,2,MIDI_SYSEX_END);
	/*
	 * In some cases it may be easier to use the macro only to initialize
	 * the event, and fill in the message bytes later. The code that fills
	 * in the message does not need to store 0xff following the SYSEX_END.
	 */
	e = SEQ_MK_SYSEX(1);
	for ( i = 0; i < 3; ++ i )
		e.sysex.buffer[i] = i;
	/*
	 * It would be nice to think the old /dev/sequencer MIDIPUTC event
	 * obsolete, but it is still needed (absent any better API) by any MIDI
	 * file player that will implement the ESCAPED events that may occur in
	 * SMF. Sorry. Here's how to use it:
	 */
	e = SEQ_MK_EVENT(putc, SEQOLD_MIDIPUTC, .device=1, .byte=42);
	
	printf("confirm event size: %d (should be 8)\n", sizeof (seq_event_t));
	return 0;
}
#endif /* 0 */

#endif /* !_SYS_MIDIIO_H_ */