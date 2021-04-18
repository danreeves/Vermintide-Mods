local mod = get_mod("Display Main Path")

local TEXT = false
local ITEM_TEXT = false
local PRIMARY_SPAWNER_DATA = {}
local SECONDARY_SPAWNER_DATA = {}
local PRIMARY_SPAWNER_DISPLAY_DATA = {}
local SECONDARY_SPAWNER_DISPLAY_DATA = {}
local GUARENTEED_DATA = {}

local enabled = false
Development._hardcoded_dev_params.disable_debug_draw = not enabled
script_data.disable_debug_draw = not enabled
DebugManager.drawer = function(self, options)
    options = options or {}
    local drawer_name = options.name
    local drawer = nil
    local drawer_api = DebugDrawer

    if drawer_name == nil then
        local line_object = World.create_line_object(self._world)
        drawer = drawer_api.new(drawer_api, line_object, options.mode)
        self._drawers[#self._drawers + 1] = drawer
    elseif self._drawers[drawer_name] == nil then
        local line_object = World.create_line_object(self._world)
        drawer = drawer_api.new(drawer_api, line_object, options.mode)
        self._drawers[drawer_name] = drawer
    else
        drawer = self._drawers[drawer_name]
    end

    return drawer
end
local ahead_unit = nil

mod.hook_safe(mod, IngameHud, "update", function(self)
    if not self._currently_visible_components.EquipmentUI or
        self.is_own_player_dead(self) or
        string.find(Managers.state.game_mode._level_key, "inn_level") then
        enabled = false
        Development._hardcoded_dev_params.disable_debug_draw = not enabled
        script_data.disable_debug_draw = not enabled
    else
        enabled = true
        Development._hardcoded_dev_params.disable_debug_draw = not enabled
        script_data.disable_debug_draw = not enabled
    end

    return
end)

mod.update = function()
    if enabled then
        if mod:get("main_path") then mod.drawMainPath() end
        if mod:get("player_pos") then mod.drawPosition() end
        if mod:get("boss") then mod.drawBosses() end
        if mod:get("patrol") then mod.drawPats() end
        if mod:get("respawn") then mod.drawRespawns() end
        if mod:get("boss_walls") then mod.drawBossWalls() end
        if mod:get("patrol_routes") then mod.drawPatrolRoutes() end
        if mod:get("item_spawners") then mod.drawItemSpawners() end

        if Managers.state.debug then
            for _, drawer in pairs(Managers.state.debug._drawers) do
                drawer.update(drawer, Managers.state.debug._world)
            end
        end
    end

    return
end
mod.on_game_state_changed = function(self)
    enabled = false
    SAVED_WHERE = nil
    TEXT = false
    ITEM_TEXT = false

    return
end
mod.on_setting_changed = function(self)
    QuickDrawer:reset()
    QuickDrawerStay:reset()

    local debug_text = Managers.state.debug_text

    debug_text.clear_world_text(debug_text, "category: spawner_id")
    debug_text.clear_world_text(debug_text, "category: item_spawner_id")

    TEXT = false
    ITEM_TEXT = false

    return
end

mod.command(mod, "clearDraw", "", function()
    QuickDrawer:reset()
    QuickDrawerStay:reset()

    return
end)

mod.drawMainPath = function()
    local level_analysis = Managers.state.conflict.level_analysis
    local h = Vector3(0, 0, 1)
    local main_paths = level_analysis.main_paths

    for i = 1, #main_paths, 1 do
        local path = main_paths[i].nodes

        for j = 1, #path, 1 do
            local position = Vector3(path[j][1], path[j][2], path[j][3])

            QuickDrawer:sphere(position + h, 0.25, Colors.get("green"))

            if j == #path and i ~= #main_paths then
                local nextPositon = Vector3(main_paths[i + 1].nodes[1][1],
                                            main_paths[i + 1].nodes[1][2],
                                            main_paths[i + 1].nodes[1][3])

                QuickDrawer:line(position + h, nextPositon + h,
                                 Colors.get("yellow"))
            elseif j ~= #path then
                local nextPositon = Vector3(path[j + 1][1], path[j + 1][2],
                                            path[j + 1][3])

                QuickDrawer:line(position + h, nextPositon + h,
                                 Colors.get("green"))
            end
        end
    end

    return
end
mod.drawBosses = function()
    local level_analysis = Managers.state.conflict.level_analysis
    local boss_waypoints = level_analysis.boss_waypoints
    local terror_spawners = level_analysis.terror_spawners
    local enemy_recycler = level_analysis.enemy_recycler

    if not boss_waypoints then return false end

    local terror_event_kind = "event_boss"
    local data = terror_spawners[terror_event_kind]
    local spawners = data.spawners
    local h = Vector3(0, 0, 1)

    for i = 1, #spawners, 1 do
        local spawner = spawners[i]
        local spawner_pos = Unit.local_position(spawner[1], 0)
        local boxed_pos = Vector3Box(spawner_pos)
        local event_data = {event_kind = "event_boss"}
        local path_pos, travel_dist, move_percent, path_index, sub_index =
            MainPathUtils.closest_pos_at_main_path(nil,
                                                   boxed_pos.unbox(boxed_pos))
        local activation_pos, _ = MainPathUtils.point_on_mainpath(nil,
                                                                  travel_dist -
                                                                      45)

        QuickDrawer:line(spawner_pos, spawner_pos + Vector3(0, 0, 15),
                         Color(125, 255, 0))
        QuickDrawer:sphere(spawner_pos, 5, Colors.get("red"))
        QuickDrawer:line(spawner_pos, activation_pos + h, Color(125, 255, 0))
        QuickDrawer:sphere(activation_pos + h, 0.25, Colors.get("red"))
    end

    return
end
mod.drawPats = function()
    local level_analysis = Managers.state.conflict.level_analysis
    local boss_waypoints = level_analysis.boss_waypoints
    local enemy_recycler = level_analysis.enemy_recycler

    if not boss_waypoints then
        mod:echo("No boss_waypoints found in level!")

        return false
    end

    local h = Vector3(0, 0, 1)

    for i = 1, #boss_waypoints, 1 do
        local section_waypoints = boss_waypoints[i]

        for j = 1, #section_waypoints, 1 do
            local waypoints_table = section_waypoints[j]

            if not optional_id or waypoints_table.id == optional_id then
                local spline_waypoints =
                    level_analysis.boxify_waypoint_table(level_analysis,
                                                         waypoints_table.waypoints)
                local event_data = {
                    spline_type = "patrol",
                    event_kind = "event_spline_patrol",
                    spline_id = waypoints_table.id,
                    spline_way_points = spline_waypoints
                }
                local spawner_pos = spline_waypoints[1]:unbox()
                local path_pos, travel_dist, move_percent, path_index, sub_index =
                    MainPathUtils.closest_pos_at_main_path(nil, spawner_pos)
                local activation_pos, _ =
                    MainPathUtils.point_on_mainpath(nil, travel_dist - 45)

                QuickDrawer:line(spawner_pos, spawner_pos + Vector3(0, 0, 15),
                                 Color(125, 255, 0))
                QuickDrawer:sphere(spawner_pos, 5, Colors.get("orange"))
                QuickDrawer:line(spawner_pos, activation_pos + h,
                                 Color(125, 255, 0))
                QuickDrawer:sphere(activation_pos + h, 0.15,
                                   Colors.get("orange"))
            end
        end
    end

    return
end
mod.drawPosition = function()
    local h = Vector3(0, 0, 1)
    local conflict_director = Managers.state.conflict
    local level_analysis = conflict_director.level_analysis
    local main_path_data = level_analysis.main_path_data
    local ahead_travel_dist = conflict_director.main_path_info.ahead_travel_dist
    local total_travel_dist = main_path_data.total_dist
    local travel_percentage = ahead_travel_dist / total_travel_dist * 100
    local point = MainPathUtils.point_on_mainpath(nil, ahead_travel_dist)

    QuickDrawer:sphere(point + h, 0.25, Colors.get("purple"))

    local player_unit = Managers.player:local_player().player_unit
    local player_pos = Unit.local_position(player_unit, 0)

    QuickDrawer:line(point + h, player_pos + h, Colors.get("purple"))

    return
end
mod.checkCollision = function()
    local player_manager = Managers.player
    local local_player = player_manager.local_player(player_manager)
    local player_unit = local_player and local_player.player_unit
    local current_position = Unit.local_position(player_unit, 0)

    mod:position_at_cursor(local_player)

    return
end
mod.position_at_cursor = function(self, local_player)
    local viewport_name = local_player.viewport_name
    local camera_position = Managers.state.camera:camera_position(viewport_name)
    local camera_rotation = Managers.state.camera:camera_rotation(viewport_name)
    local camera_direction = Quaternion.forward(camera_rotation)
    local range = 500
    local world = Managers.world:world("level_world")
    local physics_world = World.get_data(world, "physics_world")
    local new_position = nil
    local num_shots_this_frame = 15
    local angle = math.pi / 80
    local outer_angle = 0
    local outer_number = 1

    for j = 1, outer_number, 1 do
        local rotation = camera_rotation
        local rotation2 = camera_rotation

        for i = 1, num_shots_this_frame, 1 do
            rotation = mod.get_rotation(0, angle, 0, rotation)
            rotation2 = mod.get_rotation(0, angle * -1, 0, rotation2)
            local direction = Quaternion.forward(rotation)
            local is_hit, hit_pos, hit_dist, hit_norm, hit_actor =
                PhysicsWorld.immediate_raycast(physics_world, camera_position,
                                               direction, range, "closest",
                                               "collision_filter",
                                               "filter_player_mover")

            if is_hit then
                QuickDrawerStay:circle(hit_pos, 0.1, hit_norm, Colors.get("red"))
                QuickDrawerStay:vector(hit_pos, hit_norm * 0.1,
                                       Colors.get("red"))
            end

            direction = Quaternion.forward(rotation2)
            is_hit, hit_pos, hit_dist, hit_norm, hit_actor =
                PhysicsWorld.immediate_raycast(physics_world, camera_position,
                                               direction, range, "closest",
                                               "collision_filter",
                                               "filter_player_mover")

            if is_hit then
                QuickDrawerStay:circle(hit_pos, 0.1, hit_norm, Colors.get("red"))
                QuickDrawerStay:vector(hit_pos, hit_norm * 0.1,
                                       Colors.get("red"))
            end
        end

        outer_angle = outer_angle + angle
    end

    return new_position
end
mod.get_rotation = function(roll, pitch, yaw, current_rotation)
    local roll_rot = Quaternion(Vector3.forward(), roll)
    local pitch_rot = Quaternion(Vector3.up(), pitch)
    local yaw_rot = Quaternion(Vector3.right(), yaw)
    local combined_rotation = Quaternion.multiply(current_rotation, roll_rot)
    combined_rotation = Quaternion.multiply(combined_rotation, pitch_rot)
    combined_rotation = Quaternion.multiply(combined_rotation, yaw_rot)

    return combined_rotation
end

mod.command(mod, "testVect", "", function()
    local player_unit = Managers.player:local_player().player_unit
    local player_pos = Unit.local_position(player_unit, 0)
    local player_manager = Managers.player
    local local_player = player_manager.local_player(player_manager)
    local viewport_name = local_player.viewport_name
    local camera_position = Managers.state.camera:camera_position(viewport_name)
    local camera_rotation = Managers.state.camera:camera_rotation(viewport_name)
    local camera_direction = Quaternion.forward(camera_rotation)

    QuickDrawerStay:vector(player_pos, camera_direction, Colors.get("red"))

    return
end)

local RESPAWN_DISTANCE = 70
local END_OF_LEVEL_BUFFER = 35
local BOSS_TERROR_EVENT_LOOKUP = {
    boss_event_minotaur = true,
    boss_event_chaos_troll = true,
    boss_event_storm_fiend = true,
    boss_event_chaos_spawn = true,
    boss_event_rat_ogre = true
}

local function drawNextRespawn()
    local unit = get_respawn_unit(true)
    local pos = Unit.local_position(unit, 0)

    QuickDrawerStay:sphere(pos, 0.53, Colors.get("red"))

    return
end

mod.drawRespawns = function()
    local up = Vector3(0, 0, 1)
    local up2 = Vector3(0, 0, 0.5)
    local respawners = Managers.state.game_mode:game_mode()._adventure_spawning
                           ._respawn_handler._respawn_units
    local unit_local_position = Unit.local_position

    for i = 1, #respawners, 1 do
        local respawner = respawners[i]
        local best_point, best_travel_dist, move_percent, best_sub_index,
              best_main_path = MainPathUtils.closest_pos_at_main_path(nil,
                                                                      unit_local_position(
                                                                          respawner.unit,
                                                                          0))
        local pos = unit_local_position(respawner.unit, 0)

        QuickDrawer:sphere(pos, 0.53, Colors.get("cyan"))
        QuickDrawer:line(pos, pos + Vector3(0, 0, 15), Colors.get("cyan"))

        local pos_distance = MainPathUtils.point_on_mainpath(nil,
                                                             respawner.distance_through_level -
                                                                 RESPAWN_DISTANCE)

        QuickDrawer:line(pos + up, pos_distance + up, Colors.get("cyan"))
        QuickDrawer:sphere(pos_distance + up, 0.25, Colors.get("cyan"))

        local s = string.format("respawer %d, dist: %.1f, newdist: %.1f", i,
                                respawner.distance_through_level,
                                best_travel_dist)

        Debug.world_sticky_text(pos, s, "yellow")
    end

    return
end

mod.drawBossWalls = function()
    local door_system = Managers.state.entity:system("door_system")
    local boss_door_units = door_system:get_boss_door_units()
    for i = 1, #boss_door_units, 1 do
        local door_position = Unit.local_position(boss_door_units[i], 0)
        local box_extents = Vector3(2, 1, 1)
        local h = Vector3(0, 0, 1)
        local pose = Matrix4x4.from_quaternion_position(
                         Quaternion.look(Vector3.up()), door_position + h)
        QuickDrawer:box(pose, box_extents, Colors.get("yellow"))
    end
end

mod.command(mod, "injectBoss", "", function()
    local level_analysis = Managers.state.conflict.level_analysis
    local boss_waypoints = level_analysis.boss_waypoints
    local terror_spawners = level_analysis.terror_spawners
    local enemy_recycler = level_analysis.enemy_recycler

    if not boss_waypoints then return false end

    local terror_event_kind = "event_boss"
    local data = terror_spawners[terror_event_kind]
    local spawners = data.spawners
    local h = Vector3(0, 0, 1)

    table.clear(enemy_recycler.main_path_events)

    for i = 1, #spawners, 1 do
        local spawner = spawners[i]
        local spawner_pos = Unit.local_position(spawner[1], 0)
        local boxed_pos = Vector3Box(spawner_pos)
        local event_data = {event_kind = "event_boss"}

        enemy_recycler.add_main_path_terror_event(enemy_recycler, boxed_pos,
                                                  "boss_event_rat_ogre", 45,
                                                  event_data)
    end

    return
end)

local function draw_patrol_route(route_data, col)
    local h = Vector3(0, 0, 1)
    local waypoints = route_data.waypoints
    local wp = waypoints[1]
    local p1 = Vector3(wp[1], wp[2], wp[3]) + h

    QuickDrawer:sphere(p1, 0.5, Color(255, 255, 255))

    local p2 = nil

    for i = 2, #waypoints, 1 do
        wp = waypoints[i]
        p2 = Vector3(wp[1], wp[2], wp[3]) + h

        QuickDrawer:sphere(p2, 0.5, col)
        QuickDrawer:line(p1, p2, col)

        p1 = p2
    end
end

mod.drawPatrolRoutes = function()
    local section_colors = {
        Color(255, 0, 0), Color(255, 128, 0), Color(255, 255, 0),
        Color(0, 255, 255), Color(0, 0, 255), Color(128, 0, 255),
        Color(255, 0, 255), Color(0, 255, 0)
    }

    local level_analysis = Managers.state.conflict.level_analysis
    local boss_waypoints = level_analysis.boss_waypoints

    if boss_waypoints then
        for i = 1, #boss_waypoints, 1 do
            local section = boss_waypoints[i]
            local section_color = section_colors[i]

            for j = 1, #section, 1 do
                local color = section_colors[(i + j) % 5 + 1]
                local route_data = section[j]
                draw_patrol_route(route_data, color)
            end

        end
    end
end

mod.checkCollision = function()
    local player_manager = Managers.player
    local local_player = player_manager.local_player(player_manager)
    local player_unit = local_player and local_player.player_unit
    local current_position = Unit.local_position(player_unit, 0)

    mod:position_at_cursor(local_player)

    return
end
mod.position_at_cursor = function(self, local_player)
    local viewport_name = local_player.viewport_name
    local camera_position = Managers.state.camera:camera_position(viewport_name)
    local camera_rotation = Managers.state.camera:camera_rotation(viewport_name)
    local camera_direction = Quaternion.forward(camera_rotation)
    local range = 500
    local world = Managers.world:world("level_world")
    local physics_world = World.get_data(world, "physics_world")
    local new_position = nil
    local num_shots_this_frame = 15
    local angle = math.pi / 80
    local outer_angle = 0
    local outer_number = 1

    for j = 1, outer_number, 1 do
        local rotation = camera_rotation
        local rotation2 = camera_rotation

        for i = 1, num_shots_this_frame, 1 do
            rotation = mod.get_rotation(0, angle, 0, rotation)
            rotation2 = mod.get_rotation(0, angle * -1, 0, rotation2)
            local direction = Quaternion.forward(rotation)
            local is_hit, hit_pos, hit_dist, hit_norm, hit_actor =
                PhysicsWorld.immediate_raycast(physics_world, camera_position,
                                               direction, range, "closest",
                                               "collision_filter",
                                               "filter_player_mover")

            if is_hit then
                QuickDrawerStay:circle(hit_pos, 0.1, hit_norm, Colors.get("red"))
                QuickDrawerStay:vector(hit_pos, hit_norm * 0.1,
                                       Colors.get("red"))
            end

            direction = Quaternion.forward(rotation2)
            is_hit, hit_pos, hit_dist, hit_norm, hit_actor =
                PhysicsWorld.immediate_raycast(physics_world, camera_position,
                                               direction, range, "closest",
                                               "collision_filter",
                                               "filter_player_mover")

            if is_hit then
                QuickDrawerStay:circle(hit_pos, 0.1, hit_norm, Colors.get("red"))
                QuickDrawerStay:vector(hit_pos, hit_norm * 0.1,
                                       Colors.get("red"))
            end
        end

        outer_angle = outer_angle + angle
    end

    return new_position
end
mod.get_rotation = function(roll, pitch, yaw, current_rotation)
    local roll_rot = Quaternion(Vector3.forward(), roll)
    local pitch_rot = Quaternion(Vector3.up(), pitch)
    local yaw_rot = Quaternion(Vector3.right(), yaw)
    local combined_rotation = Quaternion.multiply(current_rotation, roll_rot)
    combined_rotation = Quaternion.multiply(combined_rotation, pitch_rot)
    combined_rotation = Quaternion.multiply(combined_rotation, yaw_rot)

    return combined_rotation
end

mod:hook(PickupSystem, "populate_pickups", function(func, self, checkpoint_data)
    PRIMARY_SPAWNER_DATA = {}
    SECONDARY_SPAWNER_DATA = {}
    PRIMARY_SPAWNER_DISPLAY_DATA = {}
    SECONDARY_SPAWNER_DISPLAY_DATA = {}
    GUARENTEED_DATA = {}

    local level_settings = LevelHelper:current_level_settings()
    local level_pickup_settings = level_settings.pickup_settings

    if not level_pickup_settings then
        Application.warning(
            "[PickupSystem] CURRENT LEVEL HAS NO PICKUP DATA IN ITS SETTINGS, NO PICKUPS WILL SPAWN ")

        return
    end

    local difficulty_manager = Managers.state.difficulty
    local difficulty = difficulty_manager:get_difficulty()
    local pickup_settings = level_pickup_settings[difficulty]

    if not pickup_settings then
        Application.warning(
            "[PickupSystem] CURRENT LEVEL HAS NO PICKUP DATA FOR CURRENT DIFFICULTY: %s, USING SETTINGS FOR EASY ",
            difficulty)

        pickup_settings = level_pickup_settings.default or
                              level_pickup_settings[1]
    end

    local function comparator(a, b)
        local percentage_a = Unit.get_data(a, "percentage_through_level")
        local percentage_b = Unit.get_data(b, "percentage_through_level")

        fassert(percentage_a,
                "Level Designer working on %s, You need to rebuild paths (pickup spawners broke)",
                level_settings.display_name)
        fassert(percentage_b,
                "Level Designer working on %s, You need to rebuild paths (pickup spawners broke)",
                level_settings.display_name)

        return percentage_a < percentage_b
    end

    mod.fake_spawn_guarenteed(self)

    local primary_pickup_spawners = self.primary_pickup_spawners
    local primary_pickup_settings = pickup_settings.primary or pickup_settings

    mod.fake_spread(primary_pickup_spawners, primary_pickup_settings,
                    comparator, PRIMARY_SPAWNER_DATA)
    mod.saveSpawnerData(PRIMARY_SPAWNER_DATA, PRIMARY_SPAWNER_DISPLAY_DATA)

    local secondary_pickup_spawners = self.secondary_pickup_spawners
    local secondary_pickup_settings = pickup_settings.secondary

    if secondary_pickup_settings then
        mod:echo("Secondary")
        mod.fake_spread(secondary_pickup_spawners, secondary_pickup_settings,
                    comparator, SECONDARY_SPAWNER_DATA)
        mod.saveSpawnerData(SECONDARY_SPAWNER_DATA,
                            SECONDARY_SPAWNER_DISPLAY_DATA)
        mod:dump(SECONDARY_SPAWNER_DISPLAY_DATA, "", 4)
    end

    func(self, checkpoint_data)
end)

mod.fake_spawn_guarenteed = function(self)
    local color_vector_orange = Vector3(255, 165, 0)
    local color_vector_green = Vector3(0, 255, 0)
    local color_vector_blue = Vector3(0, 0, 255)
    local color_vector_red = Vector3(255, 0, 0)
    local color_vector = Vector3(255, 255, 0)
    local color_progress = Vector3(224, 255, 255, 0)
    local spawners = self.guaranteed_pickup_spawners
    local num_spawners = #spawners
    local spawn_type = "guaranteed"

    for i = 1, num_spawners, 1 do
        local spawner_unit = spawners[i]
        local potential_pickups = {}

        for pickup_name, settings in pairs(AllPickups) do
            local can_spawn = self:_can_spawn(spawner_unit, pickup_name)
            local color = color_vector

            if string.find(pickup_name, "damage_boost") then
                color = color_vector_orange
            elseif string.find(pickup_name, "speed_boost") then
                color = color_vector_blue
            elseif string.find(pickup_name, "healing_draught") or
                string.find(pickup_name, "first_aid") then
                color = color_vector_green
            elseif string.find(pickup_name, "grenade") then
                color = color_vector_red
            end

            if can_spawn and 0 < settings.spawn_weighting then
                table.insert(potential_pickups, {
                    pickup_name,
                    displayColor = {color[1], color[2], color[3]}
                })
            end
        end

        GUARENTEED_DATA[spawner_unit] = potential_pickups
    end
end

mod.fake_spread = function(pickup_spawners, pickup_settings, comparator,
                           spawner_data)
    table.sort(pickup_spawners, comparator)
    for pickup_type, value in pairs(pickup_settings) do
        local num_sections = 0
        if type(value) == "table" then
            for pickup_name, amount in pairs(value) do
                num_sections = num_sections + amount
            end
        else
            num_sections = value
        end
        mod:echo(pickup_type)
        mod:echo(num_sections)

        local section_size = num_sections / 1
        local section_start_point = 0
        local section_end_point = 0

        for i = 1, num_sections, 1 do
            local num_pickup_spawners = #pickup_spawners
            section_end_point = section_start_point + section_size

            for j = 1, num_pickup_spawners, 1 do
                local spawner_unit = pickup_spawners[j]
                local percentage_through_level =
                    Unit.get_data(spawner_unit, "percentage_through_level")

                if (section_start_point <= percentage_through_level and
                    percentage_through_level < section_end_point) or
                    (num_sections == i and percentage_through_level == 1) then
                    if not spawner_data[spawner_unit] then
                        spawner_data[spawner_unit] = {}
                    end

                    table.insert(spawner_data[spawner_unit],
                                 {pickup_type, i, j, percentage_through_level})
                end
            end

            section_start_point = section_end_point
        end
    end
end

mod.drawItemSpawners = function()
    local debug_text = Managers.state.debug_text
    local text_size = mod:get("item_text_mult")
    local z = Vector3.up() * 0.5
    local color_vector_orange = Vector3(255, 165, 0, 0)
    local color_vector_green = Vector3(0, 255, 0, 0)
    local color_vector_blue = Vector3(0, 0, 255, 0)
    local color_vector_red = Vector3(255, 0, 0, 0)
    local color_vector = Vector3(255, 255, 0, 0)
    local color_progress = Vector3(224, 255, 255, 0)
    local pickup_ext = Managers.state.entity:system("pickup_system")

    local player_unit = Managers.player:local_player().player_unit
    local player_pos = Unit.local_position(player_unit, 0)

    local max_distance = mod:get("text_distance")

    for spawn_unit, spawner_table in pairs(PRIMARY_SPAWNER_DISPLAY_DATA) do
        local spawner_pos = Unit.local_position(spawn_unit, 0)
        local count = 0

        if Vector3.distance(player_pos, spawner_pos) < max_distance then
            for _, pickup_info in pairs(PRIMARY_SPAWNER_DISPLAY_DATA[spawn_unit]
                                            .data) do
                debug_text.output_world_text(debug_text,
                                             pickup_info.displayString,
                                             text_size, spawner_pos + z +
                                                 Vector3.up() * count *
                                                 text_size, nil,
                                             "category: item_spawner_id",
                                             Vector3(
                                                 pickup_info.displayColor[1],
                                                 pickup_info.displayColor[2],
                                                 pickup_info.displayColor[3], 0),
                                             "player_1")

                count = count + 1
            end

            local pogress_info = string.format("Order: %i Progress: %.2f%%",
                                               PRIMARY_SPAWNER_DISPLAY_DATA[spawn_unit]
                                                   .order,
                                               PRIMARY_SPAWNER_DISPLAY_DATA[spawn_unit]
                                                   .progress)

            debug_text.output_world_text(debug_text, pogress_info, text_size,
                                         spawner_pos + z + Vector3.up() * count *
                                             text_size, nil,
                                         "category: item_spawner_id",
                                         color_progress, "player_1")
        end
        QuickDrawer:sphere(spawner_pos, 0.25, Colors.get("yellow"))
    end

    for spawn_unit, spawner_table in pairs(SECONDARY_SPAWNER_DISPLAY_DATA) do
        local spawner_pos = Unit.local_position(spawn_unit, 0)
        local count = 0

        if Vector3.distance(player_pos, spawner_pos) < max_distance then
            for _, pickup_info in pairs(
                                      SECONDARY_SPAWNER_DISPLAY_DATA[spawn_unit]
                                          .data) do
                debug_text.output_world_text(debug_text,
                                             pickup_info.displayString,
                                             text_size, spawner_pos + z +
                                                 Vector3.up() * count *
                                                 text_size, nil,
                                             "category: item_spawner_id",
                                             Vector3(
                                                 pickup_info.displayColor[1],
                                                 pickup_info.displayColor[2],
                                                 pickup_info.displayColor[3], 0),
                                             "player_1")

                count = count + 1
            end

            local pogress_info = string.format("Order: %i Progress: %.2f%%",
                                               SECONDARY_SPAWNER_DISPLAY_DATA[spawn_unit]
                                                   .order,
                                               SECONDARY_SPAWNER_DISPLAY_DATA[spawn_unit]
                                                   .progress)

            debug_text.output_world_text(debug_text, pogress_info, text_size,
                                         spawner_pos + z + Vector3.up() * count *
                                             text_size, nil,
                                         "category: item_spawner_id",
                                         color_progress, "player_1")
        end
        QuickDrawer:sphere(spawner_pos, 0.25, Colors.get("orange"))
    end

    for spawner_unit, data in pairs(GUARENTEED_DATA) do
        local spawner_pos = Unit.local_position(spawner_unit, 0)
        QuickDrawer:sphere(spawner_pos, 0.25, Colors.get("red"))
        local count = 0
        if Vector3.distance(player_pos, spawner_pos) < max_distance then
            for _, pickup in pairs(data) do
                debug_text.output_world_text(debug_text, pickup[1], text_size,
                                             spawner_pos + z + Vector3.up() *
                                                 count * text_size, nil,
                                             "category: item_spawner_id",
                                             Vector3(pickup.displayColor[1],
                                                     pickup.displayColor[2],
                                                     pickup.displayColor[3], 0),
                                             "player_1")

                count = count + 1
            end
        end
    end

    ITEM_TEXT = true

    return
end

mod.saveSpawnerData = function(spawner_data, spawner_display_data)
    local color_vector_orange = Vector3(255, 165, 0)
    local color_vector_green = Vector3(0, 255, 0)
    local color_vector_blue = Vector3(0, 191, 255)
    local color_vector_red = Vector3(255, 0, 0)
    local color_vector_purple = Vector3(138, 43, 226)
    local color_vector = Vector3(255, 255, 0)
    local color_progress = Vector3(224, 255, 255, 0)
    local pickup_ext = Managers.state.entity:system("pickup_system")

    for spawn_unit, spawner_table in pairs(spawner_data) do
        spawner_display_data[spawn_unit] =
            {
                order = spawner_table[1][3],
                progress = spawner_table[1][4] * 100,
                data = {}
            }
        local spawner_pos = Unit.local_position(spawn_unit, 0)
        local count = 0

        for _, pickup_info in pairs(spawner_table) do
            for pickup_name, settings in pairs(Pickups[pickup_info[1]]) do
                if Unit.get_data(spawn_unit, pickup_name) then
                    local color = color_vector

                    if string.find(pickup_name, "damage_boost") then
                        color = color_vector_orange
                    elseif string.find(pickup_name, "speed_boost") then
                        color = color_vector_blue
                    elseif string.find(pickup_name, "cooldown_reduction") then
                        color = color_vector_purple
                    elseif string.find(pickup_name, "healing_draught") or
                        string.find(pickup_name, "first_aid") then
                        color = color_vector_green
                    elseif string.find(pickup_name, "grenade") then
                        color = color_vector_red
                    end

                    table.insert(spawner_display_data[spawn_unit].data, {
                        displayString = tostring(pickup_info[2]) .. " " ..
                            pickup_name,
                        displayColor = {color[1], color[2], color[3]}
                    })

                    count = count + 1
                end
            end
        end
    end

    return
end
-- mod:dofile("scripts/mods/Display Main Path/game_code/debug_drawer")
-- script_data.disable_debug_draw = false

-- function mod.update ()
-- 	if Managers.state.debug then
-- 	  for _, drawer in pairs(Managers.state.debug._drawers) do
-- 		drawer:update(Managers.state.debug._world)
-- 	  end
-- 	end
--   end

--   local RESPAWN_DISTANCE = 70
--   local END_OF_LEVEL_BUFFER = 35
--   local BOSS_TERROR_EVENT_LOOKUP = {
-- 	  boss_event_chaos_spawn = true,
-- 	  boss_event_storm_fiend = true,
-- 	  boss_event_chaos_troll = true,
-- 	  boss_event_minotaur = true,
-- 	  boss_event_rat_ogre = true
--   }

-- mod:command("pickup", "", function()
-- 	local player_unit = Managers.player:local_player().player_unit
-- 	local pickup_ext = Managers.state.entity:system("pickup_system")
-- 	mod:echo(pickup_ext)
-- 	mod:dump(pickup_ext.primary_pickup_spawners, "t", 1) 
-- 	local primary_pickup_spawners = pickup_ext.primary_pickup_spawners

-- 	for i = 1, #primary_pickup_spawners, 1 do
-- 		mod:echo(primary_pickup_spawners[i])
-- 		local item_pos = Unit.local_position(primary_pickup_spawners[i], 0)
-- 		mod:echo(item_pos)
-- 		QuickDrawerStay:sphere(item_pos, .25, Colors.get("blue"))

-- 	end
-- 	local secondary_pickup_spawners = pickup_ext.secondary_pickup_spawners

-- 	for i = 1, #secondary_pickup_spawners, 1 do
-- 		mod:echo(secondary_pickup_spawners[i])
-- 		local item_pos = Unit.local_position(secondary_pickup_spawners[i], 0)
-- 		mod:echo(item_pos)
-- 		QuickDrawerStay:sphere(item_pos, .25, Colors.get("green"))

-- 	end

-- 	local guaranteed_pickup_spawners = pickup_ext.guaranteed_pickup_spawners

-- 	for i = 1, #guaranteed_pickup_spawners, 1 do
-- 		mod:echo(guaranteed_pickup_spawners[i])
-- 		local item_pos = Unit.local_position(guaranteed_pickup_spawners[i], 0)
-- 		mod:echo(item_pos)
-- 		QuickDrawerStay:sphere(item_pos, .25, Colors.get("red"))

-- 	end
-- end)

-- local RENDER = false 

-- local function get_respawn_unit(ignore_boss_doors)
--     local respawn_units = Managers.state.game_mode:game_mode()
--                               ._adventure_spawning._respawn_handler
--                               ._respawn_units
--     local active_overridden = Managers.state.game_mode:game_mode()
--                                   ._adventure_spawning._respawn_handler
--                                   ._active_overridden_units

--     if next(active_overridden) then
--         for unit, respawn_data in pairs(active_overridden) do
--             if respawn_data.available then
--                 respawn_data.available = false

--                 print("Returning override respawn unit")

--                 return respawn_data.unit
--             end
--         end

--         print("No available overriden respawning units found!")

--         return nil
--     end

--     local conflict = Managers.state.conflict
--     local level_analysis = conflict.level_analysis
--     local main_paths = level_analysis:get_main_paths()
--     local player_unit = Managers.player:local_player().player_unit
--     local ahead_position = Unit.local_position(player_unit, 0)

--     local ahead_main_path_index = conflict.main_path_info.current_path_index

--     if not ahead_position then return end

--     local _, ahead_unit_travel_dist = MainPathUtils.closest_pos_at_main_path(
--                                           main_paths, ahead_position)
--     local total_path_dist = MainPathUtils.total_path_dist()
--     local ahead_pos = MainPathUtils.point_on_mainpath(main_paths,
--                                                       ahead_unit_travel_dist +
--                                                           RESPAWN_DISTANCE)

--     if not ahead_pos then
--         print("respawner: far ahead not found, using spawner behind")

--         ahead_pos = MainPathUtils.point_on_mainpath(main_paths,
--                                                     total_path_dist -
--                                                         END_OF_LEVEL_BUFFER)

--         fassert(ahead_pos, "Cannot find point on mainpath to respawn cage")
--     end

--     local path_pos, wanted_respawn_travel_dist =
--         MainPathUtils.closest_pos_at_main_path(main_paths, ahead_pos)
--     local door_system = Managers.state.entity:system("door_system")
--     local boss_door_units = door_system:get_boss_door_units()
--     local enemy_recycler = conflict.enemy_recycler
--     local current_terror_event =
--         enemy_recycler.main_path_events[enemy_recycler.current_main_path_event_id]
--     local current_terror_event_type = current_terror_event and
--                                           current_terror_event[3]
--     local has_upcoming_boss_terror_event =
--         BOSS_TERROR_EVENT_LOOKUP[current_terror_event_type]
--     local current_terror_event_travel_dist =
--         enemy_recycler.current_main_path_event_activation_dist
--     local boss_door_between_travel_dist = nil
--     local closest_boss_door_travel_dist = 0
--     local closest_door_dist = math.huge
--     local has_close_boss_door = nil

--     for i = 1, #boss_door_units, 1 do
--         local door_unit = boss_door_units[i]
--         local door_position = Unit.world_position(door_unit, 0)
--         local door_extension = ScriptUnit.extension(door_unit, "door_system")
--         local door_state = door_extension.current_state
--         local _, door_travel_dist = MainPathUtils.closest_pos_at_main_path(
--                                         main_paths, door_position)
--         local dist_to_door = door_travel_dist - ahead_unit_travel_dist

--         if closest_door_dist > dist_to_door and dist_to_door >= 0 and
--             ((door_state and door_state == "closed") or
--                 (has_upcoming_boss_terror_event and
--                     current_terror_event_travel_dist < door_travel_dist)) then
--             closest_door_dist = dist_to_door
--             closest_boss_door_travel_dist = door_travel_dist
--             has_close_boss_door = true
--         end
--     end

--     local num_spawners = #respawn_units
--     local greatest_distance = 0
--     local selected_unit_index = nil

--     for i = 1, num_spawners, 1 do
--         local respawn_data = respawn_units[i]

--         if respawn_data.available then
--             local distance_through_level = respawn_data.distance_through_level

--             if has_close_boss_door then
--                 if wanted_respawn_travel_dist <= distance_through_level and
--                     distance_through_level < closest_boss_door_travel_dist then
--                     selected_unit_index = i

--                     break
--                 elseif greatest_distance < distance_through_level and
--                     distance_through_level < closest_boss_door_travel_dist then
--                     selected_unit_index = i
--                     greatest_distance = distance_through_level
--                 end
--             elseif wanted_respawn_travel_dist <= distance_through_level then
--                 selected_unit_index = i

--                 break
--             elseif greatest_distance < distance_through_level then
--                 selected_unit_index = i
--                 greatest_distance = distance_through_level
--             end
--         end
--     end

--     if not selected_unit_index then return nil end

--     local respawn_data = respawn_units[selected_unit_index]
--     local selected_unit = respawn_data.unit
--     -- respawn_data.available = false

--     return selected_unit
-- end

-- local function drawBossWalls() 
--     local door_system = Managers.state.entity:system("door_system")
--     local boss_door_units = door_system:get_boss_door_units()
--     for i = 1, #boss_door_units, 1 do
--         local door_position = Unit.local_position(boss_door_units[i], 0)
--         local box_extents = Vector3(2, 1, 1)
--         local h = Vector3(0,0,1)
--         local pose = Matrix4x4.from_quaternion_position(Quaternion.look(Vector3.up()), door_position + h)
--         QuickDrawerStay:box(pose, box_extents, Colors.get("yellow"))
--     end
-- end

-- local function drawBosses()
--     local level_analysis = Managers.state.conflict.level_analysis
--     local boss_waypoints = level_analysis.boss_waypoints
--     local terror_spawners = level_analysis.terror_spawners
--     local enemy_recycler = level_analysis.enemy_recycler

--     if not boss_waypoints then return false end

--     print("SPAWN BOSS SPLINES")

--     local terror_event_kind = "event_boss"
--     local data = terror_spawners[terror_event_kind]
--     local spawners = data.spawners
--     local h = Vector3(0, 0, 1)

--     for i = 1, #spawners, 1 do
--         local spawner = spawners[i]
--         local spawner_pos = Unit.local_position(spawner[1], 0)
--         local boxed_pos = Vector3Box(spawner_pos)
--         local event_data = {event_kind = "event_boss"}

--         local path_pos, travel_dist, move_percent, path_index, sub_index =
--             MainPathUtils.closest_pos_at_main_path(nil, boxed_pos:unbox())
--         local activation_pos, _ = MainPathUtils.point_on_mainpath(nil,
--                                                                   travel_dist -
--                                                                       45)

--         QuickDrawerStay:line(spawner_pos, spawner_pos + Vector3(0, 0, 15),
--                              Color(125, 255, 0))
--         QuickDrawerStay:sphere(spawner_pos, 5, Colors.get("red"))
--         QuickDrawerStay:line(spawner_pos, activation_pos + h, Color(125, 255, 0))
--         QuickDrawerStay:sphere(activation_pos + h, .25, Colors.get("red"))
--     end

-- end

-- local function drawPats()
--     local level_analysis = Managers.state.conflict.level_analysis
--     local boss_waypoints = level_analysis.boss_waypoints
--     local enemy_recycler = level_analysis.enemy_recycler

--     if not boss_waypoints then
--         print("No boss_waypoints found in level!")

--         return false
--     end

--     local h = Vector3(0, 0, 1)

--     print("SPAWN BOSS SPLINES")

--     for i = 1, #boss_waypoints, 1 do
--         local section_waypoints = boss_waypoints[i]

--         for j = 1, #section_waypoints, 1 do
--             local waypoints_table = section_waypoints[j]

--             if not optional_id or waypoints_table.id == optional_id then
--                 local spline_waypoints =
--                     level_analysis:boxify_waypoint_table(
--                         waypoints_table.waypoints)
--                 local event_data = {
--                     spline_type = "patrol",
--                     event_kind = "event_spline_patrol",
--                     spline_id = waypoints_table.id,
--                     spline_way_points = spline_waypoints
--                 }

--                 print("INJECTING BOSS SPLINE ID", waypoints_table.id)

--                 local spawner_pos = spline_waypoints[1]:unbox()
--                 local path_pos, travel_dist, move_percent, path_index, sub_index =
--                     MainPathUtils.closest_pos_at_main_path(nil, spawner_pos)
--                 local activation_pos, _ =
--                     MainPathUtils.point_on_mainpath(nil, travel_dist - 45)

--                 QuickDrawerStay:line(spawner_pos,
--                                      spawner_pos + Vector3(0, 0, 15),
--                                      Color(125, 255, 0))
--                 QuickDrawerStay:sphere(spawner_pos, 5, Colors.get("orange"))
--                 QuickDrawerStay:line(spawner_pos, activation_pos + h,
--                                      Color(125, 255, 0))
--                 QuickDrawerStay:sphere(activation_pos + h, .25,
--                                        Colors.get("orange"))
--             end
--         end
--     end
-- end

-- local function drawNextRespawn()
--     local unit = get_respawn_unit(true)
--     local pos = Unit.local_position(unit, 0)
--     QuickDrawerStay:sphere(pos, 0.53, Colors.get("red"))
-- end

-- local function drawRespawns()
--     local up = Vector3(0, 0, 1)
--     local up2 = Vector3(0, 0, .5)
--     local respawners = Managers.state.game_mode:game_mode()._adventure_spawning
--                            ._respawn_handler._respawn_units
--     local unit_local_position = Unit.local_position

--     for i = 1, #respawners, 1 do
--         local respawner = respawners[i]
--         local best_point, best_travel_dist, move_percent, best_sub_index,
--               best_main_path = MainPathUtils.closest_pos_at_main_path(nil,
--                                                                       unit_local_position(
--                                                                           respawner.unit,
--                                                                           0))
--         local pos = unit_local_position(respawner.unit, 0)

--         QuickDrawerStay:sphere(pos, 0.53, Colors.get("cyan"))
--         QuickDrawerStay:line(pos, pos + Vector3(0, 0, 15), Colors.get("cyan"))

--         local pos_distance = MainPathUtils.point_on_mainpath(nil, respawner.distance_through_level - RESPAWN_DISTANCE)
--         QuickDrawerStay:line(pos + up , pos_distance + up, Colors.get("cyan"))
--         QuickDrawerStay:sphere(pos_distance + up, .25, Colors.get("cyan"))

--         local s = string.format("respawer %d, dist: %.1f, newdist: %.1f", i,
--                                 respawner.distance_through_level,
--                                 best_travel_dist)

--         Debug.world_sticky_text(pos, s, "yellow")
--     end
-- end

-- local function drawMainPath()
--     local level_analysis = Managers.state.conflict.level_analysis
--     local h = Vector3(0, 0, 1)

--     local main_paths = level_analysis.main_paths
--     for i = 1, #main_paths, 1 do
--         local path = main_paths[i].nodes
--         for j = 1, #path, 1 do
--             local position = Vector3(path[j][1], path[j][2], path[j][3])
--             QuickDrawerStay:sphere(position + h, .25, Colors.get("green"))
--             if j == #path and i ~= #main_paths then
--                 local nextPositon = Vector3(main_paths[i + 1].nodes[1][1],
--                                             main_paths[i + 1].nodes[1][2],
--                                             main_paths[i + 1].nodes[1][3])
--                 QuickDrawerStay:line(position + h, nextPositon + h,
--                                      Colors.get("yellow"))
--             elseif j ~= #path then
--                 local nextPositon = Vector3(path[j + 1][1], path[j + 1][2],
--                                             path[j + 1][3])
--                 QuickDrawerStay:line(position + h, nextPositon + h,
--                                      Colors.get("green"))
--             end
--         end
--     end
-- end

-- local function render()
--     if mod:get("main_path") then drawMainPath() end
--     if mod:get("boss") then drawBosses() end
--     if mod:get("patrol") then drawPats() end
--     if mod:get("respawn") then drawRespawns() end
--     if mod:get("boss_walls") then drawBossWalls() end 
-- end

-- mod:command("drawMainPath", "", function() render() end)

-- mod:hook_safe(IngameHud, "update", function(self)
--     -- If the EquipmentUI isn't visible or the player is dead
--     -- then let's not show the Dodge Count UI
--     if not self._currently_visible_components.EquipmentUI or
--         self:is_own_player_dead() or Managers.state.game_mode._level_key ==
--         "inn_level" then
--         RENDER = false
--         return
--     end

--     if not RENDER then
--         render()
--         RENDER = true
--     end

--     local t = Managers.time:time("game")
--     local player_unit = Managers.player:local_player().player_unit
--     local status_system = ScriptUnit.has_extension(player_unit, "status_system")

--     if not status_system or not player_unit then return end

-- 	if mod:get("player_pos") then
-- 		local h = Vector3(0, 0, 1)

-- 		local conflict_director = Managers.state.conflict
-- 		local level_analysis = conflict_director.level_analysis
-- 		local main_path_data = level_analysis.main_path_data
-- 		local ahead_travel_dist = conflict_director.main_path_info.ahead_travel_dist
-- 		local total_travel_dist = main_path_data.total_dist
-- 		local travel_percentage = ahead_travel_dist / total_travel_dist * 100

-- 		local point = MainPathUtils.point_on_mainpath(nil, ahead_travel_dist)
-- 		QuickDrawer:sphere(point + h, .25, Colors.get("purple"))

-- 		local player_unit = Managers.player:local_player().player_unit
-- 		local player_pos = Unit.local_position(player_unit, 0)
-- 		QuickDrawer:line(point + h, player_pos +h, Colors.get("purple"))
-- 	end

-- end)

-- function mod:on_setting_changed()
--     QuickDrawerStay:reset()
--     render()
-- end

-- mod:command("injectBoss", "", function() 
--     local level_analysis = Managers.state.conflict.level_analysis
--     local boss_waypoints = level_analysis.boss_waypoints
--     local terror_spawners = level_analysis.terror_spawners
--     local enemy_recycler = level_analysis.enemy_recycler

--     if not boss_waypoints then
--         return false
--     end

--     local terror_event_kind = "event_boss"
--     local data = terror_spawners[terror_event_kind]
--     local spawners = data.spawners
--     local h = Vector3(0, 0, 1)

--     table.clear(enemy_recycler.main_path_events)

--     for i = 1, #spawners, 1 do
--         local spawner = spawners[i]

--         local spawner_pos = Unit.local_position(spawner[1], 0)
--         local boxed_pos = Vector3Box(spawner_pos)
--         local event_data = {
--             event_kind = "event_boss"
--         }

--         enemy_recycler:add_main_path_terror_event(boxed_pos, "boss_event_rat_ogre", 45, event_data)

--     end

-- end) 

-- mod:command("where", "", function()
--     local h = Vector3(0, 0, 1)
--     local h2 = Vector3(0, 0, .5)
--     local unit = get_respawn_unit(true)
--     local pos = Unit.local_position(unit, 0) 

--     -- QuickDrawerStay:sphere(pos, 0.53, Colors.get("red"))
--     local conflict_director = Managers.state.conflict
--     local level_analysis = conflict_director.level_analysis
--     local main_path_data = level_analysis.main_path_data
--     local ahead_travel_dist = conflict_director.main_path_info.ahead_travel_dist
--     local total_travel_dist = main_path_data.total_dist
--     local travel_percentage = ahead_travel_dist / total_travel_dist * 100

--     local point = MainPathUtils.point_on_mainpath(nil, ahead_travel_dist)
--     QuickDrawerStay:line(point + h, pos + h2, Colors.get("yellow"))
--     QuickDrawerStay:sphere(point + h, .25, Colors.get("yellow"))
--     -- mod:dump( get_respawn_unit(true),"t", 2)

-- end) 

-- local function set_invisible(player_unit, set_status)
--     if Unit.alive(player_unit) then
--         local status_extension = ScriptUnit.extension(player_unit,
--                                                       "status_system")
--         status_extension:set_invisible(set_status)
--         status_extension:set_noclip(set_status)
--     end
-- end

-- mod:command("invisOn", "", function()
--     local player_unit = Managers.player:local_player().player_unit
--     set_invisible(player_unit, true)
-- end)

-- mod:command("invisOff", "", function()
--     local player_unit = Managers.player:local_player().player_unit
--     set_invisible(player_unit, false)
-- end)

