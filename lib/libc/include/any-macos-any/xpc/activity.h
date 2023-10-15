#ifndef __XPC_ACTIVITY_H__
#define __XPC_ACTIVITY_H__

#ifndef __XPC_INDIRECT__
#error "Please #include <xpc/xpc.h> instead of this file directly."
// For HeaderDoc.
#include <xpc/base.h>
#endif // __XPC_INDIRECT__ 

#ifdef __BLOCKS__

XPC_ASSUME_NONNULL_BEGIN
__BEGIN_DECLS

/*
 * The following are a collection of keys and values used to set an activity's
 * execution criteria.
 */

/*!
 * @constant XPC_ACTIVITY_INTERVAL
 * An integer property indicating the desired time interval (in seconds) of the 
 * activity. The activity will not be run more than once per time interval.
 * Due to the nature of XPC Activity finding an opportune time to run
 * the activity, any two occurrences may be more or less than 'interval'
 * seconds apart, but on average will be 'interval' seconds apart.
 * The presence of this key implies the following, unless overridden:
 * - XPC_ACTIVITY_REPEATING with a value of true
 * - XPC_ACTIVITY_DELAY with a value of half the 'interval'
 *   The delay enforces a minimum distance between any two occurrences.
 * - XPC_ACTIVITY_GRACE_PERIOD with a value of half the 'interval'.
 *   The grace period is the amount of time allowed to pass after the end of
 *   the interval before more aggressive scheduling occurs. The grace period
 *   does not increase the size of the interval.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const char * const XPC_ACTIVITY_INTERVAL;

/*!
 * @constant XPC_ACTIVITY_REPEATING
 * A boolean property indicating whether this is a repeating activity.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const char * const XPC_ACTIVITY_REPEATING;

/*!
 * @constant XPC_ACTIVITY_DELAY
 * An integer property indicating the number of seconds to delay before
 * beginning the activity.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const char * const XPC_ACTIVITY_DELAY;

/*!
 * @constant XPC_ACTIVITY_GRACE_PERIOD
 * An integer property indicating the number of seconds to allow as a grace
 * period before the scheduling of the activity becomes more aggressive.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const char * const XPC_ACTIVITY_GRACE_PERIOD;


__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_1_MIN;

__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_5_MIN;

__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_15_MIN;

__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_30_MIN;

__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_1_HOUR;

__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_4_HOURS;

__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_8_HOURS;

__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_1_DAY;

__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const int64_t XPC_ACTIVITY_INTERVAL_7_DAYS;

/*!
 * @constant XPC_ACTIVITY_PRIORITY
 * A string property indicating the priority of the activity.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const char * const XPC_ACTIVITY_PRIORITY;

/*!
 * @constant XPC_ACTIVITY_PRIORITY_MAINTENANCE
 * A string indicating activity is maintenance priority.
 *
 * Maintenance priority is intended for user-invisible maintenance tasks
 * such as garbage collection or optimization.
 *
 * Maintenance activities are not permitted to run if the device thermal
 * condition exceeds a nominal level or if the battery level is lower than 20%.
 * In Low Power Mode (on supported devices), maintenance activities are not
 * permitted to run while the device is on battery, or plugged in and the
 * battery level is lower than 30%.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const char * const XPC_ACTIVITY_PRIORITY_MAINTENANCE;

/*!
 * @constant XPC_ACTIVITY_PRIORITY_UTILITY
 * A string indicating activity is utility priority.
 *
 * Utility priority is intended for user-visible tasks such as fetching data
 * from the network, copying files, or importing data.
 *
 * Utility activities are not permitted to run if the device thermal condition
 * exceeds a moderate level or if the battery level is less than 10%.  In Low
 * Power Mode (on supported devices) when on battery power, utility activities
 * are only permitted when they are close to their deadline (90% of their time
 * window has elapsed).
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const char * const XPC_ACTIVITY_PRIORITY_UTILITY;

/*!
 * @constant XPC_ACTIVITY_ALLOW_BATTERY
 * A Boolean value indicating whether the activity should be allowed to run
 * while the computer is on battery power. The default value is false for
 * maintenance priority activity and true for utility priority activity.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const char * const XPC_ACTIVITY_ALLOW_BATTERY;

/*!
 * @constant XPC_ACTIVITY_REQUIRE_SCREEN_SLEEP
 * A Boolean value indicating whether the activity should only be performed
 * while device appears to be asleep.  Note that the definition of screen sleep
 * may vary by platform and may include states where the device is known to be
 * idle despite the fact that the display itself is still powered.  Defaults to
 * false.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const char * const XPC_ACTIVITY_REQUIRE_SCREEN_SLEEP; // bool

/*!
 * @constant XPC_ACTIVITY_PREVENT_DEVICE_SLEEP
 * A Boolean value indicating whether the activity should prevent system sleep while
 * running on battery.
 * If this property is set, the activity scheduler will take the appropriate power
 * assertion to keep the device (but not the screen) awake while the activity is running.
 * Only activities which perform critical system functions that do not want to be
 * interrupted by system sleep should set this.
 * Setting this property can impact battery life.
 */
