local _PATH = (...):match('(.-)[^%.]+$' or '')
local xml_parser = require(_PATH .. 'xml_parser')
local utils = require(_PATH .. 'utils')
local Animation = require(_PATH .. 'animation')
local Tile = require(_PATH .. 'tile')

local mfloor = math.floor

local M = {}

-- the image filter used for drawing tiles, configured by calling: M.setImageFilter()
local image_filter = { 'linear', 'linear', 1 }

local function parseTile(node)
    local animation = {}

    for _, child_node in ipairs(node.children) do
        if child_node.name == 'animation' then
            animation = Animation.new(child_node)
        end
    end

    return {
        id = tonumber(node.attributes['id']),
        animation = animation,
    }
end

local function parseTileset(node, dir)
    -- in case a tileset is embedded in a tilemap, the firstgid is defined in the tileset
    -- in case a tileset is loaded from a path, the firstgid is defined in the tilemap
    local firstgid = nil

    local tsx_path = node.attributes['source']
    if tsx_path ~= nil then
        firstgid = tonumber(node.attributes['firstgid'])
        node = xml_parser.parseXmlFile(dir .. tsx_path)
    else
        firstgid = tonumber(node.attributes['firstgid'])
    end

    local image, animations = nil, {}
    for _, child_node in ipairs(node.children) do
        if child_node.name == 'image' then
            local image_node = node.children[1]
            local image_source = image_node.attributes['source']
            local rel_path = utils.getNormalizedPath(dir, image_source)
            image = love.image.newImageData(rel_path)
        elseif child_node.name == 'tile' then
            local tile = parseTile(child_node)
            animations[tile.id] = tile.animation
        end
    end
    assert(image ~= nil, 'no tileset image found')

    return {
        name        = node.attributes['name'],
        firstgid    = firstgid,
        tilewidth   = tonumber(node.attributes['tilewidth']),
        tileheight  = tonumber(node.attributes['tileheight']),
        tilecount   = tonumber(node.attributes['tilecount']),
        columns     = tonumber(node.attributes['columns']),
        image       = image,
        animations  = animations,
    }
end

local function parseChunk(node)
    local chunk = {
        width       = tonumber(node.attributes['width']),
        height      = tonumber(node.attributes['height']),
        x           = tonumber(node.attributes['x']),
        y           = tonumber(node.attributes['y']),
        tile_ids    = {},
    }

    -- convert tile ids from CSV to a Lua table, based on chunk width & height
    local tile_ids = utils.split(node.value, ',')
    for y = 1, chunk.height do
        chunk.tile_ids[y] = {}
        for x = 1, chunk.width do
            chunk.tile_ids[y][x] = tonumber(tile_ids[(y - 1) * chunk.width + x])
        end
    end

    return chunk
end

local function parseData(node)
    local data = {
        chunks      = {},
        encoding    = node.attributes['encoding'],
    }

    -- parse chunks
    -- TODO: adjustment needed for non-infinite maps, which don't have chunks
    for _, child_node in ipairs(node.children) do
        if child_node.name == 'chunk' then
            table.insert(data.chunks, parseChunk(child_node))
        end
    end

    return data
end

local function parseLayer(node)
    return {
        id      = tonumber(node.attributes['id']),
        name    = node.attributes['name'],
        width   = tonumber(node.attributes['width']),
        height  = tonumber(node.attributes['height']),
        data    = parseData(node.children[1]),
    }
end

local function parseProperties(node)
    local properties = {}

    for _, child_node in ipairs(node.children) do
        local name = child_node.attributes['name']
        local type  = child_node.attributes['type']
        local value = child_node.attributes['value']

        if type == 'bool' then
            properties[name] = (value == 'true') and true or false
        elseif type == 'color' then
            properties[name] = utils.hexToColor(value)
        elseif type == 'float' or type == 'int' or type == 'object' then
            properties[name] = tonumber(value)
        elseif type == 'string' or type == 'file' then
            properties[name] = value
        elseif type ~= nil then
            error('unexpected property type: \"' .. type .. '\"')
        end
    end

    return properties
end

local function parseObject(node)
    local properties = {}

    -- if the object node has children, we expect always a /single/ child that contains properties
    if #node.children > 0 then
        local child_node = node.children[1]
        assert(child_node.name == 'properties', 'unexpected node: \"' .. child_node.name .. '\"')
        properties = parseProperties(child_node)
    end

    return {
        id          = tonumber(node.attributes['id']),
        gid         = tonumber(node.attributes['gid']),
        x           = tonumber(node.attributes['x']),
        y           = tonumber(node.attributes['y']),
        width       = tonumber(node.attributes['width']),
        height      = tonumber(node.attributes['height']),
        type        = node.attributes['type'],
        name        = node.attributes['name'],
        properties  = properties,
    }
end

local function parseObjectGroup(node)
    local object_group = {}

    for _, child_node in ipairs(node.children) do
        table.insert(object_group, parseObject(child_node))
    end

    return object_group
