-- TODO iterate through the img tags
--
local lousy = require("lousy")
local key, buf, cmd = lousy.bind.key, lousy.bind.buf, lousy.bind.cmd

local javascript = lousy.load_asset("url_respond/manual_reload_src.js")
--local url_respond=require("url_respond")

-- Turns on relevant images.
function enable_relevant_imgs(how, after)

   local config = how.manual_reload_src or {}
   local run_status = config.in_status or {}
   if #run_status == 0 then
      run_status["first-visual"]=true
   end

   if not after then after = basic_response(how) end
   
   return {
      resource_request_starting=after.resource_request_starting,
      load_status=function(info, v, status)
         if run_status[status] then v.view:eval_js(javascript) end
      end
   }
end

local allow = function(v)
   local add = v.view:eval_js("GyFXHnTVYFd0_cur_img_under_src()")
   print(add)
   if add and string.sub(add, 0, 4) ~= "none" and add ~= "no_under" then
      -- Add to exception, create place to put if if necessary.      
      local got = url_respond.shortlist[domain_of_uri(v.view.uri)] or {response="default"}
      got.exception_uri = (got.exception_uri or "") .. " ^" .. add
      url_respond.shortlist[domain_of_uri(v.view.uri)] = got
      -- Reload it.
      v.view.eval_js("GyFXHnTVYFd0_under_mouse.src=nil;GyFXHnTVYFd0_under_mouse.src=" .. add .. ";")
   end
end

add_cmds({ cmd("uRallow", "Allow the thing under the cursor", allow) })

add_binds("normal", { buf("^,l$", "Allow the thing under the cursor", allow) })
