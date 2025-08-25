/*
 * Copyright (C) the Wine project
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#ifndef __DINPUT_INCLUDED__
#define __DINPUT_INCLUDED__

#define COM_NO_WINDOWS_H
#include <objbase.h>
#include <_mingw_dxhelper.h>

#define DIRECTINPUT_HEADER_VERSION	0x0800
#ifndef DIRECTINPUT_VERSION
#define DIRECTINPUT_VERSION	0x0800
#endif

/* Classes */
DEFINE_GUID(CLSID_DirectInput,		0x25E609E0,0xB259,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(CLSID_DirectInputDevice,	0x25E609E1,0xB259,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);

DEFINE_GUID(CLSID_DirectInput8,		0x25E609E4,0xB259,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(CLSID_DirectInputDevice8,	0x25E609E5,0xB259,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);

/* Interfaces */
DEFINE_GUID(IID_IDirectInputA,		0x89521360,0xAA8A,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(IID_IDirectInputW,		0x89521361,0xAA8A,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(IID_IDirectInput2A,		0x5944E662,0xAA8A,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(IID_IDirectInput2W,		0x5944E663,0xAA8A,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(IID_IDirectInput7A,		0x9A4CB684,0x236D,0x11D3,0x8E,0x9D,0x00,0xC0,0x4F,0x68,0x44,0xAE);
DEFINE_GUID(IID_IDirectInput7W,		0x9A4CB685,0x236D,0x11D3,0x8E,0x9D,0x00,0xC0,0x4F,0x68,0x44,0xAE);
DEFINE_GUID(IID_IDirectInput8A,		0xBF798030,0x483A,0x4DA2,0xAA,0x99,0x5D,0x64,0xED,0x36,0x97,0x00);
DEFINE_GUID(IID_IDirectInput8W,		0xBF798031,0x483A,0x4DA2,0xAA,0x99,0x5D,0x64,0xED,0x36,0x97,0x00);
DEFINE_GUID(IID_IDirectInputDeviceA,	0x5944E680,0xC92E,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(IID_IDirectInputDeviceW,	0x5944E681,0xC92E,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(IID_IDirectInputDevice2A,	0x5944E682,0xC92E,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(IID_IDirectInputDevice2W,	0x5944E683,0xC92E,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(IID_IDirectInputDevice7A,	0x57D7C6BC,0x2356,0x11D3,0x8E,0x9D,0x00,0xC0,0x4F,0x68,0x44,0xAE);
DEFINE_GUID(IID_IDirectInputDevice7W,	0x57D7C6BD,0x2356,0x11D3,0x8E,0x9D,0x00,0xC0,0x4F,0x68,0x44,0xAE);
DEFINE_GUID(IID_IDirectInputDevice8A,	0x54D41080,0xDC15,0x4833,0xA4,0x1B,0x74,0x8F,0x73,0xA3,0x81,0x79);
DEFINE_GUID(IID_IDirectInputDevice8W,	0x54D41081,0xDC15,0x4833,0xA4,0x1B,0x74,0x8F,0x73,0xA3,0x81,0x79);
DEFINE_GUID(IID_IDirectInputEffect,	0xE7E1F7C0,0x88D2,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);

/* Predefined object types */
DEFINE_GUID(GUID_XAxis,	0xA36D02E0,0xC9F3,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_YAxis,	0xA36D02E1,0xC9F3,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_ZAxis,	0xA36D02E2,0xC9F3,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_RxAxis,0xA36D02F4,0xC9F3,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_RyAxis,0xA36D02F5,0xC9F3,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_RzAxis,0xA36D02E3,0xC9F3,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_Slider,0xA36D02E4,0xC9F3,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_Button,0xA36D02F0,0xC9F3,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_Key,	0x55728220,0xD33C,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_POV,	0xA36D02F2,0xC9F3,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_Unknown,0xA36D02F3,0xC9F3,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);

/* Predefined product GUIDs */
DEFINE_GUID(GUID_SysMouse,	0x6F1D2B60,0xD5A0,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_SysKeyboard,	0x6F1D2B61,0xD5A0,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_Joystick,	0x6F1D2B70,0xD5A0,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_SysMouseEm,	0x6F1D2B80,0xD5A0,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_SysMouseEm2,	0x6F1D2B81,0xD5A0,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_SysKeyboardEm,	0x6F1D2B82,0xD5A0,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);
DEFINE_GUID(GUID_SysKeyboardEm2,0x6F1D2B83,0xD5A0,0x11CF,0xBF,0xC7,0x44,0x45,0x53,0x54,0x00,0x00);

/* predefined forcefeedback effects */
DEFINE_GUID(GUID_ConstantForce,	0x13541C20,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_RampForce,	0x13541C21,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_Square,	0x13541C22,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_Sine,		0x13541C23,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_Triangle,	0x13541C24,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_SawtoothUp,	0x13541C25,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_SawtoothDown,	0x13541C26,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_Spring,	0x13541C27,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_Damper,	0x13541C28,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_Inertia,	0x13541C29,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_Friction,	0x13541C2A,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);
DEFINE_GUID(GUID_CustomForce,	0x13541C2B,0x8E33,0x11D0,0x9A,0xD0,0x00,0xA0,0xC9,0xA0,0x6E,0x35);

typedef struct IDirectInputA *LPDIRECTINPUTA;
typedef struct IDirectInputW *LPDIRECTINPUTW;
typedef struct IDirectInput2A *LPDIRECTINPUT2A;
typedef struct IDirectInput2W *LPDIRECTINPUT2W;
typedef struct IDirectInput7A *LPDIRECTINPUT7A;
typedef struct IDirectInput7W *LPDIRECTINPUT7W;
#if DIRECTINPUT_VERSION >= 0x0800
typedef struct IDirectInput8A *LPDIRECTINPUT8A;
typedef struct IDirectInput8W *LPDIRECTINPUT8W;
#endif /* DI8 */
typedef struct IDirectInputDeviceA *LPDIRECTINPUTDEVICEA;
typedef struct IDirectInputDeviceW *LPDIRECTINPUTDEVICEW;
#if DIRECTINPUT_VERSION >= 0x0500
typedef struct IDirectInputDevice2A *LPDIRECTINPUTDEVICE2A;
typedef struct IDirectInputDevice2W *LPDIRECTINPUTDEVICE2W;
#endif /* DI5 */
#if DIRECTINPUT_VERSION >= 0x0700
typedef struct IDirectInputDevice7A *LPDIRECTINPUTDEVICE7A;
typedef struct IDirectInputDevice7W *LPDIRECTINPUTDEVICE7W;
#endif /* DI7 */
#if DIRECTINPUT_VERSION >= 0x0800
typedef struct IDirectInputDevice8A *LPDIRECTINPUTDEVICE8A;
typedef struct IDirectInputDevice8W *LPDIRECTINPUTDEVICE8W;
#endif /* DI8 */
#if DIRECTINPUT_VERSION >= 0x0500
typedef struct IDirectInputEffect *LPDIRECTINPUTEFFECT;
#endif /* DI5 */
typedef struct SysKeyboardA *LPSYSKEYBOARDA;
typedef struct SysMouseA *LPSYSMOUSEA;

#define IID_IDirectInput WINELIB_NAME_AW(IID_IDirectInput)
#define IDirectInput WINELIB_NAME_AW(IDirectInput)
DECL_WINELIB_TYPE_AW(LPDIRECTINPUT)
#define IID_IDirectInput2 WINELIB_NAME_AW(IID_IDirectInput2)
#define IDirectInput2 WINELIB_NAME_AW(IDirectInput2)
DECL_WINELIB_TYPE_AW(LPDIRECTINPUT2)
#define IID_IDirectInput7 WINELIB_NAME_AW(IID_IDirectInput7)
#define IDirectInput7 WINELIB_NAME_AW(IDirectInput7)
DECL_WINELIB_TYPE_AW(LPDIRECTINPUT7)
#if DIRECTINPUT_VERSION >= 0x0800
#define IID_IDirectInput8 WINELIB_NAME_AW(IID_IDirectInput8)
#define IDirectInput8 WINELIB_NAME_AW(IDirectInput8)
DECL_WINELIB_TYPE_AW(LPDIRECTINPUT8)
#endif /* DI8 */
#define IID_IDirectInputDevice WINELIB_NAME_AW(IID_IDirectInputDevice)
#define IDirectInputDevice WINELIB_NAME_AW(IDirectInputDevice)
DECL_WINELIB_TYPE_AW(LPDIRECTINPUTDEVICE)
#if DIRECTINPUT_VERSION >= 0x0500
#define IID_IDirectInputDevice2 WINELIB_NAME_AW(IID_IDirectInputDevice2)
#define IDirectInputDevice2 WINELIB_NAME_AW(IDirectInputDevice2)
DECL_WINELIB_TYPE_AW(LPDIRECTINPUTDEVICE2)
#endif /* DI5 */
#if DIRECTINPUT_VERSION >= 0x0700
#define IID_IDirectInputDevice7 WINELIB_NAME_AW(IID_IDirectInputDevice7)
#define IDirectInputDevice7 WINELIB_NAME_AW(IDirectInputDevice7)
DECL_WINELIB_TYPE_AW(LPDIRECTINPUTDEVICE7)
#endif /* DI7 */
#if DIRECTINPUT_VERSION >= 0x0800
#define IID_IDirectInputDevice8 WINELIB_NAME_AW(IID_IDirectInputDevice8)
#define IDirectInputDevice8 WINELIB_NAME_AW(IDirectInputDevice8)
DECL_WINELIB_TYPE_AW(LPDIRECTINPUTDEVICE8)
#endif /* DI8 */

#define DI_OK                           S_OK
#define DI_NOTATTACHED                  S_FALSE
#define DI_BUFFEROVERFLOW               S_FALSE
#define DI_PROPNOEFFECT                 S_FALSE
#define DI_NOEFFECT                     S_FALSE
#define DI_POLLEDDEVICE                 ((HRESULT)0x00000002L)
#define DI_DOWNLOADSKIPPED              ((HRESULT)0x00000003L)
#define DI_EFFECTRESTARTED              ((HRESULT)0x00000004L)
#define DI_TRUNCATED                    ((HRESULT)0x00000008L)
#define DI_SETTINGSNOTSAVED             ((HRESULT)0x0000000BL)
#define DI_TRUNCATEDANDRESTARTED        ((HRESULT)0x0000000CL)
#define DI_WRITEPROTECT                 ((HRESULT)0x00000013L)

#define DIERR_OLDDIRECTINPUTVERSION     \
    MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_OLD_WIN_VERSION)
#define DIERR_BETADIRECTINPUTVERSION    \
    MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_RMODE_APP)
#define DIERR_BADDRIVERVER              \
    MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_BAD_DRIVER_LEVEL)
#define DIERR_DEVICENOTREG              REGDB_E_CLASSNOTREG
#define DIERR_NOTFOUND                  \
    MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_FILE_NOT_FOUND)
#define DIERR_OBJECTNOTFOUND            \
    MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_FILE_NOT_FOUND)
#define DIERR_INVALIDPARAM              E_INVALIDARG
#define DIERR_NOINTERFACE               E_NOINTERFACE
#define DIERR_GENERIC                   E_FAIL
#define DIERR_OUTOFMEMORY               E_OUTOFMEMORY
#define DIERR_UNSUPPORTED               E_NOTIMPL
#define DIERR_NOTINITIALIZED            \
    MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_NOT_READY)
#define DIERR_ALREADYINITIALIZED        \
    MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_ALREADY_INITIALIZED)
#define DIERR_NOAGGREGATION             CLASS_E_NOAGGREGATION
#define DIERR_OTHERAPPHASPRIO           E_ACCESSDENIED
#define DIERR_INPUTLOST                 \
    MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_READ_FAULT)
#define DIERR_ACQUIRED                  \
    MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_BUSY)
#define DIERR_NOTACQUIRED               \
    MAKE_HRESULT(SEVERITY_ERROR, FACILITY_WIN32, ERROR_INVALID_ACCESS)
#define DIERR_READONLY                  E_ACCESSDENIED
#define DIERR_HANDLEEXISTS              E_ACCESSDENIED
#ifndef E_PENDING
#define E_PENDING                       0x8000000AL
#endif
#define DIERR_INSUFFICIENTPRIVS         0x80040200L
#define DIERR_DEVICEFULL                0x80040201L
#define DIERR_MOREDATA                  0x80040202L
#define DIERR_NOTDOWNLOADED             0x80040203L
#define DIERR_HASEFFECTS                0x80040204L
#define DIERR_NOTEXCLUSIVEACQUIRED      0x80040205L
#define DIERR_INCOMPLETEEFFECT          0x80040206L
#define DIERR_NOTBUFFERED               0x80040207L
#define DIERR_EFFECTPLAYING             0x80040208L
#define DIERR_UNPLUGGED                 0x80040209L
#define DIERR_REPORTFULL                0x8004020AL
#define DIERR_MAPFILEFAIL               0x8004020BL

#define DIENUM_STOP                     0
#define DIENUM_CONTINUE                 1

#define DIEDFL_ALLDEVICES               0x00000000
#define DIEDFL_ATTACHEDONLY             0x00000001
#define DIEDFL_FORCEFEEDBACK            0x00000100
#define DIEDFL_INCLUDEALIASES           0x00010000
#define DIEDFL_INCLUDEPHANTOMS          0x00020000
#define DIEDFL_INCLUDEHIDDEN		0x00040000

#define DIDEVTYPE_DEVICE                1
#define DIDEVTYPE_MOUSE                 2
#define DIDEVTYPE_KEYBOARD              3
#define DIDEVTYPE_JOYSTICK              4
#define DIDEVTYPE_HID                   0x00010000

#define DI8DEVCLASS_ALL             0
#define DI8DEVCLASS_DEVICE          1
#define DI8DEVCLASS_POINTER         2
#define DI8DEVCLASS_KEYBOARD        3
#define DI8DEVCLASS_GAMECTRL        4

#define DI8DEVTYPE_DEVICE           0x11
#define DI8DEVTYPE_MOUSE            0x12
#define DI8DEVTYPE_KEYBOARD         0x13
#define DI8DEVTYPE_JOYSTICK         0x14
#define DI8DEVTYPE_GAMEPAD          0x15
#define DI8DEVTYPE_DRIVING          0x16
#define DI8DEVTYPE_FLIGHT           0x17
#define DI8DEVTYPE_1STPERSON        0x18
#define DI8DEVTYPE_DEVICECTRL       0x19
#define DI8DEVTYPE_SCREENPOINTER    0x1A
#define DI8DEVTYPE_REMOTE           0x1B
#define DI8DEVTYPE_SUPPLEMENTAL     0x1C
	
#define DIDEVTYPEMOUSE_UNKNOWN          1
#define DIDEVTYPEMOUSE_TRADITIONAL      2
#define DIDEVTYPEMOUSE_FINGERSTICK      3
#define DIDEVTYPEMOUSE_TOUCHPAD         4
#define DIDEVTYPEMOUSE_TRACKBALL        5

#define DIDEVTYPEKEYBOARD_UNKNOWN       0
#define DIDEVTYPEKEYBOARD_PCXT          1
#define DIDEVTYPEKEYBOARD_OLIVETTI      2
#define DIDEVTYPEKEYBOARD_PCAT          3
#define DIDEVTYPEKEYBOARD_PCENH         4
#define DIDEVTYPEKEYBOARD_NOKIA1050     5
#define DIDEVTYPEKEYBOARD_NOKIA9140     6
#define DIDEVTYPEKEYBOARD_NEC98         7
#define DIDEVTYPEKEYBOARD_NEC98LAPTOP   8
#define DIDEVTYPEKEYBOARD_NEC98106      9
#define DIDEVTYPEKEYBOARD_JAPAN106     10
#define DIDEVTYPEKEYBOARD_JAPANAX      11
#define DIDEVTYPEKEYBOARD_J3100        12

#define DIDEVTYPEJOYSTICK_UNKNOWN       1
#define DIDEVTYPEJOYSTICK_TRADITIONAL   2
#define DIDEVTYPEJOYSTICK_FLIGHTSTICK   3
#define DIDEVTYPEJOYSTICK_GAMEPAD       4
#define DIDEVTYPEJOYSTICK_RUDDER        5
#define DIDEVTYPEJOYSTICK_WHEEL         6
#define DIDEVTYPEJOYSTICK_HEADTRACKER   7

#define DI8DEVTYPEMOUSE_UNKNOWN                     1
#define DI8DEVTYPEMOUSE_TRADITIONAL                 2
#define DI8DEVTYPEMOUSE_FINGERSTICK                 3
#define DI8DEVTYPEMOUSE_TOUCHPAD                    4
#define DI8DEVTYPEMOUSE_TRACKBALL                   5
#define DI8DEVTYPEMOUSE_ABSOLUTE                    6

#define DI8DEVTYPEKEYBOARD_UNKNOWN                  0
#define DI8DEVTYPEKEYBOARD_PCXT                     1
#define DI8DEVTYPEKEYBOARD_OLIVETTI                 2
#define DI8DEVTYPEKEYBOARD_PCAT                     3
#define DI8DEVTYPEKEYBOARD_PCENH                    4
#define DI8DEVTYPEKEYBOARD_NOKIA1050                5
#define DI8DEVTYPEKEYBOARD_NOKIA9140                6
#define DI8DEVTYPEKEYBOARD_NEC98                    7
#define DI8DEVTYPEKEYBOARD_NEC98LAPTOP              8
#define DI8DEVTYPEKEYBOARD_NEC98106                 9
#define DI8DEVTYPEKEYBOARD_JAPAN106                10
#define DI8DEVTYPEKEYBOARD_JAPANAX                 11
#define DI8DEVTYPEKEYBOARD_J3100                   12

#define DI8DEVTYPE_LIMITEDGAMESUBTYPE               1

#define DI8DEVTYPEJOYSTICK_LIMITED                  DI8DEVTYPE_LIMITEDGAMESUBTYPE
#define DI8DEVTYPEJOYSTICK_STANDARD                 2

#define DI8DEVTYPEGAMEPAD_LIMITED                   DI8DEVTYPE_LIMITEDGAMESUBTYPE
#define DI8DEVTYPEGAMEPAD_STANDARD                  2
#define DI8DEVTYPEGAMEPAD_TILT                      3

#define DI8DEVTYPEDRIVING_LIMITED                   DI8DEVTYPE_LIMITEDGAMESUBTYPE
#define DI8DEVTYPEDRIVING_COMBINEDPEDALS            2
#define DI8DEVTYPEDRIVING_DUALPEDALS                3
#define DI8DEVTYPEDRIVING_THREEPEDALS               4
#define DI8DEVTYPEDRIVING_HANDHELD                  5

#define DI8DEVTYPEFLIGHT_LIMITED                    DI8DEVTYPE_LIMITEDGAMESUBTYPE
#define DI8DEVTYPEFLIGHT_STICK                      2
#define DI8DEVTYPEFLIGHT_YOKE                       3
#define DI8DEVTYPEFLIGHT_RC                         4

#define DI8DEVTYPE1STPERSON_LIMITED                 DI8DEVTYPE_LIMITEDGAMESUBTYPE
#define DI8DEVTYPE1STPERSON_UNKNOWN                 2
#define DI8DEVTYPE1STPERSON_SIXDOF                  3
#define DI8DEVTYPE1STPERSON_SHOOTER                 4

#define DI8DEVTYPESCREENPTR_UNKNOWN                 2
#define DI8DEVTYPESCREENPTR_LIGHTGUN                3
#define DI8DEVTYPESCREENPTR_LIGHTPEN                4
#define DI8DEVTYPESCREENPTR_TOUCH                   5

#define DI8DEVTYPEREMOTE_UNKNOWN                    2

#define DI8DEVTYPEDEVICECTRL_UNKNOWN                2
#define DI8DEVTYPEDEVICECTRL_COMMSSELECTION         3
#define DI8DEVTYPEDEVICECTRL_COMMSSELECTION_HARDWIRED 4

#define DI8DEVTYPESUPPLEMENTAL_UNKNOWN              2
#define DI8DEVTYPESUPPLEMENTAL_2NDHANDCONTROLLER    3
#define DI8DEVTYPESUPPLEMENTAL_HEADTRACKER          4
#define DI8DEVTYPESUPPLEMENTAL_HANDTRACKER          5
#define DI8DEVTYPESUPPLEMENTAL_SHIFTSTICKGATE       6
#define DI8DEVTYPESUPPLEMENTAL_SHIFTER              7
#define DI8DEVTYPESUPPLEMENTAL_THROTTLE             8
#define DI8DEVTYPESUPPLEMENTAL_SPLITTHROTTLE        9
#define DI8DEVTYPESUPPLEMENTAL_COMBINEDPEDALS      10
#define DI8DEVTYPESUPPLEMENTAL_DUALPEDALS          11
#define DI8DEVTYPESUPPLEMENTAL_THREEPEDALS         12
#define DI8DEVTYPESUPPLEMENTAL_RUDDERPEDALS        13
	
#define GET_DIDEVICE_TYPE(dwDevType)     LOBYTE(dwDevType)
#define GET_DIDEVICE_SUBTYPE(dwDevType)  HIBYTE(dwDevType)

typedef struct DIDEVICEOBJECTINSTANCE_DX3A {
    DWORD   dwSize;
    GUID    guidType;
    DWORD   dwOfs;
    DWORD   dwType;
    DWORD   dwFlags;
    CHAR    tszName[MAX_PATH];
} DIDEVICEOBJECTINSTANCE_DX3A, *LPDIDEVICEOBJECTINSTANCE_DX3A;
typedef const DIDEVICEOBJECTINSTANCE_DX3A *LPCDIDEVICEOBJECTINSTANCE_DX3A;
typedef struct DIDEVICEOBJECTINSTANCE_DX3W {
    DWORD   dwSize;
    GUID    guidType;
    DWORD   dwOfs;
    DWORD   dwType;
    DWORD   dwFlags;
    WCHAR   tszName[MAX_PATH];
} DIDEVICEOBJECTINSTANCE_DX3W, *LPDIDEVICEOBJECTINSTANCE_DX3W;
typedef const DIDEVICEOBJECTINSTANCE_DX3W *LPCDIDEVICEOBJECTINSTANCE_DX3W;

DECL_WINELIB_TYPE_AW(DIDEVICEOBJECTINSTANCE_DX3)
DECL_WINELIB_TYPE_AW(LPDIDEVICEOBJECTINSTANCE_DX3)
DECL_WINELIB_TYPE_AW(LPCDIDEVICEOBJECTINSTANCE_DX3)

typedef struct DIDEVICEOBJECTINSTANCEA {
    DWORD	dwSize;
    GUID	guidType;
    DWORD	dwOfs;
    DWORD	dwType;
    DWORD	dwFlags;
    CHAR	tszName[MAX_PATH];
#if(DIRECTINPUT_VERSION >= 0x0500)
    DWORD	dwFFMaxForce;
    DWORD	dwFFForceResolution;
    WORD	wCollectionNumber;
    WORD	wDesignatorIndex;
    WORD	wUsagePage;
    WORD	wUsage;
    DWORD	dwDimension;
    WORD	wExponent;
    WORD	wReportId;
#endif /* DIRECTINPUT_VERSION >= 0x0500 */
} DIDEVICEOBJECTINSTANCEA, *LPDIDEVICEOBJECTINSTANCEA;
typedef const DIDEVICEOBJECTINSTANCEA *LPCDIDEVICEOBJECTINSTANCEA;

typedef struct DIDEVICEOBJECTINSTANCEW {
    DWORD	dwSize;
    GUID	guidType;
    DWORD	dwOfs;
    DWORD	dwType;
    DWORD	dwFlags;
    WCHAR	tszName[MAX_PATH];
#if(DIRECTINPUT_VERSION >= 0x0500)
    DWORD	dwFFMaxForce;
    DWORD	dwFFForceResolution;
    WORD	wCollectionNumber;
    WORD	wDesignatorIndex;
    WORD	wUsagePage;
    WORD	wUsage;
    DWORD	dwDimension;
    WORD	wExponent;
    WORD	wReportId;
#endif /* DIRECTINPUT_VERSION >= 0x0500 */
} DIDEVICEOBJECTINSTANCEW, *LPDIDEVICEOBJECTINSTANCEW;
typedef const DIDEVICEOBJECTINSTANCEW *LPCDIDEVICEOBJECTINSTANCEW;

DECL_WINELIB_TYPE_AW(DIDEVICEOBJECTINSTANCE)
DECL_WINELIB_TYPE_AW(LPDIDEVICEOBJECTINSTANCE)
DECL_WINELIB_TYPE_AW(LPCDIDEVICEOBJECTINSTANCE)

typedef struct DIDEVICEINSTANCE_DX3A {
    DWORD   dwSize;
    GUID    guidInstance;
    GUID    guidProduct;
    DWORD   dwDevType;
    CHAR    tszInstanceName[MAX_PATH];
    CHAR    tszProductName[MAX_PATH];
} DIDEVICEINSTANCE_DX3A, *LPDIDEVICEINSTANCE_DX3A;
typedef const DIDEVICEINSTANCE_DX3A *LPCDIDEVICEINSTANCE_DX3A;
typedef struct DIDEVICEINSTANCE_DX3W {
    DWORD   dwSize;
    GUID    guidInstance;
    GUID    guidProduct;
    DWORD   dwDevType;
    WCHAR   tszInstanceName[MAX_PATH];
    WCHAR   tszProductName[MAX_PATH];
} DIDEVICEINSTANCE_DX3W, *LPDIDEVICEINSTANCE_DX3W;
typedef const DIDEVICEINSTANCE_DX3W *LPCDIDEVICEINSTANCE_DX3W;

DECL_WINELIB_TYPE_AW(DIDEVICEINSTANCE_DX3)
DECL_WINELIB_TYPE_AW(LPDIDEVICEINSTANCE_DX3)
DECL_WINELIB_TYPE_AW(LPCDIDEVICEINSTANCE_DX3)

typedef struct DIDEVICEINSTANCEA {
    DWORD	dwSize;
    GUID	guidInstance;
    GUID	guidProduct;
    DWORD	dwDevType;
    CHAR	tszInstanceName[MAX_PATH];
    CHAR	tszProductName[MAX_PATH];
#if(DIRECTINPUT_VERSION >= 0x0500)
    GUID	guidFFDriver;
    WORD	wUsagePage;
    WORD	wUsage;
#endif /* DIRECTINPUT_VERSION >= 0x0500 */
} DIDEVICEINSTANCEA, *LPDIDEVICEINSTANCEA;
typedef const DIDEVICEINSTANCEA *LPCDIDEVICEINSTANCEA;

typedef struct DIDEVICEINSTANCEW {
    DWORD	dwSize;
    GUID	guidInstance;
    GUID	guidProduct;
    DWORD	dwDevType;
    WCHAR	tszInstanceName[MAX_PATH];
    WCHAR	tszProductName[MAX_PATH];
#if(DIRECTINPUT_VERSION >= 0x0500)
    GUID	guidFFDriver;
    WORD	wUsagePage;
    WORD	wUsage;
#endif /* DIRECTINPUT_VERSION >= 0x0500 */
} DIDEVICEINSTANCEW, *LPDIDEVICEINSTANCEW;
typedef const DIDEVICEINSTANCEW *LPCDIDEVICEINSTANCEW;

DECL_WINELIB_TYPE_AW(DIDEVICEINSTANCE)
DECL_WINELIB_TYPE_AW(LPDIDEVICEINSTANCE)
DECL_WINELIB_TYPE_AW(LPCDIDEVICEINSTANCE)

typedef WINBOOL (CALLBACK *LPDIENUMDEVICESCALLBACKA)(LPCDIDEVICEINSTANCEA,LPVOID);
typedef WINBOOL (CALLBACK *LPDIENUMDEVICESCALLBACKW)(LPCDIDEVICEINSTANCEW,LPVOID);
DECL_WINELIB_TYPE_AW(LPDIENUMDEVICESCALLBACK)

#define DIEDBS_MAPPEDPRI1		0x00000001
#define DIEDBS_MAPPEDPRI2		0x00000002
#define DIEDBS_RECENTDEVICE		0x00000010
#define DIEDBS_NEWDEVICE		0x00000020

#define DIEDBSFL_ATTACHEDONLY		0x00000000
#define DIEDBSFL_THISUSER		0x00000010
#define DIEDBSFL_FORCEFEEDBACK		DIEDFL_FORCEFEEDBACK
#define DIEDBSFL_AVAILABLEDEVICES	0x00001000
#define DIEDBSFL_MULTIMICEKEYBOARDS	0x00002000
#define DIEDBSFL_NONGAMINGDEVICES	0x00004000
#define DIEDBSFL_VALID			0x00007110

#if DIRECTINPUT_VERSION >= 0x0800
typedef WINBOOL (CALLBACK *LPDIENUMDEVICESBYSEMANTICSCBA)(LPCDIDEVICEINSTANCEA,LPDIRECTINPUTDEVICE8A,DWORD,DWORD,LPVOID);
typedef WINBOOL (CALLBACK *LPDIENUMDEVICESBYSEMANTICSCBW)(LPCDIDEVICEINSTANCEW,LPDIRECTINPUTDEVICE8W,DWORD,DWORD,LPVOID);
DECL_WINELIB_TYPE_AW(LPDIENUMDEVICESBYSEMANTICSCB)
#endif

typedef WINBOOL (CALLBACK *LPDICONFIGUREDEVICESCALLBACK)(LPUNKNOWN,LPVOID);

typedef WINBOOL (CALLBACK *LPDIENUMDEVICEOBJECTSCALLBACKA)(LPCDIDEVICEOBJECTINSTANCEA,LPVOID);
typedef WINBOOL (CALLBACK *LPDIENUMDEVICEOBJECTSCALLBACKW)(LPCDIDEVICEOBJECTINSTANCEW,LPVOID);
DECL_WINELIB_TYPE_AW(LPDIENUMDEVICEOBJECTSCALLBACK)

#if DIRECTINPUT_VERSION >= 0x0500
typedef WINBOOL (CALLBACK *LPDIENUMCREATEDEFFECTOBJECTSCALLBACK)(LPDIRECTINPUTEFFECT, LPVOID);
#endif

#define DIK_ESCAPE          0x01
#define DIK_1               0x02
#define DIK_2               0x03
#define DIK_3               0x04
#define DIK_4               0x05
#define DIK_5               0x06
#define DIK_6               0x07
#define DIK_7               0x08
#define DIK_8               0x09
#define DIK_9               0x0A
#define DIK_0               0x0B
#define DIK_MINUS           0x0C    /* - on main keyboard */
#define DIK_EQUALS          0x0D
#define DIK_BACK            0x0E    /* backspace */
#define DIK_TAB             0x0F
#define DIK_Q               0x10
#define DIK_W               0x11
#define DIK_E               0x12
#define DIK_R               0x13
#define DIK_T               0x14
#define DIK_Y               0x15
#define DIK_U               0x16
#define DIK_I               0x17
#define DIK_O               0x18
#define DIK_P               0x19
#define DIK_LBRACKET        0x1A
#define DIK_RBRACKET        0x1B
#define DIK_RETURN          0x1C    /* Enter on main keyboard */
#define DIK_LCONTROL        0x1D
#define DIK_A               0x1E
#define DIK_S               0x1F
#define DIK_D               0x20
#define DIK_F               0x21
#define DIK_G               0x22
#define DIK_H               0x23
#define DIK_J               0x24
#define DIK_K               0x25
#define DIK_L               0x26
#define DIK_SEMICOLON       0x27
#define DIK_APOSTROPHE      0x28
#define DIK_GRAVE           0x29    /* accent grave */
#define DIK_LSHIFT          0x2A
#define DIK_BACKSLASH       0x2B
#define DIK_Z               0x2C
#define DIK_X               0x2D
#define DIK_C               0x2E
#define DIK_V               0x2F
#define DIK_B               0x30
#define DIK_N               0x31
#define DIK_M               0x32
#define DIK_COMMA           0x33
#define DIK_PERIOD          0x34    /* . on main keyboard */
#define DIK_SLASH           0x35    /* / on main keyboard */
#define DIK_RSHIFT          0x36
#define DIK_MULTIPLY        0x37    /* * on numeric keypad */
#define DIK_LMENU           0x38    /* left Alt */
#define DIK_SPACE           0x39
#define DIK_CAPITAL         0x3A
#define DIK_F1              0x3B
#define DIK_F2              0x3C
#define DIK_F3              0x3D
#define DIK_F4              0x3E
#define DIK_F5              0x3F
#define DIK_F6              0x40
#define DIK_F7              0x41
#define DIK_F8              0x42
#define DIK_F9              0x43
#define DIK_F10             0x44
#define DIK_NUMLOCK         0x45
#define DIK_SCROLL          0x46    /* Scroll Lock */
#define DIK_NUMPAD7         0x47
#define DIK_NUMPAD8         0x48
#define DIK_NUMPAD9         0x49
#define DIK_SUBTRACT        0x4A    /* - on numeric keypad */
#define DIK_NUMPAD4         0x4B
#define DIK_NUMPAD5         0x4C
#define DIK_NUMPAD6         0x4D
#define DIK_ADD             0x4E    /* + on numeric keypad */
#define DIK_NUMPAD1         0x4F
#define DIK_NUMPAD2         0x50
#define DIK_NUMPAD3         0x51
#define DIK_NUMPAD0         0x52
#define DIK_DECIMAL         0x53    /* . on numeric keypad */
#define DIK_OEM_102         0x56    /* < > | on UK/Germany keyboards */
#define DIK_F11             0x57
#define DIK_F12             0x58
#define DIK_F13             0x64    /*                     (NEC PC98) */
#define DIK_F14             0x65    /*                     (NEC PC98) */
#define DIK_F15             0x66    /*                     (NEC PC98) */
#define DIK_KANA            0x70    /* (Japanese keyboard)            */
#define DIK_ABNT_C1         0x73    /* / ? on Portugese (Brazilian) keyboards */
#define DIK_CONVERT         0x79    /* (Japanese keyboard)            */
#define DIK_NOCONVERT       0x7B    /* (Japanese keyboard)            */
#define DIK_YEN             0x7D    /* (Japanese keyboard)            */
#define DIK_ABNT_C2         0x7E    /* Numpad . on Portugese (Brazilian) keyboards */
#define DIK_NUMPADEQUALS    0x8D    /* = on numeric keypad (NEC PC98) */
#define DIK_PREVTRACK       0x90    /* Previous Track (DIK_CIRCUMFLEX on Japanese keyboard) */
#define DIK_CIRCUMFLEX      0x90    /* (Japanese keyboard)            */
#define DIK_AT              0x91    /*                     (NEC PC98) */
#define DIK_COLON           0x92    /*                     (NEC PC98) */
#define DIK_UNDERLINE       0x93    /*                     (NEC PC98) */
#define DIK_KANJI           0x94    /* (Japanese keyboard)            */
#define DIK_STOP            0x95    /*                     (NEC PC98) */
#define DIK_AX              0x96    /*                     (Japan AX) */
#define DIK_UNLABELED       0x97    /*                        (J3100) */
#define DIK_NEXTTRACK       0x99    /* Next Track */
#define DIK_NUMPADENTER     0x9C    /* Enter on numeric keypad */
#define DIK_RCONTROL        0x9D
#define DIK_MUTE	    0xA0    /* Mute */
#define DIK_CALCULATOR      0xA1    /* Calculator */
#define DIK_PLAYPAUSE       0xA2    /* Play / Pause */
#define DIK_MEDIASTOP       0xA4    /* Media Stop */
#define DIK_VOLUMEDOWN      0xAE    /* Volume - */
#define DIK_VOLUMEUP        0xB0    /* Volume + */
#define DIK_WEBHOME         0xB2    /* Web home */
#define DIK_NUMPADCOMMA     0xB3    /* , on numeric keypad (NEC PC98) */
#define DIK_DIVIDE          0xB5    /* / on numeric keypad */
#define DIK_SYSRQ           0xB7
#define DIK_RMENU           0xB8    /* right Alt */
#define DIK_PAUSE           0xC5    /* Pause */
#define DIK_HOME            0xC7    /* Home on arrow keypad */
#define DIK_UP              0xC8    /* UpArrow on arrow keypad */
#define DIK_PRIOR           0xC9    /* PgUp on arrow keypad */
#define DIK_LEFT            0xCB    /* LeftArrow on arrow keypad */
#define DIK_RIGHT           0xCD    /* RightArrow on arrow keypad */
#define DIK_END             0xCF    /* End on arrow keypad */
#define DIK_DOWN            0xD0    /* DownArrow on arrow keypad */
#define DIK_NEXT            0xD1    /* PgDn on arrow keypad */
#define DIK_INSERT          0xD2    /* Insert on arrow keypad */
#define DIK_DELETE          0xD3    /* Delete on arrow keypad */
#define DIK_LWIN            0xDB    /* Left Windows key */
#define DIK_RWIN            0xDC    /* Right Windows key */
#define DIK_APPS            0xDD    /* AppMenu key */
#define DIK_POWER           0xDE
#define DIK_SLEEP           0xDF
#define DIK_WAKE            0xE3    /* System Wake */
#define DIK_WEBSEARCH       0xE5    /* Web Search */
#define DIK_WEBFAVORITES    0xE6    /* Web Favorites */
#define DIK_WEBREFRESH      0xE7    /* Web Refresh */
#define DIK_WEBSTOP         0xE8    /* Web Stop */
#define DIK_WEBFORWARD      0xE9    /* Web Forward */
#define DIK_WEBBACK         0xEA    /* Web Back */
#define DIK_MYCOMPUTER      0xEB    /* My Computer */
#define DIK_MAIL            0xEC    /* Mail */
#define DIK_MEDIASELECT     0xED    /* Media Select */

#define DIK_BACKSPACE       DIK_BACK            /* backspace */
#define DIK_NUMPADSTAR      DIK_MULTIPLY        /* * on numeric keypad */
#define DIK_LALT            DIK_LMENU           /* left Alt */
#define DIK_CAPSLOCK        DIK_CAPITAL         /* CapsLock */
#define DIK_NUMPADMINUS     DIK_SUBTRACT        /* - on numeric keypad */
#define DIK_NUMPADPLUS      DIK_ADD             /* + on numeric keypad */
#define DIK_NUMPADPERIOD    DIK_DECIMAL         /* . on numeric keypad */
#define DIK_NUMPADSLASH     DIK_DIVIDE          /* / on numeric keypad */
#define DIK_RALT            DIK_RMENU           /* right Alt */
#define DIK_UPARROW         DIK_UP              /* UpArrow on arrow keypad */
#define DIK_PGUP            DIK_PRIOR           /* PgUp on arrow keypad */
#define DIK_LEFTARROW       DIK_LEFT            /* LeftArrow on arrow keypad */
#define DIK_RIGHTARROW      DIK_RIGHT           /* RightArrow on arrow keypad */
#define DIK_DOWNARROW       DIK_DOWN            /* DownArrow on arrow keypad */
#define DIK_PGDN            DIK_NEXT            /* PgDn on arrow keypad */

#define DIDFT_ALL		0x00000000
#define DIDFT_RELAXIS		0x00000001
#define DIDFT_ABSAXIS		0x00000002
#define DIDFT_AXIS		0x00000003
#define DIDFT_PSHBUTTON		0x00000004
#define DIDFT_TGLBUTTON		0x00000008
#define DIDFT_BUTTON		0x0000000C
#define DIDFT_POV		0x00000010
#define DIDFT_COLLECTION	0x00000040
#define DIDFT_NODATA		0x00000080
#define DIDFT_ANYINSTANCE	0x00FFFF00
#define DIDFT_INSTANCEMASK	DIDFT_ANYINSTANCE
#define DIDFT_MAKEINSTANCE(n)	((WORD)(n) << 8)
#define DIDFT_GETTYPE(n)	LOBYTE(n)
#define DIDFT_GETINSTANCE(n)	LOWORD((n) >> 8)
#define DIDFT_FFACTUATOR	0x01000000
#define DIDFT_FFEFFECTTRIGGER	0x02000000
#if DIRECTINPUT_VERSION >= 0x050a
#define DIDFT_OUTPUT		0x10000000
#define DIDFT_VENDORDEFINED	0x04000000
#define DIDFT_ALIAS		0x08000000
#endif /* DI5a */
#ifndef DIDFT_OPTIONAL
#define DIDFT_OPTIONAL		0x80000000
#endif
#define DIDFT_ENUMCOLLECTION(n)	((WORD)(n) << 8)
#define DIDFT_NOCOLLECTION	0x00FFFF00

#define DIDF_ABSAXIS		0x00000001
#define DIDF_RELAXIS		0x00000002

#define DIGDD_PEEK		0x00000001

#define DISEQUENCE_COMPARE(dwSq1,cmp,dwSq2) ((int)((dwSq1) - (dwSq2)) cmp 0)

typedef struct DIDEVICEOBJECTDATA_DX3 {
    DWORD	dwOfs;
    DWORD	dwData;
    DWORD	dwTimeStamp;
    DWORD	dwSequence;
} DIDEVICEOBJECTDATA_DX3,*LPDIDEVICEOBJECTDATA_DX3;
typedef const DIDEVICEOBJECTDATA_DX3 *LPCDIDEVICEOBJECTDATA_DX3;

typedef struct DIDEVICEOBJECTDATA {
    DWORD	dwOfs;
    DWORD	dwData;
    DWORD	dwTimeStamp;
    DWORD	dwSequence;
#if(DIRECTINPUT_VERSION >= 0x0800)
    UINT_PTR	uAppData;
#endif /* DIRECTINPUT_VERSION >= 0x0800 */
} DIDEVICEOBJECTDATA, *LPDIDEVICEOBJECTDATA;
typedef const DIDEVICEOBJECTDATA *LPCDIDEVICEOBJECTDATA;

typedef struct _DIOBJECTDATAFORMAT {
    const GUID *pguid;
    DWORD	dwOfs;
    DWORD	dwType;
    DWORD	dwFlags;
} DIOBJECTDATAFORMAT, *LPDIOBJECTDATAFORMAT;
typedef const DIOBJECTDATAFORMAT *LPCDIOBJECTDATAFORMAT;

typedef struct _DIDATAFORMAT {
    DWORD			dwSize;
    DWORD			dwObjSize;
    DWORD			dwFlags;
    DWORD			dwDataSize;
    DWORD			dwNumObjs;
    LPDIOBJECTDATAFORMAT	rgodf;
} DIDATAFORMAT, *LPDIDATAFORMAT;
typedef const DIDATAFORMAT *LPCDIDATAFORMAT;

#if DIRECTINPUT_VERSION >= 0x0500
#define DIDOI_FFACTUATOR	0x00000001
#define DIDOI_FFEFFECTTRIGGER	0x00000002
#define DIDOI_POLLED		0x00008000
#define DIDOI_ASPECTPOSITION	0x00000100
#define DIDOI_ASPECTVELOCITY	0x00000200
#define DIDOI_ASPECTACCEL	0x00000300
#define DIDOI_ASPECTFORCE	0x00000400
#define DIDOI_ASPECTMASK	0x00000F00
#endif /* DI5 */
#if DIRECTINPUT_VERSION >= 0x050a
#define DIDOI_GUIDISUSAGE	0x00010000
#endif /* DI5a */

typedef struct DIPROPHEADER {
    DWORD	dwSize;
    DWORD	dwHeaderSize;
    DWORD	dwObj;
    DWORD	dwHow;
} DIPROPHEADER,*LPDIPROPHEADER;
typedef const DIPROPHEADER *LPCDIPROPHEADER;

#define DIPH_DEVICE	0
#define DIPH_BYOFFSET	1
#define DIPH_BYID	2
#if DIRECTINPUT_VERSION >= 0x050a
#define DIPH_BYUSAGE	3

#define DIMAKEUSAGEDWORD(UsagePage, Usage) (DWORD)MAKELONG(Usage, UsagePage)
#endif /* DI5a */

typedef struct DIPROPDWORD {
	DIPROPHEADER	diph;
	DWORD		dwData;
} DIPROPDWORD, *LPDIPROPDWORD;
typedef const DIPROPDWORD *LPCDIPROPDWORD;

typedef struct DIPROPRANGE {
	DIPROPHEADER	diph;
	LONG		lMin;
	LONG		lMax;
} DIPROPRANGE, *LPDIPROPRANGE;
typedef const DIPROPRANGE *LPCDIPROPRANGE;

#define DIPROPRANGE_NOMIN	((LONG)0x80000000)
#define DIPROPRANGE_NOMAX	((LONG)0x7FFFFFFF)

#if DIRECTINPUT_VERSION >= 0x050a
typedef struct DIPROPCAL {
	DIPROPHEADER diph;
	LONG	lMin;
	LONG	lCenter;
	LONG	lMax;
} DIPROPCAL, *LPDIPROPCAL;
typedef const DIPROPCAL *LPCDIPROPCAL;

typedef struct DIPROPCALPOV {
	DIPROPHEADER	diph;
	LONG		lMin[5];
	LONG		lMax[5];
} DIPROPCALPOV, *LPDIPROPCALPOV;
typedef const DIPROPCALPOV *LPCDIPROPCALPOV;

typedef struct DIPROPGUIDANDPATH {
	DIPROPHEADER diph;
	GUID    guidClass;
	WCHAR   wszPath[MAX_PATH];
} DIPROPGUIDANDPATH, *LPDIPROPGUIDANDPATH;
typedef const DIPROPGUIDANDPATH *LPCDIPROPGUIDANDPATH;

typedef struct DIPROPSTRING {
        DIPROPHEADER diph;
        WCHAR        wsz[MAX_PATH];
} DIPROPSTRING, *LPDIPROPSTRING;
typedef const DIPROPSTRING *LPCDIPROPSTRING;
#endif /* DI5a */

#if DIRECTINPUT_VERSION >= 0x0800
typedef struct DIPROPPOINTER {
	DIPROPHEADER diph;
	UINT_PTR     uData;
} DIPROPPOINTER, *LPDIPROPPOINTER;
typedef const DIPROPPOINTER *LPCDIPROPPOINTER;
#endif /* DI8 */

/* special property GUIDs */
#ifdef __cplusplus
#define MAKEDIPROP(prop)	(*(const GUID *)(prop))
#else
#define MAKEDIPROP(prop)	((REFGUID)(prop))
#endif
#define DIPROP_BUFFERSIZE	MAKEDIPROP(1)
#define DIPROP_AXISMODE		MAKEDIPROP(2)

#define DIPROPAXISMODE_ABS	0
#define DIPROPAXISMODE_REL	1

#define DIPROP_GRANULARITY	MAKEDIPROP(3)
#define DIPROP_RANGE		MAKEDIPROP(4)
#define DIPROP_DEADZONE		MAKEDIPROP(5)
#define DIPROP_SATURATION	MAKEDIPROP(6)
#define DIPROP_FFGAIN		MAKEDIPROP(7)
#define DIPROP_FFLOAD		MAKEDIPROP(8)
#define DIPROP_AUTOCENTER	MAKEDIPROP(9)

#define DIPROPAUTOCENTER_OFF	0
#define DIPROPAUTOCENTER_ON	1

#define DIPROP_CALIBRATIONMODE	MAKEDIPROP(10)

#define DIPROPCALIBRATIONMODE_COOKED	0
#define DIPROPCALIBRATIONMODE_RAW	1

#if DIRECTINPUT_VERSION >= 0x050a
#define DIPROP_CALIBRATION	MAKEDIPROP(11)
#define DIPROP_GUIDANDPATH	MAKEDIPROP(12)
#define DIPROP_INSTANCENAME	MAKEDIPROP(13)
#define DIPROP_PRODUCTNAME	MAKEDIPROP(14)
#endif

#if DIRECTINPUT_VERSION >= 0x5B2
#define DIPROP_JOYSTICKID	MAKEDIPROP(15)
#define DIPROP_GETPORTDISPLAYNAME	MAKEDIPROP(16)
#endif

#if DIRECTINPUT_VERSION >= 0x0700
#define DIPROP_PHYSICALRANGE	MAKEDIPROP(18)
#define DIPROP_LOGICALRANGE	MAKEDIPROP(19)
#endif

#if(DIRECTINPUT_VERSION >= 0x0800)
#define DIPROP_KEYNAME		MAKEDIPROP(20)
#define DIPROP_CPOINTS		MAKEDIPROP(21)
#define DIPROP_APPDATA		MAKEDIPROP(22)
#define DIPROP_SCANCODE		MAKEDIPROP(23)
#define DIPROP_VIDPID		MAKEDIPROP(24)
#define DIPROP_USERNAME		MAKEDIPROP(25)
#define DIPROP_TYPENAME		MAKEDIPROP(26)

#define MAXCPOINTSNUM		8

typedef struct _CPOINT {
    LONG	lP;
    DWORD	dwLog;
} CPOINT, *PCPOINT;

typedef struct DIPROPCPOINTS {
    DIPROPHEADER diph;
    DWORD	dwCPointsNum;
    CPOINT	cp[MAXCPOINTSNUM];
} DIPROPCPOINTS, *LPDIPROPCPOINTS;
typedef const DIPROPCPOINTS *LPCDIPROPCPOINTS;
#endif /* DI8 */


typedef struct DIDEVCAPS_DX3 {
    DWORD	dwSize;
    DWORD	dwFlags;
    DWORD	dwDevType;
    DWORD	dwAxes;
    DWORD	dwButtons;
    DWORD	dwPOVs;
} DIDEVCAPS_DX3, *LPDIDEVCAPS_DX3;

typedef struct DIDEVCAPS {
    DWORD	dwSize;
    DWORD	dwFlags;
    DWORD	dwDevType;
    DWORD	dwAxes;
    DWORD	dwButtons;
    DWORD	dwPOVs;
#if(DIRECTINPUT_VERSION >= 0x0500)
    DWORD	dwFFSamplePeriod;
    DWORD	dwFFMinTimeResolution;
    DWORD	dwFirmwareRevision;
    DWORD	dwHardwareRevision;
    DWORD	dwFFDriverVersion;
#endif /* DIRECTINPUT_VERSION >= 0x0500 */
} DIDEVCAPS,*LPDIDEVCAPS;

#define DIDC_ATTACHED		0x00000001
#define DIDC_POLLEDDEVICE	0x00000002
#define DIDC_EMULATED		0x00000004
#define DIDC_POLLEDDATAFORMAT	0x00000008
#define DIDC_FORCEFEEDBACK	0x00000100
#define DIDC_FFATTACK		0x00000200
#define DIDC_FFFADE		0x00000400
#define DIDC_SATURATION		0x00000800
#define DIDC_POSNEGCOEFFICIENTS	0x00001000
#define DIDC_POSNEGSATURATION	0x00002000
#define DIDC_DEADBAND		0x00004000
#define DIDC_STARTDELAY		0x00008000
#define DIDC_ALIAS		0x00010000
#define DIDC_PHANTOM		0x00020000
#define DIDC_HIDDEN		0x00040000


/* SetCooperativeLevel dwFlags */
#define DISCL_EXCLUSIVE		0x00000001
#define DISCL_NONEXCLUSIVE	0x00000002
#define DISCL_FOREGROUND	0x00000004
#define DISCL_BACKGROUND	0x00000008
#define DISCL_NOWINKEY          0x00000010

#if (DIRECTINPUT_VERSION >= 0x0500)
/* Device FF flags */
#define DISFFC_RESET            0x00000001
#define DISFFC_STOPALL          0x00000002
#define DISFFC_PAUSE            0x00000004
#define DISFFC_CONTINUE         0x00000008
#define DISFFC_SETACTUATORSON   0x00000010
#define DISFFC_SETACTUATORSOFF  0x00000020

#define DIGFFS_EMPTY            0x00000001
#define DIGFFS_STOPPED          0x00000002
#define DIGFFS_PAUSED           0x00000004
#define DIGFFS_ACTUATORSON      0x00000010
#define DIGFFS_ACTUATORSOFF     0x00000020
#define DIGFFS_POWERON          0x00000040
#define DIGFFS_POWEROFF         0x00000080
#define DIGFFS_SAFETYSWITCHON   0x00000100
#define DIGFFS_SAFETYSWITCHOFF  0x00000200
#define DIGFFS_USERFFSWITCHON   0x00000400
#define DIGFFS_USERFFSWITCHOFF  0x00000800
#define DIGFFS_DEVICELOST       0x80000000

/* Effect flags */
#define DIEFT_ALL		0x00000000

#define DIEFT_CONSTANTFORCE	0x00000001
#define DIEFT_RAMPFORCE		0x00000002
#define DIEFT_PERIODIC		0x00000003
#define DIEFT_CONDITION		0x00000004
#define DIEFT_CUSTOMFORCE	0x00000005
#define DIEFT_HARDWARE		0x000000FF
#define DIEFT_FFATTACK		0x00000200
#define DIEFT_FFFADE		0x00000400
#define DIEFT_SATURATION	0x00000800
#define DIEFT_POSNEGCOEFFICIENTS 0x00001000
#define DIEFT_POSNEGSATURATION	0x00002000
#define DIEFT_DEADBAND		0x00004000
#define DIEFT_STARTDELAY	0x00008000
#define DIEFT_GETTYPE(n)	LOBYTE(n)

#define DIEFF_OBJECTIDS         0x00000001
#define DIEFF_OBJECTOFFSETS     0x00000002
#define DIEFF_CARTESIAN         0x00000010
#define DIEFF_POLAR             0x00000020
#define DIEFF_SPHERICAL         0x00000040

#define DIEP_DURATION           0x00000001
#define DIEP_SAMPLEPERIOD       0x00000002
#define DIEP_GAIN               0x00000004
#define DIEP_TRIGGERBUTTON      0x00000008
#define DIEP_TRIGGERREPEATINTERVAL 0x00000010
#define DIEP_AXES               0x00000020
#define DIEP_DIRECTION          0x00000040
#define DIEP_ENVELOPE           0x00000080
#define DIEP_TYPESPECIFICPARAMS 0x00000100
#if(DIRECTINPUT_VERSION >= 0x0600)
#define DIEP_STARTDELAY         0x00000200
#define DIEP_ALLPARAMS_DX5      0x000001FF
#define DIEP_ALLPARAMS          0x000003FF
#else
#define DIEP_ALLPARAMS          0x000001FF
#endif /* DIRECTINPUT_VERSION >= 0x0600 */
#define DIEP_START              0x20000000
#define DIEP_NORESTART          0x40000000
#define DIEP_NODOWNLOAD         0x80000000
#define DIEB_NOTRIGGER          0xFFFFFFFF

#define DIES_SOLO               0x00000001
#define DIES_NODOWNLOAD         0x80000000

#define DIEGES_PLAYING          0x00000001
#define DIEGES_EMULATED         0x00000002

#define DI_DEGREES		100
#define DI_FFNOMINALMAX		10000
#define DI_SECONDS		1000000

typedef struct DICONSTANTFORCE {
	LONG			lMagnitude;
} DICONSTANTFORCE, *LPDICONSTANTFORCE;
typedef const DICONSTANTFORCE *LPCDICONSTANTFORCE;

typedef struct DIRAMPFORCE {
	LONG			lStart;
	LONG			lEnd;
} DIRAMPFORCE, *LPDIRAMPFORCE;
typedef const DIRAMPFORCE *LPCDIRAMPFORCE;

typedef struct DIPERIODIC {
	DWORD			dwMagnitude;
	LONG			lOffset;
	DWORD			dwPhase;
	DWORD			dwPeriod;
} DIPERIODIC, *LPDIPERIODIC;
typedef const DIPERIODIC *LPCDIPERIODIC;

typedef struct DICONDITION {
	LONG			lOffset;
	LONG			lPositiveCoefficient;
	LONG			lNegativeCoefficient;
	DWORD			dwPositiveSaturation;
	DWORD			dwNegativeSaturation;
	LONG			lDeadBand;
} DICONDITION, *LPDICONDITION;
typedef const DICONDITION *LPCDICONDITION;

typedef struct DICUSTOMFORCE {
	DWORD			cChannels;
	DWORD			dwSamplePeriod;
	DWORD			cSamples;
	LPLONG			rglForceData;
} DICUSTOMFORCE, *LPDICUSTOMFORCE;
typedef const DICUSTOMFORCE *LPCDICUSTOMFORCE;

typedef struct DIENVELOPE {
	DWORD			dwSize;
	DWORD			dwAttackLevel;
	DWORD			dwAttackTime;
	DWORD			dwFadeLevel;
	DWORD			dwFadeTime;
} DIENVELOPE, *LPDIENVELOPE;
typedef const DIENVELOPE *LPCDIENVELOPE;

typedef struct DIEFFECT_DX5 {
	DWORD			dwSize;
	DWORD			dwFlags;
	DWORD			dwDuration;
	DWORD			dwSamplePeriod;
	DWORD			dwGain;
	DWORD			dwTriggerButton;
	DWORD			dwTriggerRepeatInterval;
	DWORD			cAxes;
	LPDWORD			rgdwAxes;
	LPLONG			rglDirection;
	LPDIENVELOPE		lpEnvelope;
	DWORD			cbTypeSpecificParams;
	LPVOID			lpvTypeSpecificParams;
} DIEFFECT_DX5, *LPDIEFFECT_DX5;
typedef const DIEFFECT_DX5 *LPCDIEFFECT_DX5;

typedef struct DIEFFECT {
	DWORD			dwSize;
	DWORD			dwFlags;
	DWORD			dwDuration;
	DWORD			dwSamplePeriod;
	DWORD			dwGain;
	DWORD			dwTriggerButton;
	DWORD			dwTriggerRepeatInterval;
	DWORD			cAxes;
	LPDWORD			rgdwAxes;
	LPLONG			rglDirection;
	LPDIENVELOPE		lpEnvelope;
	DWORD			cbTypeSpecificParams;
	LPVOID			lpvTypeSpecificParams;
#if(DIRECTINPUT_VERSION >= 0x0600)
	DWORD			dwStartDelay;
#endif /* DIRECTINPUT_VERSION >= 0x0600 */
} DIEFFECT, *LPDIEFFECT;
typedef const DIEFFECT *LPCDIEFFECT;
typedef DIEFFECT DIEFFECT_DX6;
typedef LPDIEFFECT LPDIEFFECT_DX6;

typedef struct DIEFFECTINFOA {
	DWORD			dwSize;
	GUID			guid;
	DWORD			dwEffType;
	DWORD			dwStaticParams;
	DWORD			dwDynamicParams;
	CHAR			tszName[MAX_PATH];
} DIEFFECTINFOA, *LPDIEFFECTINFOA;
typedef const DIEFFECTINFOA *LPCDIEFFECTINFOA;

typedef struct DIEFFECTINFOW {
	DWORD			dwSize;
	GUID			guid;
	DWORD			dwEffType;
	DWORD			dwStaticParams;
	DWORD			dwDynamicParams;
	WCHAR			tszName[MAX_PATH];
} DIEFFECTINFOW, *LPDIEFFECTINFOW;
typedef const DIEFFECTINFOW *LPCDIEFFECTINFOW;

DECL_WINELIB_TYPE_AW(DIEFFECTINFO)
DECL_WINELIB_TYPE_AW(LPDIEFFECTINFO)
DECL_WINELIB_TYPE_AW(LPCDIEFFECTINFO)

typedef WINBOOL (CALLBACK *LPDIENUMEFFECTSCALLBACKA)(LPCDIEFFECTINFOA, LPVOID);
typedef WINBOOL (CALLBACK *LPDIENUMEFFECTSCALLBACKW)(LPCDIEFFECTINFOW, LPVOID);
DECL_WINELIB_TYPE_AW(LPDIENUMEFFECTSCALLBACK)

typedef struct DIEFFESCAPE {
	DWORD	dwSize;
	DWORD	dwCommand;
	LPVOID	lpvInBuffer;
	DWORD	cbInBuffer;
	LPVOID	lpvOutBuffer;
	DWORD	cbOutBuffer;
} DIEFFESCAPE, *LPDIEFFESCAPE;

typedef struct DIJOYSTATE {
	LONG	lX;
	LONG	lY;
	LONG	lZ;
	LONG	lRx;
	LONG	lRy;
	LONG	lRz;
	LONG	rglSlider[2];
	DWORD	rgdwPOV[4];
	BYTE	rgbButtons[32];
} DIJOYSTATE, *LPDIJOYSTATE;

typedef struct DIJOYSTATE2 {
	LONG	lX;
	LONG	lY;
	LONG	lZ;
	LONG	lRx;
	LONG	lRy;
	LONG	lRz;
	LONG	rglSlider[2];
	DWORD	rgdwPOV[4];
	BYTE	rgbButtons[128];
	LONG	lVX;		/* 'v' as in velocity */
	LONG	lVY;
	LONG	lVZ;
	LONG	lVRx;
	LONG	lVRy;
	LONG	lVRz;
	LONG	rglVSlider[2];
	LONG	lAX;		/* 'a' as in acceleration */
	LONG	lAY;
	LONG	lAZ;
	LONG	lARx;
	LONG	lARy;
	LONG	lARz;
	LONG	rglASlider[2];
	LONG	lFX;		/* 'f' as in force */
	LONG	lFY;
	LONG	lFZ;
	LONG	lFRx;		/* 'fr' as in rotational force aka torque */
	LONG	lFRy;
	LONG	lFRz;
	LONG	rglFSlider[2];
} DIJOYSTATE2, *LPDIJOYSTATE2;

#define DIJOFS_X		FIELD_OFFSET(DIJOYSTATE, lX)
#define DIJOFS_Y		FIELD_OFFSET(DIJOYSTATE, lY)
#define DIJOFS_Z		FIELD_OFFSET(DIJOYSTATE, lZ)
#define DIJOFS_RX		FIELD_OFFSET(DIJOYSTATE, lRx)
#define DIJOFS_RY		FIELD_OFFSET(DIJOYSTATE, lRy)
#define DIJOFS_RZ		FIELD_OFFSET(DIJOYSTATE, lRz)
#define DIJOFS_SLIDER(n)	(FIELD_OFFSET(DIJOYSTATE, rglSlider) + \
                                                        (n) * sizeof(LONG))
