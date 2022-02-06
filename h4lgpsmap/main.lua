---- ##########################################################################################################
---- #                                                                                                        #
---- # Hobby4life GPS Map Widget for ETHOS                                                                    #
---- #                                                                                                        #
---- #                                                                                                        #
---- #                                                                                                        #
---- # License GPLv3: http://www.gnu.org/licenses/gpl-3.0.html                                                #
---- #                                                                                                        #
---- # This program is free software; you can redistribute it and/or modify                                   #
---- # it under the terms of the GNU General Public License version 3 as                                      #
---- # published by the Free Software Foundation.                                                             #
---- #                                                                                                        #
---- #                                                                                                        #
---- # Björn Pasteuning / Hobby4life 2022                                                                     #
---- #                                                                                                        #
---- ##########################################################################################################



-------------------------------------------------------------------------------------------------------------------
-- Set up of variables used in whole scope
-------------------------------------------------------------------------------------------------------------------
local Version = "v1.03"
local Title = "Hobby4Life - GPS Map"
local translations = {en="H4L GPS Map"}
local mapImage                    -- Global use of map image
local Windsock                    -- Global use of windsock image
local ForceHome = false           -- Global Flag to Force Homing
local HomeSet = false             -- Global Flag if Home is set or not
local RadioInfo = {}
local Draw_LCD = false            -- Flag used in functions that have draw functions
local DMSLatString = ""           -- Global DMS Latitude string
local DMSLongString = ""          -- Global DMS Longitude string
local Heading_Previous = 0        -- Stores a global valid heading value used in drawArrow()
local TempLat =0 --52             -- Default Compare Latitude, used in drawArrow()
local TempLong = 0 --5            -- Default Compare Latitude, used in drawArrow()
local LCD_Type                    -- 0 = X10/12, 1 = X20
local Map_change                  -- Flag used when a map is changed
local Run_Script = false          -- Used to control the whole paint loop
local Bearing = 0                 -- Global Bearing variable

local function name(widget)
    local locale = system.getLocale()
    return translations[locale] or translations["en"]
end






-------------------------------------------------------------------------------------------------------------------
-- Default Source values upon creation of widget
-------------------------------------------------------------------------------------------------------------------
local function create()
    return {
            GPSSource=nil, GPSLAT=0, GPSLONG=0,
            SpeedSource=nil, SPEED=0, SPEED_UNIT=0,
            AlitudeSource=nil, ALTITUDE=0, ALTITUDE_UNIT=0,
            CourseSource=nil, COURSE=0,
            RSSISource=nil, RSSI=0,
            Calculate_Bearing=true, Update_Distance = 25,
            HomePosX=0, HomePosY=0,
            GpsPosX=0, GpsPosY=0,
            HomeLat=0, HomeLong=0,
            ResetSource=nil, 
            MapNorth=0,MapSouth=0,MapWest=0,MapEast=0,
            LatValue=0,LongValue=0,
            PlaneVisible = false,
            ArrowColor = lcd.RGB(0, 255, 0),
            HUD_Text_Color = lcd.RGB(255, 255, 255),
            Distance_Text_Color = lcd.RGB(0, 0, 0),
            LineColor = lcd.RGB(0, 0, 0),
            NS="",EW="", FM="", SPD="",
            LCD_Type, --800x480(x20) or 480x272(x10/x12)
            TX_VOLTAGE = 0,
            Map_Select = 0,
            unit = 0,           -- 0 = Metric, 1 = Imperial
            GPS_Annotation = 0, -- 0 = DMS, 1 = Decimal
            }
end









-------------------------------------------------------------------------------------------------------------------
-- Map Coordinates
-------------------------------------------------------------------------------------------------------------------
local function ReadMapCoordinates(widget)
  if Map_change ~= widget.Map_Select then
    if widget.Map_Select == 0 then
      -- Map 1
      dofile("/scripts/h4lgpsmap/maps/map1.lua")
    elseif widget.Map_Select == 1 then
      -- Map 2
      dofile("/scripts/h4lgpsmap/maps/map2.lua")
    elseif widget.Map_Select == 2 then
      -- Map 3
      dofile("/scripts/h4lgpsmap/maps/map3.lua")      
    elseif widget.Map_Select == 3 then
      -- Map 4
      dofile("/scripts/h4lgpsmap/maps/map4.lua")      
    elseif widget.Map_Select == 4 then
      -- Map 5
      dofile("/scripts/h4lgpsmap/maps/map5.lua") 
    elseif widget.Map_Select == 5 then
      -- Map 6
      dofile("/scripts/h4lgpsmap/maps/map6.lua")           
    elseif widget.Map_Select == 6 then    
      -- Map 7
      dofile("/scripts/h4lgpsmap/maps/map7.lua")          
    elseif widget.Map_Select == 7 then    
      -- Map 8      
      dofile("/scripts/h4lgpsmap/maps/map8.lua")            
    end
    widget.MapNorth = North
    widget.MapSouth = South
    widget.MapWest = West
    widget.MapEast = East    
    mapImage = Image
    Map_change = widget.Map_Select
  end
end








-------------------------------------------------------------------------------------------------------------------
-- Calculates the radius between 2 X,Y points
-------------------------------------------------------------------------------------------------------------------
local function CalcRadius( x1, y1, x2, y2 )
  local dx = x1 - x2
  local dy = y1 - y2
  return math.sqrt ( dx * dx + dy * dy )
