"""Plan safe recovery of interrupted BUA updater installations."""

from pathlib import Path


def plan_updater_recovery(root, pair_verified=False):
    """Plan recovery without modifying files or trusting unverified pairs."""
    root = Path(root)

    paths = {
        "active_updater": root / "updater",
        "active_verification": root / "verification",
        "previous_updater": root / ".bua-updater-previous",
        "previous_verification": root / ".bua-verification-previous",
    }

    for name, path in paths.items():
        if path.is_symlink():
            return "failed", f"Unexpected symlink: {name}"
        if path.exists() and not path.is_dir():
            return "failed", f"Unexpected installation type: {name}"

    present = {
        name: path.is_dir()
        for name, path in paths.items()
    }

    au = present["active_updater"]
    av = present["active_verification"]
    pu = present["previous_updater"]
    pv = present["previous_verification"]

    if not pu and not pv:
        if au and av:
            return "verify_active", "Active pair requires authentication"
        return "failed", "No complete active or recovery pair"

    if pu and pv:
        if not au and not av:
            if not pair_verified:
                return "verify_previous", "Previous pair requires authentication"
            return "restore_previous", "Authenticated previous pair"

        if au and not av:
            if not pair_verified:
                return "verify_previous", "Previous pair requires authentication"
            return "isolate_and_restore", "Authenticated previous pair"

        if au and av:
            return "verify_active_first", "Both generations are present"

    # Crash after restoring the previous updater but before restoring
    # its verification metadata. Authentication is still mandatory.
    if au and not av and not pu and pv:
        if not pair_verified:
            return (
                "verify_split_previous",
                "Interrupted restoration requires pair authentication",
            )
        return (
            "complete_split_restoration",
            "Authenticated split previous pair",
        )

    return "failed", "Recovery pair is incomplete or ambiguous"


