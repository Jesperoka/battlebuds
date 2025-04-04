/// File generated by visual_assets.py - Manual changes will probably be overwritten.
/// Stage parts are also separated into 'Modes', which doesn't really make sense,
/// but I don't feel like having separate logic for stages.
const SDL_Texture = @import("sdl2").SDL_Texture;
const StaticMap = @import("utils.zig").StaticMap;
const fields = @import("std").meta.fields;
const print = @import("std").debug.print;

pub const Texture = struct {
    ptr: ?*SDL_Texture,
    width: c_int,
    height: c_int,
};

pub const Asset = struct {
    path: []const u8,
    id: ID,
};

pub const ID = enum(u16) {
    CHARACTER_TEST_FLYING_RIGHT,
    CHARACTER_TEST_STANDING,
    CHARACTER_TEST_ATTACKING_LEFT,
    CHARACTER_TEST_FLYING_LEFT,
    CHARACTER_TEST_RUNNING_RIGHT,
    CHARACTER_TEST_ATTACKING_RIGHT,
    CHARACTER_TEST_RUNNING_LEFT,
    CHARACTER_TEST_ATTACKING_DOWN,
    CHARACTER_TEST_ATTACKING_UP,
    CHARACTER_TEST_FLYING_NEUTRAL,
    CHARACTER_TEST_JUMPING,
    CHARACTER_WURMPLE_FLYING_RIGHT,
    CHARACTER_WURMPLE_STANDING,
    CHARACTER_WURMPLE_ATTACKING_LEFT,
    CHARACTER_WURMPLE_FLYING_LEFT,
    CHARACTER_WURMPLE_RUNNING_RIGHT,
    CHARACTER_WURMPLE_ATTACKING_RIGHT,
    CHARACTER_WURMPLE_RUNNING_LEFT,
    CHARACTER_WURMPLE_ATTACKING_DOWN,
    CHARACTER_WURMPLE_ATTACKING_UP,
    CHARACTER_WURMPLE_FLYING_NEUTRAL,
    CHARACTER_WURMPLE_JUMPING,
    DONT_LOAD_TEXTURE,
    PROJECTILE_TEST_FLYING_RIGHT,
    STAGE_METEOR_BACKGROUND,
    STAGE_METEOR_PLATFORMS,
    STAGE_METEOR_FLOOR,
    STAGE_TEST00_BACKGROUND,
    STAGE_TEST00_PLATFORMS,
    MENU_WAITING_FORINPUT,
    MENU_STAGE_SELECTED,

    pub inline fn int(id: ID) u16 {
        return @intFromEnum(id);
    }

    pub inline fn size() u16 {
        return fields(ID).len;
    }
};

