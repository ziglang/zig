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

#ifndef NATIVE_AVFORMAT_H
#define NATIVE_AVFORMAT_H

#include <stdint.h>
#include <stdbool.h>
#include <stdio.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OH_AVFormat OH_AVFormat;

/**
 * @brief Enumerates AVPixel Format.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @since 9
 * @version 1.0
 */
typedef enum OH_AVPixelFormat {
    /**
     * yuv 420 planar.
     */
    AV_PIXEL_FORMAT_YUVI420 = 1,
    /**
     *  NV12. yuv 420 semiplanar.
     */
    AV_PIXEL_FORMAT_NV12 = 2,
    /**
     *  NV21. yvu 420 semiplanar.
     */
    AV_PIXEL_FORMAT_NV21 = 3,
    /**
     * format from surface.
     */
    AV_PIXEL_FORMAT_SURFACE_FORMAT = 4,
    /**
     * RGBA8888
     */
    AV_PIXEL_FORMAT_RGBA = 5,
} OH_AVPixelFormat;

/**
 * @briefCreate an OH_AVFormat handle pointer to read and write data
 * @syscap SystemCapability.Multimedia.Media.Core
 * @return Returns a pointer to an OH_AVFormat instance
 * @since 9
 * @version 1.0
 */
struct OH_AVFormat *OH_AVFormat_Create(void);

/**
 * @briefCreate an audio OH_AVFormat handle pointer to read and write data
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param mimeType mime type
 * @param sampleRate sample rate
 * @param channelCount channel count
 * @return Returns a pointer to an OH_AVFormat instance if the execution is successful, otherwise nullptr
 * Possible failure causes: 1. mimeType is nullptr. 2. new format is nullptr.
 * @since 10
 * @version 1.0
 */
struct OH_AVFormat *OH_AVFormat_CreateAudioFormat(const char *mimeType,
                                                  int32_t sampleRate,
                                                  int32_t channelCount);

/**
 * @briefCreate an video OH_AVFormat handle pointer to read and write data
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param mimeType mime type
 * @param width width
 * @param height height
 * @return Returns a pointer to an OH_AVFormat instance if the execution is successful, otherwise nullptr
 * Possible failure causes: 1. mimeType is nullptr. 2. new format is nullptr.
 * @since 10
 * @version 1.0
 */
struct OH_AVFormat *OH_AVFormat_CreateVideoFormat(const char *mimeType,
                                                  int32_t width,
                                                  int32_t height);

/**
 * @brief Destroy the specified OH_AVFormat handle resource
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @return void
 * @since 9
 * @version 1.0
 */
void OH_AVFormat_Destroy(struct OH_AVFormat *format);

/**
 * @brief Copy OH_AVFormat handle resource
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param to OH_AVFormat handle pointer to receive data
 * @param from pointer to the OH_AVFormat handle of the copied data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_Copy(struct OH_AVFormat *to, struct OH_AVFormat *from);

/**
 * @brief Write Int data to OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key key to write data
 * @param value written data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_SetIntValue(struct OH_AVFormat *format, const char *key, int32_t value);

/**
 * @brief Write Long data to OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key key to write data
 * @param value written data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_SetLongValue(struct OH_AVFormat *format, const char *key, int64_t value);

/**
 * @brief Write Float data to OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key key to write data
 * @param value written data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_SetFloatValue(struct OH_AVFormat *format, const char *key, float value);

/**
 * @brief Write Double data to OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key key to write data
 * @param value written data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_SetDoubleValue(struct OH_AVFormat *format, const char *key, double value);

/**
 * @brief Write String data to OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key key to write data
 * @param value written data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * 4. value is nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_SetStringValue(struct OH_AVFormat *format, const char *key, const char *value);

/**
 * @brief Write a block of data of a specified length to OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key key to write data
 * @param addr written data addr
 * @param size written data length
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * 4. addr is nullptr. 5. size is zero.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_SetBuffer(struct OH_AVFormat *format, const char *key, const uint8_t *addr, size_t size);

/**
 * @brief Read Int data from OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key read key value
 * @param out read data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * 4. out is nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_GetIntValue(struct OH_AVFormat *format, const char *key, int32_t *out);

/**
 * @brief Read Long data from OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key read key value
 * @param out read data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * 4. out is nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_GetLongValue(struct OH_AVFormat *format, const char *key, int64_t *out);

/**
 * @brief Read Float data from OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key read key value
 * @param out read data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * 4. out is nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_GetFloatValue(struct OH_AVFormat *format, const char *key, float *out);

/**
 * @brief Read Double data from OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key read key value
 * @param out read data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * 4. out is nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_GetDoubleValue(struct OH_AVFormat *format, const char *key, double *out);

/**
 * @brief Read String data from OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key read key value
 * @param out The read string pointer, the data life cycle pointed to is updated with GetString,
 * and Format is destroyed. If the caller needs to hold it for a long time, it must copy the memory
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * 4. out is nullptr. 5. malloc out string nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_GetStringValue(struct OH_AVFormat *format, const char *key, const char **out);

/**
 * @brief Read a block of data of specified length from OH_AVFormat
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @param key Key value for reading and writing data
 * @param addr The life cycle is held by the format, with the destruction of the format,
 * if the caller needs to hold it for a long time, it must copy the memory
 * @param size Length of read and write data
 * @return The return value is TRUE for success, FALSE for failure
 * Possible failure causes: 1. input format is nullptr. 2. input format's magic error. 3. key is nullptr.
 * 4. addr is nullptr. 5. size is nullptr.
 * @since 9
 * @version 1.0
 */
bool OH_AVFormat_GetBuffer(struct OH_AVFormat *format, const char *key, uint8_t **addr, size_t *size);

/**
 * @brief Output the information contained in OH_AVFormat as a string.
 * @syscap SystemCapability.Multimedia.Media.Core
 * @param format pointer to an OH_AVFormat instance
 * @return Returns a string consisting of key and data for success, nullptr for failure
 * Possible failure causes: 1. input format is nullptr. 2. malloc dump info nullptr.
 * @since 9
 * @version 1.0
 */
const char *OH_AVFormat_DumpInfo(struct OH_AVFormat *format);

#ifdef __cplusplus
}
#endif

#endif // NATIVE_AVFORMAT_H