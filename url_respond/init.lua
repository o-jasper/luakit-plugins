
local lousy = require("lousy")
local capi = { luakit = luakit, sqlite3 = sqlite3 }

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

local shortlist = {}
shortlist["www.reddit.com"] = {response="reddit", tags="", data=""}

shortlist["www.wolfire.com"] = {response="monitor", tags="allow_script", data=""}

-- This should be in lib/lousy/uri.lua ?
function domain_of_uri(uri)
   if uri then
      uri = lousy.uri.parse(uri)
      if uri then
         return string.lower(uri.host)
      end
   end
   return nil
end

function get_response_info(uri, from_uri)
   -- The fuck.. it *is* getting a fucking string.
   local domain = domain_of_uri((uri or "")) or ""
   local from_domain = domain_of_uri((from_uri or "")) or ""
   local got = shortlist[from_domain]
   if got then
      got.domain = domain
      got.from_domain = from_domain
      return got
   end
--   local rows = db:exec([[ SELECT domain, response, tags, data FROM url_respond WHERE domain = ?]],
   --                        { from_domain })
--   return rows[1] or { domain=domain or "", from_domain=from_domain, response="default", tags="", data=""}
   return { domain=domain, from_domain=from_domain, response="default", tags="", data=""}
end

require "url_respond.responses"

local config = globals.respond or {}

function print_table(t)
   local str = ""
   for k,v in pairs(t) do str = str .. string.format("%s: %s, ", k, v) end
   print("==" .. str)
end

local responses = config.responses or {
   default=basic_response({allow_scripts=true, allow_plugins=true, uri_maxlen=128}),
   permissive={resource_request_starting=function(...) return true, "always" end,
               load_status=function(...) end},
   monitor={resource_request_starting=function(info, ...) print_table(info) return true end,
            load_status=function(info, ...) print_table(info)  end},

   reddit=reddit_response({allow_scripts=true, allow_plugins=false, uri_maxlen=128})
}

-- Keeps count of different responses. (i,e. to see a pulse)
action_cnt = {}
response_cnt = {}

current_status = {}

requests = requests or {}

webview.init_funcs.url_respond_signals = function (view, w)
   view:add_signal("resource-request-starting", 
       function (v, uri)
          local info   = get_response_info(uri, v.uri)
          info.status = current_status[info.from_domain] or "no_info"
          
          response_cnt[info.response] = (response_cnt[info.response] or 0) + 1
          local action, reason = responses[info.response].resource_request_starting(info, v, uri)
          local name = "allow"
          if type(action) == "string" and action ~= uri then
             name = "redirect"
          elseif type(action) == "boolean" and not action then
             name = "block"
          end
          if reason then
             name = string.format("%s: %s", name, reason)
          end
          if not action or type(action) == "string" then
             info[1] = name
             info.uri = uri
             info.vuri = v.uri
             info.urilen = #uri
             table.insert(requests, info) -- Insert blocked requests.
          end
          action_cnt[name] = (action_cnt[name] or 0) + 1
          return action
       end)
   view:add_signal("load-status", 
       function (v, status)
          local info   = get_response_info(nil, v.uri)
          current_status[info.from_domain or ""] = status
          info.status = status
          return responses[info.response].load_status(info, v, status)
       end)
end

require "url_respond.chrome"