#define DIJOFS_POV(n)		(FIELD_OFFSET(DIJOYSTATE, rgdwPOV) + \
                                                        (n) * sizeof(DWORD))
#define DIJOFS_BUTTON(n)	(FIELD_OFFSET(DIJOYSTATE, rgbButtons) + (n))
#define DIJOFS_BUTTON0		DIJOFS_BUTTON(0)
#define DIJOFS_BUTTON1		DIJOFS_BUTTON(1)
#define DIJOFS_BUTTON2		DIJOFS_BUTTON(2)
#define DIJOFS_BUTTON3		DIJOFS_BUTTON(3)
#define DIJOFS_BUTTON4		DIJOFS_BUTTON(4)
#define DIJOFS_BUTTON5		DIJOFS_BUTTON(5)
#define DIJOFS_BUTTON6		DIJOFS_BUTTON(6)
#define DIJOFS_BUTTON7		DIJOFS_BUTTON(7)
#define DIJOFS_BUTTON8		DIJOFS_BUTTON(8)
#define DIJOFS_BUTTON9		DIJOFS_BUTTON(9)
#define DIJOFS_BUTTON10		DIJOFS_BUTTON(10)
#define DIJOFS_BUTTON11		DIJOFS_BUTTON(11)
#define DIJOFS_BUTTON12		DIJOFS_BUTTON(12)
#define DIJOFS_BUTTON13		DIJOFS_BUTTON(13)
#define DIJOFS_BUTTON14		DIJOFS_BUTTON(14)
#define DIJOFS_BUTTON15		DIJOFS_BUTTON(15)
#define DIJOFS_BUTTON16		DIJOFS_BUTTON(16)
#define DIJOFS_BUTTON17		DIJOFS_BUTTON(17)
#define DIJOFS_BUTTON18		DIJOFS_BUTTON(18)
#define DIJOFS_BUTTON19		DIJOFS_BUTTON(19)
#define DIJOFS_BUTTON20		DIJOFS_BUTTON(20)
#define DIJOFS_BUTTON21		DIJOFS_BUTTON(21)
#define DIJOFS_BUTTON22		DIJOFS_BUTTON(22)
#define DIJOFS_BUTTON23		DIJOFS_BUTTON(23)
#define DIJOFS_BUTTON24		DIJOFS_BUTTON(24)
#define DIJOFS_BUTTON25		DIJOFS_BUTTON(25)
#define DIJOFS_BUTTON26		DIJOFS_BUTTON(26)
#define DIJOFS_BUTTON27		DIJOFS_BUTTON(27)
#define DIJOFS_BUTTON28		DIJOFS_BUTTON(28)
#define DIJOFS_BUTTON29		DIJOFS_BUTTON(29)
#define DIJOFS_BUTTON30		DIJOFS_BUTTON(30)
#define DIJOFS_BUTTON31		DIJOFS_BUTTON(31)
#endif /* DIRECTINPUT_VERSION >= 0x0500 */