end










-------------------------------------------------------------------------------------------------------------------
-- Draws a Alert Box
-------------------------------------------------------------------------------------------------------------------
local function DrawAlertBox(widget,string,color,bkcolor)
      local lcd_width, lcd_height = lcd.getWindowSize()
      local text_w, text_h = lcd.getTextSize("")
      local str_w, str_h = lcd.getTextSize(string)
      lcd.pen(SOLID)
      lcd.color(bkcolor)
      lcd.drawFilledRectangle(((lcd_width  /2) - (str_w/2)),((lcd_height /2) - (str_h/2)),str_w,str_h)
      lcd.color(color)
      lcd.drawText(lcd_width /2,(lcd_height /2) - (text_h/2),string ,CENTERED)
      return
end









-------------------------------------------------------------------------------------------------------------------
-- Function to draw Arrow
-------------------------------------------------------------------------------------------------------------------
local function drawArrow(Start_X,Start_Y,Arrow_Width,Arrow_Length,Angle,Angle_Offset,Style,widget)

--        C
--       /|\
--      / | \
--     /  A  \
--    /   F   \
--   D----B----C
  
    --Calcutate point B from A Start position
    local B_X = Start_X + math.cos(math.rad(Angle + Angle_Offset)) * (Arrow_Length / 2)
    local B_Y = Start_Y + math.sin(math.rad(Angle + Angle_Offset)) * (Arrow_Length / 2)
    
    --Calcutate point C A Start position
    local C_X = Start_X + math.cos(math.rad((Angle + Angle_Offset) + 180)) * (Arrow_Length / 2)
    local C_Y = Start_Y + math.sin(math.rad((Angle + Angle_Offset) + 180)) * (Arrow_Length / 2)    
    
    --Calcutate point D from B
    local D_X = B_X + math.cos(math.rad((Angle + Angle_Offset) + 90)) * (Arrow_Width / 2)
    local D_Y = B_Y + math.sin(math.rad((Angle + Angle_Offset) + 90)) * (Arrow_Width / 2)    
    
    --Calcutate point E from B
    local E_X = B_X + math.cos(math.rad((Angle + Angle_Offset) + 270)) * (Arrow_Width / 2)
    local E_Y = B_Y + math.sin(math.rad((Angle + Angle_Offset) + 270)) * (Arrow_Width / 2)
    
    --Calcutate point F from A Start position, 10% of total length
    local F_X = Start_X + math.cos(math.rad(Angle + Angle_Offset)) * ((Arrow_Length / 2) - (Arrow_Length/100) * 10)
    local F_Y = Start_Y + math.sin(math.rad(Angle + Angle_Offset)) * ((Arrow_Length / 2) - (Arrow_Length/100) * 10)

    lcd.drawLine(D_X,D_Y,C_X,C_Y) 
    lcd.drawLine(C_X,C_Y,E_X,E_Y)
    
    if Style > 0 then
      lcd.drawLine(E_X,E_Y,F_X,F_Y)
      lcd.drawLine(F_X,F_Y,D_X,D_Y)
    else
      lcd.drawLine(E_X,E_Y,D_X,D_Y)
    end
end







-------------------------------------------------------------------------------------------------------------------
-- Function to Draw a bargraph
-------------------------------------------------------------------------------------------------------------------
local function drawBargraph(x,y, size,invert,background,gradient,color,value,min,max) 
  
    --[[
      x          : X Coordinate
      y          : Y Coordinate
      size       : multiplication factor, 1 = Default 10px height
      invert     : true = right aligned, false = left aligned
      background : true = grey bar background, false = none
      gradient   : true = color gradient on, false = off
      color      : When gradient = false, use custom color i.e lcd.RGB(r,g,b)
      value      : value to work with
      min        : min value for bar indication range
      max        : max value for bar indication range
   --]]
   
    local Bar_Value = (value - min) / (max - min) * 100 
    local Xpos1,Xpos2,Xpos3,Xpos4,Xpos5
     
    if invert then 
      Xpos1 = (12 * size) - (0 * size) 
      Xpos2 = (12 * size) - (3 * size) 
      Xpos3 = (12 * size) - (6 * size) 
      Xpos4 = (12 * size) - (9 * size) 
      Xpos5 = (12 * size) - (12 * size) 
    else 
       Xpos1 = 0 * size 
      Xpos2 = 3 * size 
      Xpos3 = 6 * size 
      Xpos4 = 9 * size 
      Xpos5 = 12 * size 
    end 
     
    local Bar1 = 5 
    local Bar2 = 20 
    local Bar3 = 40 
    local Bar4 = 60 
    local Bar5 = 80     
     
    local Height1 = 2 * size 
    local Height2 = 4 * size 
    local Height3 = 6 * size 
    local Height4 = 8 * size 
    local Height5 = 10 * size 
     
     
    if background then 
      lcd.color(lcd.RGB(150,150,150)) 
      lcd.drawFilledRectangle(x + Xpos1,y + Height5,2 * size,- Height1) 
      lcd.drawFilledRectangle(x + Xpos2,y + Height5,2 * size,- Height2) 
      lcd.drawFilledRectangle(x + Xpos3,y + Height5,2 * size,- Height3) 
      lcd.drawFilledRectangle(x + Xpos4,y + Height5,2 * size,- Height4) 
      lcd.drawFilledRectangle(x + Xpos5,y + Height5,2 * size,- Height5)     
    end 
     
    if Bar_Value > Bar1 then   
      if gradient then
        lcd.color(RED) 
      else
        lcd.color(color)        
      end
      lcd.drawFilledRectangle(x + Xpos1,y + Height5,2 * size,- Height1) 
    end 
    if Bar_Value > Bar2 then 
      if gradient then
        lcd.color(ORANGE) 
      else
        lcd.color(color)        
      end
      lcd.drawFilledRectangle(x + Xpos2,y + Height5,2 * size,- Height2) 
    end 
    if Bar_Value > Bar3 then 
      if gradient then
        lcd.color(YELLOW)         
      else
        lcd.color(color)
      end
      lcd.drawFilledRectangle(x + Xpos3,y + Height5,2 * size,- Height3) 
    end 
    if Bar_Value > Bar4 then 
      if gradient then
        lcd.color(lcd.RGB(0,200,0))         
      else
        lcd.color(color)
      end
      lcd.drawFilledRectangle(x + Xpos4,y + Height5,2 * size,- Height4) 
    end 
    if Bar_Value > Bar5 then 
      if gradient then
        lcd.color(GREEN) 
      else      
        lcd.color(color)
      end
      lcd.drawFilledRectangle(x + Xpos5,y + Height5,2 * size,- Height5) 
    end 
 
