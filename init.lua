local storage = minetest.get_mod_storage()

beach_party_npcs = {}

local first_names = {
    "Liam", "Olivia", "Noah", "Emma", "Oliver",
    "Ava", "Elijah", "Charlotte", "William", "Sophia",
    "James", "Amelia", "Benjamin", "Isabella", "Lucas",
    "Mia", "Henry", "Evelyn", "Alexander", "Harper",
    "Mason", "Abigail", "Michael", "Emily", "Ella",
    "Elizabeth", "Logan", "Avery", "Jackson", "Sofia",
    "Camila", "Sebastian", "Aria", "Mateo", "Scarlett",
    "Penelope", "Ellie", "Owen", "Theodore", "Layla",
    "Aiden", "Samuel", "Joseph", "John", "David",
    "Wyatt", "Matthew", "Luke", "Grayson", "Leo",
    "Jayden", "Gabriel", "Carter", "Isaac", "Lincoln",
    "Jaxon", "Hunter", "Nathan", "Caleb", "Ryan",
    "Adam", "Christian", "Thomas", "Charles", "Ezra",
    "Christopher", "Andrew", "Joshua", "Isaiah", "Hudson",
    "Elias", "Maverick", "Lucy", "Paisley", "Everly",
    "Kennedy", "Madelyn", "Piper", "Ruby", "Eva",
    "Serenity", "Stella", "Natalie", "Zoe", "Leah",
    "Hazel", "Violet", "Aurora", "Savannah", "Audrey",
    "Brooklyn", "Bella", "Claire", "Skylar", "Lily",
    "Eleanor", "Lillian", "Addison", "Aubrey", "Jack"
}

local npc_textures = {
    "beach_npc.png",
    "beach_npc_2.png",
    "beach_npc_3.png",
    "beach_npc_4.png",
    "beach_npc_5.png",
    "beach_npc_6.png",
}

beach_party_npcs.active_npcs = storage:get_int("active_npcs")
beach_party_npcs.next_name_idx = storage:get_int("next_name_idx")
if beach_party_npcs.next_name_idx < 1 then beach_party_npcs.next_name_idx = 1 end

local function save_storage()
    storage:set_int("active_npcs", beach_party_npcs.active_npcs)
    storage:set_int("next_name_idx", beach_party_npcs.next_name_idx)
end

local function get_next_name()
    if beach_party_npcs.next_name_idx > #first_names then
        return nil
    end
    local name = first_names[beach_party_npcs.next_name_idx]
    beach_party_npcs.next_name_idx = beach_party_npcs.next_name_idx + 1
    save_storage()
    return name
end

local function on_npc_death(npc_name)
    beach_party_npcs.active_npcs = math.max(0, beach_party_npcs.active_npcs - 1)
    if npc_name == "Jack" then
        beach_party_npcs.next_name_idx = 1
    end
    save_storage()
end

local function is_valid_chair(pos)
    local node = minetest.get_node(pos)
    return minetest.get_item_group(node.name, "bed") > 0 or node.name:find("mini_beach_pack:beachchair_")
end

local function is_water(pos)
    local node = minetest.get_node(pos)
    return minetest.get_item_group(node.name, "water") > 0
end