/* DInput 7 structures, types */
#if(DIRECTINPUT_VERSION >= 0x0700)
typedef struct DIFILEEFFECT {
  DWORD       dwSize;
  GUID        GuidEffect;
  LPCDIEFFECT lpDiEffect;
  CHAR        szFriendlyName[MAX_PATH];
} DIFILEEFFECT, *LPDIFILEEFFECT;

typedef const DIFILEEFFECT *LPCDIFILEEFFECT;
typedef WINBOOL (CALLBACK *LPDIENUMEFFECTSINFILECALLBACK)(LPCDIFILEEFFECT , LPVOID);
#endif /* DIRECTINPUT_VERSION >= 0x0700 */

/* DInput 8 structures and types */
#if DIRECTINPUT_VERSION >= 0x0800
typedef struct _DIACTIONA {
	UINT_PTR	uAppData;
	DWORD		dwSemantic;
	DWORD		dwFlags;
	__GNU_EXTENSION union {
		LPCSTR	lptszActionName;
		UINT	uResIdString;
	} DUMMYUNIONNAME;
	GUID		guidInstance;
	DWORD		dwObjID;
	DWORD		dwHow;
} DIACTIONA, *LPDIACTIONA;
typedef const DIACTIONA *LPCDIACTIONA;

typedef struct _DIACTIONW {
	UINT_PTR	uAppData;
	DWORD		dwSemantic;
	DWORD		dwFlags;
	__GNU_EXTENSION union {
		LPCWSTR	lptszActionName;
		UINT	uResIdString;
	} DUMMYUNIONNAME;
	GUID		guidInstance;
	DWORD		dwObjID;
	DWORD		dwHow;
} DIACTIONW, *LPDIACTIONW;
typedef const DIACTIONW *LPCDIACTIONW;

