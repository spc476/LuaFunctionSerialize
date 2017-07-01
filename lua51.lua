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
-- ***************************************************************
--
-- luacheck: ignore 611
--
-- ***************************************************************
--
-- I wanted to be really careful not to pollute the global space, nor did I
-- want to create a location variable to hold the function, only to return
-- it.
--
-- The first function (function(f)) is the Y-combinator, which allows one to
-- create a recursive anonymous function.  We then use it to create our
-- recursive anonymous function that does a rather deep copy of a table.
-- And once created, we call it on the global space.
--
-- Basically, we're doing:
--
--      local Y = function(f) ... end
--      local x = Y(function(self,target,src,label) ... end
--      return x({},_G,"")
--
-- Only without creating the local variables.
--
-- Yes, I'm being cute here.
--
-- ***************************************************************

return ((function(f)
           local function g(...) return f(g,...) end
           return g
         end)(function(self,target,src,label)
                for name,value in pairs(src) do
                  local key = label .. name
                  target[key] = value
                  target[value] = key
                  if type(value) == 'table'
                  and key ~= "_G"
                  and key ~= "package.loaded"
                  and not key:match "_M$" then
                    self(target,value,key .. ".")
                  end
                end
                return target
              end))({},_G,"")
