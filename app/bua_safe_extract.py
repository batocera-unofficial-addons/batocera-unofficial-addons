#!/usr/bin/env python3
"""BUA archive extraction guard. Deliberately rejects links, special files and duplicate paths."""
import os
import stat
import sys
import tarfile
import zipfile
from pathlib import Path, PurePosixPath

MAX_MEMBERS = 100000
MAX_TOTAL_SIZE = 20 * 1024**3

def checked_name(name):
    if not isinstance(name, str) or not name or '\\' in name or '\x00' in name:
        raise ValueError(f'Unsafe archive name: {name!r}')
    if name.startswith('/') or name.startswith('//'):
        raise ValueError(f'Absolute archive path: {name!r}')
    parts = name.rstrip('/').split('/')
    if parts and parts[0] == '.':
        parts = parts[1:]
    if not parts or any(x in ('', '.', '..') for x in parts):
        raise ValueError(f'Traversal or noncanonical path: {name!r}')
    if ':' in parts[0]:
        raise ValueError(f'Drive-like archive path: {name!r}')
    return tuple(parts)

def extract(archive_path, destination):
    archive_path = Path(archive_path)
    root = Path(destination)
    if root.is_symlink():
        raise ValueError('Extraction destination is symlink')
    for ancestor in root.parents:
        if ancestor.is_symlink():
            raise ValueError('Extraction ancestor is symlink')
    root.mkdir(parents=True, exist_ok=True)
    root = root.resolve(strict=True)
    if not root.is_dir():
        raise ValueError('Extraction destination is not directory')
    mode = 'zip' if zipfile.is_zipfile(archive_path) else 'tar'
    with (zipfile.ZipFile(archive_path) if mode == 'zip' else tarfile.open(archive_path, 'r:*')) as archive:
        members = archive.infolist() if mode == 'zip' else archive.getmembers()
        if len(members) > MAX_MEMBERS:
            raise ValueError('Too many archive members')
        seen = set()
        total = 0
        validated = []
        for member in members:
            name = member.filename if mode == 'zip' else member.name
            if name in (".", "./") and ((member.is_dir() if mode == 'zip' else member.isdir())):
                continue
            key = checked_name(name)
            if key in seen:
                raise ValueError(f'Duplicate archive entry: {name!r}')
            seen.add(key)
            if mode == 'zip':
                kind = (member.external_attr >> 16) & 0o170000
                is_dir = member.is_dir()
                if kind not in (0, stat.S_IFREG, stat.S_IFDIR) or (is_dir and kind == stat.S_IFREG):
                    raise ValueError(f'Unsafe ZIP file type: {name!r}')
                size = member.file_size
            else:
                is_dir = member.isdir()
                if not (is_dir or member.isfile()):
                    raise ValueError(f'Unsafe TAR file type/link: {name!r}')
                size = member.size
            total += size
            if total > MAX_TOTAL_SIZE:
                raise ValueError('Archive exceeds extraction size limit')
            validated.append((member, key, is_dir))
        # Validate collisions between ancestor files and descendants before writing.
        file_keys = {key for _, key, is_dir in validated if not is_dir}
        for _, key, _ in validated:
            if any(key[:i] in file_keys for i in range(1, len(key))):
                raise ValueError(f'File used as directory: {key!r}')
        # Refuse existing symlink parents and destinations even inside staging roots.
        for _, key, _ in validated:
            target = root
            for part in key:
                target = target / part
                if target.is_symlink():
                    raise ValueError(f'Existing symlink within extraction: {target}')
                if target.exists() and not (target.is_dir() or target.is_file()):
                    raise ValueError(f'Existing special file: {target}')
        for member, key, is_dir in validated:
            target = root.joinpath(*key)
            if is_dir:
                if target.exists() and not target.is_dir():
                    raise ValueError(f'Directory collides with existing file: {target}')
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with (archive.open(member, 'r') if mode == 'zip' else archive.extractfile(member)) as source:
                if source is None:
                    raise ValueError('Missing member file content')
                with target.open('xb') as output:
                    while True:
                        chunk = source.read(1024*1024)
                        if not chunk:
                            break
                        output.write(chunk)
            # Preserve executable mode for known regular files, never special bits.
            permissions = ((member.external_attr >> 16) if mode == 'zip' else member.mode) & 0o777
            os.chmod(target, permissions & 0o777)

if __name__ == '__main__':
    if len(sys.argv) != 3:
        raise SystemExit('Usage: bua_safe_extract.py ARCHIVE DESTINATION')
    try:
        extract(sys.argv[1], sys.argv[2])
    except Exception as exc:
        print(f'[BUA] Unsafe or invalid archive rejected: {exc}', file=sys.stderr)
        raise SystemExit(1)
