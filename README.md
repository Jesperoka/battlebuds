# battlebuds
Learning Zig, XCB and HID controller interfacing by making a game.

This is for educational purposes for the forseeable future.

Developing in WSL2 with x86_64 architecture.
```
    $ uname -a

Linux J 5.15.153.1-microsoft-standard-WSL2 #1 SMP Fri Mar 29 23:14:13 UTC 2024 x86_64 x86_64 x86_64 GNU/Linux
```


# TODO list to get started:

Functionality: 

- [X] Figure out Zig build system.
- ~~[ ] Draw anything to a buffer with libdrm.~~
- [X] Draw anything to a window using XCB.
- [ ] Draw colors with XCB.
- [ ] Read input from controller (libudev?).
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


# NOTES DURING DEVELOPMENT
### Libdrm and XCB
Tried using libdrm at first, but as far as I can tell, it's not possible (without some custom magic compatability layers) inside WSL2 because 
the Linux kernel does not have permission to control the framebuffers *just like that*. Thus, I've switched to XCB, and after banging my head
at a wall for a bit, it seems we can get this to work. XCB is at least somewhat low level, and does teach me stuff about C programming and the
X protocol, but it's not the ideal experience of writing directly to framebuffers. It would have been cool to learn about double buffering, page-flipping
and other low level graphics driver stuff, so I might make that when I get access to an actual Linux machine.

<div align="center">
    <img src="docs/imgs/Linux_Graphics.svg" width="350">
    <br>Overview of some parts of the Linux graphics stack.<br><br>
</div>

Basically I'm writing an X11 application, but I will not be using any premade graphics libraries, and only really using 
XCB for window management and sending requests to draw my pixels (which I will write other code to do).
The point is the excercise of it all.

### MIT-SHM
As far as I can tell, using the shared memory extension will not work on WSL2.
https://www.x.org/releases/current/doc/xextproto/shm.html
Concluded this after running:
```sh
xdpyinfo -ext MIT-SHM
```
to get information about the Shm XCB extension. Haven't actually tried though.
    


# Dependencies:
- Zig
- libc
- libxcb 
- libxcb-image `sudo apt install libxcb-image0-dev`
~~- libdrm (if missing: `sudo apt install mesa-common-dev libglu1-mesa-dev`)~~
