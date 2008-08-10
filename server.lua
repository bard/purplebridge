require 'lxp'
require 'base64'

-- Utilities
----------------------------------------------------------------------

local function dbg(msg)
   print(msg)
   print()
end

local function warn(msg)
   print('*** WARNING ***: ' .. msg)
   print()
end

local function get_child(el, tag)
   for i, child in ipairs(el) do
      if child.tag == tag then
         return child
      end
   end
end

local function has_child(el, tag)
   return get_child(el, tag)
end

local function ser(el)
   if not el.tag then
      return el
   end

   local ins = table.insert
   local s = {}
   ins(s, '<' .. el.tag)

   if el.attr then
      for k,v in pairs(el.attr) do
         if type(k) ~= 'number' then
            ins(s, ' ' .. k .. '="' .. v .. '"')
         end
      end
   end

   if table.getn(el) > 0 then
      ins(s, '>')

      for i,child in ipairs(el) do
         ins(s, ser(child))
      end

      ins(s, '</' .. el.tag .. '>')
   else
      ins(s, '/>')
   end

   return table.concat(s)
end


----------------------------------------------------------------------
-- Raw I/O

local function to_client(thing)
   local data
   if type(thing) == 'table' then
      data = ser(thing)
   else
      data = thing
   end

   dbg('(to_client) BRIDGE -> CLIENT: ' .. data)
end

----------------------------------------------------------------------
-- Us -> Purple



----------------------------------------------------------------------
-- Purple -> XMPP

local function roster_retrieved(el, contacts)
   dbg('(roster_retrieved) PURPLE -> BRIDGE: [contacts]')

   local response = {
      tag = 'iq',
      attr = { type = 'result', id = el.attr.id }
   }

   for i,contact in ipairs(contacts) do
      table.insert(
         response, {
            tag = 'item',
            attr = {
               jid = contact,
               subscription = 'both'
            }
         })
   end

   to_client(response)
end

local function got_auth_result(el, error)
   if not error then
      to_client([[<success xmlns="urn:ietf:params:xml:ns:xmpp-sasl"/>]])
   end
end


----------------------------------------------------------------------
-- Client -> Us

local function stream(attr)
   local attrvals = {}
   for k,v in pairs(attr) do
      if type(k)~= 'number' then table.insert(attrvals, k .. ': ' .. v) end
   end

   dbg('(stream) CLIENT -> BRIDGE: <stream> (' .. table.concat(attrvals, ', ') ..')')

   if attr.to == 'msn' then
      to_client('<stream:features xmlns:stream="http://etherx.jabber.org/streams"><mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl">' ..
                '<mechanism>PLAIN</mechanism></mechanisms>' ..
                '</stream:features>')
   else
      warn('foreign network not recognized (' .. attr.to .. ')')
   end
end

local function message(el)
   -- does not handle groupchat...
   if el.attr.type == 'chat' or el.attr.type == 'normal' then
      purple.send_message(el)
   end
end

local function iq(el)
   if el.attr.type == 'get' and has_child(el, 'jabber:iq:roster|query') then
      purple.retrieve_roster(el, roster_retrieved)
   end
end

local function presence(el)
   if not el.attr.type then
      purple.set_status(el)
   elseif has_child('http://jabber.org/protocol/muc|user') then
      purple.join_room(el)
   elseif el.attr.type == 'subscribe' then
      purple.subscribe_to_presence(el)
   elseif el.attr.type == 'unsubscribe' then
      purple.unsubscribe_from_presence(el)
   end
end

local function auth(el)
   local authstr, address, user, pwd, protocol

   assert(el.attr.mechanism == 'PLAIN')

   authstr = base64.decode(el[1])
   address, user, pwd = authstr:match("([^%z]+)%z([^%z]+)%z([^%z]+)")
   protocol = address:match('@(.+)')
   purple.signon('prpl-' .. protocol, user:gsub('%%', '@'), pwd)
end

function on_network_signon(username, protocol)
   dbg('(on_network_signon) ' .. username .. ' logged on on ' .. protocol)
end

local function element(el)
   local data = ser(el)
   dbg('(element) CLIENT -> BRIDGE: ' .. data)

   if el.tag == 'jabber:client|message' then
      message(el)
   elseif el.tag == 'jabber:client|iq' then
      iq(el)
   elseif el.tag == 'jabber:client|presence' then
      presence(el)
   elseif el.tag == 'urn:ietf:params:xml:ns:xmpp-sasl|auth' then
      auth(el)
   end
