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

/**
 * @addtogroup image
 * @{
 *
 * @brief Provides APIs for obtaining image data from the native layer.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 10
 * @version 2.0
 */

/**
 * @file image_receiver_mdk.h
 *
 * @brief Declares the APIs for obtaining image data from the native layer.
 * Need link <b>libimagendk.z.so</b> and <b>libimage_receiverndk.z.so</b>
 * @since 10
 * @version 2.0
 */

#ifndef INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_RECEIVER_MDK_H_
#define INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_RECEIVER_MDK_H_
#include "napi/native_api.h"
#include "image_mdk_common.h"
#include "image_mdk.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines an <b>ImageReceiver</b> object at the native layer.
 *
 * @since 10
 * @version 2.0
 */
struct ImageReceiverNative_;

/**
 * @brief Defines the data type name of a native image receiver.
 *
 * @since 10
 * @version 2.0
 */
typedef struct ImageReceiverNative_ ImageReceiverNative;

/**
 * @brief Defines the callbacks for images at the native layer.
 *
 * @since 10
 * @version 2.0
 */
typedef void (*OH_Image_Receiver_On_Callback)(void);

/**
 * @brief Defines the information about an image receiver.
 *
 * @since 10
 * @version 2.0
 */
struct OhosImageReceiverInfo {
    /* Default width of the image received by the consumer, in pixels. */
    int32_t width;
    /* Default height of the image received by the consumer, in pixels. */
    int32_t height;
    /* Image format {@link OHOS_IMAGE_FORMAT_JPEG} created by using the receiver. */
    int32_t format;
    /* Maximum number of images that can be cached. */
    int32_t capicity;
};

/**
 * @brief Creates an <b>ImageReceiver</b> object at the application layer.
 *
 * @param env Indicates the NAPI environment pointer.
 * @param info Indicates the options for setting the <b>ImageReceiver</b> object.
 * @param res Indicates the pointer to the <b>ImageReceiver</b> object obtained.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SURFACE_GET_PARAMETER_FAILED - if Failed to obtain parameters for surface.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_SURFACE_FAILED - if create surface failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SURFACE_GRALLOC_BUFFER_FAILED - if surface gralloc buffer failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_SURFACE_FAILED - if get sufrace failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MEDIA_RTSP_SURFACE_UNSUPPORT - if media rtsp surface not support.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image type unsupported.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MEDIA_DATA_UNSUPPORT - if media type unsupported.
 * @see OhosImageReceiverInfo
 * @since 10
 * @version 2.0
 */
int32_t OH_Image_Receiver_CreateImageReceiver(napi_env env, struct OhosImageReceiverInfo info, napi_value* res);

/**
 * @brief Initializes an {@link ImageReceiverNative} object at the native layer
 * through an <b>ImageReceiver</b> object at the application layer.
 *
 * @param env Indicates the NAPI environment pointer.
 * @param source Indicates an <b>ImageReceiver</b> object.
 * @return Returns the pointer to the {@link ImageReceiverNative} object obtained if the operation is successful;
 * returns a null pointer otherwise.
 * @see ImageReceiverNative, OH_Image_Receiver_Release
 * @since 10
 * @version 2.0
 */
ImageReceiverNative* OH_Image_Receiver_InitImageReceiverNative(napi_env env, napi_value source);

/**
 * @brief Obtains the receiver ID through an {@link ImageReceiverNative} object.
 *
 * @param native Indicates the pointer to an {@link ImageReceiverNative} object at the native layer.
 * @param id Indicates the pointer to the buffer that stores the ID string obtained.
 * @param len Indicates the size of the buffer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SURFACE_GET_PARAMETER_FAILED - if Failed to obtain parameters for surface.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_SURFACE_FAILED - if get sufrace failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image type unsupported.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MEDIA_DATA_UNSUPPORT - if media type unsupported.
 * @see ImageReceiverNative
 * @since 10
 * @version 2.0
 */
int32_t OH_Image_Receiver_GetReceivingSurfaceId(const ImageReceiverNative* native, char* id, size_t len);

