
local lousy = require("lousy")
local capi = { luakit = luakit, sqlite3 = sqlite3 }

-- This should be in lib/lousy/uri.lua ?
function my_domain_of_uri(uri)
   if uri then
      uri = lousy.uri.parse(uri)
      if uri then
         return string.lower(uri.host)
      end
   end
   return nil
end

local monitor = {}  -- Monitorring for debug, will monitor everything if empty.

function is_monitorred(uri)
   return (#monitor == 0) or monitor[get_domain(uri)]
end

db = capi.sqlite3{ filename = capi.luakit.data_dir .. "/respond.db" }
db:exec([[
PRAGMA synchronous = OFF;
PRAGMA secure_delete = 1;

CREATE TABLE IF NOT EXISTS url_respond (
    domain TEXT PRIMARY KEY,
    response TEXT NOT NULL,
    tags TEXT NOT NULL,
    data TEXT NOT NULL
);
]])

function get_response_info(uri, from_uri)
   local domain, from_domain = my_domain_of_uri(uri or ""), my_domain_of_uri(from_uri or "")
--   local rows = db:exec([[ SELECT domain, response, tags, data FROM url_respond WHERE domain = ?]],
--                        { domain })
--   return rows[1] or { domain=domain, response="default", tags="", data=""}
   return { domain=domain or "", from_domain=from_domain or "",
            response="default", tags="", data=""}
end

require "url_respond.responses"

local config = globals.respond or {}

local responses = config.responses or {
   default=basic_response({allowed_status={committed=true, provisional=true},
                           allow_scripts=false, allow_plugins=false}),
   permissive={resource_request_starting=function(...) return true end,
               load_status=function(...) end},

}

-- Keeps count of different responses. (i,e. to see a pulse)
action_cnt = {}
response_cnt = {}

current_status = {}

webview.init_funcs.url_respond_signals = function (view, w)
   view:add_signal("resource-request-starting", 
       function (v, uri)
          local info   = get_response_info(uri, v.uri)
          info.status = current_status[info.from_domain] or "no_info"
          
          response_cnt[info.response] = (response_cnt[info.response] or 0) + 1
          local action = responses[info.response].resource_request_starting(info, v, uri)
          local name = "allow"
          if type(action) == "string" and action ~= uri then
             name = "redirect"
          elseif type(action) == "boolean" and not action then
             name = "block"
          end
          action_cnt[name] = (action_cnt[name] or 0) + 1
          return action
       end)
   view:add_signal("load-status", 
       function (v, status)
          local info   = get_response_info(nil, v.uri)
          current_status[info.from_domain or ""] = status
          info.status = status
          for k,v in pairs(info) do print(k, v) end
          return responses[info.response].load_status(info, v, status)
       end)
end

require "url_respond.chrome"
