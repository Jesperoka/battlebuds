/// Using SDL2 for window management and pointers to GPU buffers.
const std = @import("std");
const SDL = @import("sdl2");
const rgbapng = @import("rgbapng");
const PngDecodeError = rgbapng.PngDecodeError;

const constants = @import("constants.zig");
const visual_assets = @import("visual_assets.zig");
const utils = @import("utils.zig");
const stages = @import("stages.zig");

const Vec = @import("types.zig").Vec;
const VecI32 = @import("types.zig").VecI32;
const float = @import("types.zig").float;

const WindowSettings = struct {
    const title: [*]const u8 = "Battlebuds";
    const width: u16 = constants.X_RESOLUTION;
    const height: u16 = constants.Y_RESOLUTION;
    const x0 = SDL.SDL_WINDOWPOS_CENTERED;
    const y0 = SDL.SDL_WINDOWPOS_CENTERED;
    const sdl_flags = SDL.SDL_WINDOW_SHOWN; // | SDL.SDL_WINDOW_BORDERLESS;
};

fn toPixelX(x: float) u16 {
    return @intFromFloat(x * constants.PIXELS_PER_METER + @as(float, @floatFromInt(WindowSettings.width / 2)));
}

fn vecToPixelX(X: Vec) VecI32 {
    const ppm: Vec = @splat(constants.PIXELS_PER_METER);
    const screen_halfwidth: VecI32 = @splat(WindowSettings.width / 2);

    return @intFromFloat(X * ppm + @as(Vec, @floatFromInt(screen_halfwidth)));
}

fn toPixelY(y: float) i32 {
    return @intFromFloat(@as(float, @floatFromInt(WindowSettings.height / 2)) - y * constants.PIXELS_PER_METER);
}

fn vecToPixelY(Y: Vec) VecI32 {
    const ppm: Vec = @splat(constants.PIXELS_PER_METER);
    const screen_halfheight: VecI32 = @splat(WindowSettings.height / 2);

    return @intFromFloat(-Y * ppm + @as(Vec, @floatFromInt(screen_halfheight)));
}

pub const DynamicEntities = struct {
    const NUM = constants.VEC_LENGTH;

    X: VecI32 = @splat(0),
    Y: VecI32 = @splat(0),
    damage_on_hit: Vec = @splat(0),
    active: Vec = @splat(0.0),
    modes: [NUM]visual_assets.EntityMode = .{.{ .dont_load = visual_assets.DontLoadMode.TEXTURE }} ** NUM,
    counter_corrections: [NUM]u64 = .{0} ** NUM,

    pub fn init(
        self: *DynamicEntities,
        starting_positions: [constants.MAX_NUM_PLAYERS]stages.Position,
        shuffled_indices: [constants.MAX_NUM_PLAYERS]u8,
        entity_modes: [constants.MAX_NUM_PLAYERS]visual_assets.EntityMode,
    ) void {
        self.* = .{}; // Clear all fields.

        for (shuffled_indices, 0..constants.MAX_NUM_PLAYERS) |idx, i| {
            self.X[i] = toPixelX(starting_positions[idx].x);
            self.Y[i] = toPixelY(starting_positions[idx].y);
            self.modes[i] = entity_modes[i];
        }
    }

    pub fn updatePosition(self: *DynamicEntities, X: Vec, Y: Vec) void {
        self.X = vecToPixelX(X);
        self.Y = vecToPixelY(Y);
    }
};

pub fn corrected_animation_counter(counter: usize, comptime slowdown_factor: float) usize {
    return @intFromFloat(@floor(@as(float, @floatFromInt(counter)) / slowdown_factor));
}

