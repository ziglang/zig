/*	$NetBSD: iscsi.h,v 1.4.50.1 2023/12/18 14:15:58 martin Exp $	*/

/*-
 * Copyright (c) 2004,2006,2011 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Wasabi Systems, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */
#ifndef _ISCSI_H
#define _ISCSI_H

#define ISCSI_DEV_MAJOR    203

#define ISCSI_STRING_LENGTH   (223+1)
#define ISCSI_ADDRESS_LENGTH  (255+1)
#define ISCSI_AUTH_OPTIONS    4

typedef enum {
	ISCSI_AUTH_None		= 0,
	ISCSI_AUTH_CHAP		= 1,
	ISCSI_AUTH_KRB5		= 2,
	ISCSI_AUTH_SRP		= 3
} iscsi_auth_types_t;
/*
   ISCSI_AUTH_None
      Indicates that no authentication is necessary.
   ISCSI_AUTH_CHAP
      Indicates CHAP authentication should be used.
   ISCSI_AUTH_KRB5
      Indicates Kerberos 5 authentication (fur future use).
   ISCSI_AUTH_SRP
      Indicates SRP authentication (for future use).
*/

typedef enum {
	ISCSI_CHAP_MD5		= 5,
	ISCSI_CHAP_SHA1		= 6,
	ISCSI_CHAP_SHA256	= 7,
	ISCSI_CHAP_SHA3_256	= 8
} iscsi_chap_types_t;

typedef struct {
	unsigned int		mutual_auth:1;
	unsigned int		is_secure:1;
	unsigned int		auth_number:4;
	iscsi_auth_types_t	auth_type[ISCSI_AUTH_OPTIONS];
} iscsi_auth_info_t;

/*
   mutual_auth
      Indicates that authentication should be mutual, i.e.
      the initiator should authenticate the target, and the target
      should authenticate the initiator. If not specified, the target
      will authenticate the initiator only.
   is_secure
      Indicates that the connection is secure.
   auth_number
      Indicates the number of elements in auth_type.
      When 0, no authentication will be used.
   auth_type
      Contains up to ISCSI_AUTH_OPTIONS enumerator values of type
      ISCSI_AUTH_TYPES that indicates the authentication method that
      should be used to establish a login connection (none, CHAP, KRB5,
      etc.), in order of priority. The first element is the most
      preferred method, the last element the least preferred.

*/

typedef enum {
	ISCSI_DIGEST_None	= 0,
	ISCSI_DIGEST_CRC32C	= 1
} iscsi_digest_t;

/*
   ISCSI_DIGEST_None
      Indicates that no CRC is to be generated.
   ISCSI_DIGEST_CRC32C
      Indicates the CRC32C digest should be used.
*/

typedef enum {
	ISCSI_LOGINTYPE_DISCOVERY	= 0,
	ISCSI_LOGINTYPE_NOMAP		= 1,
	ISCSI_LOGINTYPE_MAP		= 2
} iscsi_login_session_type_t;

/*
   ISCSI_LOGINTYPE_DISCOVERY
      Indicates that the login session is for discovery only.
      Initiators use this type of session to send a SCSI SendTargets
      command to an iSCSI target to request assistance in
      discovering other targets accessible to the target that
      receives the SendTargets command.
   ISCSI_LOGINTYPE_NOMAP
      This establishes a normal (full featured) session, but does
      not report the target LUNs to the operating system as
      available drives. Communication with the target is limited
      to io-controls through the driver.
   ISCSI_LOGINTYPE_MAP
      Indicates that the login session is full featured, and reports
      all target LUNs to the operating system to map as logical drives.
*/

typedef struct {
	uint8_t		address[ISCSI_ADDRESS_LENGTH];
	uint16_t	port;
	uint16_t	group_tag;
} iscsi_portal_address_t;

/*
   address
      IP address of the target (V4 dotted quad or V6 hex).
   port
      IP port number.
   group_tag
      Target portal group tag (0 if unknown).
*/


/* -------------------------  Status Values -------------------------- */

