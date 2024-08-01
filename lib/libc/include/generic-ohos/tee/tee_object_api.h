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

#ifndef __TEE_OBJECT_API_H
#define __TEE_OBJECT_API_H

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
 * @file tee_object_api.h
 *
 * @brief Provides trusted storage APIs.
 *
 * You can use these APIs to implement trusted storage features.
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
 * @brief Defines <b>HANDLE_NULL</b>, which is used to denote the absence of a handle.
 *
 * @since 12
 */
#define TEE_HANDLE_NULL 0x00000000

/**
 * @brief Enumerates the usages of the key of the <b>TEE_ObjectHandle</b>.
 *
 * @since 12
 */
enum Usage_Constants {
    /** The object's key is extractable. */
    TEE_USAGE_EXTRACTABLE = 0x00000001,
    /** Used for encryption. */
    TEE_USAGE_ENCRYPT     = 0x00000002,
    /** Used for decryption. */
    TEE_USAGE_DECRYPT     = 0x00000004,
    /** Used for hash calculation. */
    TEE_USAGE_MAC         = 0x00000008,
    /** Used for creating a signature. */
    TEE_USAGE_SIGN        = 0x00000010,
    /** Used for signature verification. */
    TEE_USAGE_VERIFY      = 0x00000020,
    /** Used for key derivation. */
    TEE_USAGE_DERIVE      = 0x00000040,
    /** Used for object initialization, with all permissions assigned by default. */
    TEE_USAGE_DEFAULT     = 0xFFFFFFFF,
};

/**
 * @brief Defines information about the object pointed to by the flag of the <b>TEE_ObjectHandle</b>,
 * for example, whether the object is a persistent object or is initialized.
 *
 * @since 12
 */
enum Handle_Flag_Constants {
    /** The object is a persistent object. */
    TEE_HANDLE_FLAG_PERSISTENT      = 0x00010000,
    /** The object is initialized. */
    TEE_HANDLE_FLAG_INITIALIZED     = 0x00020000,
    /** Reserved */
    TEE_HANDLE_FLAG_KEY_SET         = 0x00040000,
    /** Reserved */
    TEE_HANDLE_FLAG_EXPECT_TWO_KEYS = 0x00080000,
};

/**
 * @brief Defines a value attribute identifier flag.
 *
 * @since 12
 */
#define TEE_ATTR_FLAG_VALUE  0x20000000

/**
 * @brief Defines a public attribute identifier flag.
 *
 * @since 12
 */
#define TEE_ATTR_FLAG_PUBLIC 0x10000000

/**
 * @brief Check whether the attribute is a buffer.
 *
 * @since 12
 */
#define TEE_ATTR_IS_BUFFER(attribute_id) ((((attribute_id) << 2) >> 31) == 0)

/**
 * @brief Check whether the attribute is a value.
 *
 * @since 12
 */
#define TEE_ATTR_IS_VALUE(attribute_id)  ((((attribute_id) << 2) >> 31) == 1)

/**
 * @brief Check whether the attribute is protected.
 *
 * @since 12
 */
#define TEE_ATTR_IS_PROTECTED(attribute_id) ((((attribute_id) << 3) >> 31) == 0)

/**
 * @brief Check whether the attribute is public.
 *
 * @since 12
 */
#define TEE_ATTR_IS_PUBLIC(attribute_id)    ((((attribute_id) << 3) >> 31) == 1)

