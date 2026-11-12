if string.cmatch then return end

local assert, tonumber, tinsert, pairs, unpack = assert, tonumber, table.insert, pairs, unpack

-- [ SanitizePattern ]
-- Sanitizes and convert patterns into gmatch compatible ones.
-- 'pattern'    [string]         unformatted pattern
-- returns:     [string]         simplified gmatch compatible pattern
local sanitize_cache = {}
local function SanitizePattern(pattern)
  assert(pattern, 'bad argument #1 to \'SanitizePattern\' (string expected, got nil)')
  if not sanitize_cache[pattern] then
    local ret = pattern
    -- remove '|3-formid(text)' grammar sequence (no need to handle this for this case)
    --ret = ret:gsub("%|3%-1%((.-)%)", "%1")
    -- escape magic characters
    ret = ret:gsub("([%+%-%*%(%)%?%[%]%^])", "%%%1")
    -- remove capture indexes
    ret = ret:gsub("%d%$","")
    -- catch all characters
    ret = ret:gsub("(%%%a)","%(%1+%)")
    -- convert all %s to .+
    ret = ret:gsub("%%s%+",".+")
    -- set priority to numbers over strings
    ret = ret:gsub("%(.%+%)%(%%d%+%)","%(.-%)%(%%d%+%)")
    -- cache it
    sanitize_cache[pattern] = ret
  end

  return sanitize_cache[pattern]
end

-- [ GetCaptures ]
-- Returns the indexes of a given regex pattern
-- 'pat'        [string]         unformatted pattern
-- returns:     [numbers]        capture indexes
local capture_cache = {}
local function GetCaptures(pat)
  if not capture_cache[pat] then
    local result = {}
    for capture_index in pat:gmatch("%%(%d)%$") do
      capture_index = tonumber(capture_index)
      tinsert(result, capture_index)
    end
    capture_cache[pat] = #result > 0 and result
  end

  return capture_cache[pat]
end

-- [ string.cmatch ]
-- Same as string.match but aware of capture indexes
-- 'str'        [string]         input string that should be matched
-- 'pat'        [string]         unformatted pattern
-- returns:     [strings]        matched string in capture order
string.cmatch = function(str, pat)
  -- read capture indexes
  local capture_indexes = GetCaptures(pat)
  local sanitized_pat = SanitizePattern(pat)

  -- if no capture indexes then use original string.match
  if not capture_indexes then
    return str:match(sanitized_pat)
  end

  -- read captures
  local captures = {str:match(sanitized_pat)}
  if #captures == 0 then return end
  -- put entries into the proper return values
  local result = {}
  for current_index, capture in pairs(captures) do
    local correct_index = capture_indexes[current_index]
    result[correct_index] = capture
  end
  return unpack(result)
end