__API_AVAILABLE(macos(12.0), ios(15.0), watchos(8.0))
XPC_EXPORT
const char * const XPC_ACTIVITY_PREVENT_DEVICE_SLEEP; // bool

/*!
 * @constant XPC_ACTIVITY_REQUIRE_BATTERY_LEVEL
 * An integer percentage of minimum battery charge required to allow the
 * activity to run. A default minimum battery level is determined by the
 * system.
 */
__OSX_AVAILABLE_BUT_DEPRECATED_MSG(__MAC_10_9, __MAC_10_9, __IPHONE_7_0, __IPHONE_7_0,
	"REQUIRE_BATTERY_LEVEL is not implemented")
XPC_EXPORT
const char * const XPC_ACTIVITY_REQUIRE_BATTERY_LEVEL; // int (%)

/*!
 * @constant XPC_ACTIVITY_REQUIRE_HDD_SPINNING
 * A Boolean value indicating whether the activity should only be performed
 * while the hard disk drive (HDD) is spinning. Computers with flash storage
 * are considered to be equivalent to HDD spinning. Defaults to false.
 */
__OSX_AVAILABLE_BUT_DEPRECATED_MSG(__MAC_10_9, __MAC_10_9, __IPHONE_7_0, __IPHONE_7_0,
	"REQUIRE_HDD_SPINNING is not implemented")
XPC_EXPORT
const char * const XPC_ACTIVITY_REQUIRE_HDD_SPINNING; // bool

/*!
 * @define XPC_TYPE_ACTIVITY
 * A type representing the XPC activity object.
 */
#define XPC_TYPE_ACTIVITY (&_xpc_type_activity)
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
XPC_TYPE(_xpc_type_activity);

/*!
 * @typedef xpc_activity_t
 *
 * @abstract
 * An XPC activity object.
 *
 * @discussion
 * This object represents a set of execution criteria and a current execution
 * state for background activity on the system. Once an activity is registered,
 * the system will evaluate its criteria to determine whether the activity is
 * eligible to run under current system conditions. When an activity becomes
 * eligible to run, its execution state will be updated and an invocation of
 * its handler block will be made.
 */
XPC_DECL(xpc_activity);

/*!
 * @typedef xpc_activity_handler_t
 *
 * @abstract
 * A block that is called when an XPC activity becomes eligible to run.
 */
XPC_NONNULL1
typedef void (^xpc_activity_handler_t)(xpc_activity_t activity);

