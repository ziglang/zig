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

#ifndef C_INCLUDE_NATIVE_DISPLAY_SOLOIST_H_
#define C_INCLUDE_NATIVE_DISPLAY_SOLOIST_H_

/**
 * @addtogroup NativeDisplaySoloist
 * @{
 *
 * @brief Provides the native displaySoloist capability.
 *
 * @since 12
 * @version 1.0
 */

/**
 * @file native_display_soloist.h
 *
 * @brief Defines the functions for obtaining and using a native displaySoloist.
 * @syscap SystemCapability.Graphic.Graphic2D.HyperGraphicManager
 * @library libnative_display_soloist.so
 * @since 12
 * @version 1.0
 */

#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the native displaySoloist struct.
 *
 * @since 12
 * @version 1.0
 */
typedef struct OH_DisplaySoloist OH_DisplaySoloist;

/**
 * @brief Defines the native displaySoloist callback.
 *
 * @param timestamp Indicates the current timestamp.
 * @param targetTimestamp Indicates the target timestamp.
 * @param data Indicates the pointer to user data.
 * @since 12
 * @version 1.0
 */
typedef void (*OH_DisplaySoloist_FrameCallback)(long long timestamp, long long targetTimestamp, void* data);

/**
 * @brief Defines the expected frame rate range struct.
 *
 * @since 12
 * @version 1.0
 */
typedef struct {
    /** The minimum frame rate of dynamical callback rate range. */
    int32_t min;
    /** The maximum frame rate of dynamical callback rate range. */
    int32_t max;
    /** The expected frame rate of dynamical callback rate range. */
    int32_t expected;
} DisplaySoloist_ExpectedRateRange;

/**
 * @brief Creates a <b>OH_DisplaySoloist</b> instance.\n
 *
 * @param useExclusiveThread Indicates whether the vsync run in a exclusive thread.
 * @return Returns the pointer to the <b>OH_DisplaySoloist</b> instance created if the execution is successful.
 * if nullptr is returned, the creation fails.
 * the possible cause of the failure is that the available memory is empty.
 * @since 12
 * @version 1.0
 */
OH_DisplaySoloist* OH_DisplaySoloist_Create(bool useExclusiveThread);

/**
 * @brief Destroys a <b>OH_DisplaySoloist</b> instance and reclaims the memory occupied by the object.
 *
 * @param displaySoloist Indicates the pointer to a native displaySoloist.
 * @return Returns int32_t, returns 0 if the execution is successful, returns -1 if displaySoloist is incorrect.
 * @since 12
 * @version 1.0
 */
int32_t OH_DisplaySoloist_Destroy(OH_DisplaySoloist* displaySoloist);

/**
 * @brief Start to request next vsync with callback.
 *
 * @param displaySoloist Indicates the pointer to a native displaySoloist.
 * @param callback Indicates the OH_DisplaySoloist_FrameCallback which will be called when next vsync coming.
 * @param data Indicates data whick will be used in callback.
 * @return Returns int32_t, returns 0 if the execution is successful.
 * returns -1 if displaySoloist or callback is incorrect.
 * @since 12
 * @version 1.0
 */
int32_t OH_DisplaySoloist_Start(
    OH_DisplaySoloist* displaySoloist, OH_DisplaySoloist_FrameCallback callback, void* data);

/**
 * @brief Stop to request next vsync with callback.
 *
 * @param displaySoloist Indicates the pointer to a native displaySoloist.
 * @return Returns int32_t, returns 0 if the execution is successful, returns -1 if displaySoloist is incorrect.
 * @since 12
 * @version 1.0
 */
int32_t OH_DisplaySoloist_Stop(OH_DisplaySoloist* displaySoloist);

/**
 * @brief Set vsync expected frame rate range.
 *
 * @param displaySoloist Indicates the pointer to a native displaySoloist.
 * @param range Indicates the pointer to an expected rate range.
 * @return Returns int32_t, returns 0 if the execution is successful
 * returns -1 if displaySoloist or range is incorrect.
 * @since 12
 * @version 1.0
 */
int32_t OH_DisplaySoloist_SetExpectedFrameRateRange(
    OH_DisplaySoloist* displaySoloist, DisplaySoloist_ExpectedRateRange* range);

#ifdef __cplusplus
}
#endif

#endif
/** @} */