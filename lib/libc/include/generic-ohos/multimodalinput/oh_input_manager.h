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

#ifndef OH_INPUT_MANAGER_H
#define OH_INPUT_MANAGER_H

/**
 * @addtogroup input
 * @{
 *
 * @brief Provides the C interface in the multi-modal input domain.
 *
 * @since 12
 */

/**
 * @file oh_input_manager.h
 *
 * @brief Provides capabilities such as event injection and key status query.
 *
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @library liboh_input.so
 * @since 12
 */

#include <stdint.h>

#include "oh_key_code.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerated values of key event action.
 *
 * @since 12
 */
enum Input_KeyStateAction {
    /** Default */
    KEY_DEFAULT = -1,
    /** Pressing of a key */
    KEY_PRESSED = 0,
    /** Release of a key */
    KEY_RELEASED = 1,
    /** Key switch enabled */
    KEY_SWITCH_ON = 2,
    /** Key switch disabled */
    KEY_SWITCH_OFF = 3
};

/**
 * @brief Enumerates key event types.
 *
 * @since 12
 */
typedef enum {
    /** Cancellation of a key action. */
    KEY_ACTION_CANCEL = 0,
    /** Pressing of a key. */
    KEY_ACTION_DOWN = 1,
    /** Release of a key. */
    KEY_ACTION_UP = 2,
} Input_KeyEventAction;

/**
 * @brief Enumerated values of mouse event action.
 *
 * @since 12
 */
typedef enum {
    /** Cancel. */
    MOUSE_ACTION_CANCEL = 0,
    /** Moving of the mouse pointer. */
    MOUSE_ACTION_MOVE = 1,
    /** Pressing down of the mouse. */
    MOUSE_ACTION_BUTTON_DOWN = 2,
    /** Lifting of the mouse button. */
    MOUSE_ACTION_BUTTON_UP = 3,
    /** Beginning of the mouse axis event */
    MOUSE_ACTION_AXIS_BEGIN = 4,
    /** Updating of the mouse axis event */
    MOUSE_ACTION_AXIS_UPDATE = 5,
    /** End of the mouse axis event */
    MOUSE_ACTION_AXIS_END = 6,
} Input_MouseEventAction;

/**
 * @brief Mouse axis types.
 *
 * @since 12
 */
enum InputEvent_MouseAxis {
    /** Vertical scroll axis */
    MOUSE_AXIS_SCROLL_VERTICAL = 0,
    /** Horizontal scroll axis */
    MOUSE_AXIS_SCROLL_HORIZONTAL = 1,
};

/**
 * @brief Enumerated values of mouse event button.
 *
 * @since 12
 */
typedef enum {
    /** Invalid button */
    MOUSE_BUTTON_NONE = -1,
    /** Left button on the mouse. */
    MOUSE_BUTTON_LEFT = 0,
    /** Middle button on the mouse. */
    MOUSE_BUTTON_MIDDLE = 1,
    /** Right button on the mouse. */
    MOUSE_BUTTON_RIGHT = 2,
    /** Forward button on the mouse. */
    MOUSE_BUTTON_FORWARD = 3,
    /** Back button on the mouse. */
    MOUSE_BUTTON_BACK = 4,
} Input_MouseEventButton;

/**
 * @brief Enumerated values of touch event action.
 *
 * @since 12
 */
typedef enum {
    /** Touch cancelled. */
    TOUCH_ACTION_CANCEL = 0,
    /** Touch pressed. */
    TOUCH_ACTION_DOWN = 1,
    /** Touch moved. */
    TOUCH_ACTION_MOVE = 2,
    /** Touch lifted. */
    TOUCH_ACTION_UP = 3,
} Input_TouchEventAction;

/**
 * @brief Defines key information, which identifies a key pressing behavior. For example, the Ctrl key information contains the key value and key type.
 *
 * @since 12
 */
struct Input_KeyState;

/**
 * @brief The key event to be injected.
 *
 * @since 12
 */
struct Input_KeyEvent;

/**
 * @brief The mouse event to be injected.
 *
 * @since 12
 */
struct Input_MouseEvent;

/**
 * @brief The touch event to be injected.
 *
 * @since 12
 */