/*!
 * @constant XPC_ACTIVITY_CHECK_IN
 * This constant may be passed to xpc_activity_register() as the criteria
 * dictionary in order to check in with the system for previously registered
 * activity using the same identifier (for example, an activity taken from a
 * launchd property list).
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT
const xpc_object_t XPC_ACTIVITY_CHECK_IN;

/*!
 * @function xpc_activity_register
 *
 * @abstract
 * Registers an activity with the system.
 *
 * @discussion
 * Registers a new activity with the system. The criteria of the activity are
 * described by the dictionary passed to this function. If an activity with the
 * same identifier already exists, the criteria provided override the existing
 * criteria unless the special dictionary XPC_ACTIVITY_CHECK_IN is used. The
 * XPC_ACTIVITY_CHECK_IN dictionary instructs the system to first look up an
 * existing activity without modifying its criteria. Once the existing activity
 * is found (or a new one is created with an empty set of criteria) the handler
 * will be called with an activity object in the XPC_ACTIVITY_STATE_CHECK_IN
 * state.
 *
 * @param identifier
 * A unique identifier for the activity. Each application has its own namespace.
 * The identifier should remain constant across registrations, relaunches of
 * the application, and reboots. It should identify the kind of work being done,
 * not a particular invocation of the work.
 *
 * @param criteria
 * A dictionary of criteria for the activity.
 *
 * @param handler
 * The handler block to be called when the activity changes state to one of the
 * following states:
 * - XPC_ACTIVITY_STATE_CHECK_IN (optional)
 * - XPC_ACTIVITY_STATE_RUN
 *
 * The handler block is never invoked reentrantly. It will be invoked on a
 * dispatch queue with an appropriate priority to perform the activity.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2 XPC_NONNULL3
void
xpc_activity_register(const char *identifier, xpc_object_t criteria,
	xpc_activity_handler_t handler);

/*!
 * @function xpc_activity_copy_criteria
 *
 * @abstract
 * Returns an XPC dictionary describing the execution criteria of an activity.
 * This will return NULL in cases where the activity has already completed, e.g.
 * when checking in to an event that finished and was not rescheduled.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT XPC_WARN_RESULT XPC_RETURNS_RETAINED XPC_NONNULL1
xpc_object_t _Nullable
xpc_activity_copy_criteria(xpc_activity_t activity);

/*!
 * @function xpc_activity_set_criteria
 *
 * @abstract
 * Modifies the execution criteria of an activity.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_activity_set_criteria(xpc_activity_t activity, xpc_object_t criteria);

/*!
 * @enum xpc_activity_state_t
 * An activity is defined to be in one of the following states. Applications
 * may check the current state of the activity using xpc_activity_get_state()
 * in the handler block provided to xpc_activity_register().
 *
 * The application can modify the state of the activity by calling
 * xpc_activity_set_state() with one of the following:
 * - XPC_ACTIVITY_STATE_DEFER
 * - XPC_ACTIVITY_STATE_CONTINUE
 * - XPC_ACTIVITY_STATE_DONE
 *
 * @constant XPC_ACTIVITY_STATE_CHECK_IN
 * An activity in this state has just completed a checkin with the system after
 * XPC_ACTIVITY_CHECK_IN was provided as the criteria dictionary to
 * xpc_activity_register. The state gives the application an opportunity to
 * inspect and modify the activity's criteria.
 *
 * @constant XPC_ACTIVITY_STATE_WAIT
 * An activity in this state is waiting for an opportunity to run. This value
 * is never returned within the activity's handler block, as the block is
 * invoked in response to XPC_ACTIVITY_STATE_CHECK_IN or XPC_ACTIVITY_STATE_RUN.
 *
 * Note:
 * A launchd job may idle exit while an activity is in the wait state and be
 * relaunched in response to the activity becoming runnable. The launchd job
 * simply needs to re-register for the activity on its next launch by passing
 * XPC_ACTIVITY_STATE_CHECK_IN to xpc_activity_register().
 *
 * @constant XPC_ACTIVITY_STATE_RUN
 * An activity in this state is eligible to run based on its criteria.
 *
 * @constant XPC_ACTIVITY_STATE_DEFER
 * An application may pass this value to xpc_activity_set_state() to indicate
 * that the activity should be deferred (placed back into the WAIT state) until
 * a time when its criteria are met again. Deferring an activity does not reset
 * any of its time-based criteria (in other words, it will remain past due).
 *
 * IMPORTANT:
 * This should be done in response to observing xpc_activity_should_defer().
 * It should not be done unilaterally. If you determine that conditions are bad
 * to do your activity's work for reasons you can't express in a criteria
 * dictionary, you should set the activity's state to XPC_ACTIVITY_STATE_DONE.
 *
 *
 * @constant XPC_ACTIVITY_STATE_CONTINUE
 * An application may pass this value to xpc_activity_set_state() to indicate
 * that the activity will continue its operation beyond the return of its
 * handler block. This can be used to extend an activity to include asynchronous
 * operations. The activity's handler block will not be invoked again until the
 * state has been updated to either XPC_ACTIVITY_STATE_DEFER or, in the case
 * of repeating activity, XPC_ACTIVITY_STATE_DONE.
 *
 * @constant XPC_ACTIVITY_STATE_DONE
 * An application may pass this value to xpc_activity_set_state() to indicate
 * that the activity has completed. For non-repeating activity, the resources
 * associated with the activity will be automatically released upon return from
 * the handler block. For repeating activity, timers present in the activity's
 * criteria will be reset.
 */
