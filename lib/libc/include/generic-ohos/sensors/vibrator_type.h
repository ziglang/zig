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

#ifndef VIBRATOR_TYPE_H
#define VIBRATOR_TYPE_H

#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

/**
* @brief Defines an enum that enumerates the error codes.
*
* @since 11
*/
typedef enum Vibrator_ErrorCode : int32_t {
    /**< @error Permission verification failed. */
    PERMISSION_DENIED = 201,
    /**< @error Parameter check failed. For example, a mandatory parameter is not passed in,
     * or the parameter type passed in is incorrect. */
    PARAMETER_ERROR = 401,
    /**< @error The API is not supported on the device. The device supports the corresponding SysCap,
     * but does not support certain APIs in this SysCap. */
    UNSUPPORTED = 801,
    /**< @error The operation on the device failed. */
    DEVICE_OPERATION_FAILED = 14600101,
} Vibrator_ErrorCode;

/**
 * @brief Enumerates vibration usages scenarios.
 *
 * @since 11
 */
typedef enum Vibrator_Usage {
    VIBRATOR_USAGE_UNKNOWN = 0,            /**< Vibration is used for unknown, lowest priority */
    VIBRATOR_USAGE_ALARM = 1,              /**< Vibration is used for alarm */
    VIBRATOR_USAGE_RING = 2,               /**< Vibration is used for ring */
    VIBRATOR_USAGE_NOTIFICATION = 3,       /**< Vibration is used for notification */
    VIBRATOR_USAGE_COMMUNICATION = 4,      /**< Vibration is used for communication */
    VIBRATOR_USAGE_TOUCH = 5,              /**< Vibration is used for touch */
    VIBRATOR_USAGE_MEDIA = 6,              /**< Vibration is used for media */
    VIBRATOR_USAGE_PHYSICAL_FEEDBACK = 7,  /**< Vibration is used for physical feedback */
    VIBRATOR_USAGE_SIMULATED_REALITY = 8,   /**< Vibration is used for simulate reality */
    VIBRATOR_USAGE_MAX
} Vibrator_Usage;

/**
 * @brief Defines the vibrator attribute.
 *
 * @since 11
 */
typedef struct Vibrator_Attribute {
    /**< Vibrator ID. */
    int32_t vibratorId;
    /**< Vibration scenario. */
    Vibrator_Usage usage;
} Vibrator_Attribute;

/**
 * @brief Defines the vibration file description.
 *
 * @since 11
 */
typedef struct Vibrator_FileDescription {
    /**< File handle of the custom vibration sequence. */
    int32_t fd;
    /**< Offset address of the custom vibration sequence. */
    int64_t offset;
    /**< Total length of the custom vibration sequence. */
    int64_t length;
} Vibrator_FileDescription;
#ifdef __cplusplus
}
#endif

#endif  // endif VIBRATOR_TYPE_H