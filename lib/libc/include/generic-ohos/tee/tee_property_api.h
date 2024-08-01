/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef TEE_PROPERTY_API_H
#define TEE_PROPERTY_API_H

/**
 * @addtogroup TeeTrusted
 * @{
 *
 * @brief TEE(Trusted Excution Environment) API.
 * Provides security capability APIs such as trusted storage, encryption and decryption,
 * and trusted time for trusted application development.
 *
 * @since 12
 */

/**
 * @file tee_property_api.h
 *
 * @brief Reference of TEE object api definitions.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include "tee_defines.h"

#ifdef __cplusplus
extern "C" {
#endif
/**
 * The definitions below are defined by Global Platform or Platform SDK released previously
 * for compatibility.
 * Do not make any change to the content below.
 */

/**
 * @brief Enumerates the types of the property set.
 *
 * @since 12
 */
typedef enum {
    TEE_PROPSET_UNKNOW             = 0,
    TEE_PROPSET_TEE_IMPLEMENTATION = 0xFFFFFFFD,
    TEE_PROPSET_CURRENT_CLIENT     = 0xFFFFFFFE,
    TEE_PROPSET_CURRENT_TA         = 0xFFFFFFFF,
} Pseudo_PropSetHandle;

typedef uint32_t TEE_PropSetHandle;

/**
 * @brief Obtains a property from a property set and converts its value into a printable string.
 *
 *
 * @param propsetOrEnumerator Indicates one of the TEE_PROPSET_XXX pseudo-handles or a handle on a property enumerator.
 * @param name Indicates the pointer to the zero-terminated string containing the name of the property to obtain.
 * @param valueBuffer Indicates the pointer to the buffer for holding the property value obtained.
 * @param valueBufferLen Indicates the pointer to the buffer length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the target property cannot be obtained.
 * @return Returns <b>TEE_ERROR_SHORT_BUFFER</b> if the value buffer is too small to hold the property value obtained.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetPropertyAsString(TEE_PropSetHandle propsetOrEnumerator, const char *name, char *valueBuffer,
                                   size_t *valueBufferLen);

/**
 * @brief Obtains a property from a property set and converts its value into a Boolean value.
 *
 * @param propsetOrEnumerator Indicates one of the TEE_PROPSET_XXX pseudo-handles or a handle on a property enumerator.
 * @param name Indicates the pointer to the zero-terminated string containing the name of the property to obtain.
 * @param value Indicates the pointer to the variable that holds the property value obtained.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the target property cannot be obtained.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetPropertyAsBool(TEE_PropSetHandle propsetOrEnumerator, const char *name, bool *value);

/**
 * @brief Obtains a property from a property set and converts its value into a 32-bit unsigned integer.
 *
 * @param propsetOrEnumerator Indicates one of the TEE_PROPSET_XXX pseudo-handles or a handle on a property enumerator.
 * @param name Indicates the pointer to the zero-terminated string containing the name of the property to obtain.
 * @param value Indicates the pointer to the variable that holds the property value obtained.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the target property cannot be obtained.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetPropertyAsU32(TEE_PropSetHandle propsetOrEnumerator, const char *name, uint32_t *value);

#if defined(API_LEVEL) && (API_LEVEL >= API_LEVEL1_2)
/**
 * @brief Obtains a property from a property set and converts its value into a 64-bit unsigned integer.
 *
 * @param propsetOrEnumerator Indicates one of the TEE_PROPSET_XXX pseudo-handles or a handle on a property enumerator.
 * @param name Indicates the pointer to the zero-terminated string containing the name of the property to obtain.
 * @param value Indicates the pointer to the variable that holds the property value obtained.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the target property cannot be obtained.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetPropertyAsU64(TEE_PropSetHandle propsetOrEnumerator, const char *name, uint64_t *value);
#endif // API_LEVEL

/**
 * @brief Obtains a property from a property set and converts its value into a binary block.
 *
 * @param propsetOrEnumerator Indicates one of the TEE_PROPSET_XXX pseudo-handles or a handle on a property enumerator.
 * @param name Indicates the pointer to the zero-terminated string containing the name of the property to obtain.
 * @param valueBuffer Indicates the pointer to the buffer for holding the property value obtained.
 * @param valueBufferLen Indicates the pointer to the buffer length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the target property cannot be obtained.
 * @return TEE_ERROR_SHORT_BUFFER the value buffer is not large enough to hold the whole property value
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetPropertyAsBinaryBlock(TEE_PropSetHandle propsetOrEnumerator, const char *name, void *valueBuffer,
                                        size_t *valueBufferLen);

/**
 * @brief Obtains a property from a property set and converts its value to the <b>TEE_UUID</b> struct.
 *
 * @param propsetOrEnumerator Indicates one of the TEE_PROPSET_XXX pseudo-handles or a handle on a property enumerator.
 * @param name Indicates the pointer to the zero-terminated string containing the name of the property to obtain.
 * @param value Indicates the pointer to the variable that holds the property value obtained.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the target property cannot be obtained.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetPropertyAsUUID(TEE_PropSetHandle propsetOrEnumerator, const char *name, TEE_UUID *value);

/**
 * @brief Obtains a property from a property set and converts its value to the <b>TEE_Identity</b> struct.
 *
 * @param propsetOrEnumerator Indicates one of the TEE_PROPSET_XXX pseudo-handles or a handle on a property enumerator.
 * @param name Indicates the pointer to the zero-terminated string containing the name of the property to obtain.
 * @param value Indicates the pointer to the variable that holds the property value obtained.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the target property cannot be obtained.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetPropertyAsIdentity(TEE_PropSetHandle propsetOrEnumerator, const char *name, TEE_Identity *value);

/**
 * @brief Allocates a property enumerator object.
 *
 * @param enumerator Indicates the pointer to the property enumerator filled with an opaque handle.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if there is no enough resources to allocate the property enumerator.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AllocatePropertyEnumerator(TEE_PropSetHandle *enumerator);

/**
 * @brief Releases a property enumerator object.
 *
 * @param enumerator Indicates the handle on the property enumerator to release.
 *
 * @return void
 *
 * @since 12
 * @version 1.0
 */
