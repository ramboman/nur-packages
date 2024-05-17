#!/usr/bin/env nix-shell
#! nix-shell -i bash -p nix-prefetch jq

script_file=$0
script_name=$(basename "$script_file")
script_dir=$(cd "$(dirname "$script_file")"; pwd)

get_source_version() {
    local release_text=$1

    local version=$(echo "$release_text" | jq --raw-output '.tag_name')
    echo "${version#v}"
}

get_remote_version() {
    local url=$1

    curl --silent "$url" | jq --raw-output
}

get_local_version() {
    local path=$1

    cat "$path" | jq --raw-output
}

get_source_shas_nix() {
    local release_text=$1

    local jq_text='.assets[] | select(.name | test("xz")) | .name, .browser_download_url'
    printf '{\n'
    while
        read -r name
        read -r url
    do
        printf '  "%s" = "%s";\n' "${name%%.*}" "$(nix-prefetch-url "$url")"
    done < <(echo "$release_text" | jq --raw-output "$jq_text")
    printf '}\n'
}

get_remote_shas_nix() {
    local url=$1

    curl --silent "$url"
}

get_local_shas_nix() {
    local path=$1

    cat "$path"
}

get_extra_fonts() {
    local new_shas_nix=$1
    local old_shas_nix=${2:-}

    local nix_command=(nix-instantiate --eval - --arg newShas "$new_shas_nix")
    if [ -n "$old_shas_nix" ]; then
        nix_command+=(--arg oldShas "$old_shas_nix")
    fi

    "${nix_command[@]}" << EOF \
    | jq --raw-output \
    | jq '.'
    { newShas
    , oldShas ? {}
    }:
    let
      pkgs = import <nixpkgs> {};
      naming = import "$script_dir/naming.nix" { lib = pkgs.lib; };
      newFontNames = builtins.attrNames newShas;
      oldFontNames = builtins.attrNames oldShas;
      extraFontNames = pkgs.lib.lists.subtractLists oldFontNames newFontNames;
      getProcessedNames =
        fontName:
        {
          tempName = naming.getTempName fontName;
          pname = naming.getPname fontName;
          attrName = naming.getAttrName fontName;
        };
      extraProcessedNames =
        builtins.listToAttrs
          (map
            (fontName: { name = fontName; value = getProcessedNames fontName; })
            extraFontNames);
    in builtins.toJSON extraProcessedNames
EOF
}

usage() {
cat << EOF
Usage: $script_name [OPTIONS] [SOURCE]
Update the version and the fonts shas

Positionals:
  SOURCE  where to get the version and the fonts shas
            choices:
              source: nerdfonts source repository
              remote: nerdfonts from github:NixOS/nixpkgs
              relative: ../<original nerdfonts directory>
            default: source

Options:
  -h, --help  Show this message
EOF
}

main() {
    local source=source

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            *) source=$1 ; shift ;;
        esac
        shift
    done

    local version_command
    local shas_nix_command
    case "$source" in
        source)
            local latest_release=$(curl --silent https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest)
            version_command=(get_source_version "$latest_release")
            shas_nix_command=(get_source_shas_nix "$latest_release")
            ;;
        remote)
            local path=https://raw.githubusercontent.com/NixOS/nixpkgs/master/pkgs/data/fonts/nerdfonts
            version_command=(get_remote_version "$path/version.nix")
            shas_nix_command=(get_remote_shas_nix "$path/shas.nix")
            ;;
        relative)
            local path=../nerdfonts-og
            version_command=(get_local_version "$path/version.nix")
            shas_nix_command=(get_local_shas_nix "$path/shas.nix")
            ;;
        *)
            echo "ERROR: unknown source: $source">&2
            exit 1
            ;;
    esac

    local version_file=$script_dir/version.nix
    local old_version=
    if [ -f "$version_file" ]; then
        old_version=$(jq --raw-output '.' "$version_file")
    fi
    local new_version=$("${version_command[@]}")

    if [ -n "$old_version" ] && (! [[ "$new_version" > "$old_version" ]]); then
        echo "No new version available, current: $old_version"
        exit 0
    fi

    local shas_file=$script_dir/shas.nix
    local old_shas_nix=
    if [ -f "$shas_file" ]; then
        old_shas_nix=$(cat "$shas_file")
    fi
    local new_shas_nix=$("${shas_nix_command[@]}")

    echo "\"$new_version\"" > "$version_file"
    echo "$new_shas_nix" > "$shas_file"
    echo "Updated to version $new_version"

    local extra_fonts=$(get_extra_fonts "$new_shas_nix" "$old_shas_nix")
    if [ "$extra_fonts" != '{}' ]; then
        echo "New fonts added:"
        echo "$extra_fonts"
    fi
}

main "$@"

