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
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid. Possible causes:
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
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid. Possible causes:
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
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid. Possible causes:
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
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid. Possible causes:
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
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid. Possible causes:
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
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid. Possible causes:
 *         1.Incorrect parameter types; 2.Parameter verification failed.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetDrawableDescriptorByName(const NativeResourceManager *mgr,
    const char *resName, ArkUI_DrawableDescriptor **drawableDescriptor, uint32_t density = 0, uint32_t type = 0);

/**
 * @brief Obtains the symbol resource.
 *
 * Obtains the symbol resource corresponding to the specified resource ID.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetSymbol(const NativeResourceManager *mgr, uint32_t resId,
    uint32_t *resultValue);

/**
 * @brief Obtains the symbol resource.
 *
 * Obtains the symbol resource corresponding to the specified resource name.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetSymbolByName(const NativeResourceManager *mgr, const char *resName,
    uint32_t *resultValue);

/**
 * @brief Obtains locales list.
 *
 * You need to call the OH_ResourceManager_ReleaseStringArray() method to release the memory of localinfo.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resultValue the result write to resultValue.
 * @param resultLen the locales length write to resultLen.
 * @param includeSystem the parameter controls whether to include system resources,
 * the default value is false, it has no effect when only system resources query the locales list.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
 *         {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetLocales(const NativeResourceManager *mgr, char ***resultValue,
    uint32_t *resultLen, bool includeSystem = false);

/**
 * @brief Obtains the device configuration.
 *
 * You need to call the OH_ResourceManager_ReleaseConfiguration() method to release the memory.
 * If you use malloc to create a ResourceManager_Configuration object, you also need to call free to release it.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param configuration the result write to ResourceManager_Configuration.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_SYSTEM_RES_MANAGER_GET_FAILED} 9001009 - If failed to access the system resource.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetConfiguration(const NativeResourceManager *mgr,
    ResourceManager_Configuration *configuration);

/**
 * @brief Release the device configuration.
 * @param configuration the object need to release.
 * @return {@link SUCCESS} 0 - Success.
           {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_ReleaseConfiguration(ResourceManager_Configuration *configuration);

/**
 * @brief Obtains the character string.
 *
 * Obtains the character string corresponding to a specified resource ID.
 * Obtain normal resource by calling OH_ResourceManager_GetString(mgr, resId, resultValue),
   obtain a formatted resource with replacements for %d, %s, %f,
   call OH_ResourceManager_GetString(mgr, resId, resultValue, 10, "format", 10.10).
 * You need to call free() to release the memory for the string.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param resultValue the result write to resultValue.
 * @param { const char* | int | float } args - Indicates the formatting string resource parameters.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetString(const NativeResourceManager *mgr, uint32_t resId,
    char **resultValue, ...);

/**
 * @brief Obtains the character string.
 *
 * Obtains the character string corresponding to a specified resource name.
 * Obtain normal resource by calling OH_ResourceManager_GetString(mgr, resName, resultValue),
   obtain a formatted resource with replacements for %d, %s, %f,
   call OH_ResourceManager_GetString(mgr, resName, resultValue, 10, "format", 10.10).
 * You need to call free() to release the memory for the string.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param resultValue the result write to resultValue.
 * @param { const char* | int | float } args - Indicates the formatting string resource parameters.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetStringByName(const NativeResourceManager *mgr, const char *resName,
    char **resultValue, ...);

/**
 * @brief Obtains the array of character strings.
 *
 * Obtains the array of character strings corresponding to a specified resource ID.
 * You need to call the OH_ResourceManager_ReleaseStringArray() method to release the memory of string array.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param resultValue the result write to resultValue.
 * @param resultLen the StringArray length write to resultLen.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetStringArray(const NativeResourceManager *mgr, uint32_t resId,
    char ***resultValue, uint32_t *resultLen);

/**
 * @brief Obtains the array of character strings.
 *
 * Obtains the array of character strings corresponding to a specified resource name.
 * You need to call the OH_ResourceManager_ReleaseStringArray() method to release the memory of string array.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param resultValue the result write to resultValue.
 * @param resultLen the StringArray length write to resultLen.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetStringArrayByName(const NativeResourceManager *mgr,
    const char *resName, char ***resultValue, uint32_t *resultLen);

/**
 * @brief Release the array of character strings.
 * @param resValue the array of character strings corresponding to the specified resource name.
 * @param len the length of array.
 * @return {@link SUCCESS} 0 - Success.
           {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_ReleaseStringArray(char ***resValue, uint32_t len);

/**
 * @brief Obtains the singular-plural character string represented.
 *
 * Obtains the singular-plural character string represented by the ID string corresponding to the specified number.
 * You need to call free() to release the memory for the string.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param num - Indicates the number.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetPluralString(const NativeResourceManager *mgr, uint32_t resId,
    uint32_t num, char **resultValue);

/**
 * @brief Obtains the singular-plural character string represented.
 *
 * Obtains the singular-plural character string represented by the Name string corresponding to the specified number.
 * You need to call free() to release the memory for the string.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param num - Indicates the number.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
           {@link ERROR_CODE_OUT_OF_MEMORY} 9001100 - Out of memory.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetPluralStringByName(const NativeResourceManager *mgr,
    const char *resName, uint32_t num, char **resultValue);

/**
 * @brief Obtains the color resource.
 *
 * Obtains the color resource corresponding to the specified resource ID.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetColor(const NativeResourceManager *mgr, uint32_t resId,
    uint32_t *resultValue);

/**
 * @brief Obtains the color resource.
 *
 * Obtains the color resource corresponding to the specified resource name.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetColorByName(const NativeResourceManager *mgr, const char *resName,
    uint32_t *resultValue);

/**
 * @brief Obtains the Int resource.
 *
 * Obtains the Int resource corresponding to the specified resource ID.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetInt(const NativeResourceManager *mgr, uint32_t resId,
    int *resultValue);

/**
 * @brief Obtains the Int resource.
 *
 * Obtains the Int resource corresponding to the specified resource name.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetIntByName(const NativeResourceManager *mgr, const char *resName,
    int *resultValue);

/**
 * @brief Obtains the Float resource.
 *
 * Obtains the Int resource corresponding to the specified resource ID.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetFloat(const NativeResourceManager *mgr, uint32_t resId,
    float *resultValue);

/**
 * @brief Obtains the Float resource.
 *
 * Obtains the Float resource corresponding to the specified resource name.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetFloatByName(const NativeResourceManager *mgr, const char *resName,
    float *resultValue);

/**
 * @brief Obtains the boolean result.
 *
 * Obtains the boolean result with a specified resource ID.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resId Indicates the resource ID.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_ID_NOT_FOUND} 9001001 - Invalid resource ID.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_ID} 9001002 - No matching resource is found based on the resource ID.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetBool(const NativeResourceManager *mgr, uint32_t resId,
    bool *resultValue);

/**
 * @brief Obtains the boolean result.
 *
 * Obtains the boolean result with a specified resource name.
 *
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param resName Indicates the resource name.
 * @param resultValue the result write to resultValue.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_RES_NAME_NOT_FOUND} 9001003 - Invalid resource name.
           {@link ERROR_CODE_RES_NOT_FOUND_BY_NAME} 9001004 - No matching resource is found based on the resource name.
           {@link ERROR_CODE_RES_REF_TOO_MUCH} 9001006 - The resource is referenced cyclically.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_GetBoolByName(const NativeResourceManager *mgr, const char *resName,
    bool *resultValue);

/**
 * @brief Add overlay resources during application runtime.
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param path Indicates the application overlay path.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_OVERLAY_RES_PATH_INVALID} 9001010 - Invalid overlay path.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_AddResource(const NativeResourceManager *mgr, const char *path);

/**
 * @brief Remove overlay resources during application runtime.
 * @param mgr Indicates the pointer to {@link NativeResourceManager}
 *        {@link OH_ResourceManager_InitNativeResourceManager}.
 * @param path Indicates the application overlay path.
 * @return {@link SUCCESS} 0 - Success.
 *         {@link ERROR_CODE_INVALID_INPUT_PARAMETER} 401 - The input parameter invalid.
           Possible causes: Incorrect parameter types.
           {@link ERROR_CODE_OVERLAY_RES_PATH_INVALID} 9001010 - Invalid overlay path.
 * @since 12
 */
ResourceManager_ErrorCode OH_ResourceManager_RemoveResource(const NativeResourceManager *mgr, const char *path);
#ifdef __cplusplus
};
#endif

/** @} */
#endif // GLOBAL_OH_RESMGR_H