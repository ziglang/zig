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

#ifndef FILE_MANAGEMENT_OH_FILE_SHARE_H
#define FILE_MANAGEMENT_OH_FILE_SHARE_H

#include "error_code.h"

/**
 * @addtogroup fileShare
 * @{
 *
 * @brief This module provides file sharing capabilities to authorize Uniform Resource Identifiers (URIs)
 * for public directory files that have read and write access to other applications.
 * @since 12
 */

/**
 * @file oh_file_share.h
 * @kit CoreFileKit
 *
 * @brief Provides URI-based file and directory authorization and persistence, permission activation, permission query,
 * and other methods.
 * @library libohfileshare.so
 * @syscap SystemCapability.FileManagement.AppFileService.FolderAuthorization
 * @since 12
 */
#ifdef __cplusplus
extern "C" {
#endif
/**
 * @brief Enumerates the uri operate mode types.
 *
 * @since 12
 */
typedef enum FileShare_OperationMode {
    /**
     * @brief Indicates read permissions.
     */
    READ_MODE = 1 << 0,

    /**
     * @brief Indicates write permissions.
     */
    WRITE_MODE = 1 << 1
} FileShare_OperationMode;

/**
 * @brief Enumerates the error code of the permission policy for the URI operation.
 *
 * @since 12
 */
typedef enum FileShare_PolicyErrorCode {
    /**
     * @brief Indicates that the policy is not allowed to be persisted.
     */
    PERSISTENCE_FORBIDDEN = 1,

    /**
     * @brief Indicates that the mode of this policy is invalid.
     */
    INVALID_MODE = 2,

    /**
     * @brief Indicates that the path of this policy is invalid.
     */
    INVALID_PATH = 3,

    /**
     * @brief Indicates that the policy is no persistent capability.
     */
    PERMISSION_NOT_PERSISTED = 4
} FileShare_PolicyErrorCode;

/**
 * @brief Define the FileShare_PolicyErrorResult structure type.
 *
 * Failed policy result on URI.
 *
 * @since 12
 */
typedef struct FileShare_PolicyErrorResult {
    /**
     * Indicates the failed uri of the policy information.
     */
    char *uri;

    /**
     * Indicates the error code of the failure in the policy information.
     */
    FileShare_PolicyErrorCode code;

    /**
     * Indicates the reason of the failure in the policy information.
     */
    char *message;
} FileShare_PolicyErrorResult;

/**
 * @brief Define the FileShare_PolicyInfo structure type.
 *
 * Policy information to manager permissions on a URI.
 *
 * @since 12
 */
typedef struct FileShare_PolicyInfo {
    /**
     * Indicates the uri of the policy information.
     */
    char *uri;

    /**
     * Indicates The length of the uri.
     */
    unsigned int length;

    /**
     * Indicates the mode of operation for the URI.
     * example { FileShare_OperationMode.READ_MODE } or { FileShare_OperationMode.READ_MODE |
     * FileShare_OperationMode.WRITE_MODE }.
     */
    unsigned int operationMode;
} FileShare_PolicyInfo;

/**
 * @brief Set persistent permissions for the URI.
 *
 * @permission ohos.permission.FILE_ACCESS_PERSIST
 * @param policies Input a pointer to an {@link FileShare_PolicyInfo} instance.
 * @param policyNum Indicates the size of the policies array.
 * @param result Output a pointer to an {@link FileShare_PolicyErrorResult} instance. Please use
 * OH_FileShare_ReleasePolicyErrorResult() to clear Resource.
 * @param resultNum Output the size of the result array.
 * @return Returns the status code of the execution.
 *         {@link E_PARAMS} 401 - Invalid input parameter.
 *         {@link E_DEVICE_NOT_SUPPORT} 801 - Device not supported.
 *         {@link E_PERMISSION} 201 - No permission to perform this operation.
 *         {@link E_EPERM} 13900001 - operation not permitted.
 *         {@link E_ENOMEM} 13900011 - Failed to apply for memory or failed to copy memory.
 *         {@link E_NO_ERROR} 0 - This operation was successfully executed.
 * @since 12
 */
FileManagement_ErrCode OH_FileShare_PersistPermission(const FileShare_PolicyInfo *policies,
                                                      unsigned int policyNum,
                                                      FileShare_PolicyErrorResult **result,
                                                      unsigned int *resultNum);

/**
 * @brief Revoke persistent permissions for the URI.
 *
 * @permission ohos.permission.FILE_ACCESS_PERSIST
 * @param policies Input a pointer to an {@link FileShare_PolicyInfo} instance.
 * @param policyNum Indicates the size of the policies array.
 * @param result Output a pointer to an {@link FileShare_PolicyErrorResult} instance. Please use
 * OH_FileShare_ReleasePolicyErrorResult() to clear Resource.
 * @param resultNum Output the size of the result array.
 * @return Returns the status code of the execution.
 *         {@link E_PARAMS} 401 - Invalid input parameter.
 *         {@link E_DEVICE_NOT_SUPPORT} 801 - Device not supported.
 *         {@link E_PERMISSION} 201 - No permission to perform this operation.
 *         {@link E_EPERM} 13900001 - operation not permitted.
 *         {@link E_ENOMEM} 13900011 - Failed to apply for memory or failed to copy memory.
 *         {@link E_NO_ERROR} 0 - This operation was successfully executed.
 * @since 12
 */
FileManagement_ErrCode OH_FileShare_RevokePermission(const FileShare_PolicyInfo *policies,
                                                     unsigned int policyNum,
                                                     FileShare_PolicyErrorResult **result,
                                                     unsigned int *resultNum);

/**
 * @brief Enable the URI that have been permanently authorized.
 *
 * @permission ohos.permission.FILE_ACCESS_PERSIST
 * @param policies Input a pointer to an {@link FileShare_PolicyInfo} instance.
 * @param policyNum Indicates the size of the policies array.
 * @param result Output a pointer to an {@link FileShare_PolicyErrorResult} instance. Please use
 * OH_FileShare_ReleasePolicyErrorResult() to clear Resource.
 * @param resultNum Output the size of the result array.
 * @return Returns the status code of the execution.
 *         {@link E_PARAMS} 401 - Invalid input parameter.
 *         {@link E_DEVICE_NOT_SUPPORT} 801 - Device not supported.
 *         {@link E_PERMISSION} 201 - No permission to perform this operation.
 *         {@link E_EPERM} 13900001 - operation not permitted.
 *         {@link E_ENOMEM} 13900011 - Failed to apply for memory or failed to copy memory.
 *         {@link E_NO_ERROR} 0 - This operation was successfully executed.
 * @since 12
 */
FileManagement_ErrCode OH_FileShare_ActivatePermission(const FileShare_PolicyInfo *policies,
                                                       unsigned int policyNum,
                                                       FileShare_PolicyErrorResult **result,
                                                       unsigned int *resultNum);

/**
 * @brief Stop the authorized URI that has been enabled.
 *
 * @permission ohos.permission.FILE_ACCESS_PERSIST
 * @param policies Input a pointer to an {@link FileShare_PolicyInfo} instance.
 * @param policyNum Indicates the size of the policies array.
 * @param result Output a pointer to an {@link FileShare_PolicyErrorResult} instance. Please use
 * OH_FileShare_ReleasePolicyErrorResult() to clear Resource.
 * @param resultNum Output the size of the result array.
 * @return Returns the status code of the execution.
 *         {@link E_PARAMS} 401 - Invalid input parameter.
 *         {@link E_DEVICE_NOT_SUPPORT} 801 - Device not supported.
 *         {@link E_PERMISSION} 201 - No permission to perform this operation.
 *         {@link E_EPERM} 13900001 - operation not permitted.
 *         {@link E_ENOMEM} 13900011 - Failed to apply for memory or failed to copy memory.
 *         {@link E_NO_ERROR} 0 - This operation was successfully executed.
 * @since 12
 */
FileManagement_ErrCode OH_FileShare_DeactivatePermission(const FileShare_PolicyInfo *policies,
                                                         unsigned int policyNum,
                                                         FileShare_PolicyErrorResult **result,
                                                         unsigned int *resultNum);

/**
 * @brief Check persistent permissions for the URI.
 *
 * @permission ohos.permission.FILE_ACCESS_PERSIST
 * @param policies Input a pointer to an {@link FileShare_PolicyInfo} instance.
 * @param policyNum Indicates the size of the policies array.
 * @param result Output a pointer to an bool instance. Please use free() to clear Resource.
 * @param resultNum Output the size of the result array.
 * @return Returns the status code of the execution.
 *         {@link E_PARAMS} 401 - Invalid input parameter.
 *         {@link E_DEVICE_NOT_SUPPORT} 801 - Device not supported.
 *         {@link E_PERMISSION} 201 - No permission to perform this operation.
 *         {@link E_EPERM} 13900001 - operation not permitted.
 *         {@link E_ENOMEM} 13900011 - Failed to apply for memory or failed to copy memory.
 *         {@link E_NO_ERROR} 0 - This operation was successfully executed.
 * @since 12
 */
FileManagement_ErrCode OH_FileShare_CheckPersistentPermission(const FileShare_PolicyInfo *policies,
                                                              unsigned int policyNum,
                                                              bool **result,
                                                              unsigned int *resultNum);

/**
 * @brief Free FileShare_PolicyErrorResult pointer points to address memory.
 *
 * @param errorResult Input a pointer to an {@link FileShare_PolicyErrorResult} instance.
 * @param resultNum Indicates the size of the errorResult array.
 * @since 12
 */
void OH_FileShare_ReleasePolicyErrorResult(FileShare_PolicyErrorResult *errorResult, unsigned int resultNum);
#ifdef __cplusplus
};
#endif
/** @} */
#endif // FILE_MANAGEMENT_OH_FILE_SHARE_H