DECL_WINELIB_TYPE_AW(DIACTION)
DECL_WINELIB_TYPE_AW(LPDIACTION)
DECL_WINELIB_TYPE_AW(LPCDIACTION)

#define DIA_FORCEFEEDBACK	0x00000001
#define DIA_APPMAPPED		0x00000002
#define DIA_APPNOMAP		0x00000004
#define DIA_NORANGE		0x00000008
#define DIA_APPFIXED		0x00000010

#define DIAH_UNMAPPED		0x00000000
#define DIAH_USERCONFIG		0x00000001
#define DIAH_APPREQUESTED	0x00000002
#define DIAH_HWAPP		0x00000004
#define DIAH_HWDEFAULT		0x00000008
#define DIAH_DEFAULT		0x00000020
#define DIAH_ERROR		0x80000000

typedef struct _DIACTIONFORMATA {
	DWORD		dwSize;
	DWORD		dwActionSize;
	DWORD		dwDataSize;
	DWORD		dwNumActions;
	LPDIACTIONA	rgoAction;
	GUID		guidActionMap;
	DWORD		dwGenre;
	DWORD		dwBufferSize;
	LONG		lAxisMin;
	LONG		lAxisMax;
	HINSTANCE	hInstString;
	FILETIME	ftTimeStamp;
	DWORD		dwCRC;
	CHAR		tszActionMap[MAX_PATH];
} DIACTIONFORMATA, *LPDIACTIONFORMATA;
typedef const DIACTIONFORMATA *LPCDIACTIONFORMATA;

typedef struct _DIACTIONFORMATW {
	DWORD		dwSize;
	DWORD		dwActionSize;
	DWORD		dwDataSize;
	DWORD		dwNumActions;
	LPDIACTIONW	rgoAction;
	GUID		guidActionMap;
	DWORD		dwGenre;
	DWORD		dwBufferSize;
	LONG		lAxisMin;
	LONG		lAxisMax;
	HINSTANCE	hInstString;
	FILETIME	ftTimeStamp;
	DWORD		dwCRC;
	WCHAR		tszActionMap[MAX_PATH];
} DIACTIONFORMATW, *LPDIACTIONFORMATW;
typedef const DIACTIONFORMATW *LPCDIACTIONFORMATW;

DECL_WINELIB_TYPE_AW(DIACTIONFORMAT)
DECL_WINELIB_TYPE_AW(LPDIACTIONFORMAT)
DECL_WINELIB_TYPE_AW(LPCDIACTIONFORMAT)

#define DIAFTS_NEWDEVICELOW	0xFFFFFFFF
#define DIAFTS_NEWDEVICEHIGH	0xFFFFFFFF
#define DIAFTS_UNUSEDDEVICELOW	0x00000000
#define DIAFTS_UNUSEDDEVICEHIGH	0x00000000

#define DIDBAM_DEFAULT		0x00000000
#define DIDBAM_PRESERVE		0x00000001
#define DIDBAM_INITIALIZE	0x00000002
#define DIDBAM_HWDEFAULTS	0x00000004

#define DIDSAM_DEFAULT		0x00000000
#define DIDSAM_NOUSER		0x00000001
#define DIDSAM_FORCESAVE	0x00000002

#define DICD_DEFAULT		0x00000000
#define DICD_EDIT		0x00000001

#ifndef D3DCOLOR_DEFINED
typedef DWORD D3DCOLOR;
#define D3DCOLOR_DEFINED
#endif

typedef struct _DICOLORSET {
	DWORD		dwSize;
	D3DCOLOR	cTextFore;
	D3DCOLOR	cTextHighlight;
	D3DCOLOR	cCalloutLine;
	D3DCOLOR	cCalloutHighlight;
	D3DCOLOR	cBorder;
	D3DCOLOR	cControlFill;
	D3DCOLOR	cHighlightFill;
	D3DCOLOR	cAreaFill;
} DICOLORSET, *LPDICOLORSET;
typedef const DICOLORSET *LPCDICOLORSET;

typedef struct _DICONFIGUREDEVICESPARAMSA {
	DWORD			dwSize;
	DWORD			dwcUsers;
	LPSTR			lptszUserNames;
	DWORD			dwcFormats;
	LPDIACTIONFORMATA	lprgFormats;
	HWND			hwnd;
	DICOLORSET		dics;
	LPUNKNOWN		lpUnkDDSTarget;
} DICONFIGUREDEVICESPARAMSA, *LPDICONFIGUREDEVICESPARAMSA;
typedef const DICONFIGUREDEVICESPARAMSA *LPCDICONFIGUREDEVICESPARAMSA;

typedef struct _DICONFIGUREDEVICESPARAMSW {
	DWORD			dwSize;
	DWORD			dwcUsers;
	LPWSTR			lptszUserNames;
	DWORD			dwcFormats;
	LPDIACTIONFORMATW	lprgFormats;
	HWND			hwnd;
	DICOLORSET		dics;
	LPUNKNOWN		lpUnkDDSTarget;
} DICONFIGUREDEVICESPARAMSW, *LPDICONFIGUREDEVICESPARAMSW;
typedef const DICONFIGUREDEVICESPARAMSW *LPCDICONFIGUREDEVICESPARAMSW;

DECL_WINELIB_TYPE_AW(DICONFIGUREDEVICESPARAMS)
DECL_WINELIB_TYPE_AW(LPDICONFIGUREDEVICESPARAMS)
DECL_WINELIB_TYPE_AW(LPCDICONFIGUREDEVICESPARAMS)

#define DIDIFT_CONFIGURATION	0x00000001
#define DIDIFT_OVERLAY		0x00000002

#define DIDAL_CENTERED		0x00000000
#define DIDAL_LEFTALIGNED	0x00000001
#define DIDAL_RIGHTALIGNED	0x00000002
#define DIDAL_MIDDLE		0x00000000
#define DIDAL_TOPALIGNED	0x00000004
#define DIDAL_BOTTOMALIGNED	0x00000008

typedef struct _DIDEVICEIMAGEINFOA {
	CHAR	tszImagePath[MAX_PATH];
	DWORD	dwFlags;
	DWORD	dwViewID;
	RECT	rcOverlay;
	DWORD	dwObjID;
	DWORD	dwcValidPts;
	POINT	rgptCalloutLine[5];
	RECT	rcCalloutRect;
	DWORD	dwTextAlign;
} DIDEVICEIMAGEINFOA, *LPDIDEVICEIMAGEINFOA;
typedef const DIDEVICEIMAGEINFOA *LPCDIDEVICEIMAGEINFOA;

typedef struct _DIDEVICEIMAGEINFOW {
	WCHAR	tszImagePath[MAX_PATH];
	DWORD	dwFlags;
	DWORD	dwViewID;
	RECT	rcOverlay;
	DWORD	dwObjID;
	DWORD	dwcValidPts;
	POINT	rgptCalloutLine[5];
	RECT	rcCalloutRect;
	DWORD	dwTextAlign;
} DIDEVICEIMAGEINFOW, *LPDIDEVICEIMAGEINFOW;
typedef const DIDEVICEIMAGEINFOW *LPCDIDEVICEIMAGEINFOW;

DECL_WINELIB_TYPE_AW(DIDEVICEIMAGEINFO)
DECL_WINELIB_TYPE_AW(LPDIDEVICEIMAGEINFO)
DECL_WINELIB_TYPE_AW(LPCDIDEVICEIMAGEINFO)

typedef struct _DIDEVICEIMAGEINFOHEADERA {
	DWORD	dwSize;
	DWORD	dwSizeImageInfo;
	DWORD	dwcViews;
	DWORD	dwcButtons;
	DWORD	dwcAxes;
	DWORD	dwcPOVs;
	DWORD	dwBufferSize;
	DWORD	dwBufferUsed;
	LPDIDEVICEIMAGEINFOA	lprgImageInfoArray;
} DIDEVICEIMAGEINFOHEADERA, *LPDIDEVICEIMAGEINFOHEADERA;
typedef const DIDEVICEIMAGEINFOHEADERA *LPCDIDEVICEIMAGEINFOHEADERA;

typedef struct _DIDEVICEIMAGEINFOHEADERW {
	DWORD	dwSize;
	DWORD	dwSizeImageInfo;
	DWORD	dwcViews;
	DWORD	dwcButtons;
	DWORD	dwcAxes;
	DWORD	dwcPOVs;
	DWORD	dwBufferSize;
	DWORD	dwBufferUsed;
	LPDIDEVICEIMAGEINFOW	lprgImageInfoArray;
} DIDEVICEIMAGEINFOHEADERW, *LPDIDEVICEIMAGEINFOHEADERW;
typedef const DIDEVICEIMAGEINFOHEADERW *LPCDIDEVICEIMAGEINFOHEADERW;

DECL_WINELIB_TYPE_AW(DIDEVICEIMAGEINFOHEADER)
DECL_WINELIB_TYPE_AW(LPDIDEVICEIMAGEINFOHEADER)
DECL_WINELIB_TYPE_AW(LPCDIDEVICEIMAGEINFOHEADER)

#endif /* DI8 */


/*****************************************************************************
 * IDirectInputEffect interface
 */
#if (DIRECTINPUT_VERSION >= 0x0500)
#undef INTERFACE
#define INTERFACE IDirectInputEffect
DECLARE_INTERFACE_(IDirectInputEffect,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputEffect methods ***/
    STDMETHOD(Initialize)(THIS_ HINSTANCE, DWORD, REFGUID) PURE;
    STDMETHOD(GetEffectGuid)(THIS_ LPGUID) PURE;
    STDMETHOD(GetParameters)(THIS_ LPDIEFFECT, DWORD) PURE;
    STDMETHOD(SetParameters)(THIS_ LPCDIEFFECT, DWORD) PURE;
    STDMETHOD(Start)(THIS_ DWORD, DWORD) PURE;
    STDMETHOD(Stop)(THIS) PURE;
    STDMETHOD(GetEffectStatus)(THIS_ LPDWORD) PURE;
    STDMETHOD(Download)(THIS) PURE;
    STDMETHOD(Unload)(THIS) PURE;
    STDMETHOD(Escape)(THIS_ LPDIEFFESCAPE) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectInputEffect_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectInputEffect_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectInputEffect_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectInputEffect methods ***/
#define IDirectInputEffect_Initialize(p,a,b,c)    (p)->lpVtbl->Initialize(p,a,b,c)
#define IDirectInputEffect_GetEffectGuid(p,a)     (p)->lpVtbl->GetEffectGuid(p,a)
#define IDirectInputEffect_GetParameters(p,a,b)   (p)->lpVtbl->GetParameters(p,a,b)
#define IDirectInputEffect_SetParameters(p,a,b)   (p)->lpVtbl->SetParameters(p,a,b)
#define IDirectInputEffect_Start(p,a,b)           (p)->lpVtbl->Start(p,a,b)
#define IDirectInputEffect_Stop(p)                (p)->lpVtbl->Stop(p)
#define IDirectInputEffect_GetEffectStatus(p,a)   (p)->lpVtbl->GetEffectStatus(p,a)
#define IDirectInputEffect_Download(p)            (p)->lpVtbl->Download(p)
#define IDirectInputEffect_Unload(p)              (p)->lpVtbl->Unload(p)
#define IDirectInputEffect_Escape(p,a)            (p)->lpVtbl->Escape(p,a)
#else
/*** IUnknown methods ***/
#define IDirectInputEffect_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectInputEffect_AddRef(p)             (p)->AddRef()
#define IDirectInputEffect_Release(p)            (p)->Release()
/*** IDirectInputEffect methods ***/
#define IDirectInputEffect_Initialize(p,a,b,c)    (p)->Initialize(a,b,c)
#define IDirectInputEffect_GetEffectGuid(p,a)     (p)->GetEffectGuid(a)
#define IDirectInputEffect_GetParameters(p,a,b)   (p)->GetParameters(a,b)
#define IDirectInputEffect_SetParameters(p,a,b)   (p)->SetParameters(a,b)
#define IDirectInputEffect_Start(p,a,b)           (p)->Start(a,b)
#define IDirectInputEffect_Stop(p)                (p)->Stop()
#define IDirectInputEffect_GetEffectStatus(p,a)   (p)->GetEffectStatus(a)
#define IDirectInputEffect_Download(p)            (p)->Download()
#define IDirectInputEffect_Unload(p)              (p)->Unload()
#define IDirectInputEffect_Escape(p,a)            (p)->Escape(a)
#endif

#endif /* DI5 */


/*****************************************************************************
 * IDirectInputDeviceA interface
 */
#undef INTERFACE
#define INTERFACE IDirectInputDeviceA
DECLARE_INTERFACE_(IDirectInputDeviceA,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputDeviceA methods ***/
    STDMETHOD(GetCapabilities)(THIS_ LPDIDEVCAPS lpDIDevCaps) PURE;
    STDMETHOD(EnumObjects)(THIS_ LPDIENUMDEVICEOBJECTSCALLBACKA lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetProperty)(THIS_ REFGUID rguidProp, LPDIPROPHEADER pdiph) PURE;
    STDMETHOD(SetProperty)(THIS_ REFGUID rguidProp, LPCDIPROPHEADER pdiph) PURE;
    STDMETHOD(Acquire)(THIS) PURE;
    STDMETHOD(Unacquire)(THIS) PURE;
    STDMETHOD(GetDeviceState)(THIS_ DWORD cbData, LPVOID lpvData) PURE;
    STDMETHOD(GetDeviceData)(THIS_ DWORD cbObjectData, LPDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD dwFlags) PURE;
    STDMETHOD(SetDataFormat)(THIS_ LPCDIDATAFORMAT lpdf) PURE;
    STDMETHOD(SetEventNotification)(THIS_ HANDLE hEvent) PURE;
    STDMETHOD(SetCooperativeLevel)(THIS_ HWND hwnd, DWORD dwFlags) PURE;
    STDMETHOD(GetObjectInfo)(THIS_ LPDIDEVICEOBJECTINSTANCEA pdidoi, DWORD dwObj, DWORD dwHow) PURE;
    STDMETHOD(GetDeviceInfo)(THIS_ LPDIDEVICEINSTANCEA pdidi) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion, REFGUID rguid) PURE;
};

/*****************************************************************************
 * IDirectInputDeviceW interface
 */
#undef INTERFACE
#define INTERFACE IDirectInputDeviceW
DECLARE_INTERFACE_(IDirectInputDeviceW,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputDeviceW methods ***/
    STDMETHOD(GetCapabilities)(THIS_ LPDIDEVCAPS lpDIDevCaps) PURE;
    STDMETHOD(EnumObjects)(THIS_ LPDIENUMDEVICEOBJECTSCALLBACKW lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetProperty)(THIS_ REFGUID rguidProp, LPDIPROPHEADER pdiph) PURE;
    STDMETHOD(SetProperty)(THIS_ REFGUID rguidProp, LPCDIPROPHEADER pdiph) PURE;
    STDMETHOD(Acquire)(THIS) PURE;
    STDMETHOD(Unacquire)(THIS) PURE;
    STDMETHOD(GetDeviceState)(THIS_ DWORD cbData, LPVOID lpvData) PURE;
    STDMETHOD(GetDeviceData)(THIS_ DWORD cbObjectData, LPDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD dwFlags) PURE;
    STDMETHOD(SetDataFormat)(THIS_ LPCDIDATAFORMAT lpdf) PURE;
    STDMETHOD(SetEventNotification)(THIS_ HANDLE hEvent) PURE;
    STDMETHOD(SetCooperativeLevel)(THIS_ HWND hwnd, DWORD dwFlags) PURE;
    STDMETHOD(GetObjectInfo)(THIS_ LPDIDEVICEOBJECTINSTANCEW pdidoi, DWORD dwObj, DWORD dwHow) PURE;
    STDMETHOD(GetDeviceInfo)(THIS_ LPDIDEVICEINSTANCEW pdidi) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion, REFGUID rguid) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectInputDevice_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectInputDevice_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectInputDevice_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectInputDevice methods ***/
