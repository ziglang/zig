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
 * @brief Provides native APIs for encoding image data
 *
 * The encoding image data module part of image module.
 * It used to pack pixel data infomation into a target like data or file.
 *
 * @since 11
 * @version 4.1
 */

/**
 * @file image_packer_mdk.h
 *
 * @brief Declares APIs for encoding image into data or file.
 *
 * The packing image data module used to pack pixel data into a target.
 *
 * The following steps are recommended for packing process:
 * Create a image packer object by calling OH_ImagePacker_Create function.
 * And then covert the image packer object to ImagePacker_Native by OH_ImagePacker_InitNative.
 * Next using OH_ImagePacker_PackToData or OH_ImagePacker_PackToFile to pack source to target area with
 * requird packing options.
 * Finally, release the ImagePacker_Native by OH_ImagePacker_Release.
 *
 * @library libimage_packer_ndk.z.so
 * @syscap SystemCapability.Multimedia.Image
 * @since 11
 * @version 4.1
 */

#ifndef INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PACKER_MDK_H_
#define INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PACKER_MDK_H_
#include "napi/native_api.h"
#include "image_mdk_common.h"

#ifdef __cplusplus
extern "C" {
#endif

struct ImagePacker_Native_;

/**
 * @brief Defines an image packer object at the native layer for the image packer interface.
 *
 * @since 11
 * @version 4.1
 */
typedef struct ImagePacker_Native_ ImagePacker_Native;

/**
 * @brief Defines the image packing options.
 *
 * @since 11
 * @version 4.1
 */
struct ImagePacker_Opts_ {
    /** Encoding format. */
    const char* format;
    /** Encoding quality. */
    int quality;
};

/**
 * @brief Defines alias of image packing options.
 *
 * @since 11
 * @version 4.1
 */
typedef struct ImagePacker_Opts_ ImagePacker_Opts;

/**
 * @brief Creates an <b>ImagePacker</b> object at the JavaScript native layer.
 *
 * @param env Indicates a pointer to the JavaScript Native Interface (JNI) environment.
 * @param res Indicates a pointer to the <b>ImagePacker</b> object created at the JavaScript native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
 *
 * @Syscap SystemCapability.Multimedia.Image
 * @since 11
 * @version 4.1
 */
int32_t OH_ImagePacker_Create(napi_env env, napi_value *res);

/**
 * @brief Parses an {@link ImagePacker_Native} object at the native layer
 * from a JavaScript native API <b>ImagePacker</b> object.
 *
 * @param env Indicates the pointer to the JavaScript Native Interface (JNI) environment.
 * @param packer Indicates a JavaScript native API <b>ImagePacker</b> object.
 * @return Returns an {@link ImagePacker_Native} pointer object if the operation is successful
 * returns a null pointer otherwise.
 * @see {@link OH_ImagePacker_Release}
 * @since 11
 * @version 4.1
 */
ImagePacker_Native* OH_ImagePacker_InitNative(napi_env env, napi_value packer);

/**
 * @brief Encoding an <b>ImageSource</b> or a <b>PixelMap</b> into the data with required format
 *
 * @param native Indicates the pointer to an {@link ImagePacker} object at the native layer.
 * @param source Indicates an encoding source, a JS pixel map object or a JS image source object .
 * @param opts Indicates the encoding {@link ImagePacker_Opts} .
 * @param outData Indicates the pointer to the encoded data.
 * @param size Indicates the pointer to the {@link OhosImageComponent} object obtained.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
  * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
  * returns {@link IRNdkErrCode} ERR_IMAGE_DATA_ABNORMAL - if output target abnormal
  * returns {@link IRNdkErrCode} ERR_IMAGE_MISMATCHED_FORMAT - if format mismatched
  * returns {@link IRNdkErrCode} ERR_IMAGE_MALLOC_ABNORMAL - if malloc internal buffer error
  * returns {@link IRNdkErrCode} ERR_IMAGE_DECODE_ABNORMAL - if init codec internal error
  * returns {@link IRNdkErrCode} ERR_IMAGE_ENCODE_FAILED - if encoder occur error during encoding
 * @see {@link OH_ImagePacker_PackToFile}
 * @since 11
 * @version 4.1
 */
int32_t OH_ImagePacker_PackToData(ImagePacker_Native* native, napi_value source,
    ImagePacker_Opts* opts, uint8_t* outData, size_t* size);

/**
 * @brief Encoding an <b>ImageSource</b> or a <b>PixelMap</b> into the a file with fd with required format
 *
 * @param native Indicates the pointer to an {@link ImagePacker} object at the native layer.
 * @param source Indicates an encoding source, a JS pixel map object or a JS image source object .
 * @param opts Indicates the encoding {@link ImagePacker_Opts} .
 * @param fd Indicates the a writable file descriptor.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
  * returns {@link IRNdkErrCode} IMAGE_RESULT_INVALID_PARAMETER - if invalid parameter.
  * returns {@link IRNdkErrCode} ERR_IMAGE_DATA_ABNORMAL - if output target abnormal
  * returns {@link IRNdkErrCode} ERR_IMAGE_MISMATCHED_FORMAT - if format mismatched
  * returns {@link IRNdkErrCode} ERR_IMAGE_MALLOC_ABNORMAL - if malloc internal buffer error
  * returns {@link IRNdkErrCode} ERR_IMAGE_DECODE_ABNORMAL - if init codec internal error
  * returns {@link IRNdkErrCode} ERR_IMAGE_ENCODE_FAILED - if encoder occur error during encoding
 * @see {@link OH_ImagePacker_PackToData}
 * @since 11
 * @version 4.1
 */
int32_t OH_ImagePacker_PackToFile(ImagePacker_Native* native, napi_value source,
    ImagePacker_Opts* opts, int fd);


/**
 * @brief Releases an {@link ImagePacker_Native} object at the native layer.
 * Note: This API is not used to release a JavaScript native API <b>ImagePacker</b> object.
 * It is used to release the object {@link ImagePacker_Native} at the native layer
 * parsed by calling {@link OH_ImagePacker_InitNative}.
 *
 * @param native Indicates the pointer to an {@link ImagePacker_Native} object at the native layer.
 * @return Returns {@link IRNdkErrCode} IMAGE_RESULT_SUCCESS - if the operation is successful.
 * @see {@link OH_ImagePacker_InitNative}
 * @since 11
 * @version 4.1
 */
int32_t OH_ImagePacker_Release(ImagePacker_Native* native);
#ifdef __cplusplus
};
#endif
/** @} */
#endif // INTERFACES_KITS_NATIVE_INCLUDE_IMAGE_PACKER_MDK_H_