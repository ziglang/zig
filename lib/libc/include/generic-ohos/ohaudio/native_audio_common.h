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
 * @addtogroup OHAudio
 * @{
 *
 * @brief Provide the definition of the C interface for the audio module.
 *
 * @syscap SystemCapability.Multimedia.Audio.Core
 *
 * @since 12
 * @version 1.0
 */

/**
 * @file native_audio_common.h
 *
 * @brief Declare the audio common base data structure.
 *
 * Defines the types of public return values for audio interfaces.
 *
 * @library libohaudio.so
 * @syscap SystemCapability.Multimedia.Audio.Core
 * @since 12
 * @version 1.0
 */

#ifndef NATIVE_AUDIO_COMMON_H
#define NATIVE_AUDIO_COMMON_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Define the result of the function execution.
 *
 * @since 12
 */
typedef enum {
    /**
     * @error The call was successful.
     */
    AUDIOCOMMON_RESULT_SUCCESS = 0,

    /**
     * @error This means that the input parameter is invalid.
     */
    AUDIOCOMMON_RESULT_ERROR_INVALID_PARAM = 6800101,

    /**
     * @error This means there is no memory left.
     */
    AUDIOCOMMON_RESULT_ERROR_NO_MEMORY = 6800102,

    /**
     * @error Execution status exception.
     */
    AUDIOCOMMON_RESULT_ERROR_ILLEGAL_STATE = 6800103,

    /**
     * @error This means the operation is unsupported.
     */
    AUDIOCOMMON_RESULT_ERROR_UNSUPPORTED = 6800104,

    /**
     * @error This means the operation is timeout.
     */
    AUDIOCOMMON_RESULT_ERROR_TIMEOUT = 6800105,

    /**
     * @error This means reached stream limit.
     */
    AUDIOCOMMON_RESULT_ERROR_STREAM_LIMIT = 6800201,

    /**
     * @error An system error has occurred.
     */
    AUDIOCOMMON_RESULT_ERROR_SYSTEM = 6800301,
} OH_AudioCommon_Result;

#ifdef __cplusplus
}
#endif
/** @} */
#endif // NATIVE_AUDIO_COMMON_H