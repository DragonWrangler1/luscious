
vlf_luscious = {}

local mgp = minetest.get_mapgen_params()
local chunksize = 16 * mgp.chunksize

-- Optimize biome color blending function by caching biome data locally
local biome_cache = {}
function vlf_luscious.get_biome_color(pos)
    local biome_data = minetest.get_biome_data(pos)
    if biome_data and biome_data.biome then
        local biome_name = minetest.get_biome_name(biome_data.biome)
        local biome = minetest.registered_biomes[biome_name]
        if biome and biome.heat_point and biome.humidity_point then
            local heat = math.floor(math.min(math.max(math.floor(biome.heat_point), 0), 100) / 6.6)
            local humidity = math.floor(math.min(math.max(math.floor(biome.humidity_point), 0), 100) / 6.6)
            return heat + (humidity * 16) or 0
        end
    end
    return 136 -- Default palette index
end

function vlf_luscious.blend_biome_color(pos, blend_distance)
    if blend_distance == 0 then
        return vlf_luscious.get_biome_color(pos)
    end

    blend_distance = math.min(blend_distance, 14)
    local heat_total, humidity_total, count = 0, 0, 0
    
    for x = -blend_distance, blend_distance, 2 do
    for z = -blend_distance, blend_distance, 2 do
        local sample_pos = {x = pos.x + x, y = pos.y, z = pos.z + z}
        local cache_key = sample_pos.x .. "," .. sample_pos.z
        if not biome_cache[cache_key] then
            biome_cache[cache_key] = vlf_luscious.get_biome_color(sample_pos)
        end
        local biome_value = biome_cache[cache_key]
        if biome_value then
            heat_total = heat_total + (biome_value % 16) * 6.6
            humidity_total = humidity_total + math.floor(biome_value / 16) * 6.6
            count = count + 1
        end
    end
    end
    
    if count == 0 then return 136 end -- Default palette index
    
    local heat = math.floor(math.min(math.max(math.floor(heat_total / count), 0), 100) / 6.6)
    local humidity = math.floor(math.min(math.max(math.floor(humidity_total / count), 0), 100) / 6.6)
    return heat + (humidity * 16) or 0
end

function vlf_luscious.on_construct(pos)
    local node = minetest.get_node(pos)
    node.param2 = vlf_luscious.blend_biome_color(pos, 2) -- Default blend distance
    minetest.swap_node(pos, node)
end

minetest.register_on_generated(function(minp, maxp, blockseed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
    local param2_data = {}
    
    for z = emin.z, emax.z do
        for y = emin.y, emax.y do
            for x = emin.x, emax.x do
                local pos = {x = x, y = y, z = z}
                local node = minetest.get_node(pos)
                if node.name == "default:dirt_with_grass" then
                    local idx = area:index(x, y, z)
                    param2_data[idx] = vlf_luscious.blend_biome_color(pos, 5)
                end
            end
        end
    end
    vm:set_param2_data(param2_data)
end)

