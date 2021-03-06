#!/bin/env bash
# todo: remove support for git repositoris in favor of `git archive`
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Package all a directory according to the '.pak' file.                 #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
SCRIPT_NAME="$(basename "$0")"

usage()
{
echo "Usage: $SCRIPT_NAME [options] [ARCHIVE]
     --help              diaplay this help text.
  -f --pak-file=[FILE]   use a specific pak file.
     --include           include specified paths.
     --no-ignore-pak     include the pak file in the resulting archive.
  -g --git               pak a directory according according to a '.gitignore'
                         file.
     --tarball           package as a tarball filtered through gzip instead of
                         a simple compressed archive.
"
}

echo_err()
{
    echo "$SCRIPT_NAME: $1" 1>&2
}

# Zip contents of the current git branch
get_git_targets()
{
    git ls-tree -r --name-only "$(git branch | grep \* | cut --delimiter ' ' --fields 2)" | tr '\n' ' '
}

# Find all files pointed to by the pak file
get_pak_targets()
{
    while IFS= read -r path; do
        path="$target_dir/$path"
        if [ -d "$path" ]; then
            pattern="$pattern|$path(/.*)?"
        elif [ -f "$path" ]; then
            pattern="$pattern|.*/$path"
        fi
    done < "$pak_file"

    # remove the first uneeded pipe
    pattern="${pattern:1}"

    if [ "$mode" == "ignore" ]; then
        find "$target_dir" -regextype posix-egrep -not -regex "$pattern" | tr '\n' ' '
    elif [ "$mode" == "include" ]; then
        find "$target_dir" -regextype posix-egrep -regex "$pattern" | tr '\n' ' '
    fi
}

pak_git()
{
    if [ -n "$tarball" ]; then
        tar --create --verbose --gzip --file "$archive" $(get_git_targets)
    else
        zip "$archive" $(get_git_targets)
    fi
}

pak_dir()
{
    get_pak_targets
    if [ "$noignore" ]; then
        if [ -n "$tarball" ]; then
              tar --create --verbose --gzip --file "$archive" $(get_pak_targets)
        else
            zip "$archive" $(get_pak_targets)
        fi
    else
        if [ -n "$tarball" ]; then
              tar --create --gzip --verbose --file "$archive" $(get_pak_targets) --exclude "$pak_file"
        else
            zip "$archive" $(get_pak_targets) -x "$pak_file"
        fi
    fi
}

# parse options and arguments
opts=$(getopt -qo "gp:f:" --long "help,include,git,pak-file:,no-ignore-pak,tarball" -- "$@")
eval set -- "${opts}"

mode="ignore"
target_dir=$(basename "$PWD")
pak_file="$target_dir/.pak"

while [ "$#" -ne 0 ]; do
    case "$1" in
        --help) usage
            exit 0
            ;;
        -f | --pak-file) pak_file="$2"
            shift
            ;;
        --include) mode="include"
            ;;
        -g | --git) mode="git"
            ;;
        --no-ignore-pak) noignore=0
            ;;
        --tarball) tarball=0
            ;;
        *) shift
            break
            ;;
    esac
    shift
done

if [ -n "$1" ]; then archive="$1"; fi
if [ -z "$archive" ]; then archive="$target_dir"; fi
if [ -n "$tarball" ]; then archive="${archive}.tar.gz"; else archive="$archive.zip"; fi

if [ "$mode" == "git" ]; then
    if ! git rev-parse --git-dir &> /dev/null; then
        exit 1
    fi

    cd "$(basename $(git rev-parse --show-toplevel))"
    pak_git
else
    cd ..
    if [ ! -e "$pak_file" ]; then
        echo_err "Could not find pak file '$pak_file'."
        exit 1
    fi
    pak_dir
    mv "$archive" "$target_dir"
fi
