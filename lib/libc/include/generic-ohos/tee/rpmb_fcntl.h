/*
 * Copyright (c) 2024 Huawei Device Co., Ltd.
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

#ifndef RPMB_RPMB_FCNTL_H
#define RPMB_RPMB_FCNTL_H
/**
 * @addtogroup TeeTrusted
 * @{
 *
 * @brief TEE(Trusted Excution Environment) API.
 * Provides security capability APIs such as trusted storage, encryption and decryption,
 * and trusted time for trusted application development.
 *
 * @since 12
 */

/**
 * @file rpmb_fcntl.h
 *
 * @brief Provides the APIs related to RPMB service.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Partition initialization, perform RPMB Key writing and formatting operations.
 *
 * @attention This function only needs to be executed once.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_RPMB_GENERIC} if the RPMB controller general error.
 *         Returns {@code TEE_ERROR_RPMB_MAC_FAIL} if the RPMB controller MAC check error.
 *         Returns {@code TEE_ERROR_RPMB_RESP_UNEXPECT_MAC} if the RPMB response data MAC check error.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_FS_Init(void);

/**
 * @brief RPMB secure storage fully formatted operation.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_RPMB_GENERIC} if the RPMB controller general error.
 *         Returns {@code TEE_ERROR_RPMB_MAC_FAIL} if the RPMB controller MAC check error.
 *         Returns {@code TEE_ERROR_RPMB_RESP_UNEXPECT_MAC} if the RPMB response data MAC check error.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_FS_Format(void);

/**
 * @brief Write files to RPMB.
 *
 * @attention If you want to improve the performance of writing files, you need to define the heap size in TA's
 * manifest to be at leaset 3 times the file size plus 256KB.
 * For example: To write a file with a size of 100KB, the defined heap size is at least
 * 556KB (3 * 100 + 256). If the heap size cannot be satisfied, the file writing will still succeed,
 * but the performance will be poor.
 *
 * @param filename Indicates the file name of the data to be written, the maximum length is 64 bytes.
 * @param buf Indicates the buffer for writting data.
 * @param size Indicates the size of the written data, the maximum size is 160KB.
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect, or the file name is longer than 64
 * bytes.
 *         Returns {@code TEE_ERROR_RPMB_NOSPC} if the RPMB partition has insufficient disk space.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_FS_Write(const char *filename, const uint8_t *buf, size_t size);

/**
 * @brief Read files from RPMB.
 *
 * @attention If you want to improve the performance of reading files, you need to define the heap size in TA's
 * manifest to be at leaset 3 times the file size plus 256KB.
 * For example: To read a file with a size of 100KB, the defined heap size is at least
 * 556KB (3 * 100 + 256). If the heap size cannot be satisfied, the file reading will still succeed,
 * but the performance will be poor.
 *
 * @param filename Indicates the file name of the data to be read, the maximum length is 64 bytes.
 * @param buf Indicates the buffer for reading data.
 * @param size Indicates the read data size.
 * @param count Indicates the size of the actual read.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect, or the file name is longer than 64
 * bytes.
 *         Returns {@code TEE_ERROR_RPMB_FILE_NOT_FOUND} if the file dose not exist.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_FS_Read(const char *filename, uint8_t *buf, size_t size, uint32_t *count);

/**
 * @brief Rename file name in RPMB.
 *
 * @param old_name Indicates the old file name.
 * @param new_name Indicates the new file name.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect, or the file name is longer than 64
 * bytes.
 *         Returns {@code TEE_ERROR_RPMB_FILE_NOT_FOUND} if the file dose not exist.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_FS_Rename(const char *old_name, const char *new_name);

/**
 * @brief Delete files in RPMB.
 *
 * @param filename Indicates the file name to be deleted.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect, or the file name is longer than 64
 * bytes.
 *         Returns {@code TEE_ERROR_RPMB_FILE_NOT_FOUND} if the file dose not exist.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_FS_Rm(const char *filename);

/**
 * @brief File status stored in RPMB partition, used in {@code TEE_RPMB_FS_Stat}.
 *
 * @since 12
 */
