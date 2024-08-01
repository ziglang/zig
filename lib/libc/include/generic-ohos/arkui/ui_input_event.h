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

/**
 * @addtogroup ArkUI_EventModule
 * @{
 *
 * @brief Declares the UI input event capabilities provided by ArkUI on the native side.
 *
 * @since 12
 */

/**
 * @file ui_input_event.h
 *
 * @brief Provides ArkUI event definitions on the native side.
 *
 * @library libace_ndk.z.so
 * @syscap SystemCapability.ArkUI.ArkUI.Full
 * @since 12
 */

#ifndef _ARKUI_UI_INPUT_EVENT_H_
#define _ARKUI_UI_INPUT_EVENT_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the UI input event.
 *
 * @since 12
 */
typedef struct ArkUI_UIInputEvent ArkUI_UIInputEvent;

/**
 * @brief Enumerates the UI input event types.
 *
 * @since 12
 */
typedef enum {
    ARKUI_UIINPUTEVENT_TYPE_UNKNOWN = 0,
    ARKUI_UIINPUTEVENT_TYPE_TOUCH = 1,
    ARKUI_UIINPUTEVENT_TYPE_AXIS = 2,
    /** Mouse event. */
    ARKUI_UIINPUTEVENT_TYPE_MOUSE = 3,
} ArkUI_UIInputEvent_Type;

/**
 * @brief Defines the action code of the input event.
 *
 * @since 12
 */
enum {
    /** Cancellation of touch. */
    UI_TOUCH_EVENT_ACTION_CANCEL = 0,
    /** Pressing of a touch point. */
    UI_TOUCH_EVENT_ACTION_DOWN = 1,
    /** Moving of a touch point. */
    UI_TOUCH_EVENT_ACTION_MOVE = 2,
    /** Lifting of a touch point. */
    UI_TOUCH_EVENT_ACTION_UP = 3,
};

/**
 * @brief Defines the tool type of the touch event.
 *
 * @since 12
 */
enum {
    /** Unknown tool type. */
    UI_INPUT_EVENT_TOOL_TYPE_UNKNOWN = 0,

    /** Finger. */
    UI_INPUT_EVENT_TOOL_TYPE_FINGER = 1,

    /** Pen. */
    UI_INPUT_EVENT_TOOL_TYPE_PEN = 2,

    /** Mouse. */
    UI_INPUT_EVENT_TOOL_TYPE_MOUSE = 3,

    /** TouchPad. */
    UI_INPUT_EVENT_TOOL_TYPE_TOUCHPAD = 4,

    /** JoyStick. */
    UI_INPUT_EVENT_TOOL_TYPE_JOYSTICK = 5,
};

/**
 * @brief Defines the source type of the touch event.
 *
 * @since 12
 */
enum {
    /** Unknown source type. */
    UI_INPUT_EVENT_SOURCE_TYPE_UNKNOWN = 0,
    /** Mouse. */
    UI_INPUT_EVENT_SOURCE_TYPE_MOUSE = 1,
    /** Touchscreen. */
    UI_INPUT_EVENT_SOURCE_TYPE_TOUCH_SCREEN = 2,
};

/**
 * @brief Enumerates the hit test modes.
 *
 * @since 12
 */
typedef enum {
    /** Both the node and its child node respond to the hit test of a touch event, but its sibling node is blocked from
     *  the hit test.
     */
    HTM_DEFAULT = 0,

    /** The node responds to the hit test of a touch event, but its child node and sibling node are blocked from the hit
     *  test.
     */
    HTM_BLOCK,

    /** Both the node and its child node respond to the hit test of a touch event, and its sibling node is also
     *  considered during the hit test.
     */
    HTM_TRANSPARENT,

    /** The node does not respond to the hit test of a touch event, but its child node and sibling node are considered
     *  during the hit test.
     */
    HTM_NONE,
} HitTestMode;

/**
 * @brief Define the Action Code for mouse events.
 *
 * @since 12
 */
enum {
    /** Invalid. */
    UI_MOUSE_EVENT_ACTION_UNKNOWN = 0,
    /** Press. */
    UI_MOUSE_EVENT_ACTION_PRESS = 1,
    /** Release. */
    UI_MOUSE_EVENT_ACTION_RELEASE = 2,
    /** Move. */
    UI_MOUSE_EVENT_ACTION_MOVE = 3,
};

/**
 * @brief Define the button type for mouse events.
 *
 * @since 12
 */
enum {
    /** None. */
    UI_MOUSE_EVENT_BUTTON_NONE = 0,
    /** Left. */
    UI_MOUSE_EVENT_BUTTON_LEFT = 1,
    /** Right. */
    UI_MOUSE_EVENT_BUTTON_RIGHT = 2,
    /** Middle. */
    UI_MOUSE_EVENT_BUTTON_MIDDLE = 3,
    /** Back. */
    UI_MOUSE_EVENT_BUTTON_BACK = 4,
    /** Forward. */
    UI_MOUSE_EVENT_BUTTON_FORWARD = 5,
};

