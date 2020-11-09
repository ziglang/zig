#ifndef __XPC_LAUNCH_H__
#define __XPC_LAUNCH_H__

/*!
 * @header
 * These interfaces were only ever documented for the purpose of allowing a
 * launchd job to obtain file descriptors associated with the sockets it
 * advertised in its launchd.plist(5). That functionality is now available in a
 * much more straightforward fashion through the {@link launch_activate_socket}
 * API.
 *
 * There are currently no replacements for other uses of the {@link launch_msg}
 * API, including submitting, removing, starting, stopping and listing jobs.
 */

#include <os/base.h>
#include <Availability.h>

#include <mach/mach.h>
#include <stddef.h>
#include <stdbool.h>
#include <sys/cdefs.h>

#if __has_feature(assume_nonnull)
_Pragma("clang assume_nonnull begin")
#endif
__BEGIN_DECLS

#define LAUNCH_KEY_SUBMITJOB "SubmitJob"
#define LAUNCH_KEY_REMOVEJOB "RemoveJob"
#define LAUNCH_KEY_STARTJOB "StartJob"
#define LAUNCH_KEY_STOPJOB "StopJob"
#define LAUNCH_KEY_GETJOB "GetJob"
#define LAUNCH_KEY_GETJOBS "GetJobs"
#define LAUNCH_KEY_CHECKIN "CheckIn"

#define LAUNCH_JOBKEY_LABEL "Label"
#define LAUNCH_JOBKEY_DISABLED "Disabled"
#define LAUNCH_JOBKEY_USERNAME "UserName"
#define LAUNCH_JOBKEY_GROUPNAME "GroupName"
#define LAUNCH_JOBKEY_TIMEOUT "TimeOut"
#define LAUNCH_JOBKEY_EXITTIMEOUT "ExitTimeOut"
#define LAUNCH_JOBKEY_INITGROUPS "InitGroups"
#define LAUNCH_JOBKEY_SOCKETS "Sockets"
#define LAUNCH_JOBKEY_MACHSERVICES "MachServices"
#define LAUNCH_JOBKEY_MACHSERVICELOOKUPPOLICIES "MachServiceLookupPolicies"
#define LAUNCH_JOBKEY_INETDCOMPATIBILITY "inetdCompatibility"
#define LAUNCH_JOBKEY_ENABLEGLOBBING "EnableGlobbing"
#define LAUNCH_JOBKEY_PROGRAMARGUMENTS "ProgramArguments"
#define LAUNCH_JOBKEY_PROGRAM "Program"
#define LAUNCH_JOBKEY_ONDEMAND "OnDemand"
#define LAUNCH_JOBKEY_KEEPALIVE "KeepAlive"
#define LAUNCH_JOBKEY_LIMITLOADTOHOSTS "LimitLoadToHosts"
#define LAUNCH_JOBKEY_LIMITLOADFROMHOSTS "LimitLoadFromHosts"
#define LAUNCH_JOBKEY_LIMITLOADTOSESSIONTYPE "LimitLoadToSessionType"
#define LAUNCH_JOBKEY_LIMITLOADTOHARDWARE "LimitLoadToHardware"
#define LAUNCH_JOBKEY_LIMITLOADFROMHARDWARE "LimitLoadFromHardware"
#define LAUNCH_JOBKEY_RUNATLOAD "RunAtLoad"
#define LAUNCH_JOBKEY_ROOTDIRECTORY "RootDirectory"
#define LAUNCH_JOBKEY_WORKINGDIRECTORY "WorkingDirectory"
#define LAUNCH_JOBKEY_ENVIRONMENTVARIABLES "EnvironmentVariables"
#define LAUNCH_JOBKEY_USERENVIRONMENTVARIABLES "UserEnvironmentVariables"
#define LAUNCH_JOBKEY_UMASK "Umask"
#define LAUNCH_JOBKEY_NICE "Nice"
#define LAUNCH_JOBKEY_HOPEFULLYEXITSFIRST "HopefullyExitsFirst"
#define LAUNCH_JOBKEY_HOPEFULLYEXITSLAST "HopefullyExitsLast"
#define LAUNCH_JOBKEY_LOWPRIORITYIO "LowPriorityIO"
#define LAUNCH_JOBKEY_LOWPRIORITYBACKGROUNDIO "LowPriorityBackgroundIO"
#define LAUNCH_JOBKEY_MATERIALIZEDATALESSFILES "MaterializeDatalessFiles"
#define LAUNCH_JOBKEY_SESSIONCREATE "SessionCreate"
#define LAUNCH_JOBKEY_STARTONMOUNT "StartOnMount"
#define LAUNCH_JOBKEY_SOFTRESOURCELIMITS "SoftResourceLimits"
#define LAUNCH_JOBKEY_HARDRESOURCELIMITS "HardResourceLimits"
#define LAUNCH_JOBKEY_STANDARDINPATH "StandardInPath"
#define LAUNCH_JOBKEY_STANDARDOUTPATH "StandardOutPath"
#define LAUNCH_JOBKEY_STANDARDERRORPATH "StandardErrorPath"
#define LAUNCH_JOBKEY_DEBUG "Debug"
#define LAUNCH_JOBKEY_WAITFORDEBUGGER "WaitForDebugger"
#define LAUNCH_JOBKEY_QUEUEDIRECTORIES "QueueDirectories"
#define LAUNCH_JOBKEY_HOMERELATIVEQUEUEDIRECTORIES "HomeRelativeQueueDirectories"
#define LAUNCH_JOBKEY_WATCHPATHS "WatchPaths"
#define LAUNCH_JOBKEY_STARTINTERVAL "StartInterval"
#define LAUNCH_JOBKEY_STARTCALENDARINTERVAL "StartCalendarInterval"
#define LAUNCH_JOBKEY_BONJOURFDS "BonjourFDs"
#define LAUNCH_JOBKEY_LASTEXITSTATUS "LastExitStatus"
#define LAUNCH_JOBKEY_PID "PID"
#define LAUNCH_JOBKEY_THROTTLEINTERVAL "ThrottleInterval"
#define LAUNCH_JOBKEY_LAUNCHONLYONCE "LaunchOnlyOnce"
#define LAUNCH_JOBKEY_ABANDONPROCESSGROUP "AbandonProcessGroup"
#define LAUNCH_JOBKEY_IGNOREPROCESSGROUPATSHUTDOWN \
	"IgnoreProcessGroupAtShutdown"
