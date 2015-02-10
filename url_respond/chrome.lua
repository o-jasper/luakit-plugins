
local chrome = require("chrome")

chrome_name = "urlRespond"
chrome_uri = string.format("luakit://%s/", chrome_name)

local chrome_ran_cnt = 0

-- Functions that are also callable from javascript go here.
export_funcs = {
   reset_log = function() requests = {} end
   -- TODO
}

function write_keypairs(of_table)
   local str = ""
   for k, v in pairs(of_table) do
      str = str .. string.format("%s: %s, ", k, v)
   end
   return str
end

local stylesheet = lousy.load_asset("url_respond/style.css") or ""
local html_templates = {}
function get_template(name)
   if not html_templates[name] then
      html_templates[name] =
         lousy.load_asset(string.format("url_respond/assets/%s.html", name))
   end
   return html_templates[name]
end

local pages = {
   -- Log (like of shit that was blocked)
   log = function(meta, dir_split, html)
      local list_str = "<table>"
      for _, r in pairs(requests) do
         local line_str = ""
         for _, el in pairs(r) do
            line_str = line_str .. "<td>" .. el .. "</td>"
         end
         list_str = list_str .. "<tr>" .. line_str .. "</tr>"
      end
      list_str = list_str .. "</table>"
      
      chrome_ran_cnt = chrome_ran_cnt + 1
      return string.gsub(html, "{%%(%w+)}",
                         { stylesheet = stylesheet,
                           title=chrome_name,
                           listCnt=#requests,
                           list=list_str,
                           responses = write_keypairs(response_cnt),
                           actions   = write_keypairs(action_cnt),
                           chromeRanCnt=chrome_ran_cnt
                         })
   end,
   -- Info about a particular domain.
   about_domain = function(meta, dir_split, html)
      local domain = dir_split[2] or "no domain"
      local info = domain_get_response_info(nil, domain)
      local tags_html = "(no tags)"
      if #(info.tags) > 0 then
         tags_html = "<span>" .. table.concat(lousy.util.string.split(info.tags, " "),
                                              "</span>, <span class=\"tag>\">")
            .. "</span>"
      end
      local exceptions_html = "No pattern exceptions."
      if #(info.exception_uri) > 0 then
         exceptions_html = "<table>"
         for _, e in pairs(info_exceptions(info)) do
            exceptions_html = exceptions_html ..
               string.format("<tr><td><code>%s</code></td><td>; %dms</td></tr>",
                             e.pat, e.t)
         end
         exceptions_html = exceptions_html .. "</table>"
      end
      return string.gsub(html, "{%%(%w+)}",
                         { stylesheet = stylesheet,
                           title=chrome_name,
                           response=info.response,
                           --chromeRanCnt=chrome_ran_cnt,
                           aboutDomain=domain,
                           exceptions=exceptions_html,
                           tags=tags_html,
                           data=info.data,                           
                         })
   end
}

chrome.add(chrome_name, function (view, meta)

    local dir_split = lousy.util.string.split(meta.path, "/")
    local use_name, use_uri = "log", string.format("luakit://%s/log", chrome_name)
    if pages[dir_split[1]] then
       use_name = dir_split[1]
       use_uri  = meta.uri
    end
    local html = pages[use_name](meta, dir_split, get_template(use_name))

    view:load_string(html, use_uri)
    
    function on_first_visual(v, status)
       -- Wait for new page to be created
       if status ~= "first-visual" then return end
       
       for name, func in pairs(export_funcs) do
          view:register_function(name, func)
       end
       
       -- Hack to run-once
       view:remove_signal("load-status", on_first_visual)
    end
    view:add_signal("load-status", on_first_visual)
end)

local cmd = lousy.bind.cmd
add_cmds({
    cmd(chrome_name, "Open simple chrome page.",
        function (w)  w:new_tab(chrome_uri) end),
    cmd(string.format("%s_reset", chrome_name), "Reset list",
        function (w) requests = {}  end),
         })
