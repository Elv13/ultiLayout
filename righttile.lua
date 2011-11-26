local setmetatable = setmetatable
local print        = print
local ipairs       = ipairs
local table        = table
local button       = require( "awful.button" )
local beautiful    = require( "beautiful"    )
local naughty      = require( "naughty"      )
local tag          = require( "awful.tag"    )
local util         = require( "awful.util"   )
local common       = require( "ultiLayout.common" )
local clientGroup  = require( "ultiLayout.clientGroup" )

local capi = { image  = image  ,
               widget = widget }

module("ultiLayout.righttile")

function new(cg,orientation) 
   local data = {}
   data.ratio = {}
   local nb =0
   local isSplit = false
   local subCg = nil
   local mainCg = nil
   
   local function make_room(percentage) --Between 0 and 1
       if nb >= 1 then
           isSplit = true
           cg:childs()[1].width = cg.width * 0.75
       end
   end
   
   function data:update(mainGeo,subGeo)
        if mainCg then
            mainCg:geometry(mainGeo)
            mainCg:repaint()
        end
        if subCg then
            subCg:geometry(subGeo)
            subCg:repaint()
        end
   end
   
    function data:gen_vertex(vertex_list,vertex)
        local prev = nil
        vertex.cg1 = mainCg
        vertex.cg2 = subCg
        if subCg then
            subCg:gen_vertex(vertex_list)
        end
        if mainCg then
            mainCg:gen_vertex(vertex_list)
        end
        table.insert(vertex_list,vertex)
        return vertex_list
    end
   
   function data:add_child(new_cg)
        print("Adding child to righttile")
        nb = nb + 1
        if nb > 1 then
            if not subCg then
                subCg = clientGroup()
                subCg:set_layout(common.get_layout_list()["horizontal"](subCg))
            end
            print("Adding to sub")
            subCg:attach(new_cg)
        else
            if not mainCg then
                mainCg = clientGroup()
                mainCg:set_layout(common.get_layout_list()["horizontal"](mainCg))
            end
            print("adding to main")
            mainCg:attach(new_cg)
        end
        local percent = 1 / nb
        data.ratio[new_cg] = percent
   end
   
   function data:main()
       return mainCg
   end
   
   function data:sub()
       return subCg
   end
   
   return data
end

local function righttile(cg)
    local tile = new(cg,"vertical")
    local data={}
    function data:make_room(percentage) tile:make_room(percentage) end
    function data:gen_vertex(vertex_list) return tile:gen_vertex(vertex_list,common.create_vertex({x=cg.x + tile:main().width,y=cg.y,orientation="vertical",length=cg.height})) end
    function data:add_child(new_cg) tile:add_child(new_cg) end
    function data:update() tile:update({width  = cg.width*0.65, height = cg.height, x = cg.x, y = cg.y},{width  = cg.width*0.35, height = cg.height, x = cg.x+(cg.width*0.65), y = cg.y}) end
    return data
end
common.add_new_layout("righttile",righttile)

local function lefttile(cg)
    local tile = new(cg,"vertical")
    local data={}
    function data:make_room(percentage) tile:make_room(percentage) end
    function data:gen_vertex(vertex_list) return tile:gen_vertex(vertex_list,common.create_vertex({x=tile:main().x,y=cg.y,orientation="vertical",length=cg.height})) end
    function data:add_child(new_cg) tile:add_child(new_cg) end
    function data:update() tile:update({width  = cg.width*0.65, height = cg.height, x = cg.x+(cg.width*0.35), y = cg.y},{width  = cg.width*0.35, height = cg.height, x = cg.x, y = cg.y}) end
    return data
end
common.add_new_layout("lefttile",lefttile)

local function toptile(cg)
    local tile = new(cg,"horizontal")
    local data={}
    function data:make_room(percentage) tile:make_room(percentage) end
    function data:gen_vertex(vertex_list) return tile:gen_vertex(vertex_list,common.create_vertex({x=cg.x,y=cg.y + tile:main().height,orientation="horizontal",length=cg.width})) end
    function data:add_child(new_cg) tile:add_child(new_cg) end
    function data:update() tile:update({width  = cg.width, height = cg.height*0.65, x = cg.x, y = cg.y+(cg.height*0.35)},{width  = cg.width, height = cg.height*0.35, x = cg.x, y = cg.y}) end
    return data
end
common.add_new_layout("topttile",toptile)


local function bottomtile(cg)
    local tile = new(cg,"horizontal")
    local data={}
    function data:make_room(percentage) tile:make_room(percentage) end
    function data:gen_vertex(vertex_list) return tile:gen_vertex(vertex_list,common.create_vertex({x=cg.x,y=tile:main().y,orientation="horizontal",length=cg.width})) end
    function data:add_child(new_cg) tile:add_child(new_cg) end
    function data:update() tile:update({width  = cg.width, height = cg.height*0.65, x = cg.x, y = cg.y},{width  = cg.width, height = cg.height*0.35, x = cg.x, y = cg.y+(cg.height*0.65)}) end
    return data
end
common.add_new_layout("bottomttile",bottomtile)

setmetatable(_M, { __call = function(_, ...) return new(...) end })