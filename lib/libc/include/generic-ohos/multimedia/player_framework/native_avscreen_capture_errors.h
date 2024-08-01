/*
 * Copyright (C) 2023 Huawei Device Co., Ltd.
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

#ifndef NATIVE_AVSCREEN_CAPTURE_ERRORS_H
#define NATIVE_AVSCREEN_CAPTURE_ERRORS_H

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Screen capture error code
 * @syscap SystemCapability.Multimedia.Media.AVScreenCapture
 * @since 10
 * @version 1.0
 */

typedef enum OH_AVSCREEN_CAPTURE_ErrCode {
    /**
     * @error basic error mask for screen recording.
     */
    AV_SCREEN_CAPTURE_ERR_BASE = 0,
    /**
     * @error the operation completed successfully.
     */
    AV_SCREEN_CAPTURE_ERR_OK = AV_SCREEN_CAPTURE_ERR_BASE,
    /**
     * @error no memory.
     */
    AV_SCREEN_CAPTURE_ERR_NO_MEMORY = AV_SCREEN_CAPTURE_ERR_BASE + 1,
    /**
     * @error opertation not be permitted.
     */
    AV_SCREEN_CAPTURE_ERR_OPERATE_NOT_PERMIT = AV_SCREEN_CAPTURE_ERR_BASE + 2,
    /**
     * @error invalid argument.
     */
    AV_SCREEN_CAPTURE_ERR_INVALID_VAL = AV_SCREEN_CAPTURE_ERR_BASE + 3,
    /**
     * @error IO error.
     */
    AV_SCREEN_CAPTURE_ERR_IO = AV_SCREEN_CAPTURE_ERR_BASE + 4,
    /**
     * @error network timeout.
     */
    AV_SCREEN_CAPTURE_ERR_TIMEOUT = AV_SCREEN_CAPTURE_ERR_BASE + 5,
    /**
     * @error unknown error.
     */
    AV_SCREEN_CAPTURE_ERR_UNKNOWN = AV_SCREEN_CAPTURE_ERR_BASE + 6,
    /**
     * @error media service died.
     */
    AV_SCREEN_CAPTURE_ERR_SERVICE_DIED = AV_SCREEN_CAPTURE_ERR_BASE + 7,
    /**
     * @error the state is not support this operation.
     */
    AV_SCREEN_CAPTURE_ERR_INVALID_STATE = AV_SCREEN_CAPTURE_ERR_BASE + 8,
    /**
     * @error unsupport interface.
     */
    AV_SCREEN_CAPTURE_ERR_UNSUPPORT = AV_SCREEN_CAPTURE_ERR_BASE + 9,
    /**
     * @error extend err start.
     */
    AV_SCREEN_CAPTURE_ERR_EXTEND_START = AV_SCREEN_CAPTURE_ERR_BASE + 100,
} OH_AVSCREEN_CAPTURE_ErrCode;

#ifdef __cplusplus
}
#endif

#endif // NATIVE_AVSCREEN_CAPTURE_ERRORS_H