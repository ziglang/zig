/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef HID_DDK_TYPES_H
#define HID_DDK_TYPES_H
/**
 * @addtogroup HidDdk
 * @{
 *
 * @brief Provides HID DDK interfaces, including creating a device, sending an event, and destroying a device.
 *
 * @syscap SystemCapability.Driver.HID.Extension
 * @since 11
 * @version 1.0
 */

/**
 * @file hid_ddk_types.h
 *
 * @brief Provides definitions of enum variables and structs in the HID DDK.
 *
 * File to include: <hid/hid_ddk_types.h>
 * @since 11
 * @version 1.0
 */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif /* __cplusplus */

/**
 * @brief Defines event information.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Hid_EmitItem {
    /** Event type */
    uint16_t type;
    /** Event code */
    uint16_t code;
    /** Event value */
    uint32_t value;
} Hid_EmitItem;

/**
 * @brief Enumerates the input devices.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /** Pointer device */
    HID_PROP_POINTER = 0x00,
    /** Direct input device */
    HID_PROP_DIRECT = 0x01,
    /** Touch device with bottom keys */
    HID_PROP_BUTTON_PAD = 0x02,
    /** Full multi-touch device */
    HID_PROP_SEMI_MT = 0x03,
    /** Touch device with top soft keys */
    HID_PROP_TOP_BUTTON_PAD = 0x04,
    /** Pointing stick */
    HID_PROP_POINTING_STICK = 0x05,
    /** Accelerometer */
    HID_PROP_ACCELEROMETER = 0x06
} Hid_DeviceProp;

/**
 * @brief Defines the basic device information.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Hid_Device {
    /** Device name */
    const char *deviceName;
    /** Vendor ID */
    uint16_t vendorId;
    /** Product ID */
    uint16_t productId;
    /** Version */
    uint16_t version;
    /** Bus type */
    uint16_t bustype;
    /** Device properties */
    Hid_DeviceProp *properties;
    /** Number of device properties */
    uint16_t propLength;
} Hid_Device;

/**
 * @brief Enumerates the event types.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /** Synchronization event */
    HID_EV_SYN = 0x00,
    /** Key event */
    HID_EV_KEY = 0x01,
    /** Relative coordinate event */
    HID_EV_REL = 0x02,
    /** Absolute coordinate event */
    HID_EV_ABS = 0x03,
    /** Other special event */
    HID_EV_MSC = 0x04
} Hid_EventType;

/**
 * @brief Enumerates the synchronization event codes.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /** Indicates the end of an event. */
    HID_SYN_REPORT = 0,
    /** Indicates configuration synchronization. */
    HID_SYN_CONFIG = 1,
    /** Indicates the end of a multi-touch ABS data packet. */
    HID_SYN_MT_REPORT = 2,
    /** Indicates that the event is discarded. */
    HID_SYN_DROPPED = 3
} Hid_SynEvent;

