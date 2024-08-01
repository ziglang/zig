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

#ifndef TEE_INTERNAL_SE_API_H
#define TEE_INTERNAL_SE_API_H

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
 * @file tee_internal_se_api.h
 *
 * @brief Provides APIs related to the TEE Secure Element.
 *
 * @library NA
 * @kit TEE Kit
 * @syscap SystemCapability.Tee.TeeClient
 * @since 12
 * @version 1.0
 */

#include "tee_defines.h"

#ifdef __cplusplus
extern "C" {
#endif

struct __TEE_SEServiceHandle;
struct __TEE_SEReaderHandle;
struct __TEE_SESessionHandle;
struct __TEE_SEChannelHandle;

typedef struct __TEE_SEServiceHandle *TEE_SEServiceHandle;
typedef struct __TEE_SEReaderHandle *TEE_SEReaderHandle;
typedef struct __TEE_SESessionHandle *TEE_SESessionHandle;
typedef struct __TEE_SEChannelHandle *TEE_SEChannelHandle;

#define ATR_LEN_MAX 32U
#define AID_LEN_MIN 5U
#define AID_LEN_MAX 16U

/**
 * @brief Defines the maximum of the logic channel.
 *
 * @since 12
 */
#define SE_LOGIC_CHANNEL_MAX 8U

#define TEE_SC_TYPE_SCP03 0x01

#define BYTE_LEN 8

/**
 * @brief Represents the properties of the SE reader.
 *
 * @since 12
 */
typedef struct __TEE_SEReaderProperties {
    /** If an SE is present in the reader, the value is true. */
    bool sePresent;
    /** If this reader is only accessible via the TEE, the value is true. */
    bool teeOnly;
    /** If the response to a SELECT is available in the TEE, the value is true.*/
    bool selectResponseEnable;
} TEE_SEReaderProperties;

/**
 * @brief Defines the SE AID.
 *
 * @since 12
 */
typedef struct __TEE_SEAID {
    /** The value of the applet's AID. */
    uint8_t *buffer;
    /** The lenght of the applet's AID. */
    uint32_t bufferLen;
} TEE_SEAID;

/**
 * @brief Enumerates the types of the key.
 *
 * @since 12
 */
typedef enum {
    /** A base key acc. to SCP02. */
    TEE_SC_BASE_KEY = 0,
    /** A key set (key-MAC, key_ENC) acc. to SCP02, SCP03. */
    TEE_SC_KEY_SET = 1
} TEE_SC_KeyType;

typedef struct __TEE_SC_KeySetRef {
    /** Key-ENC (Static encryption key). */
    TEE_ObjectHandle scKeyEncHandle;
    /** Key-MAC (Static MAC key). */
    TEE_ObjectHandle scKeyMacHandle;
} TEE_SC_KeySetRef;

/**
 * @brief Enumerates the levels of the security.
 *
 * @since 12
 */
typedef enum {
    /** Nothing will be applied. */
    TEE_SC_NO_SECURE_MESSAGING = 0x00,
    /** Command and response APDU not be secured. */
    TEE_SC_AUTHENTICATE        = 0x80,
    /** Command APDU shall be MAC protected. */
    TEE_SC_C_MAC               = 0x01,
    /** Response APDU shall be MAC protected. */
    TEE_SC_R_MAC               = 0x10,
    /** Command and response APDU shall be MAC protected. */
    TEE_SC_CR_MAC              = 0x11,
     /** Command APDU shall be encrypted and MAC protected. */
    TEE_SC_C_ENC_MAC           = 0x03,
    /** Response APDU shall be encrypted and MAC protected. */
    TEE_SC_R_ENC_MAC           = 0x30,
    /** Command and response APDU shall be encrypted and MAC protected. */
    TEE_SC_CR_ENC_MAC          = 0x33,
    /** Command APDU shall be encrypted, and the command and response APDU shall be MAC protected.*/
    TEE_SC_C_ENC_CR_MAC        = 0x13
} TEE_SC_SecurityLevel;

#define TEE_AUTHENTICATE TEE_SC_AUTHENTICATE

/**
 * @brief Represents the reference about SC card key.
 *
 * @since 12
 */
typedef struct __TEE_SC_CardKeyRef {
    /** The key identifier of the SC card key. */
    uint8_t scKeyID;
    /** The key version if the SC card key. */
    uint8_t scKeyVersion;
} TEE_SC_CardKeyRef;

/**
 * @brief Represents the reference about the SC device key.
 *
 * @since 12
 */
typedef struct __TEE_SC_DeviceKeyRef {
    TEE_SC_KeyType scKeyType;
    union {
        TEE_ObjectHandle scBaseKeyHandle;
        TEE_SC_KeySetRef scKeySetRef;
    } __TEE_key;
} TEE_SC_DeviceKeyRef;

/**
 * @brief Defines the OID of the SC.
 *
 * @since 12
 */
typedef struct __TEE_SC_OID {
    /** The value of the OID. */
    uint8_t *buffer;
    /** The length of the OID. */
    uint32_t bufferLen;
} TEE_SC_OID;

/**
 * @brief Represents the paramaters about the SC.
 *
 * @since 12
 */
typedef struct __TEE_SC_Params {
    /** The SC type. */
    uint8_t scType;
    /** The SC type defined by OID. */
    TEE_SC_OID scOID;
    /** The SC security level. */
    TEE_SC_SecurityLevel scSecurityLevel;
    /** Reference to SC card keys. */
    TEE_SC_CardKeyRef scCardKeyRef;
    /** Reference to SC device keys. */
    TEE_SC_DeviceKeyRef scDeviceKeyRef;
} TEE_SC_Params;

/**
 * @brief Open the SE service.
 *
 * @param se_service_handle [IN] Indicates the handle of SE service.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ERROR_ACCESS_CONFLICT} if failed to access the SE service due to conflict.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SEServiceOpen(TEE_SEServiceHandle *se_service_handle);

/**
 * @brief Close the SE service.
 *
 * @param se_service_handle [IN] Indicates the handle of SE service.
 *
 * @since 12
 * @version 1.0
 */
void TEE_SEServiceClose(TEE_SEServiceHandle se_service_handle);

/**
 * @brief Get the available readers handle of the SE service.
 *
 * @param se_service_handle [IN] Indicates the handle of SE service.
 * @param se_reader_handle_list [OUT] Indicates the available readers handle list.
 * @param se_reader_handle_list_len [OUT] Indicates the length of the handle list.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ITEM_NOT_FOUND} if cannot find the input SE service handle.
 *         Returns {@code TEE_ERROR_SHORT_BUFFER} if the provided buffer is too small to store the readers handle.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SEServiceGetReaders(TEE_SEServiceHandle se_service_handle, TEE_SEReaderHandle *se_reader_handle_list,
                                   uint32_t *se_reader_handle_list_len);

/**
 * @brief Get the available readers handle of the SE service.
 *
 * @param se_reader_handle [IN] Indicates the SE readers handle.
 * @param reader_properties [OUT] Indicates the reader's properties.
 *
 * @since 12
 * @version 1.0
 */
void TEE_SEReaderGetProperties(TEE_SEReaderHandle se_reader_handle, TEE_SEReaderProperties *reader_properties);

/**
 * @brief Get the SE reader's name.
 *
 * @param se_reader_handle [IN] Indicates the SE readers handle.
 * @param reader_name [OUT] Indicates the SE reader's name.
 * @param reader_name_len [OUT] Indicates the length of the reader's name.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ITEM_NOT_FOUND} if cannot find the input SE reader handle.
 *         Returns {@code TEE_ERROR_BAD_FORMAT} if the input se_reader_handle points to the reader illegally.
 *         Returns {@code TEE_ERROR_SHORT_BUFFER} if the reader_name_len is too small to store the readers name.
 *         Returns {@code TEE_ERROR_SECURITY} if the security error is detected.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SEReaderGetName(TEE_SEReaderHandle se_reader_handle, char *reader_name, uint32_t *reader_name_len);

/**
 * @brief Open a session between the SE reader to the SE.
 *
 * @param se_reader_handle  Indicates the SE readers handle.
 * @param se_session_handle Indicates the session handle.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ITEM_NOT_FOUND} if cannot find the input SE reader handle.
 *         Returns {@code TEE_ERROR_COMMUNICATION} if communicte failed with the SE.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SEReaderOpenSession(TEE_SEReaderHandle se_reader_handle, TEE_SESessionHandle *se_session_handle);

/**
 * @brief Close sessions between the SE reader to the SE.
 *
 * @param se_reader_handle  Indicates the SE readers handle.
 *
 * @since 12
 * @version 1.0
 */
void TEE_SEReaderCloseSessions(TEE_SEReaderHandle se_reader_handle);

/**
 * @brief Get the SE ATR.
 *
 * @param se_session_handle  Indicates the session handle.
 * @param atr  Indicates the SE ATR.
 * @param atrLen  Indicates the length of ATR.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ERROR_SHORT_BUFFER} if the provided buffer is too small to store the ATR.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SESessionGetATR(TEE_SESessionHandle se_session_handle, void *atr, uint32_t *atrLen);

/**
 * @brief Check whether the session is closed.
 *
 * @param se_session_handle  Indicates the session handle.
 *
 * @return Returns {@code TEE_SUCCESS} if the session is closed or the input handle is invalid.
 *         Returns {@code TEE_ERROR_COMMUNICATION} if session state is invalid.
 *         Returns {@code TEE_ERROR_BAD_STATE} if the session is opened.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SESessionIsClosed(TEE_SESessionHandle se_session_handle);

/**
 * @brief Close the SE session.
 *
 * @param se_session_handle  Indicates the session handle.
 *
 * @since 12
 * @version 1.0
 */
void TEE_SESessionClose(TEE_SESessionHandle se_session_handle);

/**
 * @brief Close all channels which pointed to by the SE session.
 *
 * @param se_session_handle  Indicates the session handle.
 *
 * @since 12
 * @version 1.0
 */
void TEE_SESessionCloseChannels(TEE_SESessionHandle se_session_handle);

/**
 * @brief Open a basic channel which pointed to by the SE session.
 *
 * @param se_session_handle  Indicates the session handle.
 * @param se_aid  Indicates the SE AID.
 * @param se_channel_handle  Indicates the SE channel handle.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_STATE} if the session is closed.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ITEM_NOT_FOUND} if cannot find the input SE reader handle.
 *         Returns other when SE responding to the abnormal status word.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SESessionOpenBasicChannel(TEE_SESessionHandle se_session_handle, TEE_SEAID *se_aid,
                                         TEE_SEChannelHandle *se_channel_handle);

/**
 * @brief Open a logical channel which pointed to by the SE session.
 *
 * @param se_session_handle  Indicates the session handle.
 * @param se_aid  Indicates the SE AID.
 * @param se_channel_handle  Indicates the SE channel handle.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_STATE} if the session is closed.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is incorrect.
 *         Returns {@code TEE_ITEM_NOT_FOUND} if cannot find the input SE reader handle.
 *         Returns other when SE responding to the abnormal status word.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SESessionOpenLogicalChannel(TEE_SESessionHandle se_session_handle, TEE_SEAID *se_aid,
                                           TEE_SEChannelHandle *se_channel_handle);

/**
 * @brief Close the channel which pointed to by the channel handle.
 *
 * @param se_channel_handle  Indicates the SE channel handle.
 *
 * @since 12
 * @version 1.0
 */
void TEE_SEChannelClose(TEE_SEChannelHandle se_channel_handle);

/**
 * @brief Select the next SE service which pointed to by the channel handle.
 *
 * @param se_channel_handle  Indicates the SE channel handle.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is invalid or the mode of SE is wrong.
 *         Returns other when SE responding to the abnormal status word.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SEChannelSelectNext(TEE_SEChannelHandle se_channel_handle);

/**
 * @brief Get the SELECT command response of SE when open the channel handle.
 *
 * @param se_channel_handle  Indicates the SE channel handle.
 * @param response  Indicates the response of SE.
 * @param response_len  Indicates the length of the response.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is invalid.
 *         Returns {@code TEE_ERROR_SHORT_BUFFER} if the provided buffer is too small to store the response.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SEChannelGetSelectResponse(TEE_SEChannelHandle se_channel_handle, void *response,
                                          uint32_t *response_len);

/**
 * @brief Transmit the command through the channle.
 *
 * @param se_channel_handle  Indicates the SE channel handle.
 * @param command  Indicates the transmitted command.
 * @param command_len  Indicates the length of the command.
 * @param response  Indicates the response of SE.
 * @param response_len  Indicates the length of the response.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_COMMUNICATION} if length of command is less than 4.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is invalid.
 *         Returns {@code TEE_ERROR_BAD_STATE} if the channel is closed.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SEChannelTransmit(TEE_SEChannelHandle se_channel_handle, void *command, uint32_t command_len,
                                 void *response, uint32_t *response_len);

/**
 * @brief Open a SE secure channel based on the input channel handle.
 * Thereafter, when the {@code TEE_SEChannelTransmit} is called, all APDUs(ENC/MAC protected) transmitted based on
 * the handle are automatically protected based on the defined secure channel parameter options.
 * Currently, only SCP03 is supported.
 *
 * @param se_channel_handle  Indicates the SE channel handle.
 * @param sc_params  Indicates the parameter reference for the secure channel protocol.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_COMMUNICATION} if communicate failed with the SE.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is invalid or the mode of SE is wrong.
 *         Returns {@code TEE_ERROR_NOT_SUPPORTED} if the parameter of the sc_params is not supported
 *         Returns {@code TEE_ERROR_MAC_INVALID} if the verification failed.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SESecureChannelOpen(TEE_SEChannelHandle se_channel_handle, TEE_SC_Params *sc_params);

/**
 * @brief Close the SE secure channel based on the input channel handle.
 * The channel, which pointed to by the input channel handle, is not closed.
 * It can be used for insecure communication, but the APDU that calls {@code TEE_SEChannelTransmit}
 * transmission is not secure.
 *
 * @param se_channel_handle  Indicates the SE channel handle.
 *
 * @since 12
 * @version 1.0
 */
void TEE_SESecureChannelClose(TEE_SEChannelHandle se_channel_handle);

/**
 * @brief Get the channel Id which pointed to by the input channel handle.
 *
 * @param se_channel_handle  Indicates the SE channel handle.
 * @param channel_id  Indicates the SE channel Id.
 *
 * @return Returns {@code TEE_SUCCESS} if the operation is successful.
 *         Returns {@code TEE_ERROR_BAD_PARAMETERS} if input parameter is invalid.
 *
 * @since 12
 * @version 1.0
 */
TEE_Result TEE_SEChannelGetID(TEE_SEChannelHandle se_channel_handle, uint8_t *channel_id);
#ifdef __cplusplus
}
#endif
/** @} */
#endif