
----------------------------------------------------------------------------
--  slave_proxy.lua - Slave XML-RPC proxy
--
--  Created: Mon Jul 26 11:58:27 2010 (at Intel Research, Pittsburgh)
--  License: BSD, cf. LICENSE file of roslua
--  Copyright  2010  Tim Niemueller [www.niemueller.de]
--             2010  Carnegie Mellon University
--             2010  Intel Research Pittsburgh
----------------------------------------------------------------------------

--- Slave XML-RPC API proxy.
-- This module contains the SlaveProxy class to call methods provided via
-- XML-RPC by ROS slaves.
-- <br /><br />
-- The user should not have to directly interact with the slave. It is used
-- to initiate topic connections and get information about the slave.
-- It can also be used to remotely shutdown a slave.
-- @copyright Tim Niemueller, Carnegie Mellon University, Intel Research Pittsburgh
-- @release Released under BSD license
module("roslua.slave_proxy", package.seeall)

require("xmlrpc")
require("xmlrpc.http")
assert(xmlrpc._VERSION_MAJOR and
       (xmlrpc._VERSION_MAJOR > 1 or
	xmlrpc._VERSION_MAJOR == 1 and xmlrpc._VERSION_MINOR >= 2),
       "You must use version 1.2 or newer of lua-xmlrpc")
require("roslua.xmlrpc_post")

__DEBUG = false

SlaveProxy = { slave_uri = nil, node_name = nil }

--- Constructor.
-- @param slave_uri XML-RPC HTTP slave URI
-- @param node_name name of this node
function SlaveProxy:new(slave_uri, node_name)
   local o = {}
   setmetatable(o, self)
   self.__index = self

   o.slave_uri = slave_uri
   o.node_name = node_name
   o.xmlrpc_post = roslua.xmlrpc_post.XmlRpcPost:new(slave_uri)

   return o
end

-- (internal) execute XML-RPC call
-- Will always prefix the arguments with the caller ID.
-- @param method_name name of the method to execute
-- @param ... Arguments depending on the method call
function SlaveProxy:do_call(method_name, ...)
   local ok, res = xmlrpc.http.call(self.slave_uri,
				    method_name, self.node_name, ...)
   assert(ok, string.format("XML-RPC call %s failed on client: %s", method_name, tostring(res)))
   assert(res[1] == 1, string.format("XML-RPC call %s failed on server: %s",
				     method_name, tostring(res[2])))

   if __DEBUG then
      print(string.format("Ok: %s  Code: %d  Error: %s  arrlen: %i",
			  tostring(ok), tostring(res[1]), tostring(res[2]), #res))
   end

   return res
end


--- Get bus stats.
-- @return bus stats
function SlaveProxy:getBusStats()
   local res = self:do_call("getBusStats")

   return res[3]
end


--- Get slaves master URI.
-- @return slaves master URI
function SlaveProxy:getMasterUri()
   local res = self:do_call("getMasterUri")

   return res[3]
end

--- Shutdown remote node.
-- @param msg shutdown message
function SlaveProxy:shutdown(msg)
   local res = self:do_call("shutdown", msg or "")
end

--- Get PID of remote slave.
-- Can be used to "ping" the remote node.
function SlaveProxy:getPid()
   local res = self:do_call("getPid")

   return res[3]
end

--- Get all subscriptions of remote node.
-- @return list of subscriptions
function SlaveProxy:getSubscriptions()
   local res = self:do_call("getSubscriptions")

   return res[3]
end

--- Get all publications of remote node.
-- @return list of publications
function SlaveProxy:getPublications()
   local res = self:do_call("getPublications")

   return res[3]
end


function SlaveProxy:connection_params()
   local protocols = {}
   local tcpros = {"TCPROS"}
   table.insert(protocols, xmlrpc.newTypedValue(tcpros, xmlrpc.newArray()))
   return xmlrpc.newTypedValue(protocols, xmlrpc.newArray("array"))
end

--- Request a TCPROS connection for a specific topic.
-- @param topic name of topic
-- @return TCPROS communication parameters
function SlaveProxy:requestTopic(topic)
   local res = self:do_call("requestTopic", topic, self:connection_params())

   return res[3]
end


--- Assert that a specific method is currently running.
-- If the method is not running throws an error.
-- @param method name of the method that must run
function SlaveProxy:assert_running_method(method)
   assert(self.xmlrpc_post.request and self.xmlrpc_post.request.method == method,
          method .. " is not currently being executed")
end

--- Start a topic request.
-- This starts a concurrent execution of requestTopic().
-- @param topic topic to request
function SlaveProxy:requestTopic_start(topic)
   return self.xmlrpc_post:start_call("requestTopic", self.node_name,
				      topic, self:connection_params())
end

--- Check if concurrent execution is still busy.
-- @return true if execution is still busy, false otherwise
function SlaveProxy:requestTopic_busy()
   self:assert_running_method("requestTopic")
   return self.xmlrpc_post:running()
end

--- Check if concurrent execution has successfully completed.
-- @return true if execution has succeeded, false otherwise
function SlaveProxy:requestTopic_done()
   self:assert_running_method("requestTopic")
   return self.xmlrpc_post:done()
end

--- Check if concurrent execution has failed.
-- @return true if execution has failed, false otherwise
function SlaveProxy:requestTopic_failed()
   self:assert_running_method("requestTopic")
   return self.xmlrpc_post:failed()
end

--- Result from completed concurrent call.
-- @return result of completed concurrent call
function SlaveProxy:requestTopic_result()
   self:assert_running_method("requestTopic")
   assert(self.xmlrpc_post:done(), "requestTopic not done")
   assert(self.xmlrpc_post.result[1][1] == 1,
	  string.format("XML-RPC call %s failed on server: %s",
			self.xmlrpc_post.request.method,
			tostring(self.xmlrpc_post.result[1][2])))
   return self.xmlrpc_post.result[1][3]
end
