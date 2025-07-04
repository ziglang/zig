/*	$NetBSD: iscsi_ioctl.h,v 1.3 2013/04/04 22:17:13 dsl Exp $	*/

/*-
 * Copyright (c) 2004,2005,2006,2011 The NetBSD Foundation, Inc.
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
#ifndef _ISCSI_IOCTL_H
#define _ISCSI_IOCTL_H

#include <dev/iscsi/iscsi.h>
#include <sys/scsiio.h>

/* ==================  Interface Structures ======================== */

/* ===== Login, add_connection, and restore_connection ===== */

typedef struct {
	uint32_t status;
	int socket;
	struct {
		unsigned int HeaderDigest:1;
		unsigned int DataDigest:1;
		unsigned int MaxConnections:1;
		unsigned int DefaultTime2Wait:1;
		unsigned int DefaultTime2Retain:1;
		unsigned int MaxRecvDataSegmentLength:1;
		unsigned int auth_info:1;
		unsigned int user_name:1;
		unsigned int password:1;
		unsigned int target_password:1;
		unsigned int TargetName:1;
		unsigned int TargetAlias:1;
		unsigned int ErrorRecoveryLevel:1;
	} is_present;
	iscsi_auth_info_t auth_info;
	iscsi_login_session_type_t login_type;
	iscsi_digest_t HeaderDigest;
	iscsi_digest_t DataDigest;
	uint32_t session_id;
	uint32_t connection_id;
	uint32_t MaxRecvDataSegmentLength;
	uint16_t MaxConnections;
	uint16_t DefaultTime2Wait;
	uint16_t DefaultTime2Retain;
	uint16_t ErrorRecoveryLevel;
	void *user_name;
	void *password;
	void *target_password;
	void *TargetName;
	void *TargetAlias;
} iscsi_login_parameters_t;

/*
   status
      Contains, on return, the result of the command.
   socket
      A handle to the open TCP connection to the target portal.
   is_present
      Contains a bitfield that indicates which members of the
      iscsi_login_parameters structure contain valid data.
   auth_info
      Is a bitfield of parameters for authorization.
      The members are
         mutual_auth Indicates that authentication should be mutual, i.e.
            the initiator should authenticate the target, and the target
            should authenticate the initiator. If not specified, the target
            will authenticate the initiator only.
         is_secure   Indicates that the connection is secure.
         auth_number Indicates the number of elements in auth_type.
            When 0, no authentication will be used.
   auth_type
      Contains up to ISCSI_AUTH_OPTIONS enumerator values of type
      iscsi_auth_types that indicates the authentication method that should
      be used to establish a login connection (none, CHAP, KRB5, etc.), in
      order of priority.  The first element is the most preferred method, the
      last element the least preferred.
   login_type
      Contains an enumerator value of type login_session_type that indicates
      the type of logon session (discovery, informational, or full featured).
   HeaderDigest
      Indicates which digest (if any) to use for the PDU header.
   DataDigest
      Indicates which digest (if any) to use for the PDU data.
   session_id
      Login: OUT: Receives an integer that identifies the session.
      Add_connection, Restore_connection: IN: Session ID.
   connection_id
      Login, Add_connection: OUT: Receives an integer that identifies the
      connection.
      Restore_connection: IN: Connection ID.
   MaxRecvDataSegmentLength
      Allows limiting or extending the maximum receive data segment length.
      Must contain a value between 512 and 2**24-1 if specified.
   MaxConnections
      Contains a value between 1 and 65535 that specifies the maximum number
      of connections to target devices that can be associated with a single
      logon session. A value of 0 indicates that there no limit to the
      number of connections.
   DefaultTime2Wait
      Specifies the minimum time to wait, in seconds, before attempting to
      reconnect or reassign a connection that has been dropped.
	  The default is 2.
   DefaultTime2Retain
      Specifies the maximum time, in seconds, allowed to reassign a
      connection after the initial wait indicated in DefaultTime2Retain has
      elapsed. The default is 20.
   ErrorRecoveryLevel
      Specifies the desired error recovery level for the session.
	  The default and maximum is 2.
   user_name
      Sets the user (or CHAP) name to use during login authentication of the
      initiator (zero terminated UTF-8 string). Default is initiator name.
   password
      Contains the password to use during login authentication of the
      initiator (zero terminated UTF-8 string). Required if authentication
      is requested.
   target_password
      Contains the password to use during login authentication of the target
      (zero terminated UTF-8 string). Required if mutual authentication is
      requested.
   TargetName
      Indicates the name of the target with which to establish the logon
      session (zero terminated UTF-8 string).
   TargetAlias
      Receives the target alias as a zero terminated UTF-8 string. When
      present, the buffer must be of size ISCSI_STRING_LENGTH.
*/


