/*
 * Copyright (c) 2022-2023 Huawei Device Co., Ltd.
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
 * @addtogroup rawfile
 * @{
 *
 * @brief Provides native functions for the resource manager to operate raw file directories and their raw files.
 *
 * You can use the resource manager to traverse, open, seek, read, and close raw files.
 *
 * @since 8
 * @version 1.0
 */

/**
 * @file raw_file.h
 *
 * @brief Declares native functions related to raw file.
 *
 * For example, you can use the functions to search for, read, and close raw files.
 *
 * @since 8
 * @version 1.0
 */
#ifndef GLOBAL_RAW_FILE_H
#define GLOBAL_RAW_FILE_H

#include <string>

#ifdef __cplusplus
extern "C" {
#endif

struct RawFile;

/**
 * @brief Provides access to a raw file.
 *
 * @since 11
 * @version 1.0
 */
struct RawFile64;

/**
 * @brief Provides access to a raw file.
 *
 *
 *
 * @since 8
 * @version 1.0
 */
typedef struct RawFile RawFile;

/**
 * @brief Provides access to a raw file.
 *
 * @since 11
 * @version 1.0
 */
typedef struct RawFile64 RawFile64;

/**
 * @brief Represent the raw file descriptor's info.
 *
 * The RawFileDescriptor is an output parameter in the {@link OH_ResourceManager_GetRawFileDescriptor},
 * and describes the raw file's file descriptor, start position and the length in the HAP.
 *
 * @since 8
 * @version 1.0
 */
typedef struct {
    /** the raw file fd */
    int fd;

    /** the offset from where the raw file starts in the HAP */
    long start;

    /** the length of the raw file in the HAP. */
    long length;
} RawFileDescriptor;

/**
 * @brief Represent the raw file descriptor's info.
 *
 * The RawFileDescriptor64 is an output parameter in the {@link OH_ResourceManager_GetRawFileDescriptor64},
 * and describes the raw file's file descriptor, start position and the length in the HAP.
 *
 * @since 11
 * @version 1.0
 */
typedef struct {
    /** the raw file fd */
    int fd;

    /** the offset from where the raw file starts in the HAP */
    int64_t start;

    /** the length of the raw file in the HAP. */
    int64_t length;
} RawFileDescriptor64;

/**
 * @brief Reads a raw file.
 *
 * This function attempts to read data of <b>length</b> bytes from the current offset.
 *
 * @param rawFile Indicates the pointer to {@link RawFile}.
 * @param buf Indicates the pointer to the buffer for receiving the data read.
 * @param length Indicates the number of bytes to read.
 * @return Returns the number of bytes read if any;
 *         if the number reaches the end of file (EOF) or rawFile is nullptr also returns <b>0</b>
 * @since 8
 * @version 1.0
 */
int OH_ResourceManager_ReadRawFile(const RawFile *rawFile, void *buf, size_t length);

/**
 * @brief Uses the 32-bit data type to seek a data read position based on the specified offset within a raw file.
 *
 * @param rawFile Indicates the pointer to {@link RawFile}.
 * @param offset Indicates the specified offset.
 * @param whence Indicates the new read position, which can be one of the following values: \n
 * <b>0</b>: The new read position is set to <b>offset</b>. \n
 * <b>1</b>: The read position is set to the current position plus <b>offset</b>. \n
 * <b>2</b>: The read position is set to the end of file (EOF) plus <b>offset</b>.
 * @return Returns <b>(int) 0</b> if the operation is successful; returns <b>(int) -1</b> if an error
 * occurs.
 * @since 8
 * @version 1.0
 */
int OH_ResourceManager_SeekRawFile(const RawFile *rawFile, long offset, int whence);

/**
 * @brief Obtains the raw file length represented by an long.
 *
 * @param rawFile Indicates the pointer to {@link RawFile}.
 * @return Returns the total length of the raw file. If rawFile is nullptr also returns 0.
 * @since 8
 * @version 1.0
 */
long OH_ResourceManager_GetRawFileSize(RawFile *rawFile);

/**
 * @brief Obtains the remaining raw file length represented by an long.
 *
 * @param rawFile Indicates the pointer to {@link RawFile}.
 * @return Returns the remaining length of the raw file. If rawFile is nullptr also returns 0.
 * @since 11
 * @version 1.0
 */
long OH_ResourceManager_GetRawFileRemainingLength(const RawFile *rawFile);

/**
 * @brief Closes an opened {@link RawFile} and releases all associated resources.
 *
 *
 *
 * @param rawFile Indicates the pointer to {@link RawFile}.
 * @see OH_ResourceManager_OpenRawFile
 * @since 8
 * @version 1.0
 */
void OH_ResourceManager_CloseRawFile(RawFile *rawFile);

/**
 * @brief Obtains the current offset of a raw file, represented by an long.
 *
 * The current offset of a raw file.
 *
 * @param rawFile Indicates the pointer to {@link RawFile}.
 * @return Returns the current offset of a raw file. If rawFile is nullptr also returns 0.
 * @since 8
 * @version 1.0
 */
long OH_ResourceManager_GetRawFileOffset(const RawFile *rawFile);

/**
 * @brief Opens the file descriptor of a raw file based on the long offset and file length.
 *
 * The opened raw file descriptor is used to read the raw file.
 *
 * @param rawFile Indicates the pointer to {@link RawFile}.
 * @param descriptor Indicates the raw file's file descriptor, start position and the length in the HAP.
 * @return Returns true: open the raw file descriptor successfully, false: the raw file is not allowed to access.
 * @since 8
 * @version 1.0
 */
bool OH_ResourceManager_GetRawFileDescriptor(const RawFile *rawFile, RawFileDescriptor &descriptor);

/**
 * @brief Closes the file descriptor of a raw file.
 *
 * The opened raw file descriptor must be released after used to avoid the file descriptor leak.
 *
 * @param descriptor Indicates the raw file's file descriptor, start position and the length in the HAP.
 * @return Returns true: closes the raw file descriptor successfully, false: closes the raw file descriptor failed.
 * @since 8
 * @version 1.0
 */
bool OH_ResourceManager_ReleaseRawFileDescriptor(const RawFileDescriptor &descriptor);

/**
 * @brief Reads a raw file.
 *
 * This function attempts to read data of <b>length</b> bytes from the current offset. using a 64-bit
 *
 * @param rawFile Indicates the pointer to {@link RawFile64}.
 * @param buf Indicates the pointer to the buffer for receiving the data read.
 * @param length Indicates the number of bytes to read.
 * @return Returns the number of bytes read if any;
 *         returns <b>0</b> if the number reaches the end of file (EOF). or rawFile is nullptr also returns 0
 * @since 11
 * @version 1.0
 */
int64_t OH_ResourceManager_ReadRawFile64(const RawFile64 *rawFile, void *buf, int64_t length);

/**
 * @brief Uses the 64-bit data type to seek a data read position based on the specified offset within a raw file.
 *
 * @param rawFile Indicates the pointer to {@link RawFile64}.
 * @param offset Indicates the specified offset.
 * @param whence Indicates the new read position, which can be one of the following values: \n
 * <b>0</b>: The new read position is set to <b>offset</b>. \n
 * <b>1</b>: The read position is set to the current position plus <b>offset</b>. \n
 * <b>2</b>: The read position is set to the end of file (EOF) plus <b>offset</b>.
 * @return Returns <b>(int) 0</b> if the operation is successful; returns <b>(int) -1</b> if an error
 * occurs.
 * @since 11
 * @version 1.0
 */
int OH_ResourceManager_SeekRawFile64(const RawFile64 *rawFile, int64_t offset, int whence);

/**
 * @brief Obtains the raw file length represented by an int64_t.
 *
 * @param rawFile Indicates the pointer to {@link RawFile64}.
 * @return Returns the total length of the raw file. If rawFile is nullptr also returns 0.
 * @since 11
 * @version 1.0
 */
int64_t OH_ResourceManager_GetRawFileSize64(RawFile64 *rawFile);

/**
 * @brief Obtains the remaining raw file length represented by an int64_t.
 *
 * @param rawFile Indicates the pointer to {@link RawFile64}.
 * @return Returns the remaining length of the raw file. If rawFile is nullptr also returns 0.
 * @since 11
 * @version 1.0
 */
int64_t OH_ResourceManager_GetRawFileRemainingLength64(const RawFile64 *rawFile);

/**
 * @brief Closes an opened {@link RawFile64} and releases all associated resources.
 *
 *
 *
 * @param rawFile Indicates the pointer to {@link RawFile64}.
 * @see OH_ResourceManager_OpenRawFile64
 * @since 11
 * @version 1.0
 */
void OH_ResourceManager_CloseRawFile64(RawFile64 *rawFile);

/**
 * @brief Obtains the current offset of a raw file, represented by an int64_t.
 *
 * The current offset of a raw file.
 *
 * @param rawFile Indicates the pointer to {@link RawFile64}.
 * @return Returns the current offset of a raw file. If rawFile is nullptr also returns 0.
 * @since 11
 * @version 1.0
 */
int64_t OH_ResourceManager_GetRawFileOffset64(const RawFile64 *rawFile);

/**
 * @brief Opens the file descriptor of a raw file based on the int64_t offset and file length.
 *
 * The opened raw file descriptor is used to read the raw file.
 *
 * @param rawFile Indicates the pointer to {@link RawFile64}.
 * @param descriptor Indicates the raw file's file descriptor, start position and the length in the HAP.
 * @return Returns true: open the raw file descriptor successfully, false: the raw file is not allowed to access.
 * @since 11
 * @version 1.0
 */
bool OH_ResourceManager_GetRawFileDescriptor64(const RawFile64 *rawFile, RawFileDescriptor64 *descriptor);

/**
 * @brief Closes the file descriptor of a raw file.
 *
 * The opened raw file descriptor must be released after used to avoid the file descriptor leak.
 *
 * @param descriptor Indicates the raw file's file descriptor, start position and the length in the HAP.
 * @return Returns true: closes the raw file descriptor successfully, false: closes the raw file descriptor failed.
 * @since 11
 * @version 1.0
 */
bool OH_ResourceManager_ReleaseRawFileDescriptor64(const RawFileDescriptor64 *descriptor);

#ifdef __cplusplus
};
#endif

/** @} */
#endif // GLOBAL_RAW_FILE_H