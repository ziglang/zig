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

#ifndef __TEE_TRUSTED_STORAGE_API_H
#define __TEE_TRUSTED_STORAGE_API_H

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
 * @file tee_trusted_storage_api.h
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
#include "tee_object_api.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Defines the start position in the data stream associated with an object.
 * It is used in the <b>TEE_SeekObjectData</b> function.
 *
 * @since 12
 */
enum __TEE_Whence {
    /* Set the start position to the beginning of the data stream. */
    TEE_DATA_SEEK_SET = 0,
    /* Set the start position to the current data stream position. */
    TEE_DATA_SEEK_CUR,
    /* Set the start position to the end of the data stream. */
    TEE_DATA_SEEK_END
};

struct __TEE_ObjectEnumHandle;

/**
 * @brief Defines the pointer to <b>TEE_ObjectEnumHandle</b>.
 *
 * @see __TEE_ObjectEnumHandle
 *
 * @since 12
 */
typedef struct __TEE_ObjectEnumHandle *TEE_ObjectEnumHandle;

typedef uint32_t TEE_Whence;

/**
 * @brief Defines the storage ID, which identifies the storage space of the application.
 *
 * @since 12
 */
enum Object_Storage_Constants {
    /* Separate private storage space for each application. */
    TEE_OBJECT_STORAGE_PRIVATE = 0x00000001,
    /* Separate personal storage space for application. */
    TEE_OBJECT_STORAGE_PERSO   = 0x00000002,
    /* Space for secure flash storage. */
    TEE_OBJECT_SEC_FLASH       = 0x80000000,
    /* Credential encrypted storage space. */
    TEE_OBJECT_STORAGE_CE      = 0x80000002,
};

/**
 * @brief Defines the system resource constraints, such as the maximum value for the data stream position indicator.
 *
 * @since 12
 */
enum Miscellaneous_Constants {
    /* Maximum length that the position indicator of the data stream can take. */
    TEE_DATA_MAX_POSITION = 0xFFFFFFFF,
    /* Maximum length of the object ID, which can extend to 128 bytes. */
    TEE_OBJECT_ID_MAX_LEN = 64,
};

/**
 * @brief Defines the maximum number of bytes that can be held in a data stream.
 *
 * @since 12
 */
enum TEE_DATA_Size {
    TEE_DATA_OBJECT_MAX_SIZE = 0xFFFFFFFF
};

/**
 * @brief Defines the <b>handleFlags</b> of a <b>TEE_ObjectHandle</b>.
 * The <b>handleFlags</b> determines the access permissions to the data stream associated with the object.
 *
 * @since 12
 */
enum Data_Flag_Constants {
    /** The data stream can be read. */
    TEE_DATA_FLAG_ACCESS_READ = 0x00000001,
    /** The data stream can be written or truncated. */
    TEE_DATA_FLAG_ACCESS_WRITE = 0x00000002,
    /** The data stream can be deleted or renamed. */
    TEE_DATA_FLAG_ACCESS_WRITE_META = 0x00000004,
    /** Multiple TEE_ObjectHandles can be opened for concurrent read. */
    TEE_DATA_FLAG_SHARE_READ = 0x00000010,
    /** Multiple TEE_ObjectHandles can be opened for concurrent write. */
    TEE_DATA_FLAG_SHARE_WRITE = 0x00000020,
    /** Reserved. */
    TEE_DATA_FLAG_CREATE = 0x00000200,
    /**
     * Protect the existing file with the same name. Throw an error if the file with the same name exists;
     * create a data file otherwise.
     */
    TEE_DATA_FLAG_EXCLUSIVE = 0x00000400,
    /**
     * Protect the existing file with the same name. Throw an error if the file with the same name exists;
     * create a data file otherwise.
     */
    TEE_DATA_FLAG_OVERWRITE = 0x00000400,
    /** Use AES256 if bit 28 is 1; use AES128 if bit 28 is 0. */
    TEE_DATA_FLAG_AES256 =  0x10000000,
    /** If bit 29 is set to 1, open the earlier version preferentially. */
    TEE_DATA_FLAG_OPEN_AESC = 0x20000000,
};

