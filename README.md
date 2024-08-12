# battlebuds
Learning Zig, libdrm and HID controller interfacing by making a game.

This is for educational purposes for the forseeable future.

Developing in WSL2 with x86_64 architecture.
```
    $ uname -a

Linux J 5.15.153.1-microsoft-standard-WSL2 #1 SMP Fri Mar 29 23:14:13 UTC 2024 x86_64 x86_64 x86_64 GNU/Linux
```


# TODO list to get started:

Functionality: 

- [X] Figure out Zig build system.
- [ ] Draw anything to a buffer with libdrm.
- [ ] Read input from controller.
- [ ] Create a loop to move some shape based on controller input.
- [ ] Move multiple (displayed) objects at once.
- [ ] Create basic collision detection
- [ ] Add basic Newtonian physics.
- [ ] Research options for PRNG numbers in Zig/C. 
- [ ] (*) Implement framerate control.
- [ ] (.) Design player character.

Performance: 

- [ ] Investigate Zig vectors with automatic SIMD.
- [ ] Threading.
- [ ] (?) Hardware acceleration (excuse to learn CUDA, look into [GEM/libgbm](https://manpages.debian.org/unstable/libdrm-dev/drm-memory.7.en.html)).

Art: 

- [ ] Make some static pixel art.
- [ ] Make pixel art for animation frames.
- [ ] (*) Add frame count based animations
- [ ] (.) Animation switch on charater mode.
- [ ] (?) Fancy 3D/2.5D background or something, game will still be 2D.


# Dependencies:
- Zig
- libdrm (if missing: `sudo apt install mesa-common-dev libglu1-mesa-dev`)
- libc
