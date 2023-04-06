local mfloor = math.floor
local tr = table.remove
local sf = string.format

local red, orange, blue = {1, 0.2, 0.2}, {1, 0.6, 0.2}, {0.1, 0.8, 1}
local profiler = {}

local function avgTable(t)
    local v = {0, 0, 0, 0, 0, 0, 0, 0, 0}
    for i = 1, #t do
        for j = 1, 9 do
            v[j] = v[j] + t[i][j]
        end
    end
    for i = 1, 9 do
        v[i] = v[i] / #t
    end

    return v
end

local function mfloorMin(n)
    n = mfloor(n)
    if n <= 1 then n = 0 end
    return n
end

function profiler.new(params)
    display.enableStatistics(true)
    local frameCount, graphAlpha = 30, 1
    if params then
        if params.frames then frameCount = params.frames end
        if params.colour1 then red = params.colour1 end
        if params.colour2 then orange = params.colour2 end
        if params.colour3 then blue = params.colour3 end
        if params.alpha then graphAlpha = params.alpha end
    end
    local frameRate, timeScale, values = nil, nil, {}
    local prevTime = 0

    local KPIs, KPIs60Seconds = {}, {}

    local g = display.newGroup()
    local graph = nil
    local gameFPS = 0

    display.getTimings(results, "update")

    local function enterFrame(event)
        pcall(function()
            --get current frame rate
            local curTime = system.getTimer()
            local dt = curTime - prevTime
            prevTime = curTime
            local fps = mfloor(1000/dt)

            local results = {}
            local fe, re, rt, tri, tex, draw = 0, 0, 0, 0, 0, 0
            
            --how long to create a frame?
            --includes timers, frame events, etc
            local n = display.getTimings(results, "update")
            for i = 1, n, 2 do
                local what, time = results[i], results[i + 1]
                if what == "FrameEvent" then 
                    fe = time / 1000
                elseif what == "RenderEvent" then 
                    re = time / 1000 - fe
                end
            end
            
            --how long to render the current frame in the GPU?
            results = {}
            local n = display.getTimings(results, "render")
            for i = 1, n, 2 do
                local what, time = results[i], results[i + 1]
                if what == "Display::Render Done" then 
                    rt = time / 1000
                end
            end

            --get GPU stats
            results = {}
            display.getStatistics(results)
            for k, v in pairs(results) do
                if k == "triangleCount" then
                    tri = v
                elseif k == "textureBindCount" then
                    tex = v
                elseif k == "drawCallCount" then
                    draw = v
                end
            end

            --get mem stats
            local tm, lm = system.getInfo("textureMemoryUsed")/1048576, collectgarbage("count")/1024
            
            --store this frame
            KPIs[#KPIs + 1] = {fps, tm, lm, fe, re, rt, tri, tex, draw}

            if #KPIs >= frameCount then
                --average the values
                local avg = avgTable(KPIs)
                KPIs = {}

                --store to 60s array and update the screen
                if #KPIs60Seconds >= 60 then tr(KPIs60Seconds, 1) end
                KPIs60Seconds[#KPIs60Seconds + 1] = {}
                for i = 1, 9 do
                    KPIs60Seconds[#KPIs60Seconds][i] = avg[i]
                end

                --workout our max value
                local max = 0
                for i = 1, #KPIs60Seconds do
                    if KPIs60Seconds[i][4] + KPIs60Seconds[i][5] + KPIs60Seconds[i][6] > max then max = mfloor(KPIs60Seconds[i][4] + KPIs60Seconds[i][5] + KPIs60Seconds[i][6]) end
                end
                max = mfloor(max / 5 + 0.5) * 5
                max = max + 5
                timeScale.text = max.." ms"
            
                --draw graph
                local gW, gH = 250, 160
                local bw = 250/60
                local tex = graphics.newTexture( { type = "canvas", width = gW + 5, height = gH, pixelWidth = gW + 5, pixelHeight = gH } )
                local ourTris = 148
                for i = 1, #KPIs60Seconds do
                    local fe, re, rt = KPIs60Seconds[i][4], KPIs60Seconds[i][5], KPIs60Seconds[i][6]
                    --draw fe
                    local h = (fe/max) * gH
                    local lastY = 80
                    if h > 1 then
                        local rect = display.newRect( -gW/2 + i * bw, lastY, bw, h )
                        rect.anchorY = 1
                        rect:setFillColor( unpack(red) )
                        tex:draw(rect)
                        lastY = lastY - h
                        ourTris = ourTris + 6
                    end
                    --draw re
                    local h = (re/max) * gH
                    if h > 1 then
                        local rect = display.newRect( -gW/2 + i * bw, lastY, bw, h )
                        rect.anchorY = 1
                        rect:setFillColor( unpack(orange) )
                        tex:draw(rect)
                        lastY = lastY - h
                        ourTris = ourTris + 6
                    end
                    --draw rt
                    local h = (rt/max) * gH
                    if h > 1 then
                        local rect = display.newRect( -gW/2 + i * bw, lastY, bw, h )
                        rect.anchorY = 1
                        rect:setFillColor( unpack(blue) )
                        tex:draw(rect)
                        ourTris = ourTris + 6
                    end
                end
                tex:invalidate()

                display.remove(graph)
                graph = display.newImageRect(g, tex.filename, tex.baseDir, gW + 5, gH)
                graph:translate(265, 0)
                graph.alpha = graphAlpha
                tex:releaseSelf()

                --update screen
                gameFPS = mfloor(avg[1])
                frameRate.text = gameFPS
                values[1].text = sf("%3.1f", avg[2]).." mb" 
                values[2].text = sf("%3.1f", avg[3]).." mb" 
                values[3].text = sf("%3.1f", avg[4]).." ms"
                values[4].text = sf("%3.1f", avg[5]).." ms"
                values[5].text = sf("%3.1f", avg[6]).." ms"
                values[6].text = mfloorMin(avg[7] - ourTris)
                values[7].text = mfloorMin(avg[8] - 21)
                values[8].text = mfloorMin(avg[9] - 22)
            end
        end)
    end

    --create display
    local function addText(x, y, text, width, size, bold)
        x = x + width/2 
        local options = {parent = g, text = text, x = x, y = y, width = width, font = native.systemFont, fontSize = size, align = "left"}
        if bold then options.font = native.systemFontBold end
        local o = display.newText(options)
        return o
    end

    local bg = display.newRoundedRect(g, 0, 0, 400, 180, 10)
    bg:setFillColor(0,0,0,0.6)
    bg.anchorX = 0
    addText(10, -70, "FPS", 50, 20)
    frameRate = addText(78, -70, "0", 50, 24, true)

    local y = -40
    local t = {"Lua mem", "Text mem", "Frame", "Render", "Display", "Triangles", "Textures", "Draw calls"}
    for i = 1, 8 do
        addText(10, y, t[i], 60, 11)
        y = y + 16
    end

    y = -40
    local t = {"0 mb", "0 mb", "0 ms", "0 ms", "0 ms", "0", "0", "0"}
    for i = 1, 8 do
        values[#values + 1] = addText(80, y, t[i], 50, 11, true)
        y = y + 16
    end
    values[3]:setFillColor( unpack(red) )
    values[4]:setFillColor( unpack(orange) )
    values[5]:setFillColor( unpack(blue) )

    local options = {parent = g, text = "ms", x = 140, y = -80, width = 50, font = native.systemFontBold, fontSize = 8, align = "right"}
    timeScale = display.newText(options)
    timeScale.anchorX = 1

    local l = display.newLine( g, 142, -80, 392, -80 )
    l:setStrokeColor( 0.5 )
    local l = display.newLine( g, 142, 0, 392, 0 )
    l:setStrokeColor( 0.5 )
    local l = display.newLine( g, 142, 81, 392, 81 )
    l:setStrokeColor( 0.5 )

    timer.performWithDelay( 1, function()
        Runtime:addEventListener("enterFrame", enterFrame)
    end)

    function g.getFPS()
        return gameFPS
    end
    return g
end

return profiler