/**
 * @brief Enumerates the key value codes.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /** Key A */
    HID_KEY_A = 30,
    /** Key B */
    HID_KEY_B = 48,
    /** Key C */
    HID_KEY_C = 46,
    /** Key D */
    HID_KEY_D = 32,
    /** Key E */
    HID_KEY_E = 18,
    /** Key F */
    HID_KEY_F = 33,
    /** Key G */
    HID_KEY_G = 34,
    /** Key H */
    HID_KEY_H = 35,
    /** Key I */
    HID_KEY_I = 23,
    /** Key J */
    HID_KEY_J = 36,
    /** Key K */
    HID_KEY_K = 37,
    /** Key L */
    HID_KEY_L = 38,
    /** Key M */
    HID_KEY_M = 50,
    /** Key N */
    HID_KEY_N = 49,
    /** Key O */
    HID_KEY_O = 24,
    /** Key P */
    HID_KEY_P = 25,
    /** Key Q */
    HID_KEY_Q = 16,
    /** Key R */
    HID_KEY_R = 19,
    /** Key S */
    HID_KEY_S = 31,
    /** Key T */
    HID_KEY_T = 20,
    /** Key U */
    HID_KEY_U = 22,
    /** Key V */
    HID_KEY_V = 47,
    /** Key W */
    HID_KEY_W = 17,
    /** Key X */
    HID_KEY_X = 45,
    /** Key Y */
    HID_KEY_Y = 21,
    /** Key Z */
    HID_KEY_Z = 44,
    /** Key Esc */
    HID_KEY_ESC = 1,
    /** Key 0 */
    HID_KEY_0 = 11,
    /** Key 1 */
    HID_KEY_1 = 2,
    /** Key 2 */
    HID_KEY_2 = 3,
    /** Key 3 */
    HID_KEY_3 = 4,
    /** Key 4 */
    HID_KEY_4 = 5,
    /** Key 5 */
    HID_KEY_5 = 6,
    /** Key 6 */
    HID_KEY_6 = 7,
    /** Key 7 */
    HID_KEY_7 = 8,
    /** Key 8 */
    HID_KEY_8 = 9,
    /** Key 9 */
    HID_KEY_9 = 10,
    /** Key grave (`) */
    HID_KEY_GRAVE = 41,
    /** Key minum (-) */
    HID_KEY_MINUS = 12,
    /** Key equals (=) */
    HID_KEY_EQUALS = 13,
    /** Key backspace */
    HID_KEY_BACKSPACE = 14,
    /** Key left bracket ([) */
    HID_KEY_LEFT_BRACKET = 26,
    /** Key right bracket (]) */
    HID_KEY_RIGHT_BRACKET = 27,
    /** Key Enter */
    HID_KEY_ENTER = 28,
    /** Key left Shift */
    HID_KEY_LEFT_SHIFT = 42,
    /** Key backslash (\) */
    HID_KEY_BACKSLASH = 43,
    /** Key semicolon (;) */
    HID_KEY_SEMICOLON = 39,
    /** Key apostrophe (') */
    HID_KEY_APOSTROPHE = 40,
    /** Key space */
    HID_KEY_SPACE = 57,
    /** Key slash (/) */
    HID_KEY_SLASH = 53,
    /** Key comma (,) */
    HID_KEY_COMMA = 51,
    /** Key period (.) */
    HID_KEY_PERIOD = 52,
    /** Key right Shift */
    HID_KEY_RIGHT_SHIFT = 54,
    /** Numeral 0 on the numeric keypad */
    HID_KEY_NUMPAD_0 = 82,
    /** Numeral 1 on the numeric keypad */
    HID_KEY_NUMPAD_1 = 79,
    /** Numeral 2 on the numeric keypad */
    HID_KEY_NUMPAD_2 = 80,
    /** Numeral 3 on the numeric keypad */
    HID_KEY_NUMPAD_3 = 81,
    /** Numeral 4 on the numeric keypad */
    HID_KEY_NUMPAD_4 = 75,
    /** Numeral 5 on the numeric keypad */
    HID_KEY_NUMPAD_5 = 76,
    /** Numeral 6 on the numeric keypad*/
    HID_KEY_NUMPAD_6 = 77,
    /** Numeral 7 on the numeric keypad */
    HID_KEY_NUMPAD_7 = 71,
    /** Numeral 8 on the numeric keypad */
    HID_KEY_NUMPAD_8 = 72,
    /** Numeral 9 on the numeric keypad */
    HID_KEY_NUMPAD_9 = 73,
    /** Arithmetic operator / (division) on the numeric keypad */
    HID_KEY_NUMPAD_DIVIDE = 70,
    /** Arithmetic operator * (multiplication) on the numeric keypad */
    HID_KEY_NUMPAD_MULTIPLY = 55,
    /** Arithmetic operator - (subtraction) on the numeric keypad */
    HID_KEY_NUMPAD_SUBTRACT = 74,
    /** Arithmetic operator + (addition) on the numeric keypad */
    HID_KEY_NUMPAD_ADD = 78,
    /** Decimal point (.) on the numeric keypad */
    HID_KEY_NUMPAD_DOT = 83,
    /** Key Print Screen */
    HID_KEY_SYSRQ = 99,
    /** Key Delete */
    HID_KEY_DELETE = 111,
    /** Key Mute */
    HID_KEY_MUTE = 113,
    /** Key for volume down */
    HID_KEY_VOLUME_DOWN = 114,
    /** Key for volume up */
    HID_KEY_VOLUME_UP = 115,
    /** Key for decreasing brightness */
    HID_KEY_BRIGHTNESS_DOWN = 224,
    /** Key for increasing brightness */
    HID_KEY_BRIGHTNESS_UP = 225,
    /** Button 0 */
    HID_BTN_0 = 0x100,
    /** Button 1 */
    HID_BTN_1 = 0x101,
    /** Button 2 */
    HID_BTN_2 = 0x102,
    /** Button 3 */
    HID_BTN_3 = 0x103,
    /** Button 4 */
    HID_BTN_4 = 0x104,
    /** Button 5 */
    HID_BTN_5 = 0x105,
    /** Button 6 */
    HID_BTN_6 = 0x106,
    /** Button 7 */
    HID_BTN_7 = 0x107,
    /** Button 8 */
    HID_BTN_8 = 0x108,
    /** Button 9 */
    HID_BTN_9 = 0x109,
    /** Left mouse button */
    HID_BTN_LEFT = 0x110,
    /** Right mouse button */
    HID_BTN_RIGHT = 0x111,
    /** Middle mouse button */
    HID_BTN_MIDDLE = 0x112,
    /** Side mouse button */
    HID_BTN_SIDE = 0x113,
    /** Extra mouse button */
    HID_BTN_EXTRA = 0x114,
    /** Mouse forward button */
    HID_BTN_FORWARD = 0x115,
    /** Mouse backward button */
    HID_BTN_BACKWARD = 0x116,
    /** Mouse task button */
    HID_BTN_TASK = 0x117,
    /** Pen */
    HID_BTN_TOOL_PEN = 0x140,
    /** Rubber */
    HID_BTN_TOOL_RUBBER = 0x141,
    /** Brush */
    HID_BTN_TOOL_BRUSH = 0x142,
    /** Pencil */
    HID_BTN_TOOL_PENCIL = 0x143,
    /** Air brush */
    HID_BTN_TOOL_AIRBRUSH = 0x144,
    /** Finger */
    HID_BTN_TOOL_FINGER = 0x145,
    /** Mouse */
    HID_BTN_TOOL_MOUSE = 0x146,
    /** Lens */
    HID_BTN_TOOL_LENS = 0x147,
    /** Five-finger touch */
    HID_BTN_TOOL_QUINT_TAP = 0x148,
    /** Stylus 3 */
    HID_BTN_STYLUS3 = 0x149,
    /** Touch */
    HID_BTN_TOUCH = 0x14a,
    /** Stylus */
    HID_BTN_STYLUS = 0x14b,
    /** Stylus 2 */
    HID_BTN_STYLUS2 = 0x14c,
    /** Two-finger touch */
    HID_BTN_TOOL_DOUBLE_TAP = 0x14d,
    /** Three-finger touch */
    HID_BTN_TOOL_TRIPLE_TAP = 0x14e,
    /** Four-finger touch */
    HID_BTN_TOOL_QUAD_TAP = 0x14f,
    /** Scroll wheel */
    HID_BTN_WHEEL = 0x150
} Hid_KeyCode;

