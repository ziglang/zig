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
 * @addtogroup ImageEffect
 * @{
 *
 * @brief Provides APIs for obtaining and using a image effect.
 *
 * @since 12
 */

/**
 * @file image_effect.h
 *
 * @brief Declares the functions for rendering image.
 *
 * @library libimage_effect.so
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @since 12
 */

#ifndef NATIVE_IMAGE_EFFECT_H
#define NATIVE_IMAGE_EFFECT_H

#include "image_effect_errors.h"
#include "image_effect_filter.h"
#include "native_buffer/native_buffer.h"
#include "native_window/external_window.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Define the new type name OH_ImageEffect for struct OH_ImageEffect
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @since 12
 */
typedef struct OH_ImageEffect OH_ImageEffect;

/**
 * @brief Create an OH_ImageEffect instance. It should be noted that the life cycle of the OH_ImageEffect instance
 * pointed to by the return value * needs to be manually released by {@link OH_ImageEffect_Release}
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param name The name of image effect
 * @return Returns a pointer to an OH_ImageEffect instance if the execution is successful, otherwise returns nullptr
 * @since 12
 */
OH_ImageEffect *OH_ImageEffect_Create(const char *name);

/**
 * @brief Create and add the OH_EffectFilter to the OH_ImageEffect
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param filterName Indicates the name of the filter that can be customized by the developer or supported by the system
 * @return Returns a pointer to an OH_EffectFilter instance if the filter name is valid, otherwise returns nullptr
 * @since 12
 */
OH_EffectFilter *OH_ImageEffect_AddFilter(OH_ImageEffect *imageEffect, const char *filterName);

/**
 * @brief Create and add the OH_EffectFilter to the OH_ImageEffect by specified position
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param index Indicates the position of the OH_EffectFilter witch is created and added
 * @param filterName Indicates the name of the filter that can be customized by the developer or supported by the system
 * @return Returns a pointer to an OH_EffectFilter instance if the index and filter name is valid, otherwise returns
 * nullptr
 * @since 12
 */
OH_EffectFilter *OH_ImageEffect_InsertFilter(OH_ImageEffect *imageEffect, uint32_t index, const char *filterName);

/**
 * @brief Remove all filters of the specified filter name
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param filterName Indicates the name of the filter that can be customized by the developer or supported by the system
 * @return Returns the number of the filters that matches the specified filter name
 * @since 12
 */
int32_t OH_ImageEffect_RemoveFilter(OH_ImageEffect *imageEffect, const char *filterName);

/**
 * @brief Get the number of the filters in OH_ImageEffect
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @return Returns the number of the filters in OH_ImageEffect
 * @since 12
 */
int32_t OH_ImageEffect_GetFilterCount(OH_ImageEffect *imageEffect);

/**
 * @brief Get an OH_EffectFilter instance that add to OH_ImageEffect by the index
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param index Indicates the position of the OH_EffectFilter that add to OH_ImageEffect
 * @return Returns a pointer to an OH_EffectFilter instance if the index is valid, otherwise returns nullptr
 * @since 12
 */
OH_EffectFilter *OH_ImageEffect_GetFilter(OH_ImageEffect *imageEffect, uint32_t index);

/**
 * @brief Set configuration information to the OH_ImageEffect
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param key Indicates the key of the configuration
 * @param value Indicates the value corresponding to the key of the configuration
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * {@link EFFECT_KEY_ERROR}, the key of the configuration parameter is invalid.
 * {@link EFFECT_PARAM_ERROR}, the value of the configuration parameter is invalid.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_Configure(OH_ImageEffect *imageEffect, const char *key,
    const ImageEffect_Any *value);

/**
 * @brief Set the Surface to the image effect, this interface must be called before
 * @{link OH_ImageEffect_GetInputSurface} is called
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param nativeWindow A pointer to a OHNativeWindow instance, see {@link OHNativeWindow}
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_SetOutputSurface(OH_ImageEffect *imageEffect, OHNativeWindow *nativeWindow);

/**
 * @brief Get the input Surface from the image effect, this interface must be called after
 * @{link OH_ImageEffect_SetOutputSurface} is called
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param nativeWindow A pointer to a OHNativeWindow instance, see {@link OHNativeWindow}
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_GetInputSurface(OH_ImageEffect *imageEffect, OHNativeWindow **nativeWindow);

/**
 * @brief Set input pixelmap that contains the image information. It should be noted that the input pixel map will be
 * directly rendered and modified if the output is not set
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param pixelmap Indicates the OH_PixelmapNative that contains the image information
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_SetInputPixelmap(OH_ImageEffect *imageEffect, OH_PixelmapNative *pixelmap);

/**
 * @brief Set output pixelmap that contains the image information
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param pixelmap Indicates the OH_PixelmapNative that contains the image information
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_SetOutputPixelmap(OH_ImageEffect *imageEffect, OH_PixelmapNative *pixelmap);

/**
 * @brief Set input NativeBuffer that contains the image information. It should be noted that the input NativeBuffer
 * will be directly rendered and modified if the output is not set
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param nativeBuffer Indicates the NativeBuffer that contains the image information
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_SetInputNativeBuffer(OH_ImageEffect *imageEffect, OH_NativeBuffer *nativeBuffer);

/**
 * @brief Set output NativeBuffer that contains the image information
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param nativeBuffer Indicates the NativeBuffer that contains the image information
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_SetOutputNativeBuffer(OH_ImageEffect *imageEffect, OH_NativeBuffer *nativeBuffer);

/**
 * @brief Set input URI of the image. It should be noted that the image resource will be directly rendered and modified
 * if the output is not set
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param uri An URI for a image resource
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_SetInputUri(OH_ImageEffect *imageEffect, const char *uri);

/**
 * @brief Set output URI of the image
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param uri An URI for a image resource
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_SetOutputUri(OH_ImageEffect *imageEffect, const char *uri);

/**
 * @brief Render the filter effects that can be a single filter or a chain of filters
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * {@link EFFECT_INPUT_OUTPUT_NOT_SUPPORTED}, the data types of the input and output images
 * to be processed are different.
 * {@link EFFECT_COLOR_SPACE_NOT_MATCH}, the color spaces of the input and output images are different.
 * {@link EFFECT_ALLOCATE_MEMORY_FAILED}, the buffer fails to be allocated.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_Start(OH_ImageEffect *imageEffect);

/**
 * @brief Stop rendering the filter effects for next image frame data
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_Stop(OH_ImageEffect *imageEffect);

/**
 * @brief Clear the internal resources of the OH_ImageEffect and destroy the OH_ImageEffect instance
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_Release(OH_ImageEffect *imageEffect);

/**
 * @brief Convert the OH_ImageEffect and the information of the filters in OH_ImageEffect to JSON string
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param imageEffect Encapsulate OH_ImageEffect structure instance pointer
 * @param info Indicates the serialized information that is obtained by converting the information of the filters in
 * OH_ImageEffect to JSON string
 * @return Returns EFFECT_SUCCESS if the execution is successful, otherwise returns a specific error code, refer to
 * {@link ImageEffect_ErrorCode}
 * {@link EFFECT_ERROR_PARAM_INVALID}, the input parameter is a null pointer.
 * @since 12
 */
ImageEffect_ErrorCode OH_ImageEffect_Save(OH_ImageEffect *imageEffect, char **info);

/**
 * @brief Create an OH_ImageEffect instance by deserializing the JSON string info
 *
 * @syscap SystemCapability.Multimedia.ImageEffect.Core
 * @param info Indicates the serialized information that is obtained by converting the information of the filters in
 * OH_ImageEffect to JSON string
 * @return Returns a pointer to an OH_ImageEffect instance if the execution is successful, otherwise returns nullptr
 * @since 12
 */
OH_ImageEffect *OH_ImageEffect_Restore(const char *info);

#ifdef __cplusplus
}
#endif
#endif // NATIVE_IMAGE_EFFECT_H
/** @} */