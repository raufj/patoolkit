--[[

Author: Pentester Academy
Website: www.pentesteracademy.com
Version: 1.0

--]]


do
  if not gui_enabled() then return end

  local security=require('security')
  local util=require('util')


  -- threshold for smaller BI packets
  local BI_threshold=10 

  -- Threshold for Beacon 
  local beacon_threshold=20
  
  
  -- Object to get the current frame number, only for debugging purposes
  local frame_number=Field.new("frame.number")

  -- Object to get ssid
  local SSID=Field.new("wlan.ssid")

  -- Object to get bssid
  local BSSID=Field.new("wlan.bssid")

  -- Object to get channel
  local Channel=Field.new("wlan.ds.current_channel")

  -- Variable to get beacon
  local beacon=Field.new("wlan.fc.type_subtype")

  -- Variable to get Time
  local time=Field.new("frame.time_relative")

  -- Variable to get Beacon Interval
  local BI=Field.new("wlan.fixed.beacon")

  --Variable to get the timestamp
  local timestamp=Field.new("wlan.fixed.timestamp")


  --Object to get frame check
  local frame_check=Field.new("wlan.fcs")

  -- Registering the tap to listen for beacon frame
  local tap = Listener.new("frame", "wlan.ssid")

  -- Table to store beacons, beacons tble hold possible beacon flood ssid and rest of information
  local beacons={}
  local beacons_store={}

  function tap.reset()
    beacons={}
    beacons_store={}
  end

  -- This function will be called for every packet
  function tap.packet(pinfo,tvb)
 

    -- Variable to store SSID
    local ssid=tostring(SSID())

    -- Variable to store BSSID
    local bssid=tostring(BSSID())
    local gc,pc,keyM,auth,wpa_st,frame_pr=security.getEncryption()
    local key=ssid.."-"..bssid


    if(tostring(beacon())=="8")
      then


        -- Variable to store Channel
        local channel=tostring(Channel())
        
        if(beacons[key]==nil)
          then
          table.insert(beacons_store,key)
          beacons[key]={}
          beacons[key]["ssid"]=ssid
          beacons[key]["bssid"]=bssid
          beacons[key]["channel"]=channel
          beacons[key]["auth"]=auth
          beacons[key]["count"]=1
          beacons[key]["lastTime"]=timestamp().value/1000
          beacons[key]["smallerBI"]=0
          beacons[key]["BI"]=50
          beacons[key]["beaconOnly"]=true
       

        -- if an entry already exists in table upadte the beacon interval difference
        else
          local timeDiff=(timestamp().value/1000)- beacons[key]["lastTime"]
        
          -- updating the lowest beacon interval if the difference is less than the existing one
          if(timeDiff<beacons[key]["BI"])
              then
              
              beacons[key]["smallerBI"]=beacons[key]["smallerBI"]+1
          end

          beacons[key]["count"]=beacons[key]["count"]+1
          beacons[key]["lastTime"]=timestamp().value/1000
        end

      -- only check if an entry exists in table, if the other packets already exists there is no need to create entry in the table
      elseif(beacons[key]~=nil)
        then
        beacons[key]["beaconOnly"]=false
    end
  end
  
  -- Function to be called on selecting the option from Tools menu  
  local function beacon_flood_detection(win,stringToFind)
  
      local header=  " ____________________________________________________________________________________________________________________________\n"
                   .."|   S.no   |        SSID        |        BSSID       | Channel |     Security     |      Beacons Sent     |  Detection Code  |\n"

      win:set(header)
      local count=0
      for k,v in ipairs(beacons_store)do    
        data=beacons[v]
        if((data["beaconOnly"] and data["count"]>beacon_threshold)or data["smallerBI"]>=BI_threshold)
          then   

          local str=""
          if(data["beaconOnly"] ) then str="1" end
          if(data["smallerBI"]>=BI_threshold) then if(str=="1") then str="1,2" else str="2" end end   
        
          if(util.searchStr({data["ssid"],data["bssid"],data["channel"],data["auth"],data["count"],str},stringToFind))
          then  

            count=count+1
            local bfd_acf_settings={
              { 
                ["value"]=count,           
                ["length"]=10,  
                ["delimiter"]="",                 
                ["next"]=true,
                ["branch"]=false                     
              },
              { 
                ["value"]=data["ssid"],
                ["length"]=20,
                ["delimiter"]="", 
                ["next"]=true,
                ["branch"]=false
              },
              { 
                ["value"]=data["bssid"],
                ["length"]=20,
                ["delimiter"]="",
                ["next"]=true,
                ["branch"]=false
              },
              { 
                ["value"]=data["channel"],
                ["length"]=9,
                ["delimiter"]="",
                ["next"]=true,
                ["branch"]=false
              },
              { 
                ["value"]=data["auth"],
                ["length"]=18,
                ["delimiter"]="",
                ["next"]=true,
                ["branch"]=false
              },
              { 
                ["value"]=data["count"],
                ["length"]=23,
                ["delimiter"]=",",
                ["next"]=true,
                ["branch"]=true
              },
              { 
                ["value"]=str,
                ["length"]=18,
                ["delimiter"]=",",
                ["next"]=true,
                ["branch"]=true
              }                             
            }
            win:append("|----------------------------------------------------------------------------------------------------------------------------|\n")        
            win:append(bfd_acf(bfd_acf_settings,"|"))  
          end
        end
      end
      win:append("|____________________________________________________________________________________________________________________________|\n")    
      win:append("\nDetection Code:\n1) No Data Except Beacon Frame \n2) Beacon recieved before Beacon Interval\n\n")
      end

 
 function bfd_menu1()
      util.dialog_menu(beacon_flood_detection,"Beacon Flood Detection")
 end
  -- Register the function to Tools menu
  register_menu("WiFi/Beacon Flood Detection",bfd_menu1, MENU_TOOLS_UNSORTED)
end


------------------------------------- Function for string formatting START --------------------------------------------

function bfd_acf(settings,column_seperator)
  local final=""
  while(bfd_isNext(settings))do
      for k,v in ipairs(settings)do
          if(v["next"]==false) then v["value"]="" else v["next"]=false end
          final=final..column_seperator..bfd_format_str(v)
          if(k==#settings) then final=final..column_seperator.."\n" end
      end
   end
  return final
end

function bfd_isNext(settings)
  for k,v in ipairs(settings)do 
    if(v["next"]) then return true end
  end
  return false
end

function bfd_format_str(global,substr)
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
        local a=len
        if(global["branch"]) then str2=""..delimiter.."[^"..delimiter.."]" else str2=""..delimiter.."[^"..delimiter.."]*$" end
        if(delimiter~="")
            then
             a=string.find(str:sub(0,len), str2)
         end
        local c=0
        if( a==nil or a>len) then a=len else c=1 end
        global["value"]=str:sub(a+c)
        global["next"]=true
        return bfd_format_str(global,str:sub(1,a-1))
    end
    return s
end

-------------------------------- Function for string formatting END -------------------------------------------
