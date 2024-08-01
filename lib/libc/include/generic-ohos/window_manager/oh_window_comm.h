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
 * @file oh_window_comm.h
 *
 * @brief Provides the comm type definitions of windowManager on the native side.
 *
 * @syscap SystemCapability.Window.SessionManager
 * @library libnative_window_manager.so
 * @since 12
 */
#ifndef OH_WINDOW_COMM_H
#define OH_WINDOW_COMM_H

#include "stdint.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerates the result types of the wm interface
 *
 * @since 12
 */
typedef enum {
    /** succ. */
    OK = 0,
    /** window id is invaild. */
    INVAILD_WINDOW_ID = 1000,
    /** failed. */
    SERVICE_ERROR = 2000,
} WindowManager_ErrorCode;

#ifdef __cplusplus
}
#endif

#endif // OH_WINDOW_COMM_H
/** @} */