#include "lpurple.h"


/* Lua-callables */

static int l_get_protocols(lua_State *L) {
	GList *iter;
	int i;

    lua_newtable(L);

	iter = purple_plugins_get_protocols();
	for (i = 1; iter; iter = iter->next) {
		PurplePlugin *plugin = iter->data;
		PurplePluginInfo *info = plugin->info;
		if (info && info->name) {
            lua_pushnumber(L, i++);
            lua_pushstring(L, info->id);
            lua_settable(L, -3);
		}
	}

    return 1;
}

static int l_signon(lua_State *L) {
    const char *prpl = luaL_checkstring(L, 1);
    const char *name = luaL_checkstring(L, 2);
    const char *password = luaL_checkstring(L, 3);
	PurpleAccount *account;
	PurpleSavedStatus *status;

	account = purple_account_new(name, prpl);
	purple_account_set_password(account, password);
	purple_account_set_enabled(account, UI_ID, TRUE);
	status = purple_savedstatus_new(NULL, PURPLE_STATUS_AVAILABLE);
	purple_savedstatus_activate(status);
    
    return 0;
}

static const struct luaL_reg purplelib [] = {
    {"get_protocols", l_get_protocols},
    {"signon", l_signon},
    {NULL, NULL}
};

int luaopen_purple(lua_State *L) {
    luaL_openlib(L, "purple", purplelib, 0);
    return 0;
}