#define IDirectInputDevice_GetCapabilities(p,a)       (p)->lpVtbl->GetCapabilities(p,a)
#define IDirectInputDevice_EnumObjects(p,a,b,c)       (p)->lpVtbl->EnumObjects(p,a,b,c)
#define IDirectInputDevice_GetProperty(p,a,b)         (p)->lpVtbl->GetProperty(p,a,b)
#define IDirectInputDevice_SetProperty(p,a,b)         (p)->lpVtbl->SetProperty(p,a,b)
#define IDirectInputDevice_Acquire(p)                 (p)->lpVtbl->Acquire(p)
#define IDirectInputDevice_Unacquire(p)               (p)->lpVtbl->Unacquire(p)
#define IDirectInputDevice_GetDeviceState(p,a,b)      (p)->lpVtbl->GetDeviceState(p,a,b)
#define IDirectInputDevice_GetDeviceData(p,a,b,c,d)   (p)->lpVtbl->GetDeviceData(p,a,b,c,d)
#define IDirectInputDevice_SetDataFormat(p,a)         (p)->lpVtbl->SetDataFormat(p,a)
#define IDirectInputDevice_SetEventNotification(p,a)  (p)->lpVtbl->SetEventNotification(p,a)
#define IDirectInputDevice_SetCooperativeLevel(p,a,b) (p)->lpVtbl->SetCooperativeLevel(p,a,b)
#define IDirectInputDevice_GetObjectInfo(p,a,b,c)     (p)->lpVtbl->GetObjectInfo(p,a,b,c)
#define IDirectInputDevice_GetDeviceInfo(p,a)         (p)->lpVtbl->GetDeviceInfo(p,a)
#define IDirectInputDevice_RunControlPanel(p,a,b)     (p)->lpVtbl->RunControlPanel(p,a,b)
#define IDirectInputDevice_Initialize(p,a,b,c)        (p)->lpVtbl->Initialize(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirectInputDevice_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectInputDevice_AddRef(p)             (p)->AddRef()
#define IDirectInputDevice_Release(p)            (p)->Release()
/*** IDirectInputDevice methods ***/
#define IDirectInputDevice_GetCapabilities(p,a)       (p)->GetCapabilities(a)
#define IDirectInputDevice_EnumObjects(p,a,b,c)       (p)->EnumObjects(a,b,c)
#define IDirectInputDevice_GetProperty(p,a,b)         (p)->GetProperty(a,b)
#define IDirectInputDevice_SetProperty(p,a,b)         (p)->SetProperty(a,b)
#define IDirectInputDevice_Acquire(p)                 (p)->Acquire()
#define IDirectInputDevice_Unacquire(p)               (p)->Unacquire()
#define IDirectInputDevice_GetDeviceState(p,a,b)      (p)->GetDeviceState(a,b)
#define IDirectInputDevice_GetDeviceData(p,a,b,c,d)   (p)->GetDeviceData(a,b,c,d)
#define IDirectInputDevice_SetDataFormat(p,a)         (p)->SetDataFormat(a)
#define IDirectInputDevice_SetEventNotification(p,a)  (p)->SetEventNotification(a)
#define IDirectInputDevice_SetCooperativeLevel(p,a,b) (p)->SetCooperativeLevel(a,b)
#define IDirectInputDevice_GetObjectInfo(p,a,b,c)     (p)->GetObjectInfo(a,b,c)
#define IDirectInputDevice_GetDeviceInfo(p,a)         (p)->GetDeviceInfo(a)
#define IDirectInputDevice_RunControlPanel(p,a,b)     (p)->RunControlPanel(a,b)
#define IDirectInputDevice_Initialize(p,a,b,c)        (p)->Initialize(a,b,c)
#endif


#if (DIRECTINPUT_VERSION >= 0x0500)
/*****************************************************************************
 * IDirectInputDevice2A interface
 */
#undef INTERFACE
#define INTERFACE IDirectInputDevice2A
DECLARE_INTERFACE_(IDirectInputDevice2A,IDirectInputDeviceA)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputDeviceA methods ***/
    STDMETHOD(GetCapabilities)(THIS_ LPDIDEVCAPS lpDIDevCaps) PURE;
    STDMETHOD(EnumObjects)(THIS_ LPDIENUMDEVICEOBJECTSCALLBACKA lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetProperty)(THIS_ REFGUID rguidProp, LPDIPROPHEADER pdiph) PURE;
    STDMETHOD(SetProperty)(THIS_ REFGUID rguidProp, LPCDIPROPHEADER pdiph) PURE;
    STDMETHOD(Acquire)(THIS) PURE;
    STDMETHOD(Unacquire)(THIS) PURE;
    STDMETHOD(GetDeviceState)(THIS_ DWORD cbData, LPVOID lpvData) PURE;
    STDMETHOD(GetDeviceData)(THIS_ DWORD cbObjectData, LPDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD dwFlags) PURE;
    STDMETHOD(SetDataFormat)(THIS_ LPCDIDATAFORMAT lpdf) PURE;
    STDMETHOD(SetEventNotification)(THIS_ HANDLE hEvent) PURE;
    STDMETHOD(SetCooperativeLevel)(THIS_ HWND hwnd, DWORD dwFlags) PURE;
    STDMETHOD(GetObjectInfo)(THIS_ LPDIDEVICEOBJECTINSTANCEA pdidoi, DWORD dwObj, DWORD dwHow) PURE;
    STDMETHOD(GetDeviceInfo)(THIS_ LPDIDEVICEINSTANCEA pdidi) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion, REFGUID rguid) PURE;
    /*** IDirectInputDevice2A methods ***/
    STDMETHOD(CreateEffect)(THIS_ REFGUID rguid, LPCDIEFFECT lpeff, LPDIRECTINPUTEFFECT *ppdeff, LPUNKNOWN punkOuter) PURE;
    STDMETHOD(EnumEffects)(THIS_ LPDIENUMEFFECTSCALLBACKA lpCallback, LPVOID pvRef, DWORD dwEffType) PURE;
    STDMETHOD(GetEffectInfo)(THIS_ LPDIEFFECTINFOA pdei, REFGUID rguid) PURE;
    STDMETHOD(GetForceFeedbackState)(THIS_ LPDWORD pdwOut) PURE;
    STDMETHOD(SendForceFeedbackCommand)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(EnumCreatedEffectObjects)(THIS_ LPDIENUMCREATEDEFFECTOBJECTSCALLBACK lpCallback, LPVOID pvRef, DWORD fl) PURE;
    STDMETHOD(Escape)(THIS_ LPDIEFFESCAPE pesc) PURE;
    STDMETHOD(Poll)(THIS) PURE;
    STDMETHOD(SendDeviceData)(THIS_ DWORD cbObjectData, LPCDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD fl) PURE;
};

/*****************************************************************************
 * IDirectInputDevice2W interface
 */
#undef INTERFACE
#define INTERFACE IDirectInputDevice2W
DECLARE_INTERFACE_(IDirectInputDevice2W,IDirectInputDeviceW)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputDeviceW methods ***/
    STDMETHOD(GetCapabilities)(THIS_ LPDIDEVCAPS lpDIDevCaps) PURE;
    STDMETHOD(EnumObjects)(THIS_ LPDIENUMDEVICEOBJECTSCALLBACKW lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetProperty)(THIS_ REFGUID rguidProp, LPDIPROPHEADER pdiph) PURE;
    STDMETHOD(SetProperty)(THIS_ REFGUID rguidProp, LPCDIPROPHEADER pdiph) PURE;
    STDMETHOD(Acquire)(THIS) PURE;
    STDMETHOD(Unacquire)(THIS) PURE;
    STDMETHOD(GetDeviceState)(THIS_ DWORD cbData, LPVOID lpvData) PURE;
    STDMETHOD(GetDeviceData)(THIS_ DWORD cbObjectData, LPDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD dwFlags) PURE;
    STDMETHOD(SetDataFormat)(THIS_ LPCDIDATAFORMAT lpdf) PURE;
    STDMETHOD(SetEventNotification)(THIS_ HANDLE hEvent) PURE;
    STDMETHOD(SetCooperativeLevel)(THIS_ HWND hwnd, DWORD dwFlags) PURE;
    STDMETHOD(GetObjectInfo)(THIS_ LPDIDEVICEOBJECTINSTANCEW pdidoi, DWORD dwObj, DWORD dwHow) PURE;
    STDMETHOD(GetDeviceInfo)(THIS_ LPDIDEVICEINSTANCEW pdidi) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion, REFGUID rguid) PURE;
    /*** IDirectInputDevice2W methods ***/
    STDMETHOD(CreateEffect)(THIS_ REFGUID rguid, LPCDIEFFECT lpeff, LPDIRECTINPUTEFFECT *ppdeff, LPUNKNOWN punkOuter) PURE;
    STDMETHOD(EnumEffects)(THIS_ LPDIENUMEFFECTSCALLBACKW lpCallback, LPVOID pvRef, DWORD dwEffType) PURE;
    STDMETHOD(GetEffectInfo)(THIS_ LPDIEFFECTINFOW pdei, REFGUID rguid) PURE;
    STDMETHOD(GetForceFeedbackState)(THIS_ LPDWORD pdwOut) PURE;
    STDMETHOD(SendForceFeedbackCommand)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(EnumCreatedEffectObjects)(THIS_ LPDIENUMCREATEDEFFECTOBJECTSCALLBACK lpCallback, LPVOID pvRef, DWORD fl) PURE;
    STDMETHOD(Escape)(THIS_ LPDIEFFESCAPE pesc) PURE;
    STDMETHOD(Poll)(THIS) PURE;
    STDMETHOD(SendDeviceData)(THIS_ DWORD cbObjectData, LPCDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD fl) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectInputDevice2_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectInputDevice2_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectInputDevice2_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectInputDevice methods ***/
#define IDirectInputDevice2_GetCapabilities(p,a)       (p)->lpVtbl->GetCapabilities(p,a)
#define IDirectInputDevice2_EnumObjects(p,a,b,c)       (p)->lpVtbl->EnumObjects(p,a,b,c)
#define IDirectInputDevice2_GetProperty(p,a,b)         (p)->lpVtbl->GetProperty(p,a,b)
#define IDirectInputDevice2_SetProperty(p,a,b)         (p)->lpVtbl->SetProperty(p,a,b)
#define IDirectInputDevice2_Acquire(p)                 (p)->lpVtbl->Acquire(p)
#define IDirectInputDevice2_Unacquire(p)               (p)->lpVtbl->Unacquire(p)
#define IDirectInputDevice2_GetDeviceState(p,a,b)      (p)->lpVtbl->GetDeviceState(p,a,b)
#define IDirectInputDevice2_GetDeviceData(p,a,b,c,d)   (p)->lpVtbl->GetDeviceData(p,a,b,c,d)
#define IDirectInputDevice2_SetDataFormat(p,a)         (p)->lpVtbl->SetDataFormat(p,a)
#define IDirectInputDevice2_SetEventNotification(p,a)  (p)->lpVtbl->SetEventNotification(p,a)
#define IDirectInputDevice2_SetCooperativeLevel(p,a,b) (p)->lpVtbl->SetCooperativeLevel(p,a,b)
#define IDirectInputDevice2_GetObjectInfo(p,a,b,c)     (p)->lpVtbl->GetObjectInfo(p,a,b,c)
#define IDirectInputDevice2_GetDeviceInfo(p,a)         (p)->lpVtbl->GetDeviceInfo(p,a)
#define IDirectInputDevice2_RunControlPanel(p,a,b)     (p)->lpVtbl->RunControlPanel(p,a,b)
#define IDirectInputDevice2_Initialize(p,a,b,c)        (p)->lpVtbl->Initialize(p,a,b,c)
/*** IDirectInputDevice2 methods ***/
#define IDirectInputDevice2_CreateEffect(p,a,b,c,d)           (p)->lpVtbl->CreateEffect(p,a,b,c,d)
#define IDirectInputDevice2_EnumEffects(p,a,b,c)              (p)->lpVtbl->EnumEffects(p,a,b,c)
#define IDirectInputDevice2_GetEffectInfo(p,a,b)              (p)->lpVtbl->GetEffectInfo(p,a,b)
#define IDirectInputDevice2_GetForceFeedbackState(p,a)        (p)->lpVtbl->GetForceFeedbackState(p,a)
#define IDirectInputDevice2_SendForceFeedbackCommand(p,a)     (p)->lpVtbl->SendForceFeedbackCommand(p,a)
#define IDirectInputDevice2_EnumCreatedEffectObjects(p,a,b,c) (p)->lpVtbl->EnumCreatedEffectObjects(p,a,b,c)
#define IDirectInputDevice2_Escape(p,a)                       (p)->lpVtbl->Escape(p,a)
#define IDirectInputDevice2_Poll(p)                           (p)->lpVtbl->Poll(p)
#define IDirectInputDevice2_SendDeviceData(p,a,b,c,d)         (p)->lpVtbl->SendDeviceData(p,a,b,c,d)
#else
/*** IUnknown methods ***/
#define IDirectInputDevice2_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectInputDevice2_AddRef(p)             (p)->AddRef()
#define IDirectInputDevice2_Release(p)            (p)->Release()
/*** IDirectInputDevice methods ***/
#define IDirectInputDevice2_GetCapabilities(p,a)       (p)->GetCapabilities(a)
#define IDirectInputDevice2_EnumObjects(p,a,b,c)       (p)->EnumObjects(a,b,c)
#define IDirectInputDevice2_GetProperty(p,a,b)         (p)->GetProperty(a,b)
#define IDirectInputDevice2_SetProperty(p,a,b)         (p)->SetProperty(a,b)
#define IDirectInputDevice2_Acquire(p)                 (p)->Acquire()
#define IDirectInputDevice2_Unacquire(p)               (p)->Unacquire()
#define IDirectInputDevice2_GetDeviceState(p,a,b)      (p)->GetDeviceState(a,b)
#define IDirectInputDevice2_GetDeviceData(p,a,b,c,d)   (p)->GetDeviceData(a,b,c,d)
#define IDirectInputDevice2_SetDataFormat(p,a)         (p)->SetDataFormat(a)
#define IDirectInputDevice2_SetEventNotification(p,a)  (p)->SetEventNotification(a)
#define IDirectInputDevice2_SetCooperativeLevel(p,a,b) (p)->SetCooperativeLevel(a,b)
#define IDirectInputDevice2_GetObjectInfo(p,a,b,c)     (p)->GetObjectInfo(a,b,c)
#define IDirectInputDevice2_GetDeviceInfo(p,a)         (p)->GetDeviceInfo(a)
#define IDirectInputDevice2_RunControlPanel(p,a,b)     (p)->RunControlPanel(a,b)
#define IDirectInputDevice2_Initialize(p,a,b,c)        (p)->Initialize(a,b,c)
/*** IDirectInputDevice2 methods ***/
#define IDirectInputDevice2_CreateEffect(p,a,b,c,d)           (p)->CreateEffect(a,b,c,d)
#define IDirectInputDevice2_EnumEffects(p,a,b,c)              (p)->EnumEffects(a,b,c)
#define IDirectInputDevice2_GetEffectInfo(p,a,b)              (p)->GetEffectInfo(a,b)
#define IDirectInputDevice2_GetForceFeedbackState(p,a)        (p)->GetForceFeedbackState(a)
#define IDirectInputDevice2_SendForceFeedbackCommand(p,a)     (p)->SendForceFeedbackCommand(a)
#define IDirectInputDevice2_EnumCreatedEffectObjects(p,a,b,c) (p)->EnumCreatedEffectObjects(a,b,c)
#define IDirectInputDevice2_Escape(p,a)                       (p)->Escape(a)
#define IDirectInputDevice2_Poll(p)                           (p)->Poll()
#define IDirectInputDevice2_SendDeviceData(p,a,b,c,d)         (p)->SendDeviceData(a,b,c,d)
#endif
#endif /* DI5 */

#if DIRECTINPUT_VERSION >= 0x0700
/*****************************************************************************
 * IDirectInputDevice7A interface
 */
#undef INTERFACE
#define INTERFACE IDirectInputDevice7A
DECLARE_INTERFACE_(IDirectInputDevice7A,IDirectInputDevice2A)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputDeviceA methods ***/
    STDMETHOD(GetCapabilities)(THIS_ LPDIDEVCAPS lpDIDevCaps) PURE;
    STDMETHOD(EnumObjects)(THIS_ LPDIENUMDEVICEOBJECTSCALLBACKA lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetProperty)(THIS_ REFGUID rguidProp, LPDIPROPHEADER pdiph) PURE;
    STDMETHOD(SetProperty)(THIS_ REFGUID rguidProp, LPCDIPROPHEADER pdiph) PURE;
    STDMETHOD(Acquire)(THIS) PURE;
    STDMETHOD(Unacquire)(THIS) PURE;
    STDMETHOD(GetDeviceState)(THIS_ DWORD cbData, LPVOID lpvData) PURE;
    STDMETHOD(GetDeviceData)(THIS_ DWORD cbObjectData, LPDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD dwFlags) PURE;
    STDMETHOD(SetDataFormat)(THIS_ LPCDIDATAFORMAT lpdf) PURE;
    STDMETHOD(SetEventNotification)(THIS_ HANDLE hEvent) PURE;
    STDMETHOD(SetCooperativeLevel)(THIS_ HWND hwnd, DWORD dwFlags) PURE;
    STDMETHOD(GetObjectInfo)(THIS_ LPDIDEVICEOBJECTINSTANCEA pdidoi, DWORD dwObj, DWORD dwHow) PURE;
    STDMETHOD(GetDeviceInfo)(THIS_ LPDIDEVICEINSTANCEA pdidi) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion, REFGUID rguid) PURE;
    /*** IDirectInputDevice2A methods ***/
    STDMETHOD(CreateEffect)(THIS_ REFGUID rguid, LPCDIEFFECT lpeff, LPDIRECTINPUTEFFECT *ppdeff, LPUNKNOWN punkOuter) PURE;
    STDMETHOD(EnumEffects)(THIS_ LPDIENUMEFFECTSCALLBACKA lpCallback, LPVOID pvRef, DWORD dwEffType) PURE;
    STDMETHOD(GetEffectInfo)(THIS_ LPDIEFFECTINFOA pdei, REFGUID rguid) PURE;
    STDMETHOD(GetForceFeedbackState)(THIS_ LPDWORD pdwOut) PURE;
    STDMETHOD(SendForceFeedbackCommand)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(EnumCreatedEffectObjects)(THIS_ LPDIENUMCREATEDEFFECTOBJECTSCALLBACK lpCallback, LPVOID pvRef, DWORD fl) PURE;
    STDMETHOD(Escape)(THIS_ LPDIEFFESCAPE pesc) PURE;
    STDMETHOD(Poll)(THIS) PURE;
    STDMETHOD(SendDeviceData)(THIS_ DWORD cbObjectData, LPCDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD fl) PURE;
    /*** IDirectInputDevice7A methods ***/
    STDMETHOD(EnumEffectsInFile)(THIS_ LPCSTR lpszFileName,LPDIENUMEFFECTSINFILECALLBACK pec,LPVOID pvRef,DWORD dwFlags) PURE;
    STDMETHOD(WriteEffectToFile)(THIS_ LPCSTR lpszFileName,DWORD dwEntries,LPDIFILEEFFECT rgDiFileEft,DWORD dwFlags) PURE;
};

/*****************************************************************************
 * IDirectInputDevice7W interface
 */
#undef INTERFACE
#define INTERFACE IDirectInputDevice7W
DECLARE_INTERFACE_(IDirectInputDevice7W,IDirectInputDevice2W)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputDeviceW methods ***/
    STDMETHOD(GetCapabilities)(THIS_ LPDIDEVCAPS lpDIDevCaps) PURE;
    STDMETHOD(EnumObjects)(THIS_ LPDIENUMDEVICEOBJECTSCALLBACKW lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetProperty)(THIS_ REFGUID rguidProp, LPDIPROPHEADER pdiph) PURE;
    STDMETHOD(SetProperty)(THIS_ REFGUID rguidProp, LPCDIPROPHEADER pdiph) PURE;
    STDMETHOD(Acquire)(THIS) PURE;
    STDMETHOD(Unacquire)(THIS) PURE;
    STDMETHOD(GetDeviceState)(THIS_ DWORD cbData, LPVOID lpvData) PURE;
    STDMETHOD(GetDeviceData)(THIS_ DWORD cbObjectData, LPDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD dwFlags) PURE;
    STDMETHOD(SetDataFormat)(THIS_ LPCDIDATAFORMAT lpdf) PURE;
    STDMETHOD(SetEventNotification)(THIS_ HANDLE hEvent) PURE;
    STDMETHOD(SetCooperativeLevel)(THIS_ HWND hwnd, DWORD dwFlags) PURE;
    STDMETHOD(GetObjectInfo)(THIS_ LPDIDEVICEOBJECTINSTANCEW pdidoi, DWORD dwObj, DWORD dwHow) PURE;
    STDMETHOD(GetDeviceInfo)(THIS_ LPDIDEVICEINSTANCEW pdidi) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion, REFGUID rguid) PURE;
    /*** IDirectInputDevice2W methods ***/
    STDMETHOD(CreateEffect)(THIS_ REFGUID rguid, LPCDIEFFECT lpeff, LPDIRECTINPUTEFFECT *ppdeff, LPUNKNOWN punkOuter) PURE;
    STDMETHOD(EnumEffects)(THIS_ LPDIENUMEFFECTSCALLBACKW lpCallback, LPVOID pvRef, DWORD dwEffType) PURE;
    STDMETHOD(GetEffectInfo)(THIS_ LPDIEFFECTINFOW pdei, REFGUID rguid) PURE;
    STDMETHOD(GetForceFeedbackState)(THIS_ LPDWORD pdwOut) PURE;
    STDMETHOD(SendForceFeedbackCommand)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(EnumCreatedEffectObjects)(THIS_ LPDIENUMCREATEDEFFECTOBJECTSCALLBACK lpCallback, LPVOID pvRef, DWORD fl) PURE;
    STDMETHOD(Escape)(THIS_ LPDIEFFESCAPE pesc) PURE;
    STDMETHOD(Poll)(THIS) PURE;
    STDMETHOD(SendDeviceData)(THIS_ DWORD cbObjectData, LPCDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD fl) PURE;
    /*** IDirectInputDevice7W methods ***/
    STDMETHOD(EnumEffectsInFile)(THIS_ LPCWSTR lpszFileName,LPDIENUMEFFECTSINFILECALLBACK pec,LPVOID pvRef,DWORD dwFlags) PURE;
    STDMETHOD(WriteEffectToFile)(THIS_ LPCWSTR lpszFileName,DWORD dwEntries,LPDIFILEEFFECT rgDiFileEft,DWORD dwFlags) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectInputDevice7_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectInputDevice7_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectInputDevice7_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectInputDevice methods ***/
