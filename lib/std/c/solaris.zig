pub const pthread_mutex_t = extern struct {
    __pthread_mutex_flag1: u16 = 0,
    __pthread_mutex_flag2: u8 = 0,
    __pthread_mutex_ceiling: u8 = 0,
    __pthread_mutex_type: u16 = 0,
    __pthread_mutex_magic: u16 = 0x4d58,
    __pthread_mutex_lock: u64 = 0,
    __pthread_mutex_data: u64 = 0,
};
pub const pthread_cond_t = extern struct {
    __pthread_cond_flag: u32 = 0,
    __pthread_cond_type: u16 = 0,
    __pthread_cond_magic: u16 = 0x4356,
    __pthread_cond_data: u64 = 0,
};
