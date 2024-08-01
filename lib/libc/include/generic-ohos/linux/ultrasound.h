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
#ifndef _ULTRASOUND_H_
#define _ULTRASOUND_H_
#define _GUS_NUMVOICES 0x00
#define _GUS_VOICESAMPLE 0x01
#define _GUS_VOICEON 0x02
#define _GUS_VOICEOFF 0x03
#define _GUS_VOICEMODE 0x04
#define _GUS_VOICEBALA 0x05
#define _GUS_VOICEFREQ 0x06
#define _GUS_VOICEVOL 0x07
#define _GUS_RAMPRANGE 0x08
#define _GUS_RAMPRATE 0x09
#define _GUS_RAMPMODE 0x0a
#define _GUS_RAMPON 0x0b
#define _GUS_RAMPOFF 0x0c
#define _GUS_VOICEFADE 0x0d
#define _GUS_VOLUME_SCALE 0x0e
#define _GUS_VOICEVOL2 0x0f
#define _GUS_VOICE_POS 0x10
#define _GUS_CMD(chn,voice,cmd,p1,p2) { _SEQ_NEEDBUF(8); _seqbuf[_seqbufptr] = SEQ_PRIVATE; _seqbuf[_seqbufptr + 1] = (chn); _seqbuf[_seqbufptr + 2] = cmd; _seqbuf[_seqbufptr + 3] = voice; * (unsigned short *) & _seqbuf[_seqbufptr + 4] = p1; * (unsigned short *) & _seqbuf[_seqbufptr + 6] = p2; _SEQ_ADVBUF(8); }
#define GUS_NUMVOICES(chn,p1) _GUS_CMD(chn, 0, _GUS_NUMVOICES, (p1), 0)
#define GUS_VOICESAMPLE(chn,voice,p1) _GUS_CMD(chn, voice, _GUS_VOICESAMPLE, (p1), 0)
#define GUS_VOICEON(chn,voice,p1) _GUS_CMD(chn, voice, _GUS_VOICEON, (p1), 0)
#define GUS_VOICEOFF(chn,voice) _GUS_CMD(chn, voice, _GUS_VOICEOFF, 0, 0)
#define GUS_VOICEFADE(chn,voice) _GUS_CMD(chn, voice, _GUS_VOICEFADE, 0, 0)
#define GUS_VOICEMODE(chn,voice,p1) _GUS_CMD(chn, voice, _GUS_VOICEMODE, (p1), 0)
#define GUS_VOICEBALA(chn,voice,p1) _GUS_CMD(chn, voice, _GUS_VOICEBALA, (p1), 0)
#define GUS_VOICEFREQ(chn,voice,p) _GUS_CMD(chn, voice, _GUS_VOICEFREQ, (p) & 0xffff, ((p) >> 16) & 0xffff)
#define GUS_VOICEVOL(chn,voice,p1) _GUS_CMD(chn, voice, _GUS_VOICEVOL, (p1), 0)
#define GUS_VOICEVOL2(chn,voice,p1) _GUS_CMD(chn, voice, _GUS_VOICEVOL2, (p1), 0)
#define GUS_RAMPRANGE(chn,voice,low,high) _GUS_CMD(chn, voice, _GUS_RAMPRANGE, (low), (high))
#define GUS_RAMPRATE(chn,voice,p1,p2) _GUS_CMD(chn, voice, _GUS_RAMPRATE, (p1), (p2))
#define GUS_RAMPMODE(chn,voice,p1) _GUS_CMD(chn, voice, _GUS_RAMPMODE, (p1), 0)
#define GUS_RAMPON(chn,voice,p1) _GUS_CMD(chn, voice, _GUS_RAMPON, (p1), 0)
#define GUS_RAMPOFF(chn,voice) _GUS_CMD(chn, voice, _GUS_RAMPOFF, 0, 0)
#define GUS_VOLUME_SCALE(chn,voice,p1,p2) _GUS_CMD(chn, voice, _GUS_VOLUME_SCALE, (p1), (p2))
#define GUS_VOICE_POS(chn,voice,p) _GUS_CMD(chn, voice, _GUS_VOICE_POS, (p) & 0xffff, ((p) >> 16) & 0xffff)
#endif