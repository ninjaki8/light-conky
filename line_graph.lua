-- Required libraries
local cairo = require('cairo')

-- Retrieves the name of the currently active network interface on the system 
local function getCurrentNetwork()
    local command = 'ip link | grep "state UP" | cut -f 2 -d ":" | sed "s/ //g"'
    local handle = io.popen(command)
    local output = handle:read("*a")
    handle:close()
    
    return string.gsub(output, "^%s*(.-)%s*$", "%1")
end

-- Script Setup
local networkInterfaceName = getCurrentNetwork()

-- Get iface name
function conky_getNetUp()
    return networkInterfaceName
end

-- Get private ip address
function conky_getPrivateAddress()
    return conky_parse('${addr ' .. networkInterfaceName .. '}')
end

-- Get download speed
function conky_getDownloadSpeed()
    return conky_parse('${downspeed ' .. networkInterfaceName .. '}')
end

-- Get upload speed
function conky_getUploadSpeed()
    return conky_parse('${upspeed ' .. networkInterfaceName .. '}')
end

local function draw_line_chart(cr, values, width, height, x, y, max_val, grad_start_color, grad_end_color)
    -- Set the border color
    cairo_set_source_rgba(cr, grad_start_color[1], grad_start_color[2], grad_start_color[3], 0.5)

    -- Draw the border at the bottom
    cairo_move_to(cr, x, y + height)
    cairo_line_to(cr, x + width, y + height)
    cairo_stroke(cr)

    -- Create a linear gradient
    local gradient = cairo_pattern_create_linear(x, y, x + width, y + height)
    cairo_pattern_add_color_stop_rgba(gradient, 0, grad_start_color[1], grad_start_color[2], grad_start_color[3], grad_start_color[4])
    cairo_pattern_add_color_stop_rgba(gradient, 1, grad_end_color[1], grad_end_color[2], grad_end_color[3], grad_end_color[4])

    -- Set the gradient as the source for the drawing context
    cairo_set_source(cr, gradient)

    -- Set the y scaling factor based on the minimum and maximum values and the height of the chart
    local min_val = math.min(table.unpack(values))
    local y_range = max_val - min_val + 0.1
    local y_scale = height / y_range

    if y_range > max_val / height then
        -- If the maximum value is too large relative to the height, adjust the scaling factor
        y_scale = height / max_val
    end

    -- Move to the starting point
    cairo_move_to(cr, x, y + height - (values[1] * y_scale))

    -- Draw the line chart
    for i = 2, #values do
        cairo_line_to(cr, x + (i - 1) * (width / (#values - 1)), y + height - (values[i] * y_scale))
    end

    -- Fill and stroke the line chart
    cairo_line_to(cr, x + width, y + height)
    cairo_line_to(cr, x, y + height)
    cairo_close_path(cr)
    cairo_fill(cr)
    cairo_stroke(cr)
end


-- Define the Conky draw function for chart 1
function conky_draw(x, y)
    if conky_window == nil then
        return
    end

    -- Get the downspeedf value from Conky
    local downspeedf = tonumber(conky_parse('${downspeedf '.. networkInterfaceName ..'}'))
    local upspeedf = tonumber(conky_parse('${upspeedf '.. networkInterfaceName ..'}'))
    local history_size = 60

    -- Create the Cairo context
    local cs = cairo_xlib_surface_create(conky_window.display,
                                    conky_window.drawable,
                                    conky_window.visual,
                                    conky_window.width,
                                    conky_window.height)
    local cr = cairo_create(cs)

    -- Get the Conky window dimensions
    local width = 280
    local height = 50

    -- Initialize the history if it doesn't exist
    if not history1 or #history1 ~= history_size then
        history1 = {}
        for i = 1, history_size do
            history1[i] = 0.1
        end
    end

    -- Initialize the history if it doesn't exist
    if not history2 or #history2 ~= history_size then
        history2 = {}
        for i = 1, history_size do
            history2[i] = 0.1
        end
    end

    -- Update the history
    table.remove(history1, 1)
    table.insert(history1, downspeedf)

    table.remove(history2, 1)
    table.insert(history2, upspeedf)

    -- Find the maximum value in the data sets
    local max_down = math.max(table.unpack(history1))
    local max_up = math.max(table.unpack(history2))
    local max_val = math.ceil(math.max(max_down, max_up))

    -- Gradient colors
    local down_color_start = {0.68, 1.0, 0.18, 1} -- #ADFF2F
    local down_color_end = {0.20, 0.80, 0.20, 1} -- #32CD32
    local up_color_start = {0.95, 0.72, 0.02, 1} -- #f3b806
    local up_color_end = {0.99, 0.88, 0.55, 1} -- #fce08c

    -- Draw the line chart with the history and the maximum value
    draw_line_chart(cr, history1, width, height, x, y, max_val, down_color_start, down_color_end)
    draw_line_chart(cr, history2, width, height, x, y+height+50, max_val, up_color_start, up_color_end)

    -- Clean up the Cairo context
    cairo_destroy(cr)
    cairo_surface_destroy(cs)

    -- Return an empty string
    return ''
end