/**
 * @brief Creates a persistent object.
 *
 * This function creates a persistent object with initialized <b>TEE_Attribute</b> and data stream.
 * You can use the returned handle to access the <b>TEE_Attribute</b> and data stream of the object.
 *
 * @param storageID Indicates the storage to use. The value is specified by <b>Object_Storage_Constants</b>.
 * @param ojbectID Indicates the pointer to the object identifier, that is, the name of the object to create.
 * @param objectIDLen Indicates the length of the object identifier, in bytes. It cannot exceed 128 bytes.
 * @param flags Indicates the flags of the object created. The value can be
 * one or more of <b>Data_Flag_Constants</b> or <b>Handle_Flag_Constants</b>.
 * @param attributes Indicates the <b>TEE_ObjectHandle</b> of a transient object from which to take
 * <b>TEE_Attribute</b>. It can be <b>TEE_HANDLE_NULL</b> if the persistent object contains no attribute.
 * @param initialData Indicates the pointer to the initial data used to initialize the data stream data.
 * @param initialDataLen Indicates the length of the initial data, in bytes.
 * @param object Indicates the pointer to the <b>TEE_ObjectHandle</b> returned
 * after the function is successfully executed.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the storage specified by <b>storageID</b> does not exist.
 *         Returns <b>TEE_ERROR_ACCESS_CONFLICT</b> if an access conflict occurs.
 *         Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if the memory is not sufficient to complete the operation.
 *         Returns <b>TEE_ERROR_STORAGE_NO_SPACE</b> if there is no enough space to create the object.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_CreatePersistentObject(uint32_t storageID, const void *ojbectID, size_t objectIDLen, uint32_t flags,
                                      TEE_ObjectHandle attributes, const void *initialData, size_t initialDataLen,
                                      TEE_ObjectHandle *object);

/**
 * @brief Opens an existing persistent object.
 *
 * The handle returned can be used to access the <b>TEE_Attribute</b> and data stream of the object.
 *
 * @param storageID Indicates the storage to use. The value is specified by <b>Object_Storage_Constants</b>.
 * @param ojbectID Indicates the pointer to the object identifier, that is, the name of the object to open.
 * @param objectIDLen Indicates the length of the object identifier, in bytes. It cannot exceed 128 bytes.
 * @param flags Indicates the flags of the object opened.
 * The value can be one or more of <b>Data_Flag_Constants</b> or <b>Handle_Flag_Constants</b>.
 * @param object Indicates the pointer to the <b>TEE_ObjectHandle</b> returned
 * after the function is successfully executed.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_ITEM_NOT_FOUND</b> if the storage specified by <b>storageID</b> does not exist
 * or the object identifier cannot be found in the storage.
 *         Returns <b>TEE_ERROR_ACCESS_CONFLICT</b> if an access conflict occurs.
 *         Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if the memory is not sufficient to complete the operation.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_OpenPersistentObject(uint32_t storageID, const void *ojbectID, size_t objectIDLen, uint32_t flags,
                                    TEE_ObjectHandle *object);

/**
 * @brief Reads data from the data stream associated with an object into the buffer.
 *
 * The <b>TEE_ObjectHandle</b> of the object must have been opened with the <b>TEE_DATA_FLAG_ACCESS_READ</b> permission.
 *
 * @param ojbect Indicates the <b>TEE_ObjectHandle</b> of the object to read.
 * @param buffer Indicates the pointer to the buffer used to store the data read.
 * @param size Indicates the number of bytes to read.
 * @param count Indicates the pointer to the variable that contains the number of bytes read.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if the memory is not sufficient to complete the operation.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_ReadObjectData(TEE_ObjectHandle ojbect, void *buffer, size_t size, uint32_t *count);

/**
 * @brief Writes bytes from the buffer to the data stream associated with an object.
 *
 * The <b>TEE_ObjectHandle</b> must have been opened with the <b>TEE_DATA_FLAG_ACCESS_WRITE</b> permission.
 *
 * @param ojbect Indicates the <b>TEE_ObjectHandle</b> of the object.
 * @param buffer Indicates the pointer to the buffer that stores the data to be written.
 * @param size Indicates the number of bytes to be written. It cannot exceed 4096 bytes.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if the memory is not sufficient to complete the operation.
 *         Returns <b>TEE_ERROR_STORAGE_NO_SPACE</b> if the storage space is not sufficient to complete the operation.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_WriteObjectData(TEE_ObjectHandle ojbect, const void *buffer, size_t size);

/**
 * @brief Changes the size of a data stream.
 *
 * If the size is less than the current size of the data stream, all bytes beyond <b>size</b> are deleted. If the size
 * is greater than the current size of the data stream, add 0s at the end of the stream to extend the stream.
 * The object handle must be opened with the <b>TEE_DATA_FLAG_ACCESS_WRITE</b> permission.
 *
 * @param object Indicates the <b>TEE_ObjectHandle</b> of the object.
 * @param size Indicates the new size of the data stream. It cannot exceed 4096 bytes.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_STORAGE_NO_SPACE</b> if the storage space is not sufficient to complete the operation.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_TruncateObjectData(TEE_ObjectHandle object, size_t size);

/**
 * @brief Sets the position of the data stream to which <b>TEE_ObjectHandle</b> points.
 *
 * The data position indicator is determined by the start position and an offset together.
 * The <b>whence</b> parameter determines the start position. Its value is set in <b>TEE_Whence</b> as follows:
 * <b>TEE_DATA_SEEK_SET = 0</b>: The start position is the beginning of the data stream.
 * <b>TEE_DATA_SEEK_CUR</b>: The start position is the current position of the data stream.
 * <b>TEE_DATA_SEEK_END</b>: The start position is the end of the data stream.
 * If the parameter <b>offset</b> is a positive number, the data position is moved forward.
 * If <b>offset</b> is a negative number, the data position is moved backward.
 *
 * @param object Indicates the <b>TEE_ObjectHandle</b> of the object.
 * @param offset Indicates the number of bytes to move the data position. It cannot exceed 4096 bytes.
 * @param whence Indicates the start position in the data stream to calculate the new position.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_OVERFLOW</b> if the position indicator resulting from this operation
 * is greater than <b>TEE_DATA_MAX_POSIT</b>.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SeekObjectData(TEE_ObjectHandle object, int32_t offset, TEE_Whence whence);

/**
 * @brief Synchronizes the opened <b>TEE_ObjectHandle</b> and the corresponding security attribute file to the disk.
 *
 * @param object Indicates the <b>TEE_ObjectHandle</b> of the object.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SyncPersistentObject(TEE_ObjectHandle object);

/**
 * @brief Changes the object identifier.
 *
 * The <b>TEE_ObjectHandle</b> must have been opened with the <b>TEE_DATA_FLAG_ACCESS_WRITE_META</b> permission.
 *
 * @param object Indicates the handle of the target object.
 * @param newObjectID Indicates the pointer to the new object identifier.
 * @param newObjectIDLen Indicates the length of the new object identifier.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RenamePersistentObject(TEE_ObjectHandle object, void *newObjectID, size_t newObjectIDLen);

/**
 * @brief Allocates a handle on an uninitialized object enumerator.
 *
 * @param obj_enumerator Indicates the pointer to the handle of the newly created object enumerator.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_OUT_OF_MEMORY</b> if the memory is not sufficient to complete the operation.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_AllocatePersistentObjectEnumerator(TEE_ObjectEnumHandle *obj_enumerator);

/**
 * @brief Releases all resources associated with an object enumerator handle.
 *
 * After this function is called, the object handle is no longer valid and all resources associated with
 * the object enumerator handle will be reclaimed.
 * <b>TEE_FreePersistentObjectEnumerator</b> and <b>TEE_AllocatePersistentObjectEnumerator</b>are used in pairs.
 *
 * @param obj_enumerator Indicates the <b>TEE_ObjectEnumHandle</b> to release.
 *
 * @since 12
 * @version 1.0
 */