struct Input_TouchEvent;

/**
 * @brief Enumerates the error codes.
 *
 * @since 12
 */
typedef enum {
    /** @error Success return code on sucess*/
    INPUT_SUCCESS = 0,
    /** @error Permission verification failed */
    INPUT_PERMISSION_DENIED = 201,
    /** @error Non-system application */
    INPUT_NOT_SYSTEM_APPLICATION = 202,
    /** @error Parameter check failed */
    INPUT_PARAMETER_ERROR = 401
} Input_Result;

/**
 * @brief Queries the key state.
 *
 * @param keyState Key state.
 * @return OH_Input_GetKeyState function result code.
 *         {@link INPUT_SUCCESS} get KeyState sucess.\n
 *         {@link INPUT_PARAMETER_ERROR} keyCode is invalid.\n
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
Input_Result OH_Input_GetKeyState(struct Input_KeyState* keyState);

/**
 * @brief Creates a key status enumeration object.
 *
 * @return Returns an {@Input_KeyState} pointer object if the operation is successful.
 * Otherwise, a null pointer is returned. The possible cause is memory allocation failure.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
struct Input_KeyState* OH_Input_CreateKeyState();

/**
 * @brief Destroys a key status enumeration object.
 * 
 * @param keyState Key status enumeration object.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_DestroyKeyState(struct Input_KeyState** keyState);

/**
 * @brief Sets the key value of a key status enumeration object.
 * 
 * @param keyState Key status enumeration object.
 * @param keyCode Key value of the key status enumeration object.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetKeyCode(struct Input_KeyState* keyState, int32_t keyCode);

/**
 * @brief Obtains the key value of a key status enumeration object.
 * 
 * @param keyState Key status enumeration object.
 * @return Key value of the key status enumeration object.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetKeyCode(const struct Input_KeyState* keyState);

/**
 * @brief Sets whether the key specific to a key status enumeration object is pressed.
 * 
 * @param keyState Key status enumeration object.
 * @param keyAction Whether the key is pressed.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetKeyPressed(struct Input_KeyState* keyState, int32_t keyAction);

/**
 * @brief Checks whether the key specific to a key status enumeration object is pressed.
 * 
 * @param keyState Key status enumeration object.
 * @return Key pressing status of the key status enumeration object.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetKeyPressed(const struct Input_KeyState* keyState);

/**
 * @brief Sets the key switch of the key status enumeration object.
 * 
 * @param keyState Key status enumeration object.
 * @param keySwitch Key switch of the key status enumeration object.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetKeySwitch(struct Input_KeyState* keyState, int32_t keySwitch);

/**
 * @brief Obtains the key switch of the key status enumeration object.
 * 
 * @param keyState Key status enumeration object.
 * @return Key switch of the key status enumeration object.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetKeySwitch(const struct Input_KeyState* keyState);

/**
 * @brief Inject system keys.
 *
 * @param keyEvent - the key event to be injected.
 * @return OH_Input_InjectKeyEvent function result code.
 *         {@link INPUT_SUCCESS} inject keyEvent sucess.\n
 *         {@link INPUT_PERMISSION_DENIED} Permission verification failed.\n
 *         {@link INPUT_PARAMETER_ERROR} keyCode is less 0, can not process.\n
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_InjectKeyEvent(const struct Input_KeyEvent* keyEvent);

/**
 * @brief Creates a key event object.
 *
 * @return Returns an {@link Input_KeyEvent} pointer object if the operation is successful.
 * Otherwise, a null pointer is returned. The possible cause is memory allocation failure.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
struct Input_KeyEvent* OH_Input_CreateKeyEvent();

/**
 * @brief Destroys a key event object.
 *
 * @param keyEvent Key event object.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_DestroyKeyEvent(struct Input_KeyEvent** keyEvent);

/**
 * @brief Sets the key event type.
 *
 * @param keyEvent Key event object.
 * @param action Key event type.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetKeyEventAction(struct Input_KeyEvent* keyEvent, int32_t action);

/**
 * @brief Obtains the key event type.
 *
 * @param keyEvent Key event object.
 * @return Key event type.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetKeyEventAction(const struct Input_KeyEvent* keyEvent);

/**
 * @brief Sets the key value for a key event.
 *
 * @param keyEvent Key event object.
 * @param keyCode keyCode Key code.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetKeyEventKeyCode(struct Input_KeyEvent* keyEvent, int32_t keyCode);

/**
 * @brief Obtains the key value of a key event.
 *
 * @param keyEvent Key event object.
 * @return Key code.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetKeyEventKeyCode(const struct Input_KeyEvent* keyEvent);

/**
 * @brief Sets the time when a key event occurs.
 *
 * @param keyEvent Key event object.
 * @param actionTime Time when the key event occurs.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetKeyEventActionTime(struct Input_KeyEvent* keyEvent, int64_t actionTime);

/**
 * @brief Obtains the time when a key event occurs.
 *
 * @param keyEvent Key event object.
 * @return Returns the time when the key event occurs.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int64_t OH_Input_GetKeyEventActionTime(const struct Input_KeyEvent* keyEvent);

/**
 * @brief Inject mouse event.
 *
 * @param mouseEvent - the mouse event to be injected.
 * @return OH_Input_InjectMouseEvent function result code.
 *         {@link INPUT_SUCCESS} inject mouseEvent sucess.\n
 *         {@link INPUT_PERMISSION_DENIED} Permission verification failed.\n
 *         {@link INPUT_PARAMETER_ERROR} Parameter check failed.\n
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_InjectMouseEvent(const struct Input_MouseEvent* mouseEvent);

/**
 * @brief Creates a mouse event object.
 *
 * @return Returns an {@link Input_MouseEvent} pointer object if the operation is successful.
 * Otherwise, a null pointer is returned. The possible cause is memory allocation failure.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
struct Input_MouseEvent* OH_Input_CreateMouseEvent();

/**
 * @brief Destroys a mouse event object.
 *
 * @param mouseEvent Mouse event object.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_DestroyMouseEvent(struct Input_MouseEvent** mouseEvent);

/**
 * @brief Sets the action for a mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @param action Mouse action.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetMouseEventAction(struct Input_MouseEvent* mouseEvent, int32_t action);

/**
 * @brief Obtains the action of a mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @return Mouse action.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetMouseEventAction(const struct Input_MouseEvent* mouseEvent);

/**
 * @brief Sets the X coordinate for a mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @param displayX  X coordinate on the display.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetMouseEventDisplayX(struct Input_MouseEvent* mouseEvent, int32_t displayX);

/**
 * @brief Obtains the X coordinate of a mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @return X coordinate on the display.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetMouseEventDisplayX(const struct Input_MouseEvent* mouseEvent);

/**
 * @brief Sets the Y coordinate for a mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @param displayY Y coordinate on the display.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetMouseEventDisplayY(struct Input_MouseEvent* mouseEvent, int32_t displayY);

/**
 * @brief Obtains the Y coordinate of a mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @return Y coordinate on the display.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetMouseEventDisplayY(const struct Input_MouseEvent* mouseEvent);

/**
 * @brief Sets the button for a mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @param button Mouse button.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetMouseEventButton(struct Input_MouseEvent* mouseEvent, int32_t button);

/**
 * @brief Obtains the button of a mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @return Mouse button.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetMouseEventButton(const struct Input_MouseEvent* mouseEvent);

/**
 * @brief Sets the axis type for mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @param axisType Axis type, for example, X axis or Y axis.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetMouseEventAxisType(struct Input_MouseEvent* mouseEvent, int32_t axisType);

/**
 * @brief Obtains the axis type of a mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @return Axis type.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetMouseEventAxisType(const struct Input_MouseEvent* mouseEvent);

/**
 * @brief Sets the axis value for a mouse axis event.
 *
 * @param mouseEvent Mouse event object.
 * @param axisType Axis value. A positive value means scrolling forward, and a negative number means scrolling backward.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetMouseEventAxisValue(struct Input_MouseEvent* mouseEvent, float axisValue);

/**
 * @brief Obtains the axis value of a mouse event.
 *
 * @param mouseEvent Mouse event object.
 * @return Axis value.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
float OH_Input_GetMouseEventAxisValue(const struct Input_MouseEvent* mouseEvent);

/**
 * @brief Sets the time when a mouse event occurs.
 *
 * @param mouseEvent Mouse event object.
 * @param actionTime Time when the mouse event occurs.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetMouseEventActionTime(struct Input_MouseEvent* mouseEvent, int64_t actionTime);

/**
 * @brief Obtains the time when a mouse event occurs.
 *
 * @param keyEvent Mouse event object.
 * @return Returns the time when the mouse event occurs.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int64_t OH_Input_GetMouseEventActionTime(const struct Input_MouseEvent* mouseEvent);

/**
 * @brief Inject touch event.
 *
 * @param touchEvent - the touch event to be injected.
 * @return OH_Input_InjectTouchEvent function result code.
 *         {@link INPUT_SUCCESS} inject touchEvent sucess.\n
 *         {@link INPUT_PARAMETER_ERROR} Parameter check failed.\n
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_InjectTouchEvent(const struct Input_TouchEvent* touchEvent);

/**
 * @brief Creates a touch event object.
 *
 * @return Returns an {@link Input_TouchEvent} pointer object if the operation is successful.
 * Otherwise, a null pointer is returned. The possible cause is memory allocation failure.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
struct Input_TouchEvent* OH_Input_CreateTouchEvent();

/**
 * @brief Destroys a touch event object.
 *
 * @param touchEvent Touch event object.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_DestroyTouchEvent(struct Input_TouchEvent** touchEvent);

/**
 * @brief Sets the action for a touch event.
 *
 * @param touchEvent Touch event object.
 * @param action Touch action.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetTouchEventAction(struct Input_TouchEvent* touchEvent, int32_t action);

/**
 * @brief Obtains the action of a touch event.
 *
 * @param touchEvent Touch event object.
 * @return Touch action.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetTouchEventAction(const struct Input_TouchEvent* touchEvent);

/**
 * @brief Sets the finger ID for the touch event.
 *
 * @param touchEvent Touch event object.
 * @param id Finger ID.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetTouchEventFingerId(struct Input_TouchEvent* touchEvent, int32_t id);

/**
 * @brief Obtains the finger ID of a touch event.
 *
 * @param touchEvent Touch event object.
 * @return Finger ID.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetTouchEventFingerId(const struct Input_TouchEvent* touchEvent);

/**
 * @brief Sets the X coordinate for a touch event.
 *
 * @param touchEvent Touch event object.
 * @param displayX X coordinate.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetTouchEventDisplayX(struct Input_TouchEvent* touchEvent, int32_t displayX);

/**
 * @brief Obtains the X coordinate of a touch event.
 *
 * @param touchEvent Touch event object.
 * @return X coordinate.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetTouchEventDisplayX(const struct Input_TouchEvent* touchEvent);

/**
 * @brief Sets the Y coordinate for a touch event.
 *
 * @param touchEvent Touch event object.
 * @param displayY Y coordinate.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetTouchEventDisplayY(struct Input_TouchEvent* touchEvent, int32_t displayY);

/**
 * @brief Obtains the Y coordinate of a touch event.
 *
 * @param touchEvent Touch event object.
 * @return Y coordinate.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int32_t OH_Input_GetTouchEventDisplayY(const struct Input_TouchEvent* touchEvent);

/**
 * @brief Sets the time when a touch event occurs.
 *
 * @param keyEvent Touch event object.
 * @param actionTime Time when the touch event occurs.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_SetTouchEventActionTime(struct Input_TouchEvent* touchEvent, int64_t actionTime);

/**
 * @brief Obtains the time when a touch event occurs.
 *
 * @param keyEvent touch event object.
 * @return Returns the time when the touch event occurs.
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
int64_t OH_Input_GetTouchEventActionTime(const struct Input_TouchEvent* touchEvent);

/**
 * @brief Cancels event injection and revokes authorization.
 *
 * @syscap SystemCapability.MultimodalInput.Input.Core
 * @since 12
 */
void OH_Input_CancelInjection();

#ifdef __cplusplus
}
#endif
/** @} */

#endif /* OH_INPUT_MANAGER_H */