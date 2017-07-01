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

local cbor  = require "org.conman.cbor"
local lua51 = require "lua51"

-- ***********************************************************************

local function throw(pos,...)
  error( { pos = pos , msg = string.format(...) } , 2)
end

-- ***********************************************************************
-- CBOR tag ___LuaFunction (2000)
--      CBORtype(value) == true
--              function is its own upvalue.  The local variable self is
--              is used to denote this state when setting the upvals of
--              the function.
--      CBORtype(value) == UINT
--              Reference to previously defined function
--      CBORtype(value) == ARRAY[3]
--              value[1] == BIN, Lua bytecode
--              value[2] == ARRAY, upvalues for given function
--              value[3] == ARRAY, environment for function
-- ***********************************************************************

local self = {}

cbor.TAG[2000] = function(packet,pos,conv,ref)
  local value,npos,ctype = cbor.decode(packet,pos,conv,ref)
  
  if ctype == "true" then
    return self,npos,"___LuaFunction"
    
  elseif ctype == 'UINT' then
    value = value + 1
    if not ref.___LuaFunction[value] then
      throw(pos,"___LuaFunction: invalid index",value - 1)
    else
      return ref.___LuaFunction[value],npos,"___LuaFunction"
    end
    
  elseif ctype == 'ARRAY' then
    if #value ~= 3 then
      throw(pos,"___LuaFunction: invalid function")
    end
    
    if type(value[1]) ~= 'string' then
      throw(pos,"___LuaFunction: non encoded function")
    end
    
    if type(value[2]) ~= 'table'then
      throw(pos,"___LuaFunction: bad upvalue list")
    end
    
    local f,err = loadstring(value[1])
    if not f then
      throw(pos,"___LuaFunction: %s",err)
    end
    
    table.insert(ref.___LuaFunction,f)
    
    for i,v in ipairs(value[2]) do
      if v == self then v = f end
      debug.setupvalue(f,i,v)
    end
    
    debug.setfenv(f,value[3])
    
    return f,npos,"___LuaFunction"
  else
    throw(pos,"___LuaFunction: wanted UINT or ARRAY, got %s",ctype)
  end
end

-- ***********************************************************************

cbor.TAG[2001] = function(packet,pos,conv,ref)
  local value,npos,ctype = cbor.decode(packet,pos,conv,ref)
  if ctype ~= "TEXT" then
    throw(pos,"___LuaGlobal: wanted TEXT, got %s",ctype)
  else
    return lua51[value],npos,"___LuaGlobal"
  end
end

-- ***********************************************************************

local f = io.open("blob.cbor","rb")
local d = f:read("*a")
f:close()

local ref = { _stringref = {} , _sharedref = {} , ___LuaFunction = {} }
local x   = cbor.decode(d,1,nil,ref)
x({},_G,"")
