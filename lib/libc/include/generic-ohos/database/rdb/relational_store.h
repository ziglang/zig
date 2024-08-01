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

#ifndef RELATIONAL_STORE_H
#define RELATIONAL_STORE_H

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
 * @file relational_store.h
 *
 * @brief Provides database related functions and enumerations.
 *
 * @since 10
 */

#include "database/rdb/oh_cursor.h"
#include "database/rdb/oh_predicates.h"
#include "database/rdb/oh_value_object.h"
#include "database/rdb/oh_values_bucket.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Describe the security level of the database.
 *
 * @since 10
 */
typedef enum OH_Rdb_SecurityLevel {
    /**
     * @brief Low-level security. Data leaks have a minor impact.
     */
    S1 = 1,
    /**
     * @brief Medium-level security. Data leaks have a major impact.
     */
    S2,
    /**
     * @brief High-level security. Data leaks have a severe impact.
     */
    S3,
    /**
     * @brief Critical-level security. Data leaks have a critical impact.
     */
    S4
} OH_Rdb_SecurityLevel;

/**
 * @brief Describe the security area of the database.
 *
 * @since 11
 */
typedef enum Rdb_SecurityArea {
    /**
     * @brief Security Area 1.
     */
    RDB_SECURITY_AREA_EL1 = 1,
    /**
     * @brief Security Area 2.
     */
    RDB_SECURITY_AREA_EL2,
    /**
     * @brief Security Area 3.
     */
    RDB_SECURITY_AREA_EL3,
    /**
     * @brief Security Area 4.
     */
    RDB_SECURITY_AREA_EL4,
} Rdb_SecurityArea;

/**
 * @brief Manages relational database configurations.
 *
 * @since 10
 */
#pragma pack(1)
typedef struct {
    /**
     * Indicates the size of the {@link OH_Rdb_Config}. It is mandatory.
     */
    int selfSize;
    /**
     * Indicates the directory of the database.
     */
    const char *dataBaseDir;
    /**
     * Indicates the name of the database.
     */
    const char *storeName;
    /**
     * Indicates the bundle name of the application.
     */
    const char *bundleName;
    /**
     * Indicates the module name of the application.
     */
    const char *moduleName;
    /**
     * Indicates whether the database is encrypted.
     */
    bool isEncrypt;
    /**
     * Indicates the security level {@link OH_Rdb_SecurityLevel} of the database.
     */
    int securityLevel;
    /**
     * Indicates the security area {@link Rdb_SecurityArea} of the database.
     *
     * @since 11
     */
    int area;
} OH_Rdb_Config;
#pragma pack()

/**
 * @brief Define OH_Rdb_Store type.
 *
 * @since 10
 */
typedef struct {
    /**
     * The id used to uniquely identify the OH_Rdb_Store struct.
     */
    int64_t id;
} OH_Rdb_Store;

/**
 * @brief Creates an {@link OH_VObject} instance.
 *
 * @return If the creation is successful, a pointer to the instance of the @link OH_VObject} structure is returned,
 * otherwise NULL is returned.
 * @see OH_VObject.
 * @since 10
 */
OH_VObject *OH_Rdb_CreateValueObject();

/**
 * @brief Creates an {@link OH_VBucket} object.
 *
 * @return If the creation is successful, a pointer to the instance of the @link OH_VBucket} structure is returned,
 * otherwise NULL is returned.
 * @see OH_VBucket.
 * @since 10
 */
OH_VBucket *OH_Rdb_CreateValuesBucket();

/**
 * @brief Creates an {@link OH_Predicates} instance.
 *
 * @param table Indicates the table name.
 * @return If the creation is successful, a pointer to the instance of the @link OH_Predicates} structure is returned.
 *         If the table name is nullptr, Nullptr is returned.
 * @see OH_Predicates.
 * @since 10
 */
OH_Predicates *OH_Rdb_CreatePredicates(const char *table);

/**
 * @brief Obtains an RDB store.
 *
 * You can set parameters of the RDB store as required. In general,
 * this method is recommended to obtain a rdb store.
 *
 * @param config Represents a pointer to an {@link OH_Rdb_Config} instance.
 * Indicates the configuration of the database related to this RDB store.
 * @param errCode This parameter is the output parameter,
 * and the execution status of a function is written to this variable.
 * @return If the creation is successful, a pointer to the instance of the @link OH_Rdb_Store} structure is returned.
 *         If the Config is empty, config.size does not match, or errCode is empty.
 * Get database path failed.Get RDB Store fail. Nullptr is returned.
 * @see OH_Rdb_Config, OH_Rdb_Store.
 * @since 10
 */
