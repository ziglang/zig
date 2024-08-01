/*
 * Copyright (c) 2022 Huawei Device Co., Ltd.
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

#ifndef NDK_INCLUDE_NATIVE_IMAGE_H_
#define NDK_INCLUDE_NATIVE_IMAGE_H_

/**
 * @addtogroup OH_NativeImage
 * @{
 *
 * @brief Provides the native image capability.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @since 9
 * @version 1.0
 */

/**
 * @file native_image.h
 *
 * @brief Defines the functions for obtaining and using a native image.
 *
 * @library libnative_image.so
 * @since 9
 * @version 1.0
 */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

struct OH_NativeImage;
typedef struct OH_NativeImage OH_NativeImage;
typedef struct NativeWindow OHNativeWindow;
/**
 * @brief The callback function of frame available.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param context User defined context, returned to the user in the callback function
 * @since 11
 * @version 1.0
 */
typedef void (*OH_OnFrameAvailable)(void *context);

/**
 * @brief A listener for native image, use <b>OH_NativeImage_SetOnFrameAvailableListener</b> to register \n
 * the listener object to <b>OH_NativeImage</b>, the callback will be triggered when there is available frame
 *
 * @since 11
 * @version 1.0
 */
typedef struct OH_OnFrameAvailableListener {
    /** User defined context, returned to the user in the callback function*/
    void *context;
    /** The callback function of frame available.*/
    OH_OnFrameAvailable onFrameAvailable;
} OH_OnFrameAvailableListener;

/**
 * @brief Create a <b>OH_NativeImage</b> related to an Opengl ES texture and target. \n
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param textureId Indicates the id of the Opengl ES texture which the native image attached to.
 * @param textureTarget Indicates the Opengl ES target.
 * @return Returns the pointer to the <b>OH_NativeImage</b> instance created if the operation is successful, \n
 * returns <b>NULL</b> otherwise.
 * @since 9
 * @version 1.0
 */
OH_NativeImage* OH_NativeImage_Create(uint32_t textureId, uint32_t textureTarget);

/**
 * @brief Acquire the OHNativeWindow for the OH_NativeImage. This OHNativeWindow should be released by \n
 * OH_NativeWindow_DestroyNativeWindow when no longer needed.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> instance.
 * @return Returns the pointer to the OHNativeWindow if the operation is successful, returns <b>NULL</b> otherwise.
 * @since 9
 * @version 1.0
 */
OHNativeWindow* OH_NativeImage_AcquireNativeWindow(OH_NativeImage* image);

/**
 * @brief Attach the OH_NativeImage to Opengl ES context, and the Opengl ES texture is bound to the \n
 * GL_TEXTURE_EXTERNAL_OES, which will update by the OH_NativeImage.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> instance.
 * @param textureId Indicates the id of the Opengl ES texture which the native image attached to.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeImage_AttachContext(OH_NativeImage* image, uint32_t textureId);

/**
 * @brief Detach the OH_NativeImage from the Opengl ES context.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 */

int32_t OH_NativeImage_DetachContext(OH_NativeImage* image);

/**
 * @brief Update the related Opengl ES texture with the OH_NativeImage acquired buffer.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeImage_UpdateSurfaceImage(OH_NativeImage* image);

/**
 * @brief Get the timestamp of the texture image set by the most recent call to OH_NativeImage_UpdateSurfaceImage.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> instance.
 * @return Returns the timestamp associated to the texture image.
 * @since 9
 * @version 1.0
 */
int64_t OH_NativeImage_GetTimestamp(OH_NativeImage* image);

/**
 * @brief Return the transform matrix of the texture image set by the most recent call to \n
 * OH_NativeImage_UpdateSurfaceImage.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> instance.
 * @param matrix Indicates the retrieved 4*4 transform matrix .
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 9
 * @version 1.0
 */
int32_t OH_NativeImage_GetTransformMatrix(OH_NativeImage* image, float matrix[16]);

/**
 * @brief Return the native image's surface id.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> instance.
 * @param surfaceId Indicates the surface id.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 11
 * @version 1.0
 */
int32_t OH_NativeImage_GetSurfaceId(OH_NativeImage* image, uint64_t* surfaceId);

/**
 * @brief Set the frame available callback.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> instance.
 * @param listener Indicates the callback function.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 11
 * @version 1.0
 */
int32_t OH_NativeImage_SetOnFrameAvailableListener(OH_NativeImage* image, OH_OnFrameAvailableListener listener);

/**
 * @brief Unset the frame available callback.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> instance.
 * @return Returns an error code, 0 is success, otherwise, failed.
 * @since 11
 * @version 1.0
 */
int32_t OH_NativeImage_UnsetOnFrameAvailableListener(OH_NativeImage* image);

/**
 * @brief Destroy the <b>OH_NativeImage</b> created by OH_NativeImage_Create, and the pointer to \n
 * <b>OH_NativeImage</b> will be null after this operation.
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> pointer.
 * @since 9
 * @version 1.0
 */
void OH_NativeImage_Destroy(OH_NativeImage** image);

/**
 * @brief Obtains the transform matrix of the texture image by producer transform type.\n
 *
 * @syscap SystemCapability.Graphic.Graphic2D.NativeImage
 * @param image Indicates the pointer to a <b>OH_NativeImage</b> instance.
 * @param matrix Indicates the retrieved 4*4 transform matrix .
 * @return 0 - Success.
 *     40001000 - image is NULL.
 * @since 12
 * @version 1.0
 */
int32_t OH_NativeImage_GetTransformMatrixV2(OH_NativeImage* image, float matrix[16]);

#ifdef __cplusplus
}
#endif

/** @} */
#endif