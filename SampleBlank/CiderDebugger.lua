
--v1.4
-----------------------------------------------------------------------------------------
--
-- main.lua
--
-----------------------------------------------------------------------------------------


-- Your code here
local socket = require "socket"
local udpSocket = socket.udp()
udpSocket:setsockname("localhost",51248)
udpSocket:setpeername("localhost",51249)
udpSocket:settimeout(0)
--[[
CoronaCider Debugger Library v 1.0
Author: M.Y. Developers
Copyright (C) 2012 M.Y. Developers All Rights Reserved
Support: mydevelopergames@gmail.com
Website: http://www.mydevelopersgames.com/
License: Many hours of genuine hard work have gone into this project and we kindly ask you not to redistribute or illegally sell this package.
We are constantly developing this software to provide you with a better development experience and any suggestions are welcome. Thanks for you support.

-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
-- DEALINGS IN THE SOFTWARE.
--]]


local function requireDKJson()
    local always_try_using_lpeg = true
-- global dependencies:
local pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset =
      pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset
local error, require, pcall = error, require, pcall 
local floor, huge = math.floor, math.huge
local strrep, gsub, strsub, strbyte, strchar, strfind, strlen, strformat =
      string.rep, string.gsub, string.sub, string.byte, string.char,
      string.find, string.len, string.format
local concat = table.concat

if _VERSION == 'Lua 5.1' then
  local function noglobals (s,k,v) error ("global access: " .. k, 2) end
  setfenv (1, setmetatable ({}, { __index = noglobals, __newindex = noglobals }))
end
local _ENV = nil -- blocking globals in Lua 5.2

local json = { version = "dkjson 2.1" }

pcall (function()
  -- Enable access to blocked metatables.
  -- Don't worry, this module doesn't change anything in them.
  local debmeta = require "debug".getmetatable
  if debmeta then getmetatable = debmeta end
end)

json.null = setmetatable ({}, {
  __tojson = function () return "null" end
})

local function isarray (tbl)
  local max, n, arraylen = 0, 0, 0
  for k,v in pairs (tbl) do
    if k == 'n' and type(v) == 'number' then
      arraylen = v
      if v > max then
        max = v
      end
    else
      if type(k) ~= 'number' or k < 1 or floor(k) ~= k then
        return false
      end
      if k > max then
        max = k
      end
      n = n + 1
    end
  end
  if max > 10 and max > arraylen and max > n * 2 then
    return false -- don't create an array with too many holes
  end
  return true, max
end

local escapecodes = {
  ["\""] = "\\\"", ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
  ["\n"] = "\\n",  ["\r"] = "\\r",  ["\t"] = "\\t"
}

local function escapeutf8 (uchar)
  local value = escapecodes[uchar]
  if value then
    return value
  end
  local a, b, c, d = strbyte (uchar, 1, 4)
  a, b, c, d = a or 0, b or 0, c or 0, d or 0
  if a <= 0x7f then
    value = a
  elseif 0xc0 <= a and a <= 0xdf and b >= 0x80 then
    value = (a - 0xc0) * 0x40 + b - 0x80
  elseif 0xe0 <= a and a <= 0xef and b >= 0x80 and c >= 0x80 then
    value = ((a - 0xe0) * 0x40 + b - 0x80) * 0x40 + c - 0x80
  elseif 0xf0 <= a and a <= 0xf7 and b >= 0x80 and c >= 0x80 and d >= 0x80 then
    value = (((a - 0xf0) * 0x40 + b - 0x80) * 0x40 + c - 0x80) * 0x40 + d - 0x80
  else
    return ""
  end
  if value <= 0xffff then
    return strformat ("\\u%.4x", value)
  elseif value <= 0x10ffff then
    -- encode as UTF-16 surrogate pair
    value = value - 0x10000
    local highsur, lowsur = 0xD800 + floor (value/0x400), 0xDC00 + (value % 0x400)
    return strformat ("\\u%.4x\\u%.4x", highsur, lowsur)
  else
    return ""
  end
end

local function fsub (str, pattern, repl)
  -- gsub always builds a new string in a buffer, even when no match
  -- exists. First using find should be more efficient when most strings
  -- don't contain the pattern.
  if strfind (str, pattern) then
    return gsub (str, pattern, repl)
  else
    return str
  end
end

local function quotestring (value)
  -- based on the regexp "escapable" in https://github.com/douglascrockford/JSON-js
  value = fsub (value, "[%z\1-\31\"\\\127]", escapeutf8)
  if strfind (value, "[\194\216\220\225\226\239]") then
    value = fsub (value, "\194[\128-\159\173]", escapeutf8)
    value = fsub (value, "\216[\128-\132]", escapeutf8)
    value = fsub (value, "\220\143", escapeutf8)
    value = fsub (value, "\225\158[\180\181]", escapeutf8)
    value = fsub (value, "\226\128[\140-\143\168\175]", escapeutf8)
    value = fsub (value, "\226\129[\160-\175]", escapeutf8)
    value = fsub (value, "\239\187\191", escapeutf8)
    value = fsub (value, "\239\191[\176\191]", escapeutf8)
  end
  return "\"" .. value .. "\""
end
json.quotestring = quotestring

local function addnewline2 (level, buffer, buflen)
  buffer[buflen+1] = "\n"
  buffer[buflen+2] = strrep ("  ", level)
  buflen = buflen + 2
  return buflen
end