struct rpmb_fs_stat {
    /** Indicates the file size. */
    uint32_t size;
    uint32_t reserved;
};

/**
 * @brief Get file status in RPMB.
 *
 * @param filename Indicates the file name in RPMB.
 * @param stat Indicates the file status information obtained.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect, or the file name is longer than 64
 * bytes.
 *         Returns {@code TEE_ERROR_RPMB_FILE_NOT_FOUND} if the file dose not exist.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_FS_Stat(const char *filename, struct rpmb_fs_stat *stat);

/**
 * @brief Disk status stored in RPMB partition, used in {@code TEE_RPMB_FS_StatDisk}.
 *
 * @since 12
 */
struct rpmb_fs_statdisk {
    /** Indicates the total size of RPMB partition. */
    uint32_t disk_size;
    /** Indicates the TA used size. */
    uint32_t ta_used_size;
    /** Indicates the free size of the RPMB partition. */
    uint32_t free_size;
    uint32_t reserved;
};

/**
 * @brief Get the disk status.
 *
 * @param stat Indicates the disk status information obtained.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_FS_StatDisk(struct rpmb_fs_statdisk *stat);

/**
 * @brief File attribute definition, which means that the file cannot be erased during the factory reset.
 *
 * @since 12
*/
#define TEE_RPMB_FMODE_NON_ERASURE (1U << 0)

/**
 * @brief  File attribute definition, which means the attribute value of the cleard file.
 *
 * @since 12
*/
#define TEE_RPMB_FMODE_CLEAR 0


/**
 * @brief Set the file attribute in RPMB.
 *
 * @param filename Indicates the file name in RPMB.
 * @param fmode Indicates the file attribute, currently supports {@code TEE_RPMB_FMODE_NON_ERASURE} and
 * {@code TEE_RPMB_FMODE_CLEAR} two attributes, other values will return {@code TEE_ERROR_BAD_PARAMETERS}.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect,
 * or the file name is longer than 64 bytes.
 *         Returns {@code TEE_ERROR_RPMB_FILE_NOT_FOUND} if the file dose not exist.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_FS_SetAttr(const char *filename, uint32_t fmode);

/**
 * @brief Format, delete file attribute is erasable file, keep the file attribute is an inerasable file.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_RPMB_GENERIC} if the RPMB controller general error.
 *         Returns {@code TEE_ERROR_RPMB_MAC_FAIL} if the RPMB controller MAC check error.
 *         Returns {@code TEE_ERROR_RPMB_RESP_UNEXPECT_MAC} if the RPMB response data MAC check error.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_FS_Erase(void);

/**
 * @brief  Enumerates the types of RPMB key status, used in {@code TEE_RPMB_KEY_Status}.
 *
 * @since 12
*/
enum TEE_RPMB_KEY_STAT {
    /** RPMB Key status is invalid. */
    TEE_RPMB_KEY_INVALID = 0x0,
    /** RPMB Key has been programmed and matched correctly. */
    TEE_RPMB_KEY_SUCCESS,
    /** RPMB Key is not programmed. */
    TEE_RPMB_KEY_NOT_PROGRAM,
    /** RPMB Key has been programmed but failed to match. */
    TEE_RPMB_KEY_NOT_MATCH,
};

/**
 * @brief Obtain RPMB Key status.
 *
 * @return Returns {@code TEE_RPMB_KEY_SUCCESS} if the RPMB Key has been programmed and matched correctly.
 *         Returns {@code TEE_RPMB_KEY_NOT_PROGRAM} if the RPMB Key is not programmed.
 *         Returns {@code TEE_RPMB_KEY_NOT_MATCH} if RPMB Key has been programmed but failed to match.
 *         Returns {@code TEE_RPMB_KEY_INVALID} if the RPMB Key status is invalid.
 *
 * @since 12
 * @version 1.0
 */
uint32_t TEE_RPMB_KEY_Status(void);

/**
 * @brief Process the current TA version information.
 *
 * @param ta_version Indicates the TA version.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ERROR_GENERIC} if the processing failed.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_RPMB_TAVERSION_Process(uint32_t ta_version);
#ifdef __cplusplus
}
#endif

/** @} */
#endif