end









-------------------------------------------------------------------------------------------------------------------
-- Function to Validate all sources, otherwise return default values.
-------------------------------------------------------------------------------------------------------------------
local function ValidateSources(widget)
    if widget.SPEED == nil then
        widget.SPEED = 0
    end    
    
    if widget.SPEED_UNIT == nil then
        widget.SPEED_UNIT = 0
    end
    
    if widget.ALTITUDE == nil then
        widget.ALTITUDE = 0
    end       
    
    if widget.ALTITUDE_UNIT == nil then
        widget.ALTITUDE_UNIT = 0
    end    
    
    if system.getSource({category=CATEGORY_SYSTEM, member=MAIN_VOLTAGE}) ~= nil then
      widget.TX_VOLTAGE = system.getSource({category=CATEGORY_SYSTEM, member=MAIN_VOLTAGE}):value()
    else
      widget.TX_VOLTAGE = 0
    end
    
    if widget.RSSI == nil then
        widget.RSSI = 0
    end  
    
end








-------------------------------------------------------------------------------------------------------------------
-- Calculates LCD X/Y Position on map from GPS coordinates
-------------------------------------------------------------------------------------------------------------------
local function CalcLCDPosition(widget)
    local lcd_width, lcd_height = lcd.getWindowSize()
    -- Calculates position on LCD of current GPS position
    widget.GpsPosX  = math.floor(lcd_width*((widget.GPSLONG - widget.MapWest)/(widget.MapEast - widget.MapWest)))
    widget.GpsPosY  = math.floor(lcd_height*((widget.MapNorth - widget.GPSLAT)/(widget.MapNorth - widget.MapSouth)))
end







-------------------------------------------------------------------------------------------------------------------
-- Sets home position
-------------------------------------------------------------------------------------------------------------------
local function SetHome(widget)
  local lcd_width, lcd_height = lcd.getWindowSize()
  if widget.GPSLAT ~= 0 and widget.GPSLONG ~= 0 then
    if ForceHome then
        widget.HomeLat = widget.GPSLAT
        widget.HomeLong = widget.GPSLONG
        ForceHome = false
        HomeSet = true
    end
    widget.HomePosX = math.floor(lcd_width*((widget.HomeLong - widget.MapWest)/(widget.MapEast - widget.MapWest)))
    widget.HomePosY = math.floor(lcd_height*((widget.MapNorth - widget.HomeLat)/(widget.MapNorth - widget.MapSouth)))
  end
end









-------------------------------------------------------------------------------------------------------------------
-- Checks if Reset is triggered
-------------------------------------------------------------------------------------------------------------------
local function CheckSources(widget)
  -- Checks if Reset source is triggered, if so then forces a new Home init.
  if widget.rstValue == 1024 then
    ForceHome = true
  end
end






-------------------------------------------------------------------------------------------------------------------
-- Function to calculated bearing angle between 2 coordinates
-------------------------------------------------------------------------------------------------------------------
function CalcBearing(widget,PrevLat,PrevLong,NewLat,NewLong)
  local yCalc = math.sin(math.rad(NewLong)-math.rad(PrevLong)) * math.cos(math.rad(NewLat))
  local xCalc = math.cos(math.rad(PrevLat)) * math.sin(math.rad(NewLat)) - math.sin(math.rad(PrevLat)) * math.cos(math.rad(NewLat)) * math.cos(math.rad(NewLat) - math.rad(PrevLat))
  local Bearing = math.deg(math.atan(yCalc,xCalc))
  if Bearing < 0 then
    Bearing = 360 + Bearing
  end   
  return Bearing
end






-------------------------------------------------------------------------------------------------------------------
-- Function to calculate distance between 2 coordinates
-------------------------------------------------------------------------------------------------------------------
function CalcDistance(widget,PrevLat,PrevLong,NewLat,NewLong,unit)
  local earthRadius = 0
  if unit == 1 then
    earthRadius = 20902000  --feet  --3958.8 miles
  else
    earthRadius = 6371000   --meters
  end
  local dLat = math.rad(NewLat-PrevLat)
  local dLon = math.rad(NewLong-PrevLong)
  PrevLat = math.rad(PrevLat)
  NewLat = math.rad(NewLat)
  local a = math.sin(dLat/2) * math.sin(dLat/2) + math.sin(dLon/2) * math.sin(dLon/2) * math.cos(PrevLat) * math.cos(NewLat) 
  local c = 2 * math.atan(math.sqrt(a), math.sqrt(1-a))
  return (earthRadius * c)