OH_Rdb_Store *OH_Rdb_GetOrOpen(const OH_Rdb_Config *config, int *errCode);

/**
 * @brief Close the {@link OH_Rdb_Store} object and reclaim the memory occupied by the object.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @return Returns the status code of the execution. Successful execution returns RDB_OK,
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * while failure returns a specific error code. Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see OH_Rdb_Store, OH_Rdb_ErrCode.
 * @since 10
 */
int OH_Rdb_CloseStore(OH_Rdb_Store *store);

/**
 * @brief Deletes the database with a specified path.
 *
 * @param config Represents a pointer to an {@link OH_Rdb_Config} instance.
 * Indicates the configuration of the database related to this RDB store.
 * @return Returns the status code of the execution. Successful execution returns RDB_OK,
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * while failure returns a specific error code. Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see OH_Rdb_ErrCode.
 * @since 10
 */
int OH_Rdb_DeleteStore(const OH_Rdb_Config *config);

/**
 * @brief Inserts a row of data into the target table.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param table Indicates the target table.
 * @param valuesBucket Indicates the row of data {@link OH_VBucket} to be inserted into the table.
 * @return Returns the rowId if success, returns a specific error code.
 *     {@link RDB_ERR} - Indicates that the function execution exception.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see OH_Rdb_Store, OH_VBucket, OH_Rdb_ErrCode.
 * @since 10
 */
int OH_Rdb_Insert(OH_Rdb_Store *store, const char *table, OH_VBucket *valuesBucket);

/**
 * @brief Updates data in the database based on specified conditions.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param valuesBucket Indicates the row of data {@link OH__VBucket} to be updated in the database
 * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
 * Indicates the specified update condition.
 * @return Returns the number of rows changed if success, otherwise, returns a specific error code.
 *     {@link RDB_ERR} - Indicates that the function execution exception.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see OH_Rdb_Store, OH_Bucket, OH_Predicates, OH_Rdb_ErrCode.
 * @since 10
 */
int OH_Rdb_Update(OH_Rdb_Store *store, OH_VBucket *valuesBucket, OH_Predicates *predicates);

/**
 * @brief Deletes data from the database based on specified conditions.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
 * Indicates the specified delete condition.
 * @return Returns the number of rows changed if success, otherwise, returns a specific error code.
 *     {@link RDB_ERR} - Indicates that the function execution exception.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * Specific error codes can be referenced {@link OH_Rdb_ErrCode}.
 * @see OH_Rdb_Store, OH_Predicates, OH_Rdb_ErrCode.
 * @since 10
 */
int OH_Rdb_Delete(OH_Rdb_Store *store, OH_Predicates *predicates);

/**
 * @brief Queries data in the database based on specified conditions.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
 * Indicates the specified query condition.
 * @param columnNames Indicates the columns to query. If the value is empty array, the query applies to all columns.
 * @param length Indicates the length of columnNames.
 * @return If the query is successful, a pointer to the instance of the @link OH_Cursor} structure is returned.
 *         If Get store failed or resultSet is nullptr, nullptr is returned.
 * @see OH_Rdb_Store, OH_Predicates, OH_Cursor.
 * @since 10
 */
OH_Cursor *OH_Rdb_Query(OH_Rdb_Store *store, OH_Predicates *predicates, const char *const *columnNames, int length);

/**
 * @brief Executes an SQL statement.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param sql Indicates the SQL statement to execute.
 * @return Returns the status code of the execution.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @since 10
 */
int OH_Rdb_Execute(OH_Rdb_Store *store, const char *sql);

/**
 * @brief Queries data in the database based on an SQL statement.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param sql Indicates the SQL statement to execute.
 * @return If the query is successful, a pointer to the instance of the @link OH_Cursor} structure is returned.
 *         If Get store failed,sql is nullptr or resultSet is nullptr, nullptr is returned.
 * @see OH_Rdb_Store.
 * @since 10
 */
OH_Cursor *OH_Rdb_ExecuteQuery(OH_Rdb_Store *store, const char *sql);

/**
 * @brief Begins a transaction in EXCLUSIVE mode.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @return Returns the status code of the execution.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @since 10
 */
int OH_Rdb_BeginTransaction(OH_Rdb_Store *store);

/**
 * @brief Rolls back a transaction in EXCLUSIVE mode.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @return Returns the status code of the execution.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @since 10
 */
