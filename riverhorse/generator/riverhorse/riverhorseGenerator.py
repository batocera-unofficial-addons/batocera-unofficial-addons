from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

from ...batoceraPaths import CONFIGS
from ..duckstation import duckstationGenerator as _ds
from ..duckstation.duckstationGenerator import DuckstationGenerator

if TYPE_CHECKING:
    from ...types import HotkeysContext

_APPIMAGE = '/userdata/system/add-ons/riverhorse/Riverhorse.AppImage'
_SETTINGS_DIR = CONFIGS / 'riverhorse'
# A folder whose "duckstation" entry points to Riverhorse's settings folder
_SHIM = Path('/userdata/system/add-ons/riverhorse/configgen')


# configgen generator for Riverhorse (Batocera 43 and earlier; 44 and later use
# the batocera-launch emulator in launch/). BUA's usercustomize.py hook adds
# add-ons/*/generator to configgen.generators, and configgen finds this as
# riverhorse.riverhorseGenerator.RiverhorseGenerator.
#
# Riverhorse is based on the DuckStation that Batocera ships and reads the same
# settings.ini keys, so this reuses Batocera's own DuckStation generator. That
# generator always writes CONFIGS/duckstation/settings.ini, so while it runs,
# its CONFIGS points to a folder where "duckstation" is Riverhorse's settings
# folder (/userdata/system/configs/riverhorse, where Riverhorse reads them as
# XDG_CONFIG_HOME/riverhorse). DuckStation's own settings are not touched.
class RiverhorseGenerator(DuckstationGenerator):

    def getHotkeysContext(self) -> HotkeysContext:
        context = super().getHotkeysContext()
        context['name'] = 'riverhorse'
        return context

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        _SETTINGS_DIR.mkdir(parents=True, exist_ok=True)
        _SHIM.mkdir(parents=True, exist_ok=True)
        link = _SHIM / 'duckstation'
        if not link.is_symlink() or link.readlink() != _SETTINGS_DIR:
            link.unlink(missing_ok=True)
            link.symlink_to(_SETTINGS_DIR)

        configs = _ds.CONFIGS
        _ds.CONFIGS = _SHIM
        try:
            command = super().generate(system, rom, playersControllers, metadata, guns, wheels, gameResolution)
        finally:
            _ds.CONFIGS = configs

        rom = command.array[-1]  # DuckStation's rom (an .m3u already rewritten)
        command.array = [_APPIMAGE, '-batch', '-nogui', '-fullscreen', '--', rom]
        command.env['XDG_CONFIG_HOME'] = CONFIGS
        # Batocera's DuckStation needs its own shaderc; the AppImage brings
        # everything it needs
        command.env.pop('LD_LIBRARY_PATH', None)
        return command