end  








-------------------------------------------------------------------------------------------------------------------
-- Function to Convert Decimal to Degrees, Minutes, Seconds
-------------------------------------------------------------------------------------------------------------------
local function dec2deg(widget,decimal)
  local Degrees = math.floor(decimal)
  local Minutes = math.floor((decimal - Degrees) * 60)
  local Seconds = (((decimal - Degrees) * 60) - Minutes) * 60
  return Degrees, Minutes, Seconds
end








-------------------------------------------------------------------------------------------------------------------
-- Function to Build Decimal, Minutes, Seconds String
-------------------------------------------------------------------------------------------------------------------
local function BuildDMSstr(widget)
    -- Converts the gps coordinates to Degrees,Minutes,Seconds
    local LatD,LatM,LatS = dec2deg(widget,widget.GPSLAT)
    local LongD,LongM,LongS = dec2deg(widget,widget.GPSLONG)
    DMSLatString  = widget.NS..LatD.."°"..LatM.."'"..string.format("%.2f",LatS)..'"'
    DMSLongString = widget.EW..LongD.."°"..LongM.."'"..string.format("%.2f",LongS)..'"'
end



--[[
09 = UNIT_CENTIMETER           "cm"
10 = UNIT_METER                "m"
11 = UNIT_FOOT                 "ft"
15 = UNIT_KPH                  "km/h"
16 = UNIT_MPH                  "mph"
17 = UNIT_KNOT                 "knopen"
--]]
local function ConvertAltitude(widget)
-- 0 = Metric m/kmh, 1 = Imperial ft/mph
  if widget.unit == 0 then
    if widget.ALTITUDE_UNIT == 9 then
      ALTITUDE = widget.ALTITUDE * 0.01
    elseif widget.ALTITUDE_UNIT == 10 then
      ALTITUDE = widget.ALTITUDE 
    elseif widget.ALTITUDE_UNIT == 11 then
      ALTITUDE = widget.ALTITUDE * 0.3048
    else
      ALTITUDE = 0
    end
  else
    if widget.ALTITUDE_UNIT == 9 then
      ALTITUDE = widget.ALTITUDE * 0.032808399
    elseif widget.ALTITUDE_UNIT == 10 then
      ALTITUDE = widget.ALTITUDE * 3.2808399  
    elseif widget.ALTITUDE_UNIT == 11 then
      ALTITUDE = widget.ALTITUDE
    else
      ALTITUDE =0
    end   
  end
  return ALTITUDE
end

local function ConvertSpeed(widget)
  if widget.unit == 0 then
    if widget.SPEED_UNIT == 15 then
      SPEED = widget.SPEED 
    elseif widget.SPEED_UNIT == 16 then
      SPEED = widget.SPEED * 1.609344
    elseif widget.SPEED_UNIT == 17 then
      SPEED = widget.SPEED * 1.852
    else
      SPEED = 0
    end
  else
    if widget.SPEED_UNIT == 15 then
      SPEED = widget.SPEED * 0.621371192
    elseif widget.SPEED_UNIT == 16 then
      SPEED = widget.SPEED  
    elseif widget.SPEED_UNIT == 17 then
      SPEED = widget.SPEED * 1.15077945
    else
      SPEED = 0
    end  
  end
  return SPEED
end




