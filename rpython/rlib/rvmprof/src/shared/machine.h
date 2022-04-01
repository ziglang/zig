#pragma once

/**
 * What is the usual word size of the processor? 64bit? 32bit?
 */
int vmp_machine_bits(void);

/**
 * Return the human readable name of the operating system.
 */
const char * vmp_machine_os_name(void);

/**
 * Writes the filename into buffer. Returns -1 if the platform is not
 * implemented.
 */
long vmp_fd_to_path(int fd, char * buffer, long buffer_len);

