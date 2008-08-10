#ifndef __LUA_GLIB__
#define __LUA_GLIB__

#include <glib.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

int luaopen_glib(lua_State *L);

#endif  /* __LUA_GLIB__ */

