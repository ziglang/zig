/*
 * Copyright (c) 2023 Huawei Device Co., Ltd.
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

#ifndef DATA_ASSET_H
#define DATA_ASSET_H
/**
 * @addtogroup RDB
 * @{
 *
 * @brief The relational database (RDB) store manages data based on relational models.
 * With the underlying SQLite database, the RDB store provides a complete mechanism for managing local databases.
 * To satisfy different needs in complicated scenarios, the RDB store offers a series of APIs for performing operations
 * such as adding, deleting, modifying, and querying data, and supports direct execution of SQL statements.
 *
 * @since 11
 */

/**
 * @file data_asset.h
 *
 * @brief Provides the data type of asset.
 * @library libnative_rdb_ndk.z.so
 * @syscap SystemCapability.DistributedDataManager.RelationalStore.Core
 * @since 11
 */
#include <cstddef>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
/**
 * @brief Describes the status of asset.
 *
 * @since 11
 */
typedef enum Data_AssetStatus {
    /**
     * @brief Means the status of asset is null.
     */
    ASSET_NULL = 0,

    /**
     * @brief Means the status of asset is normal.
     */
    ASSET_NORMAL,

    /**
     * @brief Means the asset needs to be inserted.
     */
    ASSET_INSERT,

    /**
     * @brief Means the asset needs to be updated.
     */
    ASSET_UPDATE,

    /**
     * @brief Means the asset needs to be deleted.
     */
    ASSET_DELETE,

    /**
     * @brief Means the status of asset is abnormal.
     */
    ASSET_ABNORMAL,

    /**
     * @brief Means the status of asset is downloading.
     */
    ASSET_DOWNLOADING
} Data_AssetStatus;

/**
 * @brief Define the Data_Asset structure type.
 *
 * Provides information of an asset.
 *
 * @since 11
 */
typedef struct Data_Asset Data_Asset;

/**
 * @brief Set the name of the Data_Asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param name Indicates the name to set.
 * @return Returns a specific error code.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_SetName(Data_Asset *asset, const char *name);

/**
 * @brief Set the uri of the Data_Asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param uri Indicates the uri to set.
 * @return Returns a specific error code.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_SetUri(Data_Asset *asset, const char *uri);

/**
 * @brief Set the path of the Data_Asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param path Indicates the path to set.
 * @return Returns a specific error code.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_SetPath(Data_Asset *asset, const char *path);

/**
 * @brief Set the create time of the Data_Asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param createTime Indicates the create time to set.
 * @return Returns a specific error code.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_SetCreateTime(Data_Asset *asset, int64_t createTime);

/**
 * @brief Set the modify time of the Data_Asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param modifyTime Indicates the create time to set.
 * @return Returns a specific error code.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_SetModifyTime(Data_Asset *asset, int64_t modifyTime);

/**
 * @brief Set the size of the Data_Asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param size Indicates the size to set.
 * @return Returns a specific error code.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_SetSize(Data_Asset *asset, size_t size);

/**
 * @brief Set the status of the Data_Asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param status Indicates the status to set. Specific status can be referenced {@link Data_AssetStatus}.
 * @return Returns a specific error code.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset, Data_AssetStatus
 * @since 11
 */
int OH_Data_Asset_SetStatus(Data_Asset *asset, Data_AssetStatus status);

/**
 * @brief Obtains the name of the asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param name This parameter is the output parameter,
 * and the name of the asset as a char * is written to this variable.
 * @param length Indicates the length of the name.
 * @return Returns a specific error code.
 *     {@link RDB_ERR} - Indicates that the function execution exception.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_GetName(Data_Asset *asset, char *name, size_t *length);

/**
 * @brief Obtains the uri of the asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param uri This parameter is the output parameter,
 * and the uri of the asset as a char * is written to this variable.
 * @param length Indicates the length of the uri.
 * @return Returns a specific error code.
 *     {@link RDB_ERR} - Indicates that the function execution exception.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_GetUri(Data_Asset *asset, char *uri, size_t *length);

/**
 * @brief Obtains the path of the asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param path This parameter is the output parameter,
 * and the path of the asset as a char * is written to this variable.
 * @param length Indicates the length of the path.
 * @return Returns a specific error code.
 *     {@link RDB_ERR} - Indicates that the function execution exception.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_GetPath(Data_Asset *asset, char *path, size_t *length);

/**
 * @brief Obtains the create time of the asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param createTime This parameter is the output parameter,
 * and the create time of the asset as a int64_t is written to this variable.
 * @return Returns a specific error code.
 *     {@link RDB_ERR} - Indicates that the function execution exception.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_GetCreateTime(Data_Asset *asset, int64_t *createTime);

/**
 * @brief Obtains the modify time of the asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param modifyTime This parameter is the output parameter,
 * and the create time of the asset as a int64_t is written to this variable.
 * @return Returns a specific error code.
 *     {@link RDB_ERR} - Indicates that the function execution exception.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_GetModifyTime(Data_Asset *asset, int64_t *modifyTime);

/**
 * @brief Obtains the size of the asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param size This parameter is the output parameter,
 * and the size of the asset as a size_t is written to this variable.
 * @return Returns a specific error code.
 *     {@link RDB_ERR} - Indicates that the function execution exception.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset
 * @since 11
 */
int OH_Data_Asset_GetSize(Data_Asset *asset, size_t *size);

/**
 * @brief Obtains the status of the asset.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @param status This parameter is the output parameter,
 * and the size of the status as a {@link Data_AssetStatus} is written to this variable.
 * @return Returns a specific error code.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset Data_AssetStatus.
 * @since 11
 */
int OH_Data_Asset_GetStatus(Data_Asset *asset, Data_AssetStatus *status);

/**
 * @brief Creates an {@link Data_Asset} instance.
 *
 * @return If the creation is successful, a pointer to the instance of the @link Data_Asset} structure is returned,
 * otherwise NULL is returned.
 * @see Data_Asset.
 * @since 11
 */
Data_Asset *OH_Data_Asset_CreateOne(void);

/**
 * @brief Destroy the {@link Data_Asset} object and reclaim the memory occupied by the object.
 *
 * @param asset Represents a pointer to an {@link Data_Asset} instance.
 * @return Returns the status code of the execution. Successful execution returns RDB_OK,
 * while failure returns a specific error code. Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset, OH_Rdb_ErrCode.
 * @since 11
 */
int OH_Data_Asset_DestroyOne(Data_Asset *asset);

/**
 * @brief Creates {@link Data_Asset} instances of given number.
 *
 * @param count Represents the count of {@link Data_Asset} to create.
 * @return If the creation is successful, a pointer to the instance of the {@link Data_Asset} structure is returned.
 *         If the creation is unsuccessful, NULL is returned.
 * @see Data_Asset.
 * @since 11
 */
Data_Asset **OH_Data_Asset_CreateMultiple(uint32_t count);

/**
 * @brief Destroy the {@link Data_Asset} objects and reclaim the memory occupied by the objects.
 *
 * @param assets Represents a pointer to an {@link Data_Asset} instance.
 * @param count Represents the count of {@link Data_Asset} to destroy.
 * @return Returns the status code of the execution. Successful execution returns RDB_OK,
 * while failure returns a specific error code. Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see Data_Asset, OH_Rdb_ErrCode.
 * @since 11
 */
int OH_Data_Asset_DestroyMultiple(Data_Asset **assets, uint32_t count);
#ifdef __cplusplus
};
#endif
#endif // DATA_ASSET_H