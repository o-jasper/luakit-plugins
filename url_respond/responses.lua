
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

function match_in_list(list, str)
   for i, el in pairs(list) do
      if string.match(str, el) then return i, el end
   end
end

function basic_response(how)
   local allowed_status = how.allowed_status or
      {committed=true, provisional=true, no_info=true}
   local allowed_long = how.allowed_long or {provisional=true}
   return {
      resource_request_starting=function (info, v, uri)
         -- TODO give them a bit of time, and no more.
         if how.exception_uri  and match_in_exceptions(how.exception_uri, uri) and
            info.exception_uri and match_in_exceptions(info.exception_uri, uri)
         then
           return true, "exception"
         end
         local uri_maxlen = info.uri_maxlen or how.uri_maxlen
         if not allowed_status[info.status] then
            return false, "wrong_status"
         elseif uri_maxlen and uri_maxlen ~= "none" and (#uri) > uri_maxlen and
                not allowed_long[info.status] then
            return false, "uri too long"
         else
            return true, "ok"
         end
         assert(false)
      end,
      load_status=function(info, v, status)
         local tags = split_to_set(info.tags)
         -- Script disabling. (TODO doesnt seem to work)
         -- Specific configuration overrides global, no overrides yes.
         if status == "committed" and v.uri ~= "about:blank" then
            v.enable_scripts = itob(((not tags.noscript) and
                                        (tags.allow_script or how.allow_script)))
            v.enable_plugins = itob(((not tags.noplugin) and
                                        (tags.allow_plugin or how.allow_plugin)))
         end
      end
   }
end

function reddit_response(how, after)
   how.exception_uri = how.exception_uri or {}
   -- TODO very incomplete..
   table.insert(how.exception_uri, "^https://www.reddit.com/api/login/.+")
   local apilist = {"comment", "del", "editusertext", "hide", "info", "marknsfw",
                    "morechildren", "report", "save", "saved_categories.json",
                    "sendreplies", "set_contest_mode", "set_subreddit_sticky",
                    "store_visits", "submit", "unhide", "unmarknsfw", "unsave", "vote",
   }
   for _, el in pairs(apilist) do
      table.insert(how.exception_uri, string.format("^https*://www.reddit.com/api/%s", el))
   end
   if not after then after = basic_response(how) end
   return {
      resource_request_starting=function (info, v, uri)
         for _, el in pairs(apilist) do
            if string.match(uri, string.format("^https*://www.reddit.com/api/%s", el)) then
               if string.sub(uri, 1, 6) == "http:" then
                  return ("https:" .. string.sub(uri, 6)), "https-ize"
               end
               return true, "allow"
            end
         end
         for _, el in pairs({ "^http://a.thumbs.redditmedia.com/.+png",
                              "^https://pixel.redditmedia.com/i.gif.e.+",
                              "^http://pixel.redditmedia.com/pixel/of_doom.png.r.+",
                              "^http://www.redditstatic.com/icon.png"
                            }) do
            if string.match(uri, el) then
               local file = "file:///home/jasper/oproj/browsing/luakit-stuff/luakit-plugins/url_respond/pic/%d.png"
               return string.format(file, math.random(10)), "countah"
            end
         end
         return after.resource_request_starting(info, v, uri)
      end,
      load_status=after.load_status,
   }
end
