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
 * @addtogroup ArkUI_NativeModule
 * @{
 *
 * @brief Provides UI capabilities of ArkUI on the native side, such as UI component creation and destruction,
 * tree node operations, attribute setting, and event listening.
 *
 * @since 12
 */

/**
 * @file drawable_descriptor.h
 *
 * @brief Defines theNativeDrawableDescriptor for the native module.
 *
 * @library libace_ndk.z.so
 * @syscap SystemCapability.ArkUI.ArkUI.Full
 * @since 12
 */

#ifndef ARKUI_NATIVE_DRAWABLE_DESCRIPTOR_H
#define ARKUI_NATIVE_DRAWABLE_DESCRIPTOR_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the drawable descriptor.
 *
 * @since 12
 */
typedef struct ArkUI_DrawableDescriptor ArkUI_DrawableDescriptor;

/**
 * @brief Introduces the native pixel map information defined by Image Kit.
 *
 * @since 12
 */
struct OH_PixelmapNative;

/**
 * @brief Defines the pointer to OH_PixelmapNative.
 *
 * @since 12
 */
typedef struct OH_PixelmapNative* OH_PixelmapNativeHandle;

/**
 * @brief Creates a DrawableDescriptor from a Pixelmap.
 *
 * @param pixelMap Indicates the pointer to a Pixelmap
 * @return Returns the pointer to the drawableDescriptor.
 * @since 12
*/
ArkUI_DrawableDescriptor* OH_ArkUI_DrawableDescriptor_CreateFromPixelMap(OH_PixelmapNativeHandle pixelMap);

/**
 * @brief Creates a DrawableDescriptor from a Pixelmap array.
 *
 * @param array Indicates the pointer to a Pixelmap array.
 * @param size Indicates the size of the Pixelmap array.
 * @return Returns the pointer to the drawableDescriptor.
 * @since 12
*/
ArkUI_DrawableDescriptor* OH_ArkUI_DrawableDescriptor_CreateFromAnimatedPixelMap(
    OH_PixelmapNativeHandle* array, int32_t size);

/**
 * @brief Destroys the pointer to the drawableDescriptor.
 *
 * @param drawableDescriptor Indicates the pointer to the drawableDescriptor.
 * @since 12
*/
void OH_ArkUI_DrawableDescriptor_Dispose(ArkUI_DrawableDescriptor* drawableDescriptor);

/**
 * @brief Obtains the Pixelmap object.
 *
 * @param drawableDescriptor Indicates the pointer to the drawableDescriptor.
 * @return Returns the pointer to the PixelMap.
 * @since 12
*/
OH_PixelmapNativeHandle OH_ArkUI_DrawableDescriptor_GetStaticPixelMap(ArkUI_DrawableDescriptor* drawableDescriptor);

/**
 * @brief Obtains the Pixelmap array used to play the animation.
 *
 * @param drawableDescriptor Indicates the pointer to the drawableDescriptor.
 * @return Returns the pointer to the PixelMap array.
 * @since 12
*/
OH_PixelmapNativeHandle* OH_ArkUI_DrawableDescriptor_GetAnimatedPixelMapArray(
    ArkUI_DrawableDescriptor* drawableDescriptor);

/**
 * @brief Obtains the size of the Pixelmap array used to play the animation.
 *
 * @param drawableDescriptor Indicates the pointer to the drawableDescriptor.
 * @return Returns the size of the Pixelmap array.
 * @since 12
*/
int32_t OH_ArkUI_DrawableDescriptor_GetAnimatedPixelMapArraySize(ArkUI_DrawableDescriptor* drawableDescriptor);

/**
 * @brief Sets the total playback duration.
 *
 * @param drawableDescriptor Indicates the pointer to the drawableDescriptor.
 * @param duration Indicates the total playback duration. The unit is millisecond.
 * @since 12
*/
void OH_ArkUI_DrawableDescriptor_SetAnimationDuration(ArkUI_DrawableDescriptor* drawableDescriptor, int32_t duration);

/**
 * @brief Obtains the total playback duration.
 *
 * @param drawableDescriptor Indicates the pointer to the drawableDescriptor.
 * @return Return the total playback duration. The unit is millisecond.
 * @since 12
*/
int32_t OH_ArkUI_DrawableDescriptor_GetAnimationDuration(ArkUI_DrawableDescriptor* drawableDescriptor);

/**
 * @brief Sets the number of playback times.
 *
 * @param drawableDescriptor Indicates the pointer to the drawableDescriptor.
 * @param iterations Indicates the number of playback times.
 * @since 12
*/
void OH_ArkUI_DrawableDescriptor_SetAnimationIteration(
    ArkUI_DrawableDescriptor* drawableDescriptor, int32_t iteration);

/**
 * @brief Obtains the number of playback times.
 *
 * @param drawableDescriptor Indicates the pointer to the drawableDescriptor.
 * @return Returns the number of playback times.
 * @since 12
*/
int32_t OH_ArkUI_DrawableDescriptor_GetAnimationIteration(ArkUI_DrawableDescriptor* drawableDescriptor);
#ifdef __cplusplus
};
#endif

#endif // ARKUI_NATIVE_DRAWABLE_DESCRIPTOR_H
/** @} */