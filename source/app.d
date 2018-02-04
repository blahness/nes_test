import std.conv;
import std.file;
import std.functional;
import std.getopt;
import std.path;
import std.stdio;
import std.string;

import derelict.sdl2.sdl;

import nes.console;
import nes.controller;
import scaler;

enum WINDOW_WIDTH = 1280;
enum WINDOW_HEIGHT = 720;

enum NATIVE_WIDTH = 256;
enum NATIVE_HEIGHT = 240;

enum SAMPLE_RATE = 44100;
enum SAMPLE_BUFFER_LENGTH = 4096;

enum FPS = 60;

enum TARGET_FRAME_TIME = 1000 / double(FPS);
enum WRAP_TICKS = 86400000; // Every 24 hours

Scaler CurrentScaler;

SDL_Rect CurrentRect;
SDL_Rect PixelPerfectRect = SDL_Rect(256, 0, 760, 720);
SDL_Rect FourThreeRect = SDL_Rect(160, 0, 960, 720);

float[SAMPLE_BUFFER_LENGTH] SampleBuffer;
uint SampleLength;

Console MyConsole;

SDL_GameController* GameController;

string ExeDir;
string StatePath;
string SavePath;
string RomFile, RomFileMinusExtension;

int main(string[] args) {
    string display = "4:3";
    string scaler = "none";

    auto helpInformation = getopt(
        args,
        "display|d", "Display mode [default: 4:3]. Can be pixel-perfect or 4:3.", &display,
        "scaler|s", "Use scaler [default: none]. Can be none, scale2x or scale3x.", &scaler);

    if (helpInformation.helpWanted || args.length < 2) {
        defaultGetoptPrinter("Usage:\nnes <rom> [--display=<s>] [--scaler=<s>] \n\nOptions:",
            helpInformation.options);

        return 0;
    }

    switch (display) {
        case "4:3":
            CurrentRect = FourThreeRect;
            writeln("Using display mode 4:3.");
            break;
        case "pixel-perfect":
            CurrentRect = PixelPerfectRect;
            writeln("Using display mode pixel-perfect.");
            break;
        default:
            writeln("Error: Invalid display mode ", display);
            return 1;
    }
    
    switch (scaler) {
        case "none":
            CurrentScaler = new NoScaler();
            break;
        case "scale2x":
            CurrentScaler = new Scale2x();
            writeln("Using scaler scale2x.");
            break;
        case "scale3x":
            CurrentScaler = new Scale3xFaster();
            writeln("Using scaler scale3x.");
            break;
        default:
            writeln("Error: Invalid scaler ", scaler);
            return 1;
    }

    writeln("Starting NES emulator...");

    RomFile = args[1];

    ExeDir = thisExePath().dirName();

    StatePath = ExeDir ~ "/state/";
    SavePath = ExeDir ~ "/save/";

    if (!exists(StatePath) || !isDir(StatePath))
        mkdir(StatePath);

    if (!exists(SavePath) || !isDir(SavePath))
        mkdir(SavePath);

    MyConsole = new Console(RomFile);

    RomFileMinusExtension = baseName(RomFile, extension(RomFile));

    MyConsole.setAudioCallback(toDelegate(&audioCallback));
    MyConsole.setAudioSampleRate(SAMPLE_RATE);

    auto saveFileName = SavePath ~ RomFileMinusExtension ~ ".sav";

    if (exists(saveFileName))
        MyConsole.loadBatteryBackedRam(saveFileName);

    auto stateFileName = StatePath ~ RomFileMinusExtension ~ ".state";

    DerelictSDL2.load();

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_GAMECONTROLLER) != 0) {
        writeln("SDL Error (SDL_Init): ", to!string(SDL_GetError()));
        return 1;
    }

    scope(exit) SDL_Quit();

    SDL_Window* win = SDL_CreateWindow("nes", SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED, WINDOW_WIDTH, WINDOW_HEIGHT, SDL_WINDOW_SHOWN);
    if (win == null) {
        writeln("SDL Error (SDL_CreateWindow): ", to!string(SDL_GetError()));
        return 1;
    }

    scope(exit) SDL_DestroyWindow(win);

    SDL_Renderer* ren = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED |
        SDL_RENDERER_PRESENTVSYNC);
    if (ren == null) {
        writeln("SDL Error (SDL_CreateRenderer): ", to!string(SDL_GetError()));
        return 1;
    }

    scope(exit) SDL_DestroyRenderer(ren);

    SDL_Texture* texture = SDL_CreateTexture(ren,
        SDL_PIXELFORMAT_RGBA32, SDL_TEXTUREACCESS_STREAMING,
        NATIVE_WIDTH * CurrentScaler.factor(),
        NATIVE_HEIGHT * CurrentScaler.factor());
    if (texture == null) {
        writeln("SDL Error (SDL_CreateTexture): ", to!string(SDL_GetError()));
        return 1;
    }

    scope(exit) SDL_DestroyTexture(texture);

    SDL_AudioSpec want, have;

    want.freq = SAMPLE_RATE;
    want.format = AUDIO_F32;
    want.channels = 1;
    want.samples = SAMPLE_RATE / FPS;
    want.callback = null;

    SDL_AudioDeviceID audioDev = SDL_OpenAudioDevice(null, 0, &want, &have, 0);
    if (audioDev == 0) {
        writeln("SDL Error (SDL_OpenAudioDevice): ", to!string(SDL_GetError()));
        return 1;
    }

    scope(exit) SDL_CloseAudioDevice(audioDev);

    SDL_PauseAudioDevice(audioDev, 0);

    if (SDL_GameControllerAddMappingsFromFile((ExeDir ~ "/gamecontrollerdb_205.txt").toStringz()) == -1)
        writeln("Warning: Unable to open game controller mapping file! SDL Error (SDL_GameControllerAddMappingsFromFile): ",
                to!string(SDL_GetError()));

    // Check for joysticks
    if (SDL_NumJoysticks() < 1) {
        writeln("Warning: No joysticks connected!");
    }
    else {
        // Load joystick
        GameController = SDL_GameControllerOpen(0);
        if (GameController == null) {
            writeln("Warning: Unable to open game controller! SDL Error (SDL_GameControllerOpen): ",
                to!string(SDL_GetError()));
        }
    }

    int pitch = NATIVE_WIDTH * CurrentScaler.factor() * 4;

    uint startTicks;
    uint ticks;
    double target = 0;
    uint targetInt;

    bool quit = false;
    SDL_Event e;

    bool[8] buttons;

    while (!quit) {
        startTicks = SDL_GetTicks();

        auto pixels = MyConsole.buffer().pix.ptr;

        pixels = CurrentScaler.scale(pixels);

        SDL_UpdateTexture(texture, null,  cast(void*)pixels, pitch);

        while (SDL_PollEvent(&e) != 0) {
            if (e.type == SDL_QUIT) {
                quit = true;
                MyConsole.saveBatteryBackedRam(saveFileName);

                bool isFullscreen = (SDL_GetWindowFlags(win) & SDL_WINDOW_FULLSCREEN) > 0;

                if (isFullscreen) {
                    SDL_SetWindowFullscreen(win, 0);
                    SDL_ShowCursor(SDL_ENABLE);
                }

                break;
            }
            else if (e.type == SDL_KEYDOWN) {
                if (e.key.keysym.sym == SDLK_RETURN)
                    buttons[ButtonStart] = true;
                if (e.key.keysym.sym == SDLK_SPACE || e.key.keysym.sym == SDLK_RSHIFT)
                    buttons[ButtonSelect] = true;
                if (e.key.keysym.sym == SDLK_UP || e.key.keysym.sym == SDLK_w)
                    buttons[ButtonUp] = true;
                if (e.key.keysym.sym == SDLK_DOWN || e.key.keysym.sym == SDLK_s)
                    buttons[ButtonDown] = true;
                if (e.key.keysym.sym == SDLK_LEFT || e.key.keysym.sym == SDLK_a)
                    buttons[ButtonLeft] = true;
                if (e.key.keysym.sym == SDLK_RIGHT || e.key.keysym.sym == SDLK_d)
                    buttons[ButtonRight] = true;
                if (e.key.keysym.sym == SDLK_n || e.key.keysym.sym == SDLK_z)
                    buttons[ButtonB] = true;
                if (e.key.keysym.sym == SDLK_m || e.key.keysym.sym == SDLK_x)
                    buttons[ButtonA] = true;

                MyConsole.controller1.setButtons(buttons);
            }
            else if (e.type == SDL_KEYUP) {
                if (e.key.keysym.sym == SDLK_RETURN)
                    buttons[ButtonStart] = false;
                if (e.key.keysym.sym == SDLK_SPACE || e.key.keysym.sym == SDLK_RSHIFT)
                    buttons[ButtonSelect] = false;
                if (e.key.keysym.sym == SDLK_UP || e.key.keysym.sym == SDLK_w)
                    buttons[ButtonUp] = false;
                if (e.key.keysym.sym == SDLK_DOWN || e.key.keysym.sym == SDLK_s)
                    buttons[ButtonDown] = false;
                if (e.key.keysym.sym == SDLK_LEFT || e.key.keysym.sym == SDLK_a)
                    buttons[ButtonLeft] = false;
                if (e.key.keysym.sym == SDLK_RIGHT || e.key.keysym.sym == SDLK_d)
                    buttons[ButtonRight] = false;
                if (e.key.keysym.sym == SDLK_n || e.key.keysym.sym == SDLK_z)
                    buttons[ButtonB] = false;
                if (e.key.keysym.sym == SDLK_m || e.key.keysym.sym == SDLK_x)
                    buttons[ButtonA] = false;

                MyConsole.controller1.setButtons(buttons);

                if (e.key.keysym.sym == SDLK_ESCAPE) {
                    bool isFullscreen = (SDL_GetWindowFlags(win) & SDL_WINDOW_FULLSCREEN) > 0;

                    if (isFullscreen) {
                        SDL_SetWindowFullscreen(win, 0);
                        SDL_ShowCursor(SDL_ENABLE);
                    }
                }
                else if (e.key.keysym.sym == SDLK_r) {
                    auto state = SDL_GetKeyboardState(null);

                    if (state[SDL_SCANCODE_LCTRL] || state[SDL_SCANCODE_RCTRL])
                        MyConsole.reset();
                }
                else if (e.key.keysym.sym == SDLK_F1) {
                    if (exists(stateFileName)) {
                        MyConsole.reset();
                        MyConsole.loadState(stateFileName);
                    }
                }
                else if (e.key.keysym.sym == SDLK_F5) {
                    MyConsole.saveState(stateFileName);
                }
                else if (e.key.keysym.sym == SDLK_F11) {
                    bool isFullscreen = (SDL_GetWindowFlags(win) & SDL_WINDOW_FULLSCREEN) > 0;

                    if (isFullscreen) SDL_SetWindowFullscreen(win, 0);
                    else SDL_SetWindowFullscreen(win, SDL_WINDOW_FULLSCREEN);

                    SDL_ShowCursor(isFullscreen ? SDL_ENABLE : SDL_DISABLE);
                }
            }
            else if (e.type == SDL_CONTROLLERBUTTONDOWN) {
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_START)
                    buttons[ButtonStart] = true;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_BACK)
                    buttons[ButtonSelect] = true;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_DPAD_UP)
                    buttons[ButtonUp] = true;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_DPAD_DOWN)
                    buttons[ButtonDown] = true;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_DPAD_LEFT)
                    buttons[ButtonLeft] = true;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_DPAD_RIGHT)
                    buttons[ButtonRight] = true;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_A)
                    buttons[ButtonB] = true;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_B)
                    buttons[ButtonA] = true;

                MyConsole.controller1.setButtons(buttons);
            }
            else if (e.type == SDL_CONTROLLERBUTTONUP) {
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_START)
                    buttons[ButtonStart] = false;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_BACK)
                    buttons[ButtonSelect] = false;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_DPAD_UP)
                    buttons[ButtonUp] = false;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_DPAD_DOWN)
                    buttons[ButtonDown] = false;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_DPAD_LEFT)
                    buttons[ButtonLeft] = false;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_DPAD_RIGHT)
                    buttons[ButtonRight] = false;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_A)
                    buttons[ButtonB] = false;
                if (e.cbutton.button == SDL_CONTROLLER_BUTTON_B)
                    buttons[ButtonA] = false;

                MyConsole.controller1.setButtons(buttons);
            }
            else if (e.type == SDL_CONTROLLERDEVICEADDED) {
                if (e.cdevice.which == 0) {
                    GameController = SDL_GameControllerOpen(0);
                    if (GameController == null) {
                        writeln("Warning: Unable to open game controller! SDL Error (SDL_GameControllerOpen): ",
                            to!string(SDL_GetError()));
                    }
                }
            }
            else if (e.type == SDL_CONTROLLERDEVICEREMOVED) {
                SDL_Joystick* j = SDL_GameControllerGetJoystick(GameController);
                auto id = SDL_JoystickInstanceID(j);
                if (id == e.cdevice.which) {
                    SDL_GameControllerClose(GameController);
                    GameController = null;
                }
            }
        }

        if (quit) break;

        SDL_RenderClear(ren);
        SDL_RenderCopy(ren, texture, null, &CurrentRect);
        SDL_RenderPresent(ren);

        if (SampleLength > 1) {
            auto r = SDL_QueueAudio(audioDev, cast(void*)SampleBuffer.ptr, SampleLength * 4);
            if (r == 0) SampleLength = 0;
        }

        MyConsole.stepSeconds(0.01666666666);

        // Limit to 60 fps
        ticks += SDL_GetTicks() - startTicks;
        target += TARGET_FRAME_TIME;
        targetInt = cast(uint)target;

        if (ticks < targetInt) {
            auto delta = targetInt - ticks;

            SDL_Delay(delta);
            ticks += delta;
        }

        if (ticks >= WRAP_TICKS) ticks -= WRAP_TICKS;
        if (target >= WRAP_TICKS) target -= WRAP_TICKS;
    }
    
    if (GameController != null)
        SDL_GameControllerClose(GameController);

    return 0;
}

void audioCallback(float sample) {
    if (SampleLength >= SAMPLE_BUFFER_LENGTH)
        return;

    SampleBuffer[SampleLength] = sample;
    SampleLength++;
}
