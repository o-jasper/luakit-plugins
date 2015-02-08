
local lousy = require("lousy")
local capi = { luakit = luakit, sqlite3 = sqlite3 }

local monitor = {}  -- Monitorring for debug, will monitor everything if empty.

function is_monitorred(uri)
   return (#monitor == 0) or monitor[get_domain(uri)]
end

-- ... Not used at the moment.
--db = capi.sqlite3{ filename = capi.luakit.data_dir .. "/respond.db" }
--db:exec([[
--PRAGMA synchronous = OFF;
--PRAGMA secure_delete = 1;
--
--CREATE TABLE IF NOT EXISTS url_respond (
--    domain TEXT PRIMARY KEY,
--    response TEXT NOT NULL,
--    tags TEXT NOT NULL,
--    data TEXT NOT NULL,
--    exception_uri TEXT NOTE NULL
--);
--]])

-- TODO system of matching end/beginning with the dict
local shortlist = {}

shortlist["www.reddit.com"]  = {response="reddit", exception_uri="^http://..thumbs.redditmedia.com/.+.jpg"}
shortlist["www.wolfire.com"] = {response="monitor", tags="allow_script"}
shortlist["www.youtube.com"] = { -- Seems that i cant do much better easily.
   response="default",
   exception_uri="^https://clients1.google.com/generate_204 ^https://s.ytimg.com/yts/jsbin/.+ ^https://i.ytimg.com/vi/.+/mqdefault.jpg https://i.ytimg.com/vi/.+/default.jpg"
}

shortlist["www.tvgids.nl"] = {
   response="default",
   exception_uri="http://www.tvgids.nl/json/lists/.+"
   -- Mirror 
}
shortlist["imgur.com"] = {
   response="default",
   exception_uri="^http://..imgur.com/.+"
}
-- Exceptions instead?
shortlist["en.wikipedia.org"] = { response="permissive" }
shortlist["nl.wikipedia.org"] = { response="permissive" }
shortlist["bits.wikimedia.org"] = { response="permissive" }

local initial_shortlist = {}
for k,v in pairs(shortlist) do initial_shortlist[k] = v end

-- This should be in lib/lousy/uri.lua ?
function domain_of_uri(uri)
   if type(uri) == "string" then
      uri = lousy.uri.parse(uri)
      if uri then
         return string.lower(uri.host)
      end
   end
   return nil
end

function get_response_info(uri, from_uri)
   -- The fuck.. it *is* getting a fucking string.
   local domain = domain_of_uri(uri or "") or ""
   local from_domain = domain_of_uri(from_uri or "") or ""
   local got = shortlist[from_domain]
   if got then
      got.domain = domain
      got.from_domain = from_domain
      got.data = got.data or ""  -- Fill in defaults.
      got.tags = got.tags or ""
      got.exceptions = got.exceptions or ""
      return got
   end
--   local rows = db:exec([[ SELECT domain, response, tags, data FROM url_respond WHERE domain = ?]],
   --                        { from_domain })
--   return rows[1] or { domain=domain or "", from_domain=from_domain, response="default", tags="", data=""}
   return { domain=domain, from_domain=from_domain,
            response="default", tags="", data="", exceptions="" }
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
          -- Get info on domain.
          local info  = get_response_info(uri, v.uri)
          info.status = current_status[info.from_domain] or "no_info"
          
          local action, reason = responses[info.response].resource_request_starting(info, v, uri)
          local name = "allow"  -- Figure out what to name it for statistics.
          if type(action) == "string" and action ~= uri then
             name = "redirect"
          elseif type(action) == "boolean" and not action then
             name = "block"
          end
          if reason then  -- Can give a reason too.
             name = string.format("%s: %s", name, reason)
          end
          if not action or type(action) == "string" then  -- If blocked/redirected, log.
             info[1] = name
             if type(action) == "string" then info[2] = action end
             info.uri = uri
             info.vuri = v.uri
             info.urilen = #uri
             table.insert(requests, info) -- Insert blocked requests.
          end
          if info.domain ~= info.from_domain then
             print(action, name, info.from_domain, info.domain)
          end
          -- Keep statistics.
          action_cnt[name] = (action_cnt[name] or 0) + 1
          response_cnt[info.response] = (response_cnt[info.response] or 0) + 1
          -- Return what we do.
          return action
       end)
   view:add_signal("load-status", 
       function (v, status)
          local info = get_response_info(nil, v.uri)
          current_status[info.from_domain or ""] = status
          info.status = status
          return responses[info.response].load_status(info, v, status)
       end)
end

local make_permissive = function(w)
   shortlist[domain_of_uri(w.view.uri)] = {response="permissive"}
   w:reload()
end
local make_initial = function(w)
   local domain = domain_of_uri(w.view.uri)
   shortlist[domain] = initial_shortlist[domain]
end

local key, buf, cmd = lousy.bind.key, lousy.bind.buf, lousy.bind.cmd

add_binds("normal", { buf("^,k$", "Permissive urlrespond here(for session)",
                          make_permissive) })
add_binds("normal", { buf("^,K$", "urlRespond back to initial.",
                          make_initial) })

add_cmds({ cmd("urlRespondPermissive", "Permissive urlrespond here(for session)",
               make_permissive) })
add_cmds({ cmd("urlRespondDefault", "urlRespond back to initial.",
               make_initial) })

require "url_respond.chrome"