def recover_interrupted_updater(root, trusted_bundle, bundle_sha256, verify_pair):
    """Recover under the shared lock using an authenticated pair verifier.

    verify_pair must be the trusted verify_bua_candidate_pair function.
    Returns (ready | rolled_back | failed, explanation).
    """
    import fcntl
    import os
    import uuid

    root = Path(root)
    if root.is_symlink() or not root.is_dir():
        return "failed", "Invalid BUA installation root"

    lock_path = root / ".bua-support-install.lock"
    if lock_path.is_symlink():
        return "failed", "Invalid installation lock"

    active_updater = root / "updater"
    active_verification = root / "verification"
    previous_updater = root / ".bua-updater-previous"
    previous_verification = root / ".bua-verification-previous"

    def authenticated(updater, verification):
        try:
            return verify_pair(
                updater, verification, trusted_bundle, bundle_sha256
            )
        except Exception as exc:
            return False, "Verification error: " + str(exc)

    with lock_path.open("a+b") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        try:
            decision, reason = plan_updater_recovery(root)

            if decision == "verify_split_previous":
                # The previous updater was restored before interruption.
                # Authenticate it against its still-retained metadata.
                valid, detail = authenticated(
                    active_updater, previous_verification
                )
                if not valid:
                    return "failed", "Split previous pair rejected: " + detail

                confirmed, reason = plan_updater_recovery(
                    root, pair_verified=True
                )
                if confirmed != "complete_split_restoration":
                    return "failed", reason

                # A valid pair exists, but its directories are split.
                # Do not overwrite any destination.
                if (
                    active_verification.exists()
                    or active_verification.is_symlink()
                    or previous_verification.is_symlink()
                    or not previous_verification.is_dir()
                ):
                    return "failed", "Unsafe split restoration state"

                try:
                    os.rename(
                        previous_verification,
                        active_verification,
                    )
                except OSError as exc:
                    return "failed", "Split restoration failed: " + str(exc)

                valid, detail = authenticated(
                    active_updater, active_verification
                )
                if not valid:
                    return (
                        "failed",
                        "Completed split restoration failed verification: "
                        + detail,
                    )

                return "rolled_back", "Authenticated split restoration completed"

            if decision == "verify_active":
                valid, detail = authenticated(
                    active_updater, active_verification
                )
                return ("ready" if valid else "failed"), detail

            if decision == "verify_active_first":
                valid, detail = authenticated(
                    active_updater, active_verification
                )
                if valid:
                    # Leave previous pair intact for later backup retention.
                    return "ready", "Active pair verified; previous pair retained"

            elif decision != "verify_previous":
                return "failed", reason

            # Never modify filesystem entries before authenticating
            # the complete previous pair.
            valid, detail = authenticated(
                previous_updater, previous_verification
            )
            if not valid:
                return "failed", "Previous pair rejected: " + detail

            decision, reason = plan_updater_recovery(
                root, pair_verified=True
            )

            if decision == "verify_active_first":
                decision = "isolate_and_restore"

            if decision not in ("restore_previous", "isolate_and_restore"):
                return "failed", reason

            # Preserve any partially activated generation without deleting it.
            quarantine = root / ".bua-recovery-quarantine"
            isolated = []

            if decision == "isolate_and_restore":
                try:
                    quarantine.mkdir(mode=0o700, exist_ok=True)
                    if quarantine.is_symlink():
                        return "failed", "Invalid quarantine directory"

                    for current in (active_updater, active_verification):
                        if current.exists() or current.is_symlink():
                            destination = quarantine / (
                                current.name + "-" + uuid.uuid4().hex
                            )
                            os.rename(current, destination)
                            isolated.append((current, destination))
                except OSError as exc:
                    reversal_errors = []

                    # Undo successful quarantine moves in reverse order.
                    # Never overwrite an existing active directory.
                    for original, isolated_path in reversed(isolated):
                        try:
                            if (
                                original.exists()
                                or original.is_symlink()
                                or not isolated_path.is_dir()
                                or isolated_path.is_symlink()
                            ):
                                raise OSError(
                                    "Unsafe quarantine reversal destination"
                                )

                            os.rename(isolated_path, original)

                        except OSError as reversal_exc:
                            reversal_errors.append(
                                str(isolated_path) + ": " + str(reversal_exc)
                            )

                    if reversal_errors:
                        return (
                            "failed",
                            "Quarantine failure: "
                            + str(exc)
                            + "; incomplete reversal; recovery files preserved: "
                            + "; ".join(reversal_errors),
                        )

                    return (
                        "failed",
                        "Cannot isolate active files; completed moves reversed: "
                        + str(exc),
                    )

            if (
                active_updater.exists()
                or active_updater.is_symlink()
                or active_verification.exists()
                or active_verification.is_symlink()
            ):
                return "failed", "Active directory still obstructs restoration"

            restored = []

            try:
                for previous, active in (
                    (previous_updater, active_updater),
                    (previous_verification, active_verification),
                ):
                    if (
                        previous.is_symlink()
                        or not previous.is_dir()
                        or active.exists()
                        or active.is_symlink()
                    ):
                        raise OSError(
                            "Unsafe restoration source or destination: "
                            + str(active)
                        )

                    os.rename(previous, active)
                    restored.append((previous, active))

            except OSError as exc:
                reversal_errors = []

                # Undo completed restoration moves in reverse order.
                # Keep the previous generation together if possible.
                for previous, active in reversed(restored):
                    try:
                        if (
                            previous.exists()
                            or previous.is_symlink()
                            or active.is_symlink()
                            or not active.is_dir()
                        ):
                            raise OSError(
                                "Unsafe restoration reversal: " + str(previous)
                            )

                        os.rename(active, previous)

                    except OSError as reversal_exc:
                        reversal_errors.append(
                            str(active) + ": " + str(reversal_exc)
                        )

                if reversal_errors:
                    return (
                        "failed",
                        "Restoration failed: "
                        + str(exc)
                        + "; reversal incomplete; manual recovery required: "
                        + "; ".join(reversal_errors),
                    )

                return (
                    "failed",
                    "Restoration failed; completed moves reversed: "
                    + str(exc),
                )

            valid, detail = authenticated(
                active_updater, active_verification
            )
            if not valid:
                return "failed", "Restored pair failed verification: " + detail

            return "rolled_back", "Authenticated previous pair restored"
        finally:
            fcntl.flock(lock.fileno(), fcntl.LOCK_UN)
