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
 * @brief Provides APIs to define common sensor attributes.
 *
 * @since 11
 */

/**
 * @file oh_sensor_type.h
 *
 * @brief Declares the common sensor attributes.
 * @library libohsensor.so
 * @syscap SystemCapability.Sensors.Sensor
 * @since 11
 */

#ifndef OH_SENSOR_TYPE_H
#define OH_SENSOR_TYPE_H

#include <cstdint>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerates the sensor types.
 *
 * @since 11
 */
typedef enum Sensor_Type {
    /**
     * Acceleration sensor.
     * @since 11
     */
    SENSOR_TYPE_ACCELEROMETER = 1,
    /**
     * Gyroscope sensor.
     * @since 11
     */
    SENSOR_TYPE_GYROSCOPE = 2,
    /**
     * Ambient light sensor.
     * @since 11
     */
    SENSOR_TYPE_AMBIENT_LIGHT = 5,
    /**
     * Magnetic field sensor.
     * @since 11
     */
    SENSOR_TYPE_MAGNETIC_FIELD = 6,
    /**
     * Barometer sensor.
     * @since 11
     */
    SENSOR_TYPE_BAROMETER = 8,
    /**
     * Hall effect sensor.
     * @since 11
     */
    SENSOR_TYPE_HALL = 10,
    /**
     * Proximity sensor.
     * @since 11
     */
    SENSOR_TYPE_PROXIMITY = 12,
    /**
     * Orientation sensor.
     * @since 11
     */
    SENSOR_TYPE_ORIENTATION = 256,
    /**
     * Gravity sensor.
     * @since 11
     */
    SENSOR_TYPE_GRAVITY = 257,
    /**
     * Rotation vector sensor.
     * @since 11
     */
    SENSOR_TYPE_ROTATION_VECTOR = 259,
    /**
     * Pedometer detection sensor.
     * @since 11
     */
    SENSOR_TYPE_PEDOMETER_DETECTION = 265,
    /**
     * Pedometer sensor.
     * @since 11
     */
    SENSOR_TYPE_PEDOMETER = 266,
    /**
     * Heart rate sensor.
     * @since 11
     */
    SENSOR_TYPE_HEART_RATE = 278,
} Sensor_Type;

/**
 * @brief Enumerates the sensor result codes.
 *
 * @since 11
 */
typedef enum Sensor_Result {
    /**
     * @error The operation is successful.
     * @since 11
     */
    SENSOR_SUCCESS = 0,
    /**
     * @error Permission verification failed.
     * @since 11
     */
    SENSOR_PERMISSION_DENIED = 201,
    /**
     * @error Parameter check failed. For example, a mandatory parameter is not passed in,
     * or the parameter type passed in is incorrect.
     * @since 11
     */
    SENSOR_PARAMETER_ERROR = 401,
    /**
     * @error The sensor service is abnormal.
     * @since 11
     */
    SENSOR_SERVICE_EXCEPTION = 14500101,
} Sensor_Result;

/**
 * @brief Enumerates the accuracy levels of data reported by a sensor.
 *
 * @since 11
 */
typedef enum Sensor_Accuracy {
    /**
     * The sensor data is unreliable. It is possible that the sensor does not contact with the device to measure.
     * @since 11
     */
    SENSOR_ACCURACY_UNRELIABLE = 0,
    /**
     * The sensor data is at a low accuracy level. The data must be calibrated based on
     * the environment before being used.
     * @since 11
     */
    SENSOR_ACCURACY_LOW = 1,
    /**
     * The sensor data is at a medium accuracy level. You are advised to calibrate the data
     * based on the environment before using it.
     * @since 11
     */
    SENSOR_ACCURACY_MEDIUM = 2,
    /**
     * The sensor data is at a high accuracy level. The data can be used directly.
     * @since 11
     */
    SENSOR_ACCURACY_HIGH = 3
} Sensor_Accuracy;

/**
 * @brief Defines the sensor information.
 * @since 11
 */
typedef struct Sensor_Info Sensor_Info;

/**
 * @brief Creates an array of {@link Sensor_Info} instances with the given number.
 *
 * @param count - Number of {@link Sensor_Info} instances to create.
 * @return Returns the double pointer to the array of {@link Sensor_Info} instances
 * if the operation is successful;
 * returns <b>NULL</b> otherwise.
 * @since 11
 */
Sensor_Info **OH_Sensor_CreateInfos(uint32_t count);

