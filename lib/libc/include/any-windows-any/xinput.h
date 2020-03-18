/*
 * The Wine project - Xinput Joystick Library
 * Copyright 2008 Andrew Fenn
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

#ifndef __WINE_XINPUT_H
#define __WINE_XINPUT_H

#include <windef.h>

/*
 * Bitmasks for the joysticks buttons, determines what has
 * been pressed on the joystick, these need to be mapped
 * to whatever device you're using instead of an xbox 360
 * joystick
 */

#define XINPUT_GAMEPAD_DPAD_UP          0x0001
#define XINPUT_GAMEPAD_DPAD_DOWN        0x0002
#define XINPUT_GAMEPAD_DPAD_LEFT        0x0004
#define XINPUT_GAMEPAD_DPAD_RIGHT       0x0008
#define XINPUT_GAMEPAD_START            0x0010
#define XINPUT_GAMEPAD_BACK             0x0020
#define XINPUT_GAMEPAD_LEFT_THUMB       0x0040
#define XINPUT_GAMEPAD_RIGHT_THUMB      0x0080
#define XINPUT_GAMEPAD_LEFT_SHOULDER    0x0100
#define XINPUT_GAMEPAD_RIGHT_SHOULDER   0x0200
#define XINPUT_GAMEPAD_A                0x1000
#define XINPUT_GAMEPAD_B                0x2000
#define XINPUT_GAMEPAD_X                0x4000
#define XINPUT_GAMEPAD_Y                0x8000

/*
 * Defines the flags used to determine if the user is pushing
 * down on a button, not holding a button, etc
 */

#define XINPUT_KEYSTROKE_KEYDOWN        0x0001
#define XINPUT_KEYSTROKE_KEYUP          0x0002
#define XINPUT_KEYSTROKE_REPEAT         0x0004

/*
 * Defines the codes which are returned by XInputGetKeystroke
 */

#define VK_PAD_A                        0x5800
#define VK_PAD_B                        0x5801
#define VK_PAD_X                        0x5802
#define VK_PAD_Y                        0x5803
#define VK_PAD_RSHOULDER                0x5804
#define VK_PAD_LSHOULDER                0x5805
#define VK_PAD_LTRIGGER                 0x5806
#define VK_PAD_RTRIGGER                 0x5807
#define VK_PAD_DPAD_UP                  0x5810
#define VK_PAD_DPAD_DOWN                0x5811
#define VK_PAD_DPAD_LEFT                0x5812
#define VK_PAD_DPAD_RIGHT               0x5813
#define VK_PAD_START                    0x5814
#define VK_PAD_BACK                     0x5815
#define VK_PAD_LTHUMB_PRESS             0x5816
#define VK_PAD_RTHUMB_PRESS             0x5817
#define VK_PAD_LTHUMB_UP                0x5820
#define VK_PAD_LTHUMB_DOWN              0x5821
#define VK_PAD_LTHUMB_RIGHT             0x5822
#define VK_PAD_LTHUMB_LEFT              0x5823
#define VK_PAD_LTHUMB_UPLEFT            0x5824
#define VK_PAD_LTHUMB_UPRIGHT           0x5825
#define VK_PAD_LTHUMB_DOWNRIGHT         0x5826
#define VK_PAD_LTHUMB_DOWNLEFT          0x5827
#define VK_PAD_RTHUMB_UP                0x5830
#define VK_PAD_RTHUMB_DOWN              0x5831
#define VK_PAD_RTHUMB_RIGHT             0x5832
#define VK_PAD_RTHUMB_LEFT              0x5833
#define VK_PAD_RTHUMB_UPLEFT            0x5834
#define VK_PAD_RTHUMB_UPRIGHT           0x5835
#define VK_PAD_RTHUMB_DOWNRIGHT         0x5836
#define VK_PAD_RTHUMB_DOWNLEFT          0x5837

/*
 * Deadzones are for analogue joystick controls on the joypad
 * which determine when input should be assumed to be in the
 * middle of the pad. This is a threshold to stop a joypad
 * controlling the game when the player isn't touching the
 * controls.
 */

#define XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE  7849
#define XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE 8689
#define XINPUT_GAMEPAD_TRIGGER_THRESHOLD    30


/*
 * Defines what type of abilities the type of joystick has
 * DEVTYPE_GAMEPAD is available for all joysticks, however
 * there may be more specific identifiers for other joysticks
 * which are being used.
 */

#define XINPUT_DEVTYPE_GAMEPAD          0x01
#define XINPUT_DEVSUBTYPE_GAMEPAD       0x01
#define XINPUT_DEVSUBTYPE_WHEEL         0x02
#define XINPUT_DEVSUBTYPE_ARCADE_STICK  0x03
#define XINPUT_DEVSUBTYPE_FLIGHT_SICK   0x04
#define XINPUT_DEVSUBTYPE_DANCE_PAD     0x05
#define XINPUT_DEVSUBTYPE_GUITAR        0x06
#define XINPUT_DEVSUBTYPE_DRUM_KIT      0x08

