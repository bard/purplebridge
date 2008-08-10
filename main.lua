require('server')

function debug(msg)
   print('** (lua): DEBUG: ' .. msg)
   print()
end

function on_client_connection(conn)
   debug('Client connected')
   --sessions[conn] = session_create(conn)
   sess = Session:new(conn)
end

function on_client_activity(conn, data)
   --session_receive(sessions[con])
   sess:receive(data)
end

function on_client_disconnection(conn)
   --session_close(sessions[conn])
   sess:close()
end

-- local protocols = {}
-- for i,name in ipairs(purple.get_protocols()) do
--    table.insert(protocols, name)
-- end
-- debug('found protocol plugins: ' .. table.concat(protocols, ', '))

--purple.signon('prpl-msn', 'milly.tom@hotmail.it', 'potina')