pub fn IDFromEntityMode(mode: EntityMode) ID {
    switch (mode) {
        .character_test => |character_test_mode| switch (character_test_mode) {
            .FLYING_RIGHT => return ID.CHARACTER_TEST_FLYING_RIGHT,
            .STANDING => return ID.CHARACTER_TEST_STANDING,
            .ATTACKING_LEFT => return ID.CHARACTER_TEST_ATTACKING_LEFT,
            .FLYING_LEFT => return ID.CHARACTER_TEST_FLYING_LEFT,
            .RUNNING_RIGHT => return ID.CHARACTER_TEST_RUNNING_RIGHT,
            .ATTACKING_RIGHT => return ID.CHARACTER_TEST_ATTACKING_RIGHT,
            .RUNNING_LEFT => return ID.CHARACTER_TEST_RUNNING_LEFT,
            .ATTACKING_DOWN => return ID.CHARACTER_TEST_ATTACKING_DOWN,
            .ATTACKING_UP => return ID.CHARACTER_TEST_ATTACKING_UP,
            .FLYING_NEUTRAL => return ID.CHARACTER_TEST_FLYING_NEUTRAL,
            .JUMPING => return ID.CHARACTER_TEST_JUMPING,
        },
        .character_wurmple => |character_wurmple_mode| switch (character_wurmple_mode) {
            .FLYING_RIGHT => return ID.CHARACTER_WURMPLE_FLYING_RIGHT,
            .STANDING => return ID.CHARACTER_WURMPLE_STANDING,
            .ATTACKING_LEFT => return ID.CHARACTER_WURMPLE_ATTACKING_LEFT,
            .FLYING_LEFT => return ID.CHARACTER_WURMPLE_FLYING_LEFT,
            .RUNNING_RIGHT => return ID.CHARACTER_WURMPLE_RUNNING_RIGHT,
            .ATTACKING_RIGHT => return ID.CHARACTER_WURMPLE_ATTACKING_RIGHT,
            .RUNNING_LEFT => return ID.CHARACTER_WURMPLE_RUNNING_LEFT,
            .ATTACKING_DOWN => return ID.CHARACTER_WURMPLE_ATTACKING_DOWN,
            .ATTACKING_UP => return ID.CHARACTER_WURMPLE_ATTACKING_UP,
            .FLYING_NEUTRAL => return ID.CHARACTER_WURMPLE_FLYING_NEUTRAL,
            .JUMPING => return ID.CHARACTER_WURMPLE_JUMPING,
        },
        .dont_load => |dont_load_mode| switch (dont_load_mode) {
            .TEXTURE => return ID.DONT_LOAD_TEXTURE,
        },
        .projectile_test => |projectile_test_mode| switch (projectile_test_mode) {
            .FLYING_RIGHT => return ID.PROJECTILE_TEST_FLYING_RIGHT,
        },
        .stage_meteor => |stage_meteor_mode| switch (stage_meteor_mode) {
            .BACKGROUND => return ID.STAGE_METEOR_BACKGROUND,
            .PLATFORMS => return ID.STAGE_METEOR_PLATFORMS,
            .FLOOR => return ID.STAGE_METEOR_FLOOR,
        },
        .stage_test00 => |stage_test00_mode| switch (stage_test00_mode) {
            .BACKGROUND => return ID.STAGE_TEST00_BACKGROUND,
            .PLATFORMS => return ID.STAGE_TEST00_PLATFORMS,
        },
        .menu_waiting => |menu_waiting_mode| switch (menu_waiting_mode) {
            .FORINPUT => return ID.MENU_WAITING_FORINPUT,
        },
        .menu_stage => |menu_stage_mode| switch (menu_stage_mode) {
            .SELECTED => return ID.MENU_STAGE_SELECTED,
        },
    }
    unreachable; // shouldn't happen
}

pub const EntityMode = union(enum(u16)) {
    character_test: CharacterTestMode,
    character_wurmple: CharacterWurmpleMode,
    dont_load: DontLoadMode,
    projectile_test: ProjectileTestMode,
    stage_meteor: StageMeteorMode,
    stage_test00: StageTest00Mode,
    menu_waiting: MenuWaitingMode,
    menu_stage: MenuStageMode,

    pub fn from_enum_literal(comptime Type: type, comptime val: @TypeOf(.enum_literal)) @This() {
        switch (Type) {
            CharacterTestMode => |Enum| return @unionInit(@This(), "character_test", @as(Enum, val)),
            CharacterWurmpleMode => |Enum| return @unionInit(@This(), "character_wurmple", @as(Enum, val)),
            DontLoadMode => |Enum| return @unionInit(@This(), "dont_load", @as(Enum, val)),
            ProjectileTestMode => |Enum| return @unionInit(@This(), "projectile_test", @as(Enum, val)),
            StageMeteorMode => |Enum| return @unionInit(@This(), "stage_meteor", @as(Enum, val)),
            StageTest00Mode => |Enum| return @unionInit(@This(), "stage_test00", @as(Enum, val)),
            MenuWaitingMode => |Enum| return @unionInit(@This(), "menu_waiting", @as(Enum, val)),
            MenuStageMode => |Enum| return @unionInit(@This(), "menu_stage", @as(Enum, val)),

            else => |mode| {
                print("\nUnexpected entity mode: {any}\n", .{mode});
                unreachable; // shouldn't happen
            }
        }
    }
};

pub const CharacterTestMode = enum(u16) {
    FLYING_RIGHT,
    STANDING,
    ATTACKING_LEFT,
    FLYING_LEFT,
    RUNNING_RIGHT,
    ATTACKING_RIGHT,
    RUNNING_LEFT,
    ATTACKING_DOWN,
    ATTACKING_UP,
    FLYING_NEUTRAL,
    JUMPING,
};

