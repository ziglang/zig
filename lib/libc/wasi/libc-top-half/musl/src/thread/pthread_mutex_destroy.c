#include "pthread_impl.h"

int pthread_mutex_destroy(pthread_mutex_t *mutex)
{
#ifdef __wasilibc_unmodified_upstream
	/* If the mutex being destroyed is process-shared and has nontrivial
	 * type (tracking ownership), it might be in the pending slot of a
	 * robust_list; wait for quiescence. */
	if (mutex->_m_type > 128) __vm_wait();
#else
	/* For now, wasi-libc chooses to avoid implementing robust mutex support
	 * though this could be added later. The error code indicates that the
	 * mutex was an invalid type, but it would be more accurate as 
	 * "unimplemented". */
	if (mutex->_m_type > 128) return EINVAL;
#endif
	return 0;
}