pub const Renderer = struct {
    renderer: *SDL.SDL_Renderer = undefined,
    window: *SDL.SDL_Window = undefined,
    num_textures: u8 = undefined,

    pub fn init(comptime self: *Renderer) *Renderer {
        // TODO: Once controller exiting is done, disable SDL_INIT_EVENTS.
        if (SDL.SDL_Init(SDL.SDL_INIT_VIDEO | SDL.SDL_INIT_EVENTS | SDL.SDL_INIT_AUDIO) < 0) {
            utils.sdlPanic();
        }
        self.window = SDL.SDL_CreateWindow(
            WindowSettings.title,
            WindowSettings.x0,
            WindowSettings.y0,
            WindowSettings.width,
            WindowSettings.height,
            WindowSettings.sdl_flags,
        ) orelse utils.sdlPanic();

        self.renderer = SDL.SDL_CreateRenderer(self.window, -1, SDL.SDL_RENDERER_ACCELERATED) orelse utils.sdlPanic();

        if (SDL.SDL_SetRenderDrawBlendMode(self.renderer, SDL.SDL_BLENDMODE_BLEND) < 0) {
            utils.sdlPanic();
        }

        Textures.init(self.renderer);

        utils.assert(Textures.map.cur_back_idx < Textures.map.cur_front_idx, "Can't loop through texture map if it's not full.");

        for (Textures.map.things) |textures| {
            for (textures) |*texture| {
                if (texture.ptr) |ptr| {
                    if (SDL.SDL_SetTextureBlendMode(ptr, SDL.SDL_BLENDMODE_BLEND) < 0) {
                        utils.sdlPanic();
                    }
                }
            }
        }

        return self;
    }

    pub fn deinit(self: *Renderer) void {
        Textures.deinit();
        _ = SDL.SDL_DestroyRenderer(self.renderer);
        SDL.SDL_DestroyWindow(self.window);
        SDL.SDL_Quit();
    }

    // TODO: Fix interger overflow!!!
    pub fn draw_dynamic_entities(
        self: *Renderer,
        counter: usize,
        dynamic_entities: *DynamicEntities,
        comptime slowdown_factor: float,
    ) !void {
        const N = DynamicEntities.NUM;

        for (
            @as([N]i32, dynamic_entities.X),
            @as([N]i32, dynamic_entities.Y),
            dynamic_entities.modes,
            dynamic_entities.counter_corrections,
        ) |x, y, mode, counter_correction| {
            const id = visual_assets.IDFromEntityMode(mode);
            if (id == .DONT_LOAD_TEXTURE) continue;

            const textures = try Textures.map.lookup(id, false);
            if (corrected_animation_counter(counter, slowdown_factor) < counter_correction) {
                std.debug.print("\n\n{any}\n{any}\n\n", .{
                    counter_correction,
                    corrected_animation_counter(counter, slowdown_factor),
                });
            }
            const animation_counter = corrected_animation_counter(counter, slowdown_factor) - counter_correction;
            const texture = textures[animation_counter % textures.len];

            _ = SDL.SDL_RenderCopy(
                self.renderer,
                texture.ptr,
                null,
                &SDL.SDL_Rect{
                    .x = x - @divExact(texture.width, 2),
                    .y = y - @divExact(texture.height, 2),
                    .w = texture.width,
                    .h = texture.height,
                },
            );
        }
    }

    pub fn draw_looping_animations(
        self: *Renderer,
        counter: usize,
        asset_ids: []const visual_assets.ID,
        comptime slowdown_factor: float,
    ) !void {
        for (asset_ids) |asset_id| {
            const animation_counter = corrected_animation_counter(counter, slowdown_factor);
            self.draw_animation_frame(animation_counter, asset_id) catch unreachable;
        }
    }

    pub fn draw_animation_frame(
        self: *Renderer,
        frame_index: usize,
        asset_id: visual_assets.ID,
    ) !void {
        const textures = try Textures.map.lookup(asset_id, false);
        const texture = textures[frame_index % textures.len];
        _ = SDL.SDL_RenderCopy(self.renderer, texture.ptr, null, null);
    }

    pub fn draw_looping_animations_at(
        self: *Renderer,
        counter: usize,
        asset_ids: []const visual_assets.ID,
        X: []const i32,
        Y: []const i32,
        comptime slowdown_factor: float,
    ) !void {
        for (X, Y, asset_ids) |x, y, asset_id| {
            const animation_counter = corrected_animation_counter(counter, slowdown_factor);
            self.draw_animation_frame_at(animation_counter, asset_id, x, y) catch unreachable;
        }
    }

    pub fn draw_animation_frame_at(
        self: *Renderer,
        frame_index: usize,
        asset_id: visual_assets.ID,
        x: i32,
        y: i32,
    ) !void {
        const textures = try Textures.map.lookup(asset_id, false);
        const texture = textures[frame_index % textures.len];

        _ = SDL.SDL_RenderCopy(
            self.renderer,
            texture.ptr,
            null,
            &SDL.SDL_Rect{
                .x = x,
                .y = y,
                .w = texture.width,
                .h = texture.height,
            },
        );
    }

    pub fn render(self: *Renderer) void {
        SDL.SDL_RenderPresent(self.renderer);
    }
};

