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

#ifndef FILE_MANAGEMENT_OH_FILE_URI_H
#define FILE_MANAGEMENT_OH_FILE_URI_H

/**
 * @file oh_file_uri.h
 *
 * @brief uri verification and conversion
 * @library libohfileuri.so
 * @syscap SystemCapability.FileManagement.AppFileService
 * @since 12
 */

#include "error_code.h"
#include "stdbool.h"
#include <stdio.h>
#include <stdlib.h>
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Get uri From path.
 *
 * @param path Input a pointer to the path string.
 * @param length The length of the input path.
 * @param result Output a pointer to a uri string. Please use free() to clear the resource.
 * @return Returns the status code of the execution.
 * @syscap SystemCapability.FileManagement.AppFileService
 * @since 12
 */
FileManagement_ErrCode OH_FileUri_GetUriFromPath(const char *path, unsigned int length, char **result);

/**
 * @brief Get path From uri.
 *
 * @param uri Input a pointer to the uri string.
 * @param length The length of the input uri.
 * @param result Output a pointer to a path string. Please use free() to clear the resource.
 * @return Returns the status code of the execution.
 * @syscap SystemCapability.FileManagement.AppFileService
 * @since 12
 */
FileManagement_ErrCode OH_FileUri_GetPathFromUri(const char *uri, unsigned int length, char **result);

/**
 * @brief Gets the uri of the path or directory where the uri is located.
 *
 * @param uri Input a pointer to the uri string.
 * @param length  The length of the input uri.
 * @param result Output a pointer to a uri string. Please use free() to clear the resource.
 * @return Returns the status code of the execution.
 * @syscap SystemCapability.FileManagement.AppFileService
 * @since 12
 */
FileManagement_ErrCode OH_FileUri_GetFullDirectoryUri(const char *uri, unsigned int length, char **result);

/**
 * @brief Check that the incoming uri is valid
 *
 * @param uri Input a pointer to the uri string.
 * @param length The length of the input uri.
 * @return Returns true: Valid incoming uri, false: Invalid incoming uri.
 * @syscap SystemCapability.FileManagement.AppFileService
 * @since 12
 */
bool OH_FileUri_IsValidUri(const char *uri, unsigned int length);
#ifdef __cplusplus
};
#endif
#endif // FILE_MANAGEMENT_OH_FILE_URI_H