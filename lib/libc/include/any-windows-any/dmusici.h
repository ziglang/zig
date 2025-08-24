#undef INTERFACE
/*
 *  DirectMusic Performance API
 *
 *  Copyright (C) 2003-2004 Rok Mandeljc
 *
 *  This program is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this program; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __WINE_DMUSIC_PERFORMANCE_H
#define __WINE_DMUSIC_PERFORMANCE_H

#include <windows.h>

#define COM_NO_WINDOWS_H
#include <objbase.h>
#include <mmsystem.h>
#include <dmusicc.h>
#include <dmplugin.h>
#pragma pack(push,8)

#ifdef WINE_NO_UNICODE_MACROS
#undef AddPort
#endif

#ifdef __cplusplus
extern "C" {
#endif

/*****************************************************************************
 * Predeclare the interfaces
 */
/* CLSIDs */
DEFINE_GUID(CLSID_DirectMusicAudioPathConfig,              0xee0b9ca0,0xa81e,0x11d3,0x9b,0xd1,0x00,0x80,0xc7,0x15,0x0a,0x74);
DEFINE_GUID(CLSID_DirectMusicBand,                         0x79ba9e00,0xb6ee,0x11d1,0x86,0xbe,0x00,0xc0,0x4f,0xbf,0x8f,0xef);
DEFINE_GUID(CLSID_DirectMusicChordMap,                     0xd2ac288f,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(CLSID_DirectMusicComposer,                     0xd2ac2890,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(CLSID_DirectMusicContainer,                    0x9301e380,0x1f22,0x11d3,0x82,0x26,0xd2,0xfa,0x76,0x25,0x5d,0x47);
DEFINE_GUID(CLSID_DirectMusicGraph,                        0xd2ac2884,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(CLSID_DirectMusicLoader,                       0xd2ac2892,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(CLSID_DirectMusicPatternTrack,                 0xd2ac2897,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(CLSID_DirectMusicPerformance,                  0xd2ac2881,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(CLSID_DirectMusicScript,                       0x810b5013,0xe88d,0x11d2,0x8b,0xc1,0x00,0x60,0x08,0x93,0xb1,0xb6);
DEFINE_GUID(CLSID_DirectMusicSegment,                      0xd2ac2882,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(CLSID_DirectMusicSegmentState,                 0xd2ac2883,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(CLSID_DirectMusicStyle,                        0xd2ac288a,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(CLSID_DirectSoundWave,                         0x8a667154,0xf9cb,0x11d2,0xad,0x8a,0x00,0x60,0xb0,0x57,0x5a,0xbc);
/* MS doesn't support this in DX 9.0 and newer... but there's no harm in keeping it around */
DEFINE_GUID(CLSID_DirectMusicSong,                         0xaed5f0a5,0xd972,0x483d,0xa3,0x84,0x64,0x9d,0xfe,0xb9,0xc1,0x81);
/* these CLSIDs aren't officially declared in any dmusic header, but are used by wine's regsvr implementations*/
DEFINE_GUID(CLSID_DirectMusicSynthSink,                    0xaec17ce3,0xa514,0x11d1,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(CLSID_DirectMusicSection,                      0x3f037241,0x414e,0x11d1,0xa7,0xce,0x00,0xa0,0xc9,0x13,0xf7,0x3c);
DEFINE_GUID(CLSID_DirectMusicAuditionTrack,                0xd2ac2897,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(CLSID_DirectMusicSegTriggerTrack,              0xbae4d665,0x4ea1,0x11d3,0x8b,0xda,0x00,0x60,0x08,0x93,0xb1,0xb6);
DEFINE_GUID(CLSID_DirectMusicTemplate,                     0xd30bcc65,0x60e8,0x11d1,0xa7,0xce,0x00,0xa0,0xc9,0x13,0xf7,0x3c);
DEFINE_GUID(CLSID_DirectMusicScriptAutoImpSegment,         0x4062c116,0x0270,0x11d3,0x8b,0xcb,0x00,0x60,0x08,0x93,0xb1,0xb6);
DEFINE_GUID(CLSID_AudioVBScript,                           0x4ee17959,0x931e,0x49e4,0xa2,0xc6,0x97,0x7e,0xcf,0x36,0x28,0xf3);
DEFINE_GUID(CLSID_DirectMusicScriptAutoImpPerformance,     0xa861c6e2,0xfcfc,0x11d2,0x8b,0xc9,0x00,0x60,0x08,0x93,0xb1,0xb6);
DEFINE_GUID(CLSID_DirectMusicScriptSourceCodeLoader,       0xc70eb77f,0xefd4,0x4678,0xa2,0x7b,0xbf,0x16,0x48,0xf3,0x0d,0x04);
DEFINE_GUID(CLSID_DirectMusicScriptAutoImpSegmentState,    0xebf2320a,0x2502,0x11d3,0x8b,0xd1,0x00,0x60,0x08,0x93,0xb1,0xb6);
DEFINE_GUID(CLSID_DirectMusicScriptAutoImpAudioPathConfig, 0x1cebde3e,0x6b91,0x484a,0xaf,0x48,0x5e,0x4f,0x4e,0xd6,0xb1,0xe1);
DEFINE_GUID(CLSID_DirectMusicScriptAutoImpAudioPath,       0x2c5f9b72,0x7148,0x4d97,0xbf,0xc9,0x68,0xa0,0xe0,0x76,0xbe,0xbd);
DEFINE_GUID(CLSID_DirectMusicScriptAutoImpSong,            0xa16f1761,0xb6d8,0x42eb,0x8d,0x57,0x4a,0x44,0xfe,0xdd,0x3b,0xd2);

/* IIDs */
DEFINE_GUID(IID_IDirectMusicAudioPath,                     0xc87631f5,0x23be,0x4986,0x88,0x36,0x05,0x83,0x2f,0xcc,0x48,0xf9);
DEFINE_GUID(IID_IDirectMusicBand,                          0xd2ac28c0,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicChordMap,                      0xd2ac28be,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicComposer,                      0xd2ac28bf,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicContainer,                     0x9301e386,0x1f22,0x11d3,0x82,0x26,0xd2,0xfa,0x76,0x25,0x5d,0x47);
DEFINE_GUID(IID_IDirectMusicGetLoader,                     0x68a04844,0xd13d,0x11d1,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(IID_IDirectMusicGraph,                         0x2befc277,0x5497,0x11d2,0xbc,0xcb,0x00,0xa0,0xc9,0x22,0xe6,0xeb);
DEFINE_GUID(IID_IDirectMusicLoader,                        0x2ffaaca2,0x5dca,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(IID_IDirectMusicLoader8,                       0x19e7c08c,0x0a44,0x4e6a,0xa1,0x16,0x59,0x5a,0x7c,0xd5,0xde,0x8c);
DEFINE_GUID(IID_IDirectMusicObject,                        0xd2ac28b5,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicPatternTrack,                  0x51c22e10,0xb49f,0x46fc,0xbe,0xc2,0xe6,0x28,0x8f,0xb9,0xed,0xe6);
DEFINE_GUID(IID_IDirectMusicPerformance,                   0x07d43d03,0x6523,0x11d2,0x87,0x1d,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicPerformance2,                  0x6fc2cae0,0xbc78,0x11d2,0xaf,0xa6,0x00,0xaa,0x00,0x24,0xd8,0xb6);
DEFINE_GUID(IID_IDirectMusicPerformance8,                  0x679c4137,0xc62e,0x4147,0xb2,0xb4,0x9d,0x56,0x9a,0xcb,0x25,0x4c);
DEFINE_GUID(IID_IDirectMusicScript,                        0x2252373a,0x5814,0x489b,0x82,0x09,0x31,0xfe,0xde,0xba,0xf1,0x37);
DEFINE_GUID(IID_IDirectMusicSegment,                       0xf96029a2,0x4282,0x11d2,0x87,0x17,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicSegment2,                      0xd38894d1,0xc052,0x11d2,0x87,0x2f,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicSegment8,                      0xc6784488,0x41a3,0x418f,0xaa,0x15,0xb3,0x50,0x93,0xba,0x42,0xd4);
DEFINE_GUID(IID_IDirectMusicSegmentState,                  0xa3afdcc7,0xd3ee,0x11d1,0xbc,0x8d,0x00,0xa0,0xc9,0x22,0xe6,0xeb);
DEFINE_GUID(IID_IDirectMusicSegmentState8,                 0xa50e4730,0x0ae4,0x48a7,0x98,0x39,0xbc,0x04,0xbf,0xe0,0x77,0x72);
DEFINE_GUID(IID_IDirectMusicStyle,                         0xd2ac28bd,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(IID_IDirectMusicStyle8,                        0xfd24ad8a,0xa260,0x453d,0xbf,0x50,0x6f,0x93,0x84,0xf7,0x09,0x85);

/* IIDs of unchanged interfaces */
#define IID_IDirectMusicAudioPath8    IID_IDirectMusicAudioPath
#define IID_IDirectMusicBand8         IID_IDirectMusicBand
#define IID_IDirectMusicChordMap8     IID_IDirectMusicChordMap
#define IID_IDirectMusicComposer8     IID_IDirectMusicComposer
#define IID_IDirectMusicContainer8    IID_IDirectMusicContainer
#define IID_IDirectMusicGetLoader8    IID_IDirectMusicGetLoader
#define IID_IDirectMusicGraph8        IID_IDirectMusicGraph
#define IID_IDirectMusicObject8       IID_IDirectMusicObject
#define IID_IDirectMusicPatternTrack8 IID_IDirectMusicPatternTrack
#define IID_IDirectMusicScript8       IID_IDirectMusicScript

/* typedef definitions */
typedef struct IDirectMusicBand *LPDIRECTMUSICBAND;
typedef struct IDirectMusicBand         IDirectMusicBand8,         *LPDIRECTMUSICBAND8;
typedef struct IDirectMusicObject *LPDIRECTMUSICOBJECT;
typedef struct IDirectMusicObject       IDirectMusicObject8,       *LPDIRECTMUSICOBJECT8;
typedef struct IDirectMusicLoader *LPDIRECTMUSICLOADER;
typedef struct IDirectMusicLoader8 *LPDIRECTMUSICLOADER8;
typedef struct IDirectMusicGetLoader *LPDIRECTMUSICGETLOADER;
typedef struct IDirectMusicGetLoader    IDirectMusicGetLoader8,    *LPDIRECTMUSICGETLOADER8;
typedef struct IDirectMusicAudioPath *LPDIRECTMUSICAUDIOPATH;
typedef struct IDirectMusicAudioPath    IDirectMusicAudioPath8,    *LPDIRECTMUSICAUDIOPATH8;
typedef struct IDirectMusicStyle *LPDIRECTMUSICSTYLE;
typedef struct IDirectMusicStyle8 *LPDIRECTMUSICSTYLE8;
typedef struct IDirectMusicChordMap *LPDIRECTMUSICCHORDMAP;
typedef struct IDirectMusicChordMap     IDirectMusicChordMap8,     *LPDIRECTMUSICCHORDMAP8;
typedef struct IDirectMusicComposer *LPDIRECTMUSICCOMPOSER;
typedef struct IDirectMusicComposer     IDirectMusicComposer8,     *LPDIRECTMUSICCOMPOSER8;
typedef struct IDirectMusicPatternTrack *LPDIRECTMUSICPATTERNTRACK;
typedef struct IDirectMusicPatternTrack IDirectMusicPatternTrack8, *LPDIRECTMUSICPATTERNTRACK8;
typedef struct IDirectMusicScript *LPDIRECTMUSICSCRIPT;
typedef struct IDirectMusicScript       IDirectMusicScript8,       *LPDIRECTMUSICSCRIPT8;
typedef struct IDirectMusicContainer *LPDIRECTMUSICCONTAINER;
typedef struct IDirectMusicContainer    IDirectMusicContainer8,    *LPDIRECTMUSICCONTAINER8;

/* RPC declarations */
typedef struct IDirectMusicBand   *LPDMUS_BAND;
typedef struct IDirectMusicLoader *LPDMUS_LOADER;
typedef struct IDirectMusicObject *LPDMUS_OBJECT;

/* GUIDs - all types loader */
DEFINE_GUID(GUID_DirectMusicAllTypes,         0xd2ac2893,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
/* GUIDs - notification */
DEFINE_GUID(GUID_NOTIFICATION_CHORD,          0xd2ac289b,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_NOTIFICATION_COMMAND,        0xd2ac289c,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_NOTIFICATION_MEASUREANDBEAT, 0xd2ac289a,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_NOTIFICATION_PERFORMANCE,    0x81f75bc5,0x4e5d,0x11d2,0xbc,0xc7,0x00,0xa0,0xc9,0x22,0xe6,0xeb);
DEFINE_GUID(GUID_NOTIFICATION_RECOMPOSE,      0xd348372b,0x945b,0x45ae,0xa5,0x22,0x45,0x0f,0x12,0x5b,0x84,0xa5);
DEFINE_GUID(GUID_NOTIFICATION_SEGMENT,        0xd2ac2899,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
/* GUIDs - param types */
DEFINE_GUID(GUID_BandParam,                   0x02bb1938,0xcb8b,0x11d2,0x8b,0xb9,0x00,0x60,0x08,0x93,0xb1,0xb6);
DEFINE_GUID(GUID_ChordParam,                  0xd2ac289e,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_CommandParam,                0xd2ac289d,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_CommandParam2,               0x28f97ef7,0x9538,0x11d2,0x97,0xa9,0x00,0xc0,0x4f,0xa3,0x6e,0x58);
DEFINE_GUID(GUID_CommandParamNext,            0x472afe7a,0x281b,0x11d3,0x81,0x7d,0x00,0xc0,0x4f,0xa3,0x6e,0x58);
DEFINE_GUID(GUID_IDirectMusicBand,            0xd2ac28ac,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_IDirectMusicChordMap,        0xd2ac28ad,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_IDirectMusicStyle,           0xd2ac28a1,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_MuteParam,                   0xd2ac28af,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_Play_Marker,                 0xd8761a41,0x801a,0x11d3,0x9b,0xd1,0xda,0xf7,0xe1,0xc3,0xd8,0x34);
DEFINE_GUID(GUID_RhythmParam,                 0xd2ac289f,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_TempoParam,                  0xd2ac28a5,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_TimeSignature,               0xd2ac28a4,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_Valid_Start_Time,            0x7f6b1760,0x1fdb,0x11d3,0x82,0x26,0x44,0x45,0x53,0x54,0x00,0x00);
/* GUIDs - param setting */
DEFINE_GUID(GUID_Clear_All_Bands,             0xd2ac28ab,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_ConnectToDLSCollection,      0x1db1ae6b,0xe92e,0x11d1,0xa8,0xc5,0x00,0xc0,0x4f,0xa3,0x72,0x6e);
DEFINE_GUID(GUID_Disable_Auto_Download,       0xd2ac28aa,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_DisableTempo,                0x45fc707d,0x1db4,0x11d2,0xbc,0xac,0x00,0xa0,0xc9,0x22,0xe6,0xeb);
DEFINE_GUID(GUID_DisableTimeSig,              0x45fc707b,0x1db4,0x11d2,0xbc,0xac,0x00,0xa0,0xc9,0x22,0xe6,0xeb);
DEFINE_GUID(GUID_Download,                    0xd2ac28a7,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_DownloadToAudioPath,         0x9f2c0341,0xc5c4,0x11d3,0x9b,0xd1,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_Enable_Auto_Download,        0xd2ac28a9,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_EnableTempo,                 0x45fc707e,0x1db4,0x11d2,0xbc,0xac,0x00,0xa0,0xc9,0x22,0xe6,0xeb);
DEFINE_GUID(GUID_EnableTimeSig,               0x45fc707c,0x1db4,0x11d2,0xbc,0xac,0x00,0xa0,0xc9,0x22,0xe6,0xeb);
#define GUID_IgnoreBankSelectForGM            GUID_StandardMIDIFile
DEFINE_GUID(GUID_SeedVariations,              0x65b76fa5,0xff37,0x11d2,0x81,0x4e,0x00,0xc0,0x4f,0xa3,0x6e,0x58);
DEFINE_GUID(GUID_StandardMIDIFile,            0x06621075,0xe92e,0x11d1,0xa8,0xc5,0x00,0xc0,0x4f,0xa3,0x72,0x6e);
DEFINE_GUID(GUID_Unload,                      0xd2ac28a8,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_UnloadFromAudioPath,         0x9f2c0342,0xc5c4,0x11d3,0x9b,0xd1,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_Variations,                  0x11f72cce,0x26e6,0x4ecd,0xaf,0x2e,0xd6,0x68,0xe6,0x67,0x07,0xd8);
/* GUIDs - global data */
DEFINE_GUID(GUID_PerfMasterTempo,             0xd2ac28b0,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_PerfMasterVolume,            0xd2ac28b1,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_PerfMasterGrooveLevel,       0xd2ac28b2,0xb39b,0x11d1,0x87,0x04,0x00,0x60,0x08,0x93,0xb1,0xbd);
DEFINE_GUID(GUID_PerfAutoDownload,            0xfb09565b,0x3631,0x11d2,0xbc,0xb8,0x00,0xa0,0xc9,0x22,0xe6,0xeb);
/* GUID - default DLS collection */
DEFINE_GUID(GUID_DefaultGMCollection,         0xf17e8673,0xc3b4,0x11d1,0x87,0x0b,0x00,0x60,0x08,0x93,0xb1,0xbd);
/* GUID - default synthesizer */
DEFINE_GUID(GUID_Synth_Default,               0x26bb9432,0x45fe,0x48d3,0xa3,0x75,0x24,0x72,0xc5,0xe3,0xe7,0x86);
/* GUIDs - define default buffer configuration */
DEFINE_GUID(GUID_Buffer_Reverb,               0x186cc541,0xdb29,0x11d3,0x9b,0xd1,0x00,0x80,0xc7,0x15,0x0a,0x74);
DEFINE_GUID(GUID_Buffer_EnvReverb,            0x186cc542,0xdb29,0x11d3,0x9b,0xd1,0x00,0x80,0xc7,0x15,0x0a,0x74);
DEFINE_GUID(GUID_Buffer_Stereo,               0x186cc545,0xdb29,0x11d3,0x9b,0xd1,0x00,0x80,0xc7,0x15,0x0a,0x74);
DEFINE_GUID(GUID_Buffer_3D_Dry,               0x186cc546,0xdb29,0x11d3,0x9b,0xd1,0x00,0x80,0xc7,0x15,0x0a,0x74);
DEFINE_GUID(GUID_Buffer_Mono,                 0x186cc547,0xdb29,0x11d3,0x9b,0xd1,0x00,0x80,0xc7,0x15,0x0a,0x74);


/*****************************************************************************
 * Typedef definitions
 */
typedef WORD    TRANSITION_TYPE, *LPTRANSITION_TYPE;
/*
 * typedef __int64 REFERENCE_TIME,  *LPREFERENCE_TIME;
 * typedef LONG    MUSIC_TIME,      *LPMUSIC_TIME;
 */


/*****************************************************************************
 * Flags
 */
#define DMUS_APATH_SHARED_STEREOPLUSREVERB 0x1
#define DMUS_APATH_DYNAMIC_3D              0x6
#define DMUS_APATH_DYNAMIC_MONO            0x7
#define DMUS_APATH_DYNAMIC_STEREO          0x8

#define DMUS_AUDIOF_3D          0x01
#define DMUS_AUDIOF_ENVIRON     0x02
#define DMUS_AUDIOF_EAX         0x04
#define DMUS_AUDIOF_DMOS        0x08
#define DMUS_AUDIOF_STREAMING   0x10
#define DMUS_AUDIOF_BUFFERS     0x20
#define DMUS_AUDIOF_ALL         0x3F

#define DMUS_AUDIOPARAMS_FEATURES     0x1
#define DMUS_AUDIOPARAMS_VOICES       0x2
#define DMUS_AUDIOPARAMS_SAMPLERATE   0x4
#define DMUS_AUDIOPARAMS_DEFAULTSYNTH 0x8

#define DMUS_CURVET_PBCURVE   0x03
#define DMUS_CURVET_CCCURVE   0x04
#define DMUS_CURVET_MATCURVE  0x05
#define DMUS_CURVET_PATCURVE  0x06
#define DMUS_CURVET_RPNCURVE  0x07
#define DMUS_CURVET_NRPNCURVE 0x08

#define DMUS_MASTERTEMPO_MAX 100.0f
#define DMUS_MASTERTEMPO_MIN 0.01f

#define DMUS_MAX_NAME     0x40
#define DMUS_MAX_CATEGORY 0x40
#define DMUS_MAX_FILENAME MAX_PATH

#define DMUS_MAXSUBCHORD 0x8

#define DMUS_NOTIFICATION_SEGSTART       0x0
#define DMUS_NOTIFICATION_SEGEND         0x1
#define DMUS_NOTIFICATION_SEGALMOSTEND   0x2
#define DMUS_NOTIFICATION_SEGLOOP        0x3
#define DMUS_NOTIFICATION_SEGABORT       0x4
#define DMUS_NOTIFICATION_MUSICSTARTED   0x0
#define DMUS_NOTIFICATION_MUSICSTOPPED   0x1
#define DMUS_NOTIFICATION_MUSICALMOSTEND 0x2
#define DMUS_NOTIFICATION_MEASUREBEAT    0x0
#define DMUS_NOTIFICATION_CHORD          0x0
#define DMUS_NOTIFICATION_GROOVE         0x0
#define DMUS_NOTIFICATION_EMBELLISHMENT  0x1
#define DMUS_NOTIFICATION_RECOMPOSE      0x0

#define DMUS_OBJ_OBJECT   0x001
#define DMUS_OBJ_CLASS    0x002
#define DMUS_OBJ_NAME     0x004
#define DMUS_OBJ_CATEGORY 0x008
#define DMUS_OBJ_FILENAME 0x010
#define DMUS_OBJ_FULLPATH 0x020
#define DMUS_OBJ_URL      0x040
#define DMUS_OBJ_VERSION  0x080
#define DMUS_OBJ_DATE     0x100
#define DMUS_OBJ_LOADED   0x200
#define DMUS_OBJ_MEMORY   0x400
#define DMUS_OBJ_STREAM   0x800

#define DMUS_PATH_SEGMENT           0x1000
#define DMUS_PATH_SEGMENT_TRACK     0x1100
#define DMUS_PATH_SEGMENT_GRAPH     0x1200
#define DMUS_PATH_SEGMENT_TOOL      0x1300
#define DMUS_PATH_AUDIOPATH         0x2000
#define DMUS_PATH_AUDIOPATH_GRAPH   0x2200
#define DMUS_PATH_AUDIOPATH_TOOL    0x2300
#define DMUS_PATH_PERFORMANCE       0x3000
#define DMUS_PATH_PERFORMANCE_GRAPH 0x3200
#define DMUS_PATH_PERFORMANCE_TOOL  0x3300
#define DMUS_PATH_PORT              0x4000
#define DMUS_PATH_BUFFER            0x6000
#define DMUS_PATH_BUFFER_DMO        0x6100
#define DMUS_PATH_MIXIN_BUFFER      0x7000
#define DMUS_PATH_MIXIN_BUFFER_DMO  0x7100
#define DMUS_PATH_PRIMARY_BUFFER    0x8000

#define DMUS_PCHANNEL_BROADCAST_PERFORMANCE	0xFFFFFFFF
#define DMUS_PCHANNEL_BROADCAST_AUDIOPATH   0xFFFFFFFE
#define DMUS_PCHANNEL_BROADCAST_SEGMENT	    0xFFFFFFFD
#define DMUS_PCHANNEL_BROADCAST_GROUPS  	0xFFFFFFFC
#define DMUS_PCHANNEL_ALL                   0xFFFFFFFB 

#define DMUS_PLAYMODE_FIXED             0x0  
#define DMUS_PLAYMODE_FIXEDTOKEY        DMUS_PLAYMODE_KEY_ROOT
#define DMUS_PLAYMODE_FIXEDTOCHORD      DMUS_PLAYMODE_CHORD_ROOT
#define DMUS_PLAYMODE_PEDALPOINT        (DMUS_PLAYMODE_KEY_ROOT | DMUS_PLAYMODE_SCALE_INTERVALS)
#define DMUS_PLAYMODE_MELODIC           (DMUS_PLAYMODE_CHORD_ROOT | DMUS_PLAYMODE_SCALE_INTERVALS)
#define DMUS_PLAYMODE_NORMALCHORD       (DMUS_PLAYMODE_CHORD_ROOT | DMUS_PLAYMODE_CHORD_INTERVALS)
#define DMUS_PLAYMODE_ALWAYSPLAY        (DMUS_PLAYMODE_MELODIC | DMUS_PLAYMODE_NORMALCHORD)
#define DMUS_PLAYMODE_PEDALPOINTCHORD   (DMUS_PLAYMODE_KEY_ROOT | DMUS_PLAYMODE_CHORD_INTERVALS)
#define DMUS_PLAYMODE_PEDALPOINTALWAYS  (DMUS_PLAYMODE_PEDALPOINT | DMUS_PLAYMODE_PEDALPOINTCHORD)
#define DMUS_PLAYMODE_PURPLEIZED        DMUS_PLAYMODE_ALWAYSPLAY
#define DMUS_PLAYMODE_SCALE_ROOT        DMUS_PLAYMODE_KEY_ROOT
#define DMUS_PLAYMODE_FIXEDTOSCALE      DMUS_PLAYMODE_FIXEDTOKEY

#define DMUS_PPQ 768

#define DMUS_SEG_REPEAT_INFINITE 0xFFFFFFFF
#define DMUS_SEG_ALLTRACKS       0x80000000
#define DMUS_SEG_ANYTRACK        0x80000000

#define DMUS_TEMPO_MAX 1000
#define DMUS_TEMPO_MIN 1

#define DMUS_TRACKCONFIG_OVERRIDE_ALL          0x00001
#define DMUS_TRACKCONFIG_OVERRIDE_PRIMARY      0x00002
#define DMUS_TRACKCONFIG_FALLBACK              0x00004
#define DMUS_TRACKCONFIG_CONTROL_ENABLED       0x00008
#define DMUS_TRACKCONFIG_PLAY_ENABLED          0x00010
#define DMUS_TRACKCONFIG_NOTIFICATION_ENABLED  0x00020
#define DMUS_TRACKCONFIG_PLAY_CLOCKTIME        0x00040
#define DMUS_TRACKCONFIG_PLAY_COMPOSE 	       0x00080
#define DMUS_TRACKCONFIG_LOOP_COMPOSE          0x00100
#define DMUS_TRACKCONFIG_COMPOSING             0x00200
#define DMUS_TRACKCONFIG_TRANS1_FROMSEGSTART   0x00400
#define DMUS_TRACKCONFIG_TRANS1_FROMSEGCURRENT 0x00800
#define DMUS_TRACKCONFIG_TRANS1_TOSEGSTART     0x01000
#define DMUS_TRACKCONFIG_CONTROL_PLAY          0x10000
#define DMUS_TRACKCONFIG_CONTROL_NOTIFICATION  0x20000
#define DMUS_TRACKCONFIG_DEFAULT               (DMUS_TRACKCONFIG_CONTROL_ENABLED | DMUS_TRACKCONFIG_PLAY_ENABLED | DMUS_TRACKCONFIG_NOTIFICATION_ENABLED)

#define DMUS_WAVEF_OFF          0x01
#define DMUS_WAVEF_STREAMING    0x02
#define DMUS_WAVEF_NOINVALIDATE 0x04
#define DMUS_WAVEF_NOPREROLL    0x08
#define DMUS_WAVEF_IGNORELOOPS  0x20

#define DMUSB_LOADED  0x1
#define DMUSB_DEFAULT 0x2

#define MT_MIN 0x80000000
#define MT_MAX 0x7FFFFFFF


/*****************************************************************************
 * Definitions
 */
#define DMUS_PMSG_PART \
	DWORD              dwSize; \
	REFERENCE_TIME     rtTime; \
	MUSIC_TIME         mtTime; \
	DWORD              dwFlags; \
	DWORD              dwPChannel; \
	DWORD              dwVirtualTrackID; \
	IDirectMusicTool*  pTool; \
	struct IDirectMusicGraph* pGraph; \
	DWORD              dwType; \
	DWORD              dwVoiceID; \
	DWORD              dwGroupID; \
	IUnknown*          punkUser;


/*****************************************************************************
 * Enumerations
 */

/* actual enumerations */
typedef enum enumDMUS_STYLET_TYPES {
	DMUS_STYLET_PATTERN = 0x0,
	DMUS_STYLET_MOTIF   = 0x1,
} DMUS_STYLET_TYPES;

typedef enum enumDMUS_COMMANDT_TYPES {
	DMUS_COMMANDT_GROOVE      = 0x0,
	DMUS_COMMANDT_FILL        = 0x1,
	DMUS_COMMANDT_INTRO       = 0x2,
	DMUS_COMMANDT_BREAK       = 0x3,
	DMUS_COMMANDT_END         = 0x4,
	DMUS_COMMANDT_ENDANDINTRO = 0x5
} DMUS_COMMANDT_TYPES;

typedef enum enumDMUS_SHAPET_TYPES {
	DMUS_SHAPET_FALLING  = 0x0,
	DMUS_SHAPET_LEVEL    = 0x1,
	DMUS_SHAPET_LOOPABLE = 0x2,
	DMUS_SHAPET_LOUD     = 0x3,
	DMUS_SHAPET_QUIET    = 0x4,
	DMUS_SHAPET_PEAKING  = 0x5,
	DMUS_SHAPET_RANDOM   = 0x6,
	DMUS_SHAPET_RISING   = 0x7,
	DMUS_SHAPET_SONG     = 0x8
} DMUS_SHAPET_TYPES;

typedef enum enumDMUS_COMPOSEF_FLAGS {
	DMUS_COMPOSEF_NONE                = 0x000000,
	DMUS_COMPOSEF_ALIGN               = 0x000001,
	DMUS_COMPOSEF_OVERLAP             = 0x000002,
	DMUS_COMPOSEF_IMMEDIATE           = 0x000004,
	DMUS_COMPOSEF_GRID                = 0x000008,
	DMUS_COMPOSEF_BEAT                = 0x000010,
	DMUS_COMPOSEF_MEASURE             = 0x000020,
	DMUS_COMPOSEF_AFTERPREPARETIME    = 0x000040,
	DMUS_COMPOSEF_VALID_START_BEAT    = 0x000080,
	DMUS_COMPOSEF_VALID_START_GRID    = 0x000100,
	DMUS_COMPOSEF_VALID_START_TICK    = 0x000200,
	DMUS_COMPOSEF_SEGMENTEND          = 0x000400,
	DMUS_COMPOSEF_MARKER              = 0x000800,
	DMUS_COMPOSEF_MODULATE            = 0x001000,
	DMUS_COMPOSEF_LONG                = 0x002000,
	DMUS_COMPOSEF_ENTIRE_TRANSITION   = 0x004000,
	DMUS_COMPOSEF_1BAR_TRANSITION     = 0x008000,
	DMUS_COMPOSEF_ENTIRE_ADDITION     = 0x010000,
	DMUS_COMPOSEF_1BAR_ADDITION       = 0x020000,
	DMUS_COMPOSEF_VALID_START_MEASURE = 0x040000,
	DMUS_COMPOSEF_DEFAULT             = 0x080000,
	DMUS_COMPOSEF_NOINVALIDATE        = 0x100000,
	DMUS_COMPOSEF_USE_AUDIOPATH       = 0x200000,
	DMUS_COMPOSEF_INVALIDATE_PRI      = 0x400000
} DMUS_COMPOSEF_FLAGS;

typedef enum enumDMUS_PMSGF_FLAGS {
	DMUS_PMSGF_REFTIME        = 1,
	DMUS_PMSGF_MUSICTIME      = 2,
	DMUS_PMSGF_TOOL_IMMEDIATE = 4,
	DMUS_PMSGF_TOOL_QUEUE     = 8,
	DMUS_PMSGF_TOOL_ATTIME    = 0x10,
	DMUS_PMSGF_TOOL_FLUSH     = 0x20,
	DMUS_PMSGF_LOCKTOREFTIME  = 0x40,
	DMUS_PMSGF_DX8            = 0x80
} DMUS_PMSGF_FLAGS;

typedef enum enumDMUS_PMSGT_TYPES {
	DMUS_PMSGT_MIDI             = 0x00,
	DMUS_PMSGT_NOTE             = 0x01,
	DMUS_PMSGT_SYSEX            = 0x02,
	DMUS_PMSGT_NOTIFICATION     = 0x03,
	DMUS_PMSGT_TEMPO            = 0x04,
	DMUS_PMSGT_CURVE            = 0x05,
	DMUS_PMSGT_TIMESIG          = 0x06,
	DMUS_PMSGT_PATCH            = 0x07,
	DMUS_PMSGT_TRANSPOSE        = 0x08,
	DMUS_PMSGT_CHANNEL_PRIORITY = 0x09,
	DMUS_PMSGT_STOP             = 0x0A,
	DMUS_PMSGT_DIRTY            = 0x0B,
	DMUS_PMSGT_WAVE             = 0x0C,
	DMUS_PMSGT_LYRIC            = 0x0D,
	DMUS_PMSGT_SCRIPTLYRIC      = 0x0E,
	DMUS_PMSGT_USER             = 0xFF
} DMUS_PMSGT_TYPES;

typedef enum enumDMUS_SEGF_FLAGS {
	DMUS_SEGF_REFTIME             = 0x000040,   
	DMUS_SEGF_SECONDARY           = 0x000080,
	DMUS_SEGF_QUEUE               = 0x000100,
	DMUS_SEGF_CONTROL             = 0x000200,
	DMUS_SEGF_AFTERPREPARETIME    = 0x000400,
	DMUS_SEGF_GRID                = 0x000800,
	DMUS_SEGF_BEAT                = 0x001000,
	DMUS_SEGF_MEASURE             = 0x002000,
	DMUS_SEGF_DEFAULT             = 0x004000,
	DMUS_SEGF_NOINVALIDATE        = 0x008000,
	DMUS_SEGF_ALIGN               = 0x0010000,
	DMUS_SEGF_VALID_START_BEAT    = 0x0020000,
	DMUS_SEGF_VALID_START_GRID    = 0x0040000,
	DMUS_SEGF_VALID_START_TICK    = 0x0080000,
	DMUS_SEGF_AUTOTRANSITION      = 0x0100000,
	DMUS_SEGF_AFTERQUEUETIME      = 0x0200000,
	DMUS_SEGF_AFTERLATENCYTIME    = 0x0400000,
	DMUS_SEGF_SEGMENTEND          = 0x0800000,
	DMUS_SEGF_MARKER              = 0x01000000,
	DMUS_SEGF_TIMESIG_ALWAYS      = 0x02000000,
	DMUS_SEGF_USE_AUDIOPATH       = 0x04000000,
	DMUS_SEGF_VALID_START_MEASURE = 0x08000000,
	DMUS_SEGF_INVALIDATE_PRI      = 0x10000000
} DMUS_SEGF_FLAGS;

typedef enum enumDMUS_TIME_RESOLVE_FLAGS {
	DMUS_TIME_RESOLVE_AFTERPREPARETIME = DMUS_SEGF_AFTERPREPARETIME,
	DMUS_TIME_RESOLVE_AFTERQUEUETIME   = DMUS_SEGF_AFTERQUEUETIME,
	DMUS_TIME_RESOLVE_AFTERLATENCYTIME = DMUS_SEGF_AFTERLATENCYTIME,
	DMUS_TIME_RESOLVE_GRID             = DMUS_SEGF_GRID,
	DMUS_TIME_RESOLVE_BEAT             = DMUS_SEGF_BEAT,
	DMUS_TIME_RESOLVE_MEASURE          = DMUS_SEGF_MEASURE,
	DMUS_TIME_RESOLVE_MARKER           = DMUS_SEGF_MARKER,
	DMUS_TIME_RESOLVE_SEGMENTEND       = DMUS_SEGF_SEGMENTEND,
} DMUS_TIME_RESOLVE_FLAGS;

typedef enum enumDMUS_CHORDKEYF_FLAGS {
	DMUS_CHORDKEYF_SILENT = 0x1,
} DMUS_CHORDKEYF_FLAGS;

typedef enum enumDMUS_NOTEF_FLAGS {
	DMUS_NOTEF_NOTEON               = 0x01,
	/* DX8 */
	DMUS_NOTEF_NOINVALIDATE         = 0x02,
	DMUS_NOTEF_NOINVALIDATE_INSCALE = 0x04,
	DMUS_NOTEF_NOINVALIDATE_INCHORD = 0x08,
	DMUS_NOTEF_REGENERATE           = 0x10,
} DMUS_NOTEF_FLAGS;

typedef enum enumDMUS_PLAYMODE_FLAGS {
	DMUS_PLAYMODE_KEY_ROOT        = 0x01,
	DMUS_PLAYMODE_CHORD_ROOT      = 0x02,
	DMUS_PLAYMODE_SCALE_INTERVALS = 0x04,
	DMUS_PLAYMODE_CHORD_INTERVALS = 0x08,
	DMUS_PLAYMODE_NONE            = 0x10,
} DMUS_PLAYMODE_FLAGS;

typedef enum enumDMUS_CURVE_FLAGS {
	DMUS_CURVE_RESET              = 0x1,
	DMUS_CURVE_START_FROM_CURRENT = 0x2
} DMUS_CURVE_FLAGS;

enum { 
	DMUS_CURVES_LINEAR  = 0x0,
	DMUS_CURVES_INSTANT = 0x1,
	DMUS_CURVES_EXP     = 0x2,
	DMUS_CURVES_LOG     = 0x3,
	DMUS_CURVES_SINE    = 0x4
};


/*****************************************************************************
 * Structures
 */
/* typedef definitions */
/*typedef struct _DMUS_PMSG                  DMUS_PMSG,                  *LPDMUS_PMSG; */
typedef struct _DMUS_AUDIOPARAMS           DMUS_AUDIOPARAMS,           *LPDMUS_AUDIOPARAMS;
typedef struct _DMUS_SUBCHORD              DMUS_SUBCHORD,              *LPDMUS_SUBCHORD;
typedef struct _DMUS_CHORD_KEY             DMUS_CHORD_KEY,             *LPDMUS_CHORD_KEY;
typedef struct _DMUS_NOTE_PMSG             DMUS_NOTE_PMSG,             *LPDMUS_NOTE_PMSG;
typedef struct _DMUS_MIDI_PMSG             DMUS_MIDI_PMSG,             *LPDMUS_MIDI_PMSG;
typedef struct _DMUS_PATCH_PMSG            DMUS_PATCH_PMSG,            *LPDMUS_PATCH_PMSG;
typedef struct _DMUS_TRANSPOSE_PMSG        DMUS_TRANSPOSE_PMSG,        *LPDMUS_TRANSPOSE_PMSG;
typedef struct _DMUS_CHANNEL_PRIORITY_PMSG DMUS_CHANNEL_PRIORITY_PMSG, *LPDMUS_CHANNEL_PRIORITY_PMSG;
typedef struct _DMUS_TEMPO_PMSG            DMUS_TEMPO_PMSG,            *LPDMUS_TEMPO_PMSG;
typedef struct _DMUS_SYSEX_PMSG            DMUS_SYSEX_PMSG,            *LPDMUS_SYSEX_PMSG;
typedef struct _DMUS_CURVE_PMSG            DMUS_CURVE_PMSG,            *LPDMUS_CURVE_PMSG;
typedef struct _DMUS_TIMESIG_PMSG          DMUS_TIMESIG_PMSG,          *LPDMUS_TIMESIG_PMSG;
typedef struct _DMUS_NOTIFICATION_PMSG     DMUS_NOTIFICATION_PMSG,     *LPDMUS_NOTIFICATION_PMSG;
typedef struct _DMUS_WAVE_PMSG             DMUS_WAVE_PMSG,             *LPDMUS_WAVE_PMSG;
typedef struct _DMUS_LYRIC_PMSG            DMUS_LYRIC_PMSG,            *LPDMUS_LYRIC_PMSG;
typedef struct _DMUS_VERSION               DMUS_VERSION,               *LPDMUS_VERSION;
typedef struct _DMUS_TIMESIGNATURE         DMUS_TIMESIGNATURE,         *LPDMUS_TIMESIGNATURE;
typedef struct _DMUS_VALID_START_PARAM     DMUS_VALID_START_PARAM,     *LPDMUS_VALID_START_PARAM;
typedef struct _DMUS_PLAY_MARKER_PARAM     DMUS_PLAY_MARKER_PARAM,     *LPDMUS_PLAY_MARKER_PARAM;
typedef struct _DMUS_OBJECTDESC            DMUS_OBJECTDESC,            *LPDMUS_OBJECTDESC;
typedef struct _DMUS_SCRIPT_ERRORINFO      DMUS_SCRIPT_ERRORINFO,      *LPDMUS_SCRIPT_ERRORINFO;
typedef struct _DMUS_COMMAND_PARAM         DMUS_COMMAND_PARAM,         *LPDMUS_COMMAND_PARAM;
typedef struct _DMUS_COMMAND_PARAM_2       DMUS_COMMAND_PARAM_2,       *LPDMUS_COMMAND_PARAM_2;
typedef struct _DMUS_BAND_PARAM            DMUS_BAND_PARAM,            *LPDMUS_BAND_PARAM;
typedef struct _DMUS_VARIATIONS_PARAM      DMUS_VARIATIONS_PARAM,      *LPDMUS_VARIATIONS_PARAM;

/* actual structures */
struct _DMUS_PMSG {
    DMUS_PMSG_PART
};

struct _DMUS_AUDIOPARAMS {
	DWORD dwSize;
	WINBOOL  fInitNow;
	DWORD dwValidData;
	DWORD dwFeatures;
	DWORD dwVoices;
	DWORD dwSampleRate;
	CLSID clsidDefaultSynth;
};

struct _DMUS_SUBCHORD {
	DWORD dwChordPattern;
	DWORD dwScalePattern;
	DWORD dwInversionPoints;
	DWORD dwLevels;
	BYTE  bChordRoot;
	BYTE  bScaleRoot;
};

struct _DMUS_CHORD_KEY {
	WCHAR         wszName[16];
	WORD          wMeasure;
	BYTE          bBeat;
	BYTE          bSubChordCount;
	DMUS_SUBCHORD SubChordList[DMUS_MAXSUBCHORD];
	DWORD         dwScale;
	BYTE          bKey;
	BYTE          bFlags;
};

struct _DMUS_NOTE_PMSG {
	DMUS_PMSG_PART
	MUSIC_TIME mtDuration;
	WORD       wMusicValue;
	WORD       wMeasure;
	short      nOffset;
	BYTE       bBeat;
	BYTE       bGrid;
	BYTE       bVelocity;
	BYTE       bFlags;
	BYTE       bTimeRange;
	BYTE       bDurRange;
	BYTE       bVelRange;
	BYTE       bPlayModeFlags;
	BYTE       bSubChordLevel;
	BYTE       bMidiValue;
	char       cTranspose;
};

struct _DMUS_MIDI_PMSG {
	DMUS_PMSG_PART
	BYTE bStatus;
	BYTE bByte1;
	BYTE bByte2;
	BYTE bPad[1];
};

struct _DMUS_PATCH_PMSG {
	DMUS_PMSG_PART
	BYTE byInstrument;
	BYTE byMSB;
	BYTE byLSB;
	BYTE byPad[1];
};

struct _DMUS_TRANSPOSE_PMSG {
	DMUS_PMSG_PART
	short nTranspose;
	/* DX8 */
	WORD  wMergeIndex;
};

struct _DMUS_CHANNEL_PRIORITY_PMSG {
	DMUS_PMSG_PART
	DWORD dwChannelPriority;
};

struct _DMUS_TEMPO_PMSG {
	DMUS_PMSG_PART
	double  dblTempo;
};

struct _DMUS_SYSEX_PMSG {
	DMUS_PMSG_PART
	DWORD dwLen;
	BYTE  abData[1];
};

struct _DMUS_CURVE_PMSG {
	DMUS_PMSG_PART
	MUSIC_TIME mtDuration;
	MUSIC_TIME mtOriginalStart;
	MUSIC_TIME mtResetDuration;
	short      nStartValue;
	short      nEndValue;
	short      nResetValue;
	WORD       wMeasure;
	short      nOffset;
	BYTE       bBeat;
	BYTE       bGrid;
	BYTE       bType;
	BYTE       bCurveShape;
	BYTE       bCCData;
	BYTE       bFlags;
	/* DX8 */
	WORD       wParamType;
	WORD       wMergeIndex;
};

struct _DMUS_TIMESIG_PMSG {
	DMUS_PMSG_PART
	BYTE bBeatsPerMeasure;
	BYTE bBeat;
	WORD wGridsPerBeat;
};

struct _DMUS_NOTIFICATION_PMSG {
	DMUS_PMSG_PART
	GUID  guidNotificationType;
	DWORD dwNotificationOption;
	DWORD dwField1;
	DWORD dwField2;
};

struct _DMUS_WAVE_PMSG {
	DMUS_PMSG_PART    
	REFERENCE_TIME rtStartOffset;
	REFERENCE_TIME rtDuration;
	LONG           lOffset;
	LONG           lVolume;
	LONG           lPitch;
	BYTE           bFlags;
};

struct _DMUS_LYRIC_PMSG {
	DMUS_PMSG_PART    
	WCHAR wszString[1];
};

struct _DMUS_VERSION {
	DWORD dwVersionMS;
	DWORD dwVersionLS;
};

struct _DMUS_TIMESIGNATURE {
	MUSIC_TIME mtTime;
	BYTE       bBeatsPerMeasure;
	BYTE       bBeat;
	WORD       wGridsPerBeat;
};

struct _DMUS_VALID_START_PARAM {
	MUSIC_TIME mtTime;
};

struct _DMUS_PLAY_MARKER_PARAM {
	MUSIC_TIME mtTime;
};

struct _DMUS_OBJECTDESC {
	DWORD        dwSize;
	DWORD        dwValidData;
	GUID         guidObject;
	GUID         guidClass;
	FILETIME     ftDate;
	DMUS_VERSION vVersion;
	WCHAR        wszName[DMUS_MAX_NAME];
	WCHAR        wszCategory[DMUS_MAX_CATEGORY];
	WCHAR        wszFileName[DMUS_MAX_FILENAME];
	LONGLONG     llMemLength;
	LPBYTE       pbMemData;
	IStream*     pStream;
};

struct _DMUS_SCRIPT_ERRORINFO {
	DWORD   dwSize;
	HRESULT hr;
	ULONG   ulLineNumber;
	LONG    ichCharPosition;
	WCHAR   wszSourceFile[DMUS_MAX_FILENAME];
	WCHAR   wszSourceComponent[DMUS_MAX_FILENAME];
	WCHAR   wszDescription[DMUS_MAX_FILENAME];
	WCHAR   wszSourceLineText[DMUS_MAX_FILENAME];
};

struct _DMUS_COMMAND_PARAM {
	BYTE bCommand;
	BYTE bGrooveLevel;
	BYTE bGrooveRange;
	BYTE bRepeatMode;
};

struct _DMUS_COMMAND_PARAM_2 {
	MUSIC_TIME mtTime;
	BYTE       bCommand;
	BYTE       bGrooveLevel;
	BYTE       bGrooveRange;
	BYTE       bRepeatMode;
};

struct _DMUS_BAND_PARAM {
	MUSIC_TIME       mtTimePhysical;
	struct IDirectMusicBand *pBand;
};

struct _DMUS_VARIATIONS_PARAM {
	DWORD  dwPChannelsUsed;
	DWORD* padwPChannels;
	DWORD* padwVariations;
};


/*****************************************************************************
 * IDirectMusicBand interface
 */
#define INTERFACE IDirectMusicBand
DECLARE_INTERFACE_(IDirectMusicBand,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicBand methods ***/
    STDMETHOD(CreateSegment)(THIS_ struct IDirectMusicSegment **ppSegment) PURE;
    STDMETHOD(Download)(THIS_ struct IDirectMusicPerformance *pPerformance) PURE;
    STDMETHOD(Unload)(THIS_ struct IDirectMusicPerformance *pPerformance) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicBand_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicBand_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectMusicBand_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectMusicBand methods ***/
#define IDirectMusicBand_CreateSegment(p,a)    (p)->lpVtbl->CreateSegment(p,a)
#define IDirectMusicBand_Download(p,a)         (p)->lpVtbl->Download(p,a)
#define IDirectMusicBand_Unload(p,a)           (p)->lpVtbl->Unload(p,a)
#endif


/*****************************************************************************
 * IDirectMusicObject interface
 */
#define INTERFACE IDirectMusicObject
DECLARE_INTERFACE_(IDirectMusicObject,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicObject methods ***/
    STDMETHOD(GetDescriptor)(THIS_ LPDMUS_OBJECTDESC pDesc) PURE;
    STDMETHOD(SetDescriptor)(THIS_ LPDMUS_OBJECTDESC pDesc) PURE;
    STDMETHOD(ParseDescriptor)(THIS_ LPSTREAM pStream, LPDMUS_OBJECTDESC pDesc) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicObject_QueryInterface(p,a,b)  (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicObject_AddRef(p)              (p)->lpVtbl->AddRef(p)
#define IDirectMusicObject_Release(p)             (p)->lpVtbl->Release(p)
/*** IDirectMusicObject methods ***/
#define IDirectMusicObject_GetDescriptor(p,a)     (p)->lpVtbl->GetDescriptor(p,a)
#define IDirectMusicObject_SetDescriptor(p,a)     (p)->lpVtbl->SetDescriptor(p,a)
#define IDirectMusicObject_ParseDescriptor(p,a,b) (p)->lpVtbl->ParseDescriptor(p,a,b)
#endif


/*****************************************************************************
 * IDirectMusicLoader interface
 */
#define INTERFACE IDirectMusicLoader
DECLARE_INTERFACE_(IDirectMusicLoader,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicLoader methods ***/
    STDMETHOD(GetObject)(THIS_ LPDMUS_OBJECTDESC pDesc, REFIID riid, LPVOID *ppv) PURE;
    STDMETHOD(SetObject)(THIS_ LPDMUS_OBJECTDESC pDesc) PURE;
    STDMETHOD(SetSearchDirectory)(THIS_ REFGUID rguidClass, WCHAR *pwzPath, WINBOOL fClear) PURE;
    STDMETHOD(ScanDirectory)(THIS_ REFGUID rguidClass, WCHAR *pwzFileExtension, WCHAR *pwzScanFileName) PURE;
    STDMETHOD(CacheObject)(THIS_ IDirectMusicObject *pObject) PURE;
    STDMETHOD(ReleaseObject)(THIS_ IDirectMusicObject *pObject) PURE;
    STDMETHOD(ClearCache)(THIS_ REFGUID rguidClass) PURE;
    STDMETHOD(EnableCache)(THIS_ REFGUID rguidClass, WINBOOL fEnable) PURE;
    STDMETHOD(EnumObject)(THIS_ REFGUID rguidClass, DWORD dwIndex, LPDMUS_OBJECTDESC pDesc) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicLoader_QueryInterface(p,a,b)       (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicLoader_AddRef(p)                   (p)->lpVtbl->AddRef(p)
#define IDirectMusicLoader_Release(p)                  (p)->lpVtbl->Release(p)
/*** IDirectMusicLoader methods ***/
#define IDirectMusicLoader_GetObject(p,a,b,c)          (p)->lpVtbl->GetObject(p,a,b,c)
#define IDirectMusicLoader_SetObject(p,a)              (p)->lpVtbl->SetObject(p,a)
#define IDirectMusicLoader_SetSearchDirectory(p,a,b,c) (p)->lpVtbl->SetSearchDirectory(p,a,b,c)
#define IDirectMusicLoader_ScanDirectory(p,a,b,c)      (p)->lpVtbl->ScanDirectory(p,a,b,c)
#define IDirectMusicLoader_CacheObject(p,a)            (p)->lpVtbl->CacheObject(p,a)
#define IDirectMusicLoader_ReleaseObject(p,a)          (p)->lpVtbl->ReleaseObject(p,a)
#define IDirectMusicLoader_ClearCache(p,a)             (p)->lpVtbl->ClearCache(p,a)
#define IDirectMusicLoader_EnableCache(p,a,b)          (p)->lpVtbl->EnableCache(p,a,b)
#define IDirectMusicLoader_EnumObject(p,a,b,c)         (p)->lpVtbl->EnumObject(p,a,b,c)
#endif


/*****************************************************************************
 * IDirectMusicLoader8 interface
 */
#define INTERFACE IDirectMusicLoader8
DECLARE_INTERFACE_(IDirectMusicLoader8,IDirectMusicLoader)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicLoader methods ***/
    STDMETHOD(GetObject)(THIS_ LPDMUS_OBJECTDESC pDesc, REFIID riid, LPVOID *ppv) PURE;
    STDMETHOD(SetObject)(THIS_ LPDMUS_OBJECTDESC pDesc) PURE;
    STDMETHOD(SetSearchDirectory)(THIS_ REFGUID rguidClass, WCHAR *pwzPath, WINBOOL fClear) PURE;
    STDMETHOD(ScanDirectory)(THIS_ REFGUID rguidClass, WCHAR *pwzFileExtension, WCHAR *pwzScanFileName) PURE;
    STDMETHOD(CacheObject)(THIS_ IDirectMusicObject *pObject) PURE;
    STDMETHOD(ReleaseObject)(THIS_ IDirectMusicObject *pObject) PURE;
    STDMETHOD(ClearCache)(THIS_ REFGUID rguidClass) PURE;
    STDMETHOD(EnableCache)(THIS_ REFGUID rguidClass, WINBOOL fEnable) PURE;
    STDMETHOD(EnumObject)(THIS_ REFGUID rguidClass, DWORD dwIndex, LPDMUS_OBJECTDESC pDesc) PURE;
    /*** IDirectMusicLoader8 methods ***/
    STDMETHOD_(void,CollectGarbage)(THIS) PURE;
    STDMETHOD(ReleaseObjectByUnknown)(THIS_ IUnknown *pObject) PURE;
    STDMETHOD(LoadObjectFromFile)(THIS_ REFGUID rguidClassID, REFIID iidInterfaceID, WCHAR *pwzFilePath, void **ppObject) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicLoader8_QueryInterface(p,a,b)         (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicLoader8_AddRef(p)                     (p)->lpVtbl->AddRef(p)
#define IDirectMusicLoader8_Release(p)                    (p)->lpVtbl->Release(p)
/*** IDirectMusicLoader methods ***/
#define IDirectMusicLoader8_GetObject(p,a,b,c)            (p)->lpVtbl->GetObject(p,a,b,c)
#define IDirectMusicLoader8_SetObject(p,a)                (p)->lpVtbl->SetObject(p,a)
#define IDirectMusicLoader8_SetSearchDirectory(p,a,b,c)   (p)->lpVtbl->SetSearchDirectory(p,a,b,c)
#define IDirectMusicLoader8_ScanDirectory(p,a,b,c)        (p)->lpVtbl->ScanDirectory(p,a,b,c)
#define IDirectMusicLoader8_CacheObject(p,a)              (p)->lpVtbl->CacheObject(p,a)
#define IDirectMusicLoader8_ReleaseObject(p,a)            (p)->lpVtbl->ReleaseObject(p,a)
#define IDirectMusicLoader8_ClearCache(p,a)               (p)->lpVtbl->ClearCache(p,a)
#define IDirectMusicLoader8_EnableCache(p,a,b)            (p)->lpVtbl->EnableCache(p,a,b)
#define IDirectMusicLoader8_EnumObject(p,a,b,c)           (p)->lpVtbl->EnumObject(p,a,b,c)
/*** IDirectMusicLoader8 methods ***/
#define IDirectMusicLoader8_CollectGarbage(p)             (p)->lpVtbl->CollectGarbage(p)
#define IDirectMusicLoader8_ReleaseObjectByUnknown(p,a)   (p)->lpVtbl->ReleaseObjectByUnknown(p,a)
#define IDirectMusicLoader8_LoadObjectFromFile(p,a,b,c,d) (p)->lpVtbl->LoadObjectFromFile(p,a,b,c,d)
#endif


/*****************************************************************************
 * IDirectMusicGetLoader interface
 */
#define INTERFACE IDirectMusicGetLoader
DECLARE_INTERFACE_(IDirectMusicGetLoader,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicGetLoader methods ***/
    STDMETHOD(GetLoader)(THIS_ IDirectMusicLoader **ppLoader) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicGetLoader_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicGetLoader_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectMusicGetLoader_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectMusicGetLoader methods ***/
#define IDirectMusicGetLoader_GetLoader(p,a)        (p)->lpVtbl->GetLoader(p,a)
#endif


/*****************************************************************************
 * IDirectMusicSegment interface
 */
#define INTERFACE IDirectMusicSegment
DECLARE_INTERFACE_(IDirectMusicSegment,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicSegment methods ***/
    STDMETHOD(GetLength)(THIS_ MUSIC_TIME *pmtLength) PURE;
    STDMETHOD(SetLength)(THIS_ MUSIC_TIME mtLength) PURE;
    STDMETHOD(GetRepeats)(THIS_ DWORD *pdwRepeats) PURE;
    STDMETHOD(SetRepeats)(THIS_ DWORD dwRepeats) PURE;
    STDMETHOD(GetDefaultResolution)(THIS_ DWORD *pdwResolution) PURE;
    STDMETHOD(SetDefaultResolution)(THIS_ DWORD dwResolution) PURE;
    STDMETHOD(GetTrack)(THIS_ REFGUID rguidType, DWORD dwGroupBits, DWORD dwIndex, IDirectMusicTrack **ppTrack) PURE;
    STDMETHOD(GetTrackGroup)(THIS_ IDirectMusicTrack *pTrack, DWORD *pdwGroupBits) PURE;
    STDMETHOD(InsertTrack)(THIS_ IDirectMusicTrack *pTrack, DWORD dwGroupBits) PURE;
    STDMETHOD(RemoveTrack)(THIS_ IDirectMusicTrack *pTrack) PURE;
    STDMETHOD(InitPlay)(THIS_ struct IDirectMusicSegmentState **ppSegState, struct IDirectMusicPerformance *pPerformance, DWORD  dwFlags) PURE;
    STDMETHOD(GetGraph)(THIS_ struct IDirectMusicGraph **ppGraph) PURE;
    STDMETHOD(SetGraph)(THIS_ struct IDirectMusicGraph *pGraph) PURE;
    STDMETHOD(AddNotificationType)(THIS_ REFGUID rguidNotificationType) PURE;
    STDMETHOD(RemoveNotificationType)(THIS_ REFGUID rguidNotificationType) PURE;
    STDMETHOD(GetParam)(THIS_ REFGUID rguidType, DWORD dwGroupBits, DWORD dwIndex, MUSIC_TIME mtTime, MUSIC_TIME *pmtNext, void *pParam) PURE;
    STDMETHOD(SetParam)(THIS_ REFGUID rguidType, DWORD dwGroupBits, DWORD dwIndex, MUSIC_TIME mtTime, void *pParam) PURE;
    STDMETHOD(Clone)(THIS_ MUSIC_TIME mtStart, MUSIC_TIME mtEnd, IDirectMusicSegment **ppSegment) PURE;
    STDMETHOD(SetStartPoint)(THIS_ MUSIC_TIME mtStart) PURE;
    STDMETHOD(GetStartPoint)(THIS_ MUSIC_TIME *pmtStart) PURE;
    STDMETHOD(SetLoopPoints)(THIS_ MUSIC_TIME mtStart, MUSIC_TIME mtEnd) PURE;
    STDMETHOD(GetLoopPoints)(THIS_ MUSIC_TIME *pmtStart, MUSIC_TIME *pmtEnd) PURE;
    STDMETHOD(SetPChannelsUsed)(THIS_ DWORD dwNumPChannels, DWORD *paPChannels) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicSegment_QueryInterface(p,a,b)       (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicSegment_AddRef(p)                   (p)->lpVtbl->AddRef(p)
#define IDirectMusicSegment_Release(p)                  (p)->lpVtbl->Release(p)
/*** IDirectMusicSegment methods ***/
#define IDirectMusicSegment_GetLength(p,a)              (p)->lpVtbl->GetLength(p,a)
#define IDirectMusicSegment_SetLength(p,a)              (p)->lpVtbl->SetLength(p,a)
#define IDirectMusicSegment_GetRepeats(p,a)             (p)->lpVtbl->GetRepeats(p,a)
#define IDirectMusicSegment_SetRepeats(p,a)             (p)->lpVtbl->SetRepeats(p,a)
#define IDirectMusicSegment_GetDefaultResolution(p,a)   (p)->lpVtbl->GetDefaultResolution(p,a)
#define IDirectMusicSegment_SetDefaultResolution(p,a)   (p)->lpVtbl->SetDefaultResolution(p,a)
#define IDirectMusicSegment_GetTrack(p,a,b,c,d)         (p)->lpVtbl->GetTrack(p,a,b,c,d)
#define IDirectMusicSegment_GetTrackGroup(p,a,b)        (p)->lpVtbl->GetTrackGroup(p,a,b)
#define IDirectMusicSegment_InsertTrack(p,a,b)          (p)->lpVtbl->InsertTrack(p,a,b)
#define IDirectMusicSegment_RemoveTrack(p,a)            (p)->lpVtbl->RemoveTrack(p,a)
#define IDirectMusicSegment_InitPlay(p,a,b,c)           (p)->lpVtbl->InitPlay(p,a,b,c)
#define IDirectMusicSegment_GetGraph(p,a)               (p)->lpVtbl->GetGraph(p,a)
#define IDirectMusicSegment_SetGraph(p,a)               (p)->lpVtbl->SetGraph(p,a)
#define IDirectMusicSegment_AddNotificationType(p,a)    (p)->lpVtbl->AddNotificationType(p,a)
#define IDirectMusicSegment_RemoveNotificationType(p,a) (p)->lpVtbl->RemoveNotificationType(p,a)
#define IDirectMusicSegment_GetParam(p,a,b,c,d,e,f)     (p)->lpVtbl->GetParam(p,a,b,c,d,e,f)
#define IDirectMusicSegment_SetParam(p,a,b,c,d,e)       (p)->lpVtbl->SetParam(p,a,b,c,d,e)
#define IDirectMusicSegment_Clone(p,a,b,c)              (p)->lpVtbl->Clone(p,a,b,c)
#define IDirectMusicSegment_SetStartPoint(p,a)          (p)->lpVtbl->SetStartPoint(p,a)
#define IDirectMusicSegment_GetStartPoint(p,a)          (p)->lpVtbl->GetStartPoint(p,a)
#define IDirectMusicSegment_SetLoopPoints(p,a,b)        (p)->lpVtbl->SetLoopPoints(p,a,b)
#define IDirectMusicSegment_GetLoopPoints(p,a,b)        (p)->lpVtbl->GetLoopPoints(p,a,b)
#define IDirectMusicSegment_SetPChannelsUsed(p,a,b)     (p)->lpVtbl->SetPChannelsUsed(p,a,b)
#endif


/*****************************************************************************
 * IDirectMusicSegment8 interface
 */
#define INTERFACE IDirectMusicSegment8
DECLARE_INTERFACE_(IDirectMusicSegment8,IDirectMusicSegment)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicSegment methods ***/
    STDMETHOD(GetLength)(THIS_ MUSIC_TIME *pmtLength) PURE;
    STDMETHOD(SetLength)(THIS_ MUSIC_TIME mtLength) PURE;
    STDMETHOD(GetRepeats)(THIS_ DWORD *pdwRepeats) PURE;
    STDMETHOD(SetRepeats)(THIS_ DWORD dwRepeats) PURE;
    STDMETHOD(GetDefaultResolution)(THIS_ DWORD *pdwResolution) PURE;
    STDMETHOD(SetDefaultResolution)(THIS_ DWORD dwResolution) PURE;
    STDMETHOD(GetTrack)(THIS_ REFGUID rguidType, DWORD dwGroupBits, DWORD dwIndex, IDirectMusicTrack **ppTrack) PURE;
    STDMETHOD(GetTrackGroup)(THIS_ IDirectMusicTrack *pTrack, DWORD *pdwGroupBits) PURE;
    STDMETHOD(InsertTrack)(THIS_ IDirectMusicTrack *pTrack, DWORD dwGroupBits) PURE;
    STDMETHOD(RemoveTrack)(THIS_ IDirectMusicTrack *pTrack) PURE;
    STDMETHOD(InitPlay)(THIS_ struct IDirectMusicSegmentState **ppSegState, struct IDirectMusicPerformance *pPerformance, DWORD  dwFlags) PURE;
    STDMETHOD(GetGraph)(THIS_ struct IDirectMusicGraph **ppGraph) PURE;
    STDMETHOD(SetGraph)(THIS_ struct IDirectMusicGraph *pGraph) PURE;
    STDMETHOD(AddNotificationType)(THIS_ REFGUID rguidNotificationType) PURE;
    STDMETHOD(RemoveNotificationType)(THIS_ REFGUID rguidNotificationType) PURE;
    STDMETHOD(GetParam)(THIS_ REFGUID rguidType, DWORD dwGroupBits, DWORD dwIndex, MUSIC_TIME mtTime, MUSIC_TIME *pmtNext, void *pParam) PURE;
    STDMETHOD(SetParam)(THIS_ REFGUID rguidType, DWORD dwGroupBits, DWORD dwIndex, MUSIC_TIME mtTime, void *pParam) PURE;
    STDMETHOD(Clone)(THIS_ MUSIC_TIME mtStart, MUSIC_TIME mtEnd, IDirectMusicSegment **ppSegment) PURE;
    STDMETHOD(SetStartPoint)(THIS_ MUSIC_TIME mtStart) PURE;
    STDMETHOD(GetStartPoint)(THIS_ MUSIC_TIME *pmtStart) PURE;
    STDMETHOD(SetLoopPoints)(THIS_ MUSIC_TIME mtStart, MUSIC_TIME mtEnd) PURE;
    STDMETHOD(GetLoopPoints)(THIS_ MUSIC_TIME *pmtStart, MUSIC_TIME *pmtEnd) PURE;
    STDMETHOD(SetPChannelsUsed)(THIS_ DWORD dwNumPChannels, DWORD *paPChannels) PURE;
    /*** IDirectMusicSegment8 methods ***/
    STDMETHOD(SetTrackConfig)(THIS_ REFGUID rguidTrackClassID, DWORD dwGroupBits, DWORD dwIndex, DWORD dwFlagsOn, DWORD dwFlagsOff) PURE;
    STDMETHOD(GetAudioPathConfig)(THIS_ IUnknown **ppAudioPathConfig) PURE;
    STDMETHOD(Compose)(THIS_ MUSIC_TIME mtTime, IDirectMusicSegment *pFromSegment, IDirectMusicSegment *pToSegment, IDirectMusicSegment **ppComposedSegment) PURE;
    STDMETHOD(Download)(THIS_ IUnknown *pAudioPath) PURE;
    STDMETHOD(Unload)(THIS_ IUnknown *pAudioPath) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicSegment8_QueryInterface(p,a,b)       (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicSegment8_AddRef(p)                   (p)->lpVtbl->AddRef(p)
#define IDirectMusicSegment8_Release(p)                  (p)->lpVtbl->Release(p)
/*** IDirectMusicSegment methods ***/
#define IDirectMusicSegment8_GetLength(p,a)              (p)->lpVtbl->GetLength(p,a)
#define IDirectMusicSegment8_SetLength(p,a)              (p)->lpVtbl->SetLength(p,a)
#define IDirectMusicSegment8_GetRepeats(p,a)             (p)->lpVtbl->GetRepeats(p,a)
#define IDirectMusicSegment8_SetRepeats(p,a)             (p)->lpVtbl->SetRepeats(p,a)
#define IDirectMusicSegment8_GetDefaultResolution(p,a)   (p)->lpVtbl->GetDefaultResolution(p,a)
#define IDirectMusicSegment8_SetDefaultResolution(p,a)   (p)->lpVtbl->SetDefaultResolution(p,a)
#define IDirectMusicSegment8_GetTrack(p,a,b,c,d)         (p)->lpVtbl->GetTrack(p,a,b,c,d)
#define IDirectMusicSegment8_GetTrackGroup(p,a,b)        (p)->lpVtbl->GetTrackGroup(p,a,b)
#define IDirectMusicSegment8_InsertTrack(p,a,b)          (p)->lpVtbl->InsertTrack(p,a,b)
#define IDirectMusicSegment8_RemoveTrack(p,a)            (p)->lpVtbl->RemoveTrack(p,a)
#define IDirectMusicSegment8_InitPlay(p,a,b,c)           (p)->lpVtbl->InitPlay(p,a,b,c)
#define IDirectMusicSegment8_GetGraph(p,a)               (p)->lpVtbl->GetGraph(p,a)
#define IDirectMusicSegment8_SetGraph(p,a)               (p)->lpVtbl->SetGraph(p,a)
#define IDirectMusicSegment8_AddNotificationType(p,a)    (p)->lpVtbl->AddNotificationType(p,a)
#define IDirectMusicSegment8_RemoveNotificationType(p,a) (p)->lpVtbl->RemoveNotificationType(p,a)
#define IDirectMusicSegment8_GetParam(p,a,b,c,d,e,f)     (p)->lpVtbl->GetParam(p,a,b,c,d,e,f)
#define IDirectMusicSegment8_SetParam(p,a,b,c,d,e)       (p)->lpVtbl->SetParam(p,a,b,c,d,e)
#define IDirectMusicSegment8_Clone(p,a,b,c)              (p)->lpVtbl->Clone(p,a,b,c)
#define IDirectMusicSegment8_SetStartPoint(p,a)          (p)->lpVtbl->SetStartPoint(p,a)
#define IDirectMusicSegment8_GetStartPoint(p,a)          (p)->lpVtbl->GetStartPoint(p,a)
#define IDirectMusicSegment8_SetLoopPoints(p,a,b)        (p)->lpVtbl->SetLoopPoints(p,a,b)
#define IDirectMusicSegment8_GetLoopPoints(p,a,b)        (p)->lpVtbl->GetLoopPoints(p,a,b)
#define IDirectMusicSegment8_SetPChannelsUsed(p,a,b)     (p)->lpVtbl->SetPChannelsUsed(p,a,b)
/*** IDirectMusicSegment8 methods ***/
#define IDirectMusicSegment8_SetTrackConfig(p,a,b,c,d,e) (p)->lpVtbl->SetTrackConfig(p,a,b,c,d,e)
#define IDirectMusicSegment8_GetAudioPathConfig(p,a)     (p)->lpVtbl->GetAudioPathConfig(p,a)
#define IDirectMusicSegment8_Compose(p,a,b,c,d)          (p)->lpVtbl->Compose(p,a,b,c,d)
#define IDirectMusicSegment8_Download(p,a)               (p)->lpVtbl->Download(p,a)
#define IDirectMusicSegment8_Unload(p,a)                 (p)->lpVtbl->Unload(p,a)
#endif


/*****************************************************************************
 * IDirectMusicSegmentState interface
 */
#define INTERFACE IDirectMusicSegmentState
DECLARE_INTERFACE_(IDirectMusicSegmentState,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicSegmentState methods ***/
    STDMETHOD(GetRepeats)(THIS_ DWORD *pdwRepeats) PURE;
    STDMETHOD(GetSegment)(THIS_ IDirectMusicSegment **ppSegment) PURE;
    STDMETHOD(GetStartTime)(THIS_ MUSIC_TIME *pmtStart) PURE;
    STDMETHOD(GetSeek)(THIS_ MUSIC_TIME *pmtSeek) PURE;
    STDMETHOD(GetStartPoint)(THIS_ MUSIC_TIME *pmtStart) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicSegmentState_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicSegmentState_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectMusicSegmentState_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectMusicSegmentState methods ***/
#define IDirectMusicSegmentState_GetRepeats(p,a)       (p)->lpVtbl->GetRepeats(p,a)
#define IDirectMusicSegmentState_GetSegment(p,a)       (p)->lpVtbl->GetSegment(p,a)
#define IDirectMusicSegmentState_GetStartTime(p,a)     (p)->lpVtbl->GetStartTime(p,a)
#define IDirectMusicSegmentState_GetSeek(p,a)          (p)->lpVtbl->GetSeek(p,a)
#define IDirectMusicSegmentState_GetStartPoint(p,a)    (p)->lpVtbl->GetStartPoint(p,a)
#endif


/*****************************************************************************
 * IDirectMusicSegmentState8 interface
 */
#define INTERFACE IDirectMusicSegmentState8
DECLARE_INTERFACE_(IDirectMusicSegmentState8,IDirectMusicSegmentState)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicSegmentState methods ***/
    STDMETHOD(GetRepeats)(THIS_ DWORD *pdwRepeats) PURE;
    STDMETHOD(GetSegment)(THIS_ IDirectMusicSegment **ppSegment) PURE;
    STDMETHOD(GetStartTime)(THIS_ MUSIC_TIME *pmtStart) PURE;
    STDMETHOD(GetSeek)(THIS_ MUSIC_TIME *pmtSeek) PURE;
    STDMETHOD(GetStartPoint)(THIS_ MUSIC_TIME *pmtStart) PURE;
    /*** IDirectMusicSegmentState8 methods ***/
    STDMETHOD(SetTrackConfig)(THIS_ REFGUID rguidTrackClassID, DWORD dwGroupBits, DWORD dwIndex, DWORD dwFlagsOn, DWORD dwFlagsOff) PURE;
    STDMETHOD(GetObjectInPath)(THIS_ DWORD dwPChannel, DWORD dwStage, DWORD dwBuffer, REFGUID guidObject, DWORD dwIndex, REFGUID iidInterface, void **ppObject) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicSegmentState8_QueryInterface(p,a,b)            (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicSegmentState8_AddRef(p)                        (p)->lpVtbl->AddRef(p)
#define IDirectMusicSegmentState8_Release(p)                       (p)->lpVtbl->Release(p)
/*** IDirectMusicSegmentState methods ***/
#define IDirectMusicSegmentState8_GetRepeats(p,a)                  (p)->lpVtbl->GetRepeats(p,a)
#define IDirectMusicSegmentState8_GetSegment(p,a)                  (p)->lpVtbl->GetSegment(p,a)
#define IDirectMusicSegmentState8_GetStartTime(p,a)                (p)->lpVtbl->GetStartTime(p,a)
#define IDirectMusicSegmentState8_GetSeek(p,a)                     (p)->lpVtbl->GetSeek(p,a)
#define IDirectMusicSegmentState8_GetStartPoint(p,a)               (p)->lpVtbl->GetStartPoint(p,a)
/*** IDirectMusicSegmentState8 methods ***/
#define IDirectMusicSegmentState8_SetTrackConfig(p,a,b,c,d,e)      (p)->lpVtbl->SetTrackConfig(p,a,b,c,d,e)
#define IDirectMusicSegmentState8_GetObjectInPath(p,a,b,c,d,e,f,g) (p)->lpVtbl->GetObjectInPath(p,a,b,c,d,e,f,g)
#endif


/*****************************************************************************
 * IDirectMusicAudioPath interface
 */
#define INTERFACE IDirectMusicAudioPath
DECLARE_INTERFACE_(IDirectMusicAudioPath,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicAudioPath methods ***/
    STDMETHOD(GetObjectInPath)(THIS_ DWORD dwPChannel, DWORD dwStage, DWORD dwBuffer, REFGUID guidObject, DWORD dwIndex, REFGUID iidInterface, void **ppObject) PURE;
    STDMETHOD(Activate)(THIS_ WINBOOL fActivate) PURE;
    STDMETHOD(SetVolume)(THIS_ LONG lVolume, DWORD dwDuration) PURE;
    STDMETHOD(ConvertPChannel)(THIS_ DWORD dwPChannelIn, DWORD *pdwPChannelOut) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicAudioPath_QueryInterface(p,a,b)            (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicAudioPath_AddRef(p)                        (p)->lpVtbl->AddRef(p)
#define IDirectMusicAudioPath_Release(p)                       (p)->lpVtbl->Release(p)
/*** IDirectMusicAudioPath methods ***/
#define IDirectMusicAudioPath_GetObjectInPath(p,a,b,c,d,e,f,g) (p)->lpVtbl->GetObjectInPath(p,a,b,c,d,e,f,g)
#define IDirectMusicAudioPath_Activate(p,a)                    (p)->lpVtbl->Activate(p,a)
#define IDirectMusicAudioPath_SetVolume(p,a,b)                 (p)->lpVtbl->SetVolume(p,a,b)
#define IDirectMusicAudioPath_ConvertPChannel(p,a,b)           (p)->lpVtbl->ConvertPChannel(p,a,b)
#endif


/*****************************************************************************
 * IDirectMusicPerformance interface
 */
#define INTERFACE IDirectMusicPerformance
DECLARE_INTERFACE_(IDirectMusicPerformance,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicPerformance methods ***/
    STDMETHOD(Init)(THIS_ IDirectMusic **ppDirectMusic, LPDIRECTSOUND pDirectSound, HWND hWnd) PURE;
    STDMETHOD(PlaySegment)(THIS_ IDirectMusicSegment *pSegment, DWORD dwFlags, __int64 i64StartTime, IDirectMusicSegmentState **ppSegmentState) PURE;
    STDMETHOD(Stop)(THIS_ IDirectMusicSegment *pSegment, IDirectMusicSegmentState *pSegmentState, MUSIC_TIME mtTime, DWORD dwFlags) PURE;
    STDMETHOD(GetSegmentState)(THIS_ IDirectMusicSegmentState **ppSegmentState, MUSIC_TIME mtTime) PURE;
    STDMETHOD(SetPrepareTime)(THIS_ DWORD dwMilliSeconds) PURE;
    STDMETHOD(GetPrepareTime)(THIS_ DWORD *pdwMilliSeconds) PURE;
    STDMETHOD(SetBumperLength)(THIS_ DWORD dwMilliSeconds) PURE;
    STDMETHOD(GetBumperLength)(THIS_ DWORD *pdwMilliSeconds) PURE;
    STDMETHOD(SendPMsg)(THIS_ DMUS_PMSG *pPMSG) PURE;
    STDMETHOD(MusicToReferenceTime)(THIS_ MUSIC_TIME mtTime, REFERENCE_TIME *prtTime) PURE;
    STDMETHOD(ReferenceToMusicTime)(THIS_ REFERENCE_TIME rtTime, MUSIC_TIME *pmtTime) PURE;
    STDMETHOD(IsPlaying)(THIS_ IDirectMusicSegment *pSegment, IDirectMusicSegmentState *pSegState) PURE;
    STDMETHOD(GetTime)(THIS_ REFERENCE_TIME *prtNow, MUSIC_TIME *pmtNow) PURE;
    STDMETHOD(AllocPMsg)(THIS_ ULONG cb, DMUS_PMSG **ppPMSG) PURE;
    STDMETHOD(FreePMsg)(THIS_ DMUS_PMSG *pPMSG) PURE;
    STDMETHOD(GetGraph)(THIS_ struct IDirectMusicGraph **ppGraph) PURE;
    STDMETHOD(SetGraph)(THIS_ struct IDirectMusicGraph *pGraph) PURE;
    STDMETHOD(SetNotificationHandle)(THIS_ HANDLE hNotification, REFERENCE_TIME rtMinimum) PURE;
    STDMETHOD(GetNotificationPMsg)(THIS_ DMUS_NOTIFICATION_PMSG **ppNotificationPMsg) PURE;
    STDMETHOD(AddNotificationType)(THIS_ REFGUID rguidNotificationType) PURE;
    STDMETHOD(RemoveNotificationType)(THIS_ REFGUID rguidNotificationType) PURE;
    STDMETHOD(AddPort)(THIS_ IDirectMusicPort *pPort) PURE;
    STDMETHOD(RemovePort)(THIS_ IDirectMusicPort *pPort) PURE;
    STDMETHOD(AssignPChannelBlock)(THIS_ DWORD dwBlockNum, IDirectMusicPort *pPort, DWORD dwGroup) PURE;
    STDMETHOD(AssignPChannel)(THIS_ DWORD dwPChannel, IDirectMusicPort *pPort, DWORD dwGroup, DWORD dwMChannel) PURE;
    STDMETHOD(PChannelInfo)(THIS_ DWORD dwPChannel, IDirectMusicPort **ppPort, DWORD *pdwGroup, DWORD *pdwMChannel) PURE;
    STDMETHOD(DownloadInstrument)(THIS_ IDirectMusicInstrument *pInst, DWORD dwPChannel, IDirectMusicDownloadedInstrument **ppDownInst, DMUS_NOTERANGE *pNoteRanges, DWORD dwNumNoteRanges, IDirectMusicPort **ppPort, DWORD *pdwGroup, DWORD *pdwMChannel) PURE;
    STDMETHOD(Invalidate)(THIS_ MUSIC_TIME mtTime, DWORD dwFlags) PURE;
    STDMETHOD(GetParam)(THIS_ REFGUID rguidType, DWORD dwGroupBits, DWORD dwIndex, MUSIC_TIME mtTime, MUSIC_TIME *pmtNext, void *pParam) PURE;
    STDMETHOD(SetParam)(THIS_ REFGUID rguidType, DWORD dwGroupBits, DWORD dwIndex, MUSIC_TIME mtTime, void *pParam) PURE;
    STDMETHOD(GetGlobalParam)(THIS_ REFGUID rguidType, void *pParam, DWORD dwSize) PURE;
    STDMETHOD(SetGlobalParam)(THIS_ REFGUID rguidType, void *pParam, DWORD dwSize) PURE;
    STDMETHOD(GetLatencyTime)(THIS_ REFERENCE_TIME *prtTime) PURE;
    STDMETHOD(GetQueueTime)(THIS_ REFERENCE_TIME *prtTime) PURE;
    STDMETHOD(AdjustTime)(THIS_ REFERENCE_TIME rtAmount) PURE;
    STDMETHOD(CloseDown)(THIS) PURE;
    STDMETHOD(GetResolvedTime)(THIS_ REFERENCE_TIME rtTime, REFERENCE_TIME *prtResolved, DWORD dwTimeResolveFlags) PURE;
    STDMETHOD(MIDIToMusic)(THIS_ BYTE bMIDIValue, DMUS_CHORD_KEY *pChord, BYTE bPlayMode, BYTE bChordLevel, WORD *pwMusicValue) PURE;
    STDMETHOD(MusicToMIDI)(THIS_ WORD wMusicValue, DMUS_CHORD_KEY *pChord, BYTE bPlayMode, BYTE bChordLevel, BYTE *pbMIDIValue) PURE;
    STDMETHOD(TimeToRhythm)(THIS_ MUSIC_TIME mtTime, DMUS_TIMESIGNATURE *pTimeSig, WORD *pwMeasure, BYTE *pbBeat, BYTE *pbGrid, short *pnOffset) PURE;
    STDMETHOD(RhythmToTime)(THIS_ WORD wMeasure, BYTE bBeat, BYTE bGrid, short nOffset, DMUS_TIMESIGNATURE *pTimeSig, MUSIC_TIME *pmtTime) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicPerformance_QueryInterface(p,a,b)                 (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicPerformance_AddRef(p)                             (p)->lpVtbl->AddRef(p)
#define IDirectMusicPerformance_Release(p)                            (p)->lpVtbl->Release(p)
/*** IDirectMusicPerformance methods ***/
#define IDirectMusicPerformance_Init(p,a,b,c)                         (p)->lpVtbl->Init(p,a,b,c)
#define IDirectMusicPerformance_PlaySegment(p,a,b,c,d)                (p)->lpVtbl->PlaySegment(p,a,b,c,d)
#define IDirectMusicPerformance_Stop(p,a,b,c,d)                       (p)->lpVtbl->Stop(p,a,b,c,d)
#define IDirectMusicPerformance_GetSegmentState(p,a,b)                (p)->lpVtbl->GetSegmentState(p,a,b)
#define IDirectMusicPerformance_SetPrepareTime(p,a)                   (p)->lpVtbl->SetPrepareTime(p,a)
#define IDirectMusicPerformance_GetPrepareTime(p,a)                   (p)->lpVtbl->GetPrepareTime(p,a)
#define IDirectMusicPerformance_SetBumperLength(p,a)                  (p)->lpVtbl->SetBumperLength(p,a)
#define IDirectMusicPerformance_GetBumperLength(p,a)                  (p)->lpVtbl->GetBumperLength(p,a)
#define IDirectMusicPerformance_SendPMsg(p,a)                         (p)->lpVtbl->SendPMsg(p,a)
#define IDirectMusicPerformance_MusicToReferenceTime(p,a,b)           (p)->lpVtbl->MusicToReferenceTime(p,a,b)
#define IDirectMusicPerformance_ReferenceToMusicTime(p,a,b)           (p)->lpVtbl->ReferenceToMusicTime(p,a,b)
#define IDirectMusicPerformance_IsPlaying(p,a,b)                      (p)->lpVtbl->IsPlaying(p,a,b)
#define IDirectMusicPerformance_GetTime(p,a,b)                        (p)->lpVtbl->GetTime(p,a,b)
#define IDirectMusicPerformance_AllocPMsg(p,a,b)                      (p)->lpVtbl->AllocPMsg(p,a,b)
#define IDirectMusicPerformance_FreePMsg(p,a)                         (p)->lpVtbl->FreePMsg(p,a)
#define IDirectMusicPerformance_GetGraph(p,a)                         (p)->lpVtbl->GetGraph(p,a)
#define IDirectMusicPerformance_SetGraph(p,a)                         (p)->lpVtbl->SetGraph(p,a)
#define IDirectMusicPerformance_SetNotificationHandle(p,a,b)          (p)->lpVtbl->SetNotificationHandle(p,a,b)
#define IDirectMusicPerformance_GetNotificationPMsg(p,a)              (p)->lpVtbl->GetNotificationPMsg(p,a)
#define IDirectMusicPerformance_AddNotificationType(p,a)              (p)->lpVtbl->AddNotificationType(p,a)
#define IDirectMusicPerformance_RemoveNotificationType(p,a)           (p)->lpVtbl->RemoveNotificationType(p,a)
#define IDirectMusicPerformance_AddPort(p,a)                          (p)->lpVtbl->AddPort(p,a)
#define IDirectMusicPerformance_RemovePort(p,a)                       (p)->lpVtbl->RemovePort(p,a)
#define IDirectMusicPerformance_AssignPChannelBlock(p,a,b,c)          (p)->lpVtbl->AssignPChannelBlock(p,a,b,c)
#define IDirectMusicPerformance_AssignPChannel(p,a,b,c,d)             (p)->lpVtbl->AssignPChannel(p,a,b,c,d)
#define IDirectMusicPerformance_PChannelInfo(p,a,b,c,d)               (p)->lpVtbl->PChannelInfo(p,a,b,c,d)
#define IDirectMusicPerformance_DownloadInstrument(p,a,b,c,d,e,f,g,h) (p)->lpVtbl->DownloadInstrument(p,a,b,c,d,e,f,g,h)
#define IDirectMusicPerformance_Invalidate(p,a,b)                     (p)->lpVtbl->Invalidate(p,a,b)
#define IDirectMusicPerformance_GetParam(p,a,b,c,d,e,f)               (p)->lpVtbl->GetParam(p,a,b,c,d,e,f)
#define IDirectMusicPerformance_SetParam(p,a,b,c,d,e)                 (p)->lpVtbl->SetParam(p,a,b,c,d,e)
#define IDirectMusicPerformance_GetGlobalParam(p,a,b,c)               (p)->lpVtbl->GetGlobalParam(p,a,b,c)
#define IDirectMusicPerformance_SetGlobalParam(p,a,b,c)               (p)->lpVtbl->SetGlobalParam(p,a,b,c)
#define IDirectMusicPerformance_GetLatencyTime(p,a)                   (p)->lpVtbl->GetLatencyTime(p,a)
#define IDirectMusicPerformance_GetQueueTime(p,a)                     (p)->lpVtbl->GetQueueTime(p,a)
#define IDirectMusicPerformance_AdjustTime(p,a)                       (p)->lpVtbl->AdjustTime(p,a)
#define IDirectMusicPerformance_CloseDown(p)                          (p)->lpVtbl->CloseDown(p)
#define IDirectMusicPerformance_GetResolvedTime(p,a,b,c)              (p)->lpVtbl->GetResolvedTime(p,a,b,c)
#define IDirectMusicPerformance_MIDIToMusic(p,a,b,c,d,e)              (p)->lpVtbl->MIDIToMusic(p,a,b,c,d,e)
#define IDirectMusicPerformance_MusicToMIDI(p,a,b,c,d,e)              (p)->lpVtbl->MusicToMIDI(p,a,b,c,d,e)
#define IDirectMusicPerformance_TimeToRhythm(p,a,b,c,d,e,f)           (p)->lpVtbl->TimeToRhythm(p,a,b,c,d,e,f)
#define IDirectMusicPerformance_RhythmToTime(p,a,b,c,d,e,f)           (p)->lpVtbl->RhythmToTime(p,a,b,c,d,e,f)
#endif


/*****************************************************************************
 * IDirectMusicPerformance8 interface
 */
#define INTERFACE IDirectMusicPerformance8
DECLARE_INTERFACE_(IDirectMusicPerformance8,IDirectMusicPerformance)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicPerformance methods ***/
    STDMETHOD(Init)(THIS_ IDirectMusic **ppDirectMusic, LPDIRECTSOUND pDirectSound, HWND hWnd) PURE;
    STDMETHOD(PlaySegment)(THIS_ IDirectMusicSegment *pSegment, DWORD dwFlags, __int64 i64StartTime, IDirectMusicSegmentState **ppSegmentState) PURE;
    STDMETHOD(Stop)(THIS_ IDirectMusicSegment *pSegment, IDirectMusicSegmentState *pSegmentState, MUSIC_TIME mtTime, DWORD dwFlags) PURE;
    STDMETHOD(GetSegmentState)(THIS_ IDirectMusicSegmentState **ppSegmentState, MUSIC_TIME mtTime) PURE;
    STDMETHOD(SetPrepareTime)(THIS_ DWORD dwMilliSeconds) PURE;
    STDMETHOD(GetPrepareTime)(THIS_ DWORD *pdwMilliSeconds) PURE;
    STDMETHOD(SetBumperLength)(THIS_ DWORD dwMilliSeconds) PURE;
    STDMETHOD(GetBumperLength)(THIS_ DWORD *pdwMilliSeconds) PURE;
    STDMETHOD(SendPMsg)(THIS_ DMUS_PMSG *pPMSG) PURE;
    STDMETHOD(MusicToReferenceTime)(THIS_ MUSIC_TIME mtTime, REFERENCE_TIME *prtTime) PURE;
    STDMETHOD(ReferenceToMusicTime)(THIS_ REFERENCE_TIME rtTime, MUSIC_TIME *pmtTime) PURE;
    STDMETHOD(IsPlaying)(THIS_ IDirectMusicSegment *pSegment, IDirectMusicSegmentState *pSegState) PURE;
    STDMETHOD(GetTime)(THIS_ REFERENCE_TIME *prtNow, MUSIC_TIME *pmtNow) PURE;
    STDMETHOD(AllocPMsg)(THIS_ ULONG cb, DMUS_PMSG **ppPMSG) PURE;
    STDMETHOD(FreePMsg)(THIS_ DMUS_PMSG *pPMSG) PURE;
    STDMETHOD(GetGraph)(THIS_ struct IDirectMusicGraph **ppGraph) PURE;
    STDMETHOD(SetGraph)(THIS_ struct IDirectMusicGraph *pGraph) PURE;
    STDMETHOD(SetNotificationHandle)(THIS_ HANDLE hNotification, REFERENCE_TIME rtMinimum) PURE;
    STDMETHOD(GetNotificationPMsg)(THIS_ DMUS_NOTIFICATION_PMSG **ppNotificationPMsg) PURE;
    STDMETHOD(AddNotificationType)(THIS_ REFGUID rguidNotificationType) PURE;
    STDMETHOD(RemoveNotificationType)(THIS_ REFGUID rguidNotificationType) PURE;
    STDMETHOD(AddPort)(THIS_ IDirectMusicPort *pPort) PURE;
    STDMETHOD(RemovePort)(THIS_ IDirectMusicPort *pPort) PURE;
    STDMETHOD(AssignPChannelBlock)(THIS_ DWORD dwBlockNum, IDirectMusicPort *pPort, DWORD dwGroup) PURE;
    STDMETHOD(AssignPChannel)(THIS_ DWORD dwPChannel, IDirectMusicPort *pPort, DWORD dwGroup, DWORD dwMChannel) PURE;
    STDMETHOD(PChannelInfo)(THIS_ DWORD dwPChannel, IDirectMusicPort **ppPort, DWORD *pdwGroup, DWORD *pdwMChannel) PURE;
    STDMETHOD(DownloadInstrument)(THIS_ IDirectMusicInstrument *pInst, DWORD dwPChannel, IDirectMusicDownloadedInstrument **ppDownInst, DMUS_NOTERANGE *pNoteRanges, DWORD dwNumNoteRanges, IDirectMusicPort **ppPort, DWORD *pdwGroup, DWORD *pdwMChannel) PURE;
    STDMETHOD(Invalidate)(THIS_ MUSIC_TIME mtTime, DWORD dwFlags) PURE;
    STDMETHOD(GetParam)(THIS_ REFGUID rguidType, DWORD dwGroupBits, DWORD dwIndex, MUSIC_TIME mtTime, MUSIC_TIME *pmtNext, void *pParam) PURE;
    STDMETHOD(SetParam)(THIS_ REFGUID rguidType, DWORD dwGroupBits, DWORD dwIndex, MUSIC_TIME mtTime, void *pParam) PURE;
    STDMETHOD(GetGlobalParam)(THIS_ REFGUID rguidType, void *pParam, DWORD dwSize) PURE;
    STDMETHOD(SetGlobalParam)(THIS_ REFGUID rguidType, void *pParam, DWORD dwSize) PURE;
    STDMETHOD(GetLatencyTime)(THIS_ REFERENCE_TIME *prtTime) PURE;
    STDMETHOD(GetQueueTime)(THIS_ REFERENCE_TIME *prtTime) PURE;
    STDMETHOD(AdjustTime)(THIS_ REFERENCE_TIME rtAmount) PURE;
    STDMETHOD(CloseDown)(THIS) PURE;
    STDMETHOD(GetResolvedTime)(THIS_ REFERENCE_TIME rtTime, REFERENCE_TIME *prtResolved, DWORD dwTimeResolveFlags) PURE;
    STDMETHOD(MIDIToMusic)(THIS_ BYTE bMIDIValue, DMUS_CHORD_KEY *pChord, BYTE bPlayMode, BYTE bChordLevel, WORD *pwMusicValue) PURE;
    STDMETHOD(MusicToMIDI)(THIS_ WORD wMusicValue, DMUS_CHORD_KEY *pChord, BYTE bPlayMode, BYTE bChordLevel, BYTE *pbMIDIValue) PURE;
    STDMETHOD(TimeToRhythm)(THIS_ MUSIC_TIME mtTime, DMUS_TIMESIGNATURE *pTimeSig, WORD *pwMeasure, BYTE *pbBeat, BYTE *pbGrid, short *pnOffset) PURE;
    STDMETHOD(RhythmToTime)(THIS_ WORD wMeasure, BYTE bBeat, BYTE bGrid, short nOffset, DMUS_TIMESIGNATURE *pTimeSig, MUSIC_TIME *pmtTime) PURE;
    /*** IDirectMusicPerformance8 methods ***/
    STDMETHOD(InitAudio)(THIS_ IDirectMusic **ppDirectMusic, IDirectSound **ppDirectSound, HWND hWnd, DWORD dwDefaultPathType, DWORD dwPChannelCount, DWORD dwFlags, DMUS_AUDIOPARAMS *pParams) PURE;
    STDMETHOD(PlaySegmentEx)(THIS_ IUnknown *pSource, WCHAR *pwzSegmentName, IUnknown *pTransition, DWORD dwFlags, __int64 i64StartTime, IDirectMusicSegmentState **ppSegmentState, IUnknown *pFrom, IUnknown *pAudioPath) PURE;
    STDMETHOD(StopEx)(THIS_ IUnknown *pObjectToStop, __int64 i64StopTime, DWORD dwFlags) PURE;
    STDMETHOD(ClonePMsg)(THIS_ DMUS_PMSG *pSourcePMSG, DMUS_PMSG **ppCopyPMSG) PURE;
    STDMETHOD(CreateAudioPath)(THIS_ IUnknown *pSourceConfig, WINBOOL fActivate, IDirectMusicAudioPath **ppNewPath) PURE;
    STDMETHOD(CreateStandardAudioPath)(THIS_ DWORD dwType, DWORD dwPChannelCount, WINBOOL fActivate, IDirectMusicAudioPath **ppNewPath) PURE;
    STDMETHOD(SetDefaultAudioPath)(THIS_ IDirectMusicAudioPath *pAudioPath) PURE;
    STDMETHOD(GetDefaultAudioPath)(THIS_ IDirectMusicAudioPath **ppAudioPath) PURE;
    STDMETHOD(GetParamEx)(THIS_ REFGUID rguidType, DWORD dwTrackID, DWORD dwGroupBits, DWORD dwIndex, MUSIC_TIME mtTime, MUSIC_TIME *pmtNext, void *pParam) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicPerformance8_QueryInterface(p,a,b)                 (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicPerformance8_AddRef(p)                             (p)->lpVtbl->AddRef(p)
#define IDirectMusicPerformance8_Release(p)                            (p)->lpVtbl->Release(p)
/*** IDirectMusicPerformance methods ***/
#define IDirectMusicPerformance8_Init(p,a,b,c)                         (p)->lpVtbl->Init(p,a,b,c)
#define IDirectMusicPerformance8_PlaySegment(p,a,b,c,d)                (p)->lpVtbl->PlaySegment(p,a,b,c,d)
#define IDirectMusicPerformance8_Stop(p,a,b,c,d)                       (p)->lpVtbl->Stop(p,a,b,c,d)
#define IDirectMusicPerformance8_GetSegmentState(p,a,b)                (p)->lpVtbl->GetSegmentState(p,a,b)
#define IDirectMusicPerformance8_SetPrepareTime(p,a)                   (p)->lpVtbl->SetPrepareTime(p,a)
#define IDirectMusicPerformance8_GetPrepareTime(p,a)                   (p)->lpVtbl->GetPrepareTime(p,a)
#define IDirectMusicPerformance8_SetBumperLength(p,a)                  (p)->lpVtbl->SetBumperLength(p,a)
#define IDirectMusicPerformance8_GetBumperLength(p,a)                  (p)->lpVtbl->GetBumperLength(p,a)
#define IDirectMusicPerformance8_SendPMsg(p,a)                         (p)->lpVtbl->SendPMsg(p,a)
#define IDirectMusicPerformance8_MusicToReferenceTime(p,a,b)           (p)->lpVtbl->MusicToReferenceTime(p,a,b)
#define IDirectMusicPerformance8_ReferenceToMusicTime(p,a,b)           (p)->lpVtbl->ReferenceToMusicTime(p,a,b)
#define IDirectMusicPerformance8_IsPlaying(p,a,b)                      (p)->lpVtbl->IsPlaying(p,a,b)
#define IDirectMusicPerformance8_GetTime(p,a,b)                        (p)->lpVtbl->GetTime(p,a,b)
#define IDirectMusicPerformance8_AllocPMsg(p,a,b)                      (p)->lpVtbl->AllocPMsg(p,a,b)
#define IDirectMusicPerformance8_FreePMsg(p,a)                         (p)->lpVtbl->FreePMsg(p,a)
#define IDirectMusicPerformance8_GetGraph(p,a)                         (p)->lpVtbl->GetGraph(p,a)
#define IDirectMusicPerformance8_SetGraph(p,a)                         (p)->lpVtbl->SetGraph(p,a)
#define IDirectMusicPerformance8_SetNotificationHandle(p,a,b)          (p)->lpVtbl->SetNotificationHandle(p,a,b)
#define IDirectMusicPerformance8_GetNotificationPMsg(p,a)              (p)->lpVtbl->GetNotificationPMsg(p,a)
#define IDirectMusicPerformance8_AddNotificationType(p,a)              (p)->lpVtbl->AddNotificationType(p,a)
#define IDirectMusicPerformance8_RemoveNotificationType(p,a)           (p)->lpVtbl->RemoveNotificationType(p,a)
#define IDirectMusicPerformance8_AddPort(p,a)                          (p)->lpVtbl->AddPort(p,a)
#define IDirectMusicPerformance8_RemovePort(p,a)                       (p)->lpVtbl->RemovePort(p,a)
#define IDirectMusicPerformance8_AssignPChannelBlock(p,a,b,c)          (p)->lpVtbl->AssignPChannelBlock(p,a,b,c)
#define IDirectMusicPerformance8_AssignPChannel(p,a,b,c,d)             (p)->lpVtbl->AssignPChannel(p,a,b,c,d)
#define IDirectMusicPerformance8_PChannelInfo(p,a,b,c,d)               (p)->lpVtbl->PChannelInfo(p,a,b,c,d)
#define IDirectMusicPerformance8_DownloadInstrument(p,a,b,c,d,e,f,g,h) (p)->lpVtbl->DownloadInstrument(p,a,b,c,d,e,f,g,h)
#define IDirectMusicPerformance8_Invalidate(p,a,b)                     (p)->lpVtbl->Invalidate(p,a,b)
#define IDirectMusicPerformance8_GetParam(p,a,b,c,d,e,f)               (p)->lpVtbl->GetParam(p,a,b,c,d,e,f)
#define IDirectMusicPerformance8_SetParam(p,a,b,c,d,e)                 (p)->lpVtbl->SetParam(p,a,b,c,d,e)
#define IDirectMusicPerformance8_GetGlobalParam(p,a,b,c)               (p)->lpVtbl->GetGlobalParam(p,a,b,c)
#define IDirectMusicPerformance8_SetGlobalParam(p,a,b,c)               (p)->lpVtbl->SetGlobalParam(p,a,b,c)
#define IDirectMusicPerformance8_GetLatencyTime(p,a)                   (p)->lpVtbl->GetLatencyTime(p,a)
#define IDirectMusicPerformance8_GetQueueTime(p,a)                     (p)->lpVtbl->GetQueueTime(p,a)
#define IDirectMusicPerformance8_AdjustTime(p,a)                       (p)->lpVtbl->AdjustTime(p,a)
#define IDirectMusicPerformance8_CloseDown(p)                          (p)->lpVtbl->CloseDown(p)
#define IDirectMusicPerformance8_GetResolvedTime(p,a,b,c)              (p)->lpVtbl->GetResolvedTime(p,a,b,c)
#define IDirectMusicPerformance8_MIDIToMusic(p,a,b,c,d,e)              (p)->lpVtbl->MIDIToMusic(p,a,b,c,d,e)
#define IDirectMusicPerformance8_MusicToMIDI(p,a,b,c,d,e)              (p)->lpVtbl->MusicToMIDI(p,a,b,c,d,e)
#define IDirectMusicPerformance8_TimeToRhythm(p,a,b,c,d,e,f)           (p)->lpVtbl->TimeToRhythm(p,a,b,c,d,e,f)
#define IDirectMusicPerformance8_RhythmToTime(p,a,b,c,d,e,f)           (p)->lpVtbl->RhythmToTime(p,a,b,c,d,e,f)
    /*  IDirectMusicPerformance8 methods*/
#define IDirectMusicPerformance8_InitAudio(p,a,b,c,d,e,f,g)            (p)->lpVtbl->InitAudio(p,a,b,c,d,e,f,g)
#define IDirectMusicPerformance8_PlaySegmentEx(p,a,b,c,d,e,f,g,h)      (p)->lpVtbl->PlaySegmentEx(p,a,b,c,d,e,f,g,h)
#define IDirectMusicPerformance8_StopEx(p,a,b,c)                       (p)->lpVtbl->StopEx(p,a,b,c)
#define IDirectMusicPerformance8_ClonePMsg(p,a,b)                      (p)->lpVtbl->ClonePMsg(p,a,b)
#define IDirectMusicPerformance8_CreateAudioPath(p,a,b,c)              (p)->lpVtbl->CreateAudioPath(p,a,b,c)
#define IDirectMusicPerformance8_CreateStandardAudioPath(p,a,b,c,d)    (p)->lpVtbl->CreateStandardAudioPath(p,a,b,c,d)
#define IDirectMusicPerformance8_SetDefaultAudioPath(p,a)              (p)->lpVtbl->SetDefaultAudioPath(p,a)
#define IDirectMusicPerformance8_GetDefaultAudioPath(p,a)              (p)->lpVtbl->GetDefaultAudioPath(p,a)
#define IDirectMusicPerformance8_GetParamEx(p,a,b,c,d,e,f,g)           (p)->lpVtbl->GetParamEx(p,a,b,c,d,e,f,g)
#endif


/*****************************************************************************
 * IDirectMusicGraph interface
 */
#define INTERFACE IDirectMusicGraph
DECLARE_INTERFACE_(IDirectMusicGraph,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicGraph methods ***/
    STDMETHOD(StampPMsg)(THIS_ DMUS_PMSG *pPMSG) PURE;
    STDMETHOD(InsertTool)(THIS_ IDirectMusicTool *pTool, DWORD *pdwPChannels, DWORD cPChannels, LONG lIndex) PURE;
    STDMETHOD(GetTool)(THIS_ DWORD dwIndex, IDirectMusicTool **ppTool) PURE;
    STDMETHOD(RemoveTool)(THIS_ IDirectMusicTool *pTool) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicGraph_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicGraph_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectMusicGraph_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectMusicGraph methods ***/
#define IDirectMusicGraph_StampPMsg(p,a)        (p)->lpVtbl->StampPMsg(p,a)
#define IDirectMusicGraph_InsertTool(p,a,b,c,d) (p)->lpVtbl->InsertTool(p,a,b,c,d)
#define IDirectMusicGraph_GetTool(p,a,b)        (p)->lpVtbl->GetTool(p,a,b)
#define IDirectMusicGraph_RemoveTool(p,a)       (p)->lpVtbl->RemoveTool(p,a)
#endif


/*****************************************************************************
 * IDirectMusicStyle interface
 */
#define INTERFACE IDirectMusicStyle
DECLARE_INTERFACE_(IDirectMusicStyle,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicStyle methods ***/
    STDMETHOD(GetBand)(THIS_ WCHAR *pwszName, IDirectMusicBand **ppBand) PURE;
    STDMETHOD(EnumBand)(THIS_ DWORD dwIndex, WCHAR *pwszName) PURE;
    STDMETHOD(GetDefaultBand)(THIS_ IDirectMusicBand **ppBand) PURE;
    STDMETHOD(EnumMotif)(THIS_ DWORD dwIndex, WCHAR *pwszName) PURE;
    STDMETHOD(GetMotif)(THIS_ WCHAR *pwszName, IDirectMusicSegment **ppSegment) PURE;
    STDMETHOD(GetDefaultChordMap)(THIS_ struct IDirectMusicChordMap **ppChordMap) PURE;
    STDMETHOD(EnumChordMap)(THIS_ DWORD dwIndex, WCHAR *pwszName) PURE;
    STDMETHOD(GetChordMap)(THIS_ WCHAR *pwszName, struct IDirectMusicChordMap **ppChordMap) PURE;
    STDMETHOD(GetTimeSignature)(THIS_ DMUS_TIMESIGNATURE *pTimeSig) PURE;
    STDMETHOD(GetEmbellishmentLength)(THIS_ DWORD dwType, DWORD dwLevel, DWORD *pdwMin, DWORD *pdwMax) PURE;
    STDMETHOD(GetTempo)(THIS_ double *pTempo) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicStyle_QueryInterface(p,a,b)             (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicStyle_AddRef(p)                         (p)->lpVtbl->AddRef(p)
#define IDirectMusicStyle_Release(p)                        (p)->lpVtbl->Release(p)
/*** IDirectMusicStyle methods ***/
#define IDirectMusicStyle_GetBand(p,a,b)                    (p)->lpVtbl->GetBand(p,a,b)
#define IDirectMusicStyle_EnumBand(p,a,b)                   (p)->lpVtbl->EnumBand(p,a,b)
#define IDirectMusicStyle_GetDefaultBand(p,a)               (p)->lpVtbl->GetDefaultBand(p,a)
#define IDirectMusicStyle_EnumMotif(p,a,b)                  (p)->lpVtbl->EnumMotif(p,a,b)
#define IDirectMusicStyle_GetMotif(p,a,b)                   (p)->lpVtbl->GetMotif(p,a,b)
#define IDirectMusicStyle_GetDefaultChordMap(p,a)           (p)->lpVtbl->GetDefaultChordMap(p,a)
#define IDirectMusicStyle_EnumChordMap(p,a,b)               (p)->lpVtbl->EnumChordMap(p,a,b)
#define IDirectMusicStyle_GetChordMap(p,a,b)                (p)->lpVtbl->GetChordMap(p,a,b)
#define IDirectMusicStyle_GetTimeSignature(p,a)             (p)->lpVtbl->GetTimeSignature(p,a)
#define IDirectMusicStyle_GetEmbellishmentLength(p,a,b,c,d) (p)->lpVtbl->GetEmbellishmentLength(p,a,b,c,d)
#define IDirectMusicStyle_GetTempo(p,a)                     (p)->lpVtbl->GetTempo(p,a)
#endif


/*****************************************************************************
 * IDirectMusicStyle8 interface
 */
#define INTERFACE IDirectMusicStyle8
DECLARE_INTERFACE_(IDirectMusicStyle8,IDirectMusicStyle)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicStyle methods ***/
    STDMETHOD(GetBand)(THIS_ WCHAR *pwszName, IDirectMusicBand **ppBand) PURE;
    STDMETHOD(EnumBand)(THIS_ DWORD dwIndex, WCHAR *pwszName) PURE;
    STDMETHOD(GetDefaultBand)(THIS_ IDirectMusicBand **ppBand) PURE;
    STDMETHOD(EnumMotif)(THIS_ DWORD dwIndex, WCHAR *pwszName) PURE;
    STDMETHOD(GetMotif)(THIS_ WCHAR *pwszName, IDirectMusicSegment **ppSegment) PURE;
    STDMETHOD(GetDefaultChordMap)(THIS_ struct IDirectMusicChordMap **ppChordMap) PURE;
    STDMETHOD(EnumChordMap)(THIS_ DWORD dwIndex, WCHAR *pwszName) PURE;
    STDMETHOD(GetChordMap)(THIS_ WCHAR *pwszName, struct IDirectMusicChordMap **ppChordMap) PURE;
    STDMETHOD(GetTimeSignature)(THIS_ DMUS_TIMESIGNATURE *pTimeSig) PURE;
    STDMETHOD(GetEmbellishmentLength)(THIS_ DWORD dwType, DWORD dwLevel, DWORD *pdwMin, DWORD *pdwMax) PURE;
    STDMETHOD(GetTempo)(THIS_ double *pTempo) PURE;
    /*** IDirectMusicStyle8 methods ***/
    STDMETHOD(EnumPattern)(THIS_ DWORD dwIndex, DWORD dwPatternType, WCHAR *pwszName) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicStyle8_QueryInterface(p,a,b)             (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicStyle8_AddRef(p)                         (p)->lpVtbl->AddRef(p)
#define IDirectMusicStyle8_Release(p)                        (p)->lpVtbl->Release(p)
/*** IDirectMusicStyle methods ***/
#define IDirectMusicStyle8_GetBand(p,a,b)                    (p)->lpVtbl->GetBand(p,a,b)
#define IDirectMusicStyle8_EnumBand(p,a,b)                   (p)->lpVtbl->EnumBand(p,a,b)
#define IDirectMusicStyle8_GetDefaultBand(p,a)               (p)->lpVtbl->GetDefaultBand(p,a)
#define IDirectMusicStyle8_EnumMotif(p,a,b)                  (p)->lpVtbl->EnumMotif(p,a,b)
#define IDirectMusicStyle8_GetMotif(p,a,b)                   (p)->lpVtbl->GetMotif(p,a,b)
#define IDirectMusicStyle8_GetDefaultChordMap(p,a)           (p)->lpVtbl->GetDefaultChordMap(p,a)
#define IDirectMusicStyle8_EnumChordMap(p,a,b)               (p)->lpVtbl->EnumChordMap(p,a,b)
#define IDirectMusicStyle8_GetChordMap(p,a,b)                (p)->lpVtbl->GetChordMap(p,a,b)
#define IDirectMusicStyle8_GetTimeSignature(p,a)             (p)->lpVtbl->GetTimeSignature(p,a)
#define IDirectMusicStyle8_GetEmbellishmentLength(p,a,b,c,d) (p)->lpVtbl->GetEmbellishmentLength(p,a,b,c,d)
#define IDirectMusicStyle8_GetTempo(p,a)                     (p)->lpVtbl->GetTempo(p,a)
/*** IDirectMusicStyle8 methods ***/
#define IDirectMusicStyle8_EnumPattern(p,a,b,c)              (p)->lpVtbl->EnumPattern(p,a,b,c)
#endif


/*****************************************************************************
 * IDirectMusicChordMap interface
 */
#define INTERFACE IDirectMusicChordMap
DECLARE_INTERFACE_(IDirectMusicChordMap,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicChordMap methods ***/
    STDMETHOD(GetScale)(THIS_ DWORD *pdwScale) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicChordMap_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicChordMap_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectMusicChordMap_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectMusicChordMap methods ***/
#define IDirectMusicChordMap_GetScale(p,a)         (p)->lpVtbl->GetScale(p,a)
#endif


/*****************************************************************************
 * IDirectMusicComposer interface
 */
#define INTERFACE IDirectMusicComposer
DECLARE_INTERFACE_(IDirectMusicComposer,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicComposer methods ***/
    STDMETHOD(ComposeSegmentFromTemplate)(THIS_ IDirectMusicStyle *pStyle, IDirectMusicSegment *pTemplate, WORD wActivity, IDirectMusicChordMap *pChordMap, IDirectMusicSegment **ppSegment) PURE;
    STDMETHOD(ComposeSegmentFromShape)(THIS_ IDirectMusicStyle *pStyle, WORD wNumMeasures, WORD wShape, WORD wActivity, WINBOOL fIntro, WINBOOL fEnd, IDirectMusicChordMap *pChordMap, IDirectMusicSegment **ppSegment) PURE;
    STDMETHOD(ComposeTransition)(THIS_ IDirectMusicSegment *pFromSeg, IDirectMusicSegment *pToSeg, MUSIC_TIME mtTime, WORD wCommand, DWORD dwFlags, IDirectMusicChordMap *pChordMap, IDirectMusicSegment **ppTransSeg) PURE;
    STDMETHOD(AutoTransition)(THIS_ IDirectMusicPerformance *pPerformance, IDirectMusicSegment *pToSeg, WORD wCommand, DWORD dwFlags, IDirectMusicChordMap *pChordMap, IDirectMusicSegment **ppTransSeg, IDirectMusicSegmentState **ppToSegState, IDirectMusicSegmentState **ppTransSegState) PURE;
    STDMETHOD(ComposeTemplateFromShape)(THIS_ WORD wNumMeasures, WORD wShape, WINBOOL fIntro, WINBOOL fEnd, WORD wEndLength, IDirectMusicSegment **ppTemplate) PURE;
    STDMETHOD(ChangeChordMap)(THIS_ IDirectMusicSegment *pSegment, WINBOOL fTrackScale, IDirectMusicChordMap *pChordMap) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicComposer_QueryInterface(p,a,b)                      (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicComposer_AddRef(p)                                  (p)->lpVtbl->AddRef(p)
#define IDirectMusicComposer_Release(p)                                 (p)->lpVtbl->Release(p)
/*** IDirectMusicComposer methods ***/
#define IDirectMusicComposer_ComposeSegmentFromTemplate(p,a,b,c,d,e)    (p)->lpVtbl->ComposeSegmentFromTemplate(p,a,b,c,d,e)
#define IDirectMusicComposer_ComposeSegmentFromShape(p,a,b,c,d,e,f,g,h) (p)->lpVtbl->ComposeSegmentFromShape(p,a,b,c,d,e,f,g,h)
#define IDirectMusicComposer_ComposeTransition(p,a,b,c,d,e,f,g)         (p)->lpVtbl->ComposeTransition(p,a,b,c,d,e,f,g)
#define IDirectMusicComposer_AutoTransition(p,a,b,c,d,e,f,g,h)          (p)->lpVtbl->AutoTransition(p,a,b,c,d,e,f,g,h)
#define IDirectMusicComposer_ComposeTemplateFromShape(p,a,b,c,d,e,f)    (p)->lpVtbl->ComposeTemplateFromShape(p,a,b,c,d,e,f)
#define IDirectMusicComposer_ChangeChordMap(p,a,b,c)                    (p)->lpVtbl->ChangeChordMap(p,a,b,c)
#endif


/*****************************************************************************
 * IDirectMusicPatternTrack interface
 */
#define INTERFACE IDirectMusicPatternTrack
DECLARE_INTERFACE_(IDirectMusicPatternTrack,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicPatternTrack methods ***/
    STDMETHOD(CreateSegment)(THIS_ IDirectMusicStyle *pStyle, IDirectMusicSegment **ppSegment) PURE;
    STDMETHOD(SetVariation)(THIS_ IDirectMusicSegmentState *pSegState, DWORD dwVariationFlags, DWORD dwPart) PURE;
    STDMETHOD(SetPatternByName)(THIS_ IDirectMusicSegmentState *pSegState, WCHAR *wszName, IDirectMusicStyle *pStyle, DWORD dwPatternType, DWORD *pdwLength) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicPatternTrack_QueryInterface(p,a,b)         (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicPatternTrack_AddRef(p)                     (p)->lpVtbl->AddRef(p)
#define IDirectMusicPatternTrack_Release(p)                    (p)->lpVtbl->Release(p)
/*** IDirectMusicPatternTrack methods ***/
#define IDirectMusicPatternTrack_CreateSegment(p,a,b)          (p)->lpVtbl->CreateSegment(p,a,b)
#define IDirectMusicPatternTrack_SetVariation(p,a,b,c)         (p)->lpVtbl->SetVariation(p,a,b,c)
#define IDirectMusicPatternTrack_SetPatternByName(p,a,b,c,d,e) (p)->lpVtbl->SetPatternByName(p,a,b,c,d,e)
#endif


/*****************************************************************************
 * IDirectMusicScript interface
 */
#define INTERFACE IDirectMusicScript
DECLARE_INTERFACE_(IDirectMusicScript,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicScript methods ***/
    STDMETHOD(Init)(THIS_ IDirectMusicPerformance *pPerformance, DMUS_SCRIPT_ERRORINFO *pErrorInfo) PURE;
    STDMETHOD(CallRoutine)(THIS_ WCHAR *pwszRoutineName, DMUS_SCRIPT_ERRORINFO *pErrorInfo) PURE;
    STDMETHOD(SetVariableVariant)(THIS_ WCHAR *pwszVariableName, VARIANT varValue, WINBOOL fSetRef, DMUS_SCRIPT_ERRORINFO *pErrorInfo) PURE;
    STDMETHOD(GetVariableVariant)(THIS_ WCHAR *pwszVariableName, VARIANT *pvarValue, DMUS_SCRIPT_ERRORINFO *pErrorInfo) PURE;
    STDMETHOD(SetVariableNumber)(THIS_ WCHAR *pwszVariableName, LONG lValue, DMUS_SCRIPT_ERRORINFO *pErrorInfo) PURE;
    STDMETHOD(GetVariableNumber)(THIS_ WCHAR *pwszVariableName, LONG *plValue, DMUS_SCRIPT_ERRORINFO *pErrorInfo) PURE;
    STDMETHOD(SetVariableObject)(THIS_ WCHAR *pwszVariableName, IUnknown *punkValue, DMUS_SCRIPT_ERRORINFO *pErrorInfo) PURE;
    STDMETHOD(GetVariableObject)(THIS_ WCHAR *pwszVariableName, REFIID riid, LPVOID *ppv, DMUS_SCRIPT_ERRORINFO *pErrorInfo) PURE;
    STDMETHOD(EnumRoutine)(THIS_ DWORD dwIndex, WCHAR *pwszName) PURE;
    STDMETHOD(EnumVariable)(THIS_ DWORD dwIndex, WCHAR *pwszName) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicScript_QueryInterface(p,a,b)               (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicScript_AddRef(p)                           (p)->lpVtbl->AddRef(p)
#define IDirectMusicScript_Release(p)                          (p)->lpVtbl->Release(p)
/*** IDirectMusicScript methods ***/
#define IDirectMusicPatternTrack_Init(p,a,b)                   (p)->lpVtbl->Init(p,a,b)
#define IDirectMusicPatternTrack_CallRoutine(p,a,b)            (p)->lpVtbl->CallRoutine(p,a,b)
#define IDirectMusicPatternTrack_SetVariableVariant(p,a,b,c,d) (p)->lpVtbl->SetVariableVariant(p,a,b,c,d)
#define IDirectMusicPatternTrack_GetVariableVariant(p,a,b,c)   (p)->lpVtbl->GetVariableVariant(p,a,b,c)
#define IDirectMusicPatternTrack_SetVariableNumber(p,a,b,c)    (p)->lpVtbl->SetVariableNumber(p,a,b,c)
#define IDirectMusicPatternTrack_GetVariableNumber(p,a,b,c)    (p)->lpVtbl->GetVariableNumber(p,a,b,c)
#define IDirectMusicPatternTrack_SetVariableObject(p,a,b,c)    (p)->lpVtbl->SetVariableObject(p,a,b,c)
#define IDirectMusicPatternTrack_GetVariableObject(p,a,b,c,d)  (p)->lpVtbl->GetVariableObject(p,a,b,c,d)
#define IDirectMusicPatternTrack_EnumRoutine(p,a,b)            (p)->lpVtbl->EnumRoutine(p,a,b)
#define IDirectMusicPatternTrack_EnumVariable(p,a,b)           (p)->lpVtbl->EnumVariable(p,a,b)
#endif


/*****************************************************************************
 * IDirectMusicContainer interface
 */
#define INTERFACE IDirectMusicContainer
DECLARE_INTERFACE_(IDirectMusicContainer,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectMusicContainer methods ***/
    STDMETHOD(EnumObject)(THIS_ REFGUID rguidClass, DWORD dwIndex, LPDMUS_OBJECTDESC pDesc, WCHAR *pwszAlias) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectMusicContainer_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectMusicContainer_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectMusicContainer_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectMusicContainer methods ***/
#define IDirectMusicContainer_EnumObject(p,a,b,c,d) (p)->lpVtbl->EnumObject(p,a,b,c,d)
#endif


#ifdef __cplusplus
}
#endif

#pragma pack(pop)

#endif /* __WINE_DMUSIC_PERFORMANCE_H */
