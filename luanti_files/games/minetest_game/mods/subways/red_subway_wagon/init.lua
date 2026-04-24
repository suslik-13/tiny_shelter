local S
if minetest.get_modpath("intllib") then
    S = intllib.Getter()
else
    S = function(s,a,...)a={a,...}return s:gsub("@(%d+)",function(n)return a[tonumber(n)]end)end
end

local lines = {
	"#ff1111",
	"#1111ff",
	"#ff9900",
	"#11ff11",
	"#9900ff",
	"#00ffff",
	"#ff9999",
	"#ff00ff",
	"#99ff00",
}

local function set_livery(self, puncher, itemstack, data)
	local meta = itemstack:get_meta()
	local color = meta:get_string("paint_color")
	local alpha = tonumber(meta:get_string("alpha"))
	if color and color:find("^#%x%x%x%x%x%x$") then
		data.livery = self.base_texture.."^("..self.base_livery.."^[colorize:"..color..":255)"
		data.door = self.door_texture.."^("..self.door_livery.."^[colorize:"..color..":255)"
		data.end_door = self.end_door_texture.."^("..self.end_door_livery.."^[colorize:"..color..":255)"
		self:set_textures(data)
	end
end

local function set_textures(self, data)
	if data.livery then
		self.livery = data.livery
		self.door_livery_data = data.door
		self.end_door_livery_data = data.end_door
		self.object:set_properties({
				textures={
					data.livery,
					"r_wagon_interior.png",
					"r_chassis_accessories.png",
					"r_coupler.png",
					"r_wheel_truck.png",
					"r_wheel_truck.png",
					"r_coupler.png",
					data.door,
					data.end_door,
					"r_glasses.png",
					"r_seats.png",
					"r_wheels.png",
					"r_wheels.png",
					"r_wheels.png",
					"r_wheels.png",
				}
		})
	end
end

local use_attachment_patch = advtrains_attachment_offset_patch and advtrains_attachment_offset_patch.setup_advtrains_wagon

local subway_wagon_def = {
    mesh="red_subway_wagon.b3d",
    textures={
		"r_wagon_exterior.png",
		"r_wagon_interior.png",
		"r_chassis_accessories.png",
		"r_coupler.png",
		"r_wheel_truck.png",
		"r_wheel_truck.png",
		"r_coupler.png",
		"r_doors.png",
		"r_end_doors.png",
		"r_glasses.png",
		"r_seats.png",
		"r_wheels.png",
		"r_wheels.png",
		"r_wheels.png",
		"r_wheels.png",
	},
    base_texture = "r_wagon_exterior.png",
    base_livery = "r_livery.png",
    door_texture = "r_doors.png",
    door_livery = "r_door_livery.png",
	end_door_texture = "r_end_doors.png",
	end_door_livery = "r_end_door_livery.png",
    set_textures = set_textures,
    set_livery = set_livery,
    drives_on={default=true},
    max_speed=15,
    seats={
		{
			name="Driver stand",
			attach_offset={x=-5, y=3.5, z=21},
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="driver_stand",
		},
        {
			name="1",
			attach_offset={x=-5, y=3.5, z=4},-- 4
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="passenger",
		},
		{
			name="2",
			attach_offset={x=-5, y=3.5, z=-4},
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="passenger",
		},
		{
			name="3",
			attach_offset={x=-5, y=3.5, z=-19},
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="passenger",
		},
		{
			name="4",
			attach_offset={x=-5, y=3.5, z=-25},
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="passenger",
		},
		-- END OF LEFT SIDE
		{
			name="5",
			attach_offset={x=-5, y=3.5, z=25},
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="passenger",
		},
		{
			name="6",
			attach_offset={x=5, y=3.5, z=19},
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="passenger",
		},
		{
			name="7",
			attach_offset={x=5, y=3.5, z=4},
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="passenger",
		},
		{
			name="8",
			attach_offset={x=5, y=3.5, z=-4},
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="passenger",
		},
		{
			name="9",
			attach_offset={x=5, y=3.5, z=-19},
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="passenger",
		},
		{
			name="10",
			attach_offset={x=-5, y=3.5, z=-25},
			view_offset=use_attachment_patch and {x=0, y=0, z=0} or {x=0, y=3.5, z=0},
			group="passenger",
		},
    },
    seat_groups = {
		driver_stand={
			name = "Driver Stand",
			access_to = {"passenger"},
			require_doors_open=true,
			driving_ctrl_access=true,
		},
        passenger={
			name = "Passenger Area",
			access_to = {"driver_stand"},
			require_doors_open=true,
		},
	},
    assign_to_seat_group={"passenger", "driver_stand"},
    door_entry={-1, 1},
	doors={
		open={
			[-1]={frames={x=0, y=20}, time=1},
			[1]={frames={x=40, y=60}, time=1}
		},
		close={
			[-1]={frames={x=20, y=40}, time=1},
			[1]={frames={x=60, y=80}, time=1}
		}
	},
    is_locomotive=true,
	drops={"default:steelblock 4"},
    visual_size={x=1, y=1},
	wagon_span=3.15,
	collisionbox = {
		-1.0, -0.5, -1.0,
		1.0, 2.5, 1.0
	},
	custom_on_step = function(self, dtime, data, train)
		-- Set the line number for the train
		local line = ""
		local line_number = tonumber(train.line)
		if line_number and line_number <= 9 and line_number > 0 then
			line = "^r_line_"..train.line..".png"
		end
		if self.livery then
			self.object:set_properties({
				textures={
					self.livery..line,
					"r_wagon_interior.png",
					"r_chassis_accessories.png",
					"r_coupler.png",
					"r_wheel_truck.png",
					"r_wheel_truck.png",
					"r_coupler.png",
					"r_doors.png^"..self.door_livery_data,
					"r_end_doors.png^"..self.end_door_livery_data,
					"r_glasses.png",
					"r_seats.png",
					"r_wheels.png",
					"r_wheels.png",
					"r_wheels.png",
					"r_wheels.png",
				}
			})
		else
			self.object:set_properties({
				textures={
					"r_wagon_exterior.png"..line,
					"r_wagon_interior.png",
					"r_chassis_accessories.png",
					"r_coupler.png",
					"r_wheel_truck.png",
					"r_wheel_truck.png",
					"r_coupler.png",
					"r_doors.png",
					"r_end_doors.png",
					"r_glasses.png",
					"r_seats.png",
					"r_wheels.png",
					"r_wheels.png",
					"r_wheels.png",
					"r_wheels.png",
				}
			})
		end
	end
}
if use_attachment_patch then
	advtrains_attachment_offset_patch.setup_advtrains_wagon(subway_wagon_def);
end
advtrains.register_wagon("red_subway_wagon", subway_wagon_def, S("Red Subway Car"), "r_inv.png")

-- Craft recipes
minetest.register_craft({
	output="advtrains:red_subway_wagon",
	recipe={
		{"default:steelblock", "default:steelblock", "default:steelblock"},
		{"xpanes:pane_flat", "dye:red", "xpanes:pane_flat"},
		{"advtrains:wheel", "", "advtrains:wheel"}
	}
})