----------------
-- Draws the HUD
-------------------------------------------------------------------------------------------------------------------
local function DrawHUD(widget)
  if Draw_LCD then
    local lcd_width, lcd_height = lcd.getWindowSize()  

  
    if widget.GPSLAT > 0 then
      widget.NS = "N"
    else
     widget.NS = "S"
    end

    if widget.GPSLONG > 0 then
      widget.EW = "E"
    else
      widget.EW = "W"
    end
    
    if widget.unit == 1 then
      widget.FM = "ft"
      widget.SPD = "mph"
    else
      widget.FM = "m"
      widget.SPD = "Km/h"
    end
    
    
    lcd.pen(SOLID)
    --Setup display layout
    lcd.color(lcd.RGB(128,128,128,0.8)) -- 80% Opacity
 
    local Ya,Yb,Yc,Xa,Xaa,Xb,Xbb,Xc,Xcc,Title_X,Title_Y,TX_Voltage_X,TX_Voltage_Y,RSSI_X,RSSI_Y,TX_Voltage_Bar_X,TX_Voltage_Bar_Y,RSSI_Bar_X,RSSI_Bar_Y,Map_Distance
    
    if LCD_Type == 0 then --X10/12
      TX_Voltage_X      = 2
      TX_Voltage_Y      = 0
      TX_Voltage_Bar_X  = 80
      TX_Voltage_Bar_Y  = 2      
      
      Title_X           = 240
      Title_Y           = 0
      RSSI_X            = 380
      RSSI_Y            = 0
      RSSI_Bar_X        = 460
      RSSI_Bar_Y        = 2     
      
      Bar_Size          = 1.2
            
      Xa                = 2
      Xaa               = 45
      Xb                = 150
      Xbb               = 210
      Xc                = 285
      Xcc               = 340
      
      Ya                = 238
      Yb                = 254
      
      lcd.drawFilledRectangle(0,0,480,16)
      lcd.drawFilledRectangle(0,238,480,34)       

    elseif LCD_Type == 1 then -- X20
      TX_Voltage_X      = 5
      TX_Voltage_Y      = 0
      TX_Voltage_Bar_X  = 125
      TX_Voltage_Bar_Y  = 2
      
      Title_X           = 400
      Title_Y           = 0
      RSSI_X            = 650
      RSSI_Y            = 0
      RSSI_Bar_X        = 765
      RSSI_Bar_Y        = 2
      
      Bar_Size          = 2
            
      Xa                = 5
      Xaa               = 75
      Xb                = 260
      Xbb               = 355
      Xc                = 500
      Xcc               = 590
      
      Ya                = 422
      Yb                = 450
      
      lcd.drawFilledRectangle(0,0,800,24)
      lcd.drawFilledRectangle(0,420,800,60)      
      
    end
    
    lcd.color(widget.HUD_Text_Color)
    if LCD_Type == 0 then
      lcd.font(FONT_STD)
    elseif LCD_Type == 1 then
      lcd.font(FONT_BOLD)
    end

    -- Top Bar
    lcd.drawText(TX_Voltage_X,TX_Voltage_Y,"BATT: "..widget.TX_VOLTAGE.."V",LEFT)
    lcd.drawText(Title_X,Title_Y,Title.." "..Version,CENTERED)
    lcd.drawText(RSSI_X,RSSI_Y,"RSSI: "..string.format("%.0f",widget.RSSI).."%",LEFT)
   
    drawBargraph(TX_Voltage_Bar_X,TX_Voltage_Bar_Y, Bar_Size,false,true,true,nil,widget.TX_VOLTAGE,7.0,8.4)    
    drawBargraph(RSSI_Bar_X,RSSI_Bar_Y, Bar_Size,false,true,false,lcd.RGB(255,255,255),widget.RSSI,30,100)     
    if LCD_Type == 0 then
      lcd.font(FONT_BOLD)
    elseif LCD_Type == 1 then
      lcd.font(FONT_BOLD)
    end    
    

    Map_Distance = (CalcDistance(widget,widget.MapNorth,widget.MapWest,widget.MapNorth,widget.MapEast,widget.unit) / 10)
    
    local DistanceBar_X,DistanceBar_Y
    
    DistanceBar_X = lcd_width - ((lcd_width/10) + 10)
    DistanceBar_Y = Ya + 10
    
    lcd.color(BLUE)
    lcd.drawFilledRectangle(DistanceBar_X,DistanceBar_Y,(lcd_width / 10),4)
    lcd.color(RED)
    lcd.drawFilledRectangle(DistanceBar_X , DistanceBar_Y - 5,2,14)
    lcd.drawFilledRectangle(DistanceBar_X + ((lcd_width/10) - 2), DistanceBar_Y - 5,2,14)
    
    lcd.color(widget.HUD_Text_Color)
    
    lcd.drawText(DistanceBar_X + ((lcd_width/10) /2),Yb,string.format("%.0f",Map_Distance)..widget.FM,CENTERED)
    
      lcd.drawText(Xa,Ya,"LAT:",LEFT)
      lcd.drawText(Xa,Yb,"LONG:",LEFT)    
    
    if widget.GPS_Annotation == 0 then
      lcd.drawText(Xaa,Ya,DMSLatString,LEFT)
      lcd.drawText(Xaa,Yb,DMSLongString,LEFT)    
    else
      lcd.drawText(Xaa,Ya,widget.NS..string.format("%.6f",widget.GPSLAT),LEFT)
      lcd.drawText(Xaa,Yb,widget.EW..string.format("%.6f",widget.GPSLONG),LEFT)
    end
         
    


    local ALT = ConvertAltitude(widget)
    local SPD = ConvertSpeed(widget)

    lcd.drawText(Xb,Ya,"Speed:",LEFT)
    lcd.drawText(Xb,Yb,"Altitude:",LEFT)
    lcd.drawText(Xc,Ya,"Course:",LEFT)
    
    lcd.drawText(Xbb,Ya,string.format("%.0f",SPD)..widget.SPD,LEFT)
    lcd.drawText(Xbb,Yb,string.format("%.0f",ALT)..widget.FM,LEFT)
    lcd.drawText(Xcc,Ya,string.format("%.0f",Bearing).."°",LEFT)
    
    if HomeSet then    
      lcd.drawText(Xc,Yb,"Bearing:", LEFT)
      lcd.drawText(Xcc,Yb,string.format("%.0f",math.floor(CalcBearing(widget,widget.HomeLat,widget.HomeLong,widget.GPSLAT,widget.GPSLONG))).."°", LEFT)      
    end
  end
end







-------------------------------------------------------------------------------------------------------------------
-- Checks if correct display type is used and sets LCD_Type flag
-------------------------------------------------------------------------------------------------------------------
local function CheckDisplayType(widget)
    local lcd_width, lcd_height = lcd.getWindowSize()  
    if lcd_width == 800 and lcd_height == 480 then
      LCD_Type = 1
      Run_Script = true
    elseif lcd_width == 480 and lcd_height == 272 then
      LCD_Type = 0
      Run_Script = true
    else
      lcd.font(FONT_STD)
      lcd.color(WHITE)
      lcd.drawText(lcd_width /2,lcd_height /2 -10, "ONLY FULLSCREEN",CENTERED)  
      lcd.drawText(lcd_width /2,lcd_height /2 +10, "DISABLE TITLE",CENTERED)  
      Run_Script = false
    end  
