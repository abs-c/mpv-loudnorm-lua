# mpv-loudnorm-lua

Apply a double-pass loudnorm filter in [mpv](https://mpv.io/).

Inspired by [MPV-LoudNorm](https://github.com/ThinkMcFlyThink/MPV-LoudNorm). Use only lua scripts to avoid annoying popout windows.

Save the measured results into txt for reuse. A unique profile name for each file is generated with [md5.lua](https://github.com/kikito/md5.lua).

## Usage

Put the `loudnorm` folder in mpv script folder (`scripts`). The existed profile `xxx.txt` is just an example and can be deleted, but the `data` folder should not be deleted, because I didn't write any script to regenerate it.

By default, the script will run when opening videos in `Y:` and `Z:`, which is a very personal behavior and can be modified in `main.lua`. You may also add something like `n script-message 2pass-loudnorm` to `input.conf` for manual execution.

The target loudness is defined at the beginning of `main.lua`. The default setting is `i=-24.0:tp=-1.0:lra=50.0`.

Since calculating md5 takes quite a long time, the filename of profiles are determined by the first 10 MB (could be modified in `main.lua`) of corresponding file.
