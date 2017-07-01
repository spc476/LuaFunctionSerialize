-- ***************************************************************
--
-- Copyright 2017 by Sean Conner.  All Rights Reserved.
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation; either version 3 of the License, or (at your
-- option) any later version.
--
-- This library is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
-- or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
-- License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with this library; if not, see <http://www.gnu.org/licenses/>.
--
-- Comments, questions and criticisms can be sent to: sean@conman.org
--
-- ***************************************************************
-- luacheck: ignore 611

local cbor_c = require "org.conman.cbor_c"
local cbor   = require "org.conman.cbor"
local lua51  = require "lua51"

-- ***********************************************************************

function cbor.TAG.___LuaGlobal(value,sref,stref)
  return cbor_c.encode(0xC0,2001) .. cbor.encode(value,sref,stref)
end

-- ***********************************************************************
-- CBOR tag ___LuaFunction (2000)
--      CBORtype(value) == true
--              function is its own upvalue
--      CBORtype(value) == UINT
--              Reference to previously defined function
--      CBORtype(value) == ARRAY[3]
--              value[1] == BIN, Lua bytecode
--              value[2] == ARRAY, upvalues for given function
--              value[3] == ARRAY or ___LuaGlobal, environment for function
--
-- NOTE: value[3] is right now assumed to be ___LuaGlobal("_G")
--
-- Also, the tag value here are not allocated for this purpose, and may
-- conflict with future extentions.
-- ***********************************************************************

function cbor.TAG.___LuaFunction(f,sref,stref)
  if sref[f] then
    return cbor_c.encode(0xC0,2000)
        .. cbor.TYPE.UINT(sref[f])
  end
  
  table.insert(sref,f)
  sref[f] = #sref - 1
  
  local info = debug.getinfo(f)
  
  local blob = cbor_c.encode(0xC0,2000)
               .. cbor.TYPE.ARRAY(3)
                  .. cbor.TYPE.BIN(string.dump(f))
                  .. cbor.TYPE.ARRAY(info.nups)
                  
  for i = 1 , info.nups do
    local _,v = debug.getupvalue(f,i)
    
    if v == f then
      blob = blob .. cbor_c.encode(0xC0,2000)
                  .. cbor.encode(true)
                  
    elseif lua51[v] then
      blob = blob .. cbor.TAG.___LuaGlobal(lua51[v],sref,stref)
    else
      blob = blob .. cbor.encode(v,sref,stref)
    end
  end
  
  local env = getfenv(f)
  if lua51[env] then
    blob = blob .. cbor.TAG.___LuaGlobal(lua51[env],sref,stref)
  else
    blob = blob .. cbor.TYPE.ARRAY(0)
  end
  
  return blob
end

-- ***********************************************************************

cbor.__ENCODE_MAP['function'] = function(f,sref,stref)
  return cbor.TAG.___LuaFunction(f,sref,stref)
end

-- ***********************************************************************

local fun = (function(f)
               local function g(...) return f(g,...) end
               return g
             end)(function(self,target,src,label)
                    for name,value in pairs(src) do
                      local key = label .. name print(key)
                      target[key] = value
                      target[value] = key
                      
                      if type(value) == 'table'
                      and key ~= "_G"
                      and key ~= "package.loaded"
                      and not key:match("_M$") then
                      
                        self(target,value,key .. ".")
                      end
                      
                    end
                    return target
                  end)
                  
-- ***********************************************************************

local x = cbor.encode(fun,{})
local f = io.open("blob.cbor","wb")
f:write(x)
f:close()