void TEE_FreePropertyEnumerator(TEE_PropSetHandle enumerator);

/**
 * @brief Starts to enumerate the properties in an enumerator.
 *
 * @param enumerator Indicates the handle on the enumerator.
 * @param propSet Indicates the pseudo-handle on the property set to enumerate.
 *
 * @return void
 *
 * @since 12
 * @version 1.0
 */
void TEE_StartPropertyEnumerator(TEE_PropSetHandle enumerator, TEE_PropSetHandle propSet);

/**
 * @brief Resets a property enumerator immediately after allocation.
 *
 * @param enumerator Indicates the handle on the enumerator to reset.
 *
 * @return void
 *
 * @since 12
 * @version 1.0
 */
void TEE_ResetPropertyEnumerator(TEE_PropSetHandle enumerator);

/**
 * @brief Obtains the name of this property in an enumerator.
 *
 * @param enumerator Indicates the handle on the enumerator.
 * @param nameBuffer Indicates the pointer to the buffer that stores the property name obtained.
 * @param nameBufferLen Indicates the pointer to the buffer length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the property is not found because the enumerator has not started
 * or has reached the end of the property set.
 * @return Returns <b>TEE_ERROR_SHORT_BUFFER</b> if the buffer is too small to hold the property name.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetPropertyName(TEE_PropSetHandle enumerator, void *nameBuffer, size_t *nameBufferLen);

/**
 * @brief Obtains the next property in an enumerator.
 *
 * @param enumerator Indicates the handle on the enumerator.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the property is not found because the enumerator
 * has not started or has reached the end of the property set.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetNextProperty(TEE_PropSetHandle enumerator);

#ifdef __cplusplus
}
#endif
/** @} */
#endif