end

local function drawChunk(chunk, tiles, tile_w, tile_h)
    for y = 1, chunk.height do
        for x = 1, chunk.width do
            local tile_id = chunk.tile_ids[y][x]
            tiles[tile_id]:draw((chunk.x + x) * tile_w, (chunk.y + y) * tile_h)
        end
    end
end

-- set image filter used to draw tiles, should be called prior to loading a map
-- based on the LÖVE API: Image:setFilter(min, mag, anisotropy)
M.setImageFilter = function(min, mag, anisotropy)
    min             = min or 'linear'
    mag             = mag or min
    anisotropy      = anisotropy or 1
    image_filter    = { min, mag, anisotropy }
end

-- load a TMX file based on the relative path inside the LÖVE project
M.load = function(tmx_path)
    local dir = love.filesystem.getRealDirectory(tmx_path) or ''
    local path = dir .. '/' .. tmx_path
    local xml, err = xml_parser.parseXmlFile(path)

    if err ~= nil then return error('failed to load TMX file: ' .. err) end

    local map = {
        version         = xml.attributes['version'],
        tilewidth       = tonumber(xml.attributes['tilewidth']),
        tileheight      = tonumber(xml.attributes['tileheight']),
        width           = tonumber(xml.attributes['width']),
        height          = tonumber(xml.attributes['height']),
        nextobjectid    = tonumber(xml.attributes['nextobjectid']),
        nextlayerid     = tonumber(xml.attributes['nextlayerid']),
        orientation     = xml.attributes['orientation'],
        renderorder     = xml.attributes['renderorder'],
        infinite        = (xml.attributes['infinite'] == 1) and true or false,
    }

    -- retrieve all tilesets, layers & object groups, which we'll need for drawing
    local tilesets, layers, object_groups = {}, {}, {}
    for _, node in pairs(xml.children) do
        if node.name == 'tileset' then
            table.insert(tilesets, parseTileset(node, utils.getDirectory(tmx_path)))
        elseif node.name == 'layer' then
            table.insert(layers, parseLayer(node))
        elseif node.name == 'objectgroup' then
            table.insert(object_groups, parseObjectGroup(node))
        end
    end

    -- generate tile images for each tileset
    local tile_images = {}

    local tiles = {}

    -- add dummy tile
    tiles[0] = { draw = function(x, y) end }

    for _, tileset in ipairs(tilesets) do
        local gid = tileset.firstgid
        local x, y, w, h = 0, 0, tileset.tilewidth, tileset.tileheight

        for i = 0, (tileset.tilecount - 1) do
            x = i % tileset.columns
            y = mfloor(i / tileset.columns)

            local image_data = love.image.newImageData(w, h)
            image_data:paste(tileset.image, 0, 0, x * w, y * h, w, h)
            local image = love.graphics.newImage(image_data)
            image:setFilter(unpack(image_filter))

            tile_images[gid + i] = image
            tiles[gid + i] = Tile(image)
        end
    end

    -- add drawing method
    map.draw = function(camera)
        -- TODO: use sprite batches

        if camera ~= nil then
            -- convert camera position to coordinates, to compare against chunk coordinates
            local cam_x = camera.x / map.tilewidth
            local cam_y = camera.y / map.tileheight

            -- convert camera visible area to width & height in coordinate space
            local window_w, window_h = love.graphics.getDimensions()
            local cam_w = window_w / camera.scale / map.tilewidth
            local cam_h = window_h / camera.scale / map.tileheight

            -- determine min and max coordinates for the drawing area
            local min_x, max_x = mfloor(cam_x - cam_w / 2), mfloor(cam_x + cam_w / 2)
            local min_y, max_y = mfloor(cam_y - cam_h / 2), mfloor(cam_y + cam_h / 2)

            -- draw only chunks in visible area of camera
            for _, layer in ipairs(layers) do
                for _, chunk in ipairs(layer.data.chunks) do
                    if (chunk.x + chunk.width)  < min_x or chunk.x > max_x then goto continue end
                    if (chunk.y + chunk.height) < min_y or chunk.y > max_y then goto continue end

                    drawChunk(chunk, tiles, map.tilewidth, map.tileheight)

                    ::continue::
                end
            end
        else
            -- if no camera is provied, draw all chunks
            for _, layer in ipairs(layers) do
                for _, chunk in ipairs(layer.data.chunks) do
                    drawChunk(chunk, tiles, map.tilewidth, map.tileheight)
                end
            end
        end
    end

    -- add update method
    map.update = function(dt)
        for _, tileset in ipairs(tilesets) do
            local gid = tileset.firstgid

            for tile_id, animation in pairs(tileset.animations) do
                Animation.update(animation, dt)

                local frame = Animation.getCurrentFrame(animation)
                local image = tile_images[gid + frame.tile_id]
                tiles[gid + tile_id] = Tile(image)
            end
        end
    end

    return map
end

return M
