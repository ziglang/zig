#pragma once

/**
 * Returns 0 on success
 */
int vmp_patch_callee_trampoline(void * callee_addr, void * vmprof_eval, void ** vmprof_eval_target);

/**
 * Return 0 on success, -1 if the trampoline is not in place.
 * Any other value indicates a fatal error!
 */
int vmp_unpatch_callee_trampoline(void * callee_addr);
