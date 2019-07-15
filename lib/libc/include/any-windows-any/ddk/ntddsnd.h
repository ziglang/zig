/*
    ReactOS Sound System
    NT4 Multimedia Audio Support (ntddsnd.h)

    This file is in the public domain.

    Author:
        Andrew Greenwood (andrew.greenwood@silverblade.co.uk)

    History:
        24 May 2008 - Created
        2 July 2008 - Added device names as seen from user-mode
        5 July 2008 - Added macros for checking device type
        14 Feb 2009 - Added base control codes for nonstandard extensions

    This file contains definitions and structures for Windows NT4 style
    multimedia drivers. The NT4 DDK has these split across multiple header
    files: NTDDSND.H, NTDDWAVE.H, NTDDMIDI.H, NTDDMIX.H and NTDDAUX.H

    Should you have an unstoppable urge to build an NT4 multimedia driver
    against these headers, just create the other files listed above and make
    them #include this one.

    There are also a number of additional enhancements within this file
    not found in the originals (such as DOS device name strings and device
    type IDs).
*/

#ifndef NTDDSND_H
#define NTDDSND_H

#define SOUND_MAX_DEVICES           100
#define SOUND_MAX_DEVICE_NAME       80


/*
    Base control codes
*/

#define IOCTL_SOUND_BASE    FILE_DEVICE_SOUND
#define IOCTL_WAVE_BASE     0x0000
#define IOCTL_MIDI_BASE     0x0080
#define IOCTL_AUX_BASE      0x0100
#define IOCTL_MIX_BASE      0x0180


/*
    Helper macros for defining control codes
*/

#define WAVE_CTL_CODE(subcode, iomethod, access) \
    CTL_CODE(FILE_DEVICE_SOUND, IOCTL_WAVE_BASE + subcode, iomethod, access)

#define MIDI_CTL_CODE(subcode, iomethod, access) \
    CTL_CODE(FILE_DEVICE_SOUND, IOCTL_MIDI_BASE + subcode, iomethod, access)

#define MIX_CTL_CODE(subcode, iomethod, access) \
    CTL_CODE(FILE_DEVICE_SOUND, IOCTL_MIX_BASE + subcode, iomethod, access)

#define AUX_CTL_CODE(subcode, iomethod, access) \
    CTL_CODE(FILE_DEVICE_SOUND, IOCTL_AUX_BASE + subcode, iomethod, access)


/*
    Wave device control codes
*/