function json.addnewline (state)
  if state.indent then
    state.bufferlen = addnewline2 (state.level or 0,
                           state.buffer, state.bufferlen or #(state.buffer))
  end
end

local encode2 -- forward declaration

local function addpair (key, value, prev, indent, level, buffer, buflen, tables, globalorder)
  local kt = type (key)
  if kt ~= 'string' and kt ~= 'number' then
    return nil, "type '" .. kt .. "' is not supported as a key by JSON."
  end
  if prev then
    buflen = buflen + 1
    buffer[buflen] = ","
  end
  if indent then
    buflen = addnewline2 (level, buffer, buflen)
  end
  buffer[buflen+1] = quotestring (key)
  buffer[buflen+2] = ":"
  return encode2 (value, indent, level, buffer, buflen + 2, tables, globalorder)
end

encode2 = function (value, indent, level, buffer, buflen, tables, globalorder)
  local valtype = type (value)
  local valmeta = getmetatable (value)
  valmeta = type (valmeta) == 'table' and valmeta -- only tables
  local valtojson = valmeta and valmeta.__tojson
  if valtojson then
    if tables[value] then
      return nil, "reference cycle"
    end
    tables[value] = true
    local state = {
        indent = indent, level = level, buffer = buffer,
        bufferlen = buflen, tables = tables, keyorder = globalorder
    }
    local ret, msg = valtojson (value, state)
    if not ret then return nil, msg end
    tables[value] = nil
    buflen = state.bufferlen
    if type (ret) == 'string' then
      buflen = buflen + 1
      buffer[buflen] = ret
    end
  elseif value == nil then
    buflen = buflen + 1
    buffer[buflen] = "null"
  elseif valtype == 'number' then
    local s
    if value ~= value or value >= huge or -value >= huge then
      -- This is the behaviour of the original JSON implementation.
      s = "null"
    else
      s = tostring (value)
    end
    buflen = buflen + 1
    buffer[buflen] = s
  elseif valtype == 'boolean' then
    buflen = buflen + 1
    buffer[buflen] = value and "true" or "false"
  elseif valtype == 'string' then
    buflen = buflen + 1
    buffer[buflen] = quotestring (value)
  elseif valtype == 'table' then
    if tables[value] then
      return nil, "reference cycle"
    end
    tables[value] = true
    level = level + 1
    local metatype = valmeta and valmeta.__jsontype
    local isa, n
    if metatype == 'array' then
      isa = true
      n = value.n or #value
    elseif metatype == 'object' then
      isa = false
    else
      isa, n = isarray (value)
    end
    local msg
    if isa then -- JSON array
      buflen = buflen + 1
      buffer[buflen] = "["
      for i = 1, n do
        buflen, msg = encode2 (value[i], indent, level, buffer, buflen, tables, globalorder)
        if not buflen then return nil, msg end
        if i < n then
          buflen = buflen + 1
          buffer[buflen] = ","
        end
      end
      buflen = buflen + 1
      buffer[buflen] = "]"
    else -- JSON object
      local prev = false
      buflen = buflen + 1
      buffer[buflen] = "{"
      local order = valmeta and valmeta.__jsonorder or globalorder
      if order then
        local used = {}
        n = #order
        for i = 1, n do
          local k = order[i]
          local v = value[k]
          if v then
            used[k] = true
            buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder)
            prev = true -- add a seperator before the next element
          end
        end
        for k,v in pairs (value) do
          if not used[k] then
            buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder)
            if not buflen then return nil, msg end
            prev = true -- add a seperator before the next element
          end
        end
      else -- unordered
        for k,v in pairs (value) do
          buflen, msg = addpair (k, v, prev, indent, level, buffer, buflen, tables, globalorder)
          if not buflen then return nil, msg end
          prev = true -- add a seperator before the next element
        end
      end
      if indent then
        buflen = addnewline2 (level - 1, buffer, buflen)
      end
      buflen = buflen + 1
      buffer[buflen] = "}"
    end
    tables[value] = nil
  else
    return nil, "type '" .. valtype .. "' is not supported by JSON."
  end
  return buflen
end

function json.encode (value, state)
  state = state or {}
  local oldbuffer = state.buffer
  local buffer = oldbuffer or {}
  local ret, msg = encode2 (value, state.indent, state.level or 0,
                   buffer, state.bufferlen or 0, state.tables or {}, state.keyorder)
  if not ret then
    error (msg, 2)
  elseif oldbuffer then
    state.bufferlen = ret
    return true
  else
    return concat (buffer)
  end
end

local function loc (str, where)
  local line, pos, linepos = 1, 1, 1
  while true do
    pos = strfind (str, "\n", pos, true)
    if pos and pos < where then
      line = line + 1
      linepos = pos
      pos = pos + 1
    else
      break
    end
  end
  return "line " .. line .. ", column " .. (where - linepos)
end

local function unterminated (str, what, where)
  return nil, strlen (str) + 1, "unterminated " .. what .. " at " .. loc (str, where)
end

local function scanwhite (str, pos)
  while true do
    pos = strfind (str, "%S", pos)
    if not pos then return nil end
    if strsub (str, pos, pos + 2) == "\239\187\191" then
      -- UTF-8 Byte Order Mark
      pos = pos + 3
    else
      return pos
    end
  end
end

local escapechars = {
  ["\""] = "\"", ["\\"] = "\\", ["/"] = "/", ["b"] = "\b", ["f"] = "\f",
  ["n"] = "\n", ["r"] = "\r", ["t"] = "\t"
}

local function unichar (value)
  if value < 0 then
    return nil
  elseif value <= 0x007f then
    return strchar (value)
  elseif value <= 0x07ff then
    return strchar (0xc0 + floor(value/0x40),
                    0x80 + (floor(value) % 0x40))
  elseif value <= 0xffff then
    return strchar (0xe0 + floor(value/0x1000),
                    0x80 + (floor(value/0x40) % 0x40),
                    0x80 + (floor(value) % 0x40))
  elseif value <= 0x10ffff then
    return strchar (0xf0 + floor(value/0x40000),
                    0x80 + (floor(value/0x1000) % 0x40),
                    0x80 + (floor(value/0x40) % 0x40),
                    0x80 + (floor(value) % 0x40))
  else
    return nil
  end
