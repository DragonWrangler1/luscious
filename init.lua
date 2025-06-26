rs_luscious = {}

local mgp = minetest.get_mapgen_params()
local chunksize = 16 * mgp.chunksize

-- Function to blend biomes, specifically with _c biomes' properties
function rs_luscious.blend_biome_color(pos)
    local blend_distance = 5
    local heat_total, humidity_total, count = 0, 0, 0
    local is_c_biome = false

    -- Cache the biome data within a smaller range of blocks
    for x = -blend_distance, blend_distance do
        for z = -blend_distance, blend_distance do
            local sample_pos = {x = pos.x + x, y = pos.y, z = pos.z + z}
            local biome_data = minetest.get_biome_data(sample_pos)

            -- Check if biome data is found and valid
            if biome_data and biome_data.biome then
                local biome_name = minetest.get_biome_name(biome_data.biome)
                local biome = minetest.registered_biomes[biome_name]

                if biome and biome.heat_point and biome.humidity_point then
                    -- The biome is a normal biome
                    -- Normal biomes blend with each other
                    heat_total = heat_total + biome.heat_point
                    humidity_total = humidity_total + biome.humidity_point
                    count = count + 1
                end
            end
        end
    end

    -- If no valid biomes are found, return default color (136)
    if count == 0 then
        return 136  -- Default palette index
    end

    -- Calculate the average heat and humidity
    local heat = math.floor(math.min(math.max(math.floor(heat_total / count), 0), 100) / 6.6)
    local humidity = math.floor(math.min(math.max(math.floor(humidity_total / count), 0), 100) / 6.6)

    -- For normal biomes, blend normally
    return heat + (humidity * 16)
end

function rs_luscious.on_construct(pos)
    local node = minetest.get_node(pos)
    node.param2 = rs_luscious.blend_biome_color(pos)
    minetest.swap_node(pos, node)
end

core.register_mapgen_script(minetest.get_modpath("rs_luscious").."/mg.lua")

minetest.override_item("default:dirt_with_grass", {
	paramtype2 = "color",
	palette = "luscious_grass_palette.png",
	on_construct = function(pos, node)
		rs_luscious.on_construct(pos)
	end,
})