int OH_Rdb_RollBack(OH_Rdb_Store *store);

/**
 * @brief Commits a transaction in EXCLUSIVE mode.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @return Returns the status code of the execution.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @since 10
 */
int OH_Rdb_Commit(OH_Rdb_Store *store);

/**
 * @brief Backs up a database on specified path.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param databasePath Indicates the database file path.
 * @return Returns the status code of the execution.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @since 10
 */
int OH_Rdb_Backup(OH_Rdb_Store *store, const char *databasePath);

/**
 * @brief Restores a database from a specified database file.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param databasePath Indicates the database file path.
 * @return Returns the status code of the execution.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @since 10
 */
int OH_Rdb_Restore(OH_Rdb_Store *store, const char *databasePath);

/**
 * @brief Gets the version of a database.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param version Indicates the version number.
 * @return Returns the status code of the execution.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @since 10
 */
int OH_Rdb_GetVersion(OH_Rdb_Store *store, int *version);

/**
 * @brief Sets the version of a database.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param version Indicates the version number.
 * @return Returns the status code of the execution.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @since 10
 */
int OH_Rdb_SetVersion(OH_Rdb_Store *store, int version);

/**
 * @brief Describes the distribution type of the tables.
 *
 * @since 11
 */
typedef enum Rdb_DistributedType {
    /**
     * @brief Indicates the table is distributed among the devices.
     */
    RDB_DISTRIBUTED_CLOUD
} Rdb_DistributedType;

/**
 * @brief Indicates version of {@link Rdb_DistributedConfig}
 *
 * @since 11
 */
#define DISTRIBUTED_CONFIG_VERSION 1
/**
 * @brief Manages the distributed configuration of the table.
 *
 * @since 11
 */
typedef struct Rdb_DistributedConfig {
    /**
     * The version used to uniquely identify the Rdb_DistributedConfig struct.
     */
    int version;
    /**
     * Specifies whether the table auto syncs.
     */
    bool isAutoSync;
} Rdb_DistributedConfig;

/**
 * @brief Set table to be distributed table.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param tables Indicates the table names you want to set.
 * @param count Indicates the count of tables you want to set.
 * @param type Indicates the distributed type {@link Rdb_DistributedType}.
 * @param config Indicates the distributed config of the tables. For details, see {@link Rdb_DistributedConfig}.
 * @return Returns the status code of the execution. See {@link OH_Rdb_ErrCode}.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @see Rdb_DistributedConfig.
 * @since 11
 */
int OH_Rdb_SetDistributedTables(OH_Rdb_Store *store, const char *tables[], uint32_t count, Rdb_DistributedType type,
    const Rdb_DistributedConfig *config);

/**
 * @brief Set table to be distributed table.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param tableName Indicates the name of the table to check.
 * @param columnName Indicates the name of the column corresponding to the primary key.
 * If the table has no primary key , please pass in "rowid".
 * @param values Indicates the primary keys of the rows to check.
 * If the table has no primary key , please pass in the row-ids of the rows to check.
 * @return If the operation is successful, a pointer to the instance of the @link OH_Cursor} structure is returned.
 *         If Get store failed, NULL is returned.
 * There are two columns, "data_key" and "timestamp". Otherwise NULL is returned.
 * @see OH_Rdb_Store.
 * @see OH_VObject.
 * @see OH_Cursor.
 * @since 11
 */
OH_Cursor *OH_Rdb_FindModifyTime(OH_Rdb_Store *store, const char *tableName, const char *columnName,
    OH_VObject *values);

/**
 * @brief Describes the change type.
 *
 * @since 11
 */
typedef enum Rdb_ChangeType {
    /**
     * @brief Means the change type is data change.
     */
    RDB_DATA_CHANGE,
    /**
     * @brief Means the change type is asset change.
     */
    RDB_ASSET_CHANGE
} Rdb_ChangeType;

/**
 * @brief Describes the primary keys or row-ids of changed rows.
 *
 * @since 11
 */
typedef struct Rdb_KeyInfo {
    /**
     * Indicates the count of the primary keys or row-ids.
     */
    int count;

    /**
     * Indicates data type {@link OH_ColumnType} of the key.
     */
    int type;

    /**
     * Indicates the data of the key info.
     */
    union Rdb_KeyData {
        /**
         * Indicates uint64_t type of the data.
         */
        uint64_t integer;

        /**
         * Indicates double type of the data.
         */
        double real;

        /**
         * Indicates const char * type of the data.
         */
        const char *text;
    } *data;
} Rdb_KeyInfo;

