#ifndef _SYS_REBOOT_H
#define _SYS_REBOOT_H
#ifdef __cplusplus
extern "C"
{
#endif

#define RB_AUTOBOOT 0x01234567
#define RB_HALT_SYSTEM 0xcdef0123
#define RB_ENABLE_CAD 0x89abcdef
#define RB_DISABLE_CAD 0
#define RB_POWER_OFF 0x4321fedc
#define RB_SW_SUSPEND 0xd000fce2
#define RB_KEXEC 0x45584543
#define RB_MAGIC1 0xfee1dead
#define RB_MAGIC2 672274793

/** 
  * @brief reboots the device, or enables/disables the reboot keystroke.
  * @param type commands accepted by the reboot() system call.
  *    -- RESTART     Restart system using default command and mode.
  *    -- HALT        Stop OS and give system control to ROM monitor, if any.
  *    -- CAD_ON      Ctrl-Alt-Del sequence causes RESTART command.
  *    -- CAD_OFF     Ctrl-Alt-Del sequence sends SIGINT to init task.
  *    -- POWER_OFF   Stop OS and remove all power from system, if possible.
  *    -- RESTART2    Restart system using given command string.
  *    -- SW_SUSPEND  Suspend system using software suspend if compiled in.
  *    -- KEXEC       Restart system using a previously loaded Linux kernel.
  * @return reboot result.
  * @retval 0 is returned on success, if CAD was successfully enabled/disabled.
  * @retval -1 is returned on failure, and errno is set to indicate the error.
  */
int reboot(int);

#ifdef __cplusplus
}
#endif
#endif