#define LAUNCH_JOBKEY_LEGACYTIMERS "LegacyTimers"
#define LAUNCH_JOBKEY_ENABLEPRESSUREDEXIT "EnablePressuredExit"
#define LAUNCH_JOBKEY_ENABLETRANSACTIONS "EnableTransactions"
#define LAUNCH_JOBKEY_DRAINMESSAGESONFAILEDINIT "DrainMessagesOnFailedInit"
#define LAUNCH_JOBKEY_POLICIES "Policies"

#define LAUNCH_JOBKEY_PUBLISHESEVENTS "PublishesEvents"
#define LAUNCH_KEY_PUBLISHESEVENTS_DOMAININTERNAL "DomainInternal"

#define LAUNCH_JOBPOLICY_DENYCREATINGOTHERJOBS "DenyCreatingOtherJobs"

#define LAUNCH_JOBINETDCOMPATIBILITY_WAIT "Wait"
#define LAUNCH_JOBINETDCOMPATIBILITY_INSTANCES "Instances"

#define LAUNCH_JOBKEY_MACH_RESETATCLOSE "ResetAtClose"
#define LAUNCH_JOBKEY_MACH_HIDEUNTILCHECKIN "HideUntilCheckIn"

#define LAUNCH_JOBKEY_KEEPALIVE_SUCCESSFULEXIT "SuccessfulExit"
#define LAUNCH_JOBKEY_KEEPALIVE_NETWORKSTATE "NetworkState"
#define LAUNCH_JOBKEY_KEEPALIVE_PATHSTATE "PathState"
#define LAUNCH_JOBKEY_KEEPALIVE_HOMERELATIVEPATHSTATE "HomeRelativePathState"
#define LAUNCH_JOBKEY_KEEPALIVE_OTHERJOBACTIVE "OtherJobActive"
#define LAUNCH_JOBKEY_KEEPALIVE_OTHERJOBENABLED "OtherJobEnabled"
#define LAUNCH_JOBKEY_KEEPALIVE_AFTERINITIALDEMAND	"AfterInitialDemand"
#define LAUNCH_JOBKEY_KEEPALIVE_CRASHED "Crashed"

#define LAUNCH_JOBKEY_LAUNCHEVENTS "LaunchEvents"