/*
 * These are used with the XInputGetCapabilities function to
 * determine the abilities to the joystick which has been
 * plugged in.
 */

#define XINPUT_CAPS_VOICE_SUPPORTED     0x0004
#define XINPUT_FLAG_GAMEPAD             0x00000001

/*
 * Defines the status of the battery if one is used in the
 * attached joystick. The first two define if the joystick
 * supports a battery. Disconnected means that the joystick
 * isn't connected. Wired shows that the joystick is a wired
 * joystick.
 */

#define BATTERY_DEVTYPE_GAMEPAD         0x00
#define BATTERY_DEVTYPE_HEADSET         0x01
#define BATTERY_TYPE_DISCONNECTED       0x00
#define BATTERY_TYPE_WIRED              0x01
#define BATTERY_TYPE_ALKALINE           0x02
#define BATTERY_TYPE_NIMH               0x03
#define BATTERY_TYPE_UNKNOWN            0xFF
#define BATTERY_LEVEL_EMPTY             0x00
#define BATTERY_LEVEL_LOW               0x01
#define BATTERY_LEVEL_MEDIUM            0x02
#define BATTERY_LEVEL_FULL              0x03

/*
 * How many joysticks can be used with this library. Games that
 * use the xinput library will not go over this number.
 */

#define XUSER_MAX_COUNT                 4
#define XUSER_INDEX_ANY                 0x000000FF

#define XINPUT_CAPS_FFB_SUPPORTED       0x0001
#define XINPUT_CAPS_WIRELESS            0x0002
#define XINPUT_CAPS_PMD_SUPPORTED       0x0008
#define XINPUT_CAPS_NO_NAVIGATION       0x0010

/*
 * Defines the structure of an xbox 360 joystick.
 */

typedef struct _XINPUT_GAMEPAD {
    WORD wButtons;
    BYTE bLeftTrigger;
    BYTE bRightTrigger;
    SHORT sThumbLX;
    SHORT sThumbLY;
    SHORT sThumbRX;
    SHORT sThumbRY;
} XINPUT_GAMEPAD, *PXINPUT_GAMEPAD;

typedef struct _XINPUT_STATE {
    DWORD dwPacketNumber;
    XINPUT_GAMEPAD Gamepad;
} XINPUT_STATE, *PXINPUT_STATE;

/*
 * Defines the structure of how much vibration is set on both the
 * right and left motors in a joystick. If you're not using a 360
 * joystick you will have to map these to your device.
 */

typedef struct _XINPUT_VIBRATION {
    WORD wLeftMotorSpeed;
    WORD wRightMotorSpeed;
} XINPUT_VIBRATION, *PXINPUT_VIBRATION;

/*
 * Defines the structure for what kind of abilities the joystick has
 * such abilities are things such as if the joystick has the ability
 * to send and receive audio, if the joystick is in fact a driving
 * wheel or perhaps if the joystick is some kind of dance pad or
 * guitar.
 */

typedef struct _XINPUT_CAPABILITIES {
    BYTE Type;
    BYTE SubType;
    WORD Flags;
    XINPUT_GAMEPAD Gamepad;
    XINPUT_VIBRATION Vibration;
} XINPUT_CAPABILITIES, *PXINPUT_CAPABILITIES;

/*
 * Defines the structure for a joystick input event which is
 * retrieved using the function XInputGetKeystroke
 */
typedef struct _XINPUT_KEYSTROKE {
    WORD VirtualKey;
    WCHAR Unicode;
    WORD Flags;
    BYTE UserIndex;
    BYTE HidCode;
} XINPUT_KEYSTROKE, *PXINPUT_KEYSTROKE;

typedef struct _XINPUT_BATTERY_INFORMATION
{
    BYTE BatteryType;
    BYTE BatteryLevel;
} XINPUT_BATTERY_INFORMATION, *PXINPUT_BATTERY_INFORMATION;

#ifdef __cplusplus
extern "C" {
#endif

void WINAPI XInputEnable(WINBOOL);
DWORD WINAPI XInputSetState(DWORD, XINPUT_VIBRATION*);
DWORD WINAPI XInputGetState(DWORD, XINPUT_STATE*);
DWORD WINAPI XInputGetKeystroke(DWORD, DWORD, PXINPUT_KEYSTROKE);
DWORD WINAPI XInputGetCapabilities(DWORD, DWORD, XINPUT_CAPABILITIES*);
DWORD WINAPI XInputGetDSoundAudioDeviceGuids(DWORD, GUID*, GUID*);
DWORD WINAPI XInputGetBatteryInformation(DWORD, BYTE, XINPUT_BATTERY_INFORMATION*);

DWORD WINAPI XInputGetStateEx(DWORD, XINPUT_STATE*);

#ifdef __cplusplus
}
#endif

#endif /* __WINE_XINPUT_H */