/* ===== Logout ===== */

typedef struct {
	uint32_t status;
	uint32_t session_id;
} iscsi_logout_parameters_t;

/*
   status
      Contains, on return, the result of the command.
   session_id
      Contains an integer that identifies the session.
*/

/* ===== remove_connection ===== */

typedef struct {
	uint32_t status;
	uint32_t session_id;
	uint32_t connection_id;
} iscsi_remove_parameters_t;

/*
   status
      Contains, on return, the result of the command.
   session_id
      Contains an integer that identifies the session.
   connection_id
      Contains an integer that identifies the connection.
*/

/* ===== connection status ===== */

typedef struct {
	uint32_t status;
	uint32_t session_id;
	uint32_t connection_id;
} iscsi_conn_status_parameters_t;

/*
   status
      Contains, on return, the result of the command.
   session_id
      Contains an integer that identifies the session.
   connection_id
      Contains an integer that identifies the connection.
*/

/* ===== io_command ===== */

typedef struct {
	uint32_t status;
	uint32_t session_id;
	uint32_t connection_id;
	struct {
		unsigned int immediate:1;
	} options;
	uint64_t lun;
	scsireq_t req;
} iscsi_iocommand_parameters_t;

/*
   status
      Contains, on return, the result of the command (an ISCSI_STATUS code).
   lun
      Indicates which of the target's logical units should provide the data.
   session_id
      Contains an integer that identifies the session.
   connection_id
      Contains an integer that identifies the connection.
      This parameter is optional and should only be used for test purposes.
   options
      A bitfield indicating options for the command.
      The members are
         immediate   Indicates that the command should be sent
                     immediately, ahead of any queued requests.

   req
      Contains the parameters for the request as defined in sys/scsiio.h
      typedef struct scsireq {
         u_long   flags;
         u_long   timeout;
         uint8_t   cmd[16];
         uint8_t   cmdlen;
         void * databuf;
         u_long   datalen;
         u_long   datalen_used;
         uint8_t   sense[SENSEBUFLEN];
         uint8_t   senselen;
         uint8_t   senselen_used;
         uint8_t   status;
         uint8_t   retsts;
         int      error;
      } scsireq_t;

      flags
         Indicates request status and type.
      timeout
         Indicates a timeout value (reserved).
      cmd
         SCSI command buffer.
      cmdlen
         Length of SCSI command in cmd.
      databuf
         Pointer to user-space buffer that holds the data
         read or written by the SCSI command.
      datalen
         Indicates the size in bytes of the buffer at databuf.
      datalen_used
         Returns the number of bytes actually read or written.
      sense
         Sense data buffer.
      senselen
         Indicates the requested size of sense data. Must not exceed
         SENSEBUFLEN (48).
      senselen_used
         Contains, on return, the number of bytes written to sense.
      status
         Contains, on return, the original SCSI status (reserved).
      retsts
         Contains, on return, the status of the command as defined in scsiio.h.
      error
         Contains, on return, the original SCSI error bits (reserved).
*/


/* ===== send_targets ===== */

typedef struct {
	uint32_t status;
	uint32_t session_id;
	void *response_buffer;
	uint32_t response_size;
	uint32_t response_used;
	uint32_t response_total;
	uint8_t key[ISCSI_STRING_LENGTH];
} iscsi_send_targets_parameters_t;

/*
   status
      Contains, on return, the result of the command.
   session_id
      Contains an integer that identifies the session.
   response_buffer
      User mode address of buffer to hold the response data retrieved by
      the iSCSI send targets command.
   response_size
      Contains, on input, the size in bytes of the buffer at
      response_buffer. If this is 0, the command will execute the
      SendTargets request, and return (in response_total) the number of
      bytes required.
   response_used
      Contains, on return, the number of bytes actually retrieved to
      response_buffer.
   response_total
      Contains, on return, the total number of bytes required to hold the
      complete list of targets. This may be larger than response_size.
   key
      Specifies the SendTargets key value ("All", <target name>, or empty).
*/

/* ===== set_node_name ===== */

