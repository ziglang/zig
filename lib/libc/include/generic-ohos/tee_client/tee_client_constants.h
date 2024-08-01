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

#ifndef TEE_CLIENT_CONSTANTS_H
#define TEE_CLIENT_CONSTANTS_H
/**
 * @addtogroup TeeClient
 * @{
 *
 * @brief Provides APIs for the client applications (CAs) in the Rich Execution Environment (normal mode) to
 * access the trusted applications (TAs) in a Trusted Execution Environment (TEE).
 *
 * @since 12
 * @version 1.0
 */

/**
 * @file tee_client_constants.h
 *
 * @brief Defines public data and constants.
 *
 * @library libteec.so
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

/**
 * @brief Defines the number of <b>TEEC_Parameter</b>s in <b>TEEC_Operation</b>.
 *
 * @since 12
 * @version 1.0
 */
#define TEEC_PARAM_NUM 4

/**
 * @brief Defines the error codes returned.
 *
 * @since 12
 * @version 1.0
 */
enum TEEC_ReturnCode {
    /** The operation is successful. */
    TEEC_SUCCESS = 0x0,
    /** Invalid command. The command is not supported by the TA. */
    TEEC_ERROR_INVALID_CMD,
    /** The TA does not exist. */
    TEEC_ERROR_SERVICE_NOT_EXIST,
    /** The session between the CA and TA does not exist. */
    TEEC_ERROR_SESSION_NOT_EXIST,
    /** The number of connections to the TA has reached the limit. */
    TEEC_ERROR_SESSION_MAXIMUM,
    /** The TA to be registered already exists. */
    TEEC_ERROR_REGISTER_EXIST_SERVICE,
    /** Secure OS framework error. */
    TEEC_ERROR_TAGET_DEAD_FATAL,
    /** Failed to read the file. */
    TEEC_ERROR_READ_DATA,
    /** Failed to write the file. */
    TEEC_ERROR_WRITE_DATA,
    /** Failed to truncate the file. */
    TEEC_ERROR_TRUNCATE_OBJECT,
    /** Failed to seek data. */
    TEEC_ERROR_SEEK_DATA,
    /** File synchronization error. */
    TEEC_ERROR_FSYNC_DATA,
    /** Failed to rename the file. */
    TEEC_ERROR_RENAME_OBJECT,
    /** Failed to load the TA when opening a session. */
    TEEC_ERROR_TRUSTED_APP_LOAD_ERROR,
    /** Failed to initialize the TA. */
    TEEC_ERROR_GENERIC = 0xFFFF0000,
    /** Permission verification failed. Permission verification is performed before a TEE or session is opened or
     a command is sent. */
    TEEC_ERROR_ACCESS_DENIED = 0xFFFF0001,
    /** The operation is canceled. This error code is returned when you operate the parameter with
     the cancallation flag. */
    TEEC_ERROR_CANCEL = 0xFFFF0002,
    /** Concurrent access causes permission conflict. Concurrent access to files in the trusted storage
     service may cause this error. */
    TEEC_ERROR_ACCESS_CONFLICT = 0xFFFF0003,
    /** Too much data is passed in the requested operation for the TA to parse. */
    TEEC_ERROR_EXCESS_DATA = 0xFFFF0004,
    /** Incorrect data format. The TA failed to parse the parameters sent from the CA. */
    TEEC_ERROR_BAD_FORMAT = 0xFFFF0005,
    /** Invalid parameter. The input parameter is null or invalid. */
    TEEC_ERROR_BAD_PARAMETERS = 0xFFFF0006,
    /** The operation in the current state is invalid. This error code is returned if the trusted storage service is not
     initialized when a trusted storage service operation is requested. */
    TEEC_ERROR_BAD_STATE = 0xFFFF0007,
    /** The requested data is not found. */
    TEEC_ERROR_ITEM_NOT_FOUND = 0xFFFF0008,
    /** The requested operation has not been implemented yet. This error code is returned when
     <b>TEEC_RequestCancellation</b> is called. */
    TEEC_ERROR_NOT_IMPLEMENTED = 0xFFFF0009,
    /** The requested operation is valid but is not supported in this implementation. This error code is returned
     when certain algorithms of the secure encryption and decryption service, such as DSA, are requested. */
    TEEC_ERROR_NOT_SUPPORTED = 0xFFFF000A,
    /** Expected data for the requested operation is not found. */
    TEEC_ERROR_NO_DATA = 0xFFFF000B,
    /** The available system resources are insufficient. */
    TEEC_ERROR_OUT_OF_MEMORY = 0xFFFF000C,
    /** The system is busy. Some resources are exclusively used by the system. */
    TEEC_ERROR_BUSY = 0xFFFF000D,
    /** Communication between an application in the REE and a TA failed. */
    TEEC_ERROR_COMMUNICATION = 0xFFFF000E,
    /** A security fault is detected in the TEE. */
    TEEC_ERROR_SECURITY = 0xFFFF000F,
    /** The supplied buffer is too short for the output generated.
     This error may occur when {@code TEEC_MEMREF_TEMP_OUTPUT} is used. */
    TEEC_ERROR_SHORT_BUFFER = 0xFFFF0010,
    /** MAC value check error. */
    TEEC_ERROR_MAC_INVALID = 0xFFFF3071,
    /** The TA crashed. */
    TEEC_ERROR_TARGET_DEAD = 0xFFFF3024,
    /** Common error. */
    TEEC_FAIL = 0xFFFF5002
};