end

local function scanstring (str, pos)
  local lastpos = pos + 1
  local buffer, n = {}, 0
  while true do
    local nextpos = strfind (str, "[\"\\]", lastpos)
    if not nextpos then
      return unterminated (str, "string", pos)
    end
    if nextpos > lastpos then
      n = n + 1
      buffer[n] = strsub (str, lastpos, nextpos - 1)
    end
    if strsub (str, nextpos, nextpos) == "\"" then
      lastpos = nextpos + 1
      break
    else
      local escchar = strsub (str, nextpos + 1, nextpos + 1)
      local value
      if escchar == "u" then
        value = tonumber (strsub (str, nextpos + 2, nextpos + 5), 16)
        if value then
          local value2
          if 0xD800 <= value and value <= 0xDBff then
            -- we have the high surrogate of UTF-16. Check if there is a
            -- low surrogate escaped nearby to combine them.
            if strsub (str, nextpos + 6, nextpos + 7) == "\\u" then
              value2 = tonumber (strsub (str, nextpos + 8, nextpos + 11), 16)
              if value2 and 0xDC00 <= value2 and value2 <= 0xDFFF then
                value = (value - 0xD800)  * 0x400 + (value2 - 0xDC00) + 0x10000
              else
                value2 = nil -- in case it was out of range for a low surrogate
              end
            end
          end
          value = value and unichar (value)
          if value then
            if value2 then
              lastpos = nextpos + 12
            else
              lastpos = nextpos + 6
            end
          end
        end
      end
      if not value then
        value = escapechars[escchar] or escchar
        lastpos = nextpos + 2
      end
      n = n + 1
      buffer[n] = value
    end
  end
  if n == 1 then
    return buffer[1], lastpos
  elseif n > 1 then
    return concat (buffer), lastpos
  else
    return "", lastpos
  end
end

local scanvalue -- forward declaration

local function scantable (what, closechar, str, startpos, nullval, objectmeta, arraymeta)
  local len = strlen (str)
  local tbl, n = {}, 0
  local pos = startpos + 1
  if what == 'object' then
    setmetatable (tbl, objectmeta)
  else
    setmetatable (tbl, arraymeta)
  end
  while true do
    pos = scanwhite (str, pos)
    if not pos then return unterminated (str, what, startpos) end
    local char = strsub (str, pos, pos)
    if char == closechar then
      return tbl, pos + 1
    end
    local val1, err
    val1, pos, err = scanvalue (str, pos, nullval, objectmeta, arraymeta)
    if err then return nil, pos, err end
    pos = scanwhite (str, pos)
    if not pos then return unterminated (str, what, startpos) end
    char = strsub (str, pos, pos)
    if char == ":" then
      if val1 == nil then
        return nil, pos, "cannot use nil as table index (at " .. loc (str, pos) .. ")"
      end
      pos = scanwhite (str, pos + 1)
      if not pos then return unterminated (str, what, startpos) end
      local val2
      val2, pos, err = scanvalue (str, pos, nullval, objectmeta, arraymeta)
      if err then return nil, pos, err end
      tbl[val1] = val2
      pos = scanwhite (str, pos)
      if not pos then return unterminated (str, what, startpos) end
      char = strsub (str, pos, pos)
    else
      n = n + 1
      tbl[n] = val1
    end
    if char == "," then
      pos = pos + 1
    end
  end
end

scanvalue = function (str, pos, nullval, objectmeta, arraymeta)
  pos = pos or 1
  pos = scanwhite (str, pos)
  if not pos then
    return nil, strlen (str) + 1, "no valid JSON value (reached the end)"
  end
  local char = strsub (str, pos, pos)
  if char == "{" then
    return scantable ('object', "}", str, pos, nullval, objectmeta, arraymeta)
  elseif char == "[" then
    return scantable ('array', "]", str, pos, nullval, objectmeta, arraymeta)
  elseif char == "\"" then
    return scanstring (str, pos)
  else
    local pstart, pend = strfind (str, "^%-?[%d%.]+[eE]?[%+%-]?%d*", pos)
    if pstart then
      local number = tonumber (strsub (str, pstart, pend))
      if number then
        return number, pend + 1
      end
    end
    pstart, pend = strfind (str, "^%a%w*", pos)
    if pstart then
      local name = strsub (str, pstart, pend)
      if name == "true" then
        return true, pend + 1
      elseif name == "false" then
        return false, pend + 1
      elseif name == "null" then
        return nullval, pend + 1
      end
    end
    return nil, pos, "no valid JSON value at " .. loc (str, pos)
  end
end

function json.decode (str, pos, nullval, objectmeta, arraymeta)
  objectmeta = objectmeta or {__jsontype = 'object'}
  arraymeta = arraymeta or {__jsontype = 'array'}
  return scanvalue (str, pos, nullval, objectmeta, arraymeta)
end

