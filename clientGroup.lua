local setmetatable = setmetatable
local table        = table
local pairs        = pairs
local print        = print
local type         = type
local ipairs       = ipairs
local debug        = debug
local decorations  = require( "ultiLayout.decoration" )
local object_model = require( "ultiLayout.object_model" )

module("ultiLayout.clientGroup")

local client_to_cg          = {}
local debugCounter = 0
local bigCgRepaintLock =  0

function lock()   bigCgRepaintLock = bigCgRepaintLock+1  end
function unlock() bigCgRepaintLock = bigCgRepaintLock-1 end

function new(parent)
    local data              = { swapable = false }
    local layout            = nil
    local focus             = false
    local client            = nil
    local parent            = parent or nil
    local childs_cg         = {}
    local title             = nil
    local active_cg         = nil
    local deco              = decorations.decoration(data)
    local private_data = {
        floating = false,
        visible  = true,
    }
    for k,v in ipairs({"x","y","width","height"}) do
        private_data[v] = 0
    end
    
    function data:childs()
        return childs_cg
    end
    
    local function all_visible_common(list)
      local to_return = {}
        for k,v in pairs(list) do
            if v.visible == true and (#v:all_visible_childs() > 0 or v.client ~= nil) then
                table.insert(to_return,v)
            end
        end
        return to_return
    end
    
    function data:visible_childs()
        return all_visible_common(self:childs())
    end
    
    function data:all_visible_childs()
        return all_visible_common(self:all_childs())
    end
    
    function data:all_childs()
        local to_return = {}
        for k,v in pairs(self:childs()) do
            local child_childs = v:all_childs()
            for k2,v2 in pairs(child_childs) do
                table.insert(to_return,v2)
            end
            table.insert(to_return,v)
        end
        return to_return
    end
    
    function data:nextChild(aChild)
        local idx = data:cg_to_idx(aChild)
        return childs_cg[idx+1]
    end
    
    function data:previousChild(aChild)
        local idx = data:cg_to_idx(aChild)
        return childs_cg[idx-1]
    end

    function data:all_clients()
        if client ~= nil then
            return {client}
        end
        
        local all_c = {}
        for k,v in pairs(self:childs()) do
            for k2,v2 in pairs(v:all_clients()) do
                table.insert(all_c,v2)
            end
        end
        return all_c
    end
    
    function data:has_client(c)
        if not c then
            return (client ~= nil) and true or false
        end
        local clients = data:all_clients()
        for k,v in pairs(clients) do
            if v == c then
                return true
            end
        end
        return false
    end

    function data:geometry(new,relative)
        if new ~= nil then
            for k,v in ipairs({"x","y","width","height"}) do
                data[v] = new[v] or 0
            end
        end
        return {width = private_data.width or 0, height = private_data.height or 0, x = private_data.x or 0, y = private_data.y or 0}
    end
    
    function data:center()
        return {x=private_data.x+(private_data.width/2),y=private_data.y+(private_data.height/2)}
    end

    function data:set_client(c)
        client = c
        client_to_cg[c] = client_to_cg[c] or {}
        table.insert(client_to_cg[c],self)
    end
    
    function data:has_indirect_parent(cg)
        local current_depth = data
        while current_depth ~= nil do
            if current_depth == cg then return true end
            current_depth = current_depth.parent
        end
        return false
    end
    
    --TODO deprecate in favor of get_unit_from_cg
    function get_units_from_client(c,par)
        if not par then
            return client_to_cg[c]
        else
            print("I am here")
            local to_return = {}
            for k,v in pairs(client_to_cg[c] or {}) do
                if data:has_indirect_parent(par) == true then
                    table.insert(to_return,v)
                end
            end
            return to_return
        end
    end
    
    function data:get_unit(c)
        if layout and layout.units then
            return layout.units[c]
        end
    end

    function data:set_layout(l,...)
        if not l or type(l) ~= "function" then print("No layout to be set"); return end
        layout = l(self,...)
        lock()
        for k,v in ipairs(self:childs()) do
            if not v.floating then
                layout:add_child(v)
            end
        end
        unlock()
        self:repaint()
    end

    function data:detach(child)
        for k,v in pairs(childs_cg) do
            if v == child then
                table.remove(childs_cg,k)
                child.parent = nil
            end
        end
        if parent ~= nil and #childs_cg == 0 then
            if self.keep == true then
                parent:repaint(true)
            else
                data:emit_signal("destroyed")
                self.visible = false
                parent:detach(self)
                self = nil
                return
            end
        end
        self:repaint()
    end
    
    function data:cg_to_idx(cg)
        for k,v in ipairs(childs_cg) do
            if v == cg then return k end
        end
    end
    
    function data:first_swapable_parent()
        local swapable1 = data
        while swapable1 ~= nil and swapable1.swapable == false do
            swapable1 = swapable1.parent
        end
        return swapable1
    end
    
    --It is not called swap because it only do half of the operation
    function data:replace(old_cg,new_cg)
        if old_cg.parent ~= new_cg.parent then
            for k,v in pairs(childs_cg) do
                if v == old_cg then
                    childs_cg[k] = new_cg
                    if self.active == old_cg then
                        self.active = new_cg
                    end
                    self:repaint()
                    self:emit_signal("child::replaced",old_cg,new_cg)
                    return true
                end
            end
        else --This avoid swaping CG back to original state if they are in the same parent CG
            local old_cg_idx, new_cg_idx = self:cg_to_idx(old_cg), self:cg_to_idx(new_cg)
            if old_cg_idx ~= nil and new_cg_idx ~= nil then
                childs_cg[ old_cg_idx ] = new_cg
                childs_cg[ new_cg_idx ] = old_cg
                data:emit_signal("cg::replaced",old_cg,new_cg)
                self:repaint()
                return true
            end
        end
        return false
    end
    
    function data:swap(new_cg)
        if parent ~= nil and new_cg.parent ~= nil then
            local cur_parent   = parent
            local other_parent = new_cg.parent
            parent:replace(self,new_cg)
            if cur_parent ~= other_parent then
                other_parent:replace(new_cg,self)
            end
            new_cg.parent = cur_parent
            new_cg:emit_signal("cg::swapped",self,other_parent)
            self.parent = other_parent
            self:emit_signal("cg::swapped",new_cg,cur_parent)
        end
    end
    
    function data:attach(cg,index)
        if cg.parent == self or cg == self or cg == nil then return end
        --Check if the CG is not already a child of self
        for k,v in pairs(data:childs()) do --TODO all_childs? break splitters
            if v == cg then print("Trying to add a clientgroup that is already a child of itself"); return end
        end
        if cg.parent ~= nil then
            cg.parent:detach(cg)
        end
        cg.parent = data
        cg:add_signal("geometry::changed",function() data:emit_signal("geometry::changed") end)
        
        if layout and cg.floating == false then
            cg = layout:add_child(cg,index)
        end
        
        if cg ~= nil and cg.floating == false then
            if index ~= nil then
                table.insert(childs_cg,index,cg)
            else
                table.insert(childs_cg,cg)
            end
        end
        data:emit_signal("client::attached")
        self:repaint()
        return cg
    end
    
    function data:raise()
        if parent then
            parent.active = self
        end
    end
    
    local function set_active(child_cg)
        if layout.set_active then
            layout:set_active(child_cg)
        end
        child_cg.focus = true
        active_cg = child_cg --TODO check if child
    end
    
    local function set_parent(new_parent)
        if new_parent ~= parent then
            local old_parent = parent
            parent = new_parent
            if old_parent ~= nil then
                old_parent:emit_signal("detached",data)
            end
            data:emit_signal("parent::changed",new_parent,old_parent)
        end
    end
    
    function data:resize(child_cg,w,h)
        local remainingW,remainingH=w,h
        if layout and layout.resize then
            local currentChild = child_cg
            while (remainingW~=0 or remainingH~=0) and currentChild ~= nil do
                remainingW,remainingH = layout:resize(currentChild,remainingW,remainingH)
                if ((remainingW~=0) and remainingW  or remainingH ) > 0 then
                    currentChild = self:nextChild(currentChild)
                else
                    currentChild = self:previousChild(currentChild)
                end
            end
        end
        if parent and (remainingW ~= 0 or remainingH ~= 0) then
            parent:resize(self,remainingW,remainingH)
        elseif remainingW ~= 0 or remainingH ~= 0 then
            print("Nowhere to take space from",self)
        else
            data:repaint()
        end
    end
    
    function data:repaint(force)
        if bigCgRepaintLock == 0 or force == true then
            --print("Track repaint",debug.traceback())
            private_data.workarea = deco:update()
            if layout and data.visible then
                layout:update()
            end
            for k,v in pairs(childs_cg) do
                v:repaint()
            end
        end
    end
    
    local function change_visibility(value)
        if private_data.visible ~= value then
            private_data.visible = value
            lock()
            for k,v in pairs(childs_cg) do
                v.visible = value
            end
            unlock()
            data:emit_signal("visibility::changed",value)
            data:repaint()
        end
    end
    
    local function get_title()
        return (title) and title or (function(allC) return ((#allC == 1) and allC[1].name or #allC.." clients") end)(data:all_clients())
    end
    
    local function set_focus(value)
        if value == focus then return end
        focus = value
        if parent ~= nil then
            parent.focus = value
        end
        if #childs_cg == 1 then
            childs_cg[1].focus = value
            if client then
                client.focus = client
                active_cg = data
            end
        end
        data:emit_signal("focus::changed",value)
    end
    
    local function change_geo(var,new_value)
        if new_value < 0 then return end --It can be normal, but avoid it anyway
        local prev = private_data[var]
        private_data[var] = new_value
        data:emit_signal(var.."::changed",new_value-prev)
        data:emit_signal("geometry::changed")
    end
    
    local set_map = {
        floating = function(value) private_data.floating = value end,
        parent   = function(value) set_parent(value) end,
        visible  = function(value) change_visibility(value);  end,
        title    = function(value) title = value; data:emit_signal("title::changed",value) end,
        focus    = set_focus,
        active   = set_active, --TODO change this
        workarea = false,
    }
    for k,v in pairs({"height", "width","y","x"}) do
        set_map[v] =  function (value) change_geo(v,value) end
    end
    
    local get_map = {
        parent      = function() return parent                   end,
        title       = function() return get_title()              end,
        focus       = function() return focus                    end,
        active      = function() return active_cg                end, --TODO change this
	client      = function() return client                   end,
        layout      = function() return layout                   end,
        decorations = function() return deco                     end,
    }
    
    for k,v in pairs({"height", "width","y","x"}) do
        get_map[v] =  function () return (type(private_data[v]) == "function") and private_data[v]() or private_data[v] end
    end
    
    object_model(data,get_map,set_map,private_data,{always_handle = {visible = true},autogen_getmap = true})
    return data
end

setmetatable(_M, { __call = function(_, ...) return new(...) end , __index = return_data, __newindex = catchGeoChange, __len = function() return #data +4 end})