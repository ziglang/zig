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

#ifndef OH_PREDICATES_H
#define OH_PREDICATES_H

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
 * @file oh_predicates.h
 *
 * @brief Declared predicate related functions and enumerations.
 *
 * @since 10
 */

#include <cstdint>
#include <stddef.h>
#include "database/rdb/oh_value_object.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Result set sort type.
 *
 * @since 10
 */
typedef enum OH_OrderType {
    /**
     * Ascend order.
     */
    ASC = 0,
    /**
     * Descend order.
     */
    DESC = 1,
} OH_OrderType;

/**
 * @brief Define the OH_Predicates structure type.
 *
 * @since 10
 */
typedef struct OH_Predicates {
    /**
     * The id used to uniquely identify the OH_Predicates struct.
     */
    int64_t id;

    /**
     * @brief Function pointer. Restricts the value of the field to be equal to the specified value to the predicates.
     *
     * This method is similar to = of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*equalTo)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer.
     * Restricts the value of the field to be not equal to the specified value to the predicates.
     *
     * This method is similar to != of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*notEqualTo)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer. Add left parenthesis to predicate.
     *
     * This method is similar to ( of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*beginWrap)(OH_Predicates *predicates);

    /**
     * @brief Function pointer. Add right parenthesis to predicate.
     *
     * This method is similar to ) of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*endWrap)(OH_Predicates *predicates);

    /**
     * @brief Function pointer. Adds an or condition to the predicates.
     *
     * This method is similar to OR of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*orOperate)(OH_Predicates *predicates);

    /**
     * @brief Function pointer. Adds an and condition to the predicates.
     *
     * This method is similar to AND of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*andOperate)(OH_Predicates *predicates);

    /**
     * @brief Function pointer. Restricts the value of the field which is null to the predicates.
     *
     * This method is similar to IS NULL of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*isNull)(OH_Predicates *predicates, const char *field);

    /**
     * @brief Function pointer. Restricts the value of the field which is not null to the predicates.
     *
     * This method is similar to IS NOT NULL of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*isNotNull)(OH_Predicates *predicates, const char *field);

    /**
     * @brief Function pointer. Restricts the value of the field to be like the specified value to the predicates.
     *
     * This method is similar to LIKE of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*like)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer. Restricts the value of the field to be between the specified value to the predicates.
     *
     * This method is similar to BETWEEN of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*between)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer.
     * Restricts the value of the field to be not between the specified value to the predicates.
     *
     * This method is similar to NOT BETWEEN of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*notBetween)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer.
     * Restricts the value of the field to be greater than the specified value to the predicates.
     *
     * This method is similar to > of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*greaterThan)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer.
     * Restricts the value of the field to be less than the specified value to the predicates.
     *
     * This method is similar to < of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*lessThan)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer.
     * Restricts the value of the field to be greater than or equal to the specified value to the predicates.
     *
     * This method is similar to >= of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*greaterThanOrEqualTo)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer.
     * Restricts the value of the field to be less than or equal to the specified value to the predicates.
     *
     * This method is similar to <= of the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*lessThanOrEqualTo)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer. Restricts the ascending or descending order of the return list.
     * When there are several orders, the one close to the head has the highest priority.
     *
     * This method is similar ORDER BY the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param type Indicates the sort {@link OH_OrderType} type.
     * @return Returns the self.
     * @see OH_Predicates, OH_OrderType.
     * @since 10
     */
    OH_Predicates *(*orderBy)(OH_Predicates *predicates, const char *field, OH_OrderType type);

    /**
     * @brief Function pointer. Configure predicates to filter duplicate records and retain only one of them.
     *
     * This method is similar DISTINCT the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*distinct)(OH_Predicates *predicates);

    /**
     * @brief Function pointer. Predicate for setting the maximum number of data records.
     *
     * This method is similar LIMIT the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param value Indicates the maximum number of records.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*limit)(OH_Predicates *predicates, unsigned int value);

    /**
     * @brief Function pointer. Configure the predicate to specify the starting position of the returned result.
     *
     * This method is similar OFFSET the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param rowOffset Indicates the number of rows to offset from the beginning. The value is a positive integer.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*offset)(OH_Predicates *predicates, unsigned int rowOffset);

    /**
     * @brief Function pointer. Configure predicates to group query results by specified columns.
     *
     * This method is similar GROUP BY the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param fields Indicates the column names that the grouping depends on.
     * @param length Indicates the length of fields.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*groupBy)(OH_Predicates *predicates, char const *const *fields, int length);

    /**
     * @brief Function pointer.
     * Configure the predicate to match the specified field and the value within the given array range.
     *
     * This method is similar IN the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*in)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer.
     * Configure the predicate to match the specified field and the value not within the given array range.
     *
     * This method is similar NOT IN the SQL statement.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @param field Indicates the column name in the database table.
     * @param valueObject Represents a pointer to an {@link OH_VObject} instance.
     * @return Returns the self.
     * @see OH_Predicates, OH_VObject.
     * @since 10
     */
    OH_Predicates *(*notIn)(OH_Predicates *predicates, const char *field, OH_VObject *valueObject);

    /**
     * @brief Function pointer. Initialize OH_Predicates object.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @return Returns the self.
     * @see OH_Predicates.
     * @since 10
     */
    OH_Predicates *(*clear)(OH_Predicates *predicates);

    /**
     * @brief Destroy the {@link OH_Predicates} object and reclaim the memory occupied by the object.
     *
     * @param predicates Represents a pointer to an {@link OH_Predicates} instance.
     * @return Returns the status code of the execution..
     * @see OH_Predicates.
     * @since 10
     */
    int (*destroy)(OH_Predicates *predicates);
} OH_Predicates;

#ifdef __cplusplus
};
#endif

#endif // OH_PREDICATES_H