#define IOCTL_WAVE_QUERY_FORMAT \
    WAVE_CTL_CODE(0x0001, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_WAVE_SET_FORMAT \
    WAVE_CTL_CODE(0x0002, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_GET_CAPABILITIES \
    WAVE_CTL_CODE(0x0003, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_WAVE_SET_STATE \
    WAVE_CTL_CODE(0x0004, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_GET_STATE \
    WAVE_CTL_CODE(0x0005, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_GET_POSITION \
    WAVE_CTL_CODE(0x0006, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_SET_VOLUME \
    WAVE_CTL_CODE(0x0007, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_WAVE_GET_VOLUME \
    WAVE_CTL_CODE(0x0008, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_WAVE_SET_PITCH \
    WAVE_CTL_CODE(0x0009, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_GET_PITCH \
    WAVE_CTL_CODE(0x000A, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_SET_PLAYBACK_RATE \
    WAVE_CTL_CODE(0x000B, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_GET_PLAYBACK_RATE \
    WAVE_CTL_CODE(0x000C, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_PLAY \
    WAVE_CTL_CODE(0x000D, METHOD_IN_DIRECT, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_RECORD \
    WAVE_CTL_CODE(0x000E, METHOD_OUT_DIRECT, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_BREAK_LOOP \
    WAVE_CTL_CODE(0x000F, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_WAVE_SET_LOW_PRIORITY \
    WAVE_CTL_CODE(0x0010, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#if DBG
/* Debug-only control code */
#define IOCTL_WAVE_SET_DEBUG_LEVEL \
        WAVE_CTL_CODE(0x0040, METHOD_BUFFERED, FILE_READ_ACCESS)
#endif


/*
    MIDI device control codes
*/

#define IOCTL_MIDI_GET_CAPABILITIES \
    MIDI_CTL_CODE(0x0001, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_MIDI_SET_STATE \
    MIDI_CTL_CODE(0x0002, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_MIDI_GET_STATE \
    MIDI_CTL_CODE(0x0003, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_MIDI_SET_VOLUME \
    MIDI_CTL_CODE(0x0004, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_MIDI_GET_VOLUME \
    MIDI_CTL_CODE(0x0005, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_MIDI_PLAY \
    MIDI_CTL_CODE(0x0006, METHOD_NEITHER, FILE_WRITE_ACCESS)

#define IOCTL_MIDI_RECORD \
    MIDI_CTL_CODE(0x0007, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_MIDI_CACHE_PATCHES \
    MIDI_CTL_CODE(0x0008, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#define IOCTL_MIDI_CACHE_DRUM_PATCHES \
    MIDI_CTL_CODE(0x0009, METHOD_BUFFERED, FILE_WRITE_ACCESS)

#if DBG
/* Debug-only control code */
#define IOCTL_MIDI_SET_DEBUG_LEVEL \
        WAVE_CTL_CODE(0x0040, METHOD_BUFFERED, FILE_READ_ACCESS)
#endif


/*
    Mixer device control codes
*/

#define IOCTL_MIX_GET_CONFIGURATION \
    MIX_CTL_CODE(0x0001, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_MIX_GET_CONTROL_DATA \
    MIX_CTL_CODE(0x0002, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_MIX_GET_LINE_DATA \
    MIX_CTL_CODE(0x0003, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_MIX_REQUEST_NOTIFY \
    MIX_CTL_CODE(0x0004, METHOD_BUFFERED, FILE_READ_ACCESS)


/*
    Auxiliary device control codes
*/

#define IOCTL_AUX_GET_CAPABILITIES \
    AUX_CTL_CODE(0x0001, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_AUX_SET_VOLUME \
    AUX_CTL_CODE(0x0002, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_AUX_GET_VOLUME \
    AUX_CTL_CODE(0x0003, METHOD_BUFFERED, FILE_READ_ACCESS)

#define IOCTL_SOUND_GET_CHANGED_VOLUME \
    AUX_CTL_CODE(0x0004, METHOD_BUFFERED, FILE_READ_ACCESS)


/*
    Wave structures & states
*/

#define WAVE_DD_MAX_VOLUME      0xFFFFFFFF

typedef struct _WAVE_DD_VOLUME
{
    ULONG Left;
    ULONG Right;
} WAVE_DD_VOLUME, *PWAVE_DD_VOLUME;

typedef struct _WAVE_DD_PITCH
{
    ULONG Pitch;
} WAVE_DD_PITCH, *PWAVE_DD_PITCH;

typedef struct _WAVE_DD_PLAYBACK_RATE
{
    ULONG Rate;
} WAVE_DD_PLAYBACK_RATE, *PWAVE_DD_PLAYBACK_RATE;

/* IOCTL_WAVE_SET_STATE commands */
#define WAVE_DD_STOP        0x0001
#define WAVE_DD_PLAY        0x0002
#define WAVE_DD_RECORD      0x0003
#define WAVE_DD_RESET       0x0004

/* IOCTL_WAVE_GET_STATE responses */
#define WAVE_DD_IDLE        0x0000
#define WAVE_DD_STOPPED     0x0001
#define WAVE_DD_PLAYING     0x0002
#define WAVE_DD_RECORDING   0x0003


/*
    MIDI structures & states
*/

typedef struct _MIDI_DD_INPUT_DATA
{
    LARGE_INTEGER Time;
    UCHAR Data[sizeof(ULONG)];
} MIDI_DD_INPUT_DATA, *PMIDI_DD_INPUT_DATA;

typedef struct _MIDI_DD_VOLUME
{
    ULONG Left;
    ULONG Right;
} MIDI_DD_VOLUME, *PMIDI_DD_VOLUME;

typedef struct _MIDI_DD_CACHE_PATCHES
{
    ULONG Bank;
    ULONG Flags;
    ULONG Patches[128];
} MIDI_DD_CACHE_PATCHES, *PMIDI_DD_CACHE_PATCHES;

typedef struct _MIDI_DD_CACHE_DRUM_PATCHES
{
    ULONG Patch;
    ULONG Flags;
    ULONG DrumPatches[128];
} MIDI_DD_CACHE_DRUM_PATCHES, *PMIDI_DD_CACHE_DRUM_PATCHES;

/* IOCTL_MIDI_SET_STATE commands */
#define MIDI_DD_STOP        0x0001
#define MIDI_DD_PLAY        0x0002
#define MIDI_DD_RECORD      0x0003
#define MIDI_DD_RESET       0x0004

/* IOCTL_MIDI_GET_STATE responses */
#define MIDI_DD_IDLE        0x0000
#define MIDI_DD_STOPPED     0x0001
#define MIDI_DD_PLAYING     0x0002
#define MIDI_DD_RECORDING   0x0003


/*
    Mixer structures
    TODO: This is incomplete (see NTDDMIX.H in NT4 DDK)
*/

typedef struct _MIXER_DD_READ_DATA
{
    ULONG Id;
} MIXER_DD_READ_DATA, *PMIXER_DD_READ_DATA;

typedef struct _MIXER_DD_LINE_DATA
{
    ULONG fdwLine;
} MIXER_DD_LINE_DATA, *PMIXER_DD_LINE_DATA;


/*
    Auxiliary structures
*/

#define AUX_DD_MAX_VOLUME   0xFFFFFFFF

typedef struct _AUX_DD_VOLUME
{
    ULONG Left;
    ULONG Right;
} AUX_DD_VOLUME, *PAUX_DD_VOLUME;


#endif /* NTDDSND_H */

