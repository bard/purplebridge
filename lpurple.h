#ifndef __LUA_PURPLE__
#define __LUA_PURPLE__

#include <purple.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "defines.h"

int luaopen_purple(lua_State *L);

#endif  /* __LUA_PURPLE__ */

