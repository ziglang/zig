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
#ifndef FILE_MANAGEMENT_ENVIRONMENT_OH_ENVIRONMENT_H
#define FILE_MANAGEMENT_ENVIRONMENT_OH_ENVIRONMENT_H

/**
 * @addtogroup Environment
 *
 * @brief This module provides the ability to access the environment directory and obtain the native interface
   for public root directory.
 * @since 12
 */

/**
 * @file oh_environment.h
 *
 * @brief Provide environment APIS.
 * @kit CoreFileKit
 * @library libohenvironment.so
 * @syscap SystemCapability.FileManagement.File.Environment.FolderObtain
 * @since 12
 */

#include "error_code.h"

#ifdef __cplusplus
extern "C" {
#endif
/**
 * @brief Get the user Download directory.
 *
 * @param result Output a pointer to a string. Please use free() to clear the resource.
 * @return Return the status code of the execution.
 *         {@link PARAMETER_ERROR} 401 - Invalid input parameter, pointer is null.
 *         {@link DEVICE_NOT_SUPPORTED} 801 - Device not supported.
 *         {@link E_NOMEM} 13900011 - Failed to apply for memory.
 * @since 12
 */
FileManagement_ErrCode OH_Environment_GetUserDownloadDir(char **result);

/**
 * @brief Get the user Desktop directory.
 *
 * @param result Output a pointer to a string. Please use free() to clear the resource.
 * @return Return the status code of the execution.
 *         {@link PARAMETER_ERROR} 401 - Invalid input parameter, pointer is null.
 *         {@link DEVICE_NOT_SUPPORTED} 801 - Device not supported.
 *         {@link E_NOMEM} 13900011 - Failed to apply for memory.
 * @since 12
 */
FileManagement_ErrCode OH_Environment_GetUserDesktopDir(char **result);

/**
 * @brief Get the user Document directory.
 *
 * @param result Output a pointer to a string. Please use free() to clear the resource.
 * @return Return the status code of the execution.
 *         {@link PARAMETER_ERROR} 401 - Invalid input parameter, pointer is null.
 *         {@link DEVICE_NOT_SUPPORTED} 801 - Device not supported.
 *         {@link E_NOMEM} 13900011 - Failed to apply for memory.
 * @since 12
 */
FileManagement_ErrCode OH_Environment_GetUserDocumentDir(char **result);

#ifdef __cplusplus
};
#endif

#endif //FILE_MANAGEMENT_ENVIRONMENT_OH_ENVIRONMENT_H