/**
 * @brief Destroys an array of {@link Sensor_Info} instances and reclaims memory.
 *
 * @param sensors - Double pointer to the array of {@link Sensor_Info} instances.
 * @param count - Number of {@link Sensor_Info} instances to destroy.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_Sensor_DestroyInfos(Sensor_Info **sensors, uint32_t count);

/**
 * @brief Obtains the sensor name.
 *
 * @param sensor - Pointer to the sensor information.
 * @param sensorName - Pointer to the sensor name.
 * @param length - Pointer to the length, in bytes.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorInfo_GetName(Sensor_Info* sensor, char *sensorName, uint32_t *length);

/**
 * @brief Obtains the sensor's vendor name.
 *
 * @param sensor - Pointer to the sensor information.
 * @param vendorName - Pointer to the vendor name.
 * @param length - Pointer to the length, in bytes.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorInfo_GetVendorName(Sensor_Info* sensor, char *vendorName, uint32_t *length);

/**
 * @brief Obtains the sensor type.
 *
 * @param sensor - Pointer to the sensor information.
 * @param sensorType - Pointer to the sensor type.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorInfo_GetType(Sensor_Info* sensor, Sensor_Type *sensorType);

/**
 * @brief Obtains the sensor resolution.
 *
 * @param sensor - Pointer to the sensor information.
 * @param resolution - Pointer to the sensor resolution.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorInfo_GetResolution(Sensor_Info* sensor, float *resolution);

/**
 * @brief Obtains the minimum data reporting interval of a sensor.
 *
 * @param sensor - Pointer to the sensor information.
 * @param minSamplingInterval - Pointer to the minimum data reporting interval, in nanoseconds.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorInfo_GetMinSamplingInterval(Sensor_Info* sensor, int64_t *minSamplingInterval);

/**
 * @brief Obtains the maximum data reporting interval of a sensor.
 *
 * @param sensor - Pointer to the sensor information.
 * @param maxSamplingInterval - Pointer to the maximum data reporting interval, in nanoseconds.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorInfo_GetMaxSamplingInterval(Sensor_Info* sensor, int64_t *maxSamplingInterval);

/**
 * @brief Defines the sensor data information.
 * @since 11
 */
typedef struct Sensor_Event Sensor_Event;

/**
 * @brief Obtains the sensor type.
 *
 * @param sensorEvent - Pointer to the sensor data information.
 * @param sensorType - Pointer to the sensor type.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorEvent_GetType(Sensor_Event* sensorEvent, Sensor_Type *sensorType);

/**
 * @brief Obtains the timestamp of sensor data.
 *
 * @param sensorEvent - Pointer to the sensor data information.
 * @param timestamp - Pointer to the timestamp.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorEvent_GetTimestamp(Sensor_Event* sensorEvent, int64_t *timestamp);

/**
 * @brief Obtains the accuracy of sensor data.
 *
 * @param sensorEvent - Pointer to the sensor data information.
 * @param accuracy - Pointer to the accuracy.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorEvent_GetAccuracy(Sensor_Event* sensorEvent, Sensor_Accuracy *accuracy);

/**
 * @brief Obtains sensor data. The data length and content depend on the sensor type.
 * The format of the sensor data reported is as follows:
 * SENSOR_TYPE_ACCELEROMETER: data[0], data[1], and data[2], indicating the acceleration around
 * the x, y, and z axes of the device, respectively, in m/s2.
 * SENSOR_TYPE_GYROSCOPE: data[0], data[1], and data[2], indicating the angular velocity of rotation around
 *  the x, y, and z axes of the device, respectively, in rad/s.
 * SENSOR_TYPE_AMBIENT_LIGHT: data[0], indicating the ambient light intensity, in lux. Since api version 12,
 * two additional data will be returned, where data[1] indicating the color temperature, in kelvin; data[2]
 * indicating the infrared luminance, in cd/m2.
 * SENSOR_TYPE_MAGNETIC_FIELD: data[0], data[1], and data[2], indicating the magnetic field strength around
 * the x, y, and z axes of the device, respectively, in μT.
 * SENSOR_TYPE_BAROMETER: data[0], indicating the atmospheric pressure, in hPa.
 * SENSOR_TYPE_HALL: data[0], indicating the opening/closing state of the flip cover. The value <b>0</b> means that
 * the flip cover is opened, and a value greater than <b>0</b> means that the flip cover is closed.
 * SENSOR_TYPE_PROXIMITY: data[0], indicates the approaching state. The value <b>0</b> means the two objects are close
 * to each other, and a value greater than <b>0</b> means that they are far away from each other.
 * SENSOR_TYPE_ORIENTATION: data[0], data[1], and data[2], indicating the rotation angles of a device around
 * the z, x, and y axes, respectively, in degree.
 * SENSOR_TYPE_GRAVITY: data[0], data[1], and data[2], indicating the gravitational acceleration around
 * the x, y, and z axes of a device, respectively, in m/s2.
 * SENSOR_TYPE_ROTATION_VECTOR: data[0], data[1] and data[2], indicating the rotation angles of a device around
 * the x, y, and z axes, respectively, in degree. data[3] indicates the rotation vector.
 * SENSOR_TYPE_PEDOMETER_DETECTION: data[0], indicating the pedometer detection status.
 * The value <b>1</b> means that the number of detected steps changes.
 * SENSOR_TYPE_PEDOMETER: data[0], indicating the number of steps a user has walked.
 * SENSOR_TYPE_HEART_RATE: data[0], indicating the heart rate value.
 *
 * @param sensorEvent - Pointer to the sensor data information.
 * @param data - Double pointer to the sensor data.
 * @param length - Pointer to the array length.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorEvent_GetData(Sensor_Event* sensorEvent, float **data, uint32_t *length);

/**
 * @brief Defines the sensor subscription ID, which uniquely identifies a sensor.
 * @since 11
 */