/**
 * @brief Defines the sources of the error codes returned.
 *
 * @since 12
 * @version 1.0
 */
enum TEEC_ReturnCodeOrigin {
    /** The error code indicates an error originated from the client API. */
    TEEC_ORIGIN_API = 0x1,
    /** The error code indicates an error originated from the communication between the REE and TEE. */
    TEEC_ORIGIN_COMMS = 0x2,
    /** The error code indicates an error originated within the TEE code. */
    TEEC_ORIGIN_TEE = 0x3,
    /** The error code indicates an error originated within the TA code. */
    TEEC_ORIGIN_TRUSTED_APP = 0x4,
};

/**
 * @brief Defines the identifiers of the shared memory.
 *
 * @since 12
 * @version 1.0
 */
enum TEEC_SharedMemCtl {
    /** The shared memory can carry data from CAs to TAs. */
    TEEC_MEM_INPUT = 0x1,
    /** The shared memory can carry data from TAs to CAs. */
    TEEC_MEM_OUTPUT = 0x2,
    /** The shared memory can carry data transmitted between CAs and TAs. */
    TEEC_MEM_INOUT = 0x3,
};

/**
 * @brief Defines the parameter types.
 *
 * @since 12
 * @version 1.0
 */
enum TEEC_ParamType {
    /** The parameter is not used. */
    TEEC_NONE = 0x0,
    /** The parameter is a {@code TEEC_Value} tagged as input. Data flows from a CA to a TA. */
    TEEC_VALUE_INPUT = 0x01,
    /** The parameter is a {@code TEEC_Value} tagged as output. Data flows from a TA to a CA. */
    TEEC_VALUE_OUTPUT = 0x02,
    /** The parameter is a {@code TEEC_Value} tagged as both input and output. */
    TEEC_VALUE_INOUT = 0x03,
    /** The parameter is a {@code TEEC_TempMemoryReference} tagged as input. Data flows from a CA to a TA. */
    TEEC_MEMREF_TEMP_INPUT = 0x05,
    /** The parameter is a {@code TEEC_TempMemoryReference} tagged as output. Data flows from a TA to a CA. */
    TEEC_MEMREF_TEMP_OUTPUT = 0x06,
    /** The parameter is a {@code TEEC_TempMemoryReference} tagged as both input and output.
     Data is transmitted between a TA and a CA. */
    TEEC_MEMREF_TEMP_INOUT = 0x07,
    /** The parameter is a {@code TEEC_IonReference} tagged as input. Data flows from a CA to a TA**/
    TEEC_ION_INPUT = 0x08,
    /** The parameter is a {@code TEEC_IonSglistReference} tagged as input. Data flows from a CA to a TA**/
    TEEC_ION_SGLIST_INPUT = 0x09,
    /** The parameter is a {@code TEEC_RegisteredMemoryReference} that refers to the entire memory block.
     The data flow is the same as that of {@code TEEC_SharedMemCtl}. */
    TEEC_MEMREF_WHOLE = 0xc,
    /** The parameter is a {@code TEEC_RegisteredMemoryReference} tagged as input. Data flows from a CA to a TA. */
    TEEC_MEMREF_PARTIAL_INPUT = 0xd,
    /** The parameter is a {@code TEEC_RegisteredMemoryReference} tagged as output. Data flows from a TA to a CA. */
    TEEC_MEMREF_PARTIAL_OUTPUT = 0xe,
    /** The parameter is a {@code TEEC_RegisteredMemoryReference} tagged as both input and output.
     Data is transmitted between a TA and a CA. */
    TEEC_MEMREF_PARTIAL_INOUT = 0xf
};

/**
 * @brief Defines the login methods.
 *
 * @since 12
 * @version 1.0
*/
enum TEEC_LoginMethod {
    /** No login data is provided. */
    TEEC_LOGIN_PUBLIC = 0x0,
    /** The login data about the user running the CA process is provided. */
    TEEC_LOGIN_USER,
    /** The login data about the group running the CA process is provided. */
    TEEC_LOGIN_GROUP,
    /** The login data about the running CA is provided. */
    TEEC_LOGIN_APPLICATION = 0x4,
    /** The login data about the user running the CA process and about the CA are provided. */
    TEEC_LOGIN_USER_APPLICATION = 0x5,
    /** The login data about the group running the CA process and about the CA are provided. */
    TEEC_LOGIN_GROUP_APPLICATION = 0x6,
    /** Login method reserved for TEEOS. */
    TEEC_LOGIN_IDENTIFY = 0x7,
};

/** @} */
#endif