function json.use_lpeg ()
  local g = require ("lpeg")
  local pegmatch = g.match
  local P, S, R, V = g.P, g.S, g.R, g.V

  local SpecialChars = (R"\0\31" + S"\"\\\127" +
    P"\194" * (R"\128\159" + P"\173") +
    P"\216" * R"\128\132" +
    P"\220\132" +
    P"\225\158" * S"\180\181" +
    P"\226\128" * (R"\140\143" + S"\168\175") +
    P"\226\129" * R"\160\175" +
    P"\239\187\191" +
    P"\229\191" + R"\176\191") / escapeutf8

  local QuoteStr = g.Cs (g.Cc "\"" * (SpecialChars + 1)^0 * g.Cc "\"")

  quotestring = function (str)
    return pegmatch (QuoteStr, str)
  end
  json.quotestring = quotestring

  local function ErrorCall (str, pos, msg, state)
    if not state.msg then
      state.msg = msg .. " at " .. loc (str, pos)
      state.pos = pos
    end
    return false
  end

  local function Err (msg)
    return g.Cmt (g.Cc (msg) * g.Carg (2), ErrorCall)
  end

  local Space = (S" \n\r\t" + P"\239\187\191")^0

  local PlainChar = 1 - S"\"\\\n\r"
  local EscapeSequence = (P"\\" * g.C (S"\"\\/bfnrt" + Err "unsupported escape sequence")) / escapechars
  local HexDigit = R("09", "af", "AF")
  local function UTF16Surrogate (match, pos, high, low)
    high, low = tonumber (high, 16), tonumber (low, 16)
    if 0xD800 <= high and high <= 0xDBff and 0xDC00 <= low and low <= 0xDFFF then
      return true, unichar ((high - 0xD800)  * 0x400 + (low - 0xDC00) + 0x10000)
    else
      return false
    end
  end
  local function UTF16BMP (hex)
    return unichar (tonumber (hex, 16))
  end
  local U16Sequence = (P"\\u" * g.C (HexDigit * HexDigit * HexDigit * HexDigit))
  local UnicodeEscape = g.Cmt (U16Sequence * U16Sequence, UTF16Surrogate) + U16Sequence/UTF16BMP
  local Char = UnicodeEscape + EscapeSequence + PlainChar
  local String = P"\"" * g.Cs (Char ^ 0) * (P"\"" + Err "unterminated string")
  local Integer = P"-"^(-1) * (P"0" + (R"19" * R"09"^0))
  local Fractal = P"." * R"09"^0
  local Exponent = (S"eE") * (S"+-")^(-1) * R"09"^1
  local Number = (Integer * Fractal^(-1) * Exponent^(-1))/tonumber
  local Constant = P"true" * g.Cc (true) + P"false" * g.Cc (false) + P"null" * g.Carg (1)
  local SimpleValue = Number + String + Constant
  local ArrayContent, ObjectContent

  -- The functions parsearray and parseobject parse only a single value/pair
  -- at a time and store them directly to avoid hitting the LPeg limits.
  local function parsearray (str, pos, nullval, state)
    local obj, cont
    local npos
    local t, nt = {}, 0
    repeat
      obj, cont, npos = pegmatch (ArrayContent, str, pos, nullval, state)
      if not npos then break end
      pos = npos
      nt = nt + 1
      t[nt] = obj
    until cont == 'last'
    return pos, setmetatable (t, state.arraymeta)
  end

  local function parseobject (str, pos, nullval, state)
    local obj, key, cont
    local npos
    local t = {}
    repeat
      key, obj, cont, npos = pegmatch (ObjectContent, str, pos, nullval, state)
      if not npos then break end
      pos = npos
      t[key] = obj
    until cont == 'last'
    return pos, setmetatable (t, state.objectmeta)
  end

  local Array = P"[" * g.Cmt (g.Carg(1) * g.Carg(2), parsearray) * Space * (P"]" + Err "']' expected")
  local Object = P"{" * g.Cmt (g.Carg(1) * g.Carg(2), parseobject) * Space * (P"}" + Err "'}' expected")
  local Value = Space * (Array + Object + SimpleValue)
  local ExpectedValue = Value + Space * Err "value expected"
  ArrayContent = Value * Space * (P"," * g.Cc'cont' + g.Cc'last') * g.Cp()
  local Pair = g.Cg (Space * String * Space * (P":" + Err "colon expected") * ExpectedValue)
  ObjectContent = Pair * Space * (P"," * g.Cc'cont' + g.Cc'last') * g.Cp()
  local DecodeValue = ExpectedValue * g.Cp ()

  function json.decode (str, pos, nullval, objectmeta, arraymeta)
    local state = {
      objectmeta = objectmeta or {__jsontype = 'object'},
      arraymeta = arraymeta or {__jsontype = 'array'}
    }
    local obj, retpos = pegmatch (DecodeValue, str, pos, nullval, state)
    if state.msg then
      return nil, state.pos, state.msg
    else
      return obj, retpos
    end
  end

  -- use this function only once:
  json.use_lpeg = function () return json end

  json.using_lpeg = true

  return json -- so you can get the module using json = require "dkjson".use_lpeg()
end

if always_try_using_lpeg then
  pcall (json.use_lpeg)
end

return json    
    
end


local json = requireDKJson()
local jsonNull = "nil"
if(type(json.null)=="function") then
    jsonNull = json.null()
elseif (json.Null) then
    jsonNull = json.Null
end 
local CIDER_DIR = ".cider/"
local toNetbeansFile
local pathToNetbeansFile = CIDER_DIR.."fromCorona.cider"
local fromNetbeansFile
local pathFromNetbeansFile = CIDER_DIR.."toCorona.cider"
local startDebuggerMessage = {type = "s"};
local statusMessage
local previousLine, previousFile
local Root = {} --this is for variable dumps
local globalsBlacklist = {}
local breakpoints = {}
local breakpointLines = {}
local runToCursorKey = nil
local runToCursorKeyLine = nil
local logfile
local logEverything = true
local snapshotCounter = 0
local snapshotInterval = -10
local maxSize = 2000
local fileFilters = {}
local lineBlacklist = {}
local myStack =  {}
local stackIndex = 0;
local varDumpFile, pathToVar;
local stackDumpFile, pathToStack;
local startupMode = "require"
--override display methods so warnings are thrown
if(CiderRunMode==nil) then
    CiderRunMode = {};
