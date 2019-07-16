/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#ifndef _SAPI_VER
#if _WIN32_WINNT >= 0x0601
#define _SAPI_VER 0x54
#elif _WIN32_WINNT >= 0x0600
#define _SAPI_VER 0x53
#else
#define _SAPI_VER 0x51
#endif
#endif

#include <mmsystem.h>

#define SPDUI_EngineProperties L"EngineProperties"
#define SPDUI_AddRemoveWord L"AddRemoveWord"
#define SPDUI_UserTraining L"UserTraining"
#define SPDUI_MicTraining L"MicTraining"
#define SPDUI_RecoProfileProperties L"RecoProfileProperties"
#define SPDUI_AudioProperties L"AudioProperties"
#define SPDUI_AudioVolume L"AudioVolume"
#define SPDUI_UserEnrollment L"UserEnrollment"
#define SPDUI_ShareData L"ShareData"
#define SPDUI_Tutorial L"Tutorial"
#define SPREG_USER_ROOT L"HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Speech"
#define SPREG_LOCAL_MACHINE_ROOT L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech"
#define SPCAT_AUDIOOUT L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\AudioOutput"
#define SPCAT_AUDIOIN L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\AudioInput"
#define SPCAT_VOICES L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\Voices"
#define SPCAT_RECOGNIZERS L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\Recognizers"
#define SPCAT_APPLEXICONS L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\AppLexicons"
#define SPCAT_PHONECONVERTERS L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\PhoneConverters"
#define SPCAT_TEXTNORMALIZERS L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\TextNormalizers"
#define SPCAT_RECOPROFILES L"HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Speech\\RecoProfiles"

#define SPMMSYS_AUDIO_IN_TOKEN_ID L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\AudioInput\\TokenEnums\\MMAudioIn\\"
#define SPMMSYS_AUDIO_OUT_TOKEN_ID L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\AudioOutput\\TokenEnums\\MMAudioOut\\"
#define SPCURRENT_USER_LEXICON_TOKEN_ID L"HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Speech\\CurrentUserLexicon"

#define SPTOKENVALUE_CLSID L"CLSID"
#define SPTOKENKEY_FILES L"Files"
#define SPTOKENKEY_UI L"UI"
#define SPTOKENKEY_ATTRIBUTES L"Attributes"

#if _SAPI_VER >= 0x53
#define SPCURRENT_USER_SHORTCUT_TOKEN_ID L"HKEY_CURRENT_USER\\SOFTWARE\\Microsoft\\Speech\\CurrentUserShortcut"
#define SPREG_SAFE_USER_TOKENS L"HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Speech\\UserTokens"

#define SPTOKENKEY_RETAINEDAUDIO L"SecondsPerRetainedAudioEvent"
#define SPTOKENKEY_AUDIO_LATENCY_WARNING L"LatencyWarningThreshold"
#define SPTOKENKEY_AUDIO_LATENCY_TRUNCATE L"LatencyTruncateThreshold"
#define SPTOKENKEY_AUDIO_LATENCY_UPDATE_INTERVAL L"LatencyUpdateInterval"
#endif

#define SPVOICECATEGORY_TTSRATE L"DefaultTTSRate"

#define SPPROP_RESOURCE_USAGE L"ResourceUsage"
#define SPPROP_HIGH_CONFIDENCE_THRESHOLD L"HighConfidenceThreshold"
#define SPPROP_NORMAL_CONFIDENCE_THRESHOLD L"NormalConfidenceThreshold"
#define SPPROP_LOW_CONFIDENCE_THRESHOLD L"LowConfidenceThreshold"
#define SPPROP_RESPONSE_SPEED L"ResponseSpeed"
#define SPPROP_COMPLEX_RESPONSE_SPEED L"ComplexResponseSpeed"
#define SPPROP_ADAPTATION_ON L"AdaptationOn"

#define SPPROP_PERSISTED_BACKGROUND_ADAPTATION L"PersistedBackgroundAdaptation"
#define SPPROP_PERSISTED_LANGUAGE_MODEL_ADAPTATION L"PersistedLanguageModelAdaptation"
#define SPPROP_UX_IS_LISTENING L"UXIsListening"
#define SPTOPIC_SPELLING L"Spelling"
#define SPWILDCARD L"..."
#define SPDICTATION L"*"
#define SPINFDICTATION L"*+"

#define SPFEI_FLAGCHECK ((1ull << SPEI_RESERVED1) | (1ull << SPEI_RESERVED2))
#define SPFEI_ALL_TTS_EVENTS (0x000000000000FFFEull | SPFEI_FLAGCHECK)
#define SPFEI_ALL_SR_EVENTS (0x003ffffc00000000ull | SPFEI_FLAGCHECK)
#define SPFEI_ALL_EVENTS 0xefffffffffffffffull
#define SPFEI(SPEI_ord) ((1ull << SPEI_ord) | SPFEI_FLAGCHECK)
#define SP_GETWHOLEPHRASE SPPR_ALL_ELEMENTS
#define SPRR_ALL_ELEMENTS SPPR_ALL_ELEMENTS

#if _SAPI_VER >= 0x54
#include "sapi54.h"
#elif _SAPI_VER >= 0x53
#include "sapi53.h"
#else
#include "sapi51.h"
#endif

#endif