end



-------------------------------------------------------------------------------------------------------------------
-- Draws the Plane
-------------------------------------------------------------------------------------------------------------------
local function DrawPlane(widget)
  if Draw_LCD then
    local lcd_width, lcd_height = lcd.getWindowSize() 
    if widget.PlaneVisible then
      lcd.color(widget.ArrowColor)
      -- Draws the GPS Position Dot
      -- lcd.drawFilledCircle(widget.GpsPosX,widget.GpsPosY,5)
      
      --local Bearing
      local Distance = CalcDistance(widget,widget.GPSLAT,widget.GPSLONG,TempLat,TempLong,widget.unit)
      if Distance == nil then
        Distance = 0
      end
      
      if widget.Calculate_Bearing then
        -- Checks if there is any movement between current and previous position
        -- If so then also check if this movement is bigger then widget.Update_Distance
        -- If both conditions meet, then update heading angle.
        if (widget.GPSLAT ~= TempLat or widget.GPSLONG ~= TempLong) and Distance > widget.Update_Distance then
          Bearing = CalcBearing(widget,TempLat,TempLong,widget.GPSLAT,widget.GPSLONG)
          TempLat = widget.GPSLAT
          TempLong = widget.GPSLONG
        -- Checks if there is no movement, then return previous heading angle.
        elseif widget.GPSLAT == TempLat and widget.GPSLONG == TempLong and Distance == 0 then
          Bearing = Heading_Previous
        -- return previous heading angle in any other case.
        else
          Bearing = Heading_Previous
        end
      else
        -- If Bearing 
        if widget.COURSE ~= nil then
          Bearing = widget.COURSE
        end
      end

        lcd.pen(SOLID)
        local w,h
        if LCD_Type == 0 then
          w = 15
          h = 30
        elseif LCD_Type == 1 then
          w = 30
          h = 50
        end

        drawArrow(widget.GpsPosX,widget.GpsPosY,w,h,Bearing,90,2,widget)
        drawArrow(widget.GpsPosX,widget.GpsPosY,(w/100)*70,(h/100)*80,Bearing,90,2,widget)
        drawArrow(widget.GpsPosX,widget.GpsPosY,(w/100)*30,(h/100)*60,Bearing,90,2,widget)  
        
        Heading_Previous = Bearing

    elseif widget.PlaneVisible == false then
      lcd.font(FONT_XXL)
      DrawAlertBox(widget,"OUT OF RANGE", WHITE, lcd.RGB(255,0,0,0.4))
    end  
  end
end








-------------------------------------------------------------------------------------------------------------------
-- Draws the Home Position
-------------------------------------------------------------------------------------------------------------------
local function DrawHomePosition(widget)
  local lcd_width, lcd_height = lcd.getWindowSize()  
  if Draw_LCD then
    if HomeSet then
      local Radius
      if LCD_Type == 0 then
        Radius = 8
      else
        Radius = 15
      end
      -- Draws the Home Circle and Windsock
      lcd.color(widget.LineColor)
      lcd.drawCircle(widget.HomePosX,widget.HomePosY,Radius)
      lcd.drawBitmap(widget.HomePosX-30,widget.HomePosY-30,Windsock,0,0)
   
      -- Draws the line between Home and Plane
      lcd.color(widget.LineColor)
      lcd.pen(DOTTED)
      lcd.drawLine(widget.HomePosX,widget.HomePosY,widget.GpsPosX,widget.GpsPosY)
      
      -- Calculates the middle LCD X/Y point between gps and home
      local MidLosX = ((widget.GpsPosX + widget.HomePosX)/2)
      local MidLosY = ((widget.GpsPosY + widget.HomePosY)/2)
      if MidLosX < (lcd_width /8) then
        MidLosX = (lcd_width /8)
      elseif MidLosX > (lcd_width - (lcd_width /8)) then
        MidLosX = lcd_width - (lcd_width /8)
      end
      if MidLosY < (lcd_height /4) then
        MidLosY = (lcd_height /4)
      elseif MidLosY > (lcd_height - (lcd_height /4)) then
        MidLosY = lcd_height - (lcd_height /4)
      end
      
      -- Draws a circle arround plane to midpoint of line
      lcd.pen(DOTTED)
      lcd.color(MAGENTA)
      lcd.drawCircle(widget.GpsPosX,widget.GpsPosY,CalcRadius(widget.GpsPosX,widget.GpsPosY,MidLosX,MidLosY))
      
      -- Draws the Distance on next to the line between Home and Plane
      lcd.font(FONT_STD)
      lcd.color(widget.Distance_Text_Color)
      local text_w, text_h = lcd.getTextSize("")
      lcd.drawText(MidLosX, MidLosY - (text_h /2), math.floor(CalcDistance(widget,widget.GPSLAT,widget.GPSLONG,widget.HomeLat,widget.HomeLong,widget.unit))..widget.FM , CENTERED)
    end
  end
end





