from __future__ import annotations

from batocera_common.dataclasses import cached_dataclass, cached_property
from batocera_launch import Command, Emulator, HotkeysContext


# batocera-launch emulator for KytyPS5 (Batocera 44 and later, which have no
# configgen). kytyps5.sh registers it as the "kyty" entry point.
@cached_dataclass
class Kyty(Emulator):

    @cached_property
    def hotkeygen_context(self) -> HotkeysContext:
        return {
            'name': 'kyty',
            'keys': {'exit': ['KEY_LEFTALT', 'KEY_F4']},
        }

    async def configure(self) -> Command:
        # kyty.sh finds the X display, resolves game folders to their eboot.bin
        # and logs to /userdata/system/logs/kyty.log
        return Command(['/userdata/system/add-ons/kytyps5/kyty.sh', self.rom])