/**
 * @brief Enumerates the absolute coordinate codes.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /** X axis */
    HID_ABS_X = 0x00,
    /** Y axis */
    HID_ABS_Y = 0x01,
    /** Z axis */
    HID_ABS_Z = 0x02,
    /** X axis of the right analog stick */
    HID_ABS_RX = 0x03,
    /** Y axis of the right analog stick */
    HID_ABS_RY = 0x04,
    /** Z axis of the right analog stick */
    HID_ABS_RZ = 0x05,
    /** Throttle */
    HID_ABS_THROTTLE = 0x06,
    /** Rudder */
    HID_ABS_RUDDER = 0x07,
    /** Scroll wheel */
    HID_ABS_WHEEL = 0x08,
    /** Gas */
    HID_ABS_GAS = 0x09,
    /** Brake */
    HID_ABS_BRAKE = 0x0a,
    /** HAT0X */
    HID_ABS_HAT0X = 0x10,
    /** HAT0Y */
    HID_ABS_HAT0Y = 0x11,
    /** HAT1X */
    HID_ABS_HAT1X = 0x12,
    /** HAT1Y */
    HID_ABS_HAT1Y = 0x13,
    /** HAT2X */
    HID_ABS_HAT2X = 0x14,
    /** HAT2Y */
    HID_ABS_HAT2Y = 0x15,
    /** HAT3X */
    HID_ABS_HAT3X = 0x16,
    /** HAT3Y */
    HID_ABS_HAT3Y = 0x17,
    /** Pressure */
    HID_ABS_PRESSURE = 0x18,
    /** Distance */
    HID_ABS_DISTANCE = 0x19,
    /** Inclination of X axis */
    HID_ABS_TILT_X = 0x1a,
    /** Inclination of Y axis */
    HID_ABS_TILT_Y = 0x1b,
    /** Width of the touch tool */
    HID_ABS_TOOL_WIDTH = 0x1c,
    /** Volume */
    HID_ABS_VOLUME = 0x20,
    /** Others */
    HID_ABS_MISC = 0x28
} Hid_AbsAxes;

