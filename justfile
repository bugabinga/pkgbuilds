set shell := ["bash", "-euo", "pipefail", "-c"]

packages_dir := "packages"
aur_dir := ".aur"

default:
    @just --list

[group('info')]
list:
    @fd -td -d1 . {{ packages_dir }} -x basename {}

[group('pkg')]
srcinfo name:
    cd {{ packages_dir }}/{{ name }} && makepkg --printsrcinfo > .SRCINFO

[group('pkg')]
checksums name:
    cd {{ packages_dir }}/{{ name }} && updpkgsums

[group('pkg')]
refresh name: (checksums name) (srcinfo name)

[group('pkg')]
verifysource name:
    cd {{ packages_dir }}/{{ name }} && makepkg --verifysource

[group('pkg')]
build name:
    cd {{ packages_dir }}/{{ name }} && makepkg -s --cleanbuild --force

[group('pkg')]
install name:
    cd {{ packages_dir }}/{{ name }} && makepkg -si

[group('pkg')]
lint name:
    cd {{ packages_dir }}/{{ name }} && namcap PKGBUILD
    cd {{ packages_dir }}/{{ name }} && { compgen -G '*.pkg.tar.*' >/dev/null && namcap *.pkg.tar.* || true; }

[group('pkg')]
chroot name:
    cd {{ packages_dir }}/{{ name }} && extra-x86_64-build

[group('pkg')]
check name: (build name) (lint name) (srcinfo name)

[group('pkg')]
clean name:
    rm -rf {{ packages_dir }}/{{ name }}/src {{ packages_dir }}/{{ name }}/pkg {{ packages_dir }}/{{ name }}/cargo-home
    rm -f {{ packages_dir }}/{{ name }}/*.pkg.tar.* {{ packages_dir }}/{{ name }}/*.pkg.tar.*.sig {{ packages_dir }}/{{ name }}/*.log

[group('pkg')]
status name:
    git status --short {{ packages_dir }}/{{ name }}

[group('pkg')]
latest name:
    #!/usr/bin/env bash
    set -euo pipefail
    pkgdir="{{ packages_dir }}/{{ name }}"
    current=$(cd "$pkgdir" && makepkg --printsrcinfo | awk -F ' = ' '/^[[:space:]]*pkgver = / && !v { v=$2 } END { print v }')
    url=$(cd "$pkgdir" && makepkg --printsrcinfo | awk -F ' = ' '/^[[:space:]]*url = / && !u { u=$2 } END { print u }')

    printf '==> %s\n' "{{ name }}"
    printf 'source:  %s\n' "$url"
    printf 'current: %s\n' "$current"

    if [[ "{{ name }}" == *-git ]]; then
      printf 'type:    vcs\n'
      output=$(cd "$pkgdir" && makepkg -od --noprepare --force 2>&1) || {
        printf '%s\n' "$output"
        exit 1
      }
      updated=$(awk '/^==> Updated version:/ { print $NF }' <<<"$output" | tail -1)
      latest=${updated%-*}
      latest=${latest:-$current}
      source_name=$(basename "${url%.git}")
      head=$(git -C "$pkgdir/$source_name" rev-parse --short HEAD 2>/dev/null || true)
      [[ -n "$head" ]] && printf 'head:    %s\n' "$head"
    else
      printf 'type:    release\n'
      repo=${url#https://github.com/}
      repo=${repo%.git}
      latest=$(gh release view -R "$repo" --json tagName -q .tagName)
      latest=${latest#v}
    fi

    printf 'latest:  %s\n' "$latest"
    cmp=$(vercmp "$current" "$latest")
    if [[ "$cmp" -lt 0 ]]; then
      printf 'status:  update available (%s -> %s)\n' "$current" "$latest"
    elif [[ "$cmp" -eq 0 ]]; then
      printf 'status:  current\n'
    else
      printf 'status:  local newer (%s > %s)\n' "$current" "$latest"
    fi

[group('all')]
all-latest:
    @for p in {{ packages_dir }}/*; do [ -d "$p" ] && just latest "$(basename "$p")"; done

[group('all')]
all-srcinfo:
    for p in {{ packages_dir }}/*; do [ -d "$p" ] && just srcinfo "$(basename "$p")"; done

[group('all')]
all-refresh:
    for p in {{ packages_dir }}/*; do [ -d "$p" ] && just refresh "$(basename "$p")"; done

[group('all')]
all-check:
    for p in {{ packages_dir }}/*; do [ -d "$p" ] && just check "$(basename "$p")"; done

[group('all')]
all-clean:
    for p in {{ packages_dir }}/*; do [ -d "$p" ] && just clean "$(basename "$p")"; done

[group('aur')]
aur-clone name:
    mkdir -p {{ aur_dir }}
    if [ ! -d {{ aur_dir }}/{{ name }}/.git ]; then git clone ssh://aur@aur.archlinux.org/{{ name }}.git {{ aur_dir }}/{{ name }}; fi

[group('aur')]
aur-sync name: (srcinfo name) (aur-clone name)
    #!/usr/bin/env bash
    set -euo pipefail
    pkgdir="{{ packages_dir }}/{{ name }}"
    aur="{{ aur_dir }}/{{ name }}"
    find "$aur" -mindepth 1 ! -path "$aur/.git" ! -path "$aur/.git/*" -exec rm -rf {} +
    while IFS= read -r -d '' path; do
      rel=${path#"$pkgdir/"}
      mkdir -p "$aur/$(dirname "$rel")"
      cp -p "$path" "$aur/$rel"
    done < <(git ls-files -z -- "$pkgdir")

[group('aur')]
aur-diff name: (aur-sync name)
    git -C {{ aur_dir }}/{{ name }} status --short
    git -C {{ aur_dir }}/{{ name }} diff

[group('aur')]
aur-commit name msg="Update package": (aur-sync name)
    git -C {{ aur_dir }}/{{ name }} add -A
    git -C {{ aur_dir }}/{{ name }} diff --cached --quiet && echo "No AUR changes" || git -C {{ aur_dir }}/{{ name }} commit -m "{{ msg }}"

[group('aur')]
aur-push name:
    git -C {{ aur_dir }}/{{ name }} push

[group('aur')]
publish name msg="Update package": (check name) (aur-commit name msg)
    git -C {{ aur_dir }}/{{ name }} push

[group('github')]
github-create repo visibility="public":
    gh repo create "{{ repo }}" --{{ visibility }} --source=. --remote=origin --push

[group('github')]
github-push msg="Update packages":
    git add .
    git diff --cached --quiet && echo "No GitHub changes" || git commit -m "{{ msg }}"
    git push
