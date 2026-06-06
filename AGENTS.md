# Agent instructions

- Package dirs live in `packages/<pkgbase>`; treat each dir as AUR payload.
- Root `justfile` is sole workflow interface; use it for all operations. Do not add per-package justfiles unless package has unique steps.
- If the justfile lacks a recipe needed to accomplish a goal, escalate — do not bypass with raw commands or ad-hoc scripts.
- Edit `PKGBUILD`; regenerate `.SRCINFO` with `just srcinfo <pkgbase>` or `just refresh <pkgbase>`.
- Never edit `.SRCINFO` manually.
- Build/lint with `just check <pkgbase>`; clean chroot with `just chroot <pkgbase>` when needed.
- AUR clones live in `.aur/<pkgbase>`; never edit `.aur` directly.
- Publish via `just publish <pkgbase> "message"`; push GitHub via normal git or `just github-push "message"`.