#define ISCSI_STATUS_SUCCESS                 0	/* Indicates success. */
#define ISCSI_STATUS_LIST_EMPTY              1	/* The requested list is empty. */
#define ISCSI_STATUS_DUPLICATE_NAME          2	/* The specified symbolic identifier is not unique. */
#define ISCSI_STATUS_GENERAL_ERROR           3	/* A non-specific error occurred. */
#define ISCSI_STATUS_LOGIN_FAILED            4	/* The login failed. */
#define ISCSI_STATUS_CONNECTION_FAILED       5	/* The attempt to establish a connection failed. */
#define ISCSI_STATUS_AUTHENTICATION_FAILED   6	/* Authentication negotiation failed. */
#define ISCSI_STATUS_NO_RESOURCES            7	/* Could not allocate resources (e.g. memory). */
#define ISCSI_STATUS_MAXED_CONNECTIONS       8	/* Maximum number of connections exceeded. */
#define ISCSI_STATUS_INVALID_SESSION_ID      9	/* Session ID not found */
#define ISCSI_STATUS_INVALID_CONNECTION_ID   10	/* Connection ID not found */
#define ISCSI_STATUS_INVALID_SOCKET          11	/* Specified socket is invalid */
#define ISCSI_STATUS_NOTIMPL                 12	/* Feature not implemented */
#define ISCSI_STATUS_CHECK_CONDITION         13	/* Target reported CHECK CONDITION */
#define ISCSI_STATUS_TARGET_BUSY             14	/* Target reported BUSY */
#define ISCSI_STATUS_TARGET_ERROR            15	/* Target reported other error */
#define ISCSI_STATUS_TARGET_FAILURE          16	/* Command Response was Target Failure */
#define ISCSI_STATUS_TARGET_DROP             17	/* Target dropped connection */
#define ISCSI_STATUS_SOCKET_ERROR            18	/* Communication failure */
#define ISCSI_STATUS_PARAMETER_MISSING       19	/* A required ioctl parameter is missing */
#define ISCSI_STATUS_PARAMETER_INVALID       20	/* A parameter is malformed (string too long etc.) */
#define ISCSI_STATUS_MAP_FAILED              21	/* Mapping the LUNs failed */
#define ISCSI_STATUS_NO_INITIATOR_NAME       22	/* Initiator name was not set */
#define ISCSI_STATUS_NEGOTIATION_ERROR       23	/* Negotiation failure (invalid key or value) */
#define ISCSI_STATUS_TIMEOUT                 24	/* Command timed out (at iSCSI level) */
#define ISCSI_STATUS_PROTOCOL_ERROR          25	/* Internal Error (Protocol error reject) */
#define ISCSI_STATUS_PDU_ERROR               26	/* Internal Error (Invalid PDU field reject) */
#define ISCSI_STATUS_CMD_NOT_SUPPORTED       27	/* Target does not support iSCSI command */
#define ISCSI_STATUS_DRIVER_UNLOAD           28	/* Driver is unloading */
#define ISCSI_STATUS_LOGOUT                  29	/* Session was logged out */
#define ISCSI_STATUS_PDUS_LOST               30	/* Excessive PDU loss */
#define ISCSI_STATUS_INVALID_EVENT_ID        31	/* Invalid Event ID */
#define ISCSI_STATUS_EVENT_DEREGISTERED      32	/* Wait for event cancelled by deregistration */
#define ISCSI_STATUS_EVENT_WAITING           33	/* Someone is already waiting for this event */
#define ISCSI_STATUS_TASK_NOT_FOUND          34	/* Task Management: task not found */
#define ISCSI_STATUS_LUN_NOT_FOUND           35	/* Task Management: LUN not found */
#define ISCSI_STATUS_TASK_ALLEGIANT          36	/* Task Management: Task still allegiant */
#define ISCSI_STATUS_CANT_REASSIGN           37	/* Task Management: Task reassignment not supported */
#define ISCSI_STATUS_FUNCTION_UNSUPPORTED    38	/* Task Management: Function unsupported */
#define ISCSI_STATUS_FUNCTION_NOT_AUTHORIZED 39	/* Task Management: Function not authorized */
#define ISCSI_STATUS_FUNCTION_REJECTED       40	/* Task Management: Function rejected */
#define ISCSI_STATUS_UNKNOWN_REASON          41	/* Task Management: Unknown reason code */
#define ISCSI_STATUS_DUPLICATE_ID            42	/* Given ID is a duplicate */
#define ISCSI_STATUS_INVALID_ID              43	/* Given ID was not found */
#define ISCSI_STATUS_TARGET_LOGOUT           44	/* Target requested logout */
#define ISCSI_STATUS_LOGOUT_CID_NOT_FOUND    45	/* Logout error: CID not found */
#define ISCSI_STATUS_LOGOUT_RECOVERY_NS	     46	/* Logout error: Recovery not supported */
#define ISCSI_STATUS_LOGOUT_ERROR	     47	/* Logout error: Unknown reason */
#define ISCSI_STATUS_QUEUE_FULL              48 /* iSCSI send window exhausted */

