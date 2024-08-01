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

#ifndef RPMB_DRIVER_RW_API_H
#define RPMB_DRIVER_RW_API_H
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
 * @file rpmb_driver_rw_api.h
 *
 * @brief APIs related to RPMB driver read and write.
 * Provides the function of reading and writing RPMB driver.
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
 * @brief Defines the total block number.
 *
 * @since 12
 * @version 1.0
 */
#define TOTAL_BLK 4

/**
 * @brief Defines the size of block.
 *
 * @since 12
 * @version 1.0
 */
#define BLK_SIZE 256

/**
 * @brief Defines the size of the total block.
 *
 * @since 12
 * @version 1.0
 */
#define TOTAL_BLK_SIZE (TOTAL_BLK * BLK_SIZE)

#define SEC_WRITE_PROTECT_ENTRY_NUM 4
#define SEC_WRITE_PROTECT_ENTRY_RESERVED_NUM 3
#define SEC_WRITE_PROTECT_ENTRY_RESERVED_SIZE 16
#define SEC_WRITE_PROTECT_FRAME_RESERVED_NUM 14
#define SEC_WRITE_PROTECT_FRAME_RESERVED_END_NUM 176
#define SEC_WRITE_PROTECT_BLK_SIZE 256
#define SEC_WRITE_PROTECT_LUN_MAX 5

/**
 * @brief A WPF set to one specifies that the logical unit shall inhibit alteration of the medium for LBA within
 * the range indicated by LOGICAL BLOCK ADDRESS field and NUMBER OF LOGICAL BLOCKS field.
 * Commands requiring writes to the medium shall be terminated with CHECK CONDITION status,
 * with the sense key set to DATA PROTECT, and the additional sense code set to WRITE PROTECTED.
 *
 * @since 12
 * @version 1.0
 */
typedef enum {
    SEC_WRITE_PROTECT_DISABLE = 0,
    SEC_WRITE_PROTECT_ENABLE = 1,
} write_protect_flag;

/**
 * @brief Write Protect Type specifies how WPF bit may be modified.
 *
 * @since 12
 * @version 1.0
 */
typedef enum {
    /** WPF bit is persistent through power cycle and hardware reset.
    * WPF value may only be changed writing to Secure Write Protect Configuration Block.
    */
    NV_TYPE = 0,
    /** WPF bit is automatically cleared to 0b after power cycle or hardware reset. */
    P_TYPE = 1,
    /** WPF bit is automatically set to 1b after power cycle or hardware reset. */
    NV_AWP_TYPE = 2,
} write_protect_type;

/**
 * @brief Secure Write Protect Entry.
 * +-----+---+---+---+---+---+---+---+----+
 * |     | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0  |
 * +-----+---+---+---+---+---+---+---+----+
 * | 0   |       Reserved    |  WFT  | WPF| -> wp_data
 * +-----+---+---+---+---+---+---+---+----+
 * | 1   |           Reserved             |
 * +-----+---+---+---+---+---+---+---+----+
 * | 2   |           Reserved             |
 * +-----+---+---+---+---+---+---+---+----+
 * | 3   |           Reserved             |
 * +-----+---+---+---+---+---+---+---+----+
 * | 4   |     LOGICAL BLOCK ADDRESS      | -> logical_blk_addr
 * +-----+                                +
 * | ... |                                |
 * +-----+                                +
 * | 11  |                                |
 * +-----+                                +
 * | 12  |                                |
 * +-----+---+---+---+---+---+---+---+----+
 * | ... |     NUMBER OF LOGICAL BLOCKS   | -> logical_blk_num
 * +-----+---+---+---+---+---+---+---+----+
 * | 15  |                                |
 * +-----+---+---+---+---+---+---+---+----+
 *
 * @since 12
 * @version 1.0
 */
struct rpmb_protect_cfg_blk_entry {
    uint8_t wp_data;
    uint8_t reserved[SEC_WRITE_PROTECT_ENTRY_RESERVED_NUM];
    /** This field specifies the LBA of the first logical address of the Secure Write Protect ares. */
    uint64_t logical_blk_addr;
    /** This field specifies the number of contiguous logical size that belong to the Secure Write Protect. */
    uint32_t logical_blk_num;
}__attribute__((packed));