#define IDirectInputDevice7_GetCapabilities(p,a)       (p)->lpVtbl->GetCapabilities(p,a)
#define IDirectInputDevice7_EnumObjects(p,a,b,c)       (p)->lpVtbl->EnumObjects(p,a,b,c)
#define IDirectInputDevice7_GetProperty(p,a,b)         (p)->lpVtbl->GetProperty(p,a,b)
#define IDirectInputDevice7_SetProperty(p,a,b)         (p)->lpVtbl->SetProperty(p,a,b)
#define IDirectInputDevice7_Acquire(p)                 (p)->lpVtbl->Acquire(p)
#define IDirectInputDevice7_Unacquire(p)               (p)->lpVtbl->Unacquire(p)
#define IDirectInputDevice7_GetDeviceState(p,a,b)      (p)->lpVtbl->GetDeviceState(p,a,b)
#define IDirectInputDevice7_GetDeviceData(p,a,b,c,d)   (p)->lpVtbl->GetDeviceData(p,a,b,c,d)
#define IDirectInputDevice7_SetDataFormat(p,a)         (p)->lpVtbl->SetDataFormat(p,a)
#define IDirectInputDevice7_SetEventNotification(p,a)  (p)->lpVtbl->SetEventNotification(p,a)
#define IDirectInputDevice7_SetCooperativeLevel(p,a,b) (p)->lpVtbl->SetCooperativeLevel(p,a,b)
#define IDirectInputDevice7_GetObjectInfo(p,a,b,c)     (p)->lpVtbl->GetObjectInfo(p,a,b,c)
#define IDirectInputDevice7_GetDeviceInfo(p,a)         (p)->lpVtbl->GetDeviceInfo(p,a)
#define IDirectInputDevice7_RunControlPanel(p,a,b)     (p)->lpVtbl->RunControlPanel(p,a,b)
#define IDirectInputDevice7_Initialize(p,a,b,c)        (p)->lpVtbl->Initialize(p,a,b,c)
/*** IDirectInputDevice2 methods ***/
#define IDirectInputDevice7_CreateEffect(p,a,b,c,d)           (p)->lpVtbl->CreateEffect(p,a,b,c,d)
#define IDirectInputDevice7_EnumEffects(p,a,b,c)              (p)->lpVtbl->EnumEffects(p,a,b,c)
#define IDirectInputDevice7_GetEffectInfo(p,a,b)              (p)->lpVtbl->GetEffectInfo(p,a,b)
#define IDirectInputDevice7_GetForceFeedbackState(p,a)        (p)->lpVtbl->GetForceFeedbackState(p,a)
#define IDirectInputDevice7_SendForceFeedbackCommand(p,a)     (p)->lpVtbl->SendForceFeedbackCommand(p,a)
#define IDirectInputDevice7_EnumCreatedEffectObjects(p,a,b,c) (p)->lpVtbl->EnumCreatedEffectObjects(p,a,b,c)
#define IDirectInputDevice7_Escape(p,a)                       (p)->lpVtbl->Escape(p,a)
#define IDirectInputDevice7_Poll(p)                           (p)->lpVtbl->Poll(p)
#define IDirectInputDevice7_SendDeviceData(p,a,b,c,d)         (p)->lpVtbl->SendDeviceData(p,a,b,c,d)
/*** IDirectInputDevice7 methods ***/
#define IDirectInputDevice7_EnumEffectsInFile(p,a,b,c,d) (p)->lpVtbl->EnumEffectsInFile(p,a,b,c,d)
#define IDirectInputDevice7_WriteEffectToFile(p,a,b,c,d) (p)->lpVtbl->WriteEffectToFile(p,a,b,c,d)
#else
/*** IUnknown methods ***/
#define IDirectInputDevice7_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectInputDevice7_AddRef(p)             (p)->AddRef()
#define IDirectInputDevice7_Release(p)            (p)->Release()
/*** IDirectInputDevice methods ***/
#define IDirectInputDevice7_GetCapabilities(p,a)       (p)->GetCapabilities(a)
#define IDirectInputDevice7_EnumObjects(p,a,b,c)       (p)->EnumObjects(a,b,c)
#define IDirectInputDevice7_GetProperty(p,a,b)         (p)->GetProperty(a,b)
#define IDirectInputDevice7_SetProperty(p,a,b)         (p)->SetProperty(a,b)
#define IDirectInputDevice7_Acquire(p)                 (p)->Acquire()
#define IDirectInputDevice7_Unacquire(p)               (p)->Unacquire()
#define IDirectInputDevice7_GetDeviceState(p,a,b)      (p)->GetDeviceState(a,b)
#define IDirectInputDevice7_GetDeviceData(p,a,b,c,d)   (p)->GetDeviceData(a,b,c,d)
#define IDirectInputDevice7_SetDataFormat(p,a)         (p)->SetDataFormat(a)
#define IDirectInputDevice7_SetEventNotification(p,a)  (p)->SetEventNotification(a)
#define IDirectInputDevice7_SetCooperativeLevel(p,a,b) (p)->SetCooperativeLevel(a,b)
#define IDirectInputDevice7_GetObjectInfo(p,a,b,c)     (p)->GetObjectInfo(a,b,c)
#define IDirectInputDevice7_GetDeviceInfo(p,a)         (p)->GetDeviceInfo(a)
#define IDirectInputDevice7_RunControlPanel(p,a,b)     (p)->RunControlPanel(a,b)
#define IDirectInputDevice7_Initialize(p,a,b,c)        (p)->Initialize(a,b,c)
/*** IDirectInputDevice2 methods ***/
#define IDirectInputDevice7_CreateEffect(p,a,b,c,d)           (p)->CreateEffect(a,b,c,d)
#define IDirectInputDevice7_EnumEffects(p,a,b,c)              (p)->EnumEffects(a,b,c)
#define IDirectInputDevice7_GetEffectInfo(p,a,b)              (p)->GetEffectInfo(a,b)
#define IDirectInputDevice7_GetForceFeedbackState(p,a)        (p)->GetForceFeedbackState(a)
#define IDirectInputDevice7_SendForceFeedbackCommand(p,a)     (p)->SendForceFeedbackCommand(a)
#define IDirectInputDevice7_EnumCreatedEffectObjects(p,a,b,c) (p)->EnumCreatedEffectObjects(a,b,c)
#define IDirectInputDevice7_Escape(p,a)                       (p)->Escape(a)
#define IDirectInputDevice7_Poll(p)                           (p)->Poll()
#define IDirectInputDevice7_SendDeviceData(p,a,b,c,d)         (p)->SendDeviceData(a,b,c,d)
/*** IDirectInputDevice7 methods ***/
#define IDirectInputDevice7_EnumEffectsInFile(p,a,b,c,d) (p)->EnumEffectsInFile(a,b,c,d)
#define IDirectInputDevice7_WriteEffectToFile(p,a,b,c,d) (p)->WriteEffectToFile(a,b,c,d)
#endif

#endif /* DI7 */

#if DIRECTINPUT_VERSION >= 0x0800
/*****************************************************************************
 * IDirectInputDevice8A interface
 */
#undef INTERFACE
#define INTERFACE IDirectInputDevice8A
DECLARE_INTERFACE_(IDirectInputDevice8A,IDirectInputDevice7A)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputDeviceA methods ***/
    STDMETHOD(GetCapabilities)(THIS_ LPDIDEVCAPS lpDIDevCaps) PURE;
    STDMETHOD(EnumObjects)(THIS_ LPDIENUMDEVICEOBJECTSCALLBACKA lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetProperty)(THIS_ REFGUID rguidProp, LPDIPROPHEADER pdiph) PURE;
    STDMETHOD(SetProperty)(THIS_ REFGUID rguidProp, LPCDIPROPHEADER pdiph) PURE;
    STDMETHOD(Acquire)(THIS) PURE;
    STDMETHOD(Unacquire)(THIS) PURE;
    STDMETHOD(GetDeviceState)(THIS_ DWORD cbData, LPVOID lpvData) PURE;
    STDMETHOD(GetDeviceData)(THIS_ DWORD cbObjectData, LPDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD dwFlags) PURE;
    STDMETHOD(SetDataFormat)(THIS_ LPCDIDATAFORMAT lpdf) PURE;
    STDMETHOD(SetEventNotification)(THIS_ HANDLE hEvent) PURE;
    STDMETHOD(SetCooperativeLevel)(THIS_ HWND hwnd, DWORD dwFlags) PURE;
    STDMETHOD(GetObjectInfo)(THIS_ LPDIDEVICEOBJECTINSTANCEA pdidoi, DWORD dwObj, DWORD dwHow) PURE;
    STDMETHOD(GetDeviceInfo)(THIS_ LPDIDEVICEINSTANCEA pdidi) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion, REFGUID rguid) PURE;
    /*** IDirectInputDevice2A methods ***/
    STDMETHOD(CreateEffect)(THIS_ REFGUID rguid, LPCDIEFFECT lpeff, LPDIRECTINPUTEFFECT *ppdeff, LPUNKNOWN punkOuter) PURE;
    STDMETHOD(EnumEffects)(THIS_ LPDIENUMEFFECTSCALLBACKA lpCallback, LPVOID pvRef, DWORD dwEffType) PURE;
    STDMETHOD(GetEffectInfo)(THIS_ LPDIEFFECTINFOA pdei, REFGUID rguid) PURE;
    STDMETHOD(GetForceFeedbackState)(THIS_ LPDWORD pdwOut) PURE;
    STDMETHOD(SendForceFeedbackCommand)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(EnumCreatedEffectObjects)(THIS_ LPDIENUMCREATEDEFFECTOBJECTSCALLBACK lpCallback, LPVOID pvRef, DWORD fl) PURE;
    STDMETHOD(Escape)(THIS_ LPDIEFFESCAPE pesc) PURE;
    STDMETHOD(Poll)(THIS) PURE;
    STDMETHOD(SendDeviceData)(THIS_ DWORD cbObjectData, LPCDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD fl) PURE;
    /*** IDirectInputDevice7A methods ***/
    STDMETHOD(EnumEffectsInFile)(THIS_ LPCSTR lpszFileName,LPDIENUMEFFECTSINFILECALLBACK pec,LPVOID pvRef,DWORD dwFlags) PURE;
    STDMETHOD(WriteEffectToFile)(THIS_ LPCSTR lpszFileName,DWORD dwEntries,LPDIFILEEFFECT rgDiFileEft,DWORD dwFlags) PURE;
    /*** IDirectInputDevice8A methods ***/
    STDMETHOD(BuildActionMap)(THIS_ LPDIACTIONFORMATA lpdiaf, LPCSTR lpszUserName, DWORD dwFlags) PURE;
    STDMETHOD(SetActionMap)(THIS_ LPDIACTIONFORMATA lpdiaf, LPCSTR lpszUserName, DWORD dwFlags) PURE;
    STDMETHOD(GetImageInfo)(THIS_ LPDIDEVICEIMAGEINFOHEADERA lpdiDevImageInfoHeader) PURE;
};

/*****************************************************************************
 * IDirectInputDevice8W interface
 */
#undef INTERFACE
#define INTERFACE IDirectInputDevice8W
DECLARE_INTERFACE_(IDirectInputDevice8W,IDirectInputDevice7W)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputDeviceW methods ***/
    STDMETHOD(GetCapabilities)(THIS_ LPDIDEVCAPS lpDIDevCaps) PURE;
    STDMETHOD(EnumObjects)(THIS_ LPDIENUMDEVICEOBJECTSCALLBACKW lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetProperty)(THIS_ REFGUID rguidProp, LPDIPROPHEADER pdiph) PURE;
    STDMETHOD(SetProperty)(THIS_ REFGUID rguidProp, LPCDIPROPHEADER pdiph) PURE;
    STDMETHOD(Acquire)(THIS) PURE;
    STDMETHOD(Unacquire)(THIS) PURE;
    STDMETHOD(GetDeviceState)(THIS_ DWORD cbData, LPVOID lpvData) PURE;
    STDMETHOD(GetDeviceData)(THIS_ DWORD cbObjectData, LPDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD dwFlags) PURE;
    STDMETHOD(SetDataFormat)(THIS_ LPCDIDATAFORMAT lpdf) PURE;
    STDMETHOD(SetEventNotification)(THIS_ HANDLE hEvent) PURE;
    STDMETHOD(SetCooperativeLevel)(THIS_ HWND hwnd, DWORD dwFlags) PURE;
    STDMETHOD(GetObjectInfo)(THIS_ LPDIDEVICEOBJECTINSTANCEW pdidoi, DWORD dwObj, DWORD dwHow) PURE;
    STDMETHOD(GetDeviceInfo)(THIS_ LPDIDEVICEINSTANCEW pdidi) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion, REFGUID rguid) PURE;
    /*** IDirectInputDevice2W methods ***/
    STDMETHOD(CreateEffect)(THIS_ REFGUID rguid, LPCDIEFFECT lpeff, LPDIRECTINPUTEFFECT *ppdeff, LPUNKNOWN punkOuter) PURE;
    STDMETHOD(EnumEffects)(THIS_ LPDIENUMEFFECTSCALLBACKW lpCallback, LPVOID pvRef, DWORD dwEffType) PURE;
    STDMETHOD(GetEffectInfo)(THIS_ LPDIEFFECTINFOW pdei, REFGUID rguid) PURE;
    STDMETHOD(GetForceFeedbackState)(THIS_ LPDWORD pdwOut) PURE;
    STDMETHOD(SendForceFeedbackCommand)(THIS_ DWORD dwFlags) PURE;
    STDMETHOD(EnumCreatedEffectObjects)(THIS_ LPDIENUMCREATEDEFFECTOBJECTSCALLBACK lpCallback, LPVOID pvRef, DWORD fl) PURE;
    STDMETHOD(Escape)(THIS_ LPDIEFFESCAPE pesc) PURE;
    STDMETHOD(Poll)(THIS) PURE;
    STDMETHOD(SendDeviceData)(THIS_ DWORD cbObjectData, LPCDIDEVICEOBJECTDATA rgdod, LPDWORD pdwInOut, DWORD fl) PURE;
    /*** IDirectInputDevice7W methods ***/
    STDMETHOD(EnumEffectsInFile)(THIS_ LPCWSTR lpszFileName,LPDIENUMEFFECTSINFILECALLBACK pec,LPVOID pvRef,DWORD dwFlags) PURE;
    STDMETHOD(WriteEffectToFile)(THIS_ LPCWSTR lpszFileName,DWORD dwEntries,LPDIFILEEFFECT rgDiFileEft,DWORD dwFlags) PURE;
    /*** IDirectInputDevice8W methods ***/
    STDMETHOD(BuildActionMap)(THIS_ LPDIACTIONFORMATW lpdiaf, LPCWSTR lpszUserName, DWORD dwFlags) PURE;
    STDMETHOD(SetActionMap)(THIS_ LPDIACTIONFORMATW lpdiaf, LPCWSTR lpszUserName, DWORD dwFlags) PURE;
    STDMETHOD(GetImageInfo)(THIS_ LPDIDEVICEIMAGEINFOHEADERW lpdiDevImageInfoHeader) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectInputDevice8_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectInputDevice8_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectInputDevice8_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectInputDevice methods ***/
#define IDirectInputDevice8_GetCapabilities(p,a)       (p)->lpVtbl->GetCapabilities(p,a)
#define IDirectInputDevice8_EnumObjects(p,a,b,c)       (p)->lpVtbl->EnumObjects(p,a,b,c)
#define IDirectInputDevice8_GetProperty(p,a,b)         (p)->lpVtbl->GetProperty(p,a,b)
#define IDirectInputDevice8_SetProperty(p,a,b)         (p)->lpVtbl->SetProperty(p,a,b)
#define IDirectInputDevice8_Acquire(p)                 (p)->lpVtbl->Acquire(p)
#define IDirectInputDevice8_Unacquire(p)               (p)->lpVtbl->Unacquire(p)
#define IDirectInputDevice8_GetDeviceState(p,a,b)      (p)->lpVtbl->GetDeviceState(p,a,b)
#define IDirectInputDevice8_GetDeviceData(p,a,b,c,d)   (p)->lpVtbl->GetDeviceData(p,a,b,c,d)
#define IDirectInputDevice8_SetDataFormat(p,a)         (p)->lpVtbl->SetDataFormat(p,a)
#define IDirectInputDevice8_SetEventNotification(p,a)  (p)->lpVtbl->SetEventNotification(p,a)
#define IDirectInputDevice8_SetCooperativeLevel(p,a,b) (p)->lpVtbl->SetCooperativeLevel(p,a,b)
#define IDirectInputDevice8_GetObjectInfo(p,a,b,c)     (p)->lpVtbl->GetObjectInfo(p,a,b,c)
#define IDirectInputDevice8_GetDeviceInfo(p,a)         (p)->lpVtbl->GetDeviceInfo(p,a)
#define IDirectInputDevice8_RunControlPanel(p,a,b)     (p)->lpVtbl->RunControlPanel(p,a,b)
#define IDirectInputDevice8_Initialize(p,a,b,c)        (p)->lpVtbl->Initialize(p,a,b,c)
/*** IDirectInputDevice2 methods ***/
#define IDirectInputDevice8_CreateEffect(p,a,b,c,d)           (p)->lpVtbl->CreateEffect(p,a,b,c,d)
#define IDirectInputDevice8_EnumEffects(p,a,b,c)              (p)->lpVtbl->EnumEffects(p,a,b,c)
#define IDirectInputDevice8_GetEffectInfo(p,a,b)              (p)->lpVtbl->GetEffectInfo(p,a,b)
#define IDirectInputDevice8_GetForceFeedbackState(p,a)        (p)->lpVtbl->GetForceFeedbackState(p,a)
#define IDirectInputDevice8_SendForceFeedbackCommand(p,a)     (p)->lpVtbl->SendForceFeedbackCommand(p,a)
#define IDirectInputDevice8_EnumCreatedEffectObjects(p,a,b,c) (p)->lpVtbl->EnumCreatedEffectObjects(p,a,b,c)
#define IDirectInputDevice8_Escape(p,a)                       (p)->lpVtbl->Escape(p,a)
#define IDirectInputDevice8_Poll(p)                           (p)->lpVtbl->Poll(p)
#define IDirectInputDevice8_SendDeviceData(p,a,b,c,d)         (p)->lpVtbl->SendDeviceData(p,a,b,c,d)
/*** IDirectInputDevice7 methods ***/
#define IDirectInputDevice8_EnumEffectsInFile(p,a,b,c,d) (p)->lpVtbl->EnumEffectsInFile(p,a,b,c,d)
#define IDirectInputDevice8_WriteEffectToFile(p,a,b,c,d) (p)->lpVtbl->WriteEffectToFile(p,a,b,c,d)
/*** IDirectInputDevice8 methods ***/
#define IDirectInputDevice8_BuildActionMap(p,a,b,c) (p)->lpVtbl->BuildActionMap(p,a,b,c)
#define IDirectInputDevice8_SetActionMap(p,a,b,c)   (p)->lpVtbl->SetActionMap(p,a,b,c)
#define IDirectInputDevice8_GetImageInfo(p,a)       (p)->lpVtbl->GetImageInfo(p,a)
#else
/*** IUnknown methods ***/
#define IDirectInputDevice8_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectInputDevice8_AddRef(p)             (p)->AddRef()
#define IDirectInputDevice8_Release(p)            (p)->Release()
/*** IDirectInputDevice methods ***/
#define IDirectInputDevice8_GetCapabilities(p,a)       (p)->GetCapabilities(a)
#define IDirectInputDevice8_EnumObjects(p,a,b,c)       (p)->EnumObjects(a,b,c)
#define IDirectInputDevice8_GetProperty(p,a,b)         (p)->GetProperty(a,b)
#define IDirectInputDevice8_SetProperty(p,a,b)         (p)->SetProperty(a,b)
#define IDirectInputDevice8_Acquire(p)                 (p)->Acquire()
#define IDirectInputDevice8_Unacquire(p)               (p)->Unacquire()
#define IDirectInputDevice8_GetDeviceState(p,a,b)      (p)->GetDeviceState(a,b)
#define IDirectInputDevice8_GetDeviceData(p,a,b,c,d)   (p)->GetDeviceData(a,b,c,d)
#define IDirectInputDevice8_SetDataFormat(p,a)         (p)->SetDataFormat(a)
#define IDirectInputDevice8_SetEventNotification(p,a)  (p)->SetEventNotification(a)
#define IDirectInputDevice8_SetCooperativeLevel(p,a,b) (p)->SetCooperativeLevel(a,b)
#define IDirectInputDevice8_GetObjectInfo(p,a,b,c)     (p)->GetObjectInfo(a,b,c)
#define IDirectInputDevice8_GetDeviceInfo(p,a)         (p)->GetDeviceInfo(a)
#define IDirectInputDevice8_RunControlPanel(p,a,b)     (p)->RunControlPanel(a,b)
#define IDirectInputDevice8_Initialize(p,a,b,c)        (p)->Initialize(a,b,c)
/*** IDirectInputDevice2 methods ***/
#define IDirectInputDevice8_CreateEffect(p,a,b,c,d)           (p)->CreateEffect(a,b,c,d)
#define IDirectInputDevice8_EnumEffects(p,a,b,c)              (p)->EnumEffects(a,b,c)
#define IDirectInputDevice8_GetEffectInfo(p,a,b)              (p)->GetEffectInfo(a,b)
#define IDirectInputDevice8_GetForceFeedbackState(p,a)        (p)->GetForceFeedbackState(a)
#define IDirectInputDevice8_SendForceFeedbackCommand(p,a)     (p)->SendForceFeedbackCommand(a)
#define IDirectInputDevice8_EnumCreatedEffectObjects(p,a,b,c) (p)->EnumCreatedEffectObjects(a,b,c)
#define IDirectInputDevice8_Escape(p,a)                       (p)->Escape(a)
#define IDirectInputDevice8_Poll(p)                           (p)->Poll()
#define IDirectInputDevice8_SendDeviceData(p,a,b,c,d)         (p)->SendDeviceData(a,b,c,d)
/*** IDirectInputDevice7 methods ***/
#define IDirectInputDevice8_EnumEffectsInFile(p,a,b,c,d) (p)->EnumEffectsInFile(a,b,c,d)
#define IDirectInputDevice8_WriteEffectToFile(p,a,b,c,d) (p)->WriteEffectToFile(a,b,c,d)
/*** IDirectInputDevice8 methods ***/
#define IDirectInputDevice8_BuildActionMap(p,a,b,c) (p)->BuildActionMap(a,b,c)
#define IDirectInputDevice8_SetActionMap(p,a,b,c)   (p)->SetActionMap(a,b,c)
#define IDirectInputDevice8_GetImageInfo(p,a)       (p)->GetImageInfo(a)
#endif

