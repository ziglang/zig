/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#ifndef ASSET_API_H
#define ASSET_API_H

#include <stdint.h>
#include <stdlib.h>

#include "asset_type.h"

/**
 * @addtogroup AssetApi
 * @{
 *
 * @brief Provides APIs for storing and managing short sensitive data of users, including adding, deleting, updating,
 * and querying the data.
 * The short sensitive data refers to sensitive data shorter than 1024 bytes, including the user passwords
 * (accounts/passwords), token data (application credentials), and critical data in plaintext (bank card numbers).
 *
 * @since 11
 */

/**
 * @file asset_api.h
 *
 * @brief Declares the APIs for accessing assets.
 *
 * @library libasset_ndk.z.so
 * @kit AssetStoreKit
 * @syscap SystemCapability.Security.Asset
 * @since 11
 */

#ifdef __cplusplus
extern "C" {
#endif
/**
 * @brief Adds an asset.
 *
 * @param attributes Pointer to the attributes of the asset to add.
 * @param attributes Number of the attributes of the asset to add.
 * @return {@link ASSET_SUCCESS} 0 - The operation is successful.
 *     {@link ASSET_PERMISSION_DENIED} 201 - The caller doesn't have the permission.
 *     {@link ASSET_INVALID_ARGUMENT} 401 - Parameter error. Possible causes:
 *         1. Mandatory parameters are left unspecified.
 *         2. Incorrect parameter types.
 *         3. Parameter verification failed.
 *     {@link ASSET_SERVICE_UNAVAILABLE} 24000001 - The ASSET service is unavailable.
 *     {@link ASSET_DUPLICATED} 24000003 - The asset already exists.
 *     {@link ASSET_STATUS_MISMATCH} 24000005 - The screen lock status does not match.
 *     {@link ASSET_OUT_OF_MEMORY} 24000006 - Insufficient memory.
 *     {@link ASSET_DATA_CORRUPTED} 24000007 - The asset is corrupted.
 *     {@link ASSET_DATABASE_ERROR} 24000008 - The database operation failed.
 *     {@link ASSET_CRYPTO_ERROR} 24000009 - The cryptography operation failed.
 *     {@link ASSET_IPC_ERROR} 24000010 - IPC failed.
 *     {@link ASSET_BMS_ERROR} 24000011 - Calling the Bundle Manager service failed.
 *     {@link ASSET_ACCOUNT_ERROR} 24000012 - Calling the OS Account service failed.
 *     {@link ASSET_ACCESS_TOKEN_ERROR} 24000013 - Calling the Access Token service failed.
 *     {@link ASSET_FILE_OPERATION_ERROR} 24000014 - The file operation failed.
 *     {@link ASSET_GET_SYSTEM_TIME_ERROR} 24000015 - Getting the system time failed.
 * @since 11
 */
int32_t OH_Asset_Add(const Asset_Attr *attributes, uint32_t attrCnt);

/**
 * @brief Removes one or more assets.
 *
 * @param query Pointer to the conditions for removing the assets.
 * @param queryCnt Number of conditions for removing the assets.
 * @return {@link ASSET_SUCCESS} 0 - The operation is successful.
 *     {@link ASSET_INVALID_ARGUMENT} 401 - Parameter error. Possible causes:
 *         1. Incorrect parameter types.
 *         2. Parameter verification failed.
 *     {@link ASSET_SERVICE_UNAVAILABLE} 24000001 - The ASSET service is unavailable.
 *     {@link ASSET_NOT_FOUND} 24000002 - The asset is not found.
 *     {@link ASSET_OUT_OF_MEMORY} 24000006 - Insufficient memory.
 *     {@link ASSET_DATA_CORRUPTED} 24000007 - The asset is corrupted.
 *     {@link ASSET_DATABASE_ERROR} 24000008 - The database operation failed.
 *     {@link ASSET_IPC_ERROR} 24000010 - IPC failed.
 *     {@link ASSET_BMS_ERROR} 24000011 - Calling the Bundle Manager service failed.
 *     {@link ASSET_ACCOUNT_ERROR} 24000012 - Calling the OS Account service failed.
 *     {@link ASSET_ACCESS_TOKEN_ERROR} 24000013 - Calling the Access Token service failed.
 *     {@link ASSET_GET_SYSTEM_TIME_ERROR} 24000015 - Getting the system time failed.
 * @since 11
 */
int32_t OH_Asset_Remove(const Asset_Attr *query, uint32_t queryCnt);

/**
 * @brief Updates an asset.
 *
 * @param query Pointer to the conditions for updating the asset.
 * @param queryCnt Number of conditions for updating the asset.
 * @param attributes Pointer to the attributes of the asset to update.
 * @param attributes Number of the attributes of the asset to update.
 * @return {@link ASSET_SUCCESS} 0 - The operation is successful.
 *     {@link ASSET_INVALID_ARGUMENT} 401 - Parameter error. Possible causes:
 *         1. Mandatory parameters are left unspecified.
 *         2. Incorrect parameter types.
 *         3. Parameter verification failed.
 *     {@link ASSET_SERVICE_UNAVAILABLE} 24000001 - The ASSET service is unavailable.
 *     {@link ASSET_NOT_FOUND} 24000002 - The asset is not found.
 *     {@link ASSET_STATUS_MISMATCH} 24000005 - The screen lock status does not match.
 *     {@link ASSET_OUT_OF_MEMORY} 24000006 - Insufficient memory.
 *     {@link ASSET_DATA_CORRUPTED} 24000007 - The asset is corrupted.
 *     {@link ASSET_DATABASE_ERROR} 24000008 - The database operation failed.
 *     {@link ASSET_CRYPTO_ERROR} 24000009 - The cryptography operation failed.
 *     {@link ASSET_IPC_ERROR} 24000010 - IPC failed.
 *     {@link ASSET_BMS_ERROR} 24000011 - Calling the Bundle Manager service failed.
 *     {@link ASSET_ACCOUNT_ERROR} 24000012 - Calling the OS Account service failed.
 *     {@link ASSET_ACCESS_TOKEN_ERROR} 24000013 - Calling the Access Token service failed.
 *     {@link ASSET_GET_SYSTEM_TIME_ERROR} 24000015 - Getting the system time failed.
 * @since 11
 */
int32_t OH_Asset_Update(const Asset_Attr *query, uint32_t queryCnt,
    const Asset_Attr *attributesToUpdate, uint32_t updateCnt);

/**
 * @brief Preprocesses data before querying the asset that can be accessed only after a successful user authentication.
 *
 * @param query Pointer to the search criteria of the asset.
 * @param queryCnt Number of the search criteria.
 * @param challenge Pointer to the challenge value to be used when <b>OH_Asset_Query</b> is called.
 * @return {@link ASSET_SUCCESS} 0 - The operation is successful.
 *     {@link ASSET_INVALID_ARGUMENT} 401 - Parameter error. Possible causes:
 *         1. Incorrect parameter types.
 *         2. Parameter verification failed.
 *     {@link ASSET_SERVICE_UNAVAILABLE} 24000001 - The ASSET service is unavailable.
 *     {@link ASSET_NOT_FOUND} 24000002 - The asset is not found.
 *     {@link ASSET_STATUS_MISMATCH} 24000005 - The screen lock status does not match.
 *     {@link ASSET_OUT_OF_MEMORY} 24000006 - Insufficient memory.
 *     {@link ASSET_DATA_CORRUPTED} 24000007 - The asset is corrupted.
 *     {@link ASSET_DATABASE_ERROR} 24000008 - The database operation failed.
 *     {@link ASSET_CRYPTO_ERROR} 24000009 - The cryptography operation failed.
 *     {@link ASSET_IPC_ERROR} 24000010 - IPC failed.
 *     {@link ASSET_BMS_ERROR} 24000011 - Calling the Bundle Manager service failed.
 *     {@link ASSET_ACCOUNT_ERROR} 24000012 - Calling the OS Account service failed.
 *     {@link ASSET_ACCESS_TOKEN_ERROR} 24000013 - Calling the Access Token service failed.
 *     {@link ASSET_LIMIT_EXCEEDED} 24000016 - The cache exceeds the limit.
 *     {@link ASSET_UNSUPPORTED} 24000017 - The capability is not supported.
 * @since 11
 */
int32_t OH_Asset_PreQuery(const Asset_Attr *query, uint32_t queryCnt, Asset_Blob *challenge);

/**
 * @brief Queries assets.
 *
 * @param query Pointer to the search criteria.
 * @param queryCnt Number of the search criteria.
 * @param resultSet Pointer to the query result obtained.
 * @return {@link ASSET_SUCCESS} 0 - The operation is successful.
 *     {@link ASSET_INVALID_ARGUMENT} 401 - Parameter error. Possible causes:
 *         1. Incorrect parameter types.
 *         2. Parameter verification failed.
 *     {@link ASSET_SERVICE_UNAVAILABLE} 24000001 - The ASSET service is unavailable.
 *     {@link ASSET_NOT_FOUND} 24000002 - The asset is not found.
 *     {@link ASSET_ACCESS_DENIED} 24000004 - Access to the asset is denied.
 *     {@link ASSET_STATUS_MISMATCH} 24000005 - The screen lock status does not match.
 *     {@link ASSET_OUT_OF_MEMORY} 24000006 - Insufficient memory.
 *     {@link ASSET_DATA_CORRUPTED} 24000007 - The asset is corrupted.
 *     {@link ASSET_DATABASE_ERROR} 24000008 - The database operation failed.
 *     {@link ASSET_CRYPTO_ERROR} 24000009 - The cryptography operation failed.
 *     {@link ASSET_IPC_ERROR} 24000010 - IPC failed.
 *     {@link ASSET_BMS_ERROR} 24000011 - Calling the Bundle Manager service failed.
 *     {@link ASSET_ACCOUNT_ERROR} 24000012 - Calling the OS Account service failed.
 *     {@link ASSET_ACCESS_TOKEN_ERROR} 24000013 - Calling the Access Token service failed.
 *     {@link ASSET_UNSUPPORTED} 24000017 - The capability is not supported.
 * @since 11
 */
int32_t OH_Asset_Query(const Asset_Attr *query, uint32_t queryCnt, Asset_ResultSet *resultSet);

/**
 * @brief Processes data after the query of the asset that requires user authentication.
 *
 * @param handle Pointer to the handle of the data to process, which includes the challenge value returned by
 *     <b>OH_Asset_PreQuery</b>.
 * @param handleCnt Number of the elements in the handle attribute set.
 * @return {@link ASSET_SUCCESS} 0 - The operation is successful.
 *     {@link ASSET_INVALID_ARGUMENT} 401 - Parameter error. Possible causes:
 *         1. Mandatory parameters are left unspecified.
 *         2. Incorrect parameter types.
 *         3. Parameter verification failed.
 *     {@link ASSET_SERVICE_UNAVAILABLE} 24000001 - The ASSET service is unavailable.
 *     {@link ASSET_OUT_OF_MEMORY} 24000006 - Insufficient memory.
 *     {@link ASSET_IPC_ERROR} 24000010 - IPC failed.
 *     {@link ASSET_BMS_ERROR} 24000011 - Calling the Bundle Manager service failed.
 *     {@link ASSET_ACCOUNT_ERROR} 24000012 - Calling the OS Account service failed.
 *     {@link ASSET_ACCESS_TOKEN_ERROR} 24000013 - Calling the Access Token service failed.
 * @since 11
 */
int32_t OH_Asset_PostQuery(const Asset_Attr *handle, uint32_t handleCnt);

/**
 * @brief Parses the query result to obtain the specified attribute value.
 *
 * @param result Pointer to the query result to parse, which is obtained by <b>OH_Asset_Query</b>.
 * @param tag Tag of the attribute to obtain.
 * @return Returns <b>Asset_Attr</b> obtained if the operation is successful; returns <b>NULL</b> otherwise.
 *     The attribute does not need to be released by the service.
 * @since 11
 */
Asset_Attr *OH_Asset_ParseAttr(const Asset_Result *result, Asset_Tag tag);

/**
 * @brief Releases the memory occupied by the challenge value.
 *
 * @param blob Pointer to the challenge value (obtained by <b>OH_Asset_PreQuery</b>) to release.
 * @since 11
 */
void OH_Asset_FreeBlob(Asset_Blob *blob);

/**
 * @brief Releases the memory occupied by the query result.
 *
 * @param resultSet Pointer to the query result (obtained by <b>OH_Asset_Query</b>) to release.
 * @since 11
 */
void OH_Asset_FreeResultSet(Asset_ResultSet *resultSet);

#ifdef __cplusplus
}
#endif

/** @} */
#endif // ASSET_API_H