/**
 * @brief Obtains a buffer attribute from the <b>TEE_Attribute</b> struct of the object pointed
 * to by <b>TEE_ObjectHandle</b>.
 *
 * The members in the <b>TEE_Attribute</b> struct must be <b>ref</b>. If the <b>TEE_Attribute</b> is private,
 * the <b>Usage_Constants</b> of the object must include <b>TEE_USAGE_EXTRACTABLE</b>.
 *
 * @param object Indicates the handle of the object.
 * @param attributeID Indicates the ID of the attribute to obtain, for example, <b>TEE_ObjectAttribute</b>.
 * The attribute ID can also be customized.
 * @param buffer Indicates the pointer to the buffer that stores the attribute obtained.
 * @param size Indicates the pointer to the length of the content stored.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the <b>TEE_Attribute</b> cannot be found in the object
 * or the object is not initialized.
 * @return Returns <b>TEE_ERROR_SHORT_BUFFER</b> if the buffer is too small to store the content obtained.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetObjectBufferAttribute(TEE_ObjectHandle object, uint32_t attributeID, void *buffer, size_t *size);

/**
 * @brief Obtains a value attribute from the <b>TEE_Attribute</b> of an object.
 *
 * The members of the <b>TEE_Attribute</b> struct must be values. If the <b>TEE_Attribute</b> is private,
 * the <b>Usage_Constants</b> of the object must include <b>TEE_USAGE_EXTRACTABLE</b>.
 *
 * @param object Indicates the handle of the object.
 * @param attributeID Indicates the ID of the attribute to obtain, for example, <b>TEE_ObjectAttribute</b>.
 * The attribute ID can also be customized.
 * @param a Indicates the pointer to the placeholder filled with the attribute field <b>a</b>.
 * @param b Indicates the pointer to the placeholder filled with the attribute field <b>b</b>.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the <b>TEE_Attribute</b> cannot be found in the object
 * or the object is not initialized.
 * @return Returns <b>TEE_ERROR_ACCESS_DENIED</b> if <b>TEE_Attribute</b> is private
 * but the object <b>Usage_Constants</b> does not contain the <b>TEE_USAGE_EXTRACTABLE</b> flag.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetObjectValueAttribute(TEE_ObjectHandle object, uint32_t attributeID, uint32_t *a, uint32_t *b);

/**
 * @brief Closes a <b>TEE_ObjectHandle</b> object.
 *
 * The object can be persistent or transient.
 *
 * @param object Indicates the <b>TEE_ObjectHandle</b> object to close.
 *
 * @since 12
 * @version 1.0
 */
void TEE_CloseObject(TEE_ObjectHandle object);

/**
 * @brief Allocates an uninitialized object to store keys.
 *
 * <b>objectType</b> and <b>maxObjectSize</b> must be specified.
 *
 * @param objectType Indicates the type of the object to create. The value is <b>TEE_ObjectType</b>.
 * @param maxObjectSize Indicates the maximum number of bytes of the object.
 * @param object Indicates the pointer to the handle of the newly created object.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if the memory is insufficient.
 * @return Returns <b>TEE_ERROR_NOT_SUPPORTED</b> if the object type is not supported.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AllocateTransientObject(uint32_t objectType, uint32_t maxObjectSize, TEE_ObjectHandle *object);

/**
 * @brief Releases a transient object that is previously allocated with <b>TEE_AllocateTransientObject</b>.
 *
 * After the function is called, the handle becomes invalid and all allocated resources are released.
 * <b>TEE_FreeTransientObject</b> and <b>TEE_AllocateTransientObject</b> are used in pairs.
 *
 * @param object Indicates the <b>TEE_ObjectHandle</b> to release.
 *
 * @since 12
 * @version 1.0
 */
void TEE_FreeTransientObject(TEE_ObjectHandle object);

/**
 * @brief Resets a transient object to its initial state after allocation.
 *
 * You can use an allocated object, which has not been initialized or used to store a key, to store a key.
 *
 * @param object Indicates the <b>TEE_ObjectHandle</b> to reset.
 *
 * @since 12
 * @version 1.0
 */
void TEE_ResetTransientObject(TEE_ObjectHandle object);

/**
 * @brief Populates an uninitialized object with object attributes passed by the TA in the <b>attrs</b> parameter.
 *
 * The object must be uninitialized. \n
 * The <b>attrs</b> parameter is passed by a TA.
 *
 * @param object Indicates the handle on a created but uninitialized object.
 * @param attrs Indicates the pointer to an array of object attributes, which can be one or more <b>TEE_Attribute</b>s.
 * @param attrCount Indicates the number of members in the attribute array.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if an incorrect or inconsistent attribute value is detected.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_PopulateTransientObject(TEE_ObjectHandle object, TEE_Attribute *attrs, uint32_t attrCount);

/**
 * @brief Initializes the <b>TEE_Attribute</b> of the buffer type.
 *
 * The members in the <b>TEE_Attribute</b> struct must be <b>ref</b>.
 *
 * @param attr Indicates the pointer to the <b>TEE_Attribute</b> initialized.
 * @param attributeID Indicates the ID assigned to the <b>TEE_Attribute</b>.
 * @param buffer Indicates the pointer to the buffer that stores the content to be allocated.
 * @param length Indicates the length of the assigned value, in bytes.
 *
 * @since 12
 * @version 1.0
 */