fn fillWithColor(renderer: *SDL.SDL_Renderer) void {
    if (SDL.SDL_SetRenderDrawColor(renderer, 0xF7, 0xA4, 0x1D, 0xFF) < 0) {
        utils.sdlPanic();
    }
    if (SDL.SDL_RenderClear(renderer) < 0) { // Note: read "Clear" as "Fill"
        utils.sdlPanic();
    }
}

// TODO: look into whether texture_slices can be const or not.
pub const Textures = struct {
    const FORMAT: c_int = SDL.SDL_PIXELFORMAT_ABGR8888;
    const ACCESS_MODE: c_int = SDL.SDL_TEXTUREACCESS_STREAMING;

    var map = utils.StaticMap(visual_assets.ID.size(), visual_assets.ID, []visual_assets.Texture);

    pub fn init(
        renderer: *SDL.SDL_Renderer,
    ) void {
        var arena = std.heap.ArenaAllocator.init(std.heap.raw_c_allocator);
        defer arena.deinit();

        inline for (std.meta.fields(visual_assets.ID)) |enum_field| {
            const id: visual_assets.ID = @enumFromInt(enum_field.value);
            var count: usize = 0;

            std.debug.print("Loading textures for ID: {any}\n", .{id});

            // For simplicity, just check all visual assets.
            for (visual_assets.ALL) |visual_asset| {
                if (visual_asset.id != id or visual_asset.id == .DONT_LOAD_TEXTURE) continue;

                loadTexture(
                    renderer,
                    arena.allocator(),
                    &visual_assets.texture_slices[id.int()][count],
                    visual_asset.path,
                    FORMAT,
                    ACCESS_MODE,
                ) catch unreachable;

                count += 1;

                if (count > visual_assets.texture_slices[id.int()].len) break;
            }
            map.insert(id, visual_assets.texture_slices[id.int()], false) catch unreachable;
        }
    }

    pub fn deinit() void {
        for (map.things) |textures| {
            for (textures) |texture| {
                SDL.SDL_DestroyTexture(texture.ptr);
            }
        }
    }
};

fn loadTexture(
    renderer: *SDL.SDL_Renderer,
    allocator: std.mem.Allocator,
    texture: *visual_assets.Texture,
    path: []const u8,
    comptime format: c_int,
    comptime access_mode: c_int,
) PngDecodeError!void {
    const image = try rgbapng.decode(
        .{ .optimistic = true },
        path,
        allocator,
    );

    texture.ptr = SDL.SDL_CreateTexture(
        renderer,
        format,
        access_mode,
        @intCast(image.width),
        @intCast(image.height),
    ) orelse utils.sdlPanic();

    texture.width = @intCast(image.width);
    texture.height = @intCast(image.height);

    var pixels: ?*c_int = undefined;
    var stride: c_int = undefined;
    const pixels_ptr: [*]?*anyopaque = @ptrCast(@alignCast(@constCast(&pixels)));
    const stride_ptr: [*]c_int = @ptrCast(@alignCast(@constCast(&stride)));

    utils.assert(
        SDL.SDL_LockTexture(texture.ptr, null, pixels_ptr, stride_ptr) == 0,
        "SDL_LockTexture() failed.",
    );

    const stride_gpu: usize = @intCast(stride);
    const start_addr_gpu = @intFromPtr(@as(*u8, @ptrCast(pixels_ptr[0].?)));

    copyPixels(
        image,
        start_addr_gpu,
        stride_gpu,
    );

    SDL.SDL_UnlockTexture(texture.ptr);
}

fn readPng(path: []const u8, allocator: std.mem.Allocator) PngDecodeError!rgbapng.Image {
    return rgbapng.decode(.{ .optimistic = true }, path, allocator);
}

fn copyPixels(
    image: rgbapng.Image,
    start_addr_dest: usize,
    stride_dest: usize,
) void {
    for (0..image.height) |row| {
        // const src_row_addr = start_addr_src + row * stride_src;
        const dest_row_addr = start_addr_dest + row * stride_dest;

        // const ptr_src = @as([*]u32, @ptrFromInt(src_row_addr));
        const ptr_src = @as([*]u32, @ptrCast(@alignCast(@constCast(&image.data[row * image.stride]))));
        var ptr_dest = @as([*]u32, @ptrFromInt(dest_row_addr));

        for (0..image.width) |col| {
            ptr_dest[col] = ptr_src[col];
        }
    }
}
