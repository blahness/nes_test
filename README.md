


### Summary

This is an example application for github.com/blahness/nes/.

### Dependencies

```
  github.com/blahness/nes/
  github.com/DerelictOrg/DerelictSDL2/
```

Installation
------------

### For a pre-built package

For Windows there are stand-alone binary builds available at the [GitHub release page](https://github.com/blahness/nes_test/releases). Note: they were compiled with DMD so they're not very optimized.

### Building from source

Download this repo, cd to the folder that contains the source folder & run:
```
  dub build --build=release
```
Or for a 64-bit version:
```
  dub build --arch=x86_64 --build=release
```
If you're on Windows I'd also add --arch=x86_mscoff for the 32-bit version. The linker produces a very slow executable otherwise.

The app expects the SDL2 runtime binaries (minimum version 2.0.5) to be available. You can find them here: [https://www.libsdl.org/download-2.0.php](https://www.libsdl.org/download-2.0.php).

### Usage

```
  nes_test <rom>
  Use nes_test -h for more options.
```

The app will create a save & state folder in its current directory on first run if they don't already exist.
Battery backed RAM is saved only on program exit.

### Controls

Joysticks are supported, although the button mapping is currently hard-coded.
Keyboard controls are indicated below.

| Nintendo                    | Emulator             |
| --------------------------- | -------------------- |
| Up, Down, Left, Right       | Arrow Keys or WSAD   |
| Start                       | Enter                |
| Select                      | Right Shift or Space |
| A                           | Z or N               |
| B                           | X or M               |
| Fullscreen/Windowed Toggle  | F11                  |
| Exit Fullscreen             | Escape               |
| Reset                       | Ctrl + R             |
| Save State                  | F5                   |
| Load State                  | F1                   |
