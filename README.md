# mpv-loudnorm-lua

Apply double-pass loudnorm filter in [mpv](https://mpv.io/).

Inspired by [MPV-LoudNorm](https://github.com/ThinkMcFlyThink/MPV-LoudNorm). Use only lua scripts to avoid annoying popout windows.

Save the measured results into txt for reuse. A unique profile name for each file is generated with [md5.lua](https://github.com/kikito/md5.lua).

## Usage

Put the `loudnorm` folder in mpv script folder (`scripts`). The txt profile inside `data` is just an example and can be deleted, but the `data` folder itself should always exist, because I didn't write any script to regenerate it.

By default, the script will run automatically when opening videos in `Y:` and `Z:`, which is a very personal behavior and can be modified in `main.lua`. You may also add key bindings in `input.conf` with command name `script-message 2pass-loudnorm` (could be changed in `main.lua`).

The target loudness is defined at the beginning of `main.lua`. The default setting is `i=-24.0:tp=-1.0:lra=50.0`.

Since calculating md5 takes quite a long time, the filename of profiles are determined by the first 10 MB (could be modified in `main.lua`) of corresponding file.

Since calculating true peak also takes a lot of time, `ebur128=framelog=verbose,volumedetect` is used instead of `loudnorm` to get the first-pass information. It seems that peak is used instead of true peak in this case, which may lead to a louder result.