#define LAUNCH_JOBKEY_CAL_MINUTE "Minute"
#define LAUNCH_JOBKEY_CAL_HOUR "Hour"
#define LAUNCH_JOBKEY_CAL_DAY "Day"
#define LAUNCH_JOBKEY_CAL_WEEKDAY "Weekday"
#define LAUNCH_JOBKEY_CAL_MONTH "Month"

#define LAUNCH_JOBKEY_RESOURCELIMIT_CORE "Core"
#define LAUNCH_JOBKEY_RESOURCELIMIT_CPU "CPU"
#define LAUNCH_JOBKEY_RESOURCELIMIT_DATA "Data"
#define LAUNCH_JOBKEY_RESOURCELIMIT_FSIZE "FileSize"
#define LAUNCH_JOBKEY_RESOURCELIMIT_MEMLOCK "MemoryLock"
#define LAUNCH_JOBKEY_RESOURCELIMIT_NOFILE "NumberOfFiles"
#define LAUNCH_JOBKEY_RESOURCELIMIT_NPROC "NumberOfProcesses"
#define LAUNCH_JOBKEY_RESOURCELIMIT_RSS "ResidentSetSize"
#define LAUNCH_JOBKEY_RESOURCELIMIT_STACK "Stack"

#define LAUNCH_JOBKEY_DISABLED_MACHINETYPE "MachineType"
#define LAUNCH_JOBKEY_DISABLED_MODELNAME "ModelName"

#define LAUNCH_JOBKEY_DATASTORES "Datastores"
#define LAUNCH_JOBKEY_DATASTORES_SIZELIMIT "SizeLimit"

#define LAUNCH_JOBSOCKETKEY_TYPE "SockType"
#define LAUNCH_JOBSOCKETKEY_PASSIVE "SockPassive"
#define LAUNCH_JOBSOCKETKEY_BONJOUR "Bonjour"
#define LAUNCH_JOBSOCKETKEY_SECUREWITHKEY "SecureSocketWithKey"
#define LAUNCH_JOBSOCKETKEY_PATHNAME "SockPathName"
#define LAUNCH_JOBSOCKETKEY_PATHMODE "SockPathMode"
#define LAUNCH_JOBSOCKETKEY_PATHOWNER "SockPathOwner"
#define LAUNCH_JOBSOCKETKEY_PATHGROUP "SockPathGroup"
#define LAUNCH_JOBSOCKETKEY_NODENAME "SockNodeName"
#define LAUNCH_JOBSOCKETKEY_SERVICENAME "SockServiceName"
#define LAUNCH_JOBSOCKETKEY_FAMILY "SockFamily"
#define LAUNCH_JOBSOCKETKEY_PROTOCOL "SockProtocol"
#define LAUNCH_JOBSOCKETKEY_MULTICASTGROUP "MulticastGroup"

#define LAUNCH_JOBKEY_PROCESSTYPE "ProcessType"
#define LAUNCH_KEY_PROCESSTYPE_APP "App"
#define LAUNCH_KEY_PROCESSTYPE_STANDARD "Standard"
#define LAUNCH_KEY_PROCESSTYPE_BACKGROUND "Background"
#define LAUNCH_KEY_PROCESSTYPE_INTERACTIVE "Interactive"
#define LAUNCH_KEY_PROCESSTYPE_ADAPTIVE "Adaptive"