end

if(CiderRunMode.assertImage) then
    local ov = {"newImage", "newImageRect",}
    local displayFunc = {}
    for i,v in pairs(ov) do
        local nativeF = display[v];
        display[v] = function(...)       
            return assert(nativeF(...), "display."..v.." assertion failed, check filename")        
        end   
        
    end
end


--Dont get globals already here
for i,v in pairs(_G) do
    globalsBlacklist[v] = true --dont profile corona stuff
end



local nativePrint = print
local nativeError = error
local function sendConsoleMessage(...)
    --also send via udp to cider
    --we must break up this message into parts so that it does not get truncated
    local message = {}
    message.type = "pr"
    local str = ""
    for i=1,arg.n do
        str = str..tostring(arg[i]).."\t"
    end
    message.str = str
    local messageString = json.encode(message)
    if(messageString:len()>maxSize) then
        while(messageString:len()>maxSize) do				
            local part = messageString:sub(1,maxSize)
            message = {}
            message.type = "ms"
            message.value = part			
            udpSocket:send(json.encode(message))
            messageString = messageString:sub(maxSize+1)
        end
        message = {}
        message.type = "me"
        message.value = messageString			
        udpSocket:send(json.encode(message))				
    else
        
        udpSocket:send(messageString)	
    end	
end
local function debugPrint(...)
    nativePrint(...)
    sendConsoleMessage(...)
end
print = debugPrint
local function debugError(...)
    nativeError(...)
    sendConsoleMessage(...)
    
end

error = debugError
--this will block the program initially and wait for netbeans connection

local varRefTable = {} --holds ref to all discovered vars, must remove or leak.
local function globalsDump()
    
    local globalsVars = {}
    for i,globalv in pairs(_G) do
        
        if(globalsBlacklist[globalv]==nil) then
            globalsVars[i] = globalv
        end
    end		
    --return serializeDump(globalsVars)
    return globalsVars
end
local tostring = tostring
local serializeQueue = {}
local queueIndex = 1;
local maxqueueIndex = 100;
local function serializeDump(tab, tables)--mirrors table and removes functions, userdata, and tries to identify type\
    if(tables == nil) then
        tables = {}
    end
    if(tab[".CIDERPath"]==nil) then
        tab[".CIDERPath"] = "root";
    end
    while(tab) do
        local tabKey = tostring(tab)
        varRefTable[tabKey] = tab
        if(tab == _G) then
            --dealing with global so filter the blacklist and proxy this but leave refernces to global
            tab = globalsDump()
        end
        --tab must be type table
        
        
        if(tables[tabKey] == nil) then
            local newTab = {}
            newTab[".myRef"] = tabKey
            if(tab._class and tab.x and tab.y and tab.rotation and tab.alpha) then            
                --in a displayGroup
                newTab[".isDisplayObject"] = true
                newTab.x, newTab.y, newTab.rotation, newTab.alpha, newTab.width, newTab.height, newTab.isVisible, newTab.xReference, newTab.yReference, newTab.xScale, newTab.yScale=
                tab.x,tab.y,tab.rotation,tab.alpha,tab.width,tab.height,tab.isVisible, tab.xReference, tab.yReference, tab.xScale, tab.yScale
                --also add the custom data
                if(tab.numChildren) then
                    --in a display object
                    newTab.numChildren = tab.numChildren;	
                    newTab[".isDisplayGroup"] = true
                else
                    
                end					
            end
            
            
            tables[tabKey] = newTab
            --traverse through table and add values
            for i,v in pairs(tab) do		
                local typev = type(v)
                
                if(typev=="string" or type(v)=="boolean" or type(v)=="number" ) then
                    newTab[i] = v;			
                elseif(typev=="table" ) then			
                    --local tabKey = tostring(v)
                    newTab[i] = {}
                    newTab[i][".isCiderRef"] = tostring(v);--save the reference of v
                    
                    if(tables[tostring(v)]==nil) then		--check if we have serialized this table or not			
                        --check if this is a display object (see if there is a _class key)								
                        --add it to the queue instead
						if(maxqueueIndex ~= queueIndex) then
							serializeQueue[queueIndex] = v;
							queueIndex = queueIndex+1;
						end
                        v[".CIDERPath"] = tab[".CIDERPath"]..i
                        v[".luaID"] = i; --the table itself knows its ID
                        --serializeDump(v, tables)
                    end	
                    
                elseif(v==jsonNull) then
                    newTab[i] = jsonNull;
                elseif(typev=="function") then
                    newTab[i]  = {}
                    newTab[i].isCoronaBridgeFunction = true
                    newTab[i].id = i
                elseif(typev=="userdata") then
                    newTab[i] = ".userdata"
                end
            end		
        end
        queueIndex = queueIndex-1
        tab = serializeQueue[queueIndex]
    end
    return tables	
end
local function localsDump(stackLevel, vars) --puts all locals into table
    
    if(vars==nil) then
        vars = {}
    end
    
    local db = debug.getinfo(stackLevel, "fS")
    local func = db.func
    local i = 1
    while true do
        local name, value = debug.getupvalue(func, i)
        if not name then break end
        if(value==nil) then
            vars[name] = jsonNull
        else
            vars[name] = value
        end
        
        i = i + 1
    end
    i = 1
    while true do
        local name, value = debug.getlocal(stackLevel, i)
        if not name then break end
        if(name:sub(1,1)~="(") then
            if(value==nil) then
                vars[name] = jsonNull
            else
                vars[name] = value
            end
            
            
            
        end
        i = i + 1
    end
    --setmetatable(vars, { __index = getfenv(func), __newindex = getfenv(func) })
    --	local dump = serializeDump(   vars	)
    return vars
