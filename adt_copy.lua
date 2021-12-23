local adt_copy = brush("ADT Copy")

adt_copy:add_description("<b>shift + right click</b>: Select an adt")
adt_copy:add_description("<b>shift + alt + left click</b>: Select and save an adt in file")
adt_copy:add_description("<b>shift + left click</b>: Paste selected adt if stored")
adt_copy:add_description("<b>shift + alt + left click</b>: Paste adt from saved file")
adt_copy:add_description("- does not copy vertex colors")

local paste_height   = adt_copy:add_bool_tag("Paste height", true)
local paste_textures = adt_copy:add_bool_tag("Paste textures", true)
local adtX = adt_copy:add_string_tag("ADT X","")
local adtZ = adt_copy:add_string_tag("ADT Z","")

local adt = {}
local chunk = {
  write = false
}

function GetADT(event)
  adt.x = tonumber(string.format("%.0f", event:pos().x / (1600/3) - .5))
  adt.z = tonumber(string.format("%.0f", event:pos().z / (1600/3) - .5))

  adt.offset = {}

  adt.offset.x = adt.x * (1600/3)
  adt.offset.z = adt.z * (1600/3)
end

function adt_copy:on_right_click(evt)
    if not holding_shift() then return end

    GetADT(evt)

    for cx = 0, 15 do
      for cz = 0, 15 do
        local index = (cx*16)+cz

        if ( cx == 0 and cz == 0 ) then
          chunk.write = true
        end

        chunk[index] = {
          textures   = {},
          effects    = {},
          heights    = {},
          texs       = {},
          tex_count  = 0,
        }

        _vecX = (cx+1) * (100/3) - ((100/3)/2) + adt.offset.x 
        _vexZ = (cz+1) * (100/3) - ((100/3)/2) + adt.offset.z

        self = get_chunk(vec(_vecX, 1, _vexZ))

        chunk[index].tex_count = self:get_texture_count()-1

        for i = 0, chunk[index].tex_count do
          chunk[index].textures[i] = self:get_texture(i)
          chunk[index].effects[i] = self:get_effect(i)  
        end

        for i = 0, 144 do
          chunk[index].heights[i] = self:get_vert(i):get_pos().y
        end

        for i = 0, 4095 do
          local tex = self:get_tex(i)
          chunk[index].texs[i] = {}
          for j = 0, chunk[index].tex_count do
            chunk[index].texs[i][j] = tex:get_alpha(j)  
          end
        end

      end
    end

    if ( holding_alt() ) then
      local data = {}

      for cx = 0, 15 do
        for cz = 0, 15 do
          local index = (cx*16)+cz

          data[index] = ""
          data[index] = data[index] .. chunk[index].tex_count .. ", "

          data[index] = data[index] .. (paste_height:get() and 1 or 0) .. ", "
          data[index] = data[index] .. (paste_textures:get() and 1 or 0) .. ", "

          
          if ( paste_height:get() ) then
            for i = 0, 144 do
              data[index] = data[index] .. chunk[index].heights[i] .. ", "
            end
          end
          
          
          if ( paste_textures:get() ) then
            for i = 0, chunk[index].tex_count do -- tex_count
              data[index] = data[index] .. chunk[index].textures[i] .. ", "
              data[index] = data[index] .. chunk[index].effects[i] .. ", "
            end

            
            for i = 0, 4095 do -- * tex_count
              for j = 0, chunk[index].tex_count do
                data[index] = data[index] .. chunk[index].texs[i][j] .. ", "
              end
            end
          end

          write_file("adt_copy/adt_"..adt.x.."_"..adt.z.."/chunk_"..cx.."_"..cz..".csv", data[index])

        end
      end

      print("Saved ADT in folder: adt_copy/adt_"..adt.x.."_"..adt.z)
    else
      print("Saved ADT ["..adt.x.."; "..adt.z.."]")
    end
end

function adt_copy:on_left_click(evt)
    if not holding_shift() then return end

    GetADT(evt)
    local file = {
      fromFile = false
    }

    if ( holding_alt() ) then

      file = { x = adtX:get(), z = adtZ:get() }
      file.fromFile = true

      for cx = 0, 15 do
        for cz = 0, 15 do
          local data = read_file("adt_copy/adt_"..file.x.."_"..file.z.."/chunk_"..cx.."_"..cz..".csv")

          local index = (cx*16)+cz
          local tex_count = 0
          chunk[index] = {
            textures   = {},
            effects    = {},
            heights    = {},
            texs       = {},
            tex_count = 0
          }

          _vecX = (cx+1) * (100/3) - ((100/3)/2) + adt.offset.x 
          _vexZ = (cz+1) * (100/3) - ((100/3)/2) + adt.offset.z

          self = get_chunk(vec(_vecX, 1, _vexZ))

          local c = 1
          local has_height, has_texture = false, false
          local ch, cte = 0, 0
          local tex_i, tex_j = 0, 0
          for k in string.gmatch(data, '([^,]+)') do
            if ( c == 1 ) then
              chunk[index].tex_count = tonumber(k)
            end

            if ( c == 2 ) then
              if ( tonumber(k) == 1 ) then has_height = true end
            end

            if ( c == 3 ) then
              if ( tonumber(k) == 1 ) then has_texture = true end
            end

            if ( c > 3 and c <= (145+3)) then
              if ( has_height ) then
                chunk[index].heights[ch] = tonumber(k)
                ch = ch + 1
              end
            end

            if ( c > (145+3) ) then
              if ( has_texture ) then
                if ( c > (145+3) and c <= (145+3+((chunk[index].tex_count+1)*2))) then
                  if ( ((c-(145+3))%2 ~= 0) ) then
                    chunk[index].textures[cte] = k:sub(2)
                  else
                    chunk[index].effects[cte] = tonumber(k)
                    cte = cte + 1
                  end
                end

                if ( c > (145+3+((chunk[index].tex_count+1)*2)) ) then
                  if ( tex_i == 0 and tex_j == 0 ) then
                    chunk[index].texs[tex_i] = {}
                  end

                  chunk[index].texs[tex_i][tex_j] = floor(tonumber(k))

                  tex_j = tex_j + 1 

                  if (tex_j > chunk[index].tex_count) then
                    tex_j = 0
                    tex_i = tex_i + 1

                    chunk[index].texs[tex_i] = {}
                  end

                end
              end
            end

            c = c + 1
          end
        end
      end

      chunk.write = true
    end

    if ( chunk.write ) then
      for cx = 0, 15 do
        for cz = 0, 15 do
          local index = (cx*16)+cz
  
          _vecX = (cx+1) * (100/3) - ((100/3)/2) + adt.offset.x 
          _vexZ = (cz+1) * (100/3) - ((100/3)/2) + adt.offset.z
  
          self = get_chunk(vec(_vecX, 1, _vexZ))
  
          if ( paste_height:get() ) then
            for i= 0, 144 do
              self:get_vert(i):set_height(chunk[index].heights[i])
            end
          end
  
          if ( paste_textures:get() ) then
            self:clear_textures()
  
            for i = 0, chunk[index].tex_count do
              self:add_texture(chunk[index].textures[i], chunk[index].effects[i])
            end
  
            for i = 0, 4095 do
              for j = 0, chunk[index].tex_count do
                self:get_tex(i):set_alpha(j, chunk[index].texs[i][j])
              end
            end
          end
  
          self:apply()
  
        end
      end

      if ( file.fromFile ) then
        print("Pasted ADT from folder: adt_copy/adt_"..file.x.."_"..file.z)
      else
        print("Pasted ADT")
      end
    end
end