-------------------------------------------------------------------------------------------------------------------
-- Checks if valid GPS values are available otherwise display No Signal
-------------------------------------------------------------------------------------------------------------------
local function CheckGPS(widget)
    local lcd_width, lcd_height = lcd.getWindowSize()  
    if widget.GPSSource == nil or widget.GPSLAT < -90 or widget.GPSLAT > 90 or widget.GPSLONG < -180 or widget.GPSLONG > 180 then
      lcd.font(FONT_XXL)
      DrawAlertBox(widget,"NO GPS SIGNAL", WHITE, lcd.RGB(255,0,0,0.4))
      Draw_LCD = false
      return
    else
      Draw_LCD = true
    end
end








-------------------------------------------------------------------------------------------------------------------
-- Checks if Plane is visible on the map
-------------------------------------------------------------------------------------------------------------------
local function CheckPlaneOnMap(widget)
    -- Checks if plane is visible on the map
    if widget.GPSLAT < widget.MapNorth and widget.GPSLAT > widget.MapSouth and widget.GPSLONG < widget.MapEast and widget.GPSLONG > widget.MapWest then
      widget.PlaneVisible = true
    else
      widget.PlaneVisible = false
    end
end






local function paint(widget)
    CheckDisplayType(widget)    -- Checks wheter run on X20 or X10/X12
    
    if Run_Script then
    
      ValidateSources(widget)     -- Validates Sources otherwise return default values
      CheckSources(widget)        -- Checks if sates of sources are changed
      ReadMapCoordinates(widget)  -- Reads the coordinates of the corresponding Map Image
      CalcLCDPosition(widget)     -- Calls function to calculate LCD X/Y position from current GPS position
      SetHome(widget)             -- Stores new Home Position on Reset
      CheckPlaneOnMap(widget)     -- Check if Plane is visible on the map
      if mapImage ~= nil then
        lcd.drawBitmap(0, 0, mapImage, lcd_width, lcd_height)  -- Draws the map image
      end
      CheckGPS(widget)            -- Checks if valid GPS signal is preset otherwise return
      DrawHomePosition(widget)    -- Draws Home Position
      DrawPlane(widget)           -- Draws Arrow or Out of range
      BuildDMSstr(widget)         -- Builds DMS strings
      DrawHUD(widget)             -- Draws HUD
   
    end
end




local function wakeup(widget)
    if widget.ResetSource then
        local newValue = widget.ResetSource:value()
        if widget.rstValue ~= newValue then
            widget.rstValue = newValue
            lcd.invalidate()
        end
    end

    if widget.GPSSource then
      local LatValue = widget.GPSSource:value(OPTION_LATITUDE)
      local LongValue = widget.GPSSource:value(OPTION_LONGITUDE)
      if widget.GPSLAT ~= LatValue or widget.GPSLONG ~= LongValue then
        widget.GPSLAT = LatValue
        widget.GPSLONG = LongValue
        lcd.invalidate()
      end
    end
    
    if widget.SpeedSource then
      local SpeedValue = widget.SpeedSource:value()
      local SpeedUnit = widget.SpeedSource:unit()
      if widget.SPEED ~= SpeedValue then
        widget.SPEED = SpeedValue
        lcd.invalidate()
      end
        if widget.SPEED_UNIT ~= SpeedUnit then
        widget.SPEED_UNIT = SpeedUnit
        lcd.invalidate()
      end
    end
    
    if widget.AltitudeSource then
      local AltitudeValue = widget.AltitudeSource:value()
      local AltitudeUnit = widget.AltitudeSource:unit()
      if widget.ALTITUDE ~= AltitudeValue then
        widget.ALTITUDE = AltitudeValue
        lcd.invalidate()
      end
      if widget.ALTITUDE_UNIT ~= AltitudeUnit then
        widget.ALTITUDE_UNIT = AltitudeUnit
        lcd.invalidate()
      end      
    end   
    
    if widget.CourseSource then
      local CourseValue = widget.CourseSource:value()
      if widget.COURSE ~= CourseValue then
        widget.COURSE = CourseValue
        lcd.invalidate()
      end
    end     
   
    if widget.RSSISource then
      local RSSIValue = widget.RSSISource:value()
      if widget.RSSI ~= RSSIValue then
        widget.RSSI = RSSIValue
        lcd.invalidate()
      end
    end      
    
end