end
local function searchLocals(localName,newValue,stackLevel) --puts all locals into table
    local db = debug.getinfo(stackLevel, "fS")
    local func = db.func
    local i = 1
    
    while true do
        
        local name, value = debug.getlocal(stackLevel, i)
        print("Var,",name,localName)
        if not name then break end
        if(name == localName) then  print("var found");debug.setlocal(stackLevel, i, newValue); return; end
        i = i + 1
    end
    
    i = 1
    while true do
        local name, value = debug.getupvalue(func, i)
        if not name then break end
        if(name == localName) then debug.setupvalue(func, i, newValue); return; end
        i = i + 1
    end  
end
local function stackDump(stackLevel)
    
    local stackDump = {};
    local stackIndex = stackLevel
    local index = 0;
    local info 
    local filename;
    local info = debug.getinfo(stackIndex,"S")  
    while(info) do
        
        
        filename = info.source
        if( filename:find("CiderDebugger.lua") ) then
            break;
        end
        
        if( filename:find( "@" ) ) then
            filename = filename:sub( 2 )
        end    
        
        --  print(i, "linedefined=",info.linedefined, filename)
        stackDump[index] = {filename,info.linedefined}
        
        
        index = index+1
        stackIndex = stackIndex+1
        info = debug.getinfo(stackIndex,"S")  
    end
    
    return stackDump
    
end


local function writeStackDump() --write the var dump to file
    stackDumpFile = io.open(pathToStack,"w") --clear dump
    stackDumpFile:write( json.encode(stackDump(5)).."\n" )
    stackDumpFile:close( );
    udpSocket:send( json.encode( {["type"]="st"} ) )   
    -- stackDump(6);
    --    local Root = {}
    --    Root = localsDump(5)
    --    Root[".Globals"] = _G
    --    local rootKey = tostring(Root)
    --    Root = serializeDump(Root)
    --    Root[".ROOT"] = rootKey --index to the root element
    --    local message = {}
    --    message.type = "gl"
    
    
    
    --we must break up this message into parts so that it does not get truncated
    --    if(messageString:len()>maxSize) then
    --        while(messageString:len()>maxSize) do				
    --            local part = messageString:sub(1,maxSize)
    --            message = {}
    --            message.type = "ms"
    --            message.value = part			
    --            udpSocket:send(json.encode(message))
    --            messageString = messageString:sub(maxSize+1)
    --            print("sending part", messageString:len())
    --        end
    --        message = {}
    --        message.type = "me"
    --        message.value = messageString			
    --        udpSocket:send(json.encode(message))				
    --    else
    --        
    --        udpSocket:send(messageString)
    --    end
    
    --    varDumpFile = io.open(pathToVar,"w") --clear dump
    --    varDumpFile:write( json.encode(Root) )
    --    varDumpFile:close( );
    --    udpSocket:send( json.encode( message ) )    
    
end
local dumpTable = {};
local function writeVariableDump() --write the var dump to file
    for k,v in pairs(dumpTable) do dumpTable[k]=nil end --clear the table but keep the reference
    for k,v in pairs(Root) do Root[k]=nil end
    localsDump(5, Root)
    Root[".Globals"] = _G
    local rootKey = tostring(Root)
    serializeDump(Root, dumpTable)
    Root[".luaID"]="local vars"
    dumpTable[".ROOT"] = rootKey --index to the root element
    local message = {}
    message.type = "gl"
    
    --we must break up this message into parts so that it does not get truncated
    --    if(messageString:len()>maxSize) then
    --        while(messageString:len()>maxSize) do				
    --            local part = messageString:sub(1,maxSize)
    --            message = {}
    --            message.type = "ms"
    --            message.value = part			
    --            udpSocket:send(json.encode(message))
    --            messageString = messageString:sub(maxSize+1)
    --            print("sending part", messageString:len())
    --        end
    --        message = {}
    --        message.type = "me"
    --        message.value = messageString			
    --        udpSocket:send(json.encode(message))				
    --    else
    --        
    --        udpSocket:send(messageString)
    --    end
    
    varDumpFile = io.open(pathToVar,"w") --clear dump
    varDumpFile:write( json.encode(dumpTable) )
    varDumpFile:close( );
    udpSocket:send( json.encode( message ) )    
    
end

local function standardizePath( input )
    input = string.lower( input )
    input = string.gsub( input, "/", "\\" )
    return input
end
local steppingInto
local steppingOver
local pauseOnReturn
local stepOut
local firstLine = false
local callDepth = 0
local processFunctions = {}
processFunctions.gpc = function()
    --now send the program counter position to netbeans
    local message = {}
    message.type = "gpc"
    if(previousFile:find("@")) then
        previousFile = previousFile:sub(2)
    end     
    if(previousLine==nil) then
        previousLine = 0;
    end        
    message.value = {["file"] = previousFile,["line"] = previousLine}    
    udpSocket:send(json.encode(message))
end
processFunctions.gl = function( )
    --gets the global and local variable state
    writeVariableDump( )
