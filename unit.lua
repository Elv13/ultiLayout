--This is the smallest component of a layout. It handle titlebars and (optionally) some other goodies
local print        = print
local common       = require( "ultiLayout.common" )

module("ultiLayout.unit")

function new(cg,c)
    local data = {titlebar = nil, client = c,x=0,y=0,width=0,height=0}
    cg:set_client(c)
    
    function data:update()
        c.hidden = not cg.visible
        c:geometry({x = cg.x, y = cg.y, width = cg.width, height = cg.height})
    end

    function data:gen_vertex(vertex_list)
        return vertex_list
    end

    function data:show_splitters(show,horizontal,vertical) end
    
    function data:set_active(sub_cg)
        c.focus = c
    end
   
    function data:add_child() end

    function data:add_client(c) end
   
   cg:add_signal("visibility::changed",function(_cg,value)
       c.hidden = not value
   end)
   return data
end

common.add_new_layout("unit",new)