#define ISCSID_STATUS_SUCCESS                0		/* Indicates success. */
#define ISCSID_STATUS_LIST_EMPTY             1001	/* The requested list is empty. */
#define ISCSID_STATUS_DUPLICATE_NAME         1002	/* The specified name is not unique. */
#define ISCSID_STATUS_GENERAL_ERROR          1003	/* A non-specific error occurred. */
#define ISCSID_STATUS_CONNECT_ERROR          1005	/* Failed to connect to target */
#define ISCSID_STATUS_NO_RESOURCES           1007	/* Could not allocate resources (e.g. memory). */
#define ISCSID_STATUS_INVALID_SESSION_ID     1009	/* Session ID not found */
#define ISCSID_STATUS_INVALID_CONNECTION_ID  1010	/* Connection ID not found */
#define ISCSID_STATUS_NOTIMPL                1012	/* Feature not implemented */
#define ISCSID_STATUS_SOCKET_ERROR           1018	/* Failed to create socket */
#define ISCSID_STATUS_PARAMETER_MISSING      1019	/* A required parameter is missing */
#define ISCSID_STATUS_PARAMETER_INVALID      1020	/* A parameter is malformed (string too long etc.) */
#define ISCSID_STATUS_INVALID_PARAMETER      1020	/* Alternate spelling of above */
#define ISCSID_STATUS_NO_INITIATOR_NAME      1022	/* Initiator name was not set */
#define ISCSID_STATUS_TIMEOUT                1024	/* Request timed out */
#define ISCSID_STATUS_DRIVER_NOT_LOADED      1028	/* Driver not loaded */
#define ISCSID_STATUS_INVALID_REQUEST        1101	/* Unknown request code */
#define ISCSID_STATUS_INVALID_PORTAL_ID      1102	/* Portal ID not found */
#define ISCSID_STATUS_INVALID_TARGET_ID      1103	/* Target ID not found */
#define ISCSID_STATUS_NOT_FOUND              1104	/* Search failed */
#define ISCSID_STATUS_HOST_NOT_FOUND         1105	/* Target address not found */
#define ISCSID_STATUS_HOST_TRY_AGAIN         1106	/* Target address retreival failed, try again later */
#define ISCSID_STATUS_HOST_ERROR             1107	/* Target address invalid */
#define ISCSID_STATUS_NO_TARGETS_FOUND	     1108	/* No targets found during refresh */
#define ISCSID_STATUS_INVALID_ISNS_ID        1111	/* iSNS ID not found */
#define ISCSID_STATUS_ISNS_ERROR             1112	/* Problem connecting to iSNS */
#define ISCSID_STATUS_ISNS_SERVER_ERROR      1113	/* iSNS server returned garbage */
#define ISCSID_STATUS_DUPLICATE_ENTRY        1114	/* The specified entry already exists */
#define ISCSID_STATUS_INVALID_INITIATOR_ID   1115	/* Initiator ID not found */
#define ISCSID_STATUS_INITIATOR_BIND_ERROR   1116	/* Bind to initiator portal failed */

#endif /* !_ISCSI_H */