pub const CharacterWurmpleMode = enum(u16) {
    FLYING_RIGHT,
    STANDING,
    ATTACKING_LEFT,
    FLYING_LEFT,
    RUNNING_RIGHT,
    ATTACKING_RIGHT,
    RUNNING_LEFT,
    ATTACKING_DOWN,
    ATTACKING_UP,
    FLYING_NEUTRAL,
    JUMPING,
};

pub const DontLoadMode = enum(u16) {
    TEXTURE,
};

pub const ProjectileTestMode = enum(u16) {
    FLYING_RIGHT,
};

pub const StageMeteorMode = enum(u16) {
    BACKGROUND,
    PLATFORMS,
    FLOOR,
};

pub const StageTest00Mode = enum(u16) {
    BACKGROUND,
    PLATFORMS,
};

pub const MenuWaitingMode = enum(u16) {
    FORINPUT,
};

pub const MenuStageMode = enum(u16) {
    SELECTED,
};

pub const ALL: [197]Asset = .{
    .{ .path = "assets/visual/Character/Test/Flying_Right/1.png", .id = .CHARACTER_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Flying_Right/2.png", .id = .CHARACTER_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Flying_Right/3.png", .id = .CHARACTER_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Flying_Right/4.png", .id = .CHARACTER_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Flying_Right/5.png", .id = .CHARACTER_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Standing/1.png", .id = .CHARACTER_TEST_STANDING },
    .{ .path = "assets/visual/Character/Test/Standing/2.png", .id = .CHARACTER_TEST_STANDING },
    .{ .path = "assets/visual/Character/Test/Standing/3.png", .id = .CHARACTER_TEST_STANDING },
    .{ .path = "assets/visual/Character/Test/Standing/4.png", .id = .CHARACTER_TEST_STANDING },
    .{ .path = "assets/visual/Character/Test/Standing/5.png", .id = .CHARACTER_TEST_STANDING },
    .{ .path = "assets/visual/Character/Test/Standing/6.png", .id = .CHARACTER_TEST_STANDING },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/1.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/2.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/3.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/4.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/5.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/6.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/7.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/8.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/9.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/10.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/11.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Left/12.png", .id = .CHARACTER_TEST_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Test/Flying_Left/1.png", .id = .CHARACTER_TEST_FLYING_LEFT },
    .{ .path = "assets/visual/Character/Test/Flying_Left/2.png", .id = .CHARACTER_TEST_FLYING_LEFT },
    .{ .path = "assets/visual/Character/Test/Flying_Left/3.png", .id = .CHARACTER_TEST_FLYING_LEFT },
    .{ .path = "assets/visual/Character/Test/Flying_Left/4.png", .id = .CHARACTER_TEST_FLYING_LEFT },
    .{ .path = "assets/visual/Character/Test/Flying_Left/5.png", .id = .CHARACTER_TEST_FLYING_LEFT },
    .{ .path = "assets/visual/Character/Test/Running_Right/1.png", .id = .CHARACTER_TEST_RUNNING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Running_Right/2.png", .id = .CHARACTER_TEST_RUNNING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Running_Right/3.png", .id = .CHARACTER_TEST_RUNNING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Running_Right/4.png", .id = .CHARACTER_TEST_RUNNING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Running_Right/5.png", .id = .CHARACTER_TEST_RUNNING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/1.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/2.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/3.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/4.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/5.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/6.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/7.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/8.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/9.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/10.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/11.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Attacking_Right/12.png", .id = .CHARACTER_TEST_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Test/Running_Left/1.png", .id = .CHARACTER_TEST_RUNNING_LEFT },
    .{ .path = "assets/visual/Character/Test/Running_Left/2.png", .id = .CHARACTER_TEST_RUNNING_LEFT },
    .{ .path = "assets/visual/Character/Test/Running_Left/3.png", .id = .CHARACTER_TEST_RUNNING_LEFT },
    .{ .path = "assets/visual/Character/Test/Running_Left/4.png", .id = .CHARACTER_TEST_RUNNING_LEFT },
    .{ .path = "assets/visual/Character/Test/Running_Left/5.png", .id = .CHARACTER_TEST_RUNNING_LEFT },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/1.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/2.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/3.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/4.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/5.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/6.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/7.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/8.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/9.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/10.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/11.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Down/12.png", .id = .CHARACTER_TEST_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/1.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/2.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/3.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/4.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/5.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/6.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/7.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/8.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/9.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/10.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/11.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Attacking_Up/12.png", .id = .CHARACTER_TEST_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Test/Flying_Neutral/1.png", .id = .CHARACTER_TEST_FLYING_NEUTRAL },
    .{ .path = "assets/visual/Character/Test/Flying_Neutral/2.png", .id = .CHARACTER_TEST_FLYING_NEUTRAL },
    .{ .path = "assets/visual/Character/Test/Flying_Neutral/3.png", .id = .CHARACTER_TEST_FLYING_NEUTRAL },
    .{ .path = "assets/visual/Character/Test/Flying_Neutral/4.png", .id = .CHARACTER_TEST_FLYING_NEUTRAL },
    .{ .path = "assets/visual/Character/Test/Flying_Neutral/5.png", .id = .CHARACTER_TEST_FLYING_NEUTRAL },
    .{ .path = "assets/visual/Character/Test/Jumping/1.png", .id = .CHARACTER_TEST_JUMPING },
    .{ .path = "assets/visual/Character/Test/Jumping/2.png", .id = .CHARACTER_TEST_JUMPING },
    .{ .path = "assets/visual/Character/Test/Jumping/3.png", .id = .CHARACTER_TEST_JUMPING },
    .{ .path = "assets/visual/Character/Test/Jumping/4.png", .id = .CHARACTER_TEST_JUMPING },
    .{ .path = "assets/visual/Character/Test/Jumping/5.png", .id = .CHARACTER_TEST_JUMPING },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Right/1.png", .id = .CHARACTER_WURMPLE_FLYING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Right/2.png", .id = .CHARACTER_WURMPLE_FLYING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Right/3.png", .id = .CHARACTER_WURMPLE_FLYING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Right/4.png", .id = .CHARACTER_WURMPLE_FLYING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Right/5.png", .id = .CHARACTER_WURMPLE_FLYING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Standing/1.png", .id = .CHARACTER_WURMPLE_STANDING },
    .{ .path = "assets/visual/Character/Wurmple/Standing/2.png", .id = .CHARACTER_WURMPLE_STANDING },
    .{ .path = "assets/visual/Character/Wurmple/Standing/3.png", .id = .CHARACTER_WURMPLE_STANDING },
    .{ .path = "assets/visual/Character/Wurmple/Standing/4.png", .id = .CHARACTER_WURMPLE_STANDING },
    .{ .path = "assets/visual/Character/Wurmple/Standing/5.png", .id = .CHARACTER_WURMPLE_STANDING },
    .{ .path = "assets/visual/Character/Wurmple/Standing/6.png", .id = .CHARACTER_WURMPLE_STANDING },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/1.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/2.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/3.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/4.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/5.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/6.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/7.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/8.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/9.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/10.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/11.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Left/12.png", .id = .CHARACTER_WURMPLE_ATTACKING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Left/1.png", .id = .CHARACTER_WURMPLE_FLYING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Left/2.png", .id = .CHARACTER_WURMPLE_FLYING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Left/3.png", .id = .CHARACTER_WURMPLE_FLYING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Left/4.png", .id = .CHARACTER_WURMPLE_FLYING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Left/5.png", .id = .CHARACTER_WURMPLE_FLYING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Running_Right/1.png", .id = .CHARACTER_WURMPLE_RUNNING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Running_Right/2.png", .id = .CHARACTER_WURMPLE_RUNNING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Running_Right/3.png", .id = .CHARACTER_WURMPLE_RUNNING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Running_Right/4.png", .id = .CHARACTER_WURMPLE_RUNNING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Running_Right/5.png", .id = .CHARACTER_WURMPLE_RUNNING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/1.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/2.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/3.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/4.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/5.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/6.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/7.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/8.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/9.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/10.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/11.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Right/12.png", .id = .CHARACTER_WURMPLE_ATTACKING_RIGHT },
    .{ .path = "assets/visual/Character/Wurmple/Running_Left/1.png", .id = .CHARACTER_WURMPLE_RUNNING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Running_Left/2.png", .id = .CHARACTER_WURMPLE_RUNNING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Running_Left/3.png", .id = .CHARACTER_WURMPLE_RUNNING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Running_Left/4.png", .id = .CHARACTER_WURMPLE_RUNNING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Running_Left/5.png", .id = .CHARACTER_WURMPLE_RUNNING_LEFT },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/1.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/2.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/3.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/4.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/5.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/6.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/7.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/8.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/9.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/10.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/11.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Down/12.png", .id = .CHARACTER_WURMPLE_ATTACKING_DOWN },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/1.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/2.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/3.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/4.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/5.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/6.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/7.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/8.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/9.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/10.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/11.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Attacking_Up/12.png", .id = .CHARACTER_WURMPLE_ATTACKING_UP },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Neutral/1.png", .id = .CHARACTER_WURMPLE_FLYING_NEUTRAL },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Neutral/2.png", .id = .CHARACTER_WURMPLE_FLYING_NEUTRAL },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Neutral/3.png", .id = .CHARACTER_WURMPLE_FLYING_NEUTRAL },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Neutral/4.png", .id = .CHARACTER_WURMPLE_FLYING_NEUTRAL },
    .{ .path = "assets/visual/Character/Wurmple/Flying_Neutral/5.png", .id = .CHARACTER_WURMPLE_FLYING_NEUTRAL },
    .{ .path = "assets/visual/Character/Wurmple/Jumping/1.png", .id = .CHARACTER_WURMPLE_JUMPING },
    .{ .path = "assets/visual/Character/Wurmple/Jumping/2.png", .id = .CHARACTER_WURMPLE_JUMPING },
    .{ .path = "assets/visual/Character/Wurmple/Jumping/3.png", .id = .CHARACTER_WURMPLE_JUMPING },
    .{ .path = "assets/visual/Character/Wurmple/Jumping/4.png", .id = .CHARACTER_WURMPLE_JUMPING },
    .{ .path = "assets/visual/Character/Wurmple/Jumping/5.png", .id = .CHARACTER_WURMPLE_JUMPING },
    .{ .path = "assets/visual/Dont/Load/Texture/1.png", .id = .DONT_LOAD_TEXTURE },
    .{ .path = "assets/visual/Projectile/Test/Flying_Right/1.png", .id = .PROJECTILE_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Projectile/Test/Flying_Right/2.png", .id = .PROJECTILE_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Projectile/Test/Flying_Right/3.png", .id = .PROJECTILE_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Projectile/Test/Flying_Right/4.png", .id = .PROJECTILE_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Projectile/Test/Flying_Right/5.png", .id = .PROJECTILE_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Projectile/Test/Flying_Right/6.png", .id = .PROJECTILE_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Projectile/Test/Flying_Right/7.png", .id = .PROJECTILE_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Projectile/Test/Flying_Right/8.png", .id = .PROJECTILE_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Projectile/Test/Flying_Right/9.png", .id = .PROJECTILE_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Projectile/Test/Flying_Right/10.png", .id = .PROJECTILE_TEST_FLYING_RIGHT },
    .{ .path = "assets/visual/Stage/Meteor/Background/1.png", .id = .STAGE_METEOR_BACKGROUND },
    .{ .path = "assets/visual/Stage/Meteor/Platforms/1.png", .id = .STAGE_METEOR_PLATFORMS },
    .{ .path = "assets/visual/Stage/Meteor/Floor/1.png", .id = .STAGE_METEOR_FLOOR },
    .{ .path = "assets/visual/Stage/Test00/Background/1.png", .id = .STAGE_TEST00_BACKGROUND },
    .{ .path = "assets/visual/Stage/Test00/Platforms/1.png", .id = .STAGE_TEST00_PLATFORMS },
    .{ .path = "assets/visual/Menu/Waiting/ForInput/1.png", .id = .MENU_WAITING_FORINPUT },
    .{ .path = "assets/visual/Menu/Stage/Selected/1.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/2.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/3.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/4.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/5.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/6.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/7.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/8.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/9.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/10.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/11.png", .id = .MENU_STAGE_SELECTED },
    .{ .path = "assets/visual/Menu/Stage/Selected/12.png", .id = .MENU_STAGE_SELECTED },
};

