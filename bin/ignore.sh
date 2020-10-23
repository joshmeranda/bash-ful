#!/usr/bin/env bash
# # # # # # # # # # # ## # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Merge the content of one or more gitignore files from the upstream standard  #
# gitignore repository: github.com/github/gitignore                            #
# # # # # # # # # # # ## # # # # # # # # # # # # # # # # # # # # # # # # # # # #
SCRIPT_NAME="$(basename "$0")"
upstream_url='https://github.com/github/gitignore'

usage() {
echo "Usage: $SCRIPT_NAME [targets]

For a complete list of all available targets please view the upstream repository here:
    $upstream_url"
}

echo_err() {
    echo -e "$SCRIPT_NAME: $1" 2>&1
}

if [ "$#" -eq 0 ]; then
    echo_err "missing operands."
    usage
    exit 1
fi


# check for templates, and install from upstream if not found
gitignore_dir='/usr/share/gitignore'
if [ ! -d $gitignore_dir ]; then
    echo_err "could not find templates: no such directory '$gitignore_dir'.
Attempting to clone from $upstream_url..."

    cd $(dirname $gitignore_dir)
    if ! git clone $upstream_url;then
        echo_err "Could not install templates"
        exit 1
    fi
fi

# generate find predicates
pattern=()
for name in "$@"; do
    predicates+=(-iname $name.gitignore -o)
done
predicates+=(-false) # necessary for trailinty '-o'

# write gitignore file
gitignore="$(realpath .)/.gitignore"

echo "# # # # # # # # # # # ## # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# This gitignore was auto-generated using the standard templates published by  #
# github here: github.com/github/gitignore                                     #
# # # # # # # # # # # ## # # # # # # # # # # # # # # # # # # # # # # # # # # # #
" > $gitignore

for target in $(find $gitignore_dir ${predicates[@]}); do
    echo "# $(basename $target)" >> $gitignore
    cat $target >> $gitignore
    echo >> $gitignore  # add some whitespace
done
