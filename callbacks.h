#ifndef __MAIN_H__
#define __CALLBACKS_H__

void on_client_connection(GIOChannel *source);
void on_client_activity(GIOChannel *source, const char *data);
void on_client_disconnection(GIOChannel *source);

#endif  /* __CALLBACKS_H__ */