/**
 * @brief Secure Write Protect Configuration Block is supported by RPMB region 0 only.
 * This block is used for configuring secure write protect areas in logical units.
 * Each Secure Write Protect Configuration Block for each logical unit.
 * Each entry represents one secure write protect area.
 * If an entry is not used, then the related fields shall contain a value of zero.
 * +-----+---+---+---+---+---+---+---+----+
 * |     | 7 | 6 | 5 | 4 | 3 | 2 | 1 | 0  |
 * +-----+---+---+---+---+---+---+---+----+
 * | 0   |              LUN               |
 * +-----+---+---+---+---+---+---+---+----+
 * | 1   |          DATA LENGTH           |
 * +-----+---+---+---+---+---+---+---+----+
 * | 2   |                                |
 * +-----+                                +
 * | ... |           Reserved             |
 * +-----+                                +
 * | 15  |                                |
 * +-----+---+---+---+---+---+---+---+----+
 * | 16  |                                |
 * +-----+                                +
 * | ... | Secure Write Protect Entry 0   |
 * +-----+                                +
 * | 31  |                                |
 * +-----+---+---+---+---+---+---+---+----+
 * | 32  |                                |
 * +-----+                                +
 * | ... | Secure Write Protect Entry 1   |
 * +-----+                                +
 * | 47  |                                |
 * +-----+---+---+---+---+---+---+---+----+
 * | 48  |                                |
 * +-----+                                +
 * | ... | Secure Write Protect Entry 1   |
 * +-----+                                +
 * | 63  |                                |
 * +-----+---+---+---+---+---+---+---+----+
 * | 64  |                                |
 * +-----+                                +
 * | ... | Secure Write Protect Entry 1   |
 * +-----+                                +
 * | 79  |                                |
 * +-----+---+---+---+---+---+---+---+----+
 * | 80  |                                |
 * +-----+                                +
 * | ... |           Reserved             |
 * +-----+                                +
 * | 255 |                                |
 * +-----+---+---+---+---+---+---+---+----+
 *
 * @since 12
 * @version 1.0
 */
struct rpmb_protect_cfg_block {
    uint8_t lun;
    uint8_t data_length;
    uint8_t reserved[SEC_WRITE_PROTECT_FRAME_RESERVED_NUM];
    struct rpmb_protect_cfg_blk_entry entries[SEC_WRITE_PROTECT_ENTRY_NUM];
    uint8_t reserved_end[SEC_WRITE_PROTECT_FRAME_RESERVED_END_NUM];
}__attribute__((packed));

/**
 * @brief Write protect config block by RPMB driver.
 *
 * @param lun Indicates the logical unit to which secure write protection shall apply,
 * and <b>0</b> <= lun <= {@code SEC_WRITE_PROTECT_LUN_MAX}
 * @param entries Indicates the Secure Write Protect Entry array, The maximum length is 4.
 * @param len Indicates the real length of the Secure Write Protect Entry array, which value is less than 4.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if the input parameter is incorrect.
 *         Returns {@code TEE_ERROR_OUT_OF_MEMORY} if the send message fail.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_rpmb_protect_cfg_blk_write(uint8_t lun, struct rpmb_protect_cfg_blk_entry *entries, uint32_t len);

/**
 * @brief Read protect config block by RPMB driver.
 *
 * @param lun Indicates the logical unit to which secure read protection shall apply,
 * and 0 <= lun <= <b>SEC_WRITE_PROTECT_LUN_MAX</b>.
 * @param entries Indicates the Secure Read Protect Entry array, The maximum length is 4.
 * @param len Indicates the real length of the Secure Read Protect Entry array, which value is less than 4.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if the input parameter is incorrect.
 *         Returns {@code TEE_ERROR_OUT_OF_MEMORY} if the send message fail.
  *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_rpmb_protect_cfg_blk_read(uint8_t lun, struct rpmb_protect_cfg_blk_entry *entries, uint32_t *len);

/**
 * @brief Write plaintext buffer to RPMB driver.
 *
 * @param buf Indicates the buffer for writing data.
 * @param size Indicates the length of buffer, the maximum value is 1024.
 * @param block Indicates the block index of the position of start block, the value is [0, 3].
 * @param offset Indicates the offset bytes of data position, and the value of offest bytes is less than 256.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if the input parameter is incorrect.
 *         Returns {@code TEE_ERROR_OUT_OF_MEMORY} if the send message fail.
  *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_rpmb_driver_write(const uint8_t *buf, size_t size, uint32_t block, uint32_t offset);

/**
 * @brief Read plaintext buffer from RPMB driver.
 *
 * @param buf Indicates the buffer for read data.
 * @param size Indicates the length of buffer, the maximum value is 1024.
 * @param block Indicates the block index of the position of start block, the value is [0, 3].
 * @param offset Indicates the offset bytes of data position, and the value of offest bytes is less than 256.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if the input parameter is incorrect.
 *         Returns {@code TEE_ERROR_OUT_OF_MEMORY} if the send message fail.
  *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_rpmb_driver_read(uint8_t *buf, size_t size, uint32_t block, uint32_t offset);

/**
 * @brief Remove data from RPMB driver.
 *
 * @param size Indicates the length of remove data, the maximum value is 1024.
 * @param block Indicates the block index of the position of start block, the value is [0, 3].
 * @param offset Indicates the offset bytes of data position, and the value of offest bytes is less than 256.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if the input parameter is incorrect.
 *         Returns {@code TEE_ERROR_OUT_OF_MEMORY} if the send message fail.
  *
 * @since 12
 * @version 1.0
 */
TEE_Result tee_ext_rpmb_driver_remove(size_t size, uint32_t block, uint32_t offset);

#ifdef __cplusplus
}
#endif

/** @} */
#endif