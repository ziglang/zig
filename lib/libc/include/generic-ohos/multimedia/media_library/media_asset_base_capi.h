/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
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
 * @addtogroup MediaAssetManager
 * @{
 *
 * @brief Provides APIs of request capability for Media Source.
 *
 * The OH_MediaAssetManager structure and MediaLibrary_RequestId type are used to request media library resources.
 * The request can be cancelled using the request ID.
 *
 * @since 12
 */

/**
 * @file media_asset_manager.h
 *
 * @brief Defines the structure and enumeration for Media Asset Manager.
 *
 * OH_MediaAssetManager structure: This structure provides the ability to request resources from a media library. \n
 * MediaLibrary_RequestId type: This type is returned when requesting a media library resource.
 * The request ID is used to cancel the request. \n
 * MediaLibrary_DeliveryMode enumeration: This enumeration defines the delivery mode of the requested resources. \n
 * OH_MediaLibrary_OnDataPrepared function pointer: This function is called when the requested source is prepared. \n
 * MediaLibrary_RequestOptions structure: This structure provides options for requesting media library resources. \n
 *
 * @Syscap SystemCapability.FileManagement.PhotoAccessHelper.Core
 * @library libmedia_asset_manager.so
 * @since 12
 */

#ifndef MULTIMEDIA_MEDIA_LIBRARY_NATIVE_MEDIA_ASSET_BASE_H
#define MULTIMEDIA_MEDIA_LIBRARY_NATIVE_MEDIA_ASSET_BASE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Define UUID max length
 *
 * This constant defines the maximum length of a UUID string.
 *
 * @since 12
 */
static const int32_t UUID_STR_MAX_LENGTH = 37;

/**
 * @brief Define Media Asset Manager
 *
 * This structure provides the ability to request media library resources.
 * Null pointer is returned if the creation fails.
 *
 * @since 12
 */
typedef struct OH_MediaAssetManager OH_MediaAssetManager;

/**
 * @brief Define MediaLibrary_RequestId
 *
 * This type is returned when requesting a media library resource.
 * The request id is used to cancel the request.
 * The value is all zero like "00000000-0000-0000-0000-000000000000" if the request fails.
 *
 * @since 12
 */
typedef struct MediaLibrary_RequestId {
    /*request id*/
    char requestId[UUID_STR_MAX_LENGTH];
} MediaLibrary_RequestId;

/**
 * @brief Delivery Mode
 *
 * This enumeration defines the delivery mode of the requested resources.
 * The delivery mode can be set to fast mode, high quality mode, or balanced mode.
 *
 * @since 12
 */
typedef enum MediaLibrary_DeliveryMode {
    /*delivery fast mode*/
    MEDIA_LIBRARY_FAST_MODE = 0,
    /*delivery high quality mode*/
    MEDIA_LIBRARY_HIGH_QUALITY_MODE = 1,
    /*delivery balanced mode*/
    MEDIA_LIBRARY_BALANCED_MODE = 2
} MediaLibrary_DeliveryMode;

/**
 * @brief Called when a requested source is prepared.
 *
 * This function is called when the requested source is prepared.
 *
 * @param result Results of the processing of the requested resources.
 * @param requestId Request ID.
 * @since 12
 */
typedef void (*OH_MediaLibrary_OnDataPrepared)(int32_t result, MediaLibrary_RequestId requestId);

/**
 * @brief Request Options
 *
 * This structure provides options for requesting media library resources.
 *
 * @since 12
 */
typedef struct MediaLibrary_RequestOptions {
    /*delivery mode*/
    MediaLibrary_DeliveryMode deliveryMode;
} MediaLibrary_RequestOptions;

#ifdef __cplusplus
}
#endif
#endif // MULTIMEDIA_MEDIA_LIBRARY_NATIVE_MEDIA_ASSET_BASE_H