/*
 * $Id: $
 *
 * TCP Service  -- Handles all socket level issues.
 */

#include <glib.h>
#include <stdio.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string.h>
#include <fcntl.h>

#include "callbacks.h"

/****************************************************************************
 * Forward references
 ***************************************************************************/
gboolean             tcp_new_connection           (GIOChannel     *source,
                                                   GIOCondition   condition,
                                                   gpointer       data);
gboolean             tcp_client_activity          (GIOChannel     *source,
                                                   GIOCondition   condition,
                                                   gpointer       data);
/****************************************************************************
 * Implementation.
 ***************************************************************************/
void
tcp_enable_reuseaddr (gint sock)
{
    gint tmp = 1;
    if (sock < 0)
        return;
    if (setsockopt (sock, SOL_SOCKET, SO_REUSEADDR, (gchar *)&tmp,
                    sizeof (tmp)) == -1)
        perror ("Bah! Bad setsockopt ()\n");
}

void
tcp_enable_nbio (gint fd)
{
    if (fcntl (fd, F_SETOWN, getpid()) == -1)
        perror ("fcntl (F_SETOWN) error\n");
    if (fcntl (fd, F_SETFL, FNDELAY) == -1)
        perror ("fcntl (F_SETFL, FNDELAY\n");
}

void
tcp_socket_init (gint port)
{
    gint                s;
    struct sockaddr_in  addr;
    GIOChannel          *channel;

    g_debug("initializing tcp");

    if (port <= 0)
        return ;

    s = socket (AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (s == -1)
        return;
    tcp_enable_reuseaddr (s);
    memset (&addr, 0, sizeof (addr));
    addr.sin_family       = AF_INET;
    addr.sin_port         = htons ((u_short)port);
    addr.sin_addr.s_addr  = INADDR_ANY;
    if (bind (s, (struct sockaddr *)&addr, sizeof (addr)) == -1) {
        close (s);
        return ;
    } if (listen (s, 5) == -1) {
        close (s);
        return ;
    }
    channel = g_io_channel_unix_new (s);
    g_io_add_watch (channel, G_IO_IN, tcp_new_connection, NULL);
}

/****************************************************************************
 * Callback functions
 ***************************************************************************/
/**
 * tcp_new_connection
 * Will accept a new connection and add the client to the list of clients.
 * actual client communication is handled elsewhere.
 **/
gboolean 
tcp_new_connection (GIOChannel *source, GIOCondition cond, gpointer data)
{
    gint               new;              /* new socket descriptor */
    guint               client;
    GIOChannel         *new_channel;
    struct sockaddr_in client_addr;

    g_debug("new connection");

    if (cond == G_IO_IN) {
        if ( (new = accept (g_io_channel_unix_get_fd (source),
                            (struct sockaddr *)&client_addr, &client)) < 0) {
            g_warning ("Unable to accept new connection.");
            return FALSE;
        }
        new_channel = g_io_channel_unix_new (new);
        g_io_channel_set_encoding(new_channel, NULL, NULL);
        g_io_channel_set_buffered(new_channel, FALSE);
        g_io_add_watch (new_channel, G_IO_IN | G_IO_HUP, tcp_client_activity,
                        NULL);
        on_client_connection(new_channel);
    }
    return TRUE;
}

/**
 * tcp_client_activity
 * Handles input from the clients and passes it off to the parser/dispatcher.
 * This will get the raw data from the socket, make sure there is a NULL
 * terminator, and call the command dispatcher.
 * If the client has disconnected (condition G_IO_HUP), close the channel and remove
 * this callback by returning FALSE.
 **/
gboolean
tcp_client_activity (GIOChannel *source, GIOCondition cond, gpointer data)
{
    gchar buf[1024];
    guint num_read = 0;

    if (cond == G_IO_IN) {
        if (g_io_channel_read (source, buf, sizeof (buf), &num_read) == G_IO_ERROR_NONE) {
            if(num_read == 0) {
                g_warning("Zero chars read.  Connection lost?  Closing channel.\n");
                on_client_disconnection(source);
                g_io_channel_close(source);
                return FALSE;
            } else {
                buf[num_read] = '\0';           /* Make sure its null terminated */
                on_client_activity(source, buf);
            }
        }
    } else if (cond == G_IO_HUP) {
        g_print ("Connection lost.\n");
        on_client_disconnection(source);
        g_io_channel_close(source);
        return FALSE;
    }

    return TRUE;
}

