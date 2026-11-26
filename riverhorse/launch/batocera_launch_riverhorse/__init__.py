from __future__ import annotations

from typing import TYPE_CHECKING

from batocera_common.dataclasses import cached_dataclass, cached_property
from batocera_launch.emulators.duckstation import Duckstation

if TYPE_CHECKING:
    from batocera_launch import Command, HotkeysContext

_APPIMAGE = '/userdata/system/add-ons/riverhorse/Riverhorse.AppImage'


# batocera-launch emulator for Riverhorse (Batocera 44 and later).
# riverhorse.sh registers it as the "riverhorse" entry point.
#
# Riverhorse is based on the DuckStation that Batocera ships and reads the same
# settings.ini keys, so this reuses Batocera's own DuckStation emulator
# (settings, BIOS, controllers, guns, hotkeys, es_features options) and only
# swaps the program. The emulator is named "riverhorse", so its settings go to
# /userdata/system/configs/riverhorse, which is where Riverhorse reads them
# (XDG_CONFIG_HOME/riverhorse).
@cached_dataclass
class Riverhorse(Duckstation):

    @cached_property
    def hotkeygen_context(self) -> HotkeysContext:
        return {
            'name': 'riverhorse',
            'keys': {
                'exit': ['KEY_LEFTALT', 'KEY_F4'],
                'menu': 'KEY_F7',
                'reset': 'KEY_F6',
                'restore_state': 'KEY_F1',
                'save_state': 'KEY_F2',
                'previous_slot': 'KEY_F3',
                'next_slot': 'KEY_F4',
                'rewind': 'KEY_F5',
                'fastforward': 'KEY_TAB',
                'next_disk': 'KEY_F8',
            },
        }

    async def configure(self) -> Command:
        command = await super().configure()  # writes riverhorse/settings.ini
        rom = command.args[-1]  # DuckStation's rom (an .m3u already rewritten)
        command.args = [_APPIMAGE, '-batch', '-nogui', '-fullscreen', '--', rom]
        # Batocera's DuckStation needs its own shaderc; the AppImage brings
        # everything it needs
        command.env.pop('LD_LIBRARY_PATH', None)
        return command
