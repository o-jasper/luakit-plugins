
-- String splitting, but producing a set instead. (lib/lousy/utils.lua?)
function split_to_set(str, pattern, ret)
   if not pattern then pattern = "%s+" end
   if not ret then ret = {} end   
   local pos = 1
   local fstart, fend = string.find(str, pattern, pos)
   while fstart do
      ret[string.sub(str, pos, fstart - 1)] = true
      pos = fend + 1
      fstart, fend = string.find(str, pattern, pos)
   end
   ret[string.sub(str, pos)] = true
   return ret
end

local function itob(int)  return tonumber(int) ~= 0 end

function basic_response(how)
   local allowed_status = how.allowed_status or {committed=true, provisional=true, no_info=true}
   return {
      resource_request_starting=function (info, v, uri)
         for _, el in pairs(how.exception_uri) do
            if string.match(uri, el) then  -- TODO regular expressions instead
               return true, "exception"
            end
         end
         if not allowed_status[info.status] then
            return false, "wrong_status"
         elseif how.uri_maxlen and #uri > uri_maxlen then
            return false, "uri too long"
         end
         return action, "ok"
      end,
      load_status=function(info, v, status)
         local tags = split_to_set(info.tags)
         -- Script disabling.
         -- Specific configuration overrides global, no overrides yes.

         if status == "committed" and v.uri ~= "about:blank" then
            v.enable_scripts = itob(((not tags.noscript) and (tags.allow_script or how.allow_script)))
            v.enable_plugins = itob(((not tags.noplugin) and (tags.allow_plugin or how.allow_plugin)))
         end
      end
   }
end

function reddit_response(how)
   how.exception_uri={"^https://www.reddit.com/api/login/.+",
                      "^http://www.reddit.com/api/comment",
                      "^http://www.reddit.com/api/editusertext",                      
                      "^http://www.reddit.com/api/vote",
                      "^http://www.reddit.com/api/submit"}
   local reddit = basic_response(how)
   return {
      resource_request_starting=function (info, v, uri)
         -- TODO.. hmmm
         return reddit.resource_request_starting(info, v, uri)
      end,
      load_status=reddit.load_status,
   }
end
