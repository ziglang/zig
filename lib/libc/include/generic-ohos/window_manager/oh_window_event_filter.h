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
#ifndef INCLUDE_OH_WINDOW_EVENT_FILTER_H
#define INCLUDE_OH_WINDOW_EVENT_FILTER_H


/**
 * @addtogroup WindowManager_NativeModule
 * @{
 *
 *
 * @brief Provides  abilities of windowManager on the native side, such as key event
 * filtration.
 *
 * @since 12
 */

/**
 * @file oh_window_event_filter.h
 *
 * @brief Declares APIs for window event filter
 *
 * @syscap SystemCapability.Window.SessionManager
 * @library libnative_window_manager.so
 * @since 12
 */
#include "stdint.h"
#include "oh_window_comm.h"
#include "multimodalinput/oh_input_manager.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief the callback funcation type when keyEvent was filter
 * @param keyEvent multimodal keyEvent
 * @since 12
 */
typedef bool (*OH_NativeWindowManager_KeyEventFilter)(Input_KeyEvent* keyEvent);

/**
 * @brief Registers a  filter callback for the window ,the callback is called when the
 * window is dispatched to the event
 *
 * @param windowId windowId when window is created
 * @param keyEventFilter key event callback ,called when the window is dispatched
 * to the event
 * @return Returns the status code of the execution.
 * @since 12
 */
WindowManager_ErrorCode OH_NativeWindowManager_RegisterKeyEventFilter(int32_t windowId,
    OH_NativeWindowManager_KeyEventFilter keyEventFilter);

/**
 * @brief clear callback for the window
 *
 * @param windowId windowId when window is created
 * @return Returns the status code of the execution.
 * @since 12
 */
WindowManager_ErrorCode OH_NativeWindowManager_UnregisterKeyEventFilter(int32_t windowId);

#ifdef __cplusplus
}
#endif

#endif // INCLUDE_OH_WINDOW_EVENT_FILTER_H