/**
 * @brief Indicates version of {@link Rdb_ChangeInfo}
 *
 * @since 11
 */
#define DISTRIBUTED_CHANGE_INFO_VERSION 1

/**
 * @brief Describes the notify info of data change.
 *
 * @since 11
 */
typedef struct Rdb_ChangeInfo {
    /**
     * The version used to uniquely identify the Rdb_ChangeInfo struct.
     */
    int version;

    /**
     * The name of changed table.
     */
    const char *tableName;

    /**
     * The {@link Rdb_ChangeType} of changed table.
     */
    int ChangeType;

    /**
     * The {@link Rdb_KeyInfo} of inserted rows.
     */
    Rdb_KeyInfo inserted;

    /**
     * The {@link Rdb_KeyInfo} of updated rows.
     */
    Rdb_KeyInfo updated;

    /**
     * The {@link Rdb_KeyInfo} of deleted rows.
     */
    Rdb_KeyInfo deleted;
} Rdb_ChangeInfo;

/**
 * @brief Indicates the subscribe type.
 *
 * @since 11
 */
typedef enum Rdb_SubscribeType {
    /**
     * @brief Subscription to cloud data changes.
     */
    RDB_SUBSCRIBE_TYPE_CLOUD,

    /**
     * @brief Subscription to cloud data change details.
     */
    RDB_SUBSCRIBE_TYPE_CLOUD_DETAILS,

    /**
     * @brief Subscription to local data change details.
     * @since 12
     */
    RDB_SUBSCRIBE_TYPE_LOCAL_DETAILS,
} Rdb_SubscribeType;

/**
 * @brief The callback function of cloud data change event.
 *
 * @param context Represents the context of data observer.
 * @param values Indicates the cloud accounts that changed.
 * @param count The count of changed cloud accounts.
 * @since 11
 */
typedef void (*Rdb_BriefObserver)(void *context, const char *values[], uint32_t count);

/**
 * @brief The callback function of cloud data change details event.
 *
 * @param context Represents the context of data observer.
 * @param changeInfo Indicates the {@link Rdb_ChangeInfo} of changed tables.
 * @param count The count of changed tables.
 * @see Rdb_ChangeInfo.
 * @since 11
 */
typedef void (*Rdb_DetailsObserver)(void *context, const Rdb_ChangeInfo **changeInfo, uint32_t count);

/**
 * @brief Indicates the callback functions.
 *
 * @since 11
 */
typedef union Rdb_SubscribeCallback {
    /**
     * The callback function of cloud data change details event.
     */
    Rdb_DetailsObserver detailsObserver;

    /**
     * The callback function of cloud data change event.
     */
    Rdb_BriefObserver briefObserver;
} Rdb_SubscribeCallback;

/**
 * @brief Indicates the observer of data.
 *
 * @since 11
 */
typedef struct Rdb_DataObserver {
    /**
     * The context of data observer.
     */
    void *context;

    /**
     * The callback of data observer.
     */
    Rdb_SubscribeCallback callback;
} Rdb_DataObserver;

/**
 * @brief Registers an observer for the database.
 * When data in the distributed database or the local database changes, the callback will be invoked.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param type Indicates the subscription type, which is defined in {@link Rdb_SubscribeType}.
 * If its value is RDB_SUBSCRIBE_TYPE_LOCAL_DETAILS, the callback will be invoked for data changes
 * in the local database.
 * @param observer The {@link Rdb_DataObserver} of change events in the database.
 * @return Returns the status code of the execution. See {@link OH_Rdb_ErrCode}.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @see Rdb_DataObserver.
 * @since 11
 */
int OH_Rdb_Subscribe(OH_Rdb_Store *store, Rdb_SubscribeType type, const Rdb_DataObserver *observer);

/**
 * @brief Remove specified observer of specified type from the database.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param type Indicates the subscription type, which is defined in {@link Rdb_SubscribeType}.
 * @param observer The {@link Rdb_DataObserver} of change events in the database.
 * If this is nullptr, remove all observers of the type.
 * @return Returns the status code of the execution. See {@link OH_Rdb_ErrCode}.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @see Rdb_DataObserver.
 * @since 11
 */
int OH_Rdb_Unsubscribe(OH_Rdb_Store *store, Rdb_SubscribeType type, const Rdb_DataObserver *observer);

/**
 * @brief Indicates the database synchronization mode.
 *
 * @since 11
 */
