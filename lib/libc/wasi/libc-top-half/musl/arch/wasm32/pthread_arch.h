extern _Thread_local struct __pthread __wasilibc_pthread_self;

static inline uintptr_t __get_tp() {
  return (uintptr_t)&__wasilibc_pthread_self;
}