pub const ASSETS_PER_ID: [ID.size()]usize = .{ 5, 6, 12, 5, 5, 12, 5, 12, 12, 5, 5, 5, 6, 12, 5, 5, 12, 5, 12, 12, 5, 5, 1, 10, 1, 1, 1, 1, 1, 1, 12 };

// Storage for textures to be initialized at runtime.
var character_test_flying_right_textures: [5]Texture = undefined;
var character_test_standing_textures: [6]Texture = undefined;
var character_test_attacking_left_textures: [12]Texture = undefined;
var character_test_flying_left_textures: [5]Texture = undefined;
var character_test_running_right_textures: [5]Texture = undefined;
var character_test_attacking_right_textures: [12]Texture = undefined;
var character_test_running_left_textures: [5]Texture = undefined;
var character_test_attacking_down_textures: [12]Texture = undefined;
var character_test_attacking_up_textures: [12]Texture = undefined;
var character_test_flying_neutral_textures: [5]Texture = undefined;
var character_test_jumping_textures: [5]Texture = undefined;
var character_wurmple_flying_right_textures: [5]Texture = undefined;
var character_wurmple_standing_textures: [6]Texture = undefined;
var character_wurmple_attacking_left_textures: [12]Texture = undefined;
var character_wurmple_flying_left_textures: [5]Texture = undefined;
var character_wurmple_running_right_textures: [5]Texture = undefined;
var character_wurmple_attacking_right_textures: [12]Texture = undefined;
var character_wurmple_running_left_textures: [5]Texture = undefined;
var character_wurmple_attacking_down_textures: [12]Texture = undefined;
var character_wurmple_attacking_up_textures: [12]Texture = undefined;
var character_wurmple_flying_neutral_textures: [5]Texture = undefined;
var character_wurmple_jumping_textures: [5]Texture = undefined;
var dont_load_texture_textures: [1]Texture = undefined;
var projectile_test_flying_right_textures: [10]Texture = undefined;
var stage_meteor_background_textures: [1]Texture = undefined;
var stage_meteor_platforms_textures: [1]Texture = undefined;
var stage_meteor_floor_textures: [1]Texture = undefined;
var stage_test00_background_textures: [1]Texture = undefined;
var stage_test00_platforms_textures: [1]Texture = undefined;
var menu_waiting_forinput_textures: [1]Texture = undefined;
var menu_stage_selected_textures: [12]Texture = undefined;