end
processFunctions.p = function( )
    local inPause = true
    --pause execution until resume is recieved, process other commands as they are received
    statusMessage = "paused"
    processFunctions.gpc( )
    writeVariableDump( )
    writeStackDump()
    local line = udpSocket:receive( );
    local keepWaiting = true;
    while( keepWaiting ) do
        if( line ) then
            line = json.decode( line )
            if( line.type~="p" ) then
                processFunctions[line.type]( line );
            end
            if( line.type == "k" or line.type == "r" or line.type == "si" or line.type == "sov" or line.type == "sou" or line.type == "rtc" ) then --if run or step
                return;
            end
            if( line.type == "sv" ) then
                --print( "update dump" )
                writeVariableDump( );
            end			
        end
        line = udpSocket:receive( )
        socket.sleep( 0.1 )
    end
    varRefTable = {}; --must clear reference or else we will have leaks.
end
processFunctions.r = function( )
    runToCursorKey = nil
    runToCursorKeyLine = nil
end
processFunctions.s = function( )
    
end


processFunctions.sb = function( input )
    --sets a breakpoint
    --	file = system.pathForFile( input.path )
    if( breakpointLines[input.line]==nil ) then
        breakpointLines[input.line] = 1 
    else
        breakpointLines[input.line] = breakpointLines[input.line]+1
    end
    
    breakpoints[ standardizePath( input.path )..input.line] = true;
end




processFunctions.rb = function( input )
    if( breakpointLines[input.line]==0 ) then
        breakpointLines[input.line] = nil
    else
        breakpointLines[input.line] = breakpointLines[input.line]-1
    end
    
    breakpoints[ standardizePath( input.path )..input.line] = nil;
end

processFunctions.rtc = function( input )
    --removes a breakpoint
    --	file = system.pathForFile( input.path )
    runToCursorKeyLine = input.line
    runToCursorKey = standardizePath( input.path )..input.line;
end

processFunctions.si = function( )
    print( "stepping into" )
    steppingInto = true
    runToCursorKey = nil
    runToCursorKeyLine = nil
end
processFunctions.sov = function( )
    print( "stepping over" )
    callDepth = 0;
    steppingOver= true
    runToCursorKey = nil
    runToCursorKeyLine = nil
end
processFunctions.sou = function( )
    print( "stepping out" )
    callDepth = 1;
    pauseOnReturn = true
    steppingInto = false
    steppingOver= false
    runToCursorKey = nil
    runToCursorKeyLine = nil
end
processFunctions.sv = function( input )
    print( "setting var", input.parent, input.key, input.value, _G )
    
    if( input.parent == "Root" ) then--now we must search for it
        print( "search locals")
        searchLocals( input.key,input.value, 5 );
        return;			
    elseif( input.parent == "GLOBAL" ) then--now we must search for it
        _G[input.key] = input.value
        return;		
    end	
    local mytab = varRefTable[input.parent]
    if( mytab ) then
        --try to guess the content of the input
        if( input.value == "true" ) then
            mytab[input.key] = true
        elseif( input.value == "false" ) then
            mytab[input.key] = false
        elseif( input.value == "nil" ) then
            mytab[input.key] = nil			
        else
            mytab[input.key] = input.value;
        end
    end
    writeVariableDump( )
end
processFunctions.e = function( evt )
    evt = evt.value
    --print( "event recieved",evt.name, evt.xGravity, evt.yGravity, evt.zGravity );
    Runtime:dispatchEvent( evt );
end
processFunctions.k = function( evt )
    --just remove all the breakpoints
    os.exit( )
    breakpoints = {}
    steppingInto = false
    steppingOver= false
    pauseOnReturn = false
    runToCursorKey = nil
end
--this will do the debug loop, listen for netbeans commands and respond accordingly, executes every line, return, call
local stringlen = string.len
local getinfo = debug.getinfo
local sethook =  debug.sethook
local tostring = tostring
local function runloop( phase, lineKey, err )
    sethook ( )	
    --      local fileKey =  getinfo( 2,"S" ).source 
    --       if( fileKey~="=?" and fileKey~="C" ) then
    --           previousFile,previousLine = fileKey,lineKey
    --       end
    if( phase == "error" ) then
        --send the error and just stop h
        local message = {}
        message.type = "pe"	
        message.str = err
        udpSocket:send( json.encode( message ) )
        
        --    processFunctions.p( ) 			
    end   
    sethook ( runloop, "r",0 ) --errors occur during returns
end

local function debugloop( phase,lineKey,err )
    sethook ( )	
    local fileKey = getinfo( 2,"S" ).source 
    if( phase == "error" ) then
        --send the error and just stop h
        local message = {}
        message.type = "pe"	
        message.str = err
        udpSocket:send( json.encode( message ) )   
        processFunctions.p( ) 			
    end
    
    
    if( fileKey~="=?" and fileKey~="=[C]" ) then
        
        if( lineBlacklist[fileKey]==nil ) then
            --  print( "filekey", fileKey )
            --check all the filters
            local filter
            for i=1, #fileFilters do
                filter = fileFilters[i]
                --print( "black", filter, fileKey,string.find( fileKey,filter,1,true ) )
                lineBlacklist[fileKey] = lineBlacklist[fileKey] or ( string.find( fileKey,filter,1,true ) or false )
            end                
        end
        if( lineBlacklist[fileKey] ) then
            if( phase ~= "line" ) then
                sethook ( debugloop, "l",0 )
            else
                sethook ( debugloop, "r",0 ) --future option
            end                        
            return;
        end        
        
        if( lineKey ) then
            previousLine, previousFile =  lineKey ,fileKey	--do before standardization 
        end
        -- previousLine, previousFile =  lineKey ,fileKey	--do before standardization        
        --print( phase,fileKey,lineKey )
        
        if( phase == "call" ) then
            if( fileKey:find( "@" ) ) then
                previousFile = fileKey:sub( 2 )
            end  
            callDepth = callDepth+1;
            --iterate through file filters
            if( steppingOver ) then
                pauseOnReturn = true;
                steppingOver = false;
            end
        elseif( phase == "return" ) then
            callDepth = callDepth-1;
            if( steppingOver ) then
                steppingOver =  false
                steppingInto = true
            end				
            if( pauseOnReturn and callDepth==0) then
                pauseOnReturn = false;
                steppingInto = true;--pause after stepping one more
            end
        elseif( phase == "line" ) then
            snapshotCounter = snapshotCounter+1
            if( snapshotInterval == snapshotCounter or steppingInto or steppingOver ) then
                snapshotCounter = 0
                local logMessage = {}
                for k,v in pairs(dumpTable) do dumpTable[k]=nil end --clear the table but keep the reference
                for k,v in pairs(Root) do Root[k]=nil end
                localsDump(3, Root)
                Root[".Globals"] = _G
                local rootKey = tostring(Root)
                serializeDump(Root, dumpTable)
                Root[".luaID"]="local vars"
                dumpTable[".ROOT"] = rootKey --index to the root element
                local message = {}
                message.type = "hgl"
                message.value = dumpTable	
                logMessage.var = message
