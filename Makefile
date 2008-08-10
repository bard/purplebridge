# If Lua and libpurple on your system aren't installed with package
# config support, enter their paths manually below.  Remember that
# libpurple depends on libglib2.0.

INC_LUA=$(shell pkg-config lua5.1 --cflags)
LIB_LUA=$(shell pkg-config lua5.1 --libs)

INC_PURPLE=$(shell pkg-config purple --cflags)
LIB_PURPLE=$(shell pkg-config purple --libs)


# No modification should be needed below

CFLAGS=$(INC_LUA) $(INC_PURPLE) -g -O2 -Wall
LDLIBS=$(LIB_LUA) $(LIB_PURPLE)

all: purplebridge base64.so

run: all
	./purplebridge

%.o: %.c
	$(CC) -c $(CFLAGS) $(^) -o $(@)

base64.so: lbase64.o
	$(CC) -o $(@) -shared $(^)

purplebridge: main.o lpurple.o lglib.o tcp_service.o
	$(CC) $(LDLIBS) $(^) -o $(@)

clean:
	rm -f *.o *.so
	rm -f purplebridge

tags:
	find -name '*.[ch]' | etags -

.PHONY: clean all run tags