end


-- XMPP session
----------------------------------------------------------------------

Session = {}

function Session:stream(attr)
   -- local attrvals = {}
   -- for k,v in pairs(attr) do
   --    if type(k)~= 'number' then table.insert(attrvals, k .. ': ' .. v) end
   -- end

   -- dbg('CLIENT -> BRIDGE: <stream> (' .. table.concat(attrvals, ', ') ..')')

   if attr.to == 'msn' then
      self:to_client('<stream:features xmlns:stream="http://etherx.jabber.org/streams"><mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl">' ..
                '<mechanism>PLAIN</mechanism></mechanisms>' ..
                '</stream:features>')
   else
      warn('foreign network not recognized (' .. attr.to .. ')')
   end
end

function Session:to_client(thing)
   local data
   if type(thing) == 'table' then
      data = ser(thing)
   else
      data = thing
   end

   glib.io_channel_write(self.conn, data)
   dbg('(Session:to_client) BRIDGE -> CLIENT: ' .. data)
end

function Session:new(conn)
   o = {}
   setmetatable(o, self)
   self.__index = self
   self.conn = conn

   local stack = {{}}

   local function start_element(p, tag, attr)
      if tag == 'http://etherx.jabber.org/streams|stream' then
         self:stream(attr)
         return
      end

      table.insert(stack, {tag = tag, attr = attr})
   end

   local function end_element(p, tag)
      if tag == 'http://etherx.jabber.org/streams|stream' then
         return
      end

      local el = table.remove(stack)
      assert(el.tag == tag)
      local level = table.getn(stack)
      table.insert(stack[level], el)

      if level == 1 then
         element(stack[1][1])
         stack = {{}}
      end
   end

   local function character_data(p, txt)
      local el = stack[table.getn(stack)]
      local n = table.getn(el)
      local level = table.getn(stack)
      if level == 1 then
         return
      end

      if type(el[n]) == "string" then
         el[n] = el[n] .. txt
      else
         table.insert(el, txt)
      end
   end

   self.parser = lxp.new({ StartElement  = start_element,
                           EndElement    = end_element,
                           CharacterData = character_data }, '|')
   return self
end

function Session:receive(data)
   dbg('(Session:receive) CLIENT -> BRIDGE: ' .. data)
   self.parser:parse(data)
end

function Session:close()
   self.parser:close()
end


-- Test
----------------------------------------------------------------------

-- command line if not called as library
if (arg ~= nil) then

   purple = {}
   function purple.signon(user, pwd, callback)
      dbg('PURPLE <- BRIDGE: signon("' .. user .. '", "' .. pwd .. '")')
      callback(nil)
   end

   function purple.retrieve_roster(el, callback)
      dbg('PURPLE <- BRIDGE: retrieve_roster()')
      callback(el, {'someone', 'sometwo'})
   end

   function purple.set_status(el)
      dbg('PURPLE <- BRIDGE: set_status()')
   end

   function purple.subscribe_to_presence(el)
      dbg('PURPLE <- BRIDGE: subscribe_to_presence() of ' .. el.attr.to)
   end

   function purple.send_message(el)
      local body = get_child(el, 'jabber:client|body')
      local content = body[1]

      dbg('PURPLE <- BRIDGE: send_message() to ' .. el.attr.to ..
          ' with content "' .. content .. '"...')
   end

   local s = Session:new()
   print('------------------------------------------------------------')
   s:receive([[<?xml version='1.0'?>]])
   s:receive([[<stream:stream xmlns='jabber:client' ]])
   s:receive([[xmlns:stream='http://etherx.jabber.org/streams' to='msn' xml:lang='en' version='1.0'>]])
   s:receive([[<auth mechanism="PLAIN" xmlns="urn:ietf:params:xml:ns:xmpp-sasl">dXNlciVob3RtYWlsLmNvbQBzZWNyZXQ=</auth>]])
   s:receive([[<presence/>]])
   s:receive([[<iq type='get' id='rost1'><query xmlns='jabber:iq:roster'/></iq>]])
   s:receive([[<message to='me@here'><body>hello</body></message>]])
   s:receive([[<message to='someone@there' type='chat'><body>again</body></message>]])
   s:receive([[</stream:stream>]])
   s:close()
else
  module('server',package.seeall)
end
