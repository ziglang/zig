/*
 * Copyright (c) 2007-2009 The Khronos Group Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and /or associated documentation files (the "Materials "), to
 * deal in the Materials without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Materials, and to permit persons to whom the Materials are
 * furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * in all copies or substantial portions of the Materials.
 *
 * THE MATERIALS ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE MATERIALS OR THE USE OR OTHER DEALINGS IN THE
 * MATERIALS.
 *
 * OpenSLES.h - OpenSL ES version 1.0.1
 *
 */

/****************************************************************************/
/* NOTE: This file is a standard OpenSL ES header file and should not be    */
/* modified in any way.                                                     */
/****************************************************************************/

#ifndef OPENSL_ES_H_
#define OPENSL_ES_H_

#ifdef __cplusplus
extern "C" {
#endif

#include "OpenSLES_Platform.h"


/*****************************************************************************/
/* Common types, structures, and defines                                */
/*****************************************************************************/

#ifndef _KHRONOS_KEYS_
#define _KHRONOS_KEYS_

#define KHRONOS_TITLE "KhronosTitle"
#define KHRONOS_ALBUM "KhronosAlbum"
#define KHRONOS_TRACK_NUMBER "KhronosTrackNumber"
#define KHRONOS_ARTIST "KhronosArtist"
#define KHRONOS_GENRE "KhronosGenre"
#define KHRONOS_YEAR "KhronosYear"
#define KHRONOS_COMMENT "KhronosComment"
#define KHRONOS_ARTIST_URL "KhronosArtistURL"
#define KHRONOS_CONTENT_URL "KhronosContentURL"
#define KHRONOS_RATING "KhronosRating"
#define KHRONOS_ALBUM_ART "KhronosAlbumArt"
#define KHRONOS_COPYRIGHT "KhronosCopyright"

#endif


/* remap common types to SL types for clarity */
typedef sl_int8_t              SLint8;          /* 8 bit signed integer  */
typedef sl_uint8_t             SLuint8;         /* 8 bit unsigned integer */
typedef sl_int16_t             SLint16;         /* 16 bit signed integer */
typedef sl_uint16_t            SLuint16;        /* 16 bit unsigned integer */
typedef sl_int32_t             SLint32;           /* 32 bit signed integer */
typedef sl_uint32_t            SLuint32;          /* 32 bit unsigned integer */

typedef SLuint32                    SLboolean;
#define SL_BOOLEAN_FALSE            ((SLboolean) 0x00000000)
#define SL_BOOLEAN_TRUE             ((SLboolean) 0x00000001)

typedef SLuint8						SLchar;			/* UTF-8 is to be used */
typedef SLint16						SLmillibel;
typedef SLuint32					SLmillisecond;
typedef SLuint32					SLmilliHertz;
typedef SLint32						SLmillimeter;
typedef SLint32						SLmillidegree;
typedef SLint16						SLpermille;
typedef SLuint32					SLmicrosecond;
typedef SLuint32					SLresult;

#define SL_MILLIBEL_MAX 	((SLmillibel) 0x7FFF)
#define SL_MILLIBEL_MIN 	((SLmillibel) (-SL_MILLIBEL_MAX-1))

#define SL_MILLIHERTZ_MAX	((SLmilliHertz) 0xFFFFFFFF)
#define SL_MILLIMETER_MAX	((SLmillimeter) 0x7FFFFFFF)

/** Interface ID defined as a UUID */
typedef const struct SLInterfaceID_ {
    SLuint32 time_low;
    SLuint16 time_mid;
    SLuint16 time_hi_and_version;
    SLuint16 clock_seq;
    SLuint8  node[6];
} * SLInterfaceID;

/* Forward declaration for the object interface */
struct SLObjectItf_;

typedef const struct SLObjectItf_ * const * SLObjectItf;

/* Objects ID's */

#define SL_OBJECTID_ENGINE			((SLuint32) 0x00001001)
#define SL_OBJECTID_LEDDEVICE		((SLuint32) 0x00001002)
#define SL_OBJECTID_VIBRADEVICE		((SLuint32) 0x00001003)
#define SL_OBJECTID_AUDIOPLAYER		((SLuint32) 0x00001004)
#define SL_OBJECTID_AUDIORECORDER	((SLuint32) 0x00001005)
#define SL_OBJECTID_MIDIPLAYER		((SLuint32) 0x00001006)
#define SL_OBJECTID_LISTENER		((SLuint32) 0x00001007)
#define SL_OBJECTID_3DGROUP			((SLuint32) 0x00001008)
#define SL_OBJECTID_OUTPUTMIX		((SLuint32) 0x00001009)
#define SL_OBJECTID_METADATAEXTRACTOR	((SLuint32) 0x0000100A)


/* SL Profiles */

#define SL_PROFILES_PHONE	((SLuint16) 0x0001)
#define SL_PROFILES_MUSIC	((SLuint16) 0x0002)
#define SL_PROFILES_GAME	((SLuint16) 0x0004)

/* Types of voices supported by the system */

#define SL_VOICETYPE_2D_AUDIO		((SLuint16) 0x0001)
#define SL_VOICETYPE_MIDI			((SLuint16) 0x0002)
#define SL_VOICETYPE_3D_AUDIO 		((SLuint16) 0x0004)
#define SL_VOICETYPE_3D_MIDIOUTPUT 	((SLuint16) 0x0008)

/* Convenient macros representing various different priority levels, for use with the SetPriority method */

#define SL_PRIORITY_LOWEST		((SLint32) (-0x7FFFFFFF-1))
#define SL_PRIORITY_VERYLOW		((SLint32) -0x60000000)
#define SL_PRIORITY_LOW			((SLint32) -0x40000000)
#define SL_PRIORITY_BELOWNORMAL	((SLint32) -0x20000000)
#define SL_PRIORITY_NORMAL		((SLint32) 0x00000000)
#define SL_PRIORITY_ABOVENORMAL	((SLint32) 0x20000000)
#define SL_PRIORITY_HIGH		((SLint32) 0x40000000)
#define SL_PRIORITY_VERYHIGH	((SLint32) 0x60000000)
#define SL_PRIORITY_HIGHEST	((SLint32) 0x7FFFFFFF)


/** These macros list the various sample formats that are possible on audio input and output devices. */

#define SL_PCMSAMPLEFORMAT_FIXED_8	((SLuint16) 0x0008)
#define SL_PCMSAMPLEFORMAT_FIXED_16	((SLuint16) 0x0010)
#define SL_PCMSAMPLEFORMAT_FIXED_20 	((SLuint16) 0x0014)
#define SL_PCMSAMPLEFORMAT_FIXED_24	((SLuint16) 0x0018)
#define SL_PCMSAMPLEFORMAT_FIXED_28 	((SLuint16) 0x001C)
#define SL_PCMSAMPLEFORMAT_FIXED_32	((SLuint16) 0x0020)


/** These macros specify the commonly used sampling rates (in milliHertz) supported by most audio I/O devices. */

#define SL_SAMPLINGRATE_8		((SLuint32) 8000000)
#define SL_SAMPLINGRATE_11_025	((SLuint32) 11025000)
#define SL_SAMPLINGRATE_12		((SLuint32) 12000000)
#define SL_SAMPLINGRATE_16		((SLuint32) 16000000)
#define SL_SAMPLINGRATE_22_05	((SLuint32) 22050000)
#define SL_SAMPLINGRATE_24		((SLuint32) 24000000)
#define SL_SAMPLINGRATE_32		((SLuint32) 32000000)
#define SL_SAMPLINGRATE_44_1	((SLuint32) 44100000)
#define SL_SAMPLINGRATE_48		((SLuint32) 48000000)
#define SL_SAMPLINGRATE_64		((SLuint32) 64000000)
#define SL_SAMPLINGRATE_88_2	((SLuint32) 88200000)
#define SL_SAMPLINGRATE_96		((SLuint32) 96000000)
#define SL_SAMPLINGRATE_192	((SLuint32) 192000000)

#define SL_SPEAKER_FRONT_LEFT			((SLuint32) 0x00000001)
#define SL_SPEAKER_FRONT_RIGHT			((SLuint32) 0x00000002)
#define SL_SPEAKER_FRONT_CENTER			((SLuint32) 0x00000004)
#define SL_SPEAKER_LOW_FREQUENCY			((SLuint32) 0x00000008)
#define SL_SPEAKER_BACK_LEFT			((SLuint32) 0x00000010)
#define SL_SPEAKER_BACK_RIGHT			((SLuint32) 0x00000020)
#define SL_SPEAKER_FRONT_LEFT_OF_CENTER	((SLuint32) 0x00000040)
#define SL_SPEAKER_FRONT_RIGHT_OF_CENTER	((SLuint32) 0x00000080)
#define SL_SPEAKER_BACK_CENTER			((SLuint32) 0x00000100)
#define SL_SPEAKER_SIDE_LEFT			((SLuint32) 0x00000200)
#define SL_SPEAKER_SIDE_RIGHT			((SLuint32) 0x00000400)
#define SL_SPEAKER_TOP_CENTER			((SLuint32) 0x00000800)
#define SL_SPEAKER_TOP_FRONT_LEFT		((SLuint32) 0x00001000)
#define SL_SPEAKER_TOP_FRONT_CENTER		((SLuint32) 0x00002000)
#define SL_SPEAKER_TOP_FRONT_RIGHT		((SLuint32) 0x00004000)
#define SL_SPEAKER_TOP_BACK_LEFT			((SLuint32) 0x00008000)
#define SL_SPEAKER_TOP_BACK_CENTER		((SLuint32) 0x00010000)
#define SL_SPEAKER_TOP_BACK_RIGHT		((SLuint32) 0x00020000)


/*****************************************************************************/
/* Errors                                                                    */
/*                                                                           */
/*****************************************************************************/

#define SL_RESULT_SUCCESS				((SLuint32) 0x00000000)
#define SL_RESULT_PRECONDITIONS_VIOLATED	((SLuint32) 0x00000001)
#define SL_RESULT_PARAMETER_INVALID		((SLuint32) 0x00000002)
#define SL_RESULT_MEMORY_FAILURE			((SLuint32) 0x00000003)
#define SL_RESULT_RESOURCE_ERROR			((SLuint32) 0x00000004)
#define SL_RESULT_RESOURCE_LOST			((SLuint32) 0x00000005)
#define SL_RESULT_IO_ERROR				((SLuint32) 0x00000006)
#define SL_RESULT_BUFFER_INSUFFICIENT		((SLuint32) 0x00000007)
#define SL_RESULT_CONTENT_CORRUPTED		((SLuint32) 0x00000008)
#define SL_RESULT_CONTENT_UNSUPPORTED		((SLuint32) 0x00000009)
#define SL_RESULT_CONTENT_NOT_FOUND		((SLuint32) 0x0000000A)
#define SL_RESULT_PERMISSION_DENIED		((SLuint32) 0x0000000B)
#define SL_RESULT_FEATURE_UNSUPPORTED		((SLuint32) 0x0000000C)
#define SL_RESULT_INTERNAL_ERROR			((SLuint32) 0x0000000D)
#define SL_RESULT_UNKNOWN_ERROR			((SLuint32) 0x0000000E)
#define SL_RESULT_OPERATION_ABORTED		((SLuint32) 0x0000000F)
#define SL_RESULT_CONTROL_LOST			((SLuint32) 0x00000010)


/* Object state definitions */

#define SL_OBJECT_STATE_UNREALIZED	((SLuint32) 0x00000001)
#define SL_OBJECT_STATE_REALIZED		((SLuint32) 0x00000002)
#define SL_OBJECT_STATE_SUSPENDED	((SLuint32) 0x00000003)

/* Object event definitions */

#define SL_OBJECT_EVENT_RUNTIME_ERROR			((SLuint32) 0x00000001)
#define SL_OBJECT_EVENT_ASYNC_TERMINATION		((SLuint32) 0x00000002)
#define SL_OBJECT_EVENT_RESOURCES_LOST			((SLuint32) 0x00000003)
#define SL_OBJECT_EVENT_RESOURCES_AVAILABLE		((SLuint32) 0x00000004)
#define SL_OBJECT_EVENT_ITF_CONTROL_TAKEN		((SLuint32) 0x00000005)
#define SL_OBJECT_EVENT_ITF_CONTROL_RETURNED		((SLuint32) 0x00000006)
#define SL_OBJECT_EVENT_ITF_PARAMETERS_CHANGED	((SLuint32) 0x00000007)


/*****************************************************************************/
/* Interface definitions                                                     */
/*****************************************************************************/

/** NULL Interface */

extern const SLInterfaceID SL_IID_NULL;

/*---------------------------------------------------------------------------*/
/* Data Source and Data Sink Structures                                      */
/*---------------------------------------------------------------------------*/

/** Data locator macros  */
#define SL_DATALOCATOR_URI			((SLuint32) 0x00000001)
#define SL_DATALOCATOR_ADDRESS		((SLuint32) 0x00000002)
#define SL_DATALOCATOR_IODEVICE		((SLuint32) 0x00000003)
#define SL_DATALOCATOR_OUTPUTMIX		((SLuint32) 0x00000004)
#define SL_DATALOCATOR_RESERVED5		((SLuint32) 0x00000005)
#define SL_DATALOCATOR_BUFFERQUEUE	((SLuint32) 0x00000006)
#define SL_DATALOCATOR_MIDIBUFFERQUEUE	((SLuint32) 0x00000007)
#define SL_DATALOCATOR_RESERVED8		((SLuint32) 0x00000008)



/** URI-based data locator definition where locatorType must be SL_DATALOCATOR_URI*/
typedef struct SLDataLocator_URI_ {
	SLuint32 		locatorType;
	SLchar *		URI;
} SLDataLocator_URI;

/** Address-based data locator definition where locatorType must be SL_DATALOCATOR_ADDRESS*/
typedef struct SLDataLocator_Address_ {
	SLuint32 	locatorType;
	void 		*pAddress;
	SLuint32	length;
} SLDataLocator_Address;

/** IODevice-types */
#define SL_IODEVICE_AUDIOINPUT	((SLuint32) 0x00000001)
#define SL_IODEVICE_LEDARRAY	((SLuint32) 0x00000002)
#define SL_IODEVICE_VIBRA		((SLuint32) 0x00000003)
#define SL_IODEVICE_RESERVED4	((SLuint32) 0x00000004)
#define SL_IODEVICE_RESERVED5	((SLuint32) 0x00000005)

/** IODevice-based data locator definition where locatorType must be SL_DATALOCATOR_IODEVICE*/
typedef struct SLDataLocator_IODevice_ {
	SLuint32	locatorType;
	SLuint32	deviceType;
	SLuint32	deviceID;
	SLObjectItf	device;
} SLDataLocator_IODevice;

/** OutputMix-based data locator definition where locatorType must be SL_DATALOCATOR_OUTPUTMIX*/
typedef struct SLDataLocator_OutputMix {
	SLuint32 		locatorType;
	SLObjectItf		outputMix;
} SLDataLocator_OutputMix;


/** BufferQueue-based data locator definition where locatorType must be SL_DATALOCATOR_BUFFERQUEUE*/
typedef struct SLDataLocator_BufferQueue {
	SLuint32	locatorType;
	SLuint32	numBuffers;
} SLDataLocator_BufferQueue;

/** MidiBufferQueue-based data locator definition where locatorType must be SL_DATALOCATOR_MIDIBUFFERQUEUE*/
typedef struct SLDataLocator_MIDIBufferQueue {
	SLuint32	locatorType;
	SLuint32	tpqn;
	SLuint32	numBuffers;
} SLDataLocator_MIDIBufferQueue;

/** Data format defines */
#define SL_DATAFORMAT_MIME		((SLuint32) 0x00000001)
#define SL_DATAFORMAT_PCM		((SLuint32) 0x00000002)
#define SL_DATAFORMAT_RESERVED3	((SLuint32) 0x00000003)


/** MIME-type-based data format definition where formatType must be SL_DATAFORMAT_MIME*/
typedef struct SLDataFormat_MIME_ {
	SLuint32 		formatType;
	SLchar * 		mimeType;
	SLuint32		containerType;
} SLDataFormat_MIME;

/* Byte order of a block of 16- or 32-bit data */
#define SL_BYTEORDER_BIGENDIAN				((SLuint32) 0x00000001)
#define SL_BYTEORDER_LITTLEENDIAN			((SLuint32) 0x00000002)

/* Container type */
#define SL_CONTAINERTYPE_UNSPECIFIED	((SLuint32) 0x00000001)
#define SL_CONTAINERTYPE_RAW		((SLuint32) 0x00000002)
#define SL_CONTAINERTYPE_ASF		((SLuint32) 0x00000003)
#define SL_CONTAINERTYPE_AVI		((SLuint32) 0x00000004)
#define SL_CONTAINERTYPE_BMP		((SLuint32) 0x00000005)
#define SL_CONTAINERTYPE_JPG		((SLuint32) 0x00000006)
#define SL_CONTAINERTYPE_JPG2000		((SLuint32) 0x00000007)
#define SL_CONTAINERTYPE_M4A		((SLuint32) 0x00000008)
#define SL_CONTAINERTYPE_MP3		((SLuint32) 0x00000009)
#define SL_CONTAINERTYPE_MP4		((SLuint32) 0x0000000A)
#define SL_CONTAINERTYPE_MPEG_ES		((SLuint32) 0x0000000B)
#define SL_CONTAINERTYPE_MPEG_PS		((SLuint32) 0x0000000C)
#define SL_CONTAINERTYPE_MPEG_TS		((SLuint32) 0x0000000D)
#define SL_CONTAINERTYPE_QT		((SLuint32) 0x0000000E)
#define SL_CONTAINERTYPE_WAV		((SLuint32) 0x0000000F)
#define SL_CONTAINERTYPE_XMF_0		((SLuint32) 0x00000010)
#define SL_CONTAINERTYPE_XMF_1		((SLuint32) 0x00000011)
#define SL_CONTAINERTYPE_XMF_2		((SLuint32) 0x00000012)
#define SL_CONTAINERTYPE_XMF_3		((SLuint32) 0x00000013)
#define SL_CONTAINERTYPE_XMF_GENERIC	((SLuint32) 0x00000014)
#define SL_CONTAINERTYPE_AMR  		((SLuint32) 0x00000015)
#define SL_CONTAINERTYPE_AAC		((SLuint32) 0x00000016)
#define SL_CONTAINERTYPE_3GPP		((SLuint32) 0x00000017)
#define SL_CONTAINERTYPE_3GA		((SLuint32) 0x00000018)
#define SL_CONTAINERTYPE_RM		((SLuint32) 0x00000019)
#define SL_CONTAINERTYPE_DMF		((SLuint32) 0x0000001A)
#define SL_CONTAINERTYPE_SMF		((SLuint32) 0x0000001B)
#define SL_CONTAINERTYPE_MOBILE_DLS	((SLuint32) 0x0000001C)
#define SL_CONTAINERTYPE_OGG	((SLuint32) 0x0000001D)


/** PCM-type-based data format definition where formatType must be SL_DATAFORMAT_PCM*/
typedef struct SLDataFormat_PCM_ {
	SLuint32 		formatType;
	SLuint32 		numChannels;
	SLuint32 		samplesPerSec;
	SLuint32 		bitsPerSample;
	SLuint32 		containerSize;
	SLuint32 		channelMask;
	SLuint32		endianness;
} SLDataFormat_PCM;

typedef struct SLDataSource_ {
	void *pLocator;
	void *pFormat;
} SLDataSource;


typedef struct SLDataSink_ {
	void *pLocator;
	void *pFormat;
} SLDataSink;






/*---------------------------------------------------------------------------*/
/* Standard Object Interface                                                 */
/*---------------------------------------------------------------------------*/

extern const SLInterfaceID SL_IID_OBJECT;

/** Object callback */


typedef void (SLAPIENTRY *slObjectCallback) (
	SLObjectItf caller,
	const void * pContext,
	SLuint32 event,
	SLresult result,
    SLuint32 param,
    void *pInterface
);


struct SLObjectItf_ {
	SLresult (*Realize) (
		SLObjectItf self,
		SLboolean async
	);
	SLresult (*Resume) (
		SLObjectItf self,
		SLboolean async
	);
	SLresult (*GetState) (
		SLObjectItf self,
		SLuint32 * pState
	);
	SLresult (*GetInterface) (
		SLObjectItf self,
		const SLInterfaceID iid,
		void * pInterface
	);
	SLresult (*RegisterCallback) (
		SLObjectItf self,
		slObjectCallback callback,
		void * pContext
	);
	void (*AbortAsyncOperation) (
		SLObjectItf self
	);
	void (*Destroy) (
		SLObjectItf self
	);
	SLresult (*SetPriority) (
		SLObjectItf self,
		SLint32 priority,
		SLboolean preemptable
	);
	SLresult (*GetPriority) (
		SLObjectItf self,
		SLint32 *pPriority,
		SLboolean *pPreemptable
	);
	SLresult (*SetLossOfControlInterfaces) (
		SLObjectItf self,
		SLint16 numInterfaces,
		SLInterfaceID * pInterfaceIDs,
		SLboolean enabled
	);
};


/*---------------------------------------------------------------------------*/
/* Audio IO Device capabilities interface                                    */
/*---------------------------------------------------------------------------*/

#define SL_DEFAULTDEVICEID_AUDIOINPUT 	((SLuint32) 0xFFFFFFFF)
#define SL_DEFAULTDEVICEID_AUDIOOUTPUT 	((SLuint32) 0xFFFFFFFE)
#define SL_DEFAULTDEVICEID_LED          ((SLuint32) 0xFFFFFFFD)
#define SL_DEFAULTDEVICEID_VIBRA        ((SLuint32) 0xFFFFFFFC)
#define SL_DEFAULTDEVICEID_RESERVED1    ((SLuint32) 0xFFFFFFFB)


#define SL_DEVCONNECTION_INTEGRATED         ((SLint16) 0x0001)
#define SL_DEVCONNECTION_ATTACHED_WIRED     ((SLint16) 0x0100)
#define SL_DEVCONNECTION_ATTACHED_WIRELESS  ((SLint16) 0x0200)
#define SL_DEVCONNECTION_NETWORK 		    ((SLint16) 0x0400)


#define SL_DEVLOCATION_HANDSET 	((SLuint16) 0x0001)
#define SL_DEVLOCATION_HEADSET 	((SLuint16) 0x0002)
#define SL_DEVLOCATION_CARKIT 	((SLuint16) 0x0003)
#define SL_DEVLOCATION_DOCK 	((SLuint16) 0x0004)
#define SL_DEVLOCATION_REMOTE 	((SLuint16) 0x0005)
/* Note: SL_DEVLOCATION_RESLTE is deprecated, use SL_DEVLOCATION_REMOTE instead. */
#define SL_DEVLOCATION_RESLTE 	((SLuint16) 0x0005)


#define SL_DEVSCOPE_UNKNOWN     ((SLuint16) 0x0001)
#define SL_DEVSCOPE_ENVIRONMENT ((SLuint16) 0x0002)
#define SL_DEVSCOPE_USER        ((SLuint16) 0x0003)


typedef struct SLAudioInputDescriptor_ {
	SLchar *deviceName;
	SLint16 deviceConnection;
	SLint16 deviceScope;
	SLint16 deviceLocation;
	SLboolean isForTelephony;
	SLmilliHertz minSampleRate;
	SLmilliHertz maxSampleRate;
	SLboolean isFreqRangeContinuous;
	SLmilliHertz *samplingRatesSupported;
	SLint16 numOfSamplingRatesSupported;
	SLint16 maxChannels;
} SLAudioInputDescriptor;


typedef struct SLAudioOutputDescriptor_ {
	SLchar *pDeviceName;
	SLint16 deviceConnection;
	SLint16 deviceScope;
	SLint16 deviceLocation;
	SLboolean isForTelephony;
	SLmilliHertz minSampleRate;
	SLmilliHertz maxSampleRate;
	SLboolean isFreqRangeContinuous;
	SLmilliHertz *samplingRatesSupported;
	SLint16 numOfSamplingRatesSupported;
	SLint16 maxChannels;
} SLAudioOutputDescriptor;



extern const SLInterfaceID SL_IID_AUDIOIODEVICECAPABILITIES;

struct SLAudioIODeviceCapabilitiesItf_;
typedef const struct SLAudioIODeviceCapabilitiesItf_ * const * SLAudioIODeviceCapabilitiesItf;


typedef void (SLAPIENTRY *slAvailableAudioInputsChangedCallback) (
	SLAudioIODeviceCapabilitiesItf caller,
	void *pContext,
	SLuint32 deviceID,
	SLint32 numInputs,
	SLboolean isNew
);


typedef void (SLAPIENTRY *slAvailableAudioOutputsChangedCallback) (
	SLAudioIODeviceCapabilitiesItf caller,
	void *pContext,
	SLuint32 deviceID,
	SLint32 numOutputs,
	SLboolean isNew
);

typedef void (SLAPIENTRY *slDefaultDeviceIDMapChangedCallback) (
	SLAudioIODeviceCapabilitiesItf caller,
	void *pContext,
	SLboolean isOutput,
	SLint32 numDevices
);


struct SLAudioIODeviceCapabilitiesItf_ {
	SLresult (*GetAvailableAudioInputs)(
		SLAudioIODeviceCapabilitiesItf self,
		SLint32  *pNumInputs,
		SLuint32 *pInputDeviceIDs
	);
	SLresult (*QueryAudioInputCapabilities)(
		SLAudioIODeviceCapabilitiesItf self,
		SLuint32 deviceId,
		SLAudioInputDescriptor *pDescriptor
	);
	SLresult (*RegisterAvailableAudioInputsChangedCallback) (
		SLAudioIODeviceCapabilitiesItf self,
		slAvailableAudioInputsChangedCallback callback,
		void *pContext
	);
	SLresult (*GetAvailableAudioOutputs)(
		SLAudioIODeviceCapabilitiesItf self,
		SLint32 *pNumOutputs,
		SLuint32 *pOutputDeviceIDs
	);
	SLresult (*QueryAudioOutputCapabilities)(
		SLAudioIODeviceCapabilitiesItf self,
		SLuint32 deviceId,
		SLAudioOutputDescriptor *pDescriptor
	);
	SLresult (*RegisterAvailableAudioOutputsChangedCallback) (
		SLAudioIODeviceCapabilitiesItf self,
		slAvailableAudioOutputsChangedCallback callback,
		void *pContext
	);
	SLresult (*RegisterDefaultDeviceIDMapChangedCallback) (
		SLAudioIODeviceCapabilitiesItf self,
		slDefaultDeviceIDMapChangedCallback callback,
		void *pContext
	);
	SLresult (*GetAssociatedAudioInputs) (
		SLAudioIODeviceCapabilitiesItf self,
		SLuint32 deviceId,
		SLint32 *pNumAudioInputs,
		SLuint32 *pAudioInputDeviceIDs
	);
	SLresult (*GetAssociatedAudioOutputs) (
		SLAudioIODeviceCapabilitiesItf self,
		SLuint32 deviceId,
		SLint32 *pNumAudioOutputs,
		SLuint32 *pAudioOutputDeviceIDs
	);
	SLresult (*GetDefaultAudioDevices) (
		SLAudioIODeviceCapabilitiesItf self,
		SLuint32 defaultDeviceID,
		SLint32 *pNumAudioDevices,
		SLuint32 *pAudioDeviceIDs
	);
	SLresult (*QuerySampleFormatsSupported)(
		SLAudioIODeviceCapabilitiesItf self,
		SLuint32 deviceId,
		SLmilliHertz samplingRate,
		SLint32 *pSampleFormats,
		SLint32 *pNumOfSampleFormats
	);
};



/*---------------------------------------------------------------------------*/
/* Capabilities of the LED array IODevice                                    */
/*---------------------------------------------------------------------------*/

typedef struct SLLEDDescriptor_ {
	SLuint8   ledCount;
	SLuint8   primaryLED;
	SLuint32  colorMask;
} SLLEDDescriptor;


/*---------------------------------------------------------------------------*/
/* LED Array interface                                                       */
/*---------------------------------------------------------------------------*/

typedef struct SLHSL_ {
    SLmillidegree  hue;
    SLpermille     saturation;
    SLpermille     lightness;
} SLHSL;


extern const SLInterfaceID SL_IID_LED;

struct SLLEDArrayItf_;
typedef const struct SLLEDArrayItf_ * const * SLLEDArrayItf;

struct SLLEDArrayItf_ {
	SLresult (*ActivateLEDArray) (
		SLLEDArrayItf self,
		SLuint32 lightMask
	);
	SLresult (*IsLEDArrayActivated) (
		SLLEDArrayItf self,
		SLuint32 *lightMask
	);
	SLresult (*SetColor) (
		SLLEDArrayItf self,
		SLuint8 index,
		const SLHSL *color
	);
	SLresult (*GetColor) (
		SLLEDArrayItf self,
		SLuint8 index,
		SLHSL *color
	);
};

/*---------------------------------------------------------------------------*/
/* Capabilities of the Vibra IODevice                                        */
/*---------------------------------------------------------------------------*/

typedef struct SLVibraDescriptor_ {
	SLboolean supportsFrequency;
	SLboolean supportsIntensity;
	SLmilliHertz  minFrequency;
	SLmilliHertz  maxFrequency;
} SLVibraDescriptor;



/*---------------------------------------------------------------------------*/
/* Vibra interface                                                           */
/*---------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_VIBRA;


struct SLVibraItf_;
typedef const struct SLVibraItf_ * const * SLVibraItf;

struct SLVibraItf_ {
	SLresult (*Vibrate) (
		SLVibraItf self,
		SLboolean vibrate
	);
	SLresult (*IsVibrating) (
		SLVibraItf self,
		SLboolean *pVibrating
	);
	SLresult (*SetFrequency) (
		SLVibraItf self,
		SLmilliHertz frequency
	);
	SLresult (*GetFrequency) (
		SLVibraItf self,
		SLmilliHertz *pFrequency
	);
	SLresult (*SetIntensity) (
		SLVibraItf self,
		SLpermille intensity
	);
	SLresult (*GetIntensity) (
		SLVibraItf self,
		SLpermille *pIntensity
	);
};


/*---------------------------------------------------------------------------*/
/* Meta data extraction related types and interface                          */
/*---------------------------------------------------------------------------*/

#define SL_CHARACTERENCODING_UNKNOWN			((SLuint32) 0x00000000)
#define SL_CHARACTERENCODING_BINARY       ((SLuint32) 0x00000001)
#define SL_CHARACTERENCODING_ASCII        ((SLuint32) 0x00000002)
#define SL_CHARACTERENCODING_BIG5         ((SLuint32) 0x00000003)
#define SL_CHARACTERENCODING_CODEPAGE1252		((SLuint32) 0x00000004)
#define SL_CHARACTERENCODING_GB2312			((SLuint32) 0x00000005)
#define SL_CHARACTERENCODING_HZGB2312			((SLuint32) 0x00000006)
#define SL_CHARACTERENCODING_GB12345			((SLuint32) 0x00000007)
#define SL_CHARACTERENCODING_GB18030			((SLuint32) 0x00000008)
#define SL_CHARACTERENCODING_GBK				((SLuint32) 0x00000009)
#define SL_CHARACTERENCODING_IMAPUTF7			((SLuint32) 0x0000000A)
#define SL_CHARACTERENCODING_ISO2022JP			((SLuint32) 0x0000000B)
#define SL_CHARACTERENCODING_ISO2022JP1		((SLuint32) 0x0000000B)
#define SL_CHARACTERENCODING_ISO88591			((SLuint32) 0x0000000C)
#define SL_CHARACTERENCODING_ISO885910			((SLuint32) 0x0000000D)
#define SL_CHARACTERENCODING_ISO885913			((SLuint32) 0x0000000E)
#define SL_CHARACTERENCODING_ISO885914			((SLuint32) 0x0000000F)
#define SL_CHARACTERENCODING_ISO885915			((SLuint32) 0x00000010)
#define SL_CHARACTERENCODING_ISO88592			((SLuint32) 0x00000011)
#define SL_CHARACTERENCODING_ISO88593			((SLuint32) 0x00000012)
#define SL_CHARACTERENCODING_ISO88594			((SLuint32) 0x00000013)
#define SL_CHARACTERENCODING_ISO88595			((SLuint32) 0x00000014)
#define SL_CHARACTERENCODING_ISO88596			((SLuint32) 0x00000015)
#define SL_CHARACTERENCODING_ISO88597			((SLuint32) 0x00000016)
#define SL_CHARACTERENCODING_ISO88598			((SLuint32) 0x00000017)
#define SL_CHARACTERENCODING_ISO88599			((SLuint32) 0x00000018)
#define SL_CHARACTERENCODING_ISOEUCJP			((SLuint32) 0x00000019)
#define SL_CHARACTERENCODING_SHIFTJIS			((SLuint32) 0x0000001A)
#define SL_CHARACTERENCODING_SMS7BIT			((SLuint32) 0x0000001B)
#define SL_CHARACTERENCODING_UTF7			((SLuint32) 0x0000001C)
#define SL_CHARACTERENCODING_UTF8			((SLuint32) 0x0000001D)
#define SL_CHARACTERENCODING_JAVACONFORMANTUTF8	((SLuint32) 0x0000001E)
#define SL_CHARACTERENCODING_UTF16BE			((SLuint32) 0x0000001F)
#define SL_CHARACTERENCODING_UTF16LE			((SLuint32) 0x00000020)


#define SL_METADATA_FILTER_KEY		((SLuint8) 0x01)
#define SL_METADATA_FILTER_LANG		((SLuint8) 0x02)
#define SL_METADATA_FILTER_ENCODING	((SLuint8) 0x04)


typedef struct SLMetadataInfo_ {
    SLuint32     size;
    SLuint32     encoding;
    SLchar       langCountry[16];
    SLuint8      data[1];
} SLMetadataInfo;

extern const SLInterfaceID SL_IID_METADATAEXTRACTION;

struct SLMetadataExtractionItf_;
typedef const struct SLMetadataExtractionItf_ * const * SLMetadataExtractionItf;


struct SLMetadataExtractionItf_ {
	SLresult (*GetItemCount) (
		SLMetadataExtractionItf self,
		SLuint32 *pItemCount
	);
	SLresult (*GetKeySize) (
		SLMetadataExtractionItf self,
		SLuint32 index,
		SLuint32 *pKeySize
	);
	SLresult (*GetKey) (
		SLMetadataExtractionItf self,
		SLuint32 index,
		SLuint32 keySize,
		SLMetadataInfo *pKey
	);
	SLresult (*GetValueSize) (
		SLMetadataExtractionItf self,
		SLuint32 index,
		SLuint32 *pValueSize
	);
	SLresult (*GetValue) (
		SLMetadataExtractionItf self,
		SLuint32 index,
		SLuint32 valueSize,
		SLMetadataInfo *pValue
	);
	SLresult (*AddKeyFilter) (
		SLMetadataExtractionItf self,
		SLuint32 keySize,
		const void *pKey,
		SLuint32 keyEncoding,
		const SLchar *pValueLangCountry,
		SLuint32 valueEncoding,
		SLuint8 filterMask
	);
	SLresult (*ClearKeyFilter) (
		SLMetadataExtractionItf self
	);
};


/*---------------------------------------------------------------------------*/
/* Meta data traversal related types and interface                          */
/*---------------------------------------------------------------------------*/

#define SL_METADATATRAVERSALMODE_ALL	((SLuint32) 0x00000001)
#define SL_METADATATRAVERSALMODE_NODE	((SLuint32) 0x00000002)


#define SL_NODETYPE_UNSPECIFIED	((SLuint32) 0x00000001)
#define SL_NODETYPE_AUDIO		((SLuint32) 0x00000002)
#define SL_NODETYPE_VIDEO		((SLuint32) 0x00000003)
#define SL_NODETYPE_IMAGE		((SLuint32) 0x00000004)

#define SL_NODE_PARENT 0xFFFFFFFF

extern const SLInterfaceID SL_IID_METADATATRAVERSAL;

struct SLMetadataTraversalItf_;
typedef const struct SLMetadataTraversalItf_ * const * SLMetadataTraversalItf;

struct SLMetadataTraversalItf_ {
	SLresult (*SetMode) (
		SLMetadataTraversalItf self,
		SLuint32 mode
	);
	SLresult (*GetChildCount) (
		SLMetadataTraversalItf self,
		SLuint32 *pCount
	);
	SLresult (*GetChildMIMETypeSize) (
		SLMetadataTraversalItf self,
		SLuint32 index,
		SLuint32 *pSize
	);
	SLresult (*GetChildInfo) (
		SLMetadataTraversalItf self,
		SLuint32 index,
		SLint32 *pNodeID,
		SLuint32 *pType,
		SLuint32 size,
		SLchar *pMimeType
	);
	SLresult (*SetActiveNode) (
		SLMetadataTraversalItf self,
		SLuint32 index
	);
};

/*---------------------------------------------------------------------------*/
/* Dynamic Source types and interface                                        */
/*---------------------------------------------------------------------------*/

extern const SLInterfaceID SL_IID_DYNAMICSOURCE;

struct SLDynamicSourceItf_;
typedef const struct SLDynamicSourceItf_ * const * SLDynamicSourceItf;

struct SLDynamicSourceItf_ {
	SLresult (*SetSource) (
		SLDynamicSourceItf self,
		SLDataSource *pDataSource
	);
};

/*---------------------------------------------------------------------------*/
/* Output Mix interface                                                      */
/*---------------------------------------------------------------------------*/

extern const SLInterfaceID SL_IID_OUTPUTMIX;

struct SLOutputMixItf_;
typedef const struct SLOutputMixItf_ * const * SLOutputMixItf;

typedef void (SLAPIENTRY *slMixDeviceChangeCallback) (
	SLOutputMixItf caller,
    void *pContext
);


struct SLOutputMixItf_ {
	SLresult (*GetDestinationOutputDeviceIDs) (
		SLOutputMixItf self,
		SLint32 *pNumDevices,
		SLuint32 *pDeviceIDs
	);
	SLresult (*RegisterDeviceChangeCallback) (
		SLOutputMixItf self,
		slMixDeviceChangeCallback callback,
		void *pContext
    );
    SLresult (*ReRoute)(
        SLOutputMixItf self,
        SLint32 numOutputDevices,
        SLuint32 *pOutputDeviceIDs
    );
};


/*---------------------------------------------------------------------------*/
/* Playback interface                                                        */
/*---------------------------------------------------------------------------*/

/** Playback states */
#define SL_PLAYSTATE_STOPPED	((SLuint32) 0x00000001)
#define SL_PLAYSTATE_PAUSED	((SLuint32) 0x00000002)
#define SL_PLAYSTATE_PLAYING	((SLuint32) 0x00000003)

/** Play events **/
#define SL_PLAYEVENT_HEADATEND		((SLuint32) 0x00000001)
#define SL_PLAYEVENT_HEADATMARKER	((SLuint32) 0x00000002)
#define SL_PLAYEVENT_HEADATNEWPOS	((SLuint32) 0x00000004)
#define SL_PLAYEVENT_HEADMOVING		((SLuint32) 0x00000008)
#define SL_PLAYEVENT_HEADSTALLED	((SLuint32) 0x00000010)

#define SL_TIME_UNKNOWN	((SLuint32) 0xFFFFFFFF)


extern const SLInterfaceID SL_IID_PLAY;

/** Playback interface methods */

struct SLPlayItf_;
typedef const struct SLPlayItf_ * const * SLPlayItf;

typedef void (SLAPIENTRY *slPlayCallback) (
	SLPlayItf caller,
	void *pContext,
	SLuint32 event
);

struct SLPlayItf_ {
	SLresult (*SetPlayState) (
		SLPlayItf self,
		SLuint32 state
	);
	SLresult (*GetPlayState) (
		SLPlayItf self,
		SLuint32 *pState
	);
	SLresult (*GetDuration) (
		SLPlayItf self,
		SLmillisecond *pMsec
	);
	SLresult (*GetPosition) (
		SLPlayItf self,
		SLmillisecond *pMsec
	);
	SLresult (*RegisterCallback) (
		SLPlayItf self,
		slPlayCallback callback,
		void *pContext
	);
	SLresult (*SetCallbackEventsMask) (
		SLPlayItf self,
		SLuint32 eventFlags
	);
	SLresult (*GetCallbackEventsMask) (
		SLPlayItf self,
		SLuint32 *pEventFlags
	);
	SLresult (*SetMarkerPosition) (
		SLPlayItf self,
		SLmillisecond mSec
	);
	SLresult (*ClearMarkerPosition) (
		SLPlayItf self
	);
	SLresult (*GetMarkerPosition) (
		SLPlayItf self,
		SLmillisecond *pMsec
	);
	SLresult (*SetPositionUpdatePeriod) (
		SLPlayItf self,
		SLmillisecond mSec
	);
	SLresult (*GetPositionUpdatePeriod) (
		SLPlayItf self,
		SLmillisecond *pMsec
	);
};

/*---------------------------------------------------------------------------*/
/* Prefetch status interface                                                 */
/*---------------------------------------------------------------------------*/

#define SL_PREFETCHEVENT_STATUSCHANGE		((SLuint32) 0x00000001)
#define SL_PREFETCHEVENT_FILLLEVELCHANGE	((SLuint32) 0x00000002)

#define SL_PREFETCHSTATUS_UNDERFLOW		((SLuint32) 0x00000001)
#define SL_PREFETCHSTATUS_SUFFICIENTDATA	((SLuint32) 0x00000002)
#define SL_PREFETCHSTATUS_OVERFLOW		((SLuint32) 0x00000003)


extern const SLInterfaceID SL_IID_PREFETCHSTATUS;


/** Prefetch status interface methods */

struct SLPrefetchStatusItf_;
typedef const struct SLPrefetchStatusItf_ * const * SLPrefetchStatusItf;

typedef void (SLAPIENTRY *slPrefetchCallback) (
	SLPrefetchStatusItf caller,
	void *pContext,
	SLuint32 event
);

struct SLPrefetchStatusItf_ {
	SLresult (*GetPrefetchStatus) (
		SLPrefetchStatusItf self,
		SLuint32 *pStatus
	);
	SLresult (*GetFillLevel) (
		SLPrefetchStatusItf self,
		SLpermille *pLevel
	);
	SLresult (*RegisterCallback) (
		SLPrefetchStatusItf self,
		slPrefetchCallback callback,
		void *pContext
	);
	SLresult (*SetCallbackEventsMask) (
		SLPrefetchStatusItf self,
		SLuint32 eventFlags
	);
	SLresult (*GetCallbackEventsMask) (
		SLPrefetchStatusItf self,
		SLuint32 *pEventFlags
	);
	SLresult (*SetFillUpdatePeriod) (
		SLPrefetchStatusItf self,
		SLpermille period
	);
	SLresult (*GetFillUpdatePeriod) (
		SLPrefetchStatusItf self,
		SLpermille *pPeriod
	);
};

/*---------------------------------------------------------------------------*/
/* Playback Rate interface                                                   */
/*---------------------------------------------------------------------------*/

#define SL_RATEPROP_RESERVED1		  		((SLuint32) 0x00000001)
#define SL_RATEPROP_RESERVED2		  		((SLuint32) 0x00000002)
#define SL_RATEPROP_SILENTAUDIO				((SLuint32) 0x00000100)
#define SL_RATEPROP_STAGGEREDAUDIO	((SLuint32) 0x00000200)
#define SL_RATEPROP_NOPITCHCORAUDIO	((SLuint32) 0x00000400)
#define SL_RATEPROP_PITCHCORAUDIO	((SLuint32) 0x00000800)


extern const SLInterfaceID SL_IID_PLAYBACKRATE;

struct SLPlaybackRateItf_;
typedef const struct SLPlaybackRateItf_ * const * SLPlaybackRateItf;

struct SLPlaybackRateItf_ {
	SLresult (*SetRate)(
		SLPlaybackRateItf self,
		SLpermille rate
	);
	SLresult (*GetRate)(
		SLPlaybackRateItf self,
		SLpermille *pRate
	);
	SLresult (*SetPropertyConstraints)(
		SLPlaybackRateItf self,
		SLuint32 constraints
	);
	SLresult (*GetProperties)(
		SLPlaybackRateItf self,
		SLuint32 *pProperties
	);
	SLresult (*GetCapabilitiesOfRate)(
		SLPlaybackRateItf self,
		SLpermille rate,
		SLuint32 *pCapabilities
	);
	SLresult (*GetRateRange) (
		SLPlaybackRateItf self,
		SLuint8 index,
		SLpermille *pMinRate,
		SLpermille *pMaxRate,
		SLpermille *pStepSize,
		SLuint32 *pCapabilities
	);
};

/*---------------------------------------------------------------------------*/
/* Seek Interface                                                            */
/*---------------------------------------------------------------------------*/

#define SL_SEEKMODE_FAST		((SLuint32) 0x0001)
#define SL_SEEKMODE_ACCURATE	((SLuint32) 0x0002)

extern const SLInterfaceID SL_IID_SEEK;

struct SLSeekItf_;
typedef const struct SLSeekItf_ * const * SLSeekItf;

struct SLSeekItf_ {
	SLresult (*SetPosition)(
		SLSeekItf self,
		SLmillisecond pos,
		SLuint32 seekMode
	);
	SLresult (*SetLoop)(
		SLSeekItf self,
		SLboolean loopEnable,
		SLmillisecond startPos,
		SLmillisecond endPos
	);
	SLresult (*GetLoop)(
		SLSeekItf self,
		SLboolean *pLoopEnabled,
		SLmillisecond *pStartPos,
		SLmillisecond *pEndPos
	);
};

/*---------------------------------------------------------------------------*/
/* Standard Recording Interface                                              */
/*---------------------------------------------------------------------------*/

/** Recording states */
#define SL_RECORDSTATE_STOPPED 	((SLuint32) 0x00000001)
#define SL_RECORDSTATE_PAUSED	((SLuint32) 0x00000002)
#define SL_RECORDSTATE_RECORDING	((SLuint32) 0x00000003)


/** Record event **/
#define SL_RECORDEVENT_HEADATLIMIT	((SLuint32) 0x00000001)
#define SL_RECORDEVENT_HEADATMARKER	((SLuint32) 0x00000002)
#define SL_RECORDEVENT_HEADATNEWPOS	((SLuint32) 0x00000004)
#define SL_RECORDEVENT_HEADMOVING	((SLuint32) 0x00000008)
#define SL_RECORDEVENT_HEADSTALLED 	((SLuint32) 0x00000010)
/* Note: SL_RECORDEVENT_BUFFER_INSUFFICIENT is deprecated, use SL_RECORDEVENT_BUFFER_FULL instead. */
#define SL_RECORDEVENT_BUFFER_INSUFFICIENT      ((SLuint32) 0x00000020)
#define SL_RECORDEVENT_BUFFER_FULL	((SLuint32) 0x00000020)


extern const SLInterfaceID SL_IID_RECORD;

struct SLRecordItf_;
typedef const struct SLRecordItf_ * const * SLRecordItf;

typedef void (SLAPIENTRY *slRecordCallback) (
	SLRecordItf caller,
	void *pContext,
	SLuint32 event
);

/** Recording interface methods */
struct SLRecordItf_ {
	SLresult (*SetRecordState) (
		SLRecordItf self,
		SLuint32 state
	);
	SLresult (*GetRecordState) (
		SLRecordItf self,
		SLuint32 *pState
	);
	SLresult (*SetDurationLimit) (
		SLRecordItf self,
		SLmillisecond msec
	);
	SLresult (*GetPosition) (
		SLRecordItf self,
		SLmillisecond *pMsec
	);
	SLresult (*RegisterCallback) (
		SLRecordItf self,
		slRecordCallback callback,
		void *pContext
	);
	SLresult (*SetCallbackEventsMask) (
		SLRecordItf self,
		SLuint32 eventFlags
	);
	SLresult (*GetCallbackEventsMask) (
		SLRecordItf self,
		SLuint32 *pEventFlags
	);
	SLresult (*SetMarkerPosition) (
		SLRecordItf self,
		SLmillisecond mSec
	);
	SLresult (*ClearMarkerPosition) (
		SLRecordItf self
	);
	SLresult (*GetMarkerPosition) (
		SLRecordItf self,
		SLmillisecond *pMsec
	);
	SLresult (*SetPositionUpdatePeriod) (
		SLRecordItf self,
		SLmillisecond mSec
	);
	SLresult (*GetPositionUpdatePeriod) (
		SLRecordItf self,
		SLmillisecond *pMsec
	);
};

/*---------------------------------------------------------------------------*/
/* Equalizer interface                                                       */
/*---------------------------------------------------------------------------*/

#define SL_EQUALIZER_UNDEFINED				((SLuint16) 0xFFFF)

extern const SLInterfaceID SL_IID_EQUALIZER;

struct SLEqualizerItf_;
typedef const struct SLEqualizerItf_ * const * SLEqualizerItf;

struct SLEqualizerItf_ {
	SLresult (*SetEnabled)(
		SLEqualizerItf self,
		SLboolean enabled
	);
	SLresult (*IsEnabled)(
		SLEqualizerItf self,
		SLboolean *pEnabled
	);
	SLresult (*GetNumberOfBands)(
		SLEqualizerItf self,
		SLuint16 *pAmount
	);
	SLresult (*GetBandLevelRange)(
		SLEqualizerItf self,
		SLmillibel *pMin,
		SLmillibel *pMax
	);
	SLresult (*SetBandLevel)(
		SLEqualizerItf self,
		SLuint16 band,
		SLmillibel level
	);
	SLresult (*GetBandLevel)(
		SLEqualizerItf self,
		SLuint16 band,
		SLmillibel *pLevel
	);
	SLresult (*GetCenterFreq)(
		SLEqualizerItf self,
		SLuint16 band,
		SLmilliHertz *pCenter
	);
	SLresult (*GetBandFreqRange)(
		SLEqualizerItf self,
		SLuint16 band,
		SLmilliHertz *pMin,
		SLmilliHertz *pMax
	);
	SLresult (*GetBand)(
		SLEqualizerItf self,
		SLmilliHertz frequency,
		SLuint16 *pBand
	);
	SLresult (*GetCurrentPreset)(
		SLEqualizerItf self,
		SLuint16 *pPreset
	);
	SLresult (*UsePreset)(
		SLEqualizerItf self,
		SLuint16 index
	);
	SLresult (*GetNumberOfPresets)(
		SLEqualizerItf self,
		SLuint16 *pNumPresets
	);
	SLresult (*GetPresetName)(
		SLEqualizerItf self,
		SLuint16 index,
		const SLchar ** ppName
	);
};

/*---------------------------------------------------------------------------*/
/* Volume Interface                                                           */
/* --------------------------------------------------------------------------*/

extern const SLInterfaceID SL_IID_VOLUME;

struct SLVolumeItf_;
typedef const struct SLVolumeItf_ * const * SLVolumeItf;

struct SLVolumeItf_ {
	SLresult (*SetVolumeLevel) (
		SLVolumeItf self,
		SLmillibel level
	);
	SLresult (*GetVolumeLevel) (
		SLVolumeItf self,
		SLmillibel *pLevel
	);
	SLresult (*GetMaxVolumeLevel) (
		SLVolumeItf  self,
		SLmillibel *pMaxLevel
	);
	SLresult (*SetMute) (
		SLVolumeItf self,
		SLboolean mute
	);
	SLresult (*GetMute) (
		SLVolumeItf self,
		SLboolean *pMute
	);
	SLresult (*EnableStereoPosition) (
		SLVolumeItf self,
		SLboolean enable
	);
	SLresult (*IsEnabledStereoPosition) (
		SLVolumeItf self,
		SLboolean *pEnable
	);
	SLresult (*SetStereoPosition) (
		SLVolumeItf self,
		SLpermille stereoPosition
	);
	SLresult (*GetStereoPosition) (
		SLVolumeItf self,
		SLpermille *pStereoPosition
	);
};


/*---------------------------------------------------------------------------*/
/* Device Volume Interface                                                   */
/* --------------------------------------------------------------------------*/

extern const SLInterfaceID SL_IID_DEVICEVOLUME;

struct SLDeviceVolumeItf_;
typedef const struct SLDeviceVolumeItf_ * const * SLDeviceVolumeItf;

struct SLDeviceVolumeItf_ {
	SLresult (*GetVolumeScale) (
		SLDeviceVolumeItf self,
		SLuint32 deviceID,
		SLint32 *pMinValue,
		SLint32 *pMaxValue,
		SLboolean *pIsMillibelScale
	);
	SLresult (*SetVolume) (
		SLDeviceVolumeItf self,
		SLuint32 deviceID,
		SLint32 volume
	);
	SLresult (*GetVolume) (
		SLDeviceVolumeItf self,
		SLuint32 deviceID,
		SLint32 *pVolume
	);
};


/*---------------------------------------------------------------------------*/
/* Buffer Queue Interface                                                    */
/*---------------------------------------------------------------------------*/

extern const SLInterfaceID SL_IID_BUFFERQUEUE;

struct SLBufferQueueItf_;
typedef const struct SLBufferQueueItf_ * const * SLBufferQueueItf;

typedef void (SLAPIENTRY *slBufferQueueCallback)(
	SLBufferQueueItf caller,
	void *pContext
);

/** Buffer queue state **/

typedef struct SLBufferQueueState_ {
	SLuint32	count;
	SLuint32	playIndex;
} SLBufferQueueState;


struct SLBufferQueueItf_ {
	SLresult (*Enqueue) (
		SLBufferQueueItf self,
		const void *pBuffer,
		SLuint32 size
	);
	SLresult (*Clear) (
		SLBufferQueueItf self
	);
	SLresult (*GetState) (
		SLBufferQueueItf self,
		SLBufferQueueState *pState
	);
	SLresult (*RegisterCallback) (
		SLBufferQueueItf self,
		slBufferQueueCallback callback,
		void* pContext
	);
};


/*---------------------------------------------------------------------------*/
/* PresetReverb                                                              */
/*---------------------------------------------------------------------------*/

#define SL_REVERBPRESET_NONE		((SLuint16) 0x0000)
#define SL_REVERBPRESET_SMALLROOM	((SLuint16) 0x0001)
#define SL_REVERBPRESET_MEDIUMROOM	((SLuint16) 0x0002)
#define SL_REVERBPRESET_LARGEROOM	((SLuint16) 0x0003)
#define SL_REVERBPRESET_MEDIUMHALL	((SLuint16) 0x0004)
#define SL_REVERBPRESET_LARGEHALL	((SLuint16) 0x0005)
#define SL_REVERBPRESET_PLATE 		((SLuint16) 0x0006)


extern const SLInterfaceID SL_IID_PRESETREVERB;

struct SLPresetReverbItf_;
typedef const struct SLPresetReverbItf_ * const * SLPresetReverbItf;

struct SLPresetReverbItf_ {
	SLresult (*SetPreset) (
		SLPresetReverbItf self,
		SLuint16 preset
	);
	SLresult (*GetPreset) (
		SLPresetReverbItf self,
		SLuint16 *pPreset
	);
};


/*---------------------------------------------------------------------------*/
/* EnvironmentalReverb                                                       */
/*---------------------------------------------------------------------------*/

#define SL_I3DL2_ENVIRONMENT_PRESET_DEFAULT \
	{ SL_MILLIBEL_MIN,    0,  1000,   500, SL_MILLIBEL_MIN,  20, SL_MILLIBEL_MIN,  40, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_GENERIC \
	{ -1000, -100, 1490,  830, -2602,   7,   200,  11, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_PADDEDCELL \
	{ -1000,-6000,  170,  100, -1204,   1,   207,   2, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_ROOM \
	{ -1000, -454,  400,  830, -1646,   2,    53,   3, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_BATHROOM \
	{ -1000,-1200, 1490,  540,  -370,   7,  1030,  11, 1000, 600 }
#define SL_I3DL2_ENVIRONMENT_PRESET_LIVINGROOM \
	{ -1000,-6000,  500,  100, -1376,   3, -1104,   4, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_STONEROOM \
	{ -1000, -300, 2310,  640,  -711,  12,    83,  17, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_AUDITORIUM \
	{ -1000, -476, 4320,  590,  -789,  20,  -289,  30, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_CONCERTHALL \
	{ -1000, -500, 3920,  700, -1230,  20,    -2,  29, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_CAVE \
	{ -1000,    0, 2910, 1300,  -602,  15,  -302,  22, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_ARENA \
	{ -1000, -698, 7240,  330, -1166,  20,    16,  30, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_HANGAR \
	{ -1000,-1000, 10050,  230,  -602,  20,   198,  30, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_CARPETEDHALLWAY \
	{ -1000,-4000,  300,  100, -1831,   2, -1630,  30, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_HALLWAY \
	{ -1000, -300, 1490,  590, -1219,   7,   441,  11, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_STONECORRIDOR \
	{ -1000, -237, 2700,  790, -1214,  13,   395,  20, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_ALLEY \
	{ -1000, -270, 1490,  860, -1204,   7,    -4,  11, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_FOREST \
	{ -1000,-3300, 1490,  540, -2560, 162,  -613,  88,  790,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_CITY \
	{ -1000, -800, 1490,  670, -2273,   7, -2217,  11,  500,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_MOUNTAINS \
	{ -1000,-2500, 1490,  210, -2780, 300, -2014, 100,  270,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_QUARRY \
	{ -1000,-1000, 1490,  830, SL_MILLIBEL_MIN,  61,   500,  25, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_PLAIN \
	{ -1000,-2000, 1490,  500, -2466, 179, -2514, 100,  210,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_PARKINGLOT \
	{ -1000,    0, 1650, 1500, -1363,   8, -1153,  12, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_SEWERPIPE \
	{ -1000,-1000, 2810,  140,   429,  14,   648,  21,  800, 600 }
#define SL_I3DL2_ENVIRONMENT_PRESET_UNDERWATER \
	{ -1000,-4000, 1490,  100,  -449,   7,  1700,  11, 1000,1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_SMALLROOM \
	{ -1000,-600, 1100, 830, -400, 5, 500, 10, 1000, 1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_MEDIUMROOM \
	{ -1000,-600, 1300, 830, -1000, 20, -200, 20, 1000, 1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_LARGEROOM \
	{ -1000,-600, 1500, 830, -1600, 5, -1000, 40, 1000, 1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_MEDIUMHALL \
	{ -1000,-600, 1800, 700, -1300, 15, -800, 30, 1000, 1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_LARGEHALL \
	{ -1000,-600, 1800, 700, -2000, 30, -1400, 60, 1000, 1000 }
#define SL_I3DL2_ENVIRONMENT_PRESET_PLATE \
	{ -1000,-200, 1300, 900, 0, 2, 0, 10, 1000, 750 }


typedef struct SLEnvironmentalReverbSettings_ {
	SLmillibel    roomLevel;
	SLmillibel    roomHFLevel;
	SLmillisecond decayTime;
	SLpermille    decayHFRatio;
	SLmillibel    reflectionsLevel;
	SLmillisecond reflectionsDelay;
	SLmillibel    reverbLevel;
	SLmillisecond reverbDelay;
	SLpermille    diffusion;
	SLpermille    density;
} SLEnvironmentalReverbSettings;




extern const SLInterfaceID SL_IID_ENVIRONMENTALREVERB;


struct SLEnvironmentalReverbItf_;
typedef const struct SLEnvironmentalReverbItf_ * const * SLEnvironmentalReverbItf;

struct SLEnvironmentalReverbItf_ {
	SLresult (*SetRoomLevel) (
		SLEnvironmentalReverbItf self,
		SLmillibel room
	);
	SLresult (*GetRoomLevel) (
		SLEnvironmentalReverbItf self,
		SLmillibel *pRoom
	);
	SLresult (*SetRoomHFLevel) (
		SLEnvironmentalReverbItf self,
		SLmillibel roomHF
	);
	SLresult (*GetRoomHFLevel) (
		SLEnvironmentalReverbItf self,
		SLmillibel *pRoomHF
	);
	SLresult (*SetDecayTime) (
		SLEnvironmentalReverbItf self,
		SLmillisecond decayTime
	);
	SLresult (*GetDecayTime) (
		SLEnvironmentalReverbItf self,
		SLmillisecond *pDecayTime
	);
	SLresult (*SetDecayHFRatio) (
		SLEnvironmentalReverbItf self,
		SLpermille decayHFRatio
	);
	SLresult (*GetDecayHFRatio) (
		SLEnvironmentalReverbItf self,
		SLpermille *pDecayHFRatio
	);
	SLresult (*SetReflectionsLevel) (
		SLEnvironmentalReverbItf self,
		SLmillibel reflectionsLevel
	);
	SLresult (*GetReflectionsLevel) (
		SLEnvironmentalReverbItf self,
		SLmillibel *pReflectionsLevel
	);
	SLresult (*SetReflectionsDelay) (
		SLEnvironmentalReverbItf self,
		SLmillisecond reflectionsDelay
	);
	SLresult (*GetReflectionsDelay) (
		SLEnvironmentalReverbItf self,
		SLmillisecond *pReflectionsDelay
	);
	SLresult (*SetReverbLevel) (
		SLEnvironmentalReverbItf self,
		SLmillibel reverbLevel
	);
	SLresult (*GetReverbLevel) (
		SLEnvironmentalReverbItf self,
		SLmillibel *pReverbLevel
	);
	SLresult (*SetReverbDelay) (
		SLEnvironmentalReverbItf self,
		SLmillisecond reverbDelay
	);
	SLresult (*GetReverbDelay) (
		SLEnvironmentalReverbItf self,
		SLmillisecond *pReverbDelay
	);
	SLresult (*SetDiffusion) (
		SLEnvironmentalReverbItf self,
		SLpermille diffusion
	);
	SLresult (*GetDiffusion) (
		SLEnvironmentalReverbItf self,
		SLpermille *pDiffusion
	);
	SLresult (*SetDensity) (
		SLEnvironmentalReverbItf self,
		SLpermille density
	);
	SLresult (*GetDensity) (
		SLEnvironmentalReverbItf self,
		SLpermille *pDensity
	);
	SLresult (*SetEnvironmentalReverbProperties) (
		SLEnvironmentalReverbItf self,
		const SLEnvironmentalReverbSettings *pProperties
	);
	SLresult (*GetEnvironmentalReverbProperties) (
		SLEnvironmentalReverbItf self,
		SLEnvironmentalReverbSettings *pProperties
	);
};

/*---------------------------------------------------------------------------*/
/* Effects Send Interface                                                    */
/*---------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_EFFECTSEND;

struct SLEffectSendItf_;
typedef const struct SLEffectSendItf_ * const * SLEffectSendItf;

struct SLEffectSendItf_ {
	SLresult (*EnableEffectSend) (
		SLEffectSendItf self,
		const void *pAuxEffect,
		SLboolean enable,
		SLmillibel initialLevel
	);
	SLresult (*IsEnabled) (
		SLEffectSendItf self,
		const void * pAuxEffect,
		SLboolean *pEnable
	);
	SLresult (*SetDirectLevel) (
		SLEffectSendItf self,
		SLmillibel directLevel
	);
	SLresult (*GetDirectLevel) (
		SLEffectSendItf self,
		SLmillibel *pDirectLevel
	);
	SLresult (*SetSendLevel) (
		SLEffectSendItf self,
		const void *pAuxEffect,
		SLmillibel sendLevel
	);
	SLresult (*GetSendLevel)(
		SLEffectSendItf self,
		const void *pAuxEffect,
		SLmillibel *pSendLevel
	);
};


/*---------------------------------------------------------------------------*/
/* 3D Grouping Interface                                                     */
/*---------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_3DGROUPING;


struct SL3DGroupingItf_ ;
typedef const struct SL3DGroupingItf_ * const * SL3DGroupingItf;

struct SL3DGroupingItf_ {
	SLresult (*Set3DGroup) (
		SL3DGroupingItf self,
		SLObjectItf group
	);
	SLresult (*Get3DGroup) (
		SL3DGroupingItf self,
		SLObjectItf *pGroup
	);
};


/*---------------------------------------------------------------------------*/
/* 3D Commit Interface                                                       */
/*---------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_3DCOMMIT;

struct SL3DCommitItf_;
typedef const struct SL3DCommitItf_* const * SL3DCommitItf;

struct SL3DCommitItf_ {
	SLresult (*Commit) (
		SL3DCommitItf self
	);
	SLresult (*SetDeferred) (
		SL3DCommitItf self,
		SLboolean deferred
	);
};


/*---------------------------------------------------------------------------*/
/* 3D Location Interface                                                     */
/*---------------------------------------------------------------------------*/

typedef struct SLVec3D_ {
	SLint32	x;
	SLint32	y;
	SLint32	z;
} SLVec3D;

extern const SLInterfaceID SL_IID_3DLOCATION;

struct SL3DLocationItf_;
typedef const struct SL3DLocationItf_ * const * SL3DLocationItf;

struct SL3DLocationItf_ {
	SLresult (*SetLocationCartesian) (
		SL3DLocationItf self,
		const SLVec3D *pLocation
	);
	SLresult (*SetLocationSpherical) (
		SL3DLocationItf self,
		SLmillidegree azimuth,
		SLmillidegree elevation,
		SLmillimeter distance
	);
	SLresult (*Move) (
		SL3DLocationItf self,
		const SLVec3D *pMovement
	);
	SLresult (*GetLocationCartesian) (
		SL3DLocationItf self,
		SLVec3D *pLocation
	);
	SLresult (*SetOrientationVectors) (
		SL3DLocationItf self,
		const SLVec3D *pFront,
		const SLVec3D *pAbove
	);
	SLresult (*SetOrientationAngles) (
		SL3DLocationItf self,
		SLmillidegree heading,
		SLmillidegree pitch,
		SLmillidegree roll
	);
	SLresult (*Rotate) (
		SL3DLocationItf self,
		SLmillidegree theta,
		const SLVec3D *pAxis
	);
	SLresult (*GetOrientationVectors) (
		SL3DLocationItf self,
		SLVec3D *pFront,
		SLVec3D *pUp
	);
};


/*---------------------------------------------------------------------------*/
/* 3D Doppler Interface                                                      */
/*---------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_3DDOPPLER;

struct SL3DDopplerItf_;
typedef const struct SL3DDopplerItf_ * const * SL3DDopplerItf;

struct SL3DDopplerItf_ {
	SLresult (*SetVelocityCartesian) (
		SL3DDopplerItf self,
		const SLVec3D *pVelocity
	);
	SLresult (*SetVelocitySpherical) (
		SL3DDopplerItf self,
		SLmillidegree azimuth,
		SLmillidegree elevation,
		SLmillimeter speed
	);
	SLresult (*GetVelocityCartesian) (
		SL3DDopplerItf self,
		SLVec3D *pVelocity
	);
	SLresult (*SetDopplerFactor) (
		SL3DDopplerItf self,
		SLpermille dopplerFactor
	);
	SLresult (*GetDopplerFactor) (
		SL3DDopplerItf self,
		SLpermille *pDopplerFactor
	);
};

/*---------------------------------------------------------------------------*/
/* 3D Source Interface and associated defines                                */
/* --------------------------------------------------------------------------*/

#define SL_ROLLOFFMODEL_EXPONENTIAL	((SLuint32) 0x00000000)
#define SL_ROLLOFFMODEL_LINEAR		((SLuint32) 0x00000001)


extern const SLInterfaceID SL_IID_3DSOURCE;

struct SL3DSourceItf_;
typedef const struct SL3DSourceItf_ * const * SL3DSourceItf;

struct SL3DSourceItf_ {
	SLresult (*SetHeadRelative) (
		SL3DSourceItf self,
		SLboolean headRelative
	);
	SLresult (*GetHeadRelative) (
		SL3DSourceItf self,
		SLboolean *pHeadRelative
	);
	SLresult (*SetRolloffDistances) (
		SL3DSourceItf self,
		SLmillimeter minDistance,
		SLmillimeter maxDistance
	);
	SLresult (*GetRolloffDistances) (
		SL3DSourceItf self,
		SLmillimeter *pMinDistance,
		SLmillimeter *pMaxDistance
	);
	SLresult (*SetRolloffMaxDistanceMute) (
		SL3DSourceItf self,
		SLboolean mute
	);
	SLresult (*GetRolloffMaxDistanceMute) (
		SL3DSourceItf self,
		SLboolean *pMute
	);
	SLresult (*SetRolloffFactor) (
		SL3DSourceItf self,
		SLpermille rolloffFactor
	);
	SLresult (*GetRolloffFactor) (
		SL3DSourceItf self,
		SLpermille *pRolloffFactor
	);
	SLresult (*SetRoomRolloffFactor) (
		SL3DSourceItf self,
		SLpermille roomRolloffFactor
	);
	SLresult (*GetRoomRolloffFactor) (
		SL3DSourceItf self,
		SLpermille *pRoomRolloffFactor
	);
	SLresult (*SetRolloffModel) (
		SL3DSourceItf self,
		SLuint8 model
	);
	SLresult (*GetRolloffModel) (
		SL3DSourceItf self,
		SLuint8 *pModel
	);
	SLresult (*SetCone) (
		SL3DSourceItf self,
		SLmillidegree innerAngle,
		SLmillidegree outerAngle,
		SLmillibel outerLevel
	);
	SLresult (*GetCone) (
		SL3DSourceItf self,
		SLmillidegree *pInnerAngle,
		SLmillidegree *pOuterAngle,
		SLmillibel *pOuterLevel
	);
};

/*---------------------------------------------------------------------------*/
/* 3D Macroscopic Interface                                                  */
/* --------------------------------------------------------------------------*/

extern const SLInterfaceID SL_IID_3DMACROSCOPIC;

struct SL3DMacroscopicItf_;
typedef const struct SL3DMacroscopicItf_ * const * SL3DMacroscopicItf;

struct SL3DMacroscopicItf_ {
	SLresult (*SetSize) (
		SL3DMacroscopicItf self,
		SLmillimeter width,
		SLmillimeter height,
		SLmillimeter depth
	);
	SLresult (*GetSize) (
		SL3DMacroscopicItf self,
		SLmillimeter *pWidth,
		SLmillimeter *pHeight,
		SLmillimeter *pDepth
	);
	SLresult (*SetOrientationAngles) (
		SL3DMacroscopicItf self,
		SLmillidegree heading,
		SLmillidegree pitch,
		SLmillidegree roll
	);
	SLresult (*SetOrientationVectors) (
		SL3DMacroscopicItf self,
		const SLVec3D *pFront,
		const SLVec3D *pAbove
	);
	SLresult (*Rotate) (
		SL3DMacroscopicItf self,
		SLmillidegree theta,
		const SLVec3D *pAxis
	);
	SLresult (*GetOrientationVectors) (
		SL3DMacroscopicItf self,
		SLVec3D *pFront,
		SLVec3D *pUp
	);
};

/*---------------------------------------------------------------------------*/
/* Mute Solo Interface                                                       */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_MUTESOLO;

struct SLMuteSoloItf_;
typedef const struct SLMuteSoloItf_ * const * SLMuteSoloItf;

struct SLMuteSoloItf_ {
	SLresult (*SetChannelMute) (
		SLMuteSoloItf self,
		SLuint8 chan,
		SLboolean mute
	);
	SLresult (*GetChannelMute) (
		SLMuteSoloItf self,
		SLuint8 chan,
		SLboolean *pMute
	);
	SLresult (*SetChannelSolo) (
		SLMuteSoloItf self,
		SLuint8 chan,
		SLboolean solo
	);
	SLresult (*GetChannelSolo) (
		SLMuteSoloItf self,
		SLuint8 chan,
		SLboolean *pSolo
	);
	SLresult (*GetNumChannels) (
		SLMuteSoloItf self,
		SLuint8 *pNumChannels
	);
};


/*---------------------------------------------------------------------------*/
/* Dynamic Interface Management Interface and associated types and macros    */
/* --------------------------------------------------------------------------*/

#define SL_DYNAMIC_ITF_EVENT_RUNTIME_ERROR			((SLuint32) 0x00000001)
#define SL_DYNAMIC_ITF_EVENT_ASYNC_TERMINATION		((SLuint32) 0x00000002)
#define SL_DYNAMIC_ITF_EVENT_RESOURCES_LOST			((SLuint32) 0x00000003)
#define SL_DYNAMIC_ITF_EVENT_RESOURCES_LOST_PERMANENTLY	((SLuint32) 0x00000004)
#define SL_DYNAMIC_ITF_EVENT_RESOURCES_AVAILABLE		((SLuint32) 0x00000005)




extern const SLInterfaceID SL_IID_DYNAMICINTERFACEMANAGEMENT;

struct SLDynamicInterfaceManagementItf_;
typedef const struct SLDynamicInterfaceManagementItf_ * const * SLDynamicInterfaceManagementItf;

typedef void (SLAPIENTRY *slDynamicInterfaceManagementCallback) (
	SLDynamicInterfaceManagementItf caller,
	void * pContext,
	SLuint32 event,
	SLresult result,
    const SLInterfaceID iid
);


struct SLDynamicInterfaceManagementItf_ {
	SLresult (*AddInterface) (
		SLDynamicInterfaceManagementItf self,
		const SLInterfaceID iid,
		SLboolean async
	);
	SLresult (*RemoveInterface) (
		SLDynamicInterfaceManagementItf self,
		const SLInterfaceID iid
	);
	SLresult (*ResumeInterface) (
		SLDynamicInterfaceManagementItf self,
		const SLInterfaceID iid,
		SLboolean async
	);
	SLresult (*RegisterCallback) (
		SLDynamicInterfaceManagementItf self,
		slDynamicInterfaceManagementCallback callback,
		void * pContext
	);
};

/*---------------------------------------------------------------------------*/
/* Midi Message Interface and associated types                               */
/* --------------------------------------------------------------------------*/

#define SL_MIDIMESSAGETYPE_NOTE_ON_OFF		((SLuint32) 0x00000001)
#define SL_MIDIMESSAGETYPE_POLY_PRESSURE	((SLuint32) 0x00000002)
#define SL_MIDIMESSAGETYPE_CONTROL_CHANGE	((SLuint32) 0x00000003)
#define SL_MIDIMESSAGETYPE_PROGRAM_CHANGE	((SLuint32) 0x00000004)
#define SL_MIDIMESSAGETYPE_CHANNEL_PRESSURE	((SLuint32) 0x00000005)
#define SL_MIDIMESSAGETYPE_PITCH_BEND		((SLuint32) 0x00000006)
#define SL_MIDIMESSAGETYPE_SYSTEM_MESSAGE	((SLuint32) 0x00000007)


extern const SLInterfaceID SL_IID_MIDIMESSAGE;

struct SLMIDIMessageItf_;
typedef const struct SLMIDIMessageItf_ * const * SLMIDIMessageItf;

typedef void (SLAPIENTRY *slMetaEventCallback) (
	SLMIDIMessageItf caller,
	void *pContext,
	SLuint8 type,
    SLuint32 length,
	const SLuint8 *pData,
	SLuint32 tick,
	SLuint16 track
);

typedef void (SLAPIENTRY *slMIDIMessageCallback) (
	SLMIDIMessageItf caller,
	void *pContext,
	SLuint8 statusByte,
	SLuint32 length,
	const SLuint8 *pData,
	SLuint32 tick,
	SLuint16 track
);

struct SLMIDIMessageItf_ {
	SLresult (*SendMessage) (
		SLMIDIMessageItf self,
		const SLuint8 *data,
		SLuint32 length
	);
	SLresult (*RegisterMetaEventCallback) (
		SLMIDIMessageItf self,
		slMetaEventCallback callback,
		void *pContext
	);
	SLresult (*RegisterMIDIMessageCallback) (
		SLMIDIMessageItf self,
		slMIDIMessageCallback callback,
		void *pContext
	);
	SLresult (*AddMIDIMessageCallbackFilter) (
		SLMIDIMessageItf self,
		SLuint32 messageType
	);
	SLresult (*ClearMIDIMessageCallbackFilter) (
		SLMIDIMessageItf self
	);
};


/*---------------------------------------------------------------------------*/
/* Midi Mute Solo interface                                                  */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_MIDIMUTESOLO;

struct SLMIDIMuteSoloItf_;
typedef const struct SLMIDIMuteSoloItf_ * const * SLMIDIMuteSoloItf;

struct SLMIDIMuteSoloItf_ {
	SLresult (*SetChannelMute) (
		SLMIDIMuteSoloItf self,
		SLuint8 channel,
		SLboolean mute
	);
	SLresult (*GetChannelMute) (
		SLMIDIMuteSoloItf self,
		SLuint8 channel,
		SLboolean *pMute
	);
	SLresult (*SetChannelSolo) (
		SLMIDIMuteSoloItf self,
		SLuint8 channel,
		SLboolean solo
	);
	SLresult (*GetChannelSolo) (
		SLMIDIMuteSoloItf self,
		SLuint8 channel,
		SLboolean *pSolo
	);
	SLresult (*GetTrackCount) (
		SLMIDIMuteSoloItf self,
		SLuint16 *pCount
	);
	SLresult (*SetTrackMute) (
		SLMIDIMuteSoloItf self,
		SLuint16 track,
		SLboolean mute
	);
	SLresult (*GetTrackMute) (
		SLMIDIMuteSoloItf self,
		SLuint16 track,
		SLboolean *pMute
	);
	SLresult (*SetTrackSolo) (
		SLMIDIMuteSoloItf self,
		SLuint16 track,
		SLboolean solo
	);
	SLresult (*GetTrackSolo) (
		SLMIDIMuteSoloItf self,
		SLuint16 track,
		SLboolean *pSolo
	);
};


/*---------------------------------------------------------------------------*/
/* Midi Tempo interface                                                      */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_MIDITEMPO;

struct SLMIDITempoItf_;
typedef const struct SLMIDITempoItf_ * const * SLMIDITempoItf;

struct SLMIDITempoItf_ {
	SLresult (*SetTicksPerQuarterNote) (
		SLMIDITempoItf self,
		SLuint32 tpqn
	);
	SLresult (*GetTicksPerQuarterNote) (
		SLMIDITempoItf self,
		SLuint32 *pTpqn
	);
	SLresult (*SetMicrosecondsPerQuarterNote) (
		SLMIDITempoItf self,
		SLmicrosecond uspqn
	);
	SLresult (*GetMicrosecondsPerQuarterNote) (
		SLMIDITempoItf self,
		SLmicrosecond *uspqn
	);
};


/*---------------------------------------------------------------------------*/
/* Midi Time interface                                                       */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_MIDITIME;

struct SLMIDITimeItf_;
typedef const struct SLMIDITimeItf_ * const * SLMIDITimeItf;

struct SLMIDITimeItf_ {
	SLresult (*GetDuration) (
		SLMIDITimeItf self,
		SLuint32 *pDuration
	);
	SLresult (*SetPosition) (
		SLMIDITimeItf self,
		SLuint32 position
	);
	SLresult (*GetPosition) (
		SLMIDITimeItf self,
		SLuint32 *pPosition
	);
	SLresult (*SetLoopPoints) (
		SLMIDITimeItf self,
		SLuint32 startTick,
		SLuint32 numTicks
	);
	SLresult (*GetLoopPoints) (
		SLMIDITimeItf self,
		SLuint32 *pStartTick,
		SLuint32 *pNumTicks
	);
};


/*---------------------------------------------------------------------------*/
/* Audio Decoder Capabilities Interface                                      */
/* --------------------------------------------------------------------------*/

/*Audio Codec related defines*/

#define SL_RATECONTROLMODE_CONSTANTBITRATE	((SLuint32) 0x00000001)
#define SL_RATECONTROLMODE_VARIABLEBITRATE	((SLuint32) 0x00000002)

#define SL_AUDIOCODEC_PCM         ((SLuint32) 0x00000001)
#define SL_AUDIOCODEC_MP3         ((SLuint32) 0x00000002)
#define SL_AUDIOCODEC_AMR         ((SLuint32) 0x00000003)
#define SL_AUDIOCODEC_AMRWB       ((SLuint32) 0x00000004)
#define SL_AUDIOCODEC_AMRWBPLUS   ((SLuint32) 0x00000005)
#define SL_AUDIOCODEC_AAC         ((SLuint32) 0x00000006)
#define SL_AUDIOCODEC_WMA         ((SLuint32) 0x00000007)
#define SL_AUDIOCODEC_REAL        ((SLuint32) 0x00000008)

#define SL_AUDIOPROFILE_PCM                   ((SLuint32) 0x00000001)

#define SL_AUDIOPROFILE_MPEG1_L3              ((SLuint32) 0x00000001)
#define SL_AUDIOPROFILE_MPEG2_L3              ((SLuint32) 0x00000002)
#define SL_AUDIOPROFILE_MPEG25_L3             ((SLuint32) 0x00000003)

#define SL_AUDIOCHANMODE_MP3_MONO             ((SLuint32) 0x00000001)
#define SL_AUDIOCHANMODE_MP3_STEREO           ((SLuint32) 0x00000002)
#define SL_AUDIOCHANMODE_MP3_JOINTSTEREO      ((SLuint32) 0x00000003)
#define SL_AUDIOCHANMODE_MP3_DUAL             ((SLuint32) 0x00000004)

#define SL_AUDIOPROFILE_AMR			((SLuint32) 0x00000001)

#define SL_AUDIOSTREAMFORMAT_CONFORMANCE	((SLuint32) 0x00000001)
#define SL_AUDIOSTREAMFORMAT_IF1			((SLuint32) 0x00000002)
#define SL_AUDIOSTREAMFORMAT_IF2			((SLuint32) 0x00000003)
#define SL_AUDIOSTREAMFORMAT_FSF			((SLuint32) 0x00000004)
#define SL_AUDIOSTREAMFORMAT_RTPPAYLOAD	((SLuint32) 0x00000005)
#define SL_AUDIOSTREAMFORMAT_ITU			((SLuint32) 0x00000006)

#define SL_AUDIOPROFILE_AMRWB			((SLuint32) 0x00000001)

#define SL_AUDIOPROFILE_AMRWBPLUS		((SLuint32) 0x00000001)

#define SL_AUDIOPROFILE_AAC_AAC			((SLuint32) 0x00000001)

#define SL_AUDIOMODE_AAC_MAIN			((SLuint32) 0x00000001)
#define SL_AUDIOMODE_AAC_LC			((SLuint32) 0x00000002)
#define SL_AUDIOMODE_AAC_SSR			((SLuint32) 0x00000003)
#define SL_AUDIOMODE_AAC_LTP			((SLuint32) 0x00000004)
#define SL_AUDIOMODE_AAC_HE			((SLuint32) 0x00000005)
#define SL_AUDIOMODE_AAC_SCALABLE		((SLuint32) 0x00000006)
#define SL_AUDIOMODE_AAC_ERLC			((SLuint32) 0x00000007)
#define SL_AUDIOMODE_AAC_LD			((SLuint32) 0x00000008)
#define SL_AUDIOMODE_AAC_HE_PS			((SLuint32) 0x00000009)
#define SL_AUDIOMODE_AAC_HE_MPS			((SLuint32) 0x0000000A)

#define SL_AUDIOSTREAMFORMAT_MP2ADTS		((SLuint32) 0x00000001)
#define SL_AUDIOSTREAMFORMAT_MP4ADTS		((SLuint32) 0x00000002)
#define SL_AUDIOSTREAMFORMAT_MP4LOAS		((SLuint32) 0x00000003)
#define SL_AUDIOSTREAMFORMAT_MP4LATM		((SLuint32) 0x00000004)
#define SL_AUDIOSTREAMFORMAT_ADIF		((SLuint32) 0x00000005)
#define SL_AUDIOSTREAMFORMAT_MP4FF		((SLuint32) 0x00000006)
#define SL_AUDIOSTREAMFORMAT_RAW			((SLuint32) 0x00000007)

#define SL_AUDIOPROFILE_WMA7		((SLuint32) 0x00000001)
#define SL_AUDIOPROFILE_WMA8		((SLuint32) 0x00000002)
#define SL_AUDIOPROFILE_WMA9		((SLuint32) 0x00000003)
#define SL_AUDIOPROFILE_WMA10		((SLuint32) 0x00000004)

#define SL_AUDIOMODE_WMA_LEVEL1		((SLuint32) 0x00000001)
#define SL_AUDIOMODE_WMA_LEVEL2		((SLuint32) 0x00000002)
#define SL_AUDIOMODE_WMA_LEVEL3		((SLuint32) 0x00000003)
#define SL_AUDIOMODE_WMA_LEVEL4		((SLuint32) 0x00000004)
#define SL_AUDIOMODE_WMAPRO_LEVELM0	((SLuint32) 0x00000005)
#define SL_AUDIOMODE_WMAPRO_LEVELM1	((SLuint32) 0x00000006)
#define SL_AUDIOMODE_WMAPRO_LEVELM2	((SLuint32) 0x00000007)
#define SL_AUDIOMODE_WMAPRO_LEVELM3	((SLuint32) 0x00000008)

#define SL_AUDIOPROFILE_REALAUDIO		((SLuint32) 0x00000001)

#define SL_AUDIOMODE_REALAUDIO_G2		((SLuint32) 0x00000001)
#define SL_AUDIOMODE_REALAUDIO_8			((SLuint32) 0x00000002)
#define SL_AUDIOMODE_REALAUDIO_10		((SLuint32) 0x00000003)
#define SL_AUDIOMODE_REALAUDIO_SURROUND	((SLuint32) 0x00000004)

typedef struct SLAudioCodecDescriptor_ {
    SLuint32      maxChannels;
    SLuint32      minBitsPerSample;
    SLuint32      maxBitsPerSample;
    SLmilliHertz  minSampleRate;
    SLmilliHertz  maxSampleRate;
    SLboolean     isFreqRangeContinuous;
    SLmilliHertz *pSampleRatesSupported;
    SLuint32      numSampleRatesSupported;
    SLuint32      minBitRate;
    SLuint32      maxBitRate;
    SLboolean     isBitrateRangeContinuous;
    SLuint32     *pBitratesSupported;
    SLuint32      numBitratesSupported;
    SLuint32	  profileSetting;
    SLuint32      modeSetting;
} SLAudioCodecDescriptor;

/*Structure used to retrieve the profile and level settings supported by an audio encoder */

typedef struct SLAudioCodecProfileMode_ {
    SLuint32 profileSetting;
    SLuint32 modeSetting;
} SLAudioCodecProfileMode;

extern const SLInterfaceID SL_IID_AUDIODECODERCAPABILITIES;

struct SLAudioDecoderCapabilitiesItf_;
typedef const struct SLAudioDecoderCapabilitiesItf_ * const * SLAudioDecoderCapabilitiesItf;

struct SLAudioDecoderCapabilitiesItf_ {
    SLresult (*GetAudioDecoders) (
        SLAudioDecoderCapabilitiesItf self,
        SLuint32 * pNumDecoders ,
        SLuint32 *pDecoderIds
    );
    SLresult (*GetAudioDecoderCapabilities) (
        SLAudioDecoderCapabilitiesItf self,
        SLuint32 decoderId,
        SLuint32 *pIndex,
        SLAudioCodecDescriptor *pDescriptor
    );
};




/*---------------------------------------------------------------------------*/
/* Audio Encoder Capabilities Interface                                      */
/* --------------------------------------------------------------------------*/

/* Structure used when setting audio encoding parameters */

typedef struct SLAudioEncoderSettings_ {
    SLuint32 encoderId;
    SLuint32 channelsIn;
    SLuint32 channelsOut;
    SLmilliHertz sampleRate;
    SLuint32 bitRate;
    SLuint32 bitsPerSample;
    SLuint32 rateControl;
    SLuint32 profileSetting;
    SLuint32 levelSetting;
    SLuint32 channelMode;
    SLuint32 streamFormat;
    SLuint32 encodeOptions;
    SLuint32 blockAlignment;
} SLAudioEncoderSettings;

extern const SLInterfaceID SL_IID_AUDIOENCODERCAPABILITIES;

struct SLAudioEncoderCapabilitiesItf_;
typedef const struct SLAudioEncoderCapabilitiesItf_ * const * SLAudioEncoderCapabilitiesItf;

struct SLAudioEncoderCapabilitiesItf_ {
    SLresult (*GetAudioEncoders) (
        SLAudioEncoderCapabilitiesItf self,
        SLuint32 *pNumEncoders ,
        SLuint32 *pEncoderIds
    );
    SLresult (*GetAudioEncoderCapabilities) (
        SLAudioEncoderCapabilitiesItf self,
        SLuint32 encoderId,
        SLuint32 *pIndex,
        SLAudioCodecDescriptor * pDescriptor
    );
};


/*---------------------------------------------------------------------------*/
/* Audio Encoder Interface                                                   */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_AUDIOENCODER;

struct SLAudioEncoderItf_;
typedef const struct SLAudioEncoderItf_ * const * SLAudioEncoderItf;

struct SLAudioEncoderItf_ {
    SLresult (*SetEncoderSettings) (
        SLAudioEncoderItf		self,
        SLAudioEncoderSettings 	*pSettings
    );
    SLresult (*GetEncoderSettings) (
        SLAudioEncoderItf		self,
        SLAudioEncoderSettings	*pSettings
    );
};


/*---------------------------------------------------------------------------*/
/* Bass Boost Interface                                                      */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_BASSBOOST;

struct SLBassBoostItf_;
typedef const struct SLBassBoostItf_ * const * SLBassBoostItf;

struct SLBassBoostItf_ {
	SLresult (*SetEnabled)(
		SLBassBoostItf self,
		SLboolean enabled
	);
	SLresult (*IsEnabled)(
		SLBassBoostItf self,
		SLboolean *pEnabled
	);
	SLresult (*SetStrength)(
		SLBassBoostItf self,
		SLpermille strength
	);
	SLresult (*GetRoundedStrength)(
		SLBassBoostItf self,
		SLpermille *pStrength
	);
	SLresult (*IsStrengthSupported)(
		SLBassBoostItf self,
		SLboolean *pSupported
	);
};

/*---------------------------------------------------------------------------*/
/* Pitch Interface                                                           */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_PITCH;

struct SLPitchItf_;
typedef const struct SLPitchItf_ * const * SLPitchItf;

struct SLPitchItf_ {
	SLresult (*SetPitch) (
		SLPitchItf self,
		SLpermille pitch
	);
	SLresult (*GetPitch) (
		SLPitchItf self,
		SLpermille *pPitch
	);
	SLresult (*GetPitchCapabilities) (
		SLPitchItf self,
		SLpermille *pMinPitch,
		SLpermille *pMaxPitch
	);
};


/*---------------------------------------------------------------------------*/
/* Rate Pitch Interface                                                      */
/* RatePitchItf is an interface for controlling the rate a sound is played   */
/* back. A change in rate will cause a change in pitch.                      */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_RATEPITCH;

struct SLRatePitchItf_;
typedef const struct SLRatePitchItf_ * const * SLRatePitchItf;

struct SLRatePitchItf_ {
	SLresult (*SetRate) (
		SLRatePitchItf self,
		SLpermille rate
	);
	SLresult (*GetRate) (
		SLRatePitchItf self,
		SLpermille *pRate
	);
	SLresult (*GetRatePitchCapabilities) (
		SLRatePitchItf self,
		SLpermille *pMinRate,
		SLpermille *pMaxRate
	);
};


/*---------------------------------------------------------------------------*/
/* Virtualizer Interface                                                      */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_VIRTUALIZER;

struct SLVirtualizerItf_;
typedef const struct SLVirtualizerItf_ * const * SLVirtualizerItf;

struct SLVirtualizerItf_ {
	SLresult (*SetEnabled)(
		SLVirtualizerItf self,
		SLboolean enabled
	);
	SLresult (*IsEnabled)(
		SLVirtualizerItf self,
		SLboolean *pEnabled
	);
	SLresult (*SetStrength)(
		SLVirtualizerItf self,
		SLpermille strength
	);
	SLresult (*GetRoundedStrength)(
		SLVirtualizerItf self,
		SLpermille *pStrength
	);
	SLresult (*IsStrengthSupported)(
		SLVirtualizerItf self,
		SLboolean *pSupported
	);
};

/*---------------------------------------------------------------------------*/
/* Visualization Interface                                                   */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_VISUALIZATION;

struct SLVisualizationItf_;
typedef const struct SLVisualizationItf_ * const * SLVisualizationItf;

typedef void (SLAPIENTRY *slVisualizationCallback) (
	void *pContext,
	const SLuint8 waveform[],
	const SLuint8 fft[],
	SLmilliHertz samplerate
);

struct SLVisualizationItf_{
	SLresult (*RegisterVisualizationCallback)(
		SLVisualizationItf self,
		slVisualizationCallback callback,
		void *pContext,
		SLmilliHertz rate
	);
	SLresult (*GetMaxRate)(
		SLVisualizationItf self,
		SLmilliHertz* pRate
	);
};


/*---------------------------------------------------------------------------*/
/* Engine Interface                                                          */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_ENGINE;

struct SLEngineItf_;
typedef const struct SLEngineItf_ * const * SLEngineItf;


struct SLEngineItf_ {

	SLresult (*CreateLEDDevice) (
		SLEngineItf self,
		SLObjectItf * pDevice,
		SLuint32 deviceID,
		SLuint32 numInterfaces,
		const SLInterfaceID * pInterfaceIds,
		const SLboolean * pInterfaceRequired
	);
	SLresult (*CreateVibraDevice) (
		SLEngineItf self,
		SLObjectItf * pDevice,
		SLuint32 deviceID,
		SLuint32 numInterfaces,
		const SLInterfaceID * pInterfaceIds,
		const SLboolean * pInterfaceRequired
	);
	SLresult (*CreateAudioPlayer) (
		SLEngineItf self,
		SLObjectItf * pPlayer,
		SLDataSource *pAudioSrc,
		SLDataSink *pAudioSnk,
		SLuint32 numInterfaces,
		const SLInterfaceID * pInterfaceIds,
		const SLboolean * pInterfaceRequired
	);
	SLresult (*CreateAudioRecorder) (
		SLEngineItf self,
		SLObjectItf * pRecorder,
		SLDataSource *pAudioSrc,
		SLDataSink *pAudioSnk,
		SLuint32 numInterfaces,
		const SLInterfaceID * pInterfaceIds,
		const SLboolean * pInterfaceRequired
	);
	SLresult (*CreateMidiPlayer) (
		SLEngineItf self,
		SLObjectItf * pPlayer,
		SLDataSource *pMIDISrc,
		SLDataSource *pBankSrc,
		SLDataSink *pAudioOutput,
		SLDataSink *pVibra,
		SLDataSink *pLEDArray,
		SLuint32 numInterfaces,
		const SLInterfaceID * pInterfaceIds,
		const SLboolean * pInterfaceRequired
	);
	SLresult (*CreateListener) (
		SLEngineItf self,
		SLObjectItf * pListener,
		SLuint32 numInterfaces,
		const SLInterfaceID * pInterfaceIds,
		const SLboolean * pInterfaceRequired
	);
	SLresult (*Create3DGroup) (
		SLEngineItf self,
		SLObjectItf * pGroup,
		SLuint32 numInterfaces,
		const SLInterfaceID * pInterfaceIds,
		const SLboolean * pInterfaceRequired
	);
	SLresult (*CreateOutputMix) (
		SLEngineItf self,
		SLObjectItf * pMix,
		SLuint32 numInterfaces,
		const SLInterfaceID * pInterfaceIds,
		const SLboolean * pInterfaceRequired
	);
	SLresult (*CreateMetadataExtractor) (
		SLEngineItf self,
		SLObjectItf * pMetadataExtractor,
		SLDataSource * pDataSource,
		SLuint32 numInterfaces,
		const SLInterfaceID * pInterfaceIds,
		const SLboolean * pInterfaceRequired
	);
    SLresult (*CreateExtensionObject) (
        SLEngineItf self,
        SLObjectItf * pObject,
        void * pParameters,
        SLuint32 objectID,
        SLuint32 numInterfaces,
        const SLInterfaceID * pInterfaceIds,
        const SLboolean * pInterfaceRequired
    );
	SLresult (*QueryNumSupportedInterfaces) (
		SLEngineItf self,
		SLuint32 objectID,
		SLuint32 * pNumSupportedInterfaces
	);
	SLresult (*QuerySupportedInterfaces) (
		SLEngineItf self,
		SLuint32 objectID,
		SLuint32 index,
		SLInterfaceID * pInterfaceId
	);
    SLresult (*QueryNumSupportedExtensions) (
        SLEngineItf self,
        SLuint32 * pNumExtensions
    );
    SLresult (*QuerySupportedExtension) (
        SLEngineItf self, 
        SLuint32 index,
        SLchar * pExtensionName,
        SLint16 * pNameLength
    );
    SLresult (*IsExtensionSupported) (
        SLEngineItf self, 
        const SLchar * pExtensionName,
        SLboolean * pSupported
    );
};


/*---------------------------------------------------------------------------*/
/* Engine Capabilities Interface                                             */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_ENGINECAPABILITIES;

struct SLEngineCapabilitiesItf_;
typedef const struct SLEngineCapabilitiesItf_ * const * SLEngineCapabilitiesItf;

struct SLEngineCapabilitiesItf_ {
	SLresult (*QuerySupportedProfiles) (
		SLEngineCapabilitiesItf self,
		SLuint16 *pProfilesSupported
	);
	SLresult (*QueryAvailableVoices) (
		SLEngineCapabilitiesItf self,
		SLuint16 voiceType,
		SLint16 *pNumMaxVoices,
		SLboolean *pIsAbsoluteMax,
		SLint16 *pNumFreeVoices
	);
	SLresult (*QueryNumberOfMIDISynthesizers) (
		SLEngineCapabilitiesItf self,
		SLint16 *pNumMIDIsynthesizers
	);
	SLresult (*QueryAPIVersion) (
		SLEngineCapabilitiesItf self,
		SLint16 *pMajor,
		SLint16 *pMinor,
		SLint16 *pStep
	);
	SLresult (*QueryLEDCapabilities) (
		SLEngineCapabilitiesItf self,
        SLuint32 *pIndex,
		SLuint32 *pLEDDeviceID,
		SLLEDDescriptor *pDescriptor
	);
	SLresult (*QueryVibraCapabilities) (
		SLEngineCapabilitiesItf self,
        SLuint32 *pIndex,
		SLuint32 *pVibraDeviceID,
		SLVibraDescriptor *pDescriptor
	);
	SLresult (*IsThreadSafe) (
		SLEngineCapabilitiesItf self,
		SLboolean *pIsThreadSafe
	);
};

/*---------------------------------------------------------------------------*/
/* Thread Sync Interface                                                     */
/* --------------------------------------------------------------------------*/


extern const SLInterfaceID SL_IID_THREADSYNC;

struct SLThreadSyncItf_;
typedef const struct SLThreadSyncItf_ * const * SLThreadSyncItf;


struct SLThreadSyncItf_ {
	SLresult (*EnterCriticalSection) (
		SLThreadSyncItf self
	);
	SLresult (*ExitCriticalSection) (
		SLThreadSyncItf self
	);
};


/*****************************************************************************/
/* SL engine constructor                                                     */
/*****************************************************************************/

#define SL_ENGINEOPTION_THREADSAFE	((SLuint32) 0x00000001)
#define SL_ENGINEOPTION_LOSSOFCONTROL	((SLuint32) 0x00000002)

typedef struct SLEngineOption_ {
	SLuint32 feature;
	SLuint32 data;
} SLEngineOption;


SLresult SLAPIENTRY slCreateEngine(
	SLObjectItf             *pEngine,
	SLuint32                numOptions,
	const SLEngineOption    *pEngineOptions,
	SLuint32                numInterfaces,
	const SLInterfaceID     *pInterfaceIds,
	const SLboolean         * pInterfaceRequired
);

SLresult SLAPIENTRY slQueryNumSupportedEngineInterfaces(
	SLuint32 * pNumSupportedInterfaces
);

SLresult SLAPIENTRY slQuerySupportedEngineInterfaces(
	SLuint32 index,
	SLInterfaceID * pInterfaceId
);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* OPENSL_ES_H_ */