-- Ten static poses. A pose = one frozen animation frame of the player model
-- (frames are the standard player_api / 3d_armor ones) plus relative bone
-- rotations in degrees, applied once with set_bone_override. Static poses
-- cost nothing per server step.
--
-- Axis note: +x on Arm_*/Head swings the limb forward/up (head: looks up).
-- If it is the other way round on your model, set player_pedestal.invert_pitch.
local S = player_pedestal.S

local FRAME_STAND, FRAME_SIT, FRAME_WALK, FRAME_MINE = 0, 81, 172, 194

player_pedestal.BONES = { "Head", "Body", "Arm_Left", "Arm_Right", "Leg_Left", "Leg_Right" }

player_pedestal.poses = {
	{ name = S("Standing"), frame = FRAME_STAND, bones = {} },
	{ name = S("Victory"), frame = FRAME_STAND, bones = {
		Arm_Right = { x = 165 }, Arm_Left = { x = 165 }, Head = { x = 15 },
	} },
	{ name = S("Greeting"), frame = FRAME_STAND, bones = {
		Arm_Right = { x = 150, z = 10 }, Head = { y = 10 },
	} },
	{ name = S("Pointing forward"), frame = FRAME_STAND, bones = {
		Arm_Right = { x = 90 }, Head = { x = 5 },
	} },
	{ name = S("Champion"), frame = FRAME_STAND, bones = {
		Arm_Right = { x = 180 }, Arm_Left = { x = -10 }, Head = { x = 12 },
	} },
	{ name = S("Walking"), frame = FRAME_WALK, bones = {} },
	{ name = S("Strike"), frame = FRAME_MINE, bones = {} },
	{ name = S("Sitting"), frame = FRAME_SIT, bones = {} },
	{ name = S("Thinking"), frame = FRAME_STAND, bones = {
		Head = { x = -25 }, Arm_Right = { x = 55 }, Arm_Left = { x = 10 },
	} },
	{ name = S("Relaxed"), frame = FRAME_STAND, bones = {
		Head = { y = 30 }, Arm_Left = { x = -12 }, Arm_Right = { x = -12 }, Leg_Left = { x = 8 },
	} },
}

local invert = minetest.settings:get_bool("player_pedestal.invert_pitch", false)
local rad = math.rad

local function apply_bone(obj, bone, r)
	if not r then
		obj:set_bone_override(bone, nil)
		return
	end
	local x = r.x or 0
	if invert and bone ~= "Body" then
		x = -x
	end
	obj:set_bone_override(bone, {
		rotation = { vec = vector.new(rad(x), rad(r.y or 0), rad(r.z or 0)), absolute = false, interpolation = 0 },
	})
end
player_pedestal.apply_bone = apply_bone

function player_pedestal.apply_pose(obj, index)
	local pose = player_pedestal.poses[index] or player_pedestal.poses[1]
	obj:set_animation({ x = pose.frame, y = pose.frame }, 0, 0, false)
	for _, bone in ipairs(player_pedestal.BONES) do
		apply_bone(obj, bone, pose.bones[bone])
	end
end

function player_pedestal.random_pose()
	return math.random(1, #player_pedestal.poses)
end
