/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#ifndef OH_KEY_CODE_H
#define OH_KEY_CODE_H

/**
 * @addtogroup input
 * @{
 *
 * @brief Provides the C interface in the multi-modal input domain.
 *
 * @since 12
 */

/**
 * @file oh_key_code.h
 *
 * @brief Defines the key event structure and related enumeration values.
 *
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @library libohinput.so
 * @since 12
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerated values of OpenHarmony key code.
 *
 * @since 12
 */
typedef enum {
    /** Unknown key */
    KEYCODE_UNKNOWN = -1,
    /** Function (Fn) key */
    KEYCODE_FN = 0,
    /** Volume Up key */
    KEYCODE_VOLUME_UP = 16,
    /** Volume Down button */
    KEYCODE_VOLUME_DOWN = 17,
    /** Power key */
    KEYCODE_POWER = 18,
    /** Shutter key */
    KEYCODE_CAMERA = 19,
    /** Speaker Mute key */
    KEYCODE_VOLUME_MUTE = 22,
    /** Mute key */
    KEYCODE_MUTE = 23,
    /** Brightness Up key */
    KEYCODE_BRIGHTNESS_UP = 40,
    /** Brightness Down key */
    KEYCODE_BRIGHTNESS_DOWN = 41,
    /** Key 0 */
    KEYCODE_0 = 2000,
    /** Key 1 */
    KEYCODE_1 = 2001,
    /** Key 2 */
    KEYCODE_2 = 2002,
    /** Key 3 */
    KEYCODE_3 = 2003,
    /** Key 4 */
    KEYCODE_4 = 2004,
    /** Key 5 */
    KEYCODE_5 = 2005,
    /** Key 6 */
    KEYCODE_6 = 2006,
    /** Key 7 */
    KEYCODE_7 = 2007,
    /** Key 8 */
    KEYCODE_8 = 2008,
    /** Key 9 */
    KEYCODE_9 = 2009,
    /** Key * */
    KEYCODE_STAR = 2010,
    /** Key # */
    KEYCODE_POUND = 2011,
     /** Up key on D-pad */
    KEYCODE_DPAD_UP = 2012,
    /** Down key on D-pad */
    KEYCODE_DPAD_DOWN = 2013,
    /** Left key on D-pad */
    KEYCODE_DPAD_LEFT = 2014,
    /** Right key on D-pad */
    KEYCODE_DPAD_RIGHT = 2015,
    /** OK key on D-pad */
    KEYCODE_DPAD_CENTER = 2016,
    /** Key A */
    KEYCODE_A = 2017,
    /** Key B */
    KEYCODE_B = 2018,
    /** Key C */
    KEYCODE_C = 2019,
    /** Key D */
    KEYCODE_D = 2020,
    /** Key E */
    KEYCODE_E = 2021,
    /** Key F */
    KEYCODE_F = 2022,
    /** Key G */
    KEYCODE_G = 2023,
    /** Key H */
    KEYCODE_H = 2024,
    /** Key I */
    KEYCODE_I = 2025,
    /** Key J */
    KEYCODE_J = 2026,
    /** Key K */
    KEYCODE_K = 2027,
    /** Key L */
    KEYCODE_L = 2028,
    /** Key M */
    KEYCODE_M = 2029,
    /** Key N */
    KEYCODE_N = 2030,
    /** Key O */
    KEYCODE_O = 2031,
    /** Key P */
    KEYCODE_P = 2032,
    /** Key Q */
    KEYCODE_Q = 2033,
    /** Key R */
    KEYCODE_R = 2034,
    /** Key S */
    KEYCODE_S = 2035,
    /** Key T */
    KEYCODE_T = 2036,
    /** Key U */
    KEYCODE_U = 2037,
    /** Key V */
    KEYCODE_V = 2038,
    /** Key W */
    KEYCODE_W = 2039,
    /** Key X */
    KEYCODE_X = 2040,
    /** Key Y */
    KEYCODE_Y = 2041,
    /** Key Z */
    KEYCODE_Z = 2042,
    /** Key , */
    KEYCODE_COMMA = 2043,
    /** Key . */
    KEYCODE_PERIOD = 2044,
    /** Left Alt key */
    KEYCODE_ALT_LEFT = 2045,
    /** Right Alt key */
    KEYCODE_ALT_RIGHT = 2046,
    /** Left Shift key */
    KEYCODE_SHIFT_LEFT = 2047,
    /** Right Shift key */
    KEYCODE_SHIFT_RIGHT = 2048,
    /** Tab key */
    KEYCODE_TAB = 2049,
    /** Space key */
    KEYCODE_SPACE = 2050,
    /** Symbol key */
    KEYCODE_SYM = 2051,
    /** Explorer key, used to start the explorer application */
    KEYCODE_EXPLORER = 2052,
    /** Email key, used to start the email application */
    KEYCODE_ENVELOPE = 2053,
    /** Enter key */
    KEYCODE_ENTER = 2054,
    /** Backspace key */
    KEYCODE_DEL = 2055,
    /** Key * */
    KEYCODE_GRAVE = 2056,
    /** Key - */
    KEYCODE_MINUS = 2057,
    /** Key = */
    KEYCODE_EQUALS = 2058,
    /** Key [ */
    KEYCODE_LEFT_BRACKET = 2059,
    /** Key ] */
    KEYCODE_RIGHT_BRACKET = 2060,
    /** Key \ */
    KEYCODE_BACKSLASH = 2061,
    /** Key ; */
    KEYCODE_SEMICOLON = 2062,
    /** Key ' */
    KEYCODE_APOSTROPHE = 2063,
    /** Key / */
    KEYCODE_SLASH = 2064,
    /** Key @ */
    KEYCODE_AT = 2065,
    /** Key + */
    KEYCODE_PLUS = 2066,
    /** Menu key */
    KEYCODE_MENU = 2067,
    /** Page Up key */
    KEYCODE_PAGE_UP = 2068,
    /** Page Down key */
    KEYCODE_PAGE_DOWN = 2069,
    /** ESC key */
    KEYCODE_ESCAPE = 2070,
    /** Delete key */
    KEYCODE_FORWARD_DEL = 2071,
    /** Left Ctrl key */
    KEYCODE_CTRL_LEFT = 2072,
    /** Right Ctrl key */
    KEYCODE_CTRL_RIGHT = 2073,
    /** Caps Lock key */
    KEYCODE_CAPS_LOCK = 2074,
    /** Scroll Lock key */
    KEYCODE_SCROLL_LOCK = 2075,
    /** Left Meta key */
    KEYCODE_META_LEFT = 2076,
    /** Right Meta key */
    KEYCODE_META_RIGHT = 2077,
    /** Function key */
    KEYCODE_FUNCTION = 2078,
    /** System Request/Print Screen key */
    KEYCODE_SYSRQ = 2079,
    /** Break/Pause key */
    KEYCODE_BREAK = 2080,
    /** Move to Home key */
    KEYCODE_MOVE_HOME = 2081,
    /** Move to End key */
    KEYCODE_MOVE_END = 2082,
    /** Insert key */
    KEYCODE_INSERT = 2083,
    /** Forward key */
    KEYCODE_FORWARD = 2084,
    /** Play key */
    KEYCODE_MEDIA_PLAY = 2085,
    /** Pause key */
    KEYCODE_MEDIA_PAUSE = 2086,
    /** Close key */
    KEYCODE_MEDIA_CLOSE = 2087,
    /** Eject key */
    KEYCODE_MEDIA_EJECT = 2088,
    /** Record key */
    KEYCODE_MEDIA_RECORD = 2089,
    /** F1 key */
    KEYCODE_F1 = 2090,
    /** F2 key */
    KEYCODE_F2 = 2091,
    /** F3 key */
    KEYCODE_F3 = 2092,
    /** F4 key */
    KEYCODE_F4 = 2093,
    /** F5 key */
    KEYCODE_F5 = 2094,
    /** F6 key */
    KEYCODE_F6 = 2095,
    /** F7 key */
    KEYCODE_F7 = 2096,
    /** F8 key */
    KEYCODE_F8 = 2097,
    /** F9 key */
    KEYCODE_F9 = 2098,
    /** F10 key */
    KEYCODE_F10 = 2099,
    /** F11 key */
    KEYCODE_F11 = 2100,
    /** F12 key */
    KEYCODE_F12 = 2101,
    /** Number Lock key on numeric keypad */
    KEYCODE_NUM_LOCK = 2102,
    /** Key 0 on numeric keypad */
    KEYCODE_NUMPAD_0 = 2103,
    /** Key 1 on numeric keypad */
    KEYCODE_NUMPAD_1 = 2104,
    /** Key 2 on numeric keypad */
    KEYCODE_NUMPAD_2 = 2105,
    /** Key 3 on numeric keypad */
    KEYCODE_NUMPAD_3 = 2106,
    /** Key 4 on numeric keypad */
    KEYCODE_NUMPAD_4 = 2107,
    /** Key 5 on numeric keypad */
    KEYCODE_NUMPAD_5 = 2108,
    /** Key 6 on numeric keypad */
    KEYCODE_NUMPAD_6 = 2109,
    /** Key 7 on numeric keypad */
    KEYCODE_NUMPAD_7 = 2110,
    /** Key 8 on numeric keypad */
    KEYCODE_NUMPAD_8 = 2111,
    /** Key 9 on numeric keypad */
    KEYCODE_NUMPAD_9 = 2112,
    /** Key / on numeric keypad */
    KEYCODE_NUMPAD_DIVIDE = 2113,
    /** Key * on numeric keypad */
    KEYCODE_NUMPAD_MULTIPLY = 2114,
    /** Key - on numeric keypad */
    KEYCODE_NUMPAD_SUBTRACT = 2115,
    /** Key + on numeric keypad */
    KEYCODE_NUMPAD_ADD = 2116,
    /** Key . on numeric keypad */
    KEYCODE_NUMPAD_DOT = 2117,
    /** Key , on numeric keypad */
    KEYCODE_NUMPAD_COMMA = 2118,
    /** Enter key on numeric keypad */
    KEYCODE_NUMPAD_ENTER = 2119,
    /** Key = on numeric keypad */
    KEYCODE_NUMPAD_EQUALS = 2120,
    /** Key ( on numeric keypad */
    KEYCODE_NUMPAD_LEFT_PAREN = 2121,
    /** Key ) on numeric keypad */
    KEYCODE_NUMPAD_RIGHT_PAREN = 2122
} Input_KeyCode;

#ifdef __cplusplus
}
#endif
/** @} */

#endif /* OH_KEY_CODE_H */