local function find_land_near(pos, radius)
    local positions = minetest.find_nodes_in_area(
        {x = pos.x - radius, y = pos.y - 2, z = pos.z - radius},
        {x = pos.x + radius, y = pos.y + 3, z = pos.z + radius},
        {"default:sand", "default:desert_sand", "default:dirt_with_grass", "default:dirt", "group:soil"}
    )
    if positions and #positions > 0 then
        for _ = 1, 15 do
            local p = positions[math.random(#positions)]
            local above = {x = p.x, y = p.y + 1, z = p.z}
            local node_above = minetest.get_node(above)
            if node_above.name == "air" then
                return above
            end
        end
        return {x = positions[1].x, y = positions[1].y + 1, z = positions[1].z}
    end
    return nil
end

local function set_animation(self, anim)
    if self.current_anim == anim then return end
    self.current_anim = anim
    if anim == "stand" then
        self.object:set_animation({x = 0, y = 79}, 30, 0)
    elseif anim == "walk" then
        self.object:set_animation({x = 168, y = 187}, 30, 0)
    elseif anim == "sit" then
        self.object:set_animation({x = 81, y = 160}, 30, 0)
    elseif anim == "lay" then
        self.object:set_animation({x = 162, y = 166}, 30, 0)
    end
end

local function set_velocity(self, speed, yaw)
    if speed == 0 then
        self.object:set_velocity({x = 0, y = self.object:get_velocity().y, z = 0})
        return
    end
    local v = {
        x = math.sin(yaw) * speed * -1,
        y = self.object:get_velocity().y,
        z = math.cos(yaw) * speed
    }
    self.object:set_velocity(v)
end

minetest.register_entity("beach_party_npcs:npc", {
    initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = {-0.3, 0.0, -0.3, 0.3, 1.7, 0.3},
        visual = "mesh",
        mesh = "beach_npc.b3d",
        textures = {"beach_npc.png"},
        makes_footstep_sound = true,
        stepheight = 1.1,
        nametag = "",
        nametag_color = "#ffffff"
    },
    
    on_activate = function(self, staticdata)
        self.object:set_acceleration({x=0, y=-9.81, z=0})
        self.state = "stand"
        self.timer = 0
        self.talk_count = 0
        self.talked_to = {}
        self.target_pos = nil
        
        local data = {}
        if staticdata ~= "" then
            data = minetest.deserialize(staticdata) or {}
        end
        
        if data.npc_name then
            self.npc_name = data.npc_name
            self.texture = data.texture
            self.talk_count = data.talk_count or 0
        else
            if beach_party_npcs.active_npcs >= 100 then
                self.object:remove()
                return
            end
            
            local name = get_next_name()
            if not name then
                self.object:remove()
                return
            end
            
            self.npc_name = name
            self.texture = npc_textures[math.random(#npc_textures)]
            beach_party_npcs.active_npcs = beach_party_npcs.active_npcs + 1
        end
        
        self.object:set_properties({
            nametag = self.npc_name,
            textures = {self.texture}
        })
        
        set_animation(self, "stand")
    end,
    
    get_staticdata = function(self)
        return minetest.serialize({
            npc_name = self.npc_name,
            texture = self.texture,
            talk_count = self.talk_count
        })
    end,
    
    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        
        -- Buoyancy to prevent drowning
        local in_water = minetest.get_item_group(minetest.get_node(pos).name, "water") > 0
        local in_water_head = minetest.get_item_group(minetest.get_node({x=pos.x, y=pos.y+1, z=pos.z}).name, "water") > 0
        
        if self.state == "lay" then
            self.object:set_acceleration({x=0, y=0, z=0})
            self.object:set_velocity({x=0, y=0, z=0})
        elseif in_water or in_water_head then
            self.object:set_acceleration({x=0, y=2.0, z=0})
            local v = self.object:get_velocity()
            if v.y > 2 then
                self.object:set_velocity({x=v.x, y=2, z=v.z})
            end
        else
            self.object:set_acceleration({x=0, y=-9.81, z=0})
        end

        -- Continuous movement and steering towards target
        if self.target_pos and self.state == "walk" then
            self.walk_timer = (self.walk_timer or 0) + dtime
            if self.walk_timer > 12 then
                -- Stuck timeout, abort walk
                self.state = "stand"
                self.target_pos = nil
                self.walk_timer = 0
                set_velocity(self, 0, 0)
                set_animation(self, "stand")
            else
                local dist = vector.distance(pos, self.target_pos)
                if dist < 1.5 then
                    if self.target_type == "chair" then
                        self.state = "lay"
                        self.object:set_acceleration({x=0, y=0, z=0})
                        self.object:set_velocity({x=0, y=0, z=0})
                        set_animation(self, "sit")
                        
                        local node = minetest.get_node(self.target_pos)
                        local dir = minetest.facedir_to_dir(node.param2)
                        -- Flip yaw by 180 degrees so they face forward (away from backrest)
                        local yaw = math.atan2(dir.x, dir.z)
                        -- Pitch backward (0.4 rad ≈ 23 deg) to recline them nicely on the chair
                        self.object:set_rotation({x = 0.4, y = yaw, z = 0})
                        -- Offset them slightly towards the backrest (which is +dir)
                        self.object:set_pos({
                            x = self.target_pos.x + dir.x * 0.15,
                            y = self.target_pos.y + 0.1,
                            z = self.target_pos.z + dir.z * 0.15
                        })
                    elseif self.target_type == "water" then
                        self.state = "bathe"
                        set_velocity(self, 0, 0)
                        set_animation(self, "stand")
                    else
                        self.state = "stand"
                        set_velocity(self, 0, 0)
                        set_animation(self, "stand")
                    end
                    self.target_pos = nil
                    self.walk_timer = 0
                else
                    local dir = vector.direction(pos, self.target_pos)
                    local yaw = math.atan2(dir.z, dir.x) - math.pi/2
                    self.object:set_yaw(yaw)
                    set_velocity(self, 2, yaw)
                    set_animation(self, "walk")
                    
                    local front = {x = pos.x + dir.x, y = pos.y + 0.5, z = pos.z + dir.z}
                    local node_front = minetest.get_node(front)
                    if minetest.registered_nodes[node_front.name] and minetest.registered_nodes[node_front.name].walkable then
                        local v = self.object:get_velocity()
                        if v.y == 0 and not in_water then
                            self.object:set_velocity({x=v.x, y=5.5, z=v.z})
                        end
                    end
                end
            end
        end

        -- High level decision making every 1.0 second
        self.timer = self.timer + dtime
        if self.timer > 1.0 then
            self.timer = 0
            
            if self.state == "sit" or self.state == "lay" or self.state == "bathe" then
                if math.random() < 0.1 then
                    self.object:set_rotation({x = 0, y = self.object:get_rotation().y, z = 0})
                    if self.state == "bathe" then
                        -- Go back to land!
                        local land_pos = find_land_near(pos, 20)
                        if land_pos then
                            self.target_pos = land_pos
                            self.target_type = "beach"
                            self.state = "walk"
                            self.walk_timer = 0
                            return
                        end
                    end
                    self.state = "stand"
                    self.target_pos = nil
                end
                return
            end
            
            if self.state ~= "talk" then
                for _, obj in pairs(minetest.get_objects_inside_radius(pos, 3)) do
                    if obj ~= self.object and not obj:is_player() and obj:get_luaentity() and obj:get_luaentity().name == "beach_party_npcs:npc" then
                        local other = obj:get_luaentity()
                        if other.state ~= "talk" and not self.talked_to[other.npc_name] then
                            self.state = "talk"
                            other.state = "talk"
                            self.talk_target_timer = 5
                            other.talk_target_timer = 5
                            
                            local p1 = self.object:get_pos()
                            local p2 = other.object:get_pos()
                            local dir = vector.direction(p1, p2)
                            local yaw = math.atan2(dir.z, dir.x) - math.pi/2
                            self.object:set_yaw(yaw)
                            other.object:set_yaw(yaw + math.pi)
                            
                            set_velocity(self, 0, 0)
                            set_velocity(other, 0, 0)
                            set_animation(self, "stand")
                            set_animation(other, "stand")
                            self.target_pos = nil
                            other.target_pos = nil
                            
                            self.talked_to[other.npc_name] = true
                            other.talked_to[self.npc_name] = true
                            self.talk_count = self.talk_count + 1
                            other.talk_count = other.talk_count + 1
                            
                            if self.talk_count >= 10 then
                                self:spawn_new_npc()
                                self.talk_count = 0
                            end
                            if other.talk_count >= 10 then
                                other:spawn_new_npc()
                                other.talk_count = 0
                            end
                            return
                        end
                    end
                end
            end
            
            if self.state == "talk" then
                self.talk_target_timer = (self.talk_target_timer or 0) - 1
                if self.talk_target_timer <= 0 then
                    self.state = "stand"
                end
                return
            end
            
            if not self.target_pos then
                local r = math.random()
                if r < 0.2 then
                    local p = minetest.find_node_near(pos, 25, {"group:bed"})
                    if p and is_valid_chair(p) then
                        self.target_pos = p
                        self.target_type = "chair"
                        self.state = "walk"
                        return
                    end
                elseif r < 0.4 then
                    local p = minetest.find_node_near(pos, 25, {"group:water"})
                    if p then
                        self.target_pos = p
                        self.target_type = "water"
                        self.state = "walk"
                        return
                    end
                end
                
                if math.random() < 0.5 then
                    local target = {
                        x = pos.x + math.random(-25, 25),
                        y = pos.y,
                        z = pos.z + math.random(-25, 25)
                    }
                    -- Adjust wander target Y if we are on land to avoid sinking
                    if not in_water then
                        local land_pos = find_land_near(target, 5)
                        if land_pos then
                            target = land_pos
                        end
                    end
                    self.target_pos = target
                    self.target_type = "wander"
                    self.state = "walk"
                else
                    self.state = "stand"
                    set_velocity(self, 0, 0)
                    set_animation(self, "stand")
                end
            end
        end
    end,
    
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir)
        self.object:set_velocity({x = dir.x * 2, y = 5, z = dir.z * 2})
        local hp = self.object:get_hp() - (tool_capabilities and tool_capabilities.damage_groups.fleshy or 1)
        self.object:set_hp(hp)
        if hp <= 0 then
            on_npc_death(self.npc_name)
        end
    end,
    
    spawn_new_npc = function(self)
        if beach_party_npcs.active_npcs >= 100 then return end
        local pos = self.object:get_pos()
        local r = 50
        local angle = math.random() * math.pi * 2
        local spawn_pos = {
            x = pos.x + math.cos(angle) * r,
            y = pos.y + 10,
            z = pos.z + math.sin(angle) * r
        }
        
        -- try to find surface
        for i = 0, 20 do
            local p = {x=spawn_pos.x, y=spawn_pos.y - i, z=spawn_pos.z}
            local n1 = minetest.get_node(p)
            local n2 = minetest.get_node({x=p.x, y=p.y+1, z=p.z})
            if n1.name ~= "air" and n2.name == "air" then
                spawn_pos.y = p.y + 1
                local obj = minetest.add_entity(spawn_pos, "beach_party_npcs:npc")
                if obj then
                    local ent = obj:get_luaentity()
                    if ent then
                        ent.target_pos = self.object:get_pos()
                        ent.target_type = "wander"
                        ent.state = "walk"
                    end
                end
                break
            end
        end
    end
})

minetest.register_craftitem("beach_party_npcs:npc_egg", {
    description = "Beach Party NPC Spawn Egg",
    inventory_image = "beach_npc_egg.png",
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type == "node" then
            local pos = pointed_thing.above
            if beach_party_npcs.active_npcs < 100 then
                minetest.add_entity(pos, "beach_party_npcs:npc")
                if not minetest.is_creative_enabled(placer:get_player_name()) then
                    itemstack:take_item()
                end
            else
                minetest.chat_send_player(placer:get_player_name(), "NPC cap of 100 reached.")
            end
        end
        return itemstack
    end,
})

minetest.register_chatcommand("clear_npcs", {
    description = "Clear all beach party NPCs and reset counters",
    func = function(name, param)
        local count = 0
        for _, obj in pairs(minetest.luaentities) do
            if obj.name == "beach_party_npcs:npc" then
                obj.object:remove()
                count = count + 1
            end
        end
        beach_party_npcs.active_npcs = 0
        beach_party_npcs.next_name_idx = 1
        save_storage()
        return true, "Cleared " .. count .. " NPCs and reset name cycle."
    end,
})

minetest.log("action", "[beach_party_npcs] loaded.")
