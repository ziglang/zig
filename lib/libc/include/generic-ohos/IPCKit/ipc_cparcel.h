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

#ifndef CAPI_INCLUDE_IPC_CPARCEL_H
#define CAPI_INCLUDE_IPC_CPARCEL_H

/**
 * @addtogroup OHIPCParcel
 * @{
 *
 * @brief Defines C interfaces for IPC serialization and deserialization.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @since 12
 */

/**
 * @file ipc_cparcel.h
 *
 * @brief Defines C interfaces for IPC serialization and deserialization.
 *
 * @library libipc_capi.so
 * @kit IPCKit
 * @syscap SystemCapability.Communication.IPC.Core
 * @since 12
 */

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
* @brief Defines an IPC serialized object.
*
* @syscap SystemCapability.Communication.IPC.Core
* @since 12
*/
struct OHIPCParcel;

/**
* @brief Typedef an IPC serialized object.
*
* @syscap SystemCapability.Communication.IPC.Core
* @since 12
*/
typedef struct OHIPCParcel OHIPCParcel;

/**
* @brief Defines an IPC remote proxy object.
*
* @syscap SystemCapability.Communication.IPC.Core
* @since 12
*/
struct OHIPCRemoteProxy;

/**
* @brief Typedef an IPC remote proxy object.
*
* @syscap SystemCapability.Communication.IPC.Core
* @since 12
*/
typedef struct OHIPCRemoteProxy OHIPCRemoteProxy;

/**
* @brief Defines an IPC remote service object.
*
* @syscap SystemCapability.Communication.IPC.Core
* @since 12
*/
struct OHIPCRemoteStub;

/**
* @brief Typedef an IPC remote service object.
*
* @syscap SystemCapability.Communication.IPC.Core
* @since 12
*/
typedef struct OHIPCRemoteStub OHIPCRemoteStub;

/**
 * @brief Allocates memory.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param len Length of the memory to allocate.
 * @return Returns the address of the memory allocated if the operation is successful; returns NULL otherwise.
 * @since 12
 */
typedef void* (*OH_IPC_MemAllocator)(int32_t len);

/**
 * @brief Creates an <b>OHIPCParcel</b> object, which cannot exceed 204,800 bytes.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @return Returns the pointer to the <b>OHIPCParcel</b> object created if the operation is successful;
 * returns NULL otherwise.
 * @since 12
 */
OHIPCParcel* OH_IPCParcel_Create(void);

/**
 * @brief Destroys an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the <b>OHIPCParcel</b> object to destroy.
 * @since 12
 */
void OH_IPCParcel_Destroy(OHIPCParcel *parcel);

/**
 * @brief Obtains the size of the data contained in an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @return Returns the data size obtained if the operation is successful.\n
 * Returns <b>-1</b> if invalid parameters are found.
 * @since 12
 */
int OH_IPCParcel_GetDataSize(const OHIPCParcel *parcel);

/**
 * @brief Obtains the number of bytes that can be written to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @return Returns the number of bytes that can be written to the <b>OHIPCParcel</b> object. \n
 * Returns <b>-1</b> if invalid parameters are found.
 * @since 12
 */
int OH_IPCParcel_GetWritableBytes(const OHIPCParcel *parcel);

/**
 * @brief Obtains the number of bytes that can be read from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @return Returns the number of bytes that can be read from the <b>OHIPCParcel</b> object. \n
 * Returns <b>-1</b> if invalid parameters are found.
 * @since 12
 */
int OH_IPCParcel_GetReadableBytes(const OHIPCParcel *parcel);

/**
 * @brief Obtains the position where data is read in an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @return Returns the position obtained if the operation is successful. \n
 * Returns <b>-1</b> if invalid parameters are found.
 * @since 12
 */
int OH_IPCParcel_GetReadPosition(const OHIPCParcel *parcel);

/**
 * @brief Obtains the position where data is written in an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @return Returns the position obtained if the operation is successful. \n
 * Returns <b>-1</b> if invalid parameters are found.
 * @since 12
 */
int OH_IPCParcel_GetWritePosition(const OHIPCParcel *parcel);

/**
 * @brief Resets the position to read data in an IPC parcel.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param newReadPos New position to read data. The value ranges from <b>0</b> to the current data size.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found.
 * @since 12
 */
int OH_IPCParcel_RewindReadPosition(OHIPCParcel *parcel, uint32_t newReadPos);

/**
 * @brief Resets the position to write data in an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param newWritePos New position to write data. The value ranges from <b>0</b> to the current data size.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found.
 * @since 12
 */
int OH_IPCParcel_RewindWritePosition(OHIPCParcel *parcel, uint32_t newWritePos);

/**
 * @brief Writes an int8_t value to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Value to write.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteInt8(OHIPCParcel *parcel, int8_t value);

/**
 * @brief Reads an int8_t value from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Pointer to the data to read. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_READ_ERROR} if the read operation fails.
 * @since 12
 */
int OH_IPCParcel_ReadInt8(const OHIPCParcel *parcel, int8_t *value);

/**
 * @brief Writes an int16_t value to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Value to write.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteInt16(OHIPCParcel *parcel, int16_t value);

/**
 * @brief Reads an int16_t value from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Pointer to the data to read. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_READ_ERROR} if the read operation fails.
 * @since 12
 */
int OH_IPCParcel_ReadInt16(const OHIPCParcel *parcel, int16_t *value);

/**
 * @brief Writes an int32_t value to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Value to write.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteInt32(OHIPCParcel *parcel, int32_t value);

/**
 * @brief Reads an int32_t value from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Pointer to the data to read. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_READ_ERROR} if the read operation fails.
 * @since 12
 */
int OH_IPCParcel_ReadInt32(const OHIPCParcel *parcel, int32_t *value);

