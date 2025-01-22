/// Play sounds for the game.
const SDL = @import("sdl2.zig");
const std = @import("std");
const utils = @import("utils.zig");

pub const Audio = struct {
    device_id: SDL.SDL_AudioDeviceID,
    device_spec: SDL.SDL_AudioSpec,

    // NOTE: temporarily only one file
    wav_file: WavFile,

    pub fn init(self: *Audio) Audio {
        // TODO: load wave files, similarly to Renderer.
        // TODO: store in utils.StaticMap, use ID to lookup, similarly to Renderer.

        SDL.SDL_ClearError();
        self.device_id = SDL.SDL_OpenAudioDevice(null, 0, null, &self.device_spec, SDL.SDL_AUDIO_ALLOW_ANY_CHANGE);

        if (!std.mem.eql(SDL.SDL_GetError(), "")) {
            utils.sdlPanic();
        }

        SDL.SDL_LoadWAV(
            "testfile.wav",
            &self.device_spec,
            self.wav_file.file_start_ptr,
            self.wav_file.file_length,
        ) orelse utils.sdlPanic();

        return self;
    }

    pub fn deinit(self: *Audio) void {
        SDL.SDL_FreeWAV(self.wav_file.file_start_ptr);
        SDL.SDL_CloseAudioDevice(self.device_id);
    }

    pub fn play(self: *Audio, sound_id: i32) void {
        _ = sound_id;
        SDL.SDL_QueueAudio(self.device, self.wav_file.file_start_ptr, self.wav_file.file_length);
        SDL.SDL_PauseAudioDevice(self.device_id, 0);
    }

    pub fn pause(self: *Audio) void {
        SDL.SDL_PauseAudioDevice(self.device_id, 1);
    }
};

const WavFile = struct {
    file_start_ptr: ?*u8,
    file_length: u32,
};