typedef enum Rdb_SyncMode {
    /**
     * @brief Indicates that data is synchronized from the end with the closest modification time
     * to the end with a more distant modification time.
     */
    RDB_SYNC_MODE_TIME_FIRST,
    /**
     * @brief Indicates that data is synchronized from local to cloud.
     */
    RDB_SYNC_MODE_NATIVE_FIRST,
    /**
     * @brief Indicates that data is synchronized from cloud to local.
     */
    RDB_SYNC_MODE_CLOUD_FIRST
} Rdb_SyncMode;

/**
 * @brief Describes the statistic of the cloud sync process.
 *
 * @since 11
 */
typedef struct Rdb_Statistic {
    /**
     * Describes the total number of data to sync.
     */
    int total;

    /**
     * Describes the number of successfully synced data.
     */
    int successful;

    /**
     * Describes the number of data failed to sync.
     */
    int failed;

    /**
     * Describes the number of data remained to sync.
     */
    int remained;
} Rdb_Statistic;

/**
 * @brief Describes the {@link Rdb_Statistic} details of the table.
 *
 * @since 11
 */
typedef struct Rdb_TableDetails {
    /**
     * Indicates the name of changed table.
     */
    const char *table;

    /**
     * Describes the {@link Rdb_Statistic} details of the upload process.
     */
    Rdb_Statistic upload;

    /**
     * Describes the {@link Rdb_Statistic} details of the download process.
     */
    Rdb_Statistic download;
} Rdb_TableDetails;

/**
 * The cloud sync progress
 *
 * @since 11
 */
typedef enum Rdb_Progress {
    /**
     * @brief Means the sync process begin.
     */
    RDB_SYNC_BEGIN,

    /**
     * @brief Means the sync process is in progress
     */
    RDB_SYNC_IN_PROGRESS,

    /**
     * @brief Means the sync process is finished
     */
    RDB_SYNC_FINISH
} Rdb_Progress;

/**
   * Describes the status of cloud sync progress.
   *
   * @since 11
   */
typedef enum Rdb_ProgressCode {
    /**
     * @brief Means the status of progress is success.
     */
    RDB_SUCCESS,

    /**
     * @brief Means the progress meets unknown error.
     */
    RDB_UNKNOWN_ERROR,

    /**
     * @brief Means the progress meets network error.
     */
    RDB_NETWORK_ERROR,

    /**
     * @brief Means cloud is disabled.
     */
    RDB_CLOUD_DISABLED,

    /**
     * @brief Means the progress is locked by others.
     */
    RDB_LOCKED_BY_OTHERS,

    /**
     * @brief Means the record exceeds the limit.
     */
    RDB_RECORD_LIMIT_EXCEEDED,

    /**
     * Means the cloud has no space for the asset.
     */
    RDB_NO_SPACE_FOR_ASSET
} Rdb_ProgressCode;

/**
 * @brief Indicates version of {@link Rdb_ProgressDetails}
 *
 * @since 11
 */
#define DISTRIBUTED_PROGRESS_DETAIL_VERSION 1

/**
 * @brief Describes detail of the cloud sync progress.
 *
 * @since 11
 */
typedef struct Rdb_ProgressDetails {
    /**
     * The version used to uniquely identify the Rdb_ProgressDetails struct.
     */
    int version;

    /**
     * Describes the status of data sync progress. Defined in {@link Rdb_Progress}.
     */
    int schedule;

    /**
     * Describes the code of data sync progress. Defined in {@link Rdb_ProgressCode}.
     */
    int code;

    /**
     * Describes the length of changed tables in data sync progress.
     */
    int32_t tableLength;
} Rdb_ProgressDetails;

/**
 * @brief Get table details from progress details.
 *
 * @param progress Represents a pointer to an {@link Rdb_ProgressDetails} instance.
 * @param version Indicates the version of current {@link Rdb_ProgressDetails}.
 * @return If the operation is successful, a pointer to the instance of the {@link Rdb_TableDetails}
 * structure is returned.If get details is failed,nullptr is returned.
 * @see Rdb_ProgressDetails
 * @see Rdb_TableDetails
 * @since 11
 */
Rdb_TableDetails *OH_Rdb_GetTableDetails(Rdb_ProgressDetails *progress, int32_t version);

/**
 * @brief The callback function of progress.
 *
 * @param progressDetails The details of the sync progress.
 * @see Rdb_ProgressDetails.
 * @since 11
 */
typedef void (*Rdb_ProgressCallback)(void *context, Rdb_ProgressDetails *progressDetails);