typedef struct {
	uint32_t status;
	uint8_t InitiatorName[ISCSI_STRING_LENGTH];
	uint8_t InitiatorAlias[ISCSI_STRING_LENGTH];
	uint8_t ISID[6];
} iscsi_set_node_name_parameters_t;

/*
   status
      Contains, on return, the result of the command.
   InitiatorName
      Specifies the InitiatorName used during login. Required.
   InitiatorAlias
      Specifies the InitiatorAlias for use during login. May be empty.
   ISID
      Specifies the ISID (a 6 byte binary value) for use during login.
      May be zero (all bytes) for the initiator to use a default value.
*/

/* ===== register_event and deregister_event ===== */

typedef struct {
	uint32_t status;
	uint32_t event_id;
} iscsi_register_event_parameters_t;

/*
   status
      Contains, on return, the result of the command.
   event_id
      Returns driver-assigned event ID to be used in
      subsequent calls to wait_event and deregister_event.
*/

/* ===== wait_event ===== */

typedef enum {
	ISCSI_SESSION_TERMINATED = 1,
	ISCSI_CONNECTION_TERMINATED,
	ISCSI_RECOVER_CONNECTION,
	ISCSI_DRIVER_TERMINATING
} iscsi_event_t;

/*
   Driver Events

   ISCSI_SESSION_TERMINATED
      The specified session (including all of its associated connections)
      has been terminated.
   ISCSI_CONNECTION_TERMINATED
      The specified connection has been terminated.
   ISCSI_RECOVER_CONNECTION
      The application should attempt to recover the given connection.
   ISCSI_DRIVER_TERMINATING
      The driver is unloading.
      The application MUST call ISCSI_DEREGISTER_EVENT as soon as possible
      after receiving this event. After performing the deregister IOCTL,
      the application must no longer attempt to access the driver.
*/


typedef struct {
	uint32_t status;
	uint32_t event_id;
	iscsi_event_t event_kind;
	uint32_t session_id;
	uint32_t connection_id;
	uint32_t reason;
} iscsi_wait_event_parameters_t;

/*
   status
      Contains, on return, the result of the command.
   event_id
      Driver assigned event ID.
   event_kind
      Identifies the event.
   session_id
      Identifies the affected session (0 for DRIVER_TERMINATING).
   connection_id
      Identifies the affected connection (0 for DRIVER_TERMINATING).
   reason
      Identifies the termination reason (ISCSI status code).
*/

typedef struct {
	uint32_t status;
	uint16_t interface_version;
	uint16_t major;
	uint16_t minor;
	uint8_t version_string[ISCSI_STRING_LENGTH];
} iscsi_get_version_parameters_t;

/*
   status
      Contains, on return, the result of the command.
   interface_version
      Updated when interface changes. Current Version is 2.
   major
      Major version number.
   minor
      Minor version number.
   version_string
      Displayable version string (zero terminated).
*/

/* =========================  IOCTL Codes =========================== */

#define ISCSI_GET_VERSION        _IOWR(0,  1, iscsi_get_version_parameters_t)
#define ISCSI_LOGIN              _IOWR(0,  2, iscsi_login_parameters_t)
#define ISCSI_LOGOUT             _IOWR(0,  3, iscsi_logout_parameters_t)
#define ISCSI_ADD_CONNECTION     _IOWR(0,  4, iscsi_login_parameters_t)
#define ISCSI_RESTORE_CONNECTION _IOWR(0,  5, iscsi_login_parameters_t)
#define ISCSI_REMOVE_CONNECTION  _IOWR(0,  6, iscsi_remove_parameters_t)
#define ISCSI_CONNECTION_STATUS  _IOWR(0,  7, iscsi_conn_status_parameters_t)
#define ISCSI_SEND_TARGETS       _IOWR(0,  8, iscsi_send_targets_parameters_t)
#define ISCSI_SET_NODE_NAME      _IOWR(0,  9, iscsi_set_node_name_parameters_t)
#define ISCSI_IO_COMMAND         _IOWR(0, 10, iscsi_iocommand_parameters_t)
#define ISCSI_REGISTER_EVENT     _IOWR(0, 11, iscsi_register_event_parameters_t)
#define ISCSI_DEREGISTER_EVENT   _IOWR(0, 12, iscsi_register_event_parameters_t)
#define ISCSI_WAIT_EVENT         _IOWR(0, 13, iscsi_wait_event_parameters_t)
#define ISCSI_POLL_EVENT         _IOWR(0, 14, iscsi_wait_event_parameters_t)

#endif /* !_ISCSI_IOCTL_H */