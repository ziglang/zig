/*	$NetBSD: scmdreg.h,v 1.2 2022/05/21 19:07:23 andvar Exp $	*/

/*
 * Copyright (c) 2021 Brad Spencer <brad@anduin.eldar.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#ifndef _DEV_SCMDREG_H_
#define _DEV_SCMDREG_H_

/* The device can occupy a large number of I2C addresses */

#define SCMD_LOW_I2C_ADDR	0x58
#define SCMD_HIGH_I2C_ADDR	0x61

/* The register address space for each module */

/* Some config and info registers */
#define SCMD_REG_FID			0x00 /* Firmware version */
#define SCMD_REG_ID			0x01 /* ID..  always 0xA9 */
#define SCMD_EXPECTED_ID		0xA9 /* What is always expected from the ID register */
#define SCMD_REG_SLAVE_ADDR		0x02 /* If a slave module, the I2C address */
#define SCMD_REG_CONFIG_BITS		0x03 /* Bit pattern of the jumpters on the board */
/* Diagnostics and debug registers */
#define SCMD_REG_U_I2C_RD_ERR		0x04 /* RD_ERR bits on USER port */
#define SCMD_REG_U_I2C_WR_ERR		0x05 /* WR_ERR bits on USER port */
#define SCMD_REG_U_BUF_DUMPED		0x06 /* Count of dumped buffers */
#define SCMD_REG_E_I2C_RD_ERR		0x07 /* Slave I2C read errors */
#define SCMD_REG_E_I2C_WR_ERR		0x08 /* Slave I2C write errors */
#define SCMD_REG_LOOP_TIME		0x09 /* Reports time in 100us of main loop */
#define SCMD_REG_SLV_POLL_CNT		0x0A /* Polls looking for slave modules */
#define SCMD_REG_SLV_TOP_ADDR		0x0B /* Highest slave I2C address */
#define SCMD_REG_MST_E_ERR		0x0C /* Number of expansion port I2C errors seen
					      * by the master module
					      */
#define SCMD_REG_MST_E_STATUS		0x0D /* Status of master controller board, expansion
					      * port I2C (write status)
					      */
#define SCMD_REG_FSAFE_FAULTS		0x0E /* Number of failsafe conditions seen */
#define SCMD_REG_REG_OOR_CNT		0x0F /* Register access attempts outside of range */
#define SCMD_REG_REG_RO_WRITE_CNT	0x10 /* Write lock write attempts */
#define SCMD_REG_GEN_TEST_WORD		0x11 /* Write causes data to be applied to
					      * REM_DATA_RD.
					      * 0x01: Read config bit pins
					      */
/* Local configuration registers */
#define SCMD_REG_MOTOR_A_INVERT		0x12 /* Invert direction of motor A on local module,
					      * or both if in bridged mode
					      */
#define SCMD_REG_MOTOR_B_INVERT		0x13 /* Invert direction of motor B on local module */
#define SCMD_REG_BRIDGE			0x14 /* Bridge motor A and B on local module */
#define SCMD_REG_LOCAL_MASTER_LOCK	0x15 /* Unlocked when set to 0x9B.  Allows writes to
					      * nearly any and every register.
					      */
#define SCMD_REG_LOCAL_USER_LOCK	0x16 /* Unlocked when set to 0x5C.  Allows writes to
					      * registers that are marked as user lockable
					      */
#define SCMD_REG_MST_E_IN_FN		0x17 /* Set action when master module config-in pin
					      * goes high.
					      * B1-0: Restarts
					      * 0x00 - do nothing
					      * 0x01 - reboot module
					      * 0x02 - re-enumerate
					      * B2: User port behavior
					      * 0x00 - do nothing
					      * 0x01 - reinitialize user port
					      * B3: Expansion port behavior
					      * 0x00 - do nothing
					      * 0x01 - reinitialize expansion port
					      */
#define SCMD_REG_U_PORT_CLKDIV_U	0x18 /* Clock divisor for the user port */
#define SCMD_REG_U_PORT_CLKDIV_L	0x19 /* See data sheet for more details */
#define SCMD_REG_U_PORT_CLKDIV_CTRL	0x1A /* See data sheet for more details */
#define SCMD_REG_E_PORT_CLKDIV_U	0x1B /* Clock divisor for the expansion port */
#define SCMD_REG_E_PORT_CLKDIV_L	0x1C /* See data sheet for more details */
#define SCMD_REG_E_PORT_CLKDIV_CTRL	0x1D /* See data sheet for more details */
#define SCMD_REG_U_BUS_UART_BAUD	0x1E /* Current baud rate when the module is
					      * communicating as a UART.  This register
					      * can only be read and never set directly.
					      * Use the 'U' command when communicating as
					      * an UART.
					      */
