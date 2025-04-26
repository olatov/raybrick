# RayBrick
A simple Breakout-style game built with Free Pascal and Raylib (via [ray4laz](https://github.com/GuvaCode/ray4laz)).

## Running
Find the pre-built executables for Windows and Linux in `bin/` directory. Good practice would be first to verify them by uploading to https://www.virustotal.com/ use other antivirus service, to ensure this is not not some kind of malware.
If the pre-built executables do not suit your system (or you don't like taking risks running them), proceed to building from source.

## Building from Source

### Requirements
- [Free Pascal Compiler (FPC)](https://www.freepascal.org/) v3.3.1 or later
- [Raylib](https://www.raylib.com/)
- [Ray4laz](https://github.com/GuvaCode/ray4laz/)

### Option 1: Using Lazarus
- Open `raybrick.lpi` in Lazarus.
- Add the `ray4laz.lpk` package (either from the `ray4laz` repository or the Online Package Manager).
- Build and run the project.

### Option 2: Using FPC (Command Line)
Build the project manually:
```sh
fpc raybrick.lpr -Fu"/path/to/ray4laz/source"
```

Make sure the linker can find the libraylib files appropriate for your system.
If necessary, specify the library search path using the -Fl option:
```sh
-Fl/path/to/libraylib
```