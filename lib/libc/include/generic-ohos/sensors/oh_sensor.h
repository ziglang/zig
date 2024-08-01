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
 * @addtogroup Sensor
 * @{
 *
 * @brief Provides APIs to use common sensor features. For example, you can call the APIs to obtain sensor information
 * and subscribe to or unsubscribe from sensor data.
 * @since 11
 */
/**
 * @file oh_sensor.h
 *
 * @brief Declares the APIs for operating sensors, including obtaining sensor information and subscribing to or
 * unsubscribing from sensor data.
 * @library libohsensor.so
 * @syscap SystemCapability.Sensors.Sensor
 * @since 11
 */

#ifndef OH_SENSOR_H
#define OH_SENSOR_H

#include "oh_sensor_type.h"

#ifdef __cplusplus
extern "C" {
#endif
/**
 * @brief Obtains information about all sensors on the device.
 *
 * @param infos - Double pointer to the information about all sensors on the device.
 * For details, see {@link Sensor_Info}.
 * @param count - Pointer to the number of sensors on the device.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful; returns the following error code otherwise.
 * {@link SENSOR_PARAMETER_ERROR} Parameter check failed. For example, the parameter is invalid,
 * or the parameter type passed in is incorrect.\n
 * {@link SENSOR_SERVICE_EXCEPTION} The sensor service is abnormal.\n
 *
 * @since 11
 */
Sensor_Result OH_Sensor_GetInfos(Sensor_Info **infos, uint32_t *count);

/**
 * @brief Subscribes to sensor data. The system will report sensor data to the subscriber at the specified frequency.
 * If you need to apply for the ohos.permission.ACCELEROMETER permission when subscribing to the accelerometer sensor,
 * you need to apply for the ohos.permission.GYROSCOPE permission when subscribing to the gyroscope sensor, and you need
 * to apply for the ohos.permission.ACTIVITY_MOTION permission when subscribing to the pedometer related sensor. Apply
 * for ohos.permission.READ_HEALTH_DATA permission when subscribing to health-related sensors, such as heart rate
 * sensors, otherwise the subscription fails. Other sensors do not require permissions.
 *
 * @param id - Pointer to the sensor subscription ID. For details, see {@link Sensor_SubscriptionId}.
 * @param attribute - Pointer to the subscription attribute, which is used to specify the data reporting frequency.
 * For details, see {@link Sensor_SubscriptionAttribute}.
 * @param subscriber - Pointer to the subscriber information, which is used to specify the callback function for
 * reporting the sensor data. For details, see {@link Sensor_Subscriber}.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful; returns the following error code otherwise.
 * {@link SENSOR_PERMISSION_DENIED} Permission verification failed.\n
 * {@link SENSOR_PARAMETER_ERROR} Parameter check failed. For example, the parameter is invalid,
 * or the parameter type passed in is incorrect.\n
 * {@link SENSOR_SERVICE_EXCEPTION} The sensor service is abnormal.\n
 * @permission ohos.permission.ACCELEROMETER or ohos.permission.GYROSCOPE or
 *             ohos.permission.ACTIVITY_MOTION or ohos.permission.READ_HEALTH_DATA
 * @since 11
 */
Sensor_Result OH_Sensor_Subscribe(const Sensor_SubscriptionId *id,
    const Sensor_SubscriptionAttribute *attribute, const Sensor_Subscriber *subscriber);

/**
 * @brief Unsubscribes from sensor data.
 * If you need to apply for the ohos.permission.ACCELEROMETER permission to unsubscribe from the accelerometer sensor,
 * you need to request the ohos.permission.GYROSCOPE permission to unsubscribe from the gyroscope sensor, and you need
 * to request the ohos.permission.ACTIVITY_MOTION permission to unsubscribe from the pedometer-related sensor. When you
 * unsubscribe from health-related sensors, such as heart rate sensors, apply for ohos.permission.READ_HEALTH_DATA
 * permissions, otherwise the subscription will fail. Other sensors do not require permissions.
 *
 * @param id - Pointer to the sensor subscription ID. For details, see {@link Sensor_SubscriptionId}.
 * @param subscriber - Pointer to the subscriber information, which is used to specify the callback function for
 * reporting the sensor data. For details, see {@link Sensor_Subscriber}.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful; returns the following error code otherwise.
 * {@link SENSOR_PERMISSION_DENIED} Permission verification failed.\n
 * {@link SENSOR_PARAMETER_ERROR} Parameter check failed. For example, the parameter is invalid,
 * or the parameter type passed in is incorrect.\n
 * {@link SENSOR_SERVICE_EXCEPTION} The sensor service is abnormal.\n
 * @permission ohos.permission.ACCELEROMETER or ohos.permission.GYROSCOPE or
 *             ohos.permission.ACTIVITY_MOTION or ohos.permission.READ_HEALTH_DATA
 *
 * @since 11
 */
Sensor_Result OH_Sensor_Unsubscribe(const Sensor_SubscriptionId *id, const Sensor_Subscriber *subscriber);
#ifdef __cplusplus
}
#endif
/** @} */
#endif // OH_SENSOR_H