#define SCMD_REG_FSAFE_CTRL		0x1F /* Configure what happens when a failsafe
					      * condition happens:
					      * B0: output behavior
					      * 0x00 - maintain last motor drive levels
					      * 0x01 - set output level to 0 drive
					      * B2-1: Restart operation on master module
					      * 0x00 - do nothing
					      * 0x01 - reboot
					      * 0x02 - re-enumerate
					      * B3 - user port behavior
					      * 0x00 - do nothing
					      * 0x01 - reinitialize user port
					      * B4 - expansion port behavior
					      * 0x00 - do nothing
					      * 0x01 - reinitialize expansion port
					      */
/* Motor drive levels, local and remote */
#define SCMD_REG_MA_DRIVE		0x20 /* Drive level on master module motor A */
#define SCMD_REG_MB_DRIVE		0x21 /* Drive level on master module motor B */
#define SCMD_REG_S1A_DRIVE		0x22 /* Drive level on slave 1 module motor A */
#define SCMD_REG_S1B_DRIVE		0x23 /* Drive level on slave 1 module motor B */
#define SCMD_REG_S2A_DRIVE		0x24 /* Drive level on slave 2 module motor A */
#define SCMD_REG_S2B_DRIVE		0x25 /* Drive level on slave 2 module motor B */
#define SCMD_REG_S3A_DRIVE		0x26 /* Drive level on slave 3 module motor A */
#define SCMD_REG_S3B_DRIVE		0x27 /* Drive level on slave 3 module motor B */
#define SCMD_REG_S4A_DRIVE		0x28 /* Drive level on slave 4 module motor A */
#define SCMD_REG_S4B_DRIVE		0x29 /* Drive level on slave 4 module motor B */
#define SCMD_REG_S5A_DRIVE		0x2A /* Drive level on slave 5 module motor A */
#define SCMD_REG_S5B_DRIVE		0x2B /* Drive level on slave 5 module motor B */
#define SCMD_REG_S6A_DRIVE		0x2C /* Drive level on slave 6 module motor A */
#define SCMD_REG_S6B_DRIVE		0x2D /* Drive level on slave 6 module motor B */
#define SCMD_REG_S7A_DRIVE		0x2E /* Drive level on slave 7 module motor A */
#define SCMD_REG_S7B_DRIVE		0x2F /* Drive level on slave 7 module motor B */
#define SCMD_REG_S8A_DRIVE		0x30 /* Drive level on slave 8 module motor A */
#define SCMD_REG_S8B_DRIVE		0x31 /* Drive level on slave 8 module motor B */
#define SCMD_REG_S9A_DRIVE		0x32 /* Drive level on slave 9 module motor A */
#define SCMD_REG_S9B_DRIVE		0x33 /* Drive level on slave 9 module motor B */
#define SCMD_REG_S10A_DRIVE		0x34 /* Drive level on slave 10 module motor A */
#define SCMD_REG_S10B_DRIVE		0x35 /* Drive level on slave 10 module motor B */
#define SCMD_REG_S11A_DRIVE		0x36 /* Drive level on slave 11 module motor A */
#define SCMD_REG_S11B_DRIVE		0x37 /* Drive level on slave 11 module motor B */
#define SCMD_REG_S12A_DRIVE		0x38 /* Drive level on slave 12 module motor A */
#define SCMD_REG_S12B_DRIVE		0x39 /* Drive level on slave 12 module motor B */
#define SCMD_REG_S13A_DRIVE		0x3A /* Drive level on slave 13 module motor A */
#define SCMD_REG_S13B_DRIVE		0x3B /* Drive level on slave 13 module motor B */
#define SCMD_REG_S14A_DRIVE		0x3C /* Drive level on slave 14 module motor A */
#define SCMD_REG_S14B_DRIVE		0x3D /* Drive level on slave 14 module motor B */
#define SCMD_REG_S15A_DRIVE		0x3E /* Drive level on slave 15 module motor A */
#define SCMD_REG_S15B_DRIVE		0x3F /* Drive level on slave 15 module motor B */
#define SCMD_REG_S16A_DRIVE		0x40 /* Drive level on slave 16 module motor A */
#define SCMD_REG_S16B_DRIVE		0x41 /* Drive level on slave 16 module motor B */
/* A hole in the register space */
#define SCMD_REG_HOLE_1_LOW		0x42 /* A hole in the register space */
#define SCMD_REG_HOLE_1_HIGH		0x4F
/* Remote inversion and bridging */
#define SCMD_REG_INV_2_9		0x50 /* Invert the motors on the slave modules.
					      * Each bit is a motor.  Bit 0 is slave 1
					      * module, motor A.  Bit 8 is slave 4 module,
					      * motor B.
					      */
