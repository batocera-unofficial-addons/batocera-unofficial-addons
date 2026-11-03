from __future__ import annotations

from typing import TYPE_CHECKING

from ... import Command
from ..Generator import Generator

if TYPE_CHECKING:
    from ...types import HotkeysContext


class KytyGenerator(Generator):

    def getHotkeysContext(self) -> HotkeysContext:
        return {
            "name": "kyty",
            "keys": { "exit": ["KEY_LEFTALT", "KEY_F4"] }
        }

    def generate(self, system, rom, playersControllers, metadata, guns, wheels, gameResolution):
        # kyty.sh finds the X display, resolves game folders to their eboot.bin
        # and logs to /userdata/system/logs/kyty.log
        commandArray = ['/userdata/system/add-ons/kytyps5/kyty.sh', str(rom)]

        return Command.Command(array=commandArray, env={})
