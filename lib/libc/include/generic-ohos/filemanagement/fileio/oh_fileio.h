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
#ifndef FILE_MANAGEMENT_FILEIO_OH_FILEIO_H
#define FILE_MANAGEMENT_FILEIO_OH_FILEIO_H

/**
 * @addtogroup FileIO
 *
 * @brief This module provides the basic file operations.
 * @since 12
 */

/**
 * @file oh_fileio.h
 *
 * @brief Provide fileio APIS.
 * @library libohfileio.so
 * @syscap SystemCapability.FileManagement.File.FileIO
 * @since 12
 */

#include "error_code.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Enumerates the file location.
 * @since 12
 */
typedef enum FileIO_FileLocation {
    /**
     * @brief Indicates the file located on the local.
     */
    LOCAL = 1,
    /**
     * @brief Indicates the file located on the cloud.
     */
    CLOUD = 2,
    /**
     * @brief Indicates the file located on the local and cloud.
     */
    LOCAL_AND_CLOUD = 3
} FileIO_FileLocation;

/**
 * @brief Get the file location.
 *
 * @param uri Input a pointer to a uri.
 * @param uriLength Input the length of the uri.
 * @param location Output the result of file location.
 * @return Return the status code of the execution.
 *         {@link PARAMETER_ERROR} 401 - Invalid input parameter, pointer is null.
 *         {@link E_NONET} 13900002 - No such file or directory.
 *         {@link E_NOMEM} 13900011 - Failed to apply for memory.
 * @since 12
 */
FileManagement_ErrCode OH_FileIO_GetFileLocation(char *uri, int uriLength,
    FileIO_FileLocation *location);

#ifdef __cplusplus
};
#endif

#endif //FILE_MANAGEMENT_FILEIO_OH_FILEIO_H