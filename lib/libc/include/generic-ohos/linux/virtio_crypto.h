/****************************************************************************
 ****************************************************************************
 ***
 ***   This header was automatically generated from a Linux kernel header
 ***   of the same name, to make information necessary for userspace to
 ***   call into the kernel available to libc.  It contains only constants,
 ***   structures, and macros generated from the original header, and thus,
 ***   contains no copyrightable information.
 ***
 ***   To edit the content of this header, modify the corresponding
 ***   source file (e.g. under external/kernel-headers/original/) then
 ***   run bionic/libc/kernel/tools/update_all.py
 ***
 ***   Any manual change here will be lost the next time this script will
 ***   be run. You've been warned!
 ***
 ****************************************************************************
 ****************************************************************************/
#ifndef _VIRTIO_CRYPTO_H
#define _VIRTIO_CRYPTO_H
#include <linux/types.h>
#include <linux/virtio_types.h>
#include <linux/virtio_ids.h>
#include <linux/virtio_config.h>
#define VIRTIO_CRYPTO_SERVICE_CIPHER 0
#define VIRTIO_CRYPTO_SERVICE_HASH 1
#define VIRTIO_CRYPTO_SERVICE_MAC 2
#define VIRTIO_CRYPTO_SERVICE_AEAD 3
#define VIRTIO_CRYPTO_OPCODE(service,op) (((service) << 8) | (op))
struct virtio_crypto_ctrl_header {
#define VIRTIO_CRYPTO_CIPHER_CREATE_SESSION VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_CIPHER, 0x02)
#define VIRTIO_CRYPTO_CIPHER_DESTROY_SESSION VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_CIPHER, 0x03)
#define VIRTIO_CRYPTO_HASH_CREATE_SESSION VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_HASH, 0x02)
#define VIRTIO_CRYPTO_HASH_DESTROY_SESSION VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_HASH, 0x03)
#define VIRTIO_CRYPTO_MAC_CREATE_SESSION VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_MAC, 0x02)
#define VIRTIO_CRYPTO_MAC_DESTROY_SESSION VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_MAC, 0x03)
#define VIRTIO_CRYPTO_AEAD_CREATE_SESSION VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_AEAD, 0x02)
#define VIRTIO_CRYPTO_AEAD_DESTROY_SESSION VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_AEAD, 0x03)
  __le32 opcode;
  __le32 algo;
  __le32 flag;
  __le32 queue_id;
};
struct virtio_crypto_cipher_session_para {
#define VIRTIO_CRYPTO_NO_CIPHER 0
#define VIRTIO_CRYPTO_CIPHER_ARC4 1
#define VIRTIO_CRYPTO_CIPHER_AES_ECB 2
#define VIRTIO_CRYPTO_CIPHER_AES_CBC 3
#define VIRTIO_CRYPTO_CIPHER_AES_CTR 4
#define VIRTIO_CRYPTO_CIPHER_DES_ECB 5
#define VIRTIO_CRYPTO_CIPHER_DES_CBC 6
#define VIRTIO_CRYPTO_CIPHER_3DES_ECB 7
#define VIRTIO_CRYPTO_CIPHER_3DES_CBC 8
#define VIRTIO_CRYPTO_CIPHER_3DES_CTR 9
#define VIRTIO_CRYPTO_CIPHER_KASUMI_F8 10
#define VIRTIO_CRYPTO_CIPHER_SNOW3G_UEA2 11
#define VIRTIO_CRYPTO_CIPHER_AES_F8 12
#define VIRTIO_CRYPTO_CIPHER_AES_XTS 13
#define VIRTIO_CRYPTO_CIPHER_ZUC_EEA3 14
  __le32 algo;
  __le32 keylen;
#define VIRTIO_CRYPTO_OP_ENCRYPT 1
#define VIRTIO_CRYPTO_OP_DECRYPT 2
  __le32 op;
  __le32 padding;
};
struct virtio_crypto_session_input {
  __le64 session_id;
  __le32 status;
  __le32 padding;
};
struct virtio_crypto_cipher_session_req {
  struct virtio_crypto_cipher_session_para para;
  __u8 padding[32];
};
struct virtio_crypto_hash_session_para {
#define VIRTIO_CRYPTO_NO_HASH 0
#define VIRTIO_CRYPTO_HASH_MD5 1
#define VIRTIO_CRYPTO_HASH_SHA1 2
#define VIRTIO_CRYPTO_HASH_SHA_224 3
#define VIRTIO_CRYPTO_HASH_SHA_256 4
#define VIRTIO_CRYPTO_HASH_SHA_384 5
#define VIRTIO_CRYPTO_HASH_SHA_512 6
#define VIRTIO_CRYPTO_HASH_SHA3_224 7
#define VIRTIO_CRYPTO_HASH_SHA3_256 8
#define VIRTIO_CRYPTO_HASH_SHA3_384 9
#define VIRTIO_CRYPTO_HASH_SHA3_512 10
#define VIRTIO_CRYPTO_HASH_SHA3_SHAKE128 11
#define VIRTIO_CRYPTO_HASH_SHA3_SHAKE256 12
  __le32 algo;
  __le32 hash_result_len;
  __u8 padding[8];
};
struct virtio_crypto_hash_create_session_req {
  struct virtio_crypto_hash_session_para para;
  __u8 padding[40];
};
struct virtio_crypto_mac_session_para {
#define VIRTIO_CRYPTO_NO_MAC 0
#define VIRTIO_CRYPTO_MAC_HMAC_MD5 1
#define VIRTIO_CRYPTO_MAC_HMAC_SHA1 2
#define VIRTIO_CRYPTO_MAC_HMAC_SHA_224 3
#define VIRTIO_CRYPTO_MAC_HMAC_SHA_256 4
#define VIRTIO_CRYPTO_MAC_HMAC_SHA_384 5
#define VIRTIO_CRYPTO_MAC_HMAC_SHA_512 6
#define VIRTIO_CRYPTO_MAC_CMAC_3DES 25
#define VIRTIO_CRYPTO_MAC_CMAC_AES 26
#define VIRTIO_CRYPTO_MAC_KASUMI_F9 27
#define VIRTIO_CRYPTO_MAC_SNOW3G_UIA2 28
#define VIRTIO_CRYPTO_MAC_GMAC_AES 41
#define VIRTIO_CRYPTO_MAC_GMAC_TWOFISH 42
#define VIRTIO_CRYPTO_MAC_CBCMAC_AES 49
#define VIRTIO_CRYPTO_MAC_CBCMAC_KASUMI_F9 50
#define VIRTIO_CRYPTO_MAC_XCBC_AES 53
  __le32 algo;
  __le32 hash_result_len;
  __le32 auth_key_len;
  __le32 padding;
};
struct virtio_crypto_mac_create_session_req {
  struct virtio_crypto_mac_session_para para;
  __u8 padding[40];
};
struct virtio_crypto_aead_session_para {
#define VIRTIO_CRYPTO_NO_AEAD 0
#define VIRTIO_CRYPTO_AEAD_GCM 1
#define VIRTIO_CRYPTO_AEAD_CCM 2
#define VIRTIO_CRYPTO_AEAD_CHACHA20_POLY1305 3
  __le32 algo;
  __le32 key_len;
  __le32 hash_result_len;
  __le32 aad_len;
  __le32 op;
  __le32 padding;
};
struct virtio_crypto_aead_create_session_req {
  struct virtio_crypto_aead_session_para para;
  __u8 padding[32];
};
struct virtio_crypto_alg_chain_session_para {
#define VIRTIO_CRYPTO_SYM_ALG_CHAIN_ORDER_HASH_THEN_CIPHER 1
#define VIRTIO_CRYPTO_SYM_ALG_CHAIN_ORDER_CIPHER_THEN_HASH 2
  __le32 alg_chain_order;
#define VIRTIO_CRYPTO_SYM_HASH_MODE_PLAIN 1
#define VIRTIO_CRYPTO_SYM_HASH_MODE_AUTH 2
#define VIRTIO_CRYPTO_SYM_HASH_MODE_NESTED 3
  __le32 hash_mode;
  struct virtio_crypto_cipher_session_para cipher_param;
  union {
    struct virtio_crypto_hash_session_para hash_param;
    struct virtio_crypto_mac_session_para mac_param;
    __u8 padding[16];
  } u;
  __le32 aad_len;
  __le32 padding;
};
struct virtio_crypto_alg_chain_session_req {
  struct virtio_crypto_alg_chain_session_para para;
};
struct virtio_crypto_sym_create_session_req {
  union {
    struct virtio_crypto_cipher_session_req cipher;
    struct virtio_crypto_alg_chain_session_req chain;
    __u8 padding[48];
  } u;
#define VIRTIO_CRYPTO_SYM_OP_NONE 0
#define VIRTIO_CRYPTO_SYM_OP_CIPHER 1
#define VIRTIO_CRYPTO_SYM_OP_ALGORITHM_CHAINING 2
  __le32 op_type;
  __le32 padding;
};
struct virtio_crypto_destroy_session_req {
  __le64 session_id;
  __u8 padding[48];
};
struct virtio_crypto_op_ctrl_req {
  struct virtio_crypto_ctrl_header header;
  union {
    struct virtio_crypto_sym_create_session_req sym_create_session;
    struct virtio_crypto_hash_create_session_req hash_create_session;
    struct virtio_crypto_mac_create_session_req mac_create_session;
    struct virtio_crypto_aead_create_session_req aead_create_session;
    struct virtio_crypto_destroy_session_req destroy_session;
    __u8 padding[56];
  } u;
};
struct virtio_crypto_op_header {
#define VIRTIO_CRYPTO_CIPHER_ENCRYPT VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_CIPHER, 0x00)
#define VIRTIO_CRYPTO_CIPHER_DECRYPT VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_CIPHER, 0x01)
#define VIRTIO_CRYPTO_HASH VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_HASH, 0x00)
#define VIRTIO_CRYPTO_MAC VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_MAC, 0x00)
#define VIRTIO_CRYPTO_AEAD_ENCRYPT VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_AEAD, 0x00)
#define VIRTIO_CRYPTO_AEAD_DECRYPT VIRTIO_CRYPTO_OPCODE(VIRTIO_CRYPTO_SERVICE_AEAD, 0x01)
  __le32 opcode;
  __le32 algo;
  __le64 session_id;
  __le32 flag;
  __le32 padding;
};
struct virtio_crypto_cipher_para {
  __le32 iv_len;
  __le32 src_data_len;
  __le32 dst_data_len;
  __le32 padding;
};
struct virtio_crypto_hash_para {
  __le32 src_data_len;
  __le32 hash_result_len;
};
struct virtio_crypto_mac_para {
  struct virtio_crypto_hash_para hash;
};
struct virtio_crypto_aead_para {
  __le32 iv_len;
  __le32 aad_len;
  __le32 src_data_len;
  __le32 dst_data_len;
};
struct virtio_crypto_cipher_data_req {
  struct virtio_crypto_cipher_para para;
  __u8 padding[24];
};
struct virtio_crypto_hash_data_req {
  struct virtio_crypto_hash_para para;
  __u8 padding[40];
};
struct virtio_crypto_mac_data_req {
  struct virtio_crypto_mac_para para;
  __u8 padding[40];
};
struct virtio_crypto_alg_chain_data_para {
  __le32 iv_len;
  __le32 src_data_len;
  __le32 dst_data_len;
  __le32 cipher_start_src_offset;
  __le32 len_to_cipher;
  __le32 hash_start_src_offset;
  __le32 len_to_hash;
  __le32 aad_len;
  __le32 hash_result_len;
  __le32 reserved;
};
struct virtio_crypto_alg_chain_data_req {
  struct virtio_crypto_alg_chain_data_para para;
};
struct virtio_crypto_sym_data_req {
  union {
    struct virtio_crypto_cipher_data_req cipher;
    struct virtio_crypto_alg_chain_data_req chain;
    __u8 padding[40];
  } u;
  __le32 op_type;
  __le32 padding;
};
struct virtio_crypto_aead_data_req {
  struct virtio_crypto_aead_para para;
  __u8 padding[32];
};
struct virtio_crypto_op_data_req {
  struct virtio_crypto_op_header header;
  union {
    struct virtio_crypto_sym_data_req sym_req;
    struct virtio_crypto_hash_data_req hash_req;
    struct virtio_crypto_mac_data_req mac_req;
    struct virtio_crypto_aead_data_req aead_req;
    __u8 padding[48];
  } u;
};
#define VIRTIO_CRYPTO_OK 0
#define VIRTIO_CRYPTO_ERR 1
#define VIRTIO_CRYPTO_BADMSG 2
#define VIRTIO_CRYPTO_NOTSUPP 3
#define VIRTIO_CRYPTO_INVSESS 4
#define VIRTIO_CRYPTO_S_HW_READY (1 << 0)
struct virtio_crypto_config {
  __le32 status;
  __le32 max_dataqueues;
  __le32 crypto_services;
  __le32 cipher_algo_l;
  __le32 cipher_algo_h;
  __le32 hash_algo;
  __le32 mac_algo_l;
  __le32 mac_algo_h;
  __le32 aead_algo;
  __le32 max_cipher_key_len;
  __le32 max_auth_key_len;
  __le32 reserve;
  __le64 max_size;
};
struct virtio_crypto_inhdr {
  __u8 status;
};
#endif