chrome_name = "urlRespond"
chrome_uri = string.format("luakit://%s/", chrome_name)

local stylesheet = lousy.load_asset("url_respond/style.css") or ""
local html = lousy.load_asset("url_respond/page.html")
local js = lousy.load_asset("url_respond/js.js")
local chrome = require("chrome")

local chrome_ran_cnt = 0

-- Functions that are also callable from javascript go here.
export_funcs = {
   reset = function() requests = {} end
   -- TODO
}

function write_keypairs(of_table)
   local str = ""
   for k, v in pairs(of_table) do
      str = str .. string.format("%s: %s, ", k, v)
   end
   return str
end

chrome.add(chrome_name, function (view, meta)
    local list_str = "<table>"
    for _, r in pairs(requests) do
       local line_str = ""
       for _, el in pairs(r) do
          line_str = line_str .. "<td>" .. el .. "</td>"
       end
       list_str = list_str .. "<tr>" .. line_str .. "</tr>"
    end
    list_str = list_str .. "</table>"
    
    local html = string.gsub(html, "{%%(%w+)}",
                             { stylesheet = stylesheet,
                               title=chrome_name,
                               listCnt=#requests,
                               list=list_str,
                               responses = write_keypairs(response_cnt),
                               actions   = write_keypairs(action_cnt),
                              })
    view:load_string(html, chrome_uri)
    
    function on_first_visual(_, status)
       -- Wait for new page to be created
       if status ~= "first-visual" then return end
       
       for name, func in pairs(export_funcs) do
          view:register_function(name, func)
       end
       
       -- Hack to run-once
       view:remove_signal("load-status", on_first_visual)
       
       -- Double check that we are where we should be
       if view.uri ~= chrome_uri then return end

       chrome_ran_cnt = chrome_ran_cnt + 1
       local run_js = string.gsub(js, "{%%(%w+)}", { chromeRanCnt=chrome_ran_cnt })
       local _, err = view:eval_js(run_js, { no_return = true })
       assert(not err, err)
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
