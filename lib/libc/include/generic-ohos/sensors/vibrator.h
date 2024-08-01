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
 * @addtogroup Vibrator
 * @{
 *
 * @brief Provides APIs for vibrator services to access the vibrator driver.
 * @since 11
 */

/**
 * @file vibrator.h
 *
 * @brief Declares the APIs for starting or stopping vibration.
 * @library libohvibrator.z.so
 * @syscap SystemCapability.Sensors.MiscDevice
 * @since 11
 */

#ifndef VIBRATOR_H
#define VIBRATOR_H

#include "vibrator_type.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Controls the vibrator to vibrate continuously for a given duration.
 *
 * @param duration - Vibration duration, in milliseconds.
 * @param attribute - Vibration attribute. For details, see {@link Vibrator_Attribute}.
 * @return Returns <b>0</b> if the operation is successful; returns the following error code otherwise.
 * {@link PERMISSION_DENIED} Permission verification failed.\n
 * {@link PARAMETER_ERROR} Parameter check failed. For example, the parameter is invalid,
 * or the parameter type passed in is incorrect.\n
 * {@link UNSUPPORTED} The API is not supported on the device. The device supports the corresponding SysCap,
 * but does not support certain APIs in this SysCap.\n
 * {@link DEVICE_OPERATION_FAILED} The operation on the device failed.\n
 * @permission ohos.permission.VIBRATE
 *
 * @since 11
 */
int32_t OH_Vibrator_PlayVibration(int32_t duration, Vibrator_Attribute attribute);

/**
 * @brief Controls the vibrator to vibrate with the custom sequence.
 *
 * @param fileDescription - File descriptor of the custom vibration effect.
 * For details, see {@link Vibrator_FileDescription}.
 * @param vibrateAttribute - Vibration attribute. For details, see {@link Vibrator_Attribute}.
 * @return Returns <b>0</b> if the operation is successful; returns the following error code otherwise.
 * {@link PERMISSION_DENIED} Permission verification failed.\n
 * {@link PARAMETER_ERROR} Parameter check failed. For example, the parameter is invalid,
 * or the parameter type passed in is incorrect.\n
 * {@link UNSUPPORTED} The API is not supported on the device. The device supports the corresponding SysCap,
 * but does not support certain APIs in this SysCap.\n
 * {@link DEVICE_OPERATION_FAILED} The operation on the device failed.\n
 * @permission ohos.permission.VIBRATE
 *
 * @since 11
 */
int32_t OH_Vibrator_PlayVibrationCustom(Vibrator_FileDescription fileDescription,
    Vibrator_Attribute vibrateAttribute);

/**
 * @brief Stop the motor vibration according to the input mode.
 *
 * @permission ohos.permission.VIBRATE
 * @return Returns <b>0</b> if the operation is successful; returns the following error code otherwise.
 * {@link PERMISSION_DENIED} Permission verification failed.\n
 * {@link UNSUPPORTED} The API is not supported on the device. The device supports the corresponding SysCap,
 * but does not support certain APIs in this SysCap.\n
 * {@link DEVICE_OPERATION_FAILED} The operation on the device failed.\n
 * @permission ohos.permission.VIBRATE
 *
 * @since 11
 */
int32_t OH_Vibrator_Cancel();
#ifdef __cplusplus
}
#endif
/** @} */
#endif // endif VIBRATOR_H