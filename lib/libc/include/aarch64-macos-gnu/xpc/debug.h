#ifndef __XPC_DEBUG_H__
#define __XPC_DEBUG_H__

/*!
 * @function xpc_debugger_api_misuse_info
 * Returns a pointer to a string describing the reason XPC aborted the calling
 * process. On OS X, this will be the same string present in the "Application
 * Specific Information" section of the crash report.
 * 
 * @result
 * A pointer to the human-readable string describing the reason the caller was
 * aborted. If XPC was not responsible for the program's termination, NULL will
 * be returned.
 *
 * @discussion
 * This function is only callable from within a debugger. It is not meant to be
 * called by the program directly.
 */
XPC_DEBUGGER_EXCL
const char *
xpc_debugger_api_misuse_info(void);

#endif // __XPC_DEBUG_H__ 