/**
 * @brief The callback function of sync.
 *
 * @param progressDetails The details of the sync progress.
 * @see Rdb_ProgressDetails.
 * @since 11
 */
typedef void (*Rdb_SyncCallback)(Rdb_ProgressDetails *progressDetails);

/**
 * @brief The observer of progress.
 *
 * @since 11
 */
typedef struct Rdb_ProgressObserver {
    /**
     * The context of progress observer.
     */
    void *context;

    /**
     * The callback function of progress observer.
     */
    Rdb_ProgressCallback callback;
} Rdb_ProgressObserver;

/**
 * @brief Sync data to cloud.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param mode Represents the {@link Rdb_SyncMode} of sync progress.
 * @param tables Indicates the names of tables to sync.
 * @param count The count of tables to sync. If value equals 0, sync all tables of the store.
 * @param observer The {@link Rdb_ProgressObserver} of cloud sync progress.
 * @return Returns the status code of the execution. See {@link OH_Rdb_ErrCode}.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @see Rdb_ProgressObserver.
 * @since 11
 */
int OH_Rdb_CloudSync(OH_Rdb_Store *store, Rdb_SyncMode mode, const char *tables[], uint32_t count,
    const Rdb_ProgressObserver *observer);

/**
 * @brief Subscribes to the automatic synchronization progress of an RDB store.
 * A callback will be invoked when there is a notification of the automatic synchronization progress.
 *
 * @param store Indicates the pointer to the target {@Link OH_Rdb_Store} instance.
 * @param observer The {@link Rdb_ProgressObserver} for the automatic synchornizaiton progress.
 * Indicates the callback invoked to return the automatic synchronization progress.
 * @return Returns the status code of the execution. See {@link OH_Rdb_ErrCode}.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @see Rdb_ProgressObserver.
 * @since 11
 **/
int OH_Rdb_SubscribeAutoSyncProgress(OH_Rdb_Store *store, const Rdb_ProgressObserver *observer);

/**
 * @brief Unsubscribes from the automatic synchronziation progress of an RDB store.
 *
 * @param store Indicates the pointer to the target {@Link OH_Rdb_Store} instance.
 * @param observer Indicates the {@link Rdb_ProgressObserver} callback for the automatic synchornizaiton progress.
 * If it is a null pointer, all callbacks for the automatic synchornizaiton progress will be unregistered.
 * @return Returns the status code of the execution. See {@link OH_Rdb_ErrCode}.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store.
 * @see Rdb_ProgressObserver.
 * @since 11
 */
int OH_Rdb_UnsubscribeAutoSyncProgress(OH_Rdb_Store *store, const Rdb_ProgressObserver *observer);

/**
 * @brief Lock data from the database based on specified conditions.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
 * Indicates the specified lock condition.
 * @return Returns the status code of the execution. See {@link OH_Rdb_ErrCode}.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store, OH_Predicates, OH_Rdb_ErrCode.
 * @since 12
 */
int OH_Rdb_LockRow(OH_Rdb_Store *store, OH_Predicates *predicates);

/**
 * @brief Unlock data from the database based on specified conditions.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
 * Indicates the specified unlock condition.
 * @return Returns the status code of the execution. See {@link OH_Rdb_ErrCode}.
 *     {@link RDB_OK} - success.
 *     {@link RDB_E_INVALID_ARGS} - The error code for common invalid args.
 * @see OH_Rdb_Store, OH_Predicates, OH_Rdb_ErrCode.
 * @since 12
 */
int OH_Rdb_UnlockRow(OH_Rdb_Store *store, OH_Predicates *predicates);

/**
 * @brief Queries locked data in the database based on specified conditions.
 *
 * @param store Represents a pointer to an {@link OH_Rdb_Store} instance.
 * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
 * Indicates the specified query condition.
 * @param columnNames Indicates the columns to query. If the value is empty array, the query applies to all columns.
 * @param length Indicates the length of columnNames.
 * @return If the query is successful, a pointer to the instance of the @link OH_Cursor} structure is returned.
 *         If Get store failed or resultSet is nullptr, nullptr is returned.
 * @see OH_Rdb_Store, OH_Predicates, OH_Cursor.
 * @since 12
 */
OH_Cursor *OH_Rdb_QueryLockedRow(
    OH_Rdb_Store *store, OH_Predicates *predicates, const char *const *columnNames, int length);
#ifdef __cplusplus
};
#endif

#endif // RELATIONAL_STORE_H