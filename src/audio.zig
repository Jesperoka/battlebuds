/// Play sounds for the game.
const SDL = @import("sdl2");
const std = @import("std");
const utils = @import("utils.zig");
const audio_assets = @import("audio_assets.zig");
const WavFile = @import("audio_assets.zig").WavFile;

// TODO: look into storing files zipped, and then decompressing at runtime.

// TODO: look into whether wavfile_slices can be const or not.
pub const AudioPlayer = struct {
    device_id: SDL.SDL_AudioDeviceID = undefined,

    device_spec: SDL.SDL_AudioSpec = SDL.SDL_AudioSpec{
        .freq = 48000,
        .format = SDL.AUDIO_S16SYS,
        .channels = 2,
        .silence = 0,
        .samples = 4096,
        .padding = 0,
        .size = 0,
        .callback = null,
        .userdata = null,
    },

    var wav_files = utils.StaticMap(audio_assets.ID.size(), audio_assets.ID, []WavFile);

    pub fn init(self: *AudioPlayer) *AudioPlayer {
        SDL.SDL_ClearError();
        self.device_id = SDL.SDL_OpenAudioDevice(null, 0, &self.device_spec, &self.device_spec, SDL.SDL_AUDIO_ALLOW_ANY_CHANGE);

        if (!std.mem.eql(u8, std.mem.span(SDL.SDL_GetError()), "")) {
            utils.sdlPanic();
        }

        // Load all audio assets.
        inline for (std.meta.fields(audio_assets.ID)) |enum_field| {
            const id: audio_assets.ID = @enumFromInt(enum_field.value);
            var count: usize = 0;

            // For simplicity, just check all visual assets.
            for (audio_assets.ALL) |audio_asset| {
                if (audio_asset.id != id) continue;

                _ = SDL.SDL_LoadWAV(
                    audio_asset.path,
                    &self.device_spec,
                    @as(?*(?*u8), @ptrCast(&audio_assets.wavfile_slices[id.int()][count].start_ptr)),
                    &audio_assets.wavfile_slices[id.int()][count].length,
                ) orelse utils.sdlPanic();

                count += 1;

                if (count > audio_assets.wavfile_slices[id.int()].len) break;
            }
            wav_files.insert(id, audio_assets.wavfile_slices[id.int()], false) catch unreachable;
        }

        return self;
    }

    pub fn deinit(self: *AudioPlayer) void {
        for (wav_files.things) |wav_file_variations| {
            for (wav_file_variations) |wav_file| {
                SDL.SDL_FreeWAV(wav_file.start_ptr);
            }
        }
        SDL.SDL_CloseAudioDevice(self.device_id);
    }

    pub fn play(self: *AudioPlayer, audio_asset_id: audio_assets.ID, sound_variation_index: usize) void {
        const wav_file = (wav_files.lookup(audio_asset_id, false) catch unreachable)[sound_variation_index];
        if (SDL.SDL_QueueAudio(
            self.device_id,
            wav_file.start_ptr,
            wav_file.length,
        ) != 0) {
            utils.sdlPanic();
        }
        SDL.SDL_PauseAudioDevice(self.device_id, 0);
    }

    pub fn pause(self: *AudioPlayer) void {
        SDL.SDL_PauseAudioDevice(self.device_id, 1);
    }
};