void TEE_InitRefAttribute(TEE_Attribute *attr, uint32_t attributeID, void *buffer, size_t length);

/**
 * @brief Initializes a <b>TEE_Attribute</b>.
 *
 * @param attr Indicates the pointer to the <b>TEE_Attribute</b> initialized.
 * @param attributeID Indicates the ID assigned to the <b>TEE_Attribute</b>.
 * @param a Indicates the value to be assigned to the member <b>a</b> in the <b>TEE_Attribute</b>.
 * @param b Indicates the value to be assigned to the member <b>b</b> in the <b>TEE_Attribute</b>.
 *
 * @since 12
 * @version 1.0
 */
void TEE_InitValueAttribute(TEE_Attribute *attr, uint32_t attributeID, uint32_t a, uint32_t b);

/**
 * @brief Generates a random key or a key pair and populates a transient key object with the generated key.
 *
 * @param object Indicates a transient object used to hold the generated key.
 * @param keySize Indicates the number of bytes of the key.
 * @param params Indicates the pointer to the parameters for key generation.
 * @param paramCount Indicates the number of parameters required for key generation.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_BAD_PARAMETERS</b> if the type of the key generated does not match
 * the key that can be held in the transient object.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GenerateKey(TEE_ObjectHandle object, uint32_t keySize, TEE_Attribute *params, uint32_t paramCount);

/**
 * @brief Get the information of the object data part, the total length of the data part and the current
 * position of the data stream.
 *
 * @param object Indicates the handle of the object.
 * @param pos Indicates the data stream position.
 * @param len Indicates the data stream length.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns others if the operation is failed.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_InfoObjectData(TEE_ObjectHandle object, uint32_t *pos, uint32_t *len);

/**
 * @brief Obtains <b>TEE_ObjectInfo</b>.
 *
 * This function obtains <b>TEE_ObjectInfo</b> and copies the obtained information to the pre-allocated space
 * pointed to by <b>objectInfo</b>.
 *
 * @param object Indicates the handle of the object.
 * @param objectInfo Indicates the pointer to the <b>TEE_ObjectInfo</b> obtained.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_CORRUPT_OBJECT</b> if the object is corrupted and the object handle will be closed.
 * @return Returns <b>TEE_ERROR_STORAGE_NOT_AVAILABLE</b> if the object is stored
 * in a storage area that is inaccessible currently.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetObjectInfo1(TEE_ObjectHandle object, TEE_ObjectInfo *objectInfo);

/**
 * @brief Assigns the <b>TEE_Attribute</b> of an initialized object to an uninitialized object.
 *
 * This function populates an uninitialized object with <b>TEE_Attribute</b>.
 * That is, it copies <b>TEE_Attribute</b> of <b>srcobject</b> to <b>destobject</b>.
 * The <b>TEE_Attribute</b> types and IDs of the two objects must match.
 *
 * @param destObject Indicates the uninitialized object.
 * @param srcObject Indicates the initialized object.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_CORRUPT_OBJECT</b> if the object is corrupted and the object handle will be closed.
 * @return Returns <b>TEE_ERROR_STORAGE_NOT_AVAILABLE</b> if the object is stored
 * in a storage area that is inaccessible currently.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_CopyObjectAttributes1(TEE_ObjectHandle destObject, TEE_ObjectHandle srcObject);

/**
 * @brief Restricts the <b>objectUse</b> bit of an object.
 *
 * This bit determines the usage of the key in the object. The value range is <b>Usage_Constant</b>.
 * The bit in the <b>objectUse</b> parameter can be set as follows: \n
 * If it is set to <b>1</b>, the corresponding usage flag in the object is left unchanged. \n
 * If it is set to <b>0</b>, the corresponding usage flag in the object is cleared. \n
 * The newly created object contains all <b>Usage_Constant</b>, and the usage flag can be cleared only.
 *
 * @param object Indicates the <b>TEE_ObjectHandle</b> of the target object.
 * @param objectUsage Indicates the new object usage.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 * @return Returns <b>TEE_ERROR_CORRUPT_OBJECT</b> if the object is corrupted and the object handle will be closed.
 * @return Returns <b>TEE_ERROR_STORAGE_NOT_AVAILABLE</b> if the object is stored
 * in a storage area that is inaccessible currently.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RestrictObjectUsage1(TEE_ObjectHandle object, uint32_t objectUsage);
#ifdef __cplusplus
}
#endif
/** @} */
#endif