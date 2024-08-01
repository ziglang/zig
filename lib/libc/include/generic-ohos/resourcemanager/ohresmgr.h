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
 * @addtogroup resourcemanager
 * @{
 *
 * @brief Provides the c interface to obtain resources, and relies on librawfile.z.so when used.
 *
 * @since 12
 */

/**
 * @file ohresmgr.h
 *
 * @brief Provides the implementation of the interface.
 * @syscap SystemCapability.Global.ResourceManager
 * @library libohresmgr.so
 * @since 12
 */
#ifndef GLOBAL_OH_RESMGR_H
#define GLOBAL_OH_RESMGR_H

#include "resmgr_common.h"
#include "../rawfile/raw_file_manager.h"
#include "../arkui/drawable_descriptor.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Obtains the Base64 code of the image resource.
 *
 * Obtains the Base64 code of the image resource corresponding to the specified resource ID.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 * {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param density The optional parameter ScreenDensity{@link ScreenDensity}, A value of 0 means
 * to use the density of current system dpi.
 * @param resultValue the result write to resultValue.
 * @param resultLen the media length write to resultLen.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - If the input parameter invalid. Possible causes:
 *         1.Incorrect parameter types; 2.Parameter verification failed.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetMediaBase64(const NativeResourceManager *mgr, uint32_t resId,
    char **resultValue, uint64_t *resultLen, uint32_t density = 0);

/**
 * @brief Obtains the Base64 code of the image resource.
 *
 * Obtains the Base64 code of the image resource corresponding to the specified resource name.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 * {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param density The optional parameter ScreenDensity{@link ScreenDensity}, A value of 0 means
 * to use the density of current system dpi.
 * @param resultValue the result write to resultValue.
 * @param resultLen the media length write to resultLen.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - If the input parameter invalid. Possible causes:
 *         1.Incorrect parameter types; 2.Parameter verification failed.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetMediaBase64ByName(const NativeResourceManager *mgr,
    const char *resName, char **resultValue, uint64_t *resultLen, uint32_t density = 0);

/**
 * @brief Obtains the content of the image resource.
 *
 * Obtains the content of the specified screen density media file corresponding to a specified resource ID.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 * {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param density The optional parameter ScreenDensity{@link ScreenDensity}, A value of 0 means
 * to use the density of current system dpi.
 * @param resultValue the result write to resultValue.
 * @param resultLen the media length write to resultLen.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - If the input parameter invalid. Possible causes:
 *         1.Incorrect parameter types; 2.Parameter verification failed.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetMedia(const NativeResourceManager *mgr, uint32_t resId,
    uint8_t **resultValue, uint64_t *resultLen, uint32_t density = 0);

/**
 * @brief Obtains the content of the image resource.
 *
 * Obtains the content of the specified screen density media file corresponding to a specified resource name.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 * {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param density The optional parameter ScreenDensity{@link ScreenDensity}, A value of 0 means
 * to use the density of current system dpi.
 * @param resultValue the result write to resultValue.
 * @param resultLen the media length write to resultLen.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - If the input parameter invalid. Possible causes:
 *         1.Incorrect parameter types; 2.Parameter verification failed.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetMediaByName(const NativeResourceManager *mgr, const char *resName,
    uint8_t **resultValue, uint64_t *resultLen, uint32_t density = 0);

/**
 * @brief Obtains the DrawableDescriptor of the media file.
 *
 * Obtains the DrawableDescriptor of the media file corresponding to a specified resource ID.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 * {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param density The optional parameter ScreenDensity{@link ScreenDensity}, A value of 0 means
 * to use the density of current system dpi.
 * @param type The optional parameter means the media type, 0 means the normal media, 1 means the the theme style media.
 * @param drawableDescriptor the result write to drawableDescriptor.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - If the input parameter invalid. Possible causes:
 *         1.Incorrect parameter types; 2.Parameter verification failed.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetDrawableDescriptor(const NativeResourceManager *mgr,
    uint32_t resId, ArkUI_DrawableDescriptor **drawableDescriptor, uint32_t density = 0, uint32_t type = 0);

/**
 * @brief Obtains the DrawableDescriptor of the media file.
 *
 * Obtains the DrawableDescriptor of the media file corresponding to a specified resource name.
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 * {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param density The optional parameter ScreenDensity{@link ScreenDensity}, A value of 0 means
 * to use the density of current system dpi.
 * @param type The optional parameter means the media type, 0 means the normal media, 1 means the the theme style media,
 * 2 means the theme dynamic media.
 * @param drawableDescriptor the result write to drawableDescriptor.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - If the input parameter invalid. Possible causes:
 *         1.Incorrect parameter types; 2.Parameter verification failed.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetDrawableDescriptorByName(const NativeResourceManager *mgr,
    const char *resName, ArkUI_DrawableDescriptor **drawableDescriptor, uint32_t density = 0, uint32_t type = 0);

#ifdef __cplusplus
};
#endif

/** @} */
#endif // GLOBAL_OH_RESMGR_H