enum {
	XPC_ACTIVITY_STATE_CHECK_IN,
	XPC_ACTIVITY_STATE_WAIT,
	XPC_ACTIVITY_STATE_RUN,
	XPC_ACTIVITY_STATE_DEFER,
	XPC_ACTIVITY_STATE_CONTINUE,
	XPC_ACTIVITY_STATE_DONE,
};
typedef long xpc_activity_state_t;

/*!
 * @function xpc_activity_get_state
 *
 * @abstract
 * Returns the current state of an activity.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
xpc_activity_state_t
xpc_activity_get_state(xpc_activity_t activity);

/*!
 * @function xpc_activity_set_state
 *
 * @abstract
 * Updates the current state of an activity.
 *
 * @return
 * Returns true if the state was successfully updated; otherwise, returns
 * false if the requested state transition is not valid.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
bool
xpc_activity_set_state(xpc_activity_t activity, xpc_activity_state_t state);

/*!
 * @function xpc_activity_should_defer
 *
 * @abstract
 * Test whether an activity should be deferred.
 *
 * @discussion
 * This function may be used to test whether the criteria of a long-running
 * activity are still satisfied. If not, the system indicates that the
 * application should defer the activity. The application may acknowledge the
 * deferral by calling xpc_activity_set_state() with XPC_ACTIVITY_STATE_DEFER.
 * Once deferred, the system will place the activity back into the WAIT state
 * and re-invoke the handler block at the earliest opportunity when the criteria
 * are once again satisfied.
 *
 * @return
 * Returns true if the activity should be deferred.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL1
bool
xpc_activity_should_defer(xpc_activity_t activity);

/*!
 * @function xpc_activity_unregister
 *
 * @abstract
 * Unregisters an activity found by its identifier.
 *
 * @discussion
 * A dynamically registered activity will be deleted in response to this call.
 * Statically registered activity (from a launchd property list) will be
 * deleted until the job is next loaded (e.g. at next boot).
 *
 * Unregistering an activity has no effect on any outstanding xpc_activity_t
 * objects or any currently executing xpc_activity_handler_t blocks; however,
 * no new handler block invocations will be made after it is unregistered.
 *
 * @param identifier
 * The identifier of the activity to unregister.
 */
__OSX_AVAILABLE_STARTING(__MAC_10_9, __IPHONE_7_0)
XPC_EXPORT XPC_NONNULL1
void
xpc_activity_unregister(const char *identifier);

__END_DECLS
XPC_ASSUME_NONNULL_END

#endif // __BLOCKS__

#endif // __XPC_ACTIVITY_H__ 

