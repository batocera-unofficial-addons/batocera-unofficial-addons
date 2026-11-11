from __future__ import annotations

from typing import TYPE_CHECKING

from batocera_common.configparser import CaseSensitiveRawConfigParser
from batocera_common.dataclasses import cached_dataclass, cached_property
from batocera_common.paths import SCREENSHOTS
from batocera_launch.emulators.azahar import Azahar

if TYPE_CHECKING:
    from batocera_launch import Command, HotkeysContext

_APPIMAGE = '/userdata/system/add-ons/azaharplus/azahar.AppImage'


# batocera-launch emulator for AzaharPlus (Batocera 44 and later, which have no
# configgen). azaharplus.sh registers it as the "azaharplus" entry point.
#
# AzaharPlus is a fork of Azahar and reads the same azahar-emu config folder,
# so this reuses Batocera's own Azahar emulator (qt-config.ini, controllers,
# region, Vulkan GPU, es_features options) and only swaps the program.
@cached_dataclass
class AzaharPlus(Azahar):

    @cached_property
    def hotkeygen_context(self) -> HotkeysContext:
        return {
            'name': 'azaharplus',
            'keys': {
                'exit': ['KEY_LEFTALT', 'KEY_F4'],
                'menu': 'KEY_F4',
                'pause': 'KEY_F4',
                'reset': 'KEY_F6',
                'screen_layout': 'KEY_F10',
                'swap_screen': 'KEY_F9',
            },
        }

    async def configure(self) -> Command:
        command = await super().configure()  # writes azahar-emu/qt-config.ini
        self._fix_ui_keys()
        command.args[0] = _APPIMAGE
        return command

    def _fix_ui_keys(self) -> None:
        # Batocera 44's Azahar writes these [UI] options under snake_case names
        # that neither Azahar nor AzaharPlus read. Write the names the program
        # uses (as the Batocera 43 generator did), so it starts without the
        # first-run pop-up, title bar or update check, and saves screenshots to
        # /userdata/screenshots.
        config_file = self.config_dir / 'qt-config.ini'
        config = CaseSensitiveRawConfigParser(strict=False)
        config.read(config_file)
        if not config.has_section('UI'):
            config.add_section('UI')
        for key, value in (
            ('displayTitleBars', 'false'),
            ('firstStart', 'false'),
            ('hideInactiveMouse', 'true'),
            ('calloutFlags', '1'),
            ('confirmClose', 'false'),
            (r'Paths\screenshotPath', str(SCREENSHOTS)),
            (r'Updater\check_for_update_on_start', 'false'),
        ):
            config.set('UI', key, value)
            config.set('UI', key + r'\default', 'false')
        with config_file.open('w') as fp:
            config.write(fp)
