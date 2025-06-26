
rs_luscious = {}

local mgp = minetest.get_mapgen_params()
local chunksize = 16 * mgp.chunksize

-- Pre-calculate constants
local HEAT_HUMIDITY_DIVISOR = 6.6
local DEFAULT_PALETTE_INDEX = 136
local GRASS_NODE_ID = minetest.get_content_id("default:dirt_with_grass")

-- Optimized biome cache with better memory management
local biome_cache = {}
local cache_size = 0
local MAX_CACHE_SIZE = 10000

-- Fast biome color calculation with minimal function calls
local function get_biome_color_fast(x, y, z)
    local cache_key = x .. "," .. z
    local cached = biome_cache[cache_key]
    if cached then
        return cached
    end
    
    local biome_data = minetest.get_biome_data({x = x, y = y, z = z})
    local color = DEFAULT_PALETTE_INDEX
    
    if biome_data and biome_data.biome then
        local biome_name = minetest.get_biome_name(biome_data.biome)
        local biome = minetest.registered_biomes[biome_name]
        if biome and biome.heat_point and biome.humidity_point then
            local heat = math.floor(math.min(math.max(biome.heat_point, 0), 100) / HEAT_HUMIDITY_DIVISOR)
            local humidity = math.floor(math.min(math.max(biome.humidity_point, 0), 100) / HEAT_HUMIDITY_DIVISOR)
            color = heat + (humidity * 16)
        end
    end
    
    -- Cache management to prevent memory bloat
    if cache_size >= MAX_CACHE_SIZE then
        biome_cache = {}
        cache_size = 0
    end
    
    biome_cache[cache_key] = color
    cache_size = cache_size + 1
    return color
end

-- Optimized blending with reduced sampling
local function blend_biome_color_fast(x, y, z, blend_distance)
    if blend_distance == 0 then
        return get_biome_color_fast(x, y, z)
    end
    
    blend_distance = math.min(blend_distance, 8) -- Reduced max distance for performance
    local heat_total, humidity_total, count = 0, 0, 0
    local step = math.max(1, math.floor(blend_distance / 3)) -- Adaptive sampling
    
    for dx = -blend_distance, blend_distance, step do
        for dz = -blend_distance, blend_distance, step do
            local biome_value = get_biome_color_fast(x + dx, y, z + dz)
            if biome_value ~= DEFAULT_PALETTE_INDEX then
                heat_total = heat_total + (biome_value % 16) * HEAT_HUMIDITY_DIVISOR
                humidity_total = humidity_total + math.floor(biome_value / 16) * HEAT_HUMIDITY_DIVISOR
                count = count + 1
            end
        end
    end
    
    if count == 0 then 
        return DEFAULT_PALETTE_INDEX
    end
    
    local heat = math.floor(math.min(math.max(heat_total / count, 0), 100) / HEAT_HUMIDITY_DIVISOR)
    local humidity = math.floor(math.min(math.max(humidity_total / count, 0), 100) / HEAT_HUMIDITY_DIVISOR)
    return heat + (humidity * 16)
end

-- Optimized mapgen callback using voxelmanip efficiently
minetest.register_on_generated(function(minp, maxp, blockseed)
    local vm, emin, emax = minetest.get_mapgen_object("voxelmanip")
    if not vm then return end
    
    local area = VoxelArea:new{MinEdge = emin, MaxEdge = emax}
    local data = vm:get_data()
    local param2_data = vm:get_param2_data()
    
    -- If minp is nil, use emin instead (fallback for mapgen scripts)
    local min_pos = emin
    local max_pos = emax
    
    -- Ensure we have valid coordinates and they are numbers
    if not min_pos or not max_pos or 
       type(min_pos.x) ~= "number" or type(min_pos.y) ~= "number" or type(min_pos.z) ~= "number" or
       type(max_pos.x) ~= "number" or type(max_pos.y) ~= "number" or type(max_pos.z) ~= "number" then
        minetest.log("error", "[rs_luscious] Invalid mapgen coordinates: minp=" .. 
                     (minp and tostring(minp.x) .. "," .. tostring(minp.y) .. "," .. tostring(minp.z) or "nil") ..
                     " maxp=" .. (maxp and tostring(maxp.x) .. "," .. tostring(maxp.y) .. "," .. tostring(maxp.z) or "nil") ..
                     " emin=" .. (emin and tostring(emin.x) .. "," .. tostring(emin.y) .. "," .. tostring(emin.z) or "nil") ..
                     " emax=" .. (emax and tostring(emax.x) .. "," .. tostring(emax.y) .. "," .. tostring(emax.z) or "nil"))
        return
    end
    
    -- Process only surface nodes for better performance
    for z = min_pos.z, max_pos.z do
        for x = min_pos.x, max_pos.x do
            -- Find surface level more efficiently
            local surface_y = nil
            for y = max_pos.y, min_pos.y, -1 do
                local idx = area:index(x, y, z)
                if data[idx] == GRASS_NODE_ID then
                    surface_y = y
                    break
                elseif data[idx] ~= minetest.CONTENT_AIR then
                    break -- Hit non-air, non-grass block
                end
            end
            
            if surface_y then
                local idx = area:index(x, surface_y, z)
                param2_data[idx] = blend_biome_color_fast(x, surface_y, z, 4)
            end
        end
    end
    
    vm:set_param2_data(param2_data)
end)

-- Simplified on_construct for individual node placement
function rs_luscious.on_construct(pos)
    local node = minetest.get_node(pos)
    node.param2 = blend_biome_color_fast(pos.x, pos.y, pos.z, 2)
    minetest.swap_node(pos, node)
end