/**
 * @brief Writes an int64_t value to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Value to write.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteInt64(OHIPCParcel *parcel, int64_t value);

/**
 * @brief Reads an int64_t value from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Pointer to the data to read. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_READ_ERROR} if the read operation fails.
 * @since 12
 */
int OH_IPCParcel_ReadInt64(const OHIPCParcel *parcel, int64_t *value);

/**
 * @brief Writes a float value to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Value to write.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteFloat(OHIPCParcel *parcel, float value);

/**
 * @brief Reads a float value from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Pointer to the data to read. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_READ_ERROR} if the read operation fails.
 * @since 12
 */
int OH_IPCParcel_ReadFloat(const OHIPCParcel *parcel, float *value);

/**
 * @brief Writes a double value to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Value to write.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteDouble(OHIPCParcel *parcel, double value);

/**
 * @brief Reads a double value from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param value Pointer to the data to read. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_READ_ERROR} if the read operation fails.
 * @since 12
 */
int OH_IPCParcel_ReadDouble(const OHIPCParcel *parcel, double *value);

/**
 * @brief Writes a string including a string terminator to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param str String to write, which cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteString(OHIPCParcel *parcel, const char *str);

/**
 * @brief Reads a string from an <b>OHIPCParcel</b> object. You can obtain the length of the string from <b>strlen</b>.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @return Returns the address of the string read if the operation is successful;
 * returns NULL if the operation fails or invalid parameters are found.
 * @since 12
 */
const char* OH_IPCParcel_ReadString(const OHIPCParcel *parcel);

/**
 * @brief Writes data of the specified length from the memory to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param buffer Pointer to the address of the memory information to write.
 * @param len Length of the data to write.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteBuffer(OHIPCParcel *parcel, const uint8_t *buffer, int32_t len);

/**
 * @brief Reads memory information of the specified length from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param len Length of the memory to be read.
 * @return Returns the memory address read if the operation is successful;
 * returns NULL if invalid parameters are found or <b>len</b> exceeds the readable length of <b>parcel</b>.
 * @since 12
 */
const uint8_t* OH_IPCParcel_ReadBuffer(const OHIPCParcel *parcel, int32_t len);

/**
 * @brief Writes an <b>OHIPCRemoteStub</b> object to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param stub Pointer to the <b>OHIPCRemoteStub</b> object to write. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteRemoteStub(OHIPCParcel *parcel, const OHIPCRemoteStub *stub);

/**
 * @brief Reads the <b>OHIPCRemoteStub</b> object from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @return Returns the pointer to the <b>OHIPCRemoteStub</b> object read if the operation is successful;
 * returns NULL otherwise.
 * @since 12
 */
OHIPCRemoteStub* OH_IPCParcel_ReadRemoteStub(const OHIPCParcel *parcel);

/**
 * @brief Writes an <b>OHIPCRemoteProxy</b> object to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param proxy Pointer to the <b>OHIPCRemoteProxy</b> object to write. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteRemoteProxy(OHIPCParcel *parcel, const OHIPCRemoteProxy *proxy);

/**
 * @brief Reads the <b>OHIPCRemoteProxy</b> object from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @return Returns the pointer to the <b>OHIPCRemoteProxy</b> object read if the operation is successful;
 * returns NULL otherwise.
 * @since 12
 */
OHIPCRemoteProxy* OH_IPCParcel_ReadRemoteProxy(const OHIPCParcel *parcel);

/**
 * @brief Writes a file descriptor to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param fd File descriptor to write.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteFileDescriptor(OHIPCParcel *parcel, int32_t fd);

/**
 * @brief Reads a file descriptor from an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param fd Pointer to the file descriptor to read. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_READ_ERROR} if the read operation fails.
 * @since 12
 */
int OH_IPCParcel_ReadFileDescriptor(const OHIPCParcel *parcel, int32_t *fd);

/**
 * @brief Appends data to an <b>OHIPCParcel</b> object.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param data Pointer to the data to append. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the operation fails.
 * @since 12
 */
int OH_IPCParcel_Append(OHIPCParcel *parcel, const OHIPCParcel *data);

/**
 * @brief Writes an interface token to an <b>OHIPCParcel</b> object for interface identity verification.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param token Pointer to the interface token to write. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_WRITE_ERROR} if the data write operation fails.
 * @since 12
 */
int OH_IPCParcel_WriteInterfaceToken(OHIPCParcel *parcel, const char *token);

/**
 * @brief Reads an interface token from an <b>OHIPCParcel</b> object for interface identity verification.
 *
 * @syscap SystemCapability.Communication.IPC.Core
 * @param parcel Pointer to the target <b>OHIPCParcel</b> object. It cannot be NULL.
 * @param token Pointer to the address of the memory for storing the interface token.
 * The memory is allocated by the allocator provided by the user and needs to be released. This pointer cannot be NULL.
 * If an error code is returned, you still need to check whether the memory is empty and release the memory.
 * Otherwise, memory leaks may occur.
 * @param len Pointer to the length of the interface token read, including the terminator. It cannot be NULL.
 * @param allocator Memory allocator specified by the user for allocating memory for <b>token</b>. It cannot be NULL.
 * @return Returns {@link OH_IPC_ErrorCode#OH_IPC_SUCCESS} if the operation is successful. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_CHECK_PARAM_ERROR} if invalid parameters are found. \n
 * Returns {@link OH_IPC_ErrorCode#OH_IPC_PARCEL_READ_ERROR} if the read operation fails.
 * @since 12
 */
int OH_IPCParcel_ReadInterfaceToken(const OHIPCParcel *parcel, char **token, int32_t *len,
    OH_IPC_MemAllocator allocator);

#ifdef __cplusplus
}
#endif

/** @} */
#endif