local function configure(widget)
 
 dofile("/scripts/h4lgpsmap/maps/mapnames.lua")
 
 local Map1 = Map_name_1
 local Map2 = Map_name_2
 local Map3 = Map_name_3
 local Map4 = Map_name_4
 local Map5 = Map_name_5
 local Map6 = Map_name_6
 local Map7 = Map_name_7
 local Map8 = Map_name_8
 
 -- Map select
    line = form.addLine("Select Map")
    local field_map_select = form.addChoiceField(line, form.getFieldSlots(line)[0], {{Map1, 0}, {Map2, 1}, {Map3, 2}, {Map4, 3}, {Map5, 4}, {Map6, 5}, {Map7, 6}, {Map8, 7}}, function() return widget.Map_Select end, function(value) widget.Map_Select = value end)  
 
  -- Units
    line = form.addLine("Units")
    local field_units = form.addChoiceField(line, form.getFieldSlots(line)[0], {{"Metric", 0}, {"Imperial", 1}}, function() return widget.unit end, function(value) widget.unit = value end)    
 
  -- GPS Source
    line = form.addLine("GPS Source")
    form.addSourceField(line, nil, function() return widget.GPSSource end, function(value) widget.GPSSource = value end)
    
  -- Speed Source
    line = form.addLine("Speed Source")
    form.addSourceField(line, nil, function() return widget.SpeedSource end, function(value) widget.SpeedSource = value end)    
    
  -- Altitude Source
    line = form.addLine("Altitude Source")
    form.addSourceField(line, nil, function() return widget.AltitudeSource end, function(value) widget.AltitudeSource = value end)   
    
  -- RSSI Source
    line = form.addLine("RSSI Source")
    form.addSourceField(line, nil, function() return widget.RSSISource end, function(value) widget.RSSISource = value end)   
    
  -- Reset Source
    line = form.addLine("Reset Source")
    form.addSourceField(line, nil, function() return widget.ResetSource end, function(value) widget.ResetSource = value end)    
    
  -- Course Source
    line = form.addLine("Course Source")
    widget.field_course_source = form.addSourceField(line, nil, function() return widget.CourseSource end, function(value) widget.CourseSource = value end)      
    widget.field_course_source:enable(not widget.Calculate_Bearing)
    
  -- Calculate GPS Course
    line = form.addLine("Calculate Course")
    local field_calc_bearing = form.addBooleanField(line, form.getFieldSlots(line)[0], function() return widget.Calculate_Bearing end,
      function(value)
        widget.Calculate_Bearing = value
        widget.field_update_distance:enable(value)
        widget.field_course_source:enable(not value)
      end)    
    
  -- Update Course after x Distance
    line = form.addLine("Update Distance, m/ft")
    --local slots = form.getFieldSlots(line, {0})
    widget.field_update_distance = form.addNumberField(line, nil, 0, 1000, function() return widget.Update_Distance end, function(value) widget.Update_Distance = value end)  
    widget.field_update_distance:enable(widget.Calculate_Bearing) 
    
  -- Annotation DMS/Decimal
    line = form.addLine("GPS Coordinates")
    local field_gps_annotation = form.addChoiceField(line, form.getFieldSlots(line)[0], {{"Degrees,Minutes,Seconds", 0},{"Decimal", 1}}, function() return widget.GPS_Annotation end, function(value) widget.GPS_Annotation = value end)      
  
   
  -- Arrow Color
    line = form.addLine("Arrow Color")
    local field_arrowcolor = form.addColorField(line, nil, function() return widget.ArrowColor end, function(color) widget.ArrowColor = color end)   
    
  -- HUD Text Color
    line = form.addLine("HUD Text Color")
    local field_hudtextcolor = form.addColorField(line, nil, function() return widget.HUD_Text_Color end, function(color) widget.HUD_Text_Color = color end)  
    
  -- Distance Text Color
    line = form.addLine("Distance Text Color")
    local field_disttextcolor = form.addColorField(line, nil, function() return widget.Distance_Text_Color end, function(color) widget.Distance_Text_Color = color end)      
    
  -- Line Color
    line = form.addLine("Line Color")
    local field_linecolor = form.addColorField(line, nil, function() return widget.LineColor end, function(color) widget.LineColor = color end)      
   
 
 

 
end

local function read(widget)
    widget.GPSSource          = storage.read("GPS_Source")
    widget.SpeedSource        = storage.read("Speed_Source")
    widget.AltitudeSource     = storage.read("Altitude_Source")
    widget.CourseSource       = storage.read("Course_Source")
    widget.ResetSource        = storage.read("Reset_Source")
    widget.RSSISource         = storage.read("RSSI_Source")
    widget.unit               = storage.read("Unit")
    widget.GPS_Annotation     = storage.read("GPS_Annotation")
    widget.ArrowColor         = storage.read("ArrowColor")
    widget.HUD_Text_Color     = storage.read("HUD_Text_Color")
    widget.Distance_Text_Color= storage.read("Distance_Text_Color")
    widget.LineColor          = storage.read("LineColor")
    widget.Calculate_Bearing  = storage.read("Calculate_Bearing")
    widget.Update_Distance    = storage.read("Update_Distance")
    widget.Map_Select         = storage.read("Map_Select")
end

local function write(widget)    
    storage.write("GPS_Source"          , widget.GPSSource)
    storage.write("Speed_Source"        , widget.SpeedSource)
    storage.write("Altitude_Source"     , widget.AltitudeSource)
    storage.write("Course_Source"       , widget.CourseSource)
    storage.write("Reset_Source"        , widget.ResetSource)
    storage.write("RSSI_Source"         , widget.RSSISource)
    storage.write("Unit"                , widget.unit)
    storage.write("GPS_Annotation"      , widget.GPS_Annotation)    
    storage.write("ArrowColor"          , widget.ArrowColor)
    storage.write("HUD_Text_Color"      , widget.HUD_Text_Color)
    storage.write("Distance_Text_Color" , widget.Distance_Text_Color)
    storage.write("LineColor"           , widget.LineColor)
    storage.write("Calculate_Bearing"   , widget.Calculate_Bearing)
    storage.write("Update_Distance"     , widget.Update_Distance)
    storage.write("Map_Select"          , widget.Map_Select)

end

local function init()
    Windsock = lcd.loadBitmap("/scripts/h4lgpsmap/images/Windsock.png")
    system.registerWidget({key="gps", name=name, create=create, paint=paint, wakeup=wakeup, configure=configure, read=read, write=write})
end

return {init=init}