/**
 * @brief Enumerates the relative coordinate codes.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /** X axis */
    HID_REL_X = 0x00,
    /** Y axis */
    HID_REL_Y = 0x01,
    /** Z axis */
    HID_REL_Z = 0x02,
    /** X axis of the right analog stick */
    HID_REL_RX = 0x03,
    /** Y axis of the right analog stick */
    HID_REL_RY = 0x04,
    /** Z axis of the right analog stick */
    HID_REL_RZ = 0x05,
    /** Horizontal scroll wheel */
    HID_REL_HWHEEL = 0x06,
    /** Scale */
    HID_REL_DIAL = 0x07,
    /** Scroll wheel */
    HID_REL_WHEEL = 0x08,
    /** Others */
    HID_REL_MISC = 0x09,
    /* Reserved */
    HID_REL_RESERVED = 0x0a,
    /** High-resolution scroll wheel */
    HID_REL_WHEEL_HI_RES = 0x0b,
    /** High-resolution horizontal scroll wheel */
    HID_REL_HWHEEL_HI_RES = 0x0c
} Hid_RelAxes;

/**
 * @brief Enumerates the codes of other input events.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /** Serial number */
    HID_MSC_SERIAL = 0x00,
    /** Pulse */
    HID_MSC_PULSE_LED = 0x01,
    /** Gesture */
    HID_MSC_GESTURE = 0x02,
    /** Start event */
    HID_MSC_RAW = 0x03,
    /** Scan */
    HID_MSC_SCAN = 0x04,
    /** Timestamp */
    HID_MSC_TIMESTAMP = 0x05
} Hid_MscEvent;

/**
 * @brief Defines an array of the event type codes.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Hid_EventTypeArray {
    /** Event type code */
    Hid_EventType *hidEventType;
    /** Length of the array */
    uint16_t length;
} Hid_EventTypeArray;

/**
 * @brief Defines an array of key value properties.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Hid_KeyCodeArray {
    /** Key value code */
    Hid_KeyCode *hidKeyCode;
    /** Length of the array */
    uint16_t length;
} Hid_KeyCodeArray;

/**
 * @brief Defines an array of absolute coordinate properties.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Hid_AbsAxesArray {
    /** Absolute coordinate property code */
    Hid_AbsAxes *hidAbsAxes;
    /** Length of the array */
    uint16_t length;
} Hid_AbsAxesArray;

/**
 * @brief Defines an array of relative coordinate properties.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Hid_RelAxesArray {
    /** Relative coordinate property code */
    Hid_RelAxes *hidRelAxes;
    /** Length of the array */
    uint16_t length;
} Hid_RelAxesArray;

/**
 * @brief Defines an array of other special event properties.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Hid_MscEventArray {
    /** Code of the event property */
    Hid_MscEvent *hidMscEvent;
    /** Length of the array */
    uint16_t length;
} Hid_MscEventArray;

/**
 * @brief Defines the event properties of a device to be observed.
 *
 * @since 11
 * @version 1.0
 */
typedef struct Hid_EventProperties {
    /** Array of event type codes */
    struct Hid_EventTypeArray hidEventTypes;
    /** Array of key value codes */
    struct Hid_KeyCodeArray hidKeys;
    /** Array of absolute coordinate property codes */
    struct Hid_AbsAxesArray hidAbs;
    /** Array of relative coordinate property codes */
    struct Hid_RelAxesArray hidRelBits;
    /** Array of other event property codes */
    struct Hid_MscEventArray hidMiscellaneous;

    /** Maximum values of the absolute coordinates */
    int32_t hidAbsMax[64];
    /** Minimum values of the absolute coordinates */
    int32_t hidAbsMin[64];
    /** Fuzzy values of the absolute coordinates */
    int32_t hidAbsFuzz[64];
    /** Fixed values of the absolute coordinates */
    int32_t hidAbsFlat[64];
} Hid_EventProperties;

/**
 * @brief Defines the error codes used in the HID DDK.
 *
 * @since 11
 * @version 1.0
 */
typedef enum {
    /** @error Operation successful */
    HID_DDK_SUCCESS = 0,
    /** @error Operation failed */
    HID_DDK_FAILURE = -1,
    /** @error Invalid parameter */
    HID_DDK_INVALID_PARAMETER = -2,
    /** @error Invalid operation */
    HID_DDK_INVALID_OPERATION = -3,
    /** @error Null pointer exception */
    HID_DDK_NULL_PTR = -4,
    /** @error Timeout */
    HID_DDK_TIMEOUT = -5,
    /** @error Permission denied */
    HID_DDK_NO_PERM = -6
} Hid_DdkErrCode;
#ifdef __cplusplus
}
/** @} */
#endif /* __cplusplus */
#endif // HID_DDK_TYPES_H