#endif /* DI8 */

/* "Standard" Mouse report... */
typedef struct DIMOUSESTATE {
  LONG lX;
  LONG lY;
  LONG lZ;
  BYTE rgbButtons[4];
} DIMOUSESTATE;

#if DIRECTINPUT_VERSION >= 0x0700
/* "Standard" Mouse report for DInput 7... */
typedef struct DIMOUSESTATE2 {
  LONG lX;
  LONG lY;
  LONG lZ;
  BYTE rgbButtons[8];
} DIMOUSESTATE2;
#endif /* DI7 */

#define DIMOFS_X        FIELD_OFFSET(DIMOUSESTATE, lX)
#define DIMOFS_Y        FIELD_OFFSET(DIMOUSESTATE, lY)
#define DIMOFS_Z        FIELD_OFFSET(DIMOUSESTATE, lZ)
#define DIMOFS_BUTTON0 (FIELD_OFFSET(DIMOUSESTATE, rgbButtons) + 0)
#define DIMOFS_BUTTON1 (FIELD_OFFSET(DIMOUSESTATE, rgbButtons) + 1)
#define DIMOFS_BUTTON2 (FIELD_OFFSET(DIMOUSESTATE, rgbButtons) + 2)
#define DIMOFS_BUTTON3 (FIELD_OFFSET(DIMOUSESTATE, rgbButtons) + 3)
#if DIRECTINPUT_VERSION >= 0x0700
#define DIMOFS_BUTTON4 (FIELD_OFFSET(DIMOUSESTATE2, rgbButtons) + 4)
#define DIMOFS_BUTTON5 (FIELD_OFFSET(DIMOUSESTATE2, rgbButtons) + 5)
#define DIMOFS_BUTTON6 (FIELD_OFFSET(DIMOUSESTATE2, rgbButtons) + 6)
#define DIMOFS_BUTTON7 (FIELD_OFFSET(DIMOUSESTATE2, rgbButtons) + 7)
#endif /* DI7 */

#ifdef __cplusplus
extern "C" {
#endif
extern const DIDATAFORMAT c_dfDIMouse;
#if DIRECTINPUT_VERSION >= 0x0700
extern const DIDATAFORMAT c_dfDIMouse2; /* DX 7 */
#endif /* DI7 */
extern const DIDATAFORMAT c_dfDIKeyboard;
#if DIRECTINPUT_VERSION >= 0x0500
extern const DIDATAFORMAT c_dfDIJoystick;
extern LPCDIDATAFORMAT WINAPI GetdfDIJoystick(void);

extern const DIDATAFORMAT c_dfDIJoystick2;
#endif /* DI5 */
#ifdef __cplusplus
};
#endif

/*****************************************************************************
 * IDirectInputA interface
 */
#undef INTERFACE
#define INTERFACE IDirectInputA
DECLARE_INTERFACE_(IDirectInputA,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputA methods ***/
    STDMETHOD(CreateDevice)(THIS_ REFGUID rguid, LPDIRECTINPUTDEVICEA *lplpDirectInputDevice, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(EnumDevices)(THIS_ DWORD dwDevType, LPDIENUMDEVICESCALLBACKA lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetDeviceStatus)(THIS_ REFGUID rguidInstance) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion) PURE;
};

/*****************************************************************************
 * IDirectInputW interface
 */
#undef INTERFACE
#define INTERFACE IDirectInputW
DECLARE_INTERFACE_(IDirectInputW,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputW methods ***/
    STDMETHOD(CreateDevice)(THIS_ REFGUID rguid, LPDIRECTINPUTDEVICEW *lplpDirectInputDevice, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(EnumDevices)(THIS_ DWORD dwDevType, LPDIENUMDEVICESCALLBACKW lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetDeviceStatus)(THIS_ REFGUID rguidInstance) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectInput_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectInput_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectInput_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectInput methods ***/
#define IDirectInput_CreateDevice(p,a,b,c)  (p)->lpVtbl->CreateDevice(p,a,b,c)
#define IDirectInput_EnumDevices(p,a,b,c,d) (p)->lpVtbl->EnumDevices(p,a,b,c,d)
#define IDirectInput_GetDeviceStatus(p,a)   (p)->lpVtbl->GetDeviceStatus(p,a)
#define IDirectInput_RunControlPanel(p,a,b) (p)->lpVtbl->RunControlPanel(p,a,b)
#define IDirectInput_Initialize(p,a,b)      (p)->lpVtbl->Initialize(p,a,b)
#else
/*** IUnknown methods ***/
#define IDirectInput_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectInput_AddRef(p)             (p)->AddRef()
#define IDirectInput_Release(p)            (p)->Release()
/*** IDirectInput methods ***/
#define IDirectInput_CreateDevice(p,a,b,c)  (p)->CreateDevice(a,b,c)
#define IDirectInput_EnumDevices(p,a,b,c,d) (p)->EnumDevices(a,b,c,d)
#define IDirectInput_GetDeviceStatus(p,a)   (p)->GetDeviceStatus(a)
#define IDirectInput_RunControlPanel(p,a,b) (p)->RunControlPanel(a,b)
#define IDirectInput_Initialize(p,a,b)      (p)->Initialize(a,b)
#endif

/*****************************************************************************
 * IDirectInput2A interface
 */
#undef INTERFACE
#define INTERFACE IDirectInput2A
DECLARE_INTERFACE_(IDirectInput2A,IDirectInputA)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputA methods ***/
    STDMETHOD(CreateDevice)(THIS_ REFGUID rguid, LPDIRECTINPUTDEVICEA *lplpDirectInputDevice, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(EnumDevices)(THIS_ DWORD dwDevType, LPDIENUMDEVICESCALLBACKA lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetDeviceStatus)(THIS_ REFGUID rguidInstance) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion) PURE;
    /*** IDirectInput2A methods ***/
    STDMETHOD(FindDevice)(THIS_ REFGUID rguid, LPCSTR pszName, LPGUID pguidInstance) PURE;
};

/*****************************************************************************
 * IDirectInput2W interface
 */
#undef INTERFACE
#define INTERFACE IDirectInput2W
DECLARE_INTERFACE_(IDirectInput2W,IDirectInputW)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputW methods ***/
    STDMETHOD(CreateDevice)(THIS_ REFGUID rguid, LPDIRECTINPUTDEVICEW *lplpDirectInputDevice, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(EnumDevices)(THIS_ DWORD dwDevType, LPDIENUMDEVICESCALLBACKW lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetDeviceStatus)(THIS_ REFGUID rguidInstance) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion) PURE;
    /*** IDirectInput2W methods ***/
    STDMETHOD(FindDevice)(THIS_ REFGUID rguid, LPCWSTR pszName, LPGUID pguidInstance) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectInput2_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectInput2_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectInput2_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectInput methods ***/
#define IDirectInput2_CreateDevice(p,a,b,c)  (p)->lpVtbl->CreateDevice(p,a,b,c)
#define IDirectInput2_EnumDevices(p,a,b,c,d) (p)->lpVtbl->EnumDevices(p,a,b,c,d)
#define IDirectInput2_GetDeviceStatus(p,a)   (p)->lpVtbl->GetDeviceStatus(p,a)
#define IDirectInput2_RunControlPanel(p,a,b) (p)->lpVtbl->RunControlPanel(p,a,b)
#define IDirectInput2_Initialize(p,a,b)      (p)->lpVtbl->Initialize(p,a,b)
/*** IDirectInput2 methods ***/
#define IDirectInput2_FindDevice(p,a,b,c)    (p)->lpVtbl->FindDevice(p,a,b,c)
#else
/*** IUnknown methods ***/
#define IDirectInput2_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectInput2_AddRef(p)             (p)->AddRef()
#define IDirectInput2_Release(p)            (p)->Release()
/*** IDirectInput methods ***/
#define IDirectInput2_CreateDevice(p,a,b,c)  (p)->CreateDevice(a,b,c)
#define IDirectInput2_EnumDevices(p,a,b,c,d) (p)->EnumDevices(a,b,c,d)
#define IDirectInput2_GetDeviceStatus(p,a)   (p)->GetDeviceStatus(a)
#define IDirectInput2_RunControlPanel(p,a,b) (p)->RunControlPanel(a,b)
#define IDirectInput2_Initialize(p,a,b)      (p)->Initialize(a,b)
/*** IDirectInput2 methods ***/
#define IDirectInput2_FindDevice(p,a,b,c)    (p)->FindDevice(a,b,c)
#endif

/*****************************************************************************
 * IDirectInput7A interface
 */
#undef INTERFACE
#define INTERFACE IDirectInput7A
DECLARE_INTERFACE_(IDirectInput7A,IDirectInput2A)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputA methods ***/
    STDMETHOD(CreateDevice)(THIS_ REFGUID rguid, LPDIRECTINPUTDEVICEA *lplpDirectInputDevice, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(EnumDevices)(THIS_ DWORD dwDevType, LPDIENUMDEVICESCALLBACKA lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetDeviceStatus)(THIS_ REFGUID rguidInstance) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion) PURE;
    /*** IDirectInput2A methods ***/
    STDMETHOD(FindDevice)(THIS_ REFGUID rguid, LPCSTR pszName, LPGUID pguidInstance) PURE;
    /*** IDirectInput7A methods ***/
    STDMETHOD(CreateDeviceEx)(THIS_ REFGUID rguid, REFIID riid, LPVOID *pvOut, LPUNKNOWN lpUnknownOuter) PURE;
};

/*****************************************************************************
 * IDirectInput7W interface
 */
#undef INTERFACE
#define INTERFACE IDirectInput7W
DECLARE_INTERFACE_(IDirectInput7W,IDirectInput2W)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInputW methods ***/
    STDMETHOD(CreateDevice)(THIS_ REFGUID rguid, LPDIRECTINPUTDEVICEW *lplpDirectInputDevice, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(EnumDevices)(THIS_ DWORD dwDevType, LPDIENUMDEVICESCALLBACKW lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetDeviceStatus)(THIS_ REFGUID rguidInstance) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion) PURE;
    /*** IDirectInput2W methods ***/
    STDMETHOD(FindDevice)(THIS_ REFGUID rguid, LPCWSTR pszName, LPGUID pguidInstance) PURE;
    /*** IDirectInput7W methods ***/
    STDMETHOD(CreateDeviceEx)(THIS_ REFGUID rguid, REFIID riid, LPVOID *pvOut, LPUNKNOWN lpUnknownOuter) PURE;
};

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectInput7_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectInput7_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectInput7_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectInput methods ***/
#define IDirectInput7_CreateDevice(p,a,b,c)  (p)->lpVtbl->CreateDevice(p,a,b,c)
#define IDirectInput7_EnumDevices(p,a,b,c,d) (p)->lpVtbl->EnumDevices(p,a,b,c,d)
#define IDirectInput7_GetDeviceStatus(p,a)   (p)->lpVtbl->GetDeviceStatus(p,a)
#define IDirectInput7_RunControlPanel(p,a,b) (p)->lpVtbl->RunControlPanel(p,a,b)
#define IDirectInput7_Initialize(p,a,b)      (p)->lpVtbl->Initialize(p,a,b)
/*** IDirectInput2 methods ***/
#define IDirectInput7_FindDevice(p,a,b,c)    (p)->lpVtbl->FindDevice(p,a,b,c)
/*** IDirectInput7 methods ***/
#define IDirectInput7_CreateDeviceEx(p,a,b,c,d) (p)->lpVtbl->CreateDeviceEx(p,a,b,c,d)
#else
/*** IUnknown methods ***/
#define IDirectInput7_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectInput7_AddRef(p)             (p)->AddRef()
#define IDirectInput7_Release(p)            (p)->Release()
/*** IDirectInput methods ***/
#define IDirectInput7_CreateDevice(p,a,b,c)  (p)->CreateDevice(a,b,c)
#define IDirectInput7_EnumDevices(p,a,b,c,d) (p)->EnumDevices(a,b,c,d)
#define IDirectInput7_GetDeviceStatus(p,a)   (p)->GetDeviceStatus(a)
#define IDirectInput7_RunControlPanel(p,a,b) (p)->RunControlPanel(a,b)
#define IDirectInput7_Initialize(p,a,b)      (p)->Initialize(a,b)
/*** IDirectInput2 methods ***/
#define IDirectInput7_FindDevice(p,a,b,c)    (p)->FindDevice(a,b,c)
/*** IDirectInput7 methods ***/
#define IDirectInput7_CreateDeviceEx(p,a,b,c,d) (p)->CreateDeviceEx(a,b,c,d)
#endif


#if DIRECTINPUT_VERSION >= 0x0800
/*****************************************************************************
 * IDirectInput8A interface
 */
