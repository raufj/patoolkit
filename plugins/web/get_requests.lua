--[[

Author: Pentester Academy
Website: www.pentesteracademy.com
Version: 1.0

--]]

do
  if not gui_enabled() then return end
        local util=require('util')
        local frame_number=Field.new("frame.number")
        local request_method=Field.new("http.request.method")
        local host=Field.new("http.host")
        local request_uri=Field.new("http.request.uri")
        local user_agent=Field.new("http.user_agent")

        function gr_get()
                return tostring(request_method())=="GET"
        end

        local container={}
  
  -- function to return empty string if the value returned by function is null
  function gr_check2(str)
    if str ~=nil 
      then return tostring(str)
    else
      return ""
    end
  end

local function init_listener()

    local tap = Listener.new("frame", "http.request")

    -- Called at the end of live capture run
    function tap.reset()
      container= {}
    end



    -- Called at the end of the capture to print the summary
    function tap.draw()

    end

    -- Called once each time the filter of the tap matches
    function tap.packet(pinfo, tvb)

        -- check whether the request is get 
        if gr_get()
          then
            local uri=tostring(request_uri())
            local req={}

            -- store the host and user_agent field
            req["host"]=gr_check2(host())
            req["user_agent"]=gr_check2(user_agent())

            -- look for ? to seperate uri and parameters and split the string accordingly
            local pos = string.find(uri,"?") or 0
            req["path"]=string.sub(uri,1,pos-1)

            -- if pos is zero there are no parameters
            if pos ~= 0
              then
              req["param"]=string.sub(uri,pos+1)
            else
              req["param"]=""
            end
            table.insert(container,req)
        end
    end
end

    
        local function get_request(win,stringToFind)
            local header=  " ______________________________________________________________________________________________________________________\n"
                         .."|   S.no   |       Host       |       User Agent       |              Path              |          Parameters          |\n"



           
            win:set(header)
            local count=0
            for k,v in ipairs(container)do           -- <- table whoes data you want print

            if(util.searchStr({v["host"],v["user_agent"],v["path"],v["param"]},stringToFind))
                then

                    count=count+1


                  local gr_acf_settings={
                  { 
                    ["value"]=count,           
                    ["length"]=10,  
                    ["delimiter"]=",",                 
                    ["next"]=true,
                    ["branch"]=false                     
                  },
                  { 
                    ["value"]=v["host"],
                    ["length"]=18,
                    ["delimiter"]=",",
                    ["next"]=true,
                    ["branch"]=false
                  },
                  { 
                    ["value"]=v["user_agent"],
                    ["length"]=24,
                    ["delimiter"]=",",
                    ["next"]=true,
                    ["branch"]=false
                  },
                  { 
                    ["value"]=v["path"],
                    ["length"]=32,
                    ["delimiter"]=",",
                    ["next"]=true,
                    ["branch"]=false
                  },
                  { 
                    ["value"]=v["param"],
                    ["length"]=30,
                    ["delimiter"]=",",
                    ["next"]=true,
                    ["branch"]=false
                  }                                  
                }
                  win:append("|----------------------------------------------------------------------------------------------------------------------|\n")  
                  
                  win:append(gr_acf(gr_acf_settings,"|"))  
                end
          end
          win:append("|______________________________________________________________________________________________________________________|\n")     

        end 


        function gr_menu1()
            util.dialog_menu(get_request,"GET Requests With Details")
        end

        register_menu("Web/GET Requests",gr_menu1, MENU_TOOLS_UNSORTED)


  init_listener()

end

        function gr_acf(settings,column_seperator)
          local final=""
          while(gr_isNext(settings))do
              for k,v in ipairs(settings)do
                  if(v["next"]==false) then v["value"]="" else v["next"]=false end
                  final=final..column_seperator..gr_format_str(v)
                  if(k==#settings) then final=final..column_seperator.."\n" end
              end
           end
          return final
        end

        function gr_isNext(settings)
          for k,v in ipairs(settings)do 
            if(v["next"]) then return true end
          end
          return false
        end

        function gr_format_str(global,substr)
            local m=0
            local n=0
            local str=""
            local len=global["length"]
            local delimiter=global["delimiter"]
            if(substr==nil) then str=global["value"] else str=substr end
            if(str==nil) then str="" else str=tostring(str) end
            if (len==nil) then len=0 end
            if(delimiter==nil) then delimiter="" end
            local s=str
            if(str:len()<len)
                then
                if((len-str:len())%2==0)
                    then 
                        m=(len-str:len())/2
                        n=m
                else
                        m=math.floor(((len-str:len()) /2))+1
                        n=m-1
                end     
                for i=1, m
                    do
                    s=" "..s
                end
                for i=1, n
                    do
                    s=s.." "
                end
            elseif(str:len()>len)
                then
                local str2=""
                if(global["branch"]) then str2=""..delimiter.."[^"..delimiter.."]" else str2=""..delimiter.."[^"..delimiter.."]*$" end

                local a=string.find(str:sub(0,len), str2)
                local c=0
                if(delimiter=="" or a==nil or a>len) then a=len else c=1 end
                global["value"]=str:sub(a+c)
                global["next"]=true
                return gr_format_str(global,str:sub(1,a-1))
            end
            return s
        end