pub var texture_slices: [ID.size()][]Texture = .{
    &character_test_flying_right_textures,
    &character_test_standing_textures,
    &character_test_attacking_left_textures,
    &character_test_flying_left_textures,
    &character_test_running_right_textures,
    &character_test_attacking_right_textures,
    &character_test_running_left_textures,
    &character_test_attacking_down_textures,
    &character_test_attacking_up_textures,
    &character_test_flying_neutral_textures,
    &character_test_jumping_textures,
    &character_wurmple_flying_right_textures,
    &character_wurmple_standing_textures,
    &character_wurmple_attacking_left_textures,
    &character_wurmple_flying_left_textures,
    &character_wurmple_running_right_textures,
    &character_wurmple_attacking_right_textures,
    &character_wurmple_running_left_textures,
    &character_wurmple_attacking_down_textures,
    &character_wurmple_attacking_up_textures,
    &character_wurmple_flying_neutral_textures,
    &character_wurmple_jumping_textures,
    &dont_load_texture_textures,
    &projectile_test_flying_right_textures,
    &stage_meteor_background_textures,
    &stage_meteor_platforms_textures,
    &stage_meteor_floor_textures,
    &stage_test00_background_textures,
    &stage_test00_platforms_textures,
    &menu_waiting_forinput_textures,
    &menu_stage_selected_textures,
};
