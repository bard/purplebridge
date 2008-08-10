#include "lglib.h"


/* Lua-callables */

static int l_g_io_channel_write(lua_State *L) {
    guint         num_written = 0;
    unsigned int  datalen     = 0;
    GIOChannel   *channel;
    const char   *data;

    channel = (GIOChannel *) lua_touserdata(L, 1);
    data = luaL_checklstring(L, 2, &datalen);

    g_io_channel_write(channel, data, datalen, &num_written);
    //g_io_channel_flush(source, &err);
    return 0;
}


static const struct luaL_reg glib [] = {
    {"io_channel_write", l_g_io_channel_write},
    {NULL, NULL}
};

int luaopen_glib(lua_State *L) {
    luaL_openlib(L, "glib", glib, 0);
    return 0;
}