#define SCMD_REG_INV_10_17		0x51 /* Invert motors 10 - 17 */
#define SCMD_REG_INV_18_25		0x52 /* Invert motors 18 - 25 */
#define SCMD_REG_INV_26_33		0x53 /* Invert motors 26 - 33 */
#define SCMD_REG_BRIDGE_SLV_L		0x54 /* Bridge slave module outputs.  Bit 0 is slave 1
					      * module.  Bit 8 is slave 8 module.
					      */
#define SCMD_REG_BRIDGE_SLV_H		0x55 /* Brige slave module outputs.  Slave module 9 to
					      * 16
					      */
/* Another hole in the register space */
#define SCMD_REG_HOLE_2_LOW		0x56 /* Another hole in the register space */
#define SCMD_REG_PAGE_SELECT		0x6F /* Usused function to select the register space
					      * for use
					      */
#define SCMD_REG_HOLE_2_HIGH		0x6F /* End of the second hole */
/* System configuration registers.
 * Most are passed to the slave modules.
 */
#define SCMD_REG_DRIVER_ENABLE		0x70 /* Enable / disable all motor drivers.
					      * Set to 0x01 to enable, 0x00 to disable.
					      */
#define SCMD_DRIVER_ENABLE		0x01 /* Enable all motors */
#define SCMD_DRIVER_DISABLE		0x00 /* Disable all motors */
#define SCMD_REG_UPDATE_RATE		0x71 /* Update motors every UPDATE_RATE ms.
					      * Use 0x00 to require FORCE_UPDATE.
					      */
#define SCMD_REG_FORCE_UPDATE		0x72 /* Set to 0x01 to force a update of the motors.
					      * Auto resets to 0x00.
					      */
#define SCMD_REG_E_BUS_SPEED		0x73 /* Expansion bus speed:
					      * 0x00 - 50kHz
					      * 0x01 - 100kHz
					      * 0x02 - 400kHz
					      */
#define SCMD_REG_MASTER_LOCK		0x74 /* Unlocked when set to 0x9B.  Unlocks local and
					      * remote modules.
					      */
#define SCMD_REG_USER_LOCK		0x75 /* Unlocked when set to 0x5C.  Unlocks the user lock
						on the local and remote modules.
					     */
#define SCMD_REG_FSAFE_TIME		0x76 /* Program status, if set:
					      * B0 - Enumeration complete
					      * B1 - Device busy
					      * B2 - Remote module read in progress
					      * B3 - Remote module write in progress
					      * B4 - The state of enable pin U2.5
					      */
#define SCMD_REG_STATUS_1		0x77 /* Another way to get basic program status, if set:
					      * B0 - Enumeration complete
					      * B1 - Device busy
					      */
#define SCMD_REG_CONTROL_1		0x78 /* Restart and re-enumeration control.  If set:
					      * B0 - Restart module
					      * B1 - Re-enumerate, look for modules (self clears)
					      */
#define SCMD_CONTROL_1_RESTART		0x01 /* Mask to perform a restart using CONTROL_1 */
#define SCMD_CONTROL_1_REENUMERATE	0x02 /* Mask to perform a re-enumeration using
					      * CONTROL_1
					      */
/* Remote module I2C bus write / read window */
#define SCMD_REG_REM_ADDR		0x79 /* The slave module I2C address.  This starts at 0x50 */
#define SCMD_REG_REM_OFFSET		0x7A /* Remote module I2C register for write / read */
#define SCMD_REG_REM_DATA_WR		0x7B /* Data staged for write to remote module */
#define SCMD_REG_REM_DATA_RD		0x7C /* Data returned from remote module */
#define SCMD_REG_REM_WRITE		0x7D /* Write REM_DATA_WR to REM_OFFSET on remote module */
#define SCMD_REG_REM_READ		0x7E /* Read from REM_OFFSET into REM_DATA_RD on remote
					      * module
					      */

#define SCMD_LAST_REG			SCMD_REG_REM_READ /* The last register address on a module */
#define SCMD_REG_SIZE			0x7F /* Size of the register space including the holes */
#define SCMD_REMOTE_ADDR_LOW		0x50 /* The first remote I2C addreess */
#define SCMD_REMOTE_ADDR_HIGH		0x5F /* The last remote I2C address */
#define SCMD_HOLE_VALUE			0x55 /* Artificial value on read for a hole register */
#define SCMD_IS_HOLE(r) \
((r >= SCMD_REG_HOLE_1_LOW && r <= SCMD_REG_HOLE_1_HIGH) || \
    (r >= SCMD_REG_HOLE_2_LOW && r <= SCMD_REG_HOLE_2_HIGH))

#define SCMD_MASTER_LOCK_UNLOCKED	0x9B
#define SCMD_USER_LOCK_UNLOCKED		0x5C
#define SCMD_ANY_LOCK_LOCKED		0x00

#endif