typedef struct Sensor_SubscriptionId Sensor_SubscriptionId;

/**
 * @brief Creates a {@link Sensor_SubscriptionId} instance.
 *
 * @return Returns the pointer to the {@link Sensor_SubscriptionId} instance if the operation is successful;
 * returns <b>NULL</b> otherwise.
 * @since 11
 */
Sensor_SubscriptionId *OH_Sensor_CreateSubscriptionId(void);

/**
 * @brief Destroys a {@link Sensor_SubscriptionId} instance and reclaims memory.
 *
 * @param id - Pointer to the {@link Sensor_SubscriptionId} instance.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_Sensor_DestroySubscriptionId(Sensor_SubscriptionId *id);

/**
 * @brief Obtains the sensor type.
 *
 * @param id - Pointer to the sensor subscription ID.
 * @param sensorType - Pointer to the sensor type.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorSubscriptionId_GetType(Sensor_SubscriptionId* id, Sensor_Type *sensorType);

/**
 * @brief Sets the sensor type.
 *
 * @param id - Pointer to the sensor subscription ID.
 * @param sensorType - Sensor type to set.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorSubscriptionId_SetType(Sensor_SubscriptionId* id, const Sensor_Type sensorType);

/**
 * @brief Defines the sensor subscription attribute.
 * @since 11
 */
typedef struct Sensor_SubscriptionAttribute Sensor_SubscriptionAttribute;

/**
 * @brief Creates a {@link Sensor_SubscriptionAttribute} instance.
 *
 * @return Returns the pointer to the {@link Sensor_SubscriptionAttribute} instance if the operation is successful;
 * returns <b>NULL</b> otherwise.
 * @since 11
 */
Sensor_SubscriptionAttribute *OH_Sensor_CreateSubscriptionAttribute(void);

/**
 * @brief Destroys a {@link Sensor_SubscriptionAttribute} instance and reclaims memory.
 *
 * @param attribute - Pointer to the {@link Sensor_SubscriptionAttribute} instance.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_Sensor_DestroySubscriptionAttribute(Sensor_SubscriptionAttribute *attribute);

/**
 * @brief Sets the sensor data reporting interval.
 *
 * @param attribute - Pointer to the sensor subscription attribute.
 * @param samplingInterval - Data reporting interval to set, in nanoseconds.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorSubscriptionAttribute_SetSamplingInterval(Sensor_SubscriptionAttribute* attribute,
    const int64_t samplingInterval);

/**
 * @brief Obtains the sensor data reporting interval.
 *
 * @param attribute - Pointer to the sensor subscription attribute.
 * @param samplingInterval - Pointer to the data reporting interval, in nanoseconds.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorSubscriptionAttribute_GetSamplingInterval(Sensor_SubscriptionAttribute* attribute,
    int64_t *samplingInterval);

/**
 * @brief Defines the callback function used to report sensor data.
 * @since 11
 */
typedef void (*Sensor_EventCallback)(Sensor_Event *event);

/**
 * @brief Defines the sensor subscriber information.
 * @since 11
 */
typedef struct Sensor_Subscriber Sensor_Subscriber;

/**
 * @brief Creates a {@link Sensor_Subscriber} instance.
 *
 * @return Returns the pointer to the {@link Sensor_Subscriber} instance
 * if the operation is successful; returns <b>NULL</b> otherwise.
 * @since 11
 */
Sensor_Subscriber *OH_Sensor_CreateSubscriber(void);

/**
 * @brief Destroys a {@link Sensor_Subscriber} instance and reclaims memory.
 *
 * @param subscriber - Pointer to the {@link Sensor_Subscriber} instance.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_Sensor_DestroySubscriber(Sensor_Subscriber *subscriber);

/**
 * @brief Sets a callback function to report sensor data.
 *
 * @param subscriber - Pointer to the sensor subscriber information.
 * @param callback - Callback function to set.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorSubscriber_SetCallback(Sensor_Subscriber* subscriber, const Sensor_EventCallback callback);

/**
 * @brief Obtains the callback function used to report sensor data.
 *
 * @param subscriber - Pointer to the sensor subscriber information.
 * @param callback - Pointer to the callback function.
 * @return Returns <b>SENSOR_SUCCESS</b> if the operation is successful;
 * returns an error code defined in {@link Sensor_Result} otherwise.
 * @since 11
 */
int32_t OH_SensorSubscriber_GetCallback(Sensor_Subscriber* subscriber, Sensor_EventCallback *callback);
#ifdef __cplusplus
}
#endif
/** @} */
#endif // OH_SENSOR_TYPE_H