/*!
 * @function launch_activate_socket
 *
 * @abstract
 * Retrieves the file descriptors for sockets specified in the process'
 * launchd.plist(5).
 *
 * @param name
 * The name of the socket entry in the service's Sockets dictionary.
 *
 * @param fds
 * On return, this parameter will be populated with an array of file
 * descriptors. One socket can have many descriptors associated with it
 * depending on the characteristics of the network interfaces on the system.
 * The descriptors in this array are the results of calling getaddrinfo(3) with
 * the parameters described in launchd.plist(5).
 *
 * The caller is responsible for calling free(3) on the returned pointer.
 *
 * @param cnt
 * The number of file descriptor entries in the returned array.
 *
 * @result
 * On success, zero is returned. Otherwise, an appropriate POSIX-domain is
 * returned. Possible error codes are:
 *
 * ENOENT -> There was no socket of the specified name owned by the caller.
 * ESRCH -> The caller is not a process managed by launchd.
 * EALREADY -> The socket has already been activated by the caller.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_10, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1 OS_NONNULL2 OS_NONNULL3
int
launch_activate_socket(const char *name,
	int * _Nonnull * _Nullable fds, size_t *cnt);

typedef struct _launch_data *launch_data_t;
typedef void (*launch_data_dict_iterator_t)(const launch_data_t lval,
	const char *key, void * _Nullable ctx);

typedef enum {
	LAUNCH_DATA_DICTIONARY = 1,
	LAUNCH_DATA_ARRAY,
	LAUNCH_DATA_FD,
	LAUNCH_DATA_INTEGER,
	LAUNCH_DATA_REAL,
	LAUNCH_DATA_BOOL,
	LAUNCH_DATA_STRING,
	LAUNCH_DATA_OPAQUE,
	LAUNCH_DATA_ERRNO,
	LAUNCH_DATA_MACHPORT,
} launch_data_type_t;

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_MALLOC OS_WARN_RESULT
launch_data_t
launch_data_alloc(launch_data_type_t type);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_MALLOC OS_WARN_RESULT OS_NONNULL1
launch_data_t
launch_data_copy(launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
launch_data_type_t
launch_data_get_type(const launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1
void
launch_data_free(launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1 OS_NONNULL2 OS_NONNULL3
bool
launch_data_dict_insert(launch_data_t ldict, const launch_data_t lval,
	const char *key);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1 OS_NONNULL2
launch_data_t _Nullable
launch_data_dict_lookup(const launch_data_t ldict, const char *key);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1 OS_NONNULL2
bool
launch_data_dict_remove(launch_data_t ldict, const char *key);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1 OS_NONNULL2
void
launch_data_dict_iterate(const launch_data_t ldict,
	launch_data_dict_iterator_t iterator, void * _Nullable ctx);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
size_t
launch_data_dict_get_count(const launch_data_t ldict);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1 OS_NONNULL2
bool
launch_data_array_set_index(launch_data_t larray, const launch_data_t lval,
	size_t idx);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
launch_data_t
launch_data_array_get_index(const launch_data_t larray, size_t idx);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
size_t
launch_data_array_get_count(const launch_data_t larray);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_MALLOC OS_WARN_RESULT
launch_data_t
launch_data_new_fd(int fd);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_MALLOC OS_WARN_RESULT
launch_data_t
launch_data_new_machport(mach_port_t val);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_MALLOC OS_WARN_RESULT
launch_data_t
launch_data_new_integer(long long val);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_MALLOC OS_WARN_RESULT
launch_data_t
launch_data_new_bool(bool val);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_MALLOC OS_WARN_RESULT
launch_data_t
launch_data_new_real(double val);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_MALLOC OS_WARN_RESULT
launch_data_t
launch_data_new_string(const char *val);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_MALLOC OS_WARN_RESULT
launch_data_t
launch_data_new_opaque(const void *bytes, size_t sz);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1
bool
launch_data_set_fd(launch_data_t ld, int fd);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1
bool
launch_data_set_machport(launch_data_t ld, mach_port_t mp);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1
bool
launch_data_set_integer(launch_data_t ld, long long val);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1
bool
launch_data_set_bool(launch_data_t ld, bool val);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1
bool
launch_data_set_real(launch_data_t ld, double val);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1
bool
launch_data_set_string(launch_data_t ld, const char *val);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_NONNULL1
bool
launch_data_set_opaque(launch_data_t ld, const void *bytes, size_t sz);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
int
launch_data_get_fd(const launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
mach_port_t
launch_data_get_machport(const launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
long long
launch_data_get_integer(const launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
bool
launch_data_get_bool(const launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
double
launch_data_get_real(const launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
const char *
launch_data_get_string(const launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
void *
launch_data_get_opaque(const launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
size_t
launch_data_get_opaque_size(const launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT OS_NONNULL1
int
launch_data_get_errno(const launch_data_t ld);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_WARN_RESULT
int
launch_get_fd(void);

__OSX_AVAILABLE_BUT_DEPRECATED(__MAC_10_4, __MAC_10_10, __IPHONE_2_0, __IPHONE_8_0)
OS_EXPORT OS_MALLOC OS_WARN_RESULT OS_NONNULL1
launch_data_t
launch_msg(const launch_data_t request);

__END_DECLS
#if __has_feature(assume_nonnull)
_Pragma("clang assume_nonnull end")
#endif

#endif // __XPC_LAUNCH_H__