void TEE_FreePersistentObjectEnumerator(TEE_ObjectEnumHandle obj_enumerator);

/**
 * @brief Resets an object enumerator handle to its initial state after allocation.
 *
 * @param obj_enumerator Indicates the <b>TEE_ObjectEnumHandle</b> of the object enumerator to reset.
 *
 * @since 12
 * @version 1.0
 */
void TEE_ResetPersistentObjectEnumerator(TEE_ObjectEnumHandle obj_enumerator);

/**
 * @brief Starts the enumeration of all the objects in the given trusted storage.
 *
 * The object information can be obtained by using <b>TEE_GetNextPersistentObject</b>.
 *
 * @param obj_enumerator Indicates the <b>TEE_ObjectEnumHandle</b> of the object enumerator.
 * @param storage_id Indicates the storage, in which the objects are enumerated.
 * The value is specified by <b>Object_Storage_Constants</b>.
 * Currently, only <b>TEE_STORAGE_PRIVATE</b> is supported.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ITEM_NOT_FOUND</b> if <b>storageID</b> is not <b>TEE_STORAGE_PRIVATE</b>
 * or there is no object in the specified storage.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_StartPersistentObjectEnumerator(TEE_ObjectEnumHandle obj_enumerator, uint32_t storage_id);

/**
 * @brief Obtains the next object in the object enumerator.
 *
 * Information such as <b>TEE_ObjectInfo</b>, <b>objectID</b>, and <b>objectIDLen</b> will be obtained.
 *
 * @param obj_enumerator Indicates the <b>TEE_ObjectEnumHandle</b> of the object enumerator.
 * @param object_info Indicates the pointer to the obtained<b>TEE_ObjectInfo</b>.
 * @param object_id Indicates the pointer to the buffer used to store the obtained <b>objectID</b>.
 * @param object_id_len Indicates the pointer to the <b>objectIDLen</b>.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ITEM_NOT_FOUND</b> if the object enumerator has no element
 * or the enumerator has not been initialized.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_GetNextPersistentObject(TEE_ObjectEnumHandle obj_enumerator,
    TEE_ObjectInfo *object_info, void *object_id, size_t *object_id_len);

/**
 * @brief Closes a <b>TEE_ObjectHandle</b> and deletes the object.
 *
 * The object must be a persistent object, and the object handle must have been opened with
 * the <b>TEE_DATA_FLAG_ACCESS_WRITE_META</b> permission.
 *
 * @param object Indicates the object handle to close.
 *
 * @return Returns <b>TEE_SUCCESS</b> if the operation is successful.
 *         Returns <b>TEE_ERROR_STORAGE_NOT_AVAILABLE</b> if the object is stored
 * in a storage area that is inaccessible currently.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_CloseAndDeletePersistentObject1(TEE_ObjectHandle object);

#ifdef __cplusplus
}
#endif
/** @} */
#endif