/**
 * @brief Obtains the latest image through an {@link ImageReceiverNative} object.
 *
 * @param native Indicates the pointer to an {@link ImageReceiverNative} object at the native layer.
 * @param image Indicates the pointer to an <b>Image</b> object at the application layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SURFACE_GET_PARAMETER_FAILED - if Failed to obtain parameters for surface.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_SURFACE_FAILED - if create surface failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SURFACE_GRALLOC_BUFFER_FAILED - if surface gralloc buffer failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_SURFACE_FAILED - if get sufrace failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MEDIA_RTSP_SURFACE_UNSUPPORT - if media rtsp surface not support.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image type unsupported.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SURFACE_REQUEST_BUFFER_FAILED - if request Buffer failed.
 * @see ImageReceiverNative
 * @since 10
 * @version 2.0
 */
int32_t OH_Image_Receiver_ReadLatestImage(const ImageReceiverNative* native, napi_value* image);

/**
 * @brief Obtains the next image through an {@link ImageReceiverNative} object.
 *
 * @param native Indicates the pointer to an {@link ImageReceiverNative} object at the native layer.
 * @param image Indicates the pointer to an <b>Image</b> object at the application layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SURFACE_GET_PARAMETER_FAILED - if Failed to obtain parameters for surface.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_CREATE_SURFACE_FAILED - if create surface failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SURFACE_GRALLOC_BUFFER_FAILED - if surface gralloc buffer failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_SURFACE_FAILED - if get sufrace failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_MEDIA_RTSP_SURFACE_UNSUPPORT - if media rtsp surface not support.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image type unsupported.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_SURFACE_REQUEST_BUFFER_FAILED - if request Buffer failed.
 * @see ImageReceiverNative
 * @since 10
 * @version 2.0
 */
int32_t OH_Image_Receiver_ReadNextImage(const ImageReceiverNative* native, napi_value* image);

/**
 * @brief Registers an {@link OH_Image_Receiver_On_Callback} callback event.
 *
 * This callback event is triggered whenever a new image is received.
 *
 * @param native Indicates the pointer to an {@link ImageReceiverNative} object at the native layer.
 * @param callback Indicates the {@link OH_Image_Receiver_On_Callback} callback event to register.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_GET_SURFACE_FAILED - if get sufrace failed.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image type unsupported.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_REGISTER_LISTENER_FAILED - if Failed to register listener.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_REGISTER_BUFFER_FAILED - if Failed to register buffer.
 * @see ImageReceiverNative
 * @since 10
 * @version 2.0
 */
int32_t OH_Image_Receiver_On(const ImageReceiverNative* native, OH_Image_Receiver_On_Callback callback);

/**
 * @brief Obtains the size of the image receiver through an {@link ImageReceiverNative} object.
 *
 * @param native Indicates the pointer to an {@link ImageReceiverNative} object at the native layer.
 * @param size Indicates the pointer to the {@link OhosImageSize} object obtained.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image type unsupported.
 * @see ImageReceiverNative, OH_Image_Receiver_On_Callback
 * @since 10
 * @version 2.0
 */
int32_t OH_Image_Receiver_GetSize(const ImageReceiverNative* native, struct OhosImageSize* size);

/**
 * @brief Obtains the capacity of the image receiver through an {@link ImageReceiverNative} object.
 *
 * @param native Indicates the pointer to an {@link ImageReceiverNative} object at the native layer.
 * @param capacity Indicates the pointer to the capacity obtained.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image type unsupported.
 * @see ImageReceiverNative, OhosImageSize
 * @since 10
 * @version 2.0
 */
int32_t OH_Image_Receiver_GetCapacity(const ImageReceiverNative* native, int32_t* capacity);

/**
 * @brief Obtains the format of the image receiver through an {@link ImageReceiverNative} object.
 *
 * @param native Indicates the pointer to an {@link ImageReceiverNative} object at the native layer.
 * @param format Indicates the pointer to the format obtained.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_DATA_UNSUPPORT - if image type unsupported.
 * @see ImageReceiverNative

 * @since 10
 * @version 2.0
 */
int32_t OH_Image_Receiver_GetFormat(const ImageReceiverNative* native, int32_t* format);

/**
 * @brief Releases an {@link ImageReceiverNative} object at the native layer.
 *
 * This API is not used to release an <b>ImageReceiver</b> object at the application layer.
 *
 * @param native Indicates the pointer to an {@link ImageReceiverNative} object at the native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_BAD_PARAMETER - if bad parameter.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_JNI_ENV_ABNORMAL - if Abnormal JNI environment.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 * @see ImageReceiverNative
 * @since 10
 * @version 2.0
 */
int32_t OH_Image_Receiver_Release(ImageReceiverNative* native);
#ifdef __cplusplus
};
#endif
/** @} */

#endif // INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_RECEIVER_MDK_H_