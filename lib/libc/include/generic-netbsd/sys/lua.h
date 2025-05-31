/*	$NetBSD: lua.h,v 1.8.48.1 2023/08/09 17:42:01 martin Exp $ */

/*
 * Copyright (c) 2014 by Lourival Vieira Neto <lneto@NetBSD.org>.
 * Copyright (c) 2011, 2013 Marc Balmer <mbalmer@NetBSD.org>.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the Author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef _SYS_LUA_H_
#define _SYS_LUA_H_

#include <sys/param.h>
#include <sys/ioccom.h>

#include <lua.h>		/* for lua_State */

#ifdef _KERNEL
#include <sys/condvar.h>
#include <sys/mutex.h>
#endif

#define MAX_LUA_NAME		16
#define MAX_LUA_DESC		64
#define LUA_MAX_MODNAME		32

struct lua_state_info {
	char	name[MAX_LUA_NAME];
	char	desc[MAX_LUA_DESC];
	bool	user;
};

struct lua_info {
	int num_states;		/* total number of created Lua states */
	struct lua_state_info *states;
};

struct lua_create {
	char	name[MAX_LUA_NAME];
	char	desc[MAX_LUA_DESC];
};

struct lua_require {
	char	state[MAX_LUA_NAME];
	char	module[LUA_MAX_MODNAME];
};

struct lua_load {
	char	state[MAX_LUA_NAME];
	char	path[MAXPATHLEN];
};

#define LUAINFO		_IOWR('l', 0, struct lua_info)

#define LUACREATE	_IOWR('l', 1, struct lua_create)
#define LUADESTROY	_IOWR('l', 2, struct lua_create)

/* 'require' a module in a state */
#define LUAREQUIRE	_IOWR('l', 3, struct lua_require)

/* loading Lua code into a Lua state */
#define LUALOAD		_IOWR('l', 4, struct lua_load)

#ifdef _KERNEL
extern int klua_mod_register(const char *, lua_CFunction);
extern int klua_mod_unregister(const char *);

typedef struct _klua_State {
	lua_State	*L;
	kmutex_t	 ks_lock;
	bool		 ks_user;	/* state created by user (ioctl) */
} klua_State;

extern void klua_lock(klua_State *);
extern void klua_unlock(klua_State *);

extern void klua_close(klua_State *);
extern klua_State *klua_newstate(lua_Alloc, void *, const char *, const char *,
		int);
extern klua_State *kluaL_newstate(const char *, const char *, int);
#endif

#endif /* _SYS_LUA_H_ */