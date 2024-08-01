/*
 * Copyright (c) 2021-2023 Huawei Device Co., Ltd.
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
 * @addtogroup OH_NativeXComponent Native XComponent
 * @{
 *
 * @brief Describes the surface and touch event held by the ArkUI XComponent, which can be used for the EGL/OpenGL ES\n
 *        and media data input and displayed on the ArkUI XComponent.
 *
 * @since 8
 * @version 1.0
 */

/**
 * @file native_interface_xcomponent.h
 *
 * @brief Declares APIs for accessing a Native XComponent.
 *
 * @since 8
 * @version 1.0
 */

#ifndef _NATIVE_INTERFACE_XCOMPONENT_H_
#define _NATIVE_INTERFACE_XCOMPONENT_H_

#include <stdbool.h>
#include <stdint.h>
#ifdef __cplusplus
#include <vector>
#endif

#include "arkui/native_type.h"
#include "arkui/ui_input_event.h"

#include "native_xcomponent_key_event.h"

#ifdef __cplusplus
extern "C" {
#endif

#define OH_NATIVE_XCOMPONENT_OBJ ("__NATIVE_XCOMPONENT_OBJ__")

const uint32_t OH_XCOMPONENT_ID_LEN_MAX = 128;
const uint32_t OH_MAX_TOUCH_POINTS_NUMBER = 10;

/**
 * @brief Enumerates the API access states.
 *
 * @since 8
 * @version 1.0
 */
enum {
    /** Successful. */
    OH_NATIVEXCOMPONENT_RESULT_SUCCESS = 0,
    /** Failed. */
    OH_NATIVEXCOMPONENT_RESULT_FAILED = -1,
    /** Invalid parameters. */
    OH_NATIVEXCOMPONENT_RESULT_BAD_PARAMETER = -2,
};

typedef enum {
    /** Trigger a touch event when a finger is pressed. */
    OH_NATIVEXCOMPONENT_DOWN = 0,
    /** Trigger a touch event when a finger is lifted. */
    OH_NATIVEXCOMPONENT_UP,
    /** Trigger a touch event when a finger moves on the screen in pressed state. */
    OH_NATIVEXCOMPONENT_MOVE,
    /** Trigger an event when a touch event is canceled. */
    OH_NATIVEXCOMPONENT_CANCEL,
    /** Invalid touch type. */
    OH_NATIVEXCOMPONENT_UNKNOWN,
} OH_NativeXComponent_TouchEventType;

/**
 * @brief Represents the touch point tool type.
 *
 * @since 9
 * @version 1.0
 */
typedef enum {
    /** Indicates invalid tool type. */
    OH_NATIVEXCOMPONENT_TOOL_TYPE_UNKNOWN = 0,
    /** Indicates a finger. */
    OH_NATIVEXCOMPONENT_TOOL_TYPE_FINGER,
    /** Indicates a stylus. */
    OH_NATIVEXCOMPONENT_TOOL_TYPE_PEN,
    /** Indicates a eraser. */
    OH_NATIVEXCOMPONENT_TOOL_TYPE_RUBBER,
    /** Indicates a brush. */
    OH_NATIVEXCOMPONENT_TOOL_TYPE_BRUSH,
    /** Indicates a pencil. */
    OH_NATIVEXCOMPONENT_TOOL_TYPE_PENCIL,
    /** Indicates a brush. */
    OH_NATIVEXCOMPONENT_TOOL_TYPE_AIRBRUSH,
    /** Indicates a mouse. */
    OH_NATIVEXCOMPONENT_TOOL_TYPE_MOUSE,
    /** Indicates a lens. */
    OH_NATIVEXCOMPONENT_TOOL_TYPE_LENS,
} OH_NativeXComponent_TouchPointToolType;

/**
 * @brief Represents the touch event source type.
 *
 * @since 9
 * @version 1.0
 */
typedef enum {
    /** Indicates an unknown input source type. */
    OH_NATIVEXCOMPONENT_SOURCE_TYPE_UNKNOWN = 0,
    /** Indicates that the input source generates a mouse multi-touch event. */
    OH_NATIVEXCOMPONENT_SOURCE_TYPE_MOUSE,
    /** Indicates that the input source generates a touchscreen multi-touch event. */
    OH_NATIVEXCOMPONENT_SOURCE_TYPE_TOUCHSCREEN,
    /** Indicates that the input source generates a touchpad multi-touch event. */
    OH_NATIVEXCOMPONENT_SOURCE_TYPE_TOUCHPAD,
    /** Indicates that the input source generates a joystick multi-touch event. */
    OH_NATIVEXCOMPONENT_SOURCE_TYPE_JOYSTICK,
    /**
     * @brief Indicates that the input source generates a keyboard event.
     *
     * @since 10
     * @version 1.0
     */
    OH_NATIVEXCOMPONENT_SOURCE_TYPE_KEYBOARD,
} OH_NativeXComponent_EventSourceType;

/**
 * @brief Represents the mouse event action.
 *
 * @since 9
 * @version 1.0
 */
typedef enum {
    OH_NATIVEXCOMPONENT_MOUSE_NONE = 0,
    OH_NATIVEXCOMPONENT_MOUSE_PRESS,
    OH_NATIVEXCOMPONENT_MOUSE_RELEASE,
    OH_NATIVEXCOMPONENT_MOUSE_MOVE,
} OH_NativeXComponent_MouseEventAction;

/**
 * @brief Represents the mouse event button.
 *
 * @since 9
 * @version 1.0
 */
typedef enum {
    OH_NATIVEXCOMPONENT_NONE_BUTTON = 0,
    OH_NATIVEXCOMPONENT_LEFT_BUTTON = 0x01,
    OH_NATIVEXCOMPONENT_RIGHT_BUTTON = 0x02,
    OH_NATIVEXCOMPONENT_MIDDLE_BUTTON = 0x04,
    OH_NATIVEXCOMPONENT_BACK_BUTTON = 0x08,
    OH_NATIVEXCOMPONENT_FORWARD_BUTTON = 0x10,
} OH_NativeXComponent_MouseEventButton;

/**
 * @brief Represents the source tool type of TouchEvent
 *
 * @since 10
 * @version 1.0
 */
typedef enum {
    OH_NATIVEXCOMPONENT_SOURCETOOL_UNKNOWN = 0,
    OH_NATIVEXCOMPONENT_SOURCETOOL_FINGER = 1,
    OH_NATIVEXCOMPONENT_SOURCETOOL_PEN = 2,
    OH_NATIVEXCOMPONENT_SOURCETOOL_RUBBER = 3,
    OH_NATIVEXCOMPONENT_SOURCETOOL_BRUSH = 4,
    OH_NATIVEXCOMPONENT_SOURCETOOL_PENCIL = 5,
    OH_NATIVEXCOMPONENT_SOURCETOOL_AIRBRUSH = 6,
    OH_NATIVEXCOMPONENT_SOURCETOOL_MOUSE = 7,
    OH_NATIVEXCOMPONENT_SOURCETOOL_LENS = 8,
    OH_NATIVEXCOMPONENT_SOURCETOOL_TOUCHPAD = 9,
} OH_NativeXComponent_TouchEvent_SourceTool;

typedef struct {
    /** Unique identifier of a finger. */
    int32_t id;
    /** X coordinate of the touch point relative to the left edge of the screen. */
    float screenX;
    /** Y coordinate of the touch point relative to the upper edge of the screen. */
    float screenY;
    /** X coordinate of the touch point relative to the left edge of the element to touch. */
    float x;
    /** Y coordinate of the touch point relative to the upper edge of the element to touch. */
    float y;
    /** Touch type of the touch event. */
    OH_NativeXComponent_TouchEventType type;
    /** Contact area between the finger pad and the screen. */
    double size;
    /** Pressure of the current touch event. */
    float force;
    /** Timestamp of the current touch event. */
    int64_t timeStamp;
    /** The angle betweenprojection on plane-X-Y and axis-Z of the current touch event. */
    float titlX;
    /** The angle betweenprojection on plane-Y-Z and axis-Z of the current touch event. */
    float titlY;
    /** The sourceTool of the current touch event. */
    OH_NativeXComponent_TouchEvent_SourceTool sourceTool;
} OH_NativeXComponent_HistoricalPoint;

typedef struct {
    /** Unique identifier of a finger. */
    int32_t id;
    /** X coordinate of the touch point relative to the left edge of the screen. */
    float screenX;
    /** Y coordinate of the touch point relative to the upper edge of the screen. */
    float screenY;
    /** X coordinate of the touch point relative to the left edge of the element to touch. */
    float x;
    /** Y coordinate of the touch point relative to the upper edge of the element to touch. */
    float y;
    /** Touch type of the touch event. */
    OH_NativeXComponent_TouchEventType type;
    /** Contact area between the finger pad and the screen. */
    double size;
    /** Pressure of the current touch event. */
    float force;
    /** Timestamp of the current touch event. */
    int64_t timeStamp;
    /** Whether the current point is pressed. */
    bool isPressed;
} OH_NativeXComponent_TouchPoint;

// Represents the touch point information.
typedef struct {
    /** Unique identifier of a finger. */
    int32_t id;
    /** X coordinate of the touch point relative to the left edge of the screen. */
    float screenX;
    /** Y coordinate of the touch point relative to the upper edge of the screen. */
    float screenY;
    /** X coordinate of the touch point relative to the left edge of the element to touch. */
    float x;
    /** Y coordinate of the touch point relative to the upper edge of the element to touch. */
    float y;
    /** Touch type of the touch event. */
    OH_NativeXComponent_TouchEventType type;
    /** Contact area between the finger pad and the screen. */
    double size;
    /** Pressure of the current touch event. */
    float force;
    /** ID of the device where the current touch event is generated. */
    int64_t deviceId;
    /** Timestamp of the current touch event. */
    int64_t timeStamp;
    /** Array of the current touch points. */
    OH_NativeXComponent_TouchPoint touchPoints[OH_MAX_TOUCH_POINTS_NUMBER];
    /** Number of current touch points. */
    uint32_t numPoints;
} OH_NativeXComponent_TouchEvent;

/**
 * @brief Represents the mouse event information.
 *
 * @since 9
 * @version 1.0
 */
typedef struct {
    /** X coordinate of the mouse point relative to the left edge of the element to mouse. */
    float x;
    /** Y coordinate of the mouse point relative to the upper edge of the element to mouse. */
    float y;
    /** X coordinate of the mouse point relative to the left edge of the screen. */
    float screenX;
    /** Y coordinate of the mouse point relative to the upper edge of the screen. */
    float screenY;
    /** Timestamp of the current mouse event. */
    int64_t timestamp;
    /** Mouse event action. */
    OH_NativeXComponent_MouseEventAction action;
    /** Mouse event button. */
    OH_NativeXComponent_MouseEventButton button;
} OH_NativeXComponent_MouseEvent;

/**
 * @brief Provides an encapsulated <b>OH_NativeXComponent</b> instance.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_NativeXComponent OH_NativeXComponent;

/**
 * @brief Registers the surface lifecycle and touch event callbacks.
 *
 * @since 8
 * @version 1.0
 */
typedef struct OH_NativeXComponent_Callback {
    /** Called when the surface is created. */
    void (*OnSurfaceCreated)(OH_NativeXComponent* component, void* window);
    /** Called when the surface is changed. */
    void (*OnSurfaceChanged)(OH_NativeXComponent* component, void* window);
    /** Called when the surface is destroyed. */
    void (*OnSurfaceDestroyed)(OH_NativeXComponent* component, void* window);
    /** Called when a touch event is triggered. */
    void (*DispatchTouchEvent)(OH_NativeXComponent* component, void* window);
} OH_NativeXComponent_Callback;

/**
 * @brief Registers the mouse event callbacks.
 *
 * @since 9
 * @version 1.0
 */
typedef struct OH_NativeXComponent_MouseEvent_Callback {
    /** Called when a mouse event is triggered. */
    void (*DispatchMouseEvent)(OH_NativeXComponent* component, void* window);
    /** Called when a hover event is triggered. */
    void (*DispatchHoverEvent)(OH_NativeXComponent* component, bool isHover);
} OH_NativeXComponent_MouseEvent_Callback;

struct OH_NativeXComponent_KeyEvent;
/**
 * @brief Provides an encapsulated <b>OH_NativeXComponent_KeyEvent</b> instance.
 *
 * @since 10
 * @version 1.0
 */
typedef struct OH_NativeXComponent_KeyEvent OH_NativeXComponent_KeyEvent;

/**
 * @brief Defines the expected frame rate range struct.
 *
 * @since 11
 * @version 1.0
 */
typedef struct {
    /** The minimum frame rate of dynamical callback rate range. */
    int32_t min;
    /** The maximum frame rate of dynamical callback rate range. */
    int32_t max;
    /** The expected frame rate of dynamical callback rate range. */
    int32_t expected;
} OH_NativeXComponent_ExpectedRateRange;

/**
 * @brief Obtains the ID of the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param id Indicates the char buffer to keep the ID of this <b>OH_NativeXComponent</b> instance.\n
 *        Notice that a null-terminator will be appended to the char buffer, so the size of the\n
 *        char buffer should be at least as large as the size of the real id length plus 1.\n
 *        It is recommended that the size of the char buffer be [OH_XCOMPONENT_ID_LEN_MAX + 1].
 * @param size Indicates the pointer to the length of <b>id</b>, which you can receive.
 * @return Returns the status code of the execution.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetXComponentId(OH_NativeXComponent* component, char* id, uint64_t* size);

/**
 * @brief Obtains the size of the surface held by the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param window Indicates the native window handler.
 * @param width Indicates the pointer to the width of the current surface.
 * @param height Indicates the pointer to the height of the current surface.
 * @return Returns the status code of the execution.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetXComponentSize(
    OH_NativeXComponent* component, const void* window, uint64_t* width, uint64_t* height);

/**
 * @brief Obtains the offset of the surface held by the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param window Indicates the native window handler.
 * @param x Indicates the pointer to the x coordinate of the current surface.
 * @param y Indicates the pointer to the y coordinate of the current surface.
 * @return Returns the status code of the execution.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetXComponentOffset(
    OH_NativeXComponent* component, const void* window, double* x, double* y);

/**
 * @brief Obtains the touch event dispatched by the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param window Indicates the native window handler.
 * @param touchEvent Indicates the pointer to the current touch event.
 * @return Returns the status code of the execution.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetTouchEvent(
    OH_NativeXComponent* component, const void* window, OH_NativeXComponent_TouchEvent* touchEvent);

/**
 * @brief Obtains the touch pointer tool type by the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param pointIndex Indicates the pointer index in the touchPoints.
 * @param toolType Indicates the tool Type of the pointer.
 * @return Returns the status code of the execution.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetTouchPointToolType(
    OH_NativeXComponent* component, uint32_t pointIndex, OH_NativeXComponent_TouchPointToolType* toolType);

/**
 * @brief Obtains the touch pointer tiltX by the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param pointIndex Indicates the pointer index in the touchPoints.
 * @param tiltX Indicates the x tilt of the pointer.
 * @return Returns the status code of the execution.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetTouchPointTiltX(OH_NativeXComponent* component, uint32_t pointIndex, float* tiltX);

/**
 * @brief Obtains the touch pointer tiltX by the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param pointIndex Indicates the pointer index in the touchPoints.
 * @param tiltY Indicates the y tilt of the pointer.
 * @return Returns the status code of the execution.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetTouchPointTiltY(OH_NativeXComponent* component, uint32_t pointIndex, float* tiltY);

/**
 * @brief Obtains the touch event dispatched by the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param window Indicates the native window handler.
 * @param historicalPoints Indicates the pointer to the current historicalPoints.
 * @return Returns the status code of the execution.
 * @since 10
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetHistoricalPoints(OH_NativeXComponent* component, const void* window,
    int32_t* size, OH_NativeXComponent_HistoricalPoint** historicalPoints);

/**
 * @brief Obtains the mouse event dispatched by the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param window Indicates the native window handler.
 * @param mouseEvent Indicates the pointer to the current mouse event.
 * @return Returns the status code of the execution.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetMouseEvent(
    OH_NativeXComponent* component, const void* window, OH_NativeXComponent_MouseEvent* mouseEvent);

/**
 * @brief Registers a callback for this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to a surface lifecycle and touch event callback.
 * @return Returns the status code of the execution.
 * @since 8
 * @version 1.0
 */
int32_t OH_NativeXComponent_RegisterCallback(OH_NativeXComponent* component, OH_NativeXComponent_Callback* callback);

/**
 * @brief Registers a callback for this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to a mouse event callback.
 * @return Returns the status code of the execution.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeXComponent_RegisterMouseEventCallback(
    OH_NativeXComponent* component, OH_NativeXComponent_MouseEvent_Callback* callback);

/**
 * @brief Registers a callback for this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to a focus event callback.
 * @return Returns the status code of the execution.
 * @since 10
 * @version 1.0
 */
int32_t OH_NativeXComponent_RegisterFocusEventCallback(
    OH_NativeXComponent* component, void (*callback)(OH_NativeXComponent* component, void* window));

/**
 * @brief Registers a callback for this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to a key event callback.
 * @return Returns the status code of the execution.
 * @since 10
 * @version 1.0
 */
int32_t OH_NativeXComponent_RegisterKeyEventCallback(
    OH_NativeXComponent* component, void (*callback)(OH_NativeXComponent* component, void* window));

/**
 * @brief Registers a callback for this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to a blur event callback.
 * @return Returns the status code of the execution.
 * @since 10
 * @version 1.0
 */
int32_t OH_NativeXComponent_RegisterBlurEventCallback(
    OH_NativeXComponent* component, void (*callback)(OH_NativeXComponent* component, void* window));

/**
 * @brief Obtains the key event dispatched by the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param keyEvent Indicates the pointer to pointer of <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @return Returns the status code of the execution.
 * @since 10
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetKeyEvent(OH_NativeXComponent* component, OH_NativeXComponent_KeyEvent** keyEvent);

/**
 * @brief Obtains the action of the key event.
 *
 * @param keyEvent Indicates the pointer to this <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @param action Indicates the action of the <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @return Returns the status code of the execution.
 * @since 10
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetKeyEventAction(
    OH_NativeXComponent_KeyEvent* keyEvent, OH_NativeXComponent_KeyAction* action);

/**
 * @brief Obtains the keyCode of the key event.
 *
 * @param keyEvent Indicates the pointer to this <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @param code Indicates the keyCode of the <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @return Returns the status code of the execution.
 * @since 10
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetKeyEventCode(OH_NativeXComponent_KeyEvent* keyEvent, OH_NativeXComponent_KeyCode* code);

/**
 * @brief Obtains the sourceType of the key event.
 *
 * @param keyEvent Indicates the pointer to this <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @param sourceType Indicates the sourceType of the <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @return Returns the status code of the execution.
 * @since 10
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetKeyEventSourceType(
    OH_NativeXComponent_KeyEvent* keyEvent, OH_NativeXComponent_EventSourceType* sourceType);

/**
 * @brief Obtains the deviceId of the key event.
 *
 * @param keyEvent Indicates the pointer to this <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @param deviceId Indicates the deviceId of the <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @return Returns the status code of the execution.
 * @since 10
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetKeyEventDeviceId(OH_NativeXComponent_KeyEvent* keyEvent, int64_t* deviceId);

/**
 * @brief Obtains the timestamp of the key event.
 *
 * @param keyEvent Indicates the pointer to this <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @param timestamp Indicates the timestamp of the <b>OH_NativeXComponent_KeyEvent</b> instance.
 * @return Returns the status code of the execution.
 * @since 10
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetKeyEventTimestamp(OH_NativeXComponent_KeyEvent* keyEvent, int64_t* timestamp);

/**
 * @brief Set the Expected FrameRateRange.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to a expected rate range.
 * @return Returns the status code of the execution.
 * @since 11
 * @version 1.0
 */
int32_t OH_NativeXComponent_SetExpectedFrameRateRange(
    OH_NativeXComponent* component, OH_NativeXComponent_ExpectedRateRange* range);

/**
 * @brief Registers a callback for this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to a onFrame callback.
 * @return Returns the status code of the execution.
 * @since 11
 * @version 1.0
 */
int32_t OH_NativeXComponent_RegisterOnFrameCallback(OH_NativeXComponent* component,
    void (*callback)(OH_NativeXComponent* component, uint64_t timestamp, uint64_t targetTimestamp));

/**
 * @brief UnRegister a callback for this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @return Returns the status code of the execution.
 * @since 11
 * @version 1.0
 */
int32_t OH_NativeXComponent_UnregisterOnFrameCallback(OH_NativeXComponent* component);

/**
 * @brief Attaches the UI component created through the native API of ArkUI to this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to the <b>OH_NativeXComponent</b> instance.
 * @param root Indicates the pointer to the component instance created by the native API.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 *
 * @since 12
 */
int32_t OH_NativeXComponent_AttachNativeRootNode(OH_NativeXComponent* component, ArkUI_NodeHandle root);

/**
 * @brief Detaches the native component of ArkUI from this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to the <b>OH_NativeXComponent</b> instance.
 * @param root Indicates the pointer to the component instance created by the native API.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 *
 * @since 12
 */
int32_t OH_NativeXComponent_DetachNativeRootNode(OH_NativeXComponent* component, ArkUI_NodeHandle root);

/**
 * @brief Registers a callback for this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to a surface show event callback.
 * @return Returns the status code of the execution.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeXComponent_RegisterSurfaceShowCallback(
    OH_NativeXComponent* component, void (*callback)(OH_NativeXComponent* component, void* window));

/**
 * @brief Registers a callback for this <b>OH_NativeXComponent</b> instance.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to a surface hide event callback.
 * @return Returns the status code of the execution.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeXComponent_RegisterSurfaceHideCallback(
    OH_NativeXComponent* component, void (*callback)(OH_NativeXComponent* component, void* window));

/**
 * @brief Registers a UI input event callback for this <b>OH_NativeXComponent</b> instance and enables the callback to
 * be invoked when a UI input event is received.
 *
 * @param component Indicates the pointer to the <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to the UI input event callback.
 * @param type Indicates the type of the current UI input event.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_NativeXComponent_RegisterUIInputEventCallback(
    OH_NativeXComponent* component,
    void (*callback)(OH_NativeXComponent* component, ArkUI_UIInputEvent* event,
                     ArkUI_UIInputEvent_Type type),
    ArkUI_UIInputEvent_Type type);

/**
 * @brief Set whether the <b>OH_NativeXComponent</b> instance needs soft keyboard.
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param needSoftKeyboard Indicates whether the <b>OH_NativeXComponent</b> instance needs soft keyboard or not.
 *                           Default value is false.
 * @return Returns the status code of the execution.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeXComponent_SetNeedSoftKeyboard(OH_NativeXComponent* component, bool needSoftKeyboard);

/**
 * @brief Registers a custom event intercept callback for this <b>OH_NativeXComponent</b> and enables the callback
 * during the hit test.
 *
 * @param component Indicates the pointer to the <b>OH_NativeXComponent</b> instance.
 * @param callback Indicates the pointer to the custom event intercept callback.
 * @return Returns the error code.
 *         Returns {@link ARKUI_ERROR_CODE_NO_ERROR} if the operation is successful.
 *         Returns {@link ARKUI_ERROR_CODE_PARAM_INVALID} if a parameter error occurs.
 * @since 12
 */
int32_t OH_NativeXComponent_RegisterOnTouchInterceptCallback(
    OH_NativeXComponent* component, HitTestMode (*callback)(OH_NativeXComponent* component, ArkUI_UIInputEvent* event));

/**
 * @brief Obtains the touch event's source type dispatched by the ArkUI XComponent.
 *
 * @param component Indicates the pointer to this <b>OH_NativeXComponent</b> instance.
 * @param pointId Indicates the id of the touch point which triggers this touch event.
 * @param sourceType Indicates the source type of this touch event.
 * @return Returns OH_NATIVEXCOMPONENT_RESULT_SUCCESS if success.
 *         Returns OH_NATIVEXCOMPONENT_RESULT_BAD_PARAMETER if a parameter exception occurs.
 *         Returns OH_NATIVEXCOMPONENT_RESULT_FAILED if other exceptions occur.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeXComponent_GetTouchEventSourceType(
    OH_NativeXComponent* component, int32_t pointId, OH_NativeXComponent_EventSourceType* sourceType);

/**
 * @brief Obtains the pointer to an <b>OH_NativeXComponent</b> instance based on the specified component
 * instance created by the native API.
 *
 * @param node Indicates the pointer to the component instance created by the native API.
 * @return Returns the pointer to the <b>OH_NativeXComponent</b> instance.
 * @since 12
 * @version 1.0
 */
OH_NativeXComponent* OH_NativeXComponent_GetNativeXComponent(ArkUI_NodeHandle node);

#ifdef __cplusplus
};
#endif
#endif // _NATIVE_INTERFACE_XCOMPONENT_H_