--                
                --Program counter component
                local message2 = {}
                message2.type = "gpc"
                if( previousFile:find( "@" ) ) then
                    previousFile = previousFile:sub( 2 )
                end            
                message2.value = {["file"] = previousFile , ["line"] = previousLine};
                logMessage.pc = message2
                
                local message3 = {}
                message3.type="hst"
                message3.value = stackDump(3)
                logMessage.st =message3
                
                
                --we must break up this message into parts so that it does not get truncated
                logfile:write( json.encode( logMessage ).."\n" )
                logfile:flush( )
                
                
            end
            local inLine = true
            if( steppingInto or steppingOver or firstLine ) then
                firstLine = false;
                steppingInto = false;
                steppingOver = false;
                processFunctions.p( ) --pause after stepping one line					
            else
                --check if we are at a breakpoint or if we are at run to cursor 
                if( breakpointLines[lineKey] or runToCursorKeyLine ) then
                    if( previousFile:find( "@" ) ) then
                        previousFile = previousFile:sub( 2 )
                    end                      
                    fileKey = standardizePath( previousFile )
                    local key = fileKey..lineKey                    
                    if( breakpoints[key] or runToCursorKey==key ) then
                        --we are at breakpoint
                        print( "breakpoint" )
                        if( runToCursorKey==key ) then
                            runToCursorKey = nil
                            runToCursorKeyLine = nil
                        end
                        processFunctions.p( ) 	
                    end
                end
            end
            
        end
        
        --in a lua function
        --check for netbeans commands
        
        local line = udpSocket:receive( )
        while( line ) do
            --Process Line Here
            
            line = json.decode( line )
            processFunctions[line.type]( line );
            if( line.type=="sv" )then
                processFunctions.gl( ) --send the locals.
            end
            
            
            
            line = udpSocket:receive( )				
        end
        
    end
    
    debug.sethook ( debugloop, "crl",0 )
end

local function initBlock( )
    
    --send start command and wait for response
    --first get debugger state send gb command
    
    
    local pathToHistory  = system.pathForFile( "CiderExecutionLog.dat", system.DocumentsDirectory )
    logfile = io.open( pathToHistory,"w" )	
    pathToVar = system.pathForFile( "CiderVarDump.dat", system.DocumentsDirectory )
    varDumpFile = io.open( pathToVar,"w" )
    varDumpFile:close();
    pathToStack = system.pathForFile( "CiderStackDump.dat", system.DocumentsDirectory )
    stackDumpFile = io.open( pathToStack,"w" )    
    stackDumpFile:close();    
    local message = {}
    message.type = "s"	
    message.path = tostring(pathToHistory)
    message.varDump = tostring(pathToVar);
    message.stackDump = tostring(pathToStack)
    udpSocket:send(json.encode(message))		
    print( "waiting for netbeans debugger initialization")	
    local line = udpSocket:receive()
    local keepWaiting = true
    while( keepWaiting ) do
        socket.sleep(0.1)
        if(line) then
            --	print(line)
            line = json.decode(line)
            if(line.type=="s") then
                if(line.snapshot) then
                    snapshotInterval = tonumber(line.snapshot)
                end
                for i,v in pairs(line.filters) do
                    line.filters[i] = (string.gsub(v, "^%s*(.-)%s*$", "%1"))    
                end
                
                fileFilters = line.filters;
                CiderRunMode = line.run
                startupMode = line.startup;
                keepWaiting = false
                break;
            end
            if(line.type=="sb") then
                processFunctions[line.type](line);--proccess current then the rest		
            end
        end
        line = udpSocket:receive()		
    end
    --lets initialize a log file
    
    line = udpSocket:receive()	
    while(line) do
        line = json.decode(line)
        if(line.type=="sb")  then
            processFunctions[line.type](line);
            
        end
        line = udpSocket:receive()	
    end	
    
    --now we have the first line with the start command, we can give back control of the program
    print("debugger started")	
end


if(CiderRunMode.runmode) then
    sethook (runloop, "r",0 )
else       
    initBlock()
    if(startupMode=="require") then
        debug.sethook (debugloop, "crl",0 );
    elseif(startupMode=="noRequire") then
        timer.performWithDelay(1,function() debug.sethook (debugloop, "crl",0 ); end)
        elseif(startupMode=="delay") then
        timer.performWithDelay(1000,function() debug.sethook (debugloop, "crl",0 ); end)
    end
        
    end
    CiderRunMode = nil;
    
    isCorona = nil;
    