#undef INTERFACE
#define INTERFACE IDirectInput8A
DECLARE_INTERFACE_(IDirectInput8A,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInput8A methods ***/
    STDMETHOD(CreateDevice)(THIS_ REFGUID rguid, LPDIRECTINPUTDEVICE8A *lplpDirectInputDevice, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(EnumDevices)(THIS_ DWORD dwDevType, LPDIENUMDEVICESCALLBACKA lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetDeviceStatus)(THIS_ REFGUID rguidInstance) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion) PURE;
    STDMETHOD(FindDevice)(THIS_ REFGUID rguid, LPCSTR pszName, LPGUID pguidInstance) PURE;
    STDMETHOD(EnumDevicesBySemantics)(THIS_ LPCSTR ptszUserName, LPDIACTIONFORMATA lpdiActionFormat, LPDIENUMDEVICESBYSEMANTICSCBA lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(ConfigureDevices)(THIS_ LPDICONFIGUREDEVICESCALLBACK lpdiCallback, LPDICONFIGUREDEVICESPARAMSA lpdiCDParams, DWORD dwFlags, LPVOID pvRefData) PURE;
};

/*****************************************************************************
 * IDirectInput8W interface
 */
#undef INTERFACE
#define INTERFACE IDirectInput8W
DECLARE_INTERFACE_(IDirectInput8W,IUnknown)
{
    /*** IUnknown methods ***/
    STDMETHOD_(HRESULT,QueryInterface)(THIS_ REFIID riid, void** ppvObject) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    /*** IDirectInput8W methods ***/
    STDMETHOD(CreateDevice)(THIS_ REFGUID rguid, LPDIRECTINPUTDEVICE8W *lplpDirectInputDevice, LPUNKNOWN pUnkOuter) PURE;
    STDMETHOD(EnumDevices)(THIS_ DWORD dwDevType, LPDIENUMDEVICESCALLBACKW lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(GetDeviceStatus)(THIS_ REFGUID rguidInstance) PURE;
    STDMETHOD(RunControlPanel)(THIS_ HWND hwndOwner, DWORD dwFlags) PURE;
    STDMETHOD(Initialize)(THIS_ HINSTANCE hinst, DWORD dwVersion) PURE;
    STDMETHOD(FindDevice)(THIS_ REFGUID rguid, LPCWSTR pszName, LPGUID pguidInstance) PURE;
    STDMETHOD(EnumDevicesBySemantics)(THIS_ LPCWSTR ptszUserName, LPDIACTIONFORMATW lpdiActionFormat, LPDIENUMDEVICESBYSEMANTICSCBW lpCallback, LPVOID pvRef, DWORD dwFlags) PURE;
    STDMETHOD(ConfigureDevices)(THIS_ LPDICONFIGUREDEVICESCALLBACK lpdiCallback, LPDICONFIGUREDEVICESPARAMSW lpdiCDParams, DWORD dwFlags, LPVOID pvRefData) PURE;
};
#undef INTERFACE

#if !defined(__cplusplus) || defined(CINTERFACE)
/*** IUnknown methods ***/
#define IDirectInput8_QueryInterface(p,a,b) (p)->lpVtbl->QueryInterface(p,a,b)
#define IDirectInput8_AddRef(p)             (p)->lpVtbl->AddRef(p)
#define IDirectInput8_Release(p)            (p)->lpVtbl->Release(p)
/*** IDirectInput8 methods ***/
#define IDirectInput8_CreateDevice(p,a,b,c)       (p)->lpVtbl->CreateDevice(p,a,b,c)
#define IDirectInput8_EnumDevices(p,a,b,c,d)      (p)->lpVtbl->EnumDevices(p,a,b,c,d)
#define IDirectInput8_GetDeviceStatus(p,a)        (p)->lpVtbl->GetDeviceStatus(p,a)
#define IDirectInput8_RunControlPanel(p,a,b)      (p)->lpVtbl->RunControlPanel(p,a,b)
#define IDirectInput8_Initialize(p,a,b)           (p)->lpVtbl->Initialize(p,a,b)
#define IDirectInput8_FindDevice(p,a,b,c)         (p)->lpVtbl->FindDevice(p,a,b,c)
#define IDirectInput8_EnumDevicesBySemantics(p,a,b,c,d,e) (p)->lpVtbl->EnumDevicesBySemantics(p,a,b,c,d,e)
#define IDirectInput8_ConfigureDevices(p,a,b,c,d) (p)->lpVtbl->ConfigureDevices(p,a,b,c,d)
#else
/*** IUnknown methods ***/
#define IDirectInput8_QueryInterface(p,a,b) (p)->QueryInterface(a,b)
#define IDirectInput8_AddRef(p)             (p)->AddRef()
#define IDirectInput8_Release(p)            (p)->Release()
/*** IDirectInput8 methods ***/
#define IDirectInput8_CreateDevice(p,a,b,c)       (p)->CreateDevice(a,b,c)
#define IDirectInput8_EnumDevices(p,a,b,c,d)      (p)->EnumDevices(a,b,c,d)
#define IDirectInput8_GetDeviceStatus(p,a)        (p)->GetDeviceStatus(a)
#define IDirectInput8_RunControlPanel(p,a,b)      (p)->RunControlPanel(a,b)
#define IDirectInput8_Initialize(p,a,b)           (p)->Initialize(a,b)
#define IDirectInput8_FindDevice(p,a,b,c)         (p)->FindDevice(a,b,c)
#define IDirectInput8_EnumDevicesBySemantics(p,a,b,c,d,e) (p)->EnumDevicesBySemantics(a,b,c,d,e)
#define IDirectInput8_ConfigureDevices(p,a,b,c,d) (p)->ConfigureDevices(a,b,c,d)
#endif

#endif /* DI8 */

/* Export functions */

#ifdef __cplusplus
extern "C" {
#endif

#if DIRECTINPUT_VERSION >= 0x0800
HRESULT WINAPI DirectInput8Create(HINSTANCE,DWORD,REFIID,LPVOID *,LPUNKNOWN);
#else /* DI < 8 */
HRESULT WINAPI DirectInputCreateA(HINSTANCE,DWORD,LPDIRECTINPUTA *,LPUNKNOWN);
HRESULT WINAPI DirectInputCreateW(HINSTANCE,DWORD,LPDIRECTINPUTW *,LPUNKNOWN);
#define DirectInputCreate WINELIB_NAME_AW(DirectInputCreate)

HRESULT WINAPI DirectInputCreateEx(HINSTANCE,DWORD,REFIID,LPVOID *,LPUNKNOWN);
#endif /* DI8 */


/* New DirectInput8 style keyboard constants */

#define DIKEYBOARD_ESCAPE               (DIK_ESCAPE | 0x81000400)
#define DIKEYBOARD_1                    (DIK_1 | 0x81000400)
#define DIKEYBOARD_2                    (DIK_2 | 0x81000400)
#define DIKEYBOARD_3                    (DIK_3 | 0x81000400)
#define DIKEYBOARD_4                    (DIK_4 | 0x81000400)
#define DIKEYBOARD_5                    (DIK_5 | 0x81000400)
#define DIKEYBOARD_6                    (DIK_6 | 0x81000400)
#define DIKEYBOARD_7                    (DIK_7 | 0x81000400)
#define DIKEYBOARD_8                    (DIK_8 | 0x81000400)
#define DIKEYBOARD_9                    (DIK_9 | 0x81000400)
#define DIKEYBOARD_0                    (DIK_0 | 0x81000400)
#define DIKEYBOARD_MINUS                (DIK_MINUS | 0x81000400)
#define DIKEYBOARD_EQUALS               (DIK_EQUALS | 0x81000400)
#define DIKEYBOARD_BACK                 (DIK_BACK | 0x81000400)
#define DIKEYBOARD_TAB                  (DIK_TAB | 0x81000400)
#define DIKEYBOARD_Q                    (DIK_Q | 0x81000400)
#define DIKEYBOARD_W                    (DIK_W | 0x81000400)
#define DIKEYBOARD_E                    (DIK_E | 0x81000400)
#define DIKEYBOARD_R                    (DIK_R | 0x81000400)
#define DIKEYBOARD_T                    (DIK_T | 0x81000400)
#define DIKEYBOARD_Y                    (DIK_Y | 0x81000400)
#define DIKEYBOARD_U                    (DIK_U | 0x81000400)
#define DIKEYBOARD_I                    (DIK_I | 0x81000400)
#define DIKEYBOARD_O                    (DIK_O | 0x81000400)
#define DIKEYBOARD_P                    (DIK_P | 0x81000400)
#define DIKEYBOARD_LBRACKET             (DIK_LBRACKET | 0x81000400)
#define DIKEYBOARD_RBRACKET             (DIK_RBRACKET | 0x81000400)
#define DIKEYBOARD_RETURN               (DIK_RETURN | 0x81000400)
#define DIKEYBOARD_LCONTROL             (DIK_LCONTROL | 0x81000400)
#define DIKEYBOARD_A                    (DIK_A | 0x81000400)
#define DIKEYBOARD_S                    (DIK_S | 0x81000400)
#define DIKEYBOARD_D                    (DIK_D | 0x81000400)
#define DIKEYBOARD_F                    (DIK_F | 0x81000400)
#define DIKEYBOARD_G                    (DIK_G | 0x81000400)
#define DIKEYBOARD_H                    (DIK_H | 0x81000400)
#define DIKEYBOARD_J                    (DIK_J | 0x81000400)
#define DIKEYBOARD_K                    (DIK_K | 0x81000400)
#define DIKEYBOARD_L                    (DIK_L | 0x81000400)
#define DIKEYBOARD_SEMICOLON            (DIK_SEMICOLON | 0x81000400)
#define DIKEYBOARD_APOSTROPHE           (DIK_APOSTROPHE | 0x81000400)
#define DIKEYBOARD_GRAVE                (DIK_GRAVE | 0x81000400)
#define DIKEYBOARD_LSHIFT               (DIK_LSHIFT | 0x81000400)
#define DIKEYBOARD_BACKSLASH            (DIK_BACKSLASH | 0x81000400)
#define DIKEYBOARD_Z                    (DIK_Z | 0x81000400)
#define DIKEYBOARD_X                    (DIK_X | 0x81000400)
#define DIKEYBOARD_C                    (DIK_C | 0x81000400)
#define DIKEYBOARD_V                    (DIK_V | 0x81000400)
#define DIKEYBOARD_B                    (DIK_B | 0x81000400)
#define DIKEYBOARD_N                    (DIK_N | 0x81000400)
#define DIKEYBOARD_M                    (DIK_M | 0x81000400)
#define DIKEYBOARD_COMMA                (DIK_COMMA | 0x81000400)
#define DIKEYBOARD_PERIOD               (DIK_PERIOD | 0x81000400)
#define DIKEYBOARD_SLASH                (DIK_SLASH | 0x81000400)
#define DIKEYBOARD_RSHIFT               (DIK_RSHIFT | 0x81000400)
#define DIKEYBOARD_MULTIPLY             (DIK_MULTIPLY | 0x81000400)
#define DIKEYBOARD_LMENU                (DIK_LMENU | 0x81000400)
#define DIKEYBOARD_SPACE                (DIK_SPACE | 0x81000400)
#define DIKEYBOARD_CAPITAL              (DIK_CAPITAL | 0x81000400)
#define DIKEYBOARD_F1                   (DIK_F1 | 0x81000400)
#define DIKEYBOARD_F2                   (DIK_F2 | 0x81000400)
#define DIKEYBOARD_F3                   (DIK_F3 | 0x81000400)
#define DIKEYBOARD_F4                   (DIK_F4 | 0x81000400)
#define DIKEYBOARD_F5                   (DIK_F5 | 0x81000400)
#define DIKEYBOARD_F6                   (DIK_F6 | 0x81000400)
#define DIKEYBOARD_F7                   (DIK_F7 | 0x81000400)
#define DIKEYBOARD_F8                   (DIK_F8 | 0x81000400)
#define DIKEYBOARD_F9                   (DIK_F9 | 0x81000400)
#define DIKEYBOARD_F10                  (DIK_F10 | 0x81000400)
#define DIKEYBOARD_NUMLOCK              (DIK_NUMLOCK | 0x81000400)
#define DIKEYBOARD_SCROLL               (DIK_SCROLL | 0x81000400)
#define DIKEYBOARD_NUMPAD7              (DIK_NUMPAD7 | 0x81000400)
#define DIKEYBOARD_NUMPAD8              (DIK_NUMPAD8 | 0x81000400)
#define DIKEYBOARD_NUMPAD9              (DIK_NUMPAD9 | 0x81000400)
#define DIKEYBOARD_SUBTRACT             (DIK_SUBTRACT | 0x81000400)
#define DIKEYBOARD_NUMPAD4              (DIK_NUMPAD4 | 0x81000400)
#define DIKEYBOARD_NUMPAD5              (DIK_NUMPAD5 | 0x81000400)
#define DIKEYBOARD_NUMPAD6              (DIK_NUMPAD6 | 0x81000400)
#define DIKEYBOARD_ADD                  (DIK_ADD | 0x81000400)
#define DIKEYBOARD_NUMPAD1              (DIK_NUMPAD1 | 0x81000400)
#define DIKEYBOARD_NUMPAD2              (DIK_NUMPAD2 | 0x81000400)
#define DIKEYBOARD_NUMPAD3              (DIK_NUMPAD3 | 0x81000400)
#define DIKEYBOARD_NUMPAD0              (DIK_NUMPAD0 | 0x81000400)
#define DIKEYBOARD_DECIMAL              (DIK_DECIMAL | 0x81000400)
#define DIKEYBOARD_F11                  (DIK_F11 | 0x81000400)
#define DIKEYBOARD_F12                  (DIK_F12 | 0x81000400)
#define DIKEYBOARD_F13                  (DIK_F13 | 0x81000400)
#define DIKEYBOARD_F14                  (DIK_F14 | 0x81000400)
#define DIKEYBOARD_F15                  (DIK_F15 | 0x81000400)
#define DIKEYBOARD_KANA                 (DIK_KANA | 0x81000400)
#define DIKEYBOARD_CONVERT              (DIK_CONVERT | 0x81000400)
#define DIKEYBOARD_NOCONVERT            (DIK_NOCONVERT | 0x81000400)
#define DIKEYBOARD_YEN                  (DIK_YEN | 0x81000400)
#define DIKEYBOARD_NUMPADEQUALS         (DIK_NUMPADEQUALS | 0x81000400)
#define DIKEYBOARD_CIRCUMFLEX           (DIK_CIRCUMFLEX | 0x81000400)
#define DIKEYBOARD_AT                   (DIK_AT | 0x81000400)
#define DIKEYBOARD_COLON                (DIK_COLON | 0x81000400)
#define DIKEYBOARD_UNDERLINE            (DIK_UNDERLINE | 0x81000400)
#define DIKEYBOARD_KANJI                (DIK_KANJI | 0x81000400)
#define DIKEYBOARD_STOP                 (DIK_STOP | 0x81000400)
#define DIKEYBOARD_AX                   (DIK_AX | 0x81000400)
#define DIKEYBOARD_UNLABELED            (DIK_UNLABELED | 0x81000400)
#define DIKEYBOARD_NUMPADENTER          (DIK_NUMPADENTER | 0x81000400)
#define DIKEYBOARD_RCONTROL             (DIK_RCONTROL | 0x81000400)
#define DIKEYBOARD_NUMPADCOMMA          (DIK_NUMPADCOMMA | 0x81000400)
#define DIKEYBOARD_DIVIDE               (DIK_DIVIDE | 0x81000400)
#define DIKEYBOARD_SYSRQ                (DIK_SYSRQ | 0x81000400)
#define DIKEYBOARD_RMENU                (DIK_RMENU | 0x81000400)
#define DIKEYBOARD_PAUSE                (DIK_PAUSE | 0x81000400)
#define DIKEYBOARD_HOME                 (DIK_HOME | 0x81000400)
#define DIKEYBOARD_UP                   (DIK_UP | 0x81000400)
#define DIKEYBOARD_PRIOR                (DIK_PRIOR | 0x81000400)
#define DIKEYBOARD_LEFT                 (DIK_LEFT | 0x81000400)
#define DIKEYBOARD_RIGHT                (DIK_RIGHT | 0x81000400)
#define DIKEYBOARD_END                  (DIK_END | 0x81000400)
#define DIKEYBOARD_DOWN                 (DIK_DOWN | 0x81000400)
#define DIKEYBOARD_NEXT                 (DIK_NEXT | 0x81000400)
#define DIKEYBOARD_INSERT               (DIK_INSERT | 0x81000400)
#define DIKEYBOARD_DELETE               (DIK_DELETE | 0x81000400)
#define DIKEYBOARD_LWIN                 (DIK_LWIN | 0x81000400)
#define DIKEYBOARD_RWIN                 (DIK_RWIN | 0x81000400)
#define DIKEYBOARD_APPS                 (DIK_APPS | 0x81000400)
#define DIKEYBOARD_POWER                (DIK_POWER | 0x81000400)
#define DIKEYBOARD_SLEEP                (DIK_SLEEP | 0x81000400)
#define DIKEYBOARD_BACKSPACE            (DIK_BACKSPACE | 0x81000400)
#define DIKEYBOARD_NUMPADSTAR           (DIK_NUMPADSTAR | 0x81000400)
#define DIKEYBOARD_LALT                 (DIK_LALT | 0x81000400)
#define DIKEYBOARD_CAPSLOCK             (DIK_CAPSLOCK | 0x81000400)
#define DIKEYBOARD_NUMPADMINUS          (DIK_NUMPADMINUS | 0x81000400)
#define DIKEYBOARD_NUMPADPLUS           (DIK_NUMPADPLUS | 0x81000400)
#define DIKEYBOARD_NUMPADPERIOD         (DIK_NUMPADPERIOD | 0x81000400)
#define DIKEYBOARD_NUMPADSLASH          (DIK_NUMPADSLASH | 0x81000400)
#define DIKEYBOARD_RALT                 (DIK_RALT | 0x81000400)
#define DIKEYBOARD_UPARROW              (DIK_UPARROW | 0x81000400)
#define DIKEYBOARD_PGUP                 (DIK_PGUP | 0x81000400)
#define DIKEYBOARD_LEFTARROW            (DIK_LEFTARROW | 0x81000400)
#define DIKEYBOARD_RIGHTARROW           (DIK_RIGHTARROW | 0x81000400)
#define DIKEYBOARD_DOWNARROW            (DIK_DOWNARROW | 0x81000400)
#define DIKEYBOARD_PGDN                 (DIK_PGDN | 0x81000400)

/* New DirectInput8 mouse definitions */

#define DIMOUSE_XAXISAB            (0x82000200 | DIMOFS_X)
#define DIMOUSE_YAXISAB            (0x82000200 | DIMOFS_Y)
#define DIMOUSE_XAXIS              (0x82000300 | DIMOFS_X)
#define DIMOUSE_YAXIS              (0x82000300 | DIMOFS_Y)
#define DIMOUSE_WHEEL              (0x82000300 | DIMOFS_Z)
#define DIMOUSE_BUTTON0            (0x82000400 | DIMOFS_BUTTON0)
#define DIMOUSE_BUTTON1            (0x82000400 | DIMOFS_BUTTON1)
#define DIMOUSE_BUTTON2            (0x82000400 | DIMOFS_BUTTON2)
#define DIMOUSE_BUTTON3            (0x82000400 | DIMOFS_BUTTON3)
#define DIMOUSE_BUTTON4            (0x82000400 | DIMOFS_BUTTON4)
#define DIMOUSE_BUTTON5            (0x82000400 | DIMOFS_BUTTON5)
#define DIMOUSE_BUTTON6            (0x82000400 | DIMOFS_BUTTON6)
#define DIMOUSE_BUTTON7            (0x82000400 | DIMOFS_BUTTON7)


#define DIAXIS_ANY_X_1             0xFF00C201
#define DIAXIS_ANY_X_2             0xFF00C202
#define DIAXIS_ANY_Y_1             0xFF014201
#define DIAXIS_ANY_Y_2             0xFF014202
#define DIAXIS_ANY_Z_1             0xFF01C201
#define DIAXIS_ANY_Z_2             0xFF01C202
#define DIAXIS_ANY_R_1             0xFF024201
#define DIAXIS_ANY_R_2             0xFF024202
#define DIAXIS_ANY_U_1             0xFF02C201
#define DIAXIS_ANY_U_2             0xFF02C202
#define DIAXIS_ANY_V_1             0xFF034201
#define DIAXIS_ANY_V_2             0xFF034202
#define DIAXIS_ANY_A_1             0xFF03C201
#define DIAXIS_ANY_A_2             0xFF03C202
#define DIAXIS_ANY_B_1             0xFF044201
#define DIAXIS_ANY_B_2             0xFF044202
#define DIAXIS_ANY_C_1             0xFF04C201
#define DIAXIS_ANY_C_2             0xFF04C202
#define DIAXIS_ANY_S_1             0xFF054201
#define DIAXIS_ANY_S_2             0xFF054202
#define DIAXIS_ANY_1               0xFF004201
#define DIAXIS_ANY_2               0xFF004202
#define DIAXIS_ANY_3               0xFF004203
#define DIAXIS_ANY_4               0xFF004204
#define DIPOV_ANY_1                0xFF004601
#define DIPOV_ANY_2                0xFF004602
#define DIPOV_ANY_3                0xFF004603
#define DIPOV_ANY_4                0xFF004604
#define DIBUTTON_ANY(instance)     (0xFF004400 | (instance))


#define DIVIRTUAL_FLYING_HELICOPTER        0x06000000
#define DIBUTTON_FLYINGH_MENU              0x060004fd
#define DIBUTTON_FLYINGH_FIRE              0x06001401
#define DIBUTTON_FLYINGH_WEAPONS           0x06001402
#define DIBUTTON_FLYINGH_TARGET            0x06001403
#define DIBUTTON_FLYINGH_DEVICE            0x060044fe
#define DIBUTTON_FLYINGH_PAUSE             0x060044fc
#define DIHATSWITCH_FLYINGH_GLANCE         0x06004601
#define DIBUTTON_FLYINGH_FIRESECONDARY     0x06004c07
#define DIBUTTON_FLYINGH_COUNTER           0x06005404
#define DIBUTTON_FLYINGH_VIEW              0x06006405
#define DIBUTTON_FLYINGH_GEAR              0x06006406
#define DIAXIS_FLYINGH_BANK                0x06008a01
#define DIAXIS_FLYINGH_PITCH               0x06010a02
#define DIAXIS_FLYINGH_COLLECTIVE          0x06018a03
#define DIAXIS_FLYINGH_TORQUE              0x06025a04
#define DIAXIS_FLYINGH_THROTTLE            0x0603da05
#define DIBUTTON_FLYINGH_FASTER_LINK       0x0603dce0
#define DIBUTTON_FLYINGH_SLOWER_LINK       0x0603dce8
#define DIBUTTON_FLYINGH_GLANCE_LEFT_LINK  0x0607c4e4
#define DIBUTTON_FLYINGH_GLANCE_RIGHT_LINK 0x0607c4ec
#define DIBUTTON_FLYINGH_GLANCE_UP_LINK    0x0607c4e0
#define DIBUTTON_FLYINGH_GLANCE_DOWN_LINK  0x0607c4e8

#define DIVIRTUAL_SPACESIM                  0x07000000
#define DIBUTTON_SPACESIM_FIRE              0x07000401
#define DIBUTTON_SPACESIM_WEAPONS           0x07000402
#define DIBUTTON_SPACESIM_TARGET            0x07000403
#define DIBUTTON_SPACESIM_MENU              0x070004fd
#define DIBUTTON_SPACESIM_VIEW              0x07004404
#define DIBUTTON_SPACESIM_DISPLAY           0x07004405
#define DIBUTTON_SPACESIM_RAISE             0x07004406
#define DIBUTTON_SPACESIM_LOWER             0x07004407
#define DIBUTTON_SPACESIM_GEAR              0x07004408
#define DIBUTTON_SPACESIM_FIRESECONDARY     0x07004409
#define DIBUTTON_SPACESIM_PAUSE             0x070044fc
#define DIBUTTON_SPACESIM_DEVICE            0x070044fe
#define DIHATSWITCH_SPACESIM_GLANCE         0x07004601
#define DIBUTTON_SPACESIM_LEFT_LINK         0x0700c4e4
#define DIBUTTON_SPACESIM_RIGHT_LINK        0x0700c4ec
#define DIAXIS_SPACESIM_LATERAL             0x07008201
#define DIAXIS_SPACESIM_MOVE                0x07010202
#define DIBUTTON_SPACESIM_FORWARD_LINK      0x070144e0
#define DIBUTTON_SPACESIM_BACKWARD_LINK     0x070144e8
#define DIAXIS_SPACESIM_CLIMB               0x0701c204
#define DIAXIS_SPACESIM_ROTATE              0x07024205
#define DIBUTTON_SPACESIM_TURN_LEFT_LINK    0x070244e4
#define DIBUTTON_SPACESIM_TURN_RIGHT_LINK   0x070244ec
#define DIAXIS_SPACESIM_THROTTLE            0x07038203
#define DIBUTTON_SPACESIM_FASTER_LINK       0x0703c4e0
#define DIBUTTON_SPACESIM_SLOWER_LINK       0x0703c4e8
#define DIBUTTON_SPACESIM_GLANCE_UP_LINK    0x0707c4e0
#define DIBUTTON_SPACESIM_GLANCE_LEFT_LINK  0x0707c4e4
#define DIBUTTON_SPACESIM_GLANCE_DOWN_LINK  0x0707c4e8
#define DIBUTTON_SPACESIM_GLANCE_RIGHT_LINK 0x0707c4ec

#ifdef __cplusplus
};
#endif

#endif /* __DINPUT_INCLUDED__ */
