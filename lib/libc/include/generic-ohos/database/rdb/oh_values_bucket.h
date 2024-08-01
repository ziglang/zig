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

#ifndef OH_VALUES_BUCKET_H
#define OH_VALUES_BUCKET_H

/**
 * @addtogroup RDB
 * @{
 *
 * @brief The relational database (RDB) store manages data based on relational models.
 * With the underlying SQLite database, the RDB store provides a complete mechanism for managing local databases.
 * To satisfy different needs in complicated scenarios, the RDB store offers a series of APIs for performing operations
 * such as adding, deleting, modifying, and querying data, and supports direct execution of SQL statements.
 *
 * @syscap SystemCapability.DistributedDataManager.RelationalStore.Core
 * @since 10
 */

/**
 * @file oh_values_bucket.h
 *
 * @brief Define the type of stored key value pairs.
 *
 * @since 10
 */

#include <cstdint>
#include "database/data/data_asset.h"
#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Define the OH_VBucket structure type.
 *
 * @since 10
 */
typedef struct OH_VBucket {
    /**
     * The id used to uniquely identify the OH_VBucket struct.
     */
    int64_t id;

    /**
     * Indicates the capability of OH_VBucket.
     */
    uint16_t capability;

    /**
     * @brief Put the const char * value to this {@link OH_VBucket} object for the given column name.
     *
     * @param bucket Represents a pointer to an {@link OH_VBucket} instance.
     * @param field Indicates the name of the column.
     * @param value Indicates the const char * value.
     * @return Returns the status code of the execution.
     * @see OH_VBucket.
     * @since 10
     */
    int (*putText)(OH_VBucket *bucket, const char *field, const char *value);

    /**
     * @brief Put the int64 value to this {@link OH_VBucket} object for the given column name.
     *
     * @param bucket Represents a pointer to an {@link OH_VBucket} instance.
     * @param field Indicates the name of the column.
     * @param value Indicates the int64 value.
     * @return Returns the status code of the execution.
     * @see OH_VBucket.
     * @since 10
     */
    int (*putInt64)(OH_VBucket *bucket, const char *field, int64_t value);

    /**
     * @brief Put the double value to this {@link OH_VBucket} object for the given column name.
     *
     * @param bucket Represents a pointer to an {@link OH_VBucket} instance.
     * @param field Indicates the name of the column.
     * @param value Indicates the double value.
     * @return Returns the status code of the execution.
     * @see OH_VBucket.
     * @since 10
     */
    int (*putReal)(OH_VBucket *bucket, const char *field, double value);

    /**
     * @brief Put the const uint8_t * value to this {@link OH_VBucket} object for the given column name.
     *
     * @param bucket Represents a pointer to an {@link OH_VBucket} instance.
     * @param field Indicates the name of the column.
     * @param value Indicates the const uint8_t * value.
     * @param size Indicates the size of value.
     * @return Returns the status code of the execution.
     * @see OH_VBucket.
     * @since 10
     */
    int (*putBlob)(OH_VBucket *bucket, const char *field, const uint8_t *value, uint32_t size);

    /**
     * @brief Put NULL to this {@link OH_VBucket} object for the given column name.
     *
     * @param bucket Represents a pointer to an {@link OH_VBucket} instance.
     * @param field Indicates the name of the column.
     * @return Returns the status code of the execution.
     * @see OH_VBucket.
     * @since 10
     */
    int (*putNull)(OH_VBucket *bucket, const char *field);

    /**
     * @brief Clear the {@link OH_VBucket} object's values.
     *
     * @param bucket Represents a pointer to an {@link OH_VBucket} instance.
     * @return Returns the status code of the execution.
     * @see OH_VBucket.
     * @since 10
     */
    int (*clear)(OH_VBucket *bucket);

    /**
     * @brief Destroy the {@link OH_VBucket} object and reclaim the memory occupied by the object.
     *
     * @param bucket Represents a pointer to an {@link OH_VBucket} instance.
     * @return Returns the status code of the execution.
     * @see OH_VBucket.
     * @since 10
     */
    int (*destroy)(OH_VBucket *bucket);
} OH_VBucket;

/**
 * @brief Put the {@link Data_Asset} * value to this {@link OH_VBucket} object for the given column name.
 *
 * @param bucket Represents a pointer to an {@link OH_VBucket} instance.
 * @param field Indicates the name of the column.
 * @param value Indicates the const {@link Data_Asset} * value.
 * @return Returns the status code of the execution.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_VBucket.
 * @since 11
 */
int OH_VBucket_PutAsset(OH_VBucket *bucket, const char *field, Data_Asset *value);

/**
 * @brief Put the {@link Data_Asset} * value of given count to this {@link OH_VBucket} object for the given column name.
 *
 * @param bucket Represents a pointer to an {@link OH_VBucket} instance.
 * @param field Indicates the name of the column.
 * @param value Indicates the {@link Data_Asset} value of given count.
 * @param count Indicates the count of value.
 * @return Returns the status code of the execution.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_VBucket.
 * @since 11
 */
int OH_VBucket_PutAssets(OH_VBucket *bucket, const char *field, Data_Asset **value, uint32_t count);
#ifdef __cplusplus
};
#endif

#endif // OH_VALUES_BUCKET_H