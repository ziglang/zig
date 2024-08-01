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

#ifndef INCLUDE_GRAPHIC_ERROR_CODE_H
#define INCLUDE_GRAPHIC_ERROR_CODE_H

/**
 * @addtogroup NativeWindow
 * @{
 *
 * @brief Provides the error codes for native window.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @since 12
 * @version 1.0
 */

/**
 * @file external_window.h
 *
 * @brief Defines the error codes.
 * @syscap SystemCapability.Graphic.Graphic2D.NativeWindow
 * @library libnative_window.so
 * @since 12
 * @version 1.0
 */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief interface error code.
 * @since 12
 */
typedef enum OHNativeErrorCode {
    /** @error succeed */
    NATIVE_ERROR_OK = 0,
    /** @error input invalid parameter */
    NATIVE_ERROR_INVALID_ARGUMENTS = 40001000,
    /** @error unauthorized operation */
    NATIVE_ERROR_NO_PERMISSION = 40301000,
    /** @error no idle buffer is available */
    NATIVE_ERROR_NO_BUFFER = 40601000,
    /** @error the consumer side doesn't exist */
    NATIVE_ERROR_NO_CONSUMER = 41202000,
    /** @error uninitialized */
    NATIVE_ERROR_NOT_INIT = 41203000,
    /** @error the consumer is connected */
    NATIVE_ERROR_CONSUMER_CONNECTED = 41206000,
    /** @error the buffer status did not meet expectations */
    NATIVE_ERROR_BUFFER_STATE_INVALID = 41207000,
    /** @error buffer is already in the cache queue */
    NATIVE_ERROR_BUFFER_IN_CACHE = 41208000,
    /** @error the buffer queue is full */
    NATIVE_ERROR_BUFFER_QUEUE_FULL = 41209000,
    /** @error buffer is not in the cache queue */
    NATIVE_ERROR_BUFFER_NOT_IN_CACHE = 41210000,
    /** @error the current device or platform does not support it */
    NATIVE_ERROR_UNSUPPORTED = 50102000,
    /** @error unknown error, please check log */
    NATIVE_ERROR_UNKNOWN = 50002000,
    /** @error the egl environment is abnormal */
    NATIVE_ERROR_EGL_STATE_UNKNOWN = 60001000,
    /** @error egl interface invocation failed */
    NATIVE_ERROR_EGL_API_FAILED = 60002000,
} OHNativeErrorCode;

#ifdef __cplusplus
}
#endif

/** @} */
#endif // INCLUDE_GRAPHIC_ERROR_CODE_H