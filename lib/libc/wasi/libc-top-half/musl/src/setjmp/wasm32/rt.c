/*
 * a runtime implementation for
 * https://github.com/llvm/llvm-project/pull/84137
 * https://docs.google.com/document/d/1ZvTPT36K5jjiedF8MCXbEmYjULJjI723aOAks1IdLLg/edit
 */

#include <stddef.h>
#include <stdint.h>

/*
 * function prototypes
 */
void __wasm_setjmp(void *env, uint32_t label, void *func_invocation_id);
uint32_t __wasm_setjmp_test(void *env, void *func_invocation_id);
void __wasm_longjmp(void *env, int val);

/*
 * jmp_buf should have large enough size and alignment to contain
 * this structure.
 */
struct jmp_buf_impl {
        void *func_invocation_id;
        uint32_t label;

        /*
         * this is a temorary storage used by the communication between
         * __wasm_sjlj_longjmp and WebAssemblyLowerEmscriptenEHSjL-generated
         * logic.
         * ideally, this can be replaced with multivalue.
         */
        struct arg {
                void *env;
                int val;
        } arg;
};

void
__wasm_setjmp(void *env, uint32_t label, void *func_invocation_id)
{
        struct jmp_buf_impl *jb = env;
        if (label == 0) { /* ABI contract */
                __builtin_trap();
        }
        if (func_invocation_id == NULL) { /* sanity check */
                __builtin_trap();
        }
        jb->func_invocation_id = func_invocation_id;
        jb->label = label;
}

uint32_t
__wasm_setjmp_test(void *env, void *func_invocation_id)
{
        struct jmp_buf_impl *jb = env;
        if (jb->label == 0) { /* ABI contract */
                __builtin_trap();
        }
        if (func_invocation_id == NULL) { /* sanity check */
                __builtin_trap();
        }
        if (jb->func_invocation_id == func_invocation_id) {
                return jb->label;
        }
        return 0;
}

void
__wasm_longjmp(void *env, int val)
{
        struct jmp_buf_impl *jb = env;
        struct arg *arg = &jb->arg;
        /*
         * C standard says:
         * The longjmp function cannot cause the setjmp macro to return
         * the value 0; if val is 0, the setjmp macro returns the value 1.
         */
        if (val == 0) {
                val = 1;
        }
        arg->env = env;
        arg->val = val;
        __builtin_wasm_throw(1, arg); /* 1 == C_LONGJMP */
}
