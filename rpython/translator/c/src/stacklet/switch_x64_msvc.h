/* The actual stack saving function, which just stores the stack,
 * this declared in an .asm file
 */
extern void *slp_switch(void *(*save_state)(void*, void*),
                        void *(*restore_state)(void*, void*),
                        void *extra);

#undef STATIC_NOINLINE
#define STATIC_NOINLINE   static __declspec(noinline)
