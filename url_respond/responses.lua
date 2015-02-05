
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

--
function basic_response(how)
   local allowed_status = how.allowed_status or {committed=true, provisional=true}
   return {
      resource_request_starting=function (info, v, _uri)
         local action = true
         if not allowed_status[info.status] then
            action = false
         end
         return action
      end,
      load_status=function(info, v, status)
         local tags = split_to_set(info.tags)
         -- No overrides yes.
         --v.enable_scripts = ((not tags.noscript) and (tags.allow_script or how.allow_script))
         --v.enable_plugins = ((not tags.noplugin) and (tags.allow_plugin or how.allow_plugin))
      end
   }
end