/**
 * @brief Obtains the type of this UI input event.
 *
 * @param event Indicates the pointer to the current UI input event.
 * @return Returns the type of the current UI input event; returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_UIInputEvent_GetType(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the action type of this UI input event.
 *
 * @param event Indicates the pointer to the current UI input event.
 * @return Returns the action type of the current UI input event; returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
int32_t OH_ArkUI_UIInputEvent_GetAction(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the source type of this UI input event.
 *
 * @param event Indicates the pointer to the current UI input event.
 * @return Returns the source type of the current UI input event.
 * @since 12
 */
int32_t OH_ArkUI_UIInputEvent_GetSourceType(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the tool type of this UI input event.
 *
 * @param event Indicates the pointer to the current UI input event.
 * @return Returns the tool type of the current UI input event.
 * @since 12
 */
int32_t OH_ArkUI_UIInputEvent_GetToolType(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the time when this UI input event occurs.
 *
 * @param event Indicates the pointer to the current UI input event.
 * @return Returns the time when the UI input event occurs; returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
int64_t OH_ArkUI_UIInputEvent_GetEventTime(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the number of touch points from a directional input event (such as a touch event, mouse event,
 * or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @return Returns the number of touch points for the directional input event.
 * @since 12
 */
uint32_t OH_ArkUI_PointerEvent_GetPointerCount(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the ID of a touch point from a directional input event (such as a touch event, mouse event,
 * or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the ID of the corresponding touch point.
 * @since 12
 */
int32_t OH_ArkUI_PointerEvent_GetPointerId(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the X coordinate relative to the upper left corner of the current component from a directional
 * input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the directional input event.
 * @return Returns the X coordinate relative to the upper left corner of the current component;
 * returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetX(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the X coordinate of a specific touch point relative to the upper left corner of the current component
 * from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the X coordinate relative to the upper left corner of the current component;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetXByIndex(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the Y coordinate relative to the upper left corner of the current component from a directional
 * input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the UI input event.
 * @return Returns the Y coordinate relative to the upper left corner of the current component;
 * returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetY(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the Y coordinate of a specific touch point relative to the upper left corner of the current component
 * from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the Y coordinate relative to the upper left corner of the current component;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetYByIndex(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the X coordinate relative to the upper left corner of the current application window from a
 * directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the UI input event.
 * @return Returns the X coordinate relative to the upper left corner of the current application window;
 * returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetWindowX(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the X coordinate of a specific touch point relative to the upper left corner of the current
 * application window from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the X coordinate relative to the upper left corner of the current application window;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetWindowXByIndex(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the Y coordinate relative to the upper left corner of the current application window from a
 * directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the UI input event.
 * @return Returns the Y coordinate relative to the upper left corner of the current application window;
 * returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetWindowY(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the Y coordinate of a specific touch point relative to the upper left corner of the current
 * application window from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the Y coordinate relative to the upper left corner of the current application window;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetWindowYByIndex(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the X coordinate relative to the upper left corner of the current screen from a directional input
 * event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the UI input event.
 * @return Returns the X coordinate relative to the upper left corner of the current screen;
 * returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetDisplayX(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the X coordinate of a specific touch point relative to the upper left corner of the current screen
 * from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the X coordinate relative to the upper left corner of the current screen;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetDisplayXByIndex(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the Y coordinate relative to the upper left corner of the current screen from a directional input
 * event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the UI input event.
 * @return Returns the Y coordinate relative to the upper left corner of the current screen;
 * returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetDisplayY(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the Y coordinate of a specific touch point relative to the upper left corner of the current screen
 * from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the Y coordinate relative to the upper left corner of the current screen;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetDisplayYByIndex(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the pressure applied to the touchscreen from a directional input event (for example, a touch event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the pressure applied to the touchscreen; returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetPressure(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the angle relative to the YZ plane from a directional input event (for example, a touch event).
 * The value range is [-90, 90]. A positive value indicates a rightward tilt.
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the angle relative to the YZ plane.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetTiltX(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the angle relative to the XZ plane from a directional input event (for example, a touch event).
 * The value range is [-90, 90]. A positive value indicates a downward tilt.
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the angle relative to the XZ plane.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetTiltY(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the width of the touch area from a directional input event (for example, a touch event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the width of the touch area.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetTouchAreaWidth(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the height of the touch area from a directional input event (for example, a touch event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @return Returns the height of the touch area.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetTouchAreaHeight(const ArkUI_UIInputEvent* event, uint32_t pointerIndex);

/**
 * @brief Obtains the number of historical events from a directional input event (such as a touch event, mouse event,
 * or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @return Returns the number of historical events.
 * @since 12
 */
uint32_t OH_ArkUI_PointerEvent_GetHistorySize(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the occurrence time of a historical event from a directional input event (such as a touch event,
 * mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the time when the UI input event occurs; returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
int64_t OH_ArkUI_PointerEvent_GetHistoryEventTime(const ArkUI_UIInputEvent* event, uint32_t historyIndex);

/**
 * @brief Obtains the number of touch points in a specific historical event from a directional input event (such as
 * a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the number of touch points in the specified historical event
 * @since 12
 */
uint32_t OH_ArkUI_PointerEvent_GetHistoryPointerCount(const ArkUI_UIInputEvent* event, uint32_t historyIndex);

/**
 * @brief Obtains the ID of a touch point in a specific historical event from a directional input event (such as
 * a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the ID of the corresponding touch point in the specified historical event.
 * @since 12
 */
int32_t OH_ArkUI_PointerEvent_GetHistoryPointerId(
    const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the X coordinate of a specific touch point in a historical event relative to the upper left corner
 * of the current component from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the X coordinate relative to the upper left corner of the current component;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryX(const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the Y coordinate of a specific touch point in a historical event relative to the upper left corner
 * of the current component from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the Y coordinate relative to the upper left corner of the current component;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryY(const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the X coordinate of a specific touch point in a historical event relative to the upper left corner
 * of the current application window from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the X coordinate relative to the upper left corner of the current application window;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryWindowX(
    const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the Y coordinate of a specific touch point in a historical event relative to the upper left corner
 * of the current application window from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the Y coordinate relative to the upper left corner of the current application window;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryWindowY(
    const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the X coordinate of a specific touch point in a historical event relative to the upper left corner
 * of the current screen from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the X coordinate relative to the upper left corner of the current screen;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryDisplayX(
    const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the Y coordinate of a specific touch point in a historical event relative to the upper left corner
 * of the current screen from a directional input event (such as a touch event, mouse event, or axis event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the Y coordinate relative to the upper left corner of the current screen;
 * returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryDisplayY(
    const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the pressure applied to the touchscreen in a specific historical event from a directional input event
 * (for example, a touch event)..
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the pressure applied to the touchscreen; returns <b>0.0f</b> if any parameter error occurs.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryPressure(
    const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the angle relative to the YZ plane in a specific historical event from a directional input event
 * (for example, a touch event). The value range is [-90, 90]. A positive value indicates a rightward tilt.
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the angle relative to the YZ plane.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryTiltX(
    const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the angle relative to the XZ plane in a specific historical event from a directional input event
 * (for example, a touch event). The value range is [-90, 90]. A positive value indicates a downward tilt.
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the angle relative to the XZ plane.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryTiltY(
    const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the width of the touch area in a specific historical event from a directional input event
 * (for example, a touch event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the width of the touch area.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryTouchAreaWidth(
    const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the height of the touch area in a specific historical event from a directional input event
 * (for example, a touch event).
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param pointerIndex Indicates the index of the target touch point in the multi-touch data list.
 * @param historyIndex Indicates the index of the target historical event.
 * @return Returns the height of the touch area.
 * @since 12
 */
float OH_ArkUI_PointerEvent_GetHistoryTouchAreaHeight(
    const ArkUI_UIInputEvent* event, uint32_t pointerIndex, uint32_t historyIndex);

/**
 * @brief Obtains the value of the vertical scroll axis for this axis event.
 *
 * @param event Indicates the pointer to the UI input event.
 * @return Returns the value of the vertical scroll axis of the current axis event;
 * returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
double OH_ArkUI_AxisEvent_GetVerticalAxisValue(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the value of the horizontal scroll axis for this axis event.
 *
 * @param event Indicates the pointer to the UI input event.
 * @return Returns the value of the horizontal scroll axis of the current axis event;
 * returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
double OH_ArkUI_AxisEvent_GetHorizontalAxisValue(const ArkUI_UIInputEvent* event);

/**
 * @brief Obtains the scale value of the pinch axis for this axis event.
 *
 * @param event Indicates the pointer to the UI input event.
 * @return Returns the scale value of the pinch axis of the current axis event;
 * returns <b>0</b> if any parameter error occurs.
 * @since 12
 */
double OH_ArkUI_AxisEvent_GetPinchAxisScaleValue(const ArkUI_UIInputEvent* event);

/**
 * @brief Sets how the component behaves during hit testing.
 *
 * @param event Indicates the pointer to the current UI input event.
 * @param mode Indicates how the component behaves during hit testing. The parameter type is {@link HitTestMode}.
 * @return Returns the status code of the execution.
 * @since 12
 */
int32_t OH_ArkUI_PointerEvent_SetInterceptHitTestMode(const ArkUI_UIInputEvent* event, HitTestMode mode);

/**
 * @brief Get the value of the button type for mouse events.
 *
 * @param event Represents a pointer to the current UI input event.
 * @return Return to the mouse button type, where <b>1</b> is the left button, <b>2</b> is the right button,
 * <b>3</b> is the middle button, <b>4</b> is the back button, and <b>5</b> is the forward button.
 * @since 12
 */
int32_t OH_ArkUI_MouseEvent_GetMouseButton(const ArkUI_UIInputEvent* event);

/**
 * @brief Get the value of the mouse action type for mouse events.
 *
 * @param event Represents a pointer to the current UI input event.
 * @return Returns the type of mouse action, where <b>1</b> represents button pressed,
 * <b>2</b> represents button released, and <b>3</b> represents mouse movement.
 * @since 12
 */
int32_t OH_ArkUI_MouseEvent_GetMouseAction(const ArkUI_UIInputEvent* event);

#ifdef __cplusplus
};
#endif

#endif // _ARKUI_UI_INPUT_EVENT_H_
/** @} */