# !/usr/bin/env -S just --justfile
# vim: filetype=just softtabstop=2 tabstop=2 shiftwidth=2 fenc=utf-8 fileformat=unix expandtab
## [ NOTE ] => enables passing in arguments to Just targets from the command line

set positional-arguments := true

## [ NOTE ] => loads `.env` file in repositories root directory to set
## environment variables before running each target

set dotenv-load := true

## [ NOTE ] => sets the default shell that runs instructions in each target

set shell := ["/bin/bash", "-o", "pipefail", "-c"]

# ─── VARIABLES ──────────────────────────────────────────────────────────────────
## [ NOTE ] => This variable is used across targets in the Justfile.
## It is essentially equal to repositories name.
## it uses git's origin upstream to figure out the name, if git
## fails for any reason, it just uses justfile directories name

project_name := `basename "$(git remote get-url origin)" 2>/dev/null | sed 's/.git//' || basename $PWD`

## [ NOTE ] => this variable is used for pinning Vault version

vault_version := '1.7.1'

#
# ────────────────────────────────────────────────────── I ──────────
#   :::::: T A R G E T S : :  :   :    :     :        :          :
# ────────────────────────────────────────────────────────────────
#
## This is the default target that runs when no target is specified

# # It uses FZF to list and fuzzy search the available targets.
default:
    @just --choose

# ─── DOCKER ─────────────────────────────────────────────────────────────────────
## [ NOTE ] => path to sandbox's docker-compose file

sandbox_compose_file := "contrib/docker/sandbox.docker-compose.yml"

## [ NOTE ] => this target initializes
## containers for the sandbox envioronment by building
## the custom images that has our configurations.

# # it also pulls any required docker images.
_docker-sandbox-init:
    #!/usr/bin/env bash
    set -euo pipefail
    docker-compose -f "{{ justfile_directory() }}/{{ sandbox_compose_file }}" build
    docker-compose -f "{{ justfile_directory() }}/{{ sandbox_compose_file }}" pull

## [ NOTE ] => this target tears down docker-compose based sandbox

alias sandbox-down := docker-sandbox-down

docker-sandbox-down:
    #!/usr/bin/env bash
    set -euo pipefail
    docker-compose \
      -f "{{ justfile_directory() }}/{{ sandbox_compose_file }}" \
      down --volumes --remove-orphans

## [ NOTE ] => this target performs house keeps and cleans up
## all docker volumes, networks, local images and containers.
##
## Use this when you want to make 'refresh' docker daemon with a clean
## slate. As an example, there are cases when devcontainer fails
## because of naming collision, this target can deal with that problem
## but be mindful that it will alse wipe out all other images, containers,

# # volumes and networks
docker-clean: docker-sandbox-down
    #!/usr/bin/env bash
    set -euo pipefail
    docker ps -aq | xargs -r -P $(nproc) docker rm -f
    docker system prune -f -a --volumes

## [ NOTE ] => this target blocks shell until
## a docker-compose service , which is identified by
## it's name, passes healthcheck and becomes healthy.
## https://stackoverflow.com/a/57536744

# # https://stackoverflow.com/a/16489942
_block-until-healthy service:
    #!/usr/bin/env bash
    set -euo pipefail
    container_id="$(docker-compose \
      -f "{{ justfile_directory() }}/{{ sandbox_compose_file }}" \
      ps -q '{{ service }}')"
    echo "❯ Service '{{ service }}' container ID :"
    echo "" ;
    echo "${container_id}"
    echo "" ;
    echo "❯ waiting for container '${container_id}' to become healthy."
    echo "" ;
    while : ; do
      health_status="$(docker inspect -f "{{{{.State.Health.Status}}" ${container_id})"
      echo "❯❯ '${container_id}' state ('{{ service }}' service) : ${health_status}"
      [  "${health_status}" != "healthy" ] && sleep 5 || break
    done

## [ NOTE ] => an internal target that
## prints environment variables that must

# # be set in a shell to communicate with consul sandbox environment.
_consul-sandbox-environment-variables:
    #!/usr/bin/env bash
    set -euo pipefail
    container_id="$(docker-compose \
      -f "{{ justfile_directory() }}/{{ sandbox_compose_file }}" \
      ps -q 'consul')"
    echo "export CONSUL_HTTP_TOKEN='root' ;"
    echo "export CONSUL_HTTP_SSL='false' ;"
    echo "export CONSUL_HTTP_ADDR='http://$(docker inspect --format="{{{{.NetworkSettings.IPAddress}}" ${container_id}):8500' ;"

## [ NOTE ] => an internal target that
## prints environment variables that must

# # be set in a shell to communicate with vault sandbox environment.
_vault-sandbox-environment-variables:
    #!/usr/bin/env bash
    set -euo pipefail
    container_id="$(docker-compose \
      -f "{{ justfile_directory() }}/{{ sandbox_compose_file }}" \
      ps -q 'vault')"
    echo "export VAULT_DEV_ROOT_TOKEN_ID='root' ;"
    echo "export VAULT_TOKEN='root' ;"
    echo "export VAULT_ADDR='http://$(docker inspect --format="{{{{.NetworkSettings.IPAddress}}" ${container_id}):8200' ;"

## [ NOTE ] => this is a helper target
## which simplifies process of setting sandbox
## related environment variables in a shell
## outside of the containers

alias sandbox-env := sandbox-environment-variables

sandbox-environment-variables:
    @just -f {{ justfile() }} -d {{ justfile_directory() }} _consul-sandbox-environment-variables
    @just -f {{ justfile() }} -d {{ justfile_directory() }} _vault-sandbox-environment-variables

## [ NOTE ] => this target shows healthcheck state

# # of a service in the sandbox
sandbox-healthcheck service:
    #!/usr/bin/env bash
    set -euo pipefail
    container_id="$(docker-compose \
      -f "{{ justfile_directory() }}/{{ sandbox_compose_file }}" \
      ps -q '{{ service }}')"
    docker inspect --format "{{{{json .State.Health }}" "${container_id}"

## [ NOTE ] => this target brings up the Containerized development environment
## without utilizing VSCode.
## It is useful for people that want to use the pre-configured
## Spacevim in the container rather than using VScode for
## coding.

alias dcu := docker-sandbox-up
alias sandbox := docker-sandbox-up

docker-sandbox-up: docker-sandbox-down _docker-sandbox-init
    #!/usr/bin/env bash
    set -euo pipefail
    echo "" ;
    echo "─────────────────────────────────────────────────────────────────────────"
    echo "" ;
    echo "❯ Sandbox Docker Compose File Path"
    echo "" ;
    echo "{{ sandbox_compose_file }}" ;
    echo "" ;
    echo "─────────────────────────────────────────────────────────────────────────"
    echo "" ;
    docker-compose \
      -f "{{ justfile_directory() }}/{{ sandbox_compose_file }}" \
      up --detach ;
    echo "" ;
    echo "─────────────────────────────────────────────────────────────────────────"
    echo "" ;
    just \
      -f {{ justfile() }} \
      -d {{ justfile_directory() }} \
      _block-until-healthy consul
    echo "" ;
    echo "─────────────────────────────────────────────────────────────────────────"
    echo "" ;
    just \
      -f {{ justfile() }} \
      -d {{ justfile_directory() }} \
      _block-until-healthy vault
    eval "$(just -f {{ justfile() }} -d {{ justfile_directory() }} sandbox-environment-variables)"
    echo "" ;
    echo "─────────────────────────────────────────────────────────────────────────"
    echo "" ;
    echo "❯ Consul sandbox server address :"
    echo "" ;
    echo "$(printenv CONSUL_HTTP_ADDR)" ;
    echo "" ;
    echo "❯ ensuring Consul server is accessible"
    echo "" ;
    consul members ;
    echo "" ;
    echo "─────────────────────────────────────────────────────────────────────────"
    echo "" ;
    echo "❯ Vault sandbox server address :"
    echo "" ;
    echo "$(printenv VAULT_ADDR)" ;
    echo "" ;
    echo "❯ ensuring Vault server is accessible"
    echo "" ;
    vault status ;
    echo "" ;
    echo "─────────────────────────────────────────────────────────────────────────"
    echo "" ;
    echo "❯ run the following to set your shell's env vars"
    echo "" ;
    echo 'eval "$(just sandbox-environment-variables)"'
    echo "" ;
    echo "─────────────────────────────────────────────────────────────────────────"

## [ NOTE ] => this target shows docker-compose logs
## it takes in optional arguments that would
## be appended to the default command
## it executes ( docker-compose logs <arguments/flags>)

alias sandbox-logs := docker-sandbox-logs

docker-sandbox-logs *ARGS:
    #!/usr/bin/env bash
    set -xeuo pipefail
    IFS=' ' read -a CMD <<< "logs {{ ARGS }}" ;
    docker-compose \
      -f "{{ justfile_directory() }}/{{ sandbox_compose_file }}" \
      "${CMD[@]}" ;

# ─── FORMAT ─────────────────────────────────────────────────────────────────────

# # [ NOTE ] => this target formats this Justfile.
format-just:
    #!/usr/bin/env bash
    set -euo pipefail
    just --unstable --fmt 2>/dev/null \
    && git add {{ justfile() }}

## [ NOTE ] => this in an internal target that uses Go toolchain to
## build `shfmt` from source and install it.
##
## Since `shfmt` is in our `tools.go` file, running `just bootstrap`
## which runs `go-bootstrap` target should build and install it.
## This is added here as a safety mechanism to ensure `format-bash`
## target does not fail; in case `go-bootstrap`
## failed or the developer forgot to run `just bootstrap` after cloning

# # the repository.
_format-bash:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! shfmt --version > /dev/null 2>&1 ; then
        echo "*** shfmt not found. installing ..." ;
        go install "mvdan.cc/sh/v3/cmd/shfmt@latest" ;
    fi

## [ NOTE ] => this target runs `_format-bash` internal target
## which ensures `shfmt` is available, then it detects all bash scripts
## , ensures they are set as executable and formats them.
##
## it detects shell scripts by using `gawk` to find files that have a
## shebang that ends in `sh` substring in the source code's
## first four lines.
##
## this target is meant to enforce style standards on all shell scripts.
## it can also help with detecting potential issues as it would fail
## in case the script has any syntaxical errors.

alias shfmt := format-bash

format-bash: _format-bash
    #!/usr/bin/env bash
    targets=($(find . \
        -type f \
        -not -path '*/\.git/*' \
        -exec grep -Il '.' {} \; \
        | xargs -r -P 0 -I {} \
        gawk 'FNR>4 {nextfile} /#!.*sh/ { print FILENAME ; nextfile }' {})) ;
    if [ ${#targets[@]} -ne 0  ];then
        for target in "${targets[@]}";do
            chmod +x "${target}" ;
            shfmt -kp -i 2 -ci -w "${target}" ;
        done
    fi

## [ NOTE ] => this target aggregates and runs
## all targets that are related to formatting.
##
## It is a higher level target which helps
## developers in prettyfying their code in one simple
## instruction.

alias f := format
alias fmt := format

format: format-just format-bash
    @echo format completed

# ─── MISC ───────────────────────────────────────────────────────────────────────
## [ NOTE ] => this target generates a markdown and PDF changelog file.

alias gc := generate-changelog

generate-changelog:
    #!/usr/bin/env bash
    set -euo pipefail
    rm -rf "{{ justfile_directory() }}/tmp"
    mkdir -p "{{ justfile_directory() }}/tmp"
    convco changelog > "{{ justfile_directory() }}/tmp/$(basename {{ justfile_directory() }})-changelog-$(date -u +%Y-%m-%d).md"
    if command -- pandoc -h >/dev/null 2>&1; then
    pandoc \
      --from markdown \
      --pdf-engine=xelatex \
      -o  "{{ justfile_directory() }}/tmp/$(basename {{ justfile_directory() }})-changelog-$(date -u +%Y-%m-%d).pdf" \
      "{{ justfile_directory() }}/tmp/$(basename {{ justfile_directory() }})-changelog-$(date -u +%Y-%m-%d).md"
    fi
    if [ -d /workspace ]; then
      cp -f "{{ justfile_directory() }}/tmp/$(basename {{ justfile_directory() }})-changelog-$(date -u +%Y-%m-%d).pdf" /workspace/
      cp -f "{{ justfile_directory() }}/tmp/$(basename {{ justfile_directory() }})-changelog-$(date -u +%Y-%m-%d).md" /workspace/
    fi

## [ NOTE ] => this target ensures shellcheck
## is available in system PATH; if not it would
## fail with exitcode 1.

_shellcheck:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! shellcheck --version > /dev/null 2>&1 ; then
        echo "*** shellcheck  not found"
        exit 1
    fi

## [ NOTE ] => this target uses `shellcheck` to
## lint all shell scripts.

shellcheck: _shellcheck
    #!/usr/bin/env bash
    set -euox pipefail
    targets=($(find . \
        -type f \
        -not -path '*/\.git/*' \
        -exec grep -Il '.' {} \; \
        | xargs -r -P 0 -I {} \
        gawk 'FNR>4 {nextfile} /#!.*sh/ { print FILENAME ; nextfile }' {})) ;
    if [ ${#targets[@]} -ne 0  ];then
        for target in "${targets[@]}";do
            shellcheck "${target}" || true ;
        done
    fi

## [ NOTE ] => this target takes a `snapshot` of the repository

# # by archiving it as a gzipped tarball file.
snapshot: git-fetch
    #!/usr/bin/env bash
    set -euo pipefail
    sync
    snapshot_dir="{{ justfile_directory() }}/tmp/snapshots"
    mkdir -p "${snapshot_dir}"
    time="$(date +'%Y-%m-%d-%H-%M')"
    path="${snapshot_dir}/${time}.tar.gz"
    tmp="$(mktemp -d)"
    tar -C {{ justfile_directory() }} -cpzf "$tmp/${time}.tar.gz" .
    mv "$tmp/${time}.tar.gz" "$path"
    rm -r "$tmp"
    echo >&2 "*** snapshot created at ${path}"

# ─── GIT ────────────────────────────────────────────────────────────────────────
## [ NOTE ] => This target fetches the latest changes from upstream
## repository.
## It is especially useful for cleaning up local branches after
## a branch was merged with master and deleted.

alias gf := git-fetch

git-fetch:
    #!/usr/bin/env bash
    set -euo pipefail
    pushd "{{ justfile_directory() }}" > /dev/null 2>&1
    git fetch -p ;
    for branch in $(git branch -vv | grep ': gone]' | grep -v '*' | awk '{print $1}'); do
      git branch -D "$branch";
    done
    popd > /dev/null 2>&1

## [ NOTE ] => this variable searches for
## default pager ( used to show output of commands such as `git log` ).
## based on local git config (`~/.gitconfig`).
## In case pager was not set, it is set to `less` as the fallback
## default pager tool.

DIFF_PAGER := `[[ -n $(git config pager.diff ) ]] && echo "$(git config pager.diff)" || echo 'less'`

## [ NOTE ] => this targets is meant to help developers stage changes.
##
## By default, using `git add` can be difficult when you have many
## unchanged files and want to make smaller atomic commits.
##
## This target uses FZF to let developers fuzzy-select files to stage.
## It also shows a preview of the files as the developer goes through
## them.
##
## I recommend using this target for adding files; as it can make Developers
## mindful about their scope of changes; which in turn can help them with
## limiting the scope and making their commit's more atomic which would help
## with the review process.

alias ga := git-add

git-add:
    #!/usr/bin/env bash
    set -euo pipefail
    git rev-parse --is-inside-work-tree > /dev/null || return 1;
    [[ $# -ne 0 ]] && git add "$@" && git status -su && return;
    changed=$(git config --get-color color.status.changed red);
    unmerged=$(git config --get-color color.status.unmerged red);
    untracked=$(git config --get-color color.status.untracked red);
    _FZF_DEFAULT_OPTS="--multi --height=40% --reverse --tabstop=4 -0 --prompt=' │ ' --color=prompt:0,hl:178,hl+:178 --bind='ctrl-t:toggle-all,ctrl-g:select-all+accept' --bind='tab:down,shift-tab:up' --bind='?:toggle-preview,ctrl-space:toggle'
    --ansi
    --height='80%'
    --bind='alt-k:preview-up,alt-p:preview-up'
    --bind='alt-j:preview-down,alt-n:preview-down'
    --bind='ctrl-r:toggle-all'
    --bind='ctrl-s:toggle-sort'
    --bind='?:toggle-preview'
    --bind='alt-w:toggle-preview-wrap'
    --preview-window='right:60%'
    +1"
    extract="
        sed 's/^.*]  //' |
        sed 's/.* -> //' |
        sed -e 's/^\\\"//' -e 's/\\\"\$//'";
    preview="
        file=\$(echo {} | $extract)
        if (git status -s -- \$file | grep '^??') &>/dev/null; then  # diff with /dev/null for untracked files
            git diff --color=always --no-index -- /dev/null \$file | {{ DIFF_PAGER }} | sed '2 s/added:/untracked:/'
        else
            git diff --color=always -- \$file | {{ DIFF_PAGER }}
        fi";
    opts="
        $_FZF_DEFAULT_OPTS
        -0 -m --nth 2..,..
    ";
    files=$(git -c color.status=always -c status.relativePaths=true status -su |
        grep -F -e "$changed" -e "$unmerged" -e "$untracked" |
        sed -E 's/^(..[^[:space:]]*)[[:space:]]+(.*)$/[\1]  \2/' |
        FZF_DEFAULT_OPTS="$opts" fzf --preview="$preview" |
        sh -c "$extract");
    [[ -n "$files" ]] && echo "$files" | tr '\n' '\0' | xargs -0 -I% git add % && git status -su && exit ;
    echo 'Nothing to add.'

## [ NOTE ] => this target installs pre-commit under
## `${HOME}/bin` in case it was not found in default
## system PATH.

# # It is an internal target and not exposed to outside.
_pre-commit:
    #!/usr/bin/env bash
    set -euo pipefail
    IFS=':' read -a paths <<< "$(printenv PATH)" ;
    [[ ! " ${paths[@]} " =~ " ${HOME}/bin " ]] && export PATH="${PATH}:${HOME}/bin" || true ;
    if ! command -- pre-commit -h > /dev/null 2>&1 ; then
        curl "https://pre-commit.com/install-local.py" | "$(command -v python3)" -
    fi

## [ NOTE ] => this target ensures pre-commit is installed
## and available in PATH by having `_pre-commit` target
## as a dependency.
##
## It ensures pre-commit is initialized for the repository
## after the initial git-clone and installs the hooks.
##
## It is meant to run one-time before every commit;
## so that each pre-commit hook would make the auto-fixes (in case any)
## to files.

alias pc := pre-commit

pre-commit: _pre-commit format
    #!/usr/bin/env bash
    set -euo pipefail
    IFS=':' read -a paths <<< "$(printenv PATH)" ;
    [[ ! " ${paths[@]} " =~ " ${HOME}/bin " ]] && export PATH="${PATH}:${HOME}/bin" || true ;
    pushd "{{ justfile_directory() }}" > /dev/null 2>&1
    if [ -r .pre-commit-config.yaml ]; then
      git add ".pre-commit-config.yaml"
      pre-commit install > /dev/null 2>&1
      pre-commit install-hooks
      pre-commit
    fi
    popd > /dev/null 2>&1

## [ NOTE ] => this target is meant to help developers with
## commiting and pushing their code while remaining consistent
## and compliant with pre-commit rules.
##
## I highly recommend using this target ( `just c`) instead
## of `git commit` .
##
## It uses `convco` ( which should be installed after running `just bootstrap`)
## to walk the developers through the process of making a commit
## that is compliant with Conventional Commit spec.
## Keep in mind that one of the pre-commit hooks in this repository
## enforces Conventional Commits and commits that violate this
## standard would be rejected right away.
##
## Before commiting it runs `git-fetch` target which ensures
## branches are in sync with upstream.
##
## It also rung `pre-commit` target which first runs autoformatters
## across the codebase, then runs pre-commit hooks once agains staged changes.
## This :
## - Shows any failing hooks and the issues that the developer has to address
## before being allowed to make a commit.
## - There are pre-commit hooks that make changes to staged files and
## fix violations. Running pre-commit once would  apply those changes so
## it makes it easier for the developer to stage the fixes and then commit them.

alias c := commit

commit: git-fetch pre-commit
    #!/usr/bin/env bash
    set -euo pipefail
    pushd "{{ justfile_directory() }}" > /dev/null 2>&1
    if command -- convco -h > /dev/null 2>&1 ; then
      convco commit
    else
      git commit
    fi
    popd > /dev/null 2>&1

# ─── RELEASE ────────────────────────────────────────────────────────────────────
## [ NOTE ] => this variable is used as release-related target need to know which
## branch holds the master copy of the codebase and in some cases, repositories
## use names that are different from the convention.

MASTER_BRANCH_NAME := 'master'

## [ NOTE ] => this target is used for getting the next major release tag
## following Semantic Versioning specs.
## it uses `convco` to get the next tag; in case there are no git tags
## or for some reason, `convco` was not found in PATH,
## it will fallback to default `0.0.1`.

MAJOR_VERSION := `[[ -n $(git tag -l | head -n 1 ) ]] && convco version --major 2>/dev/null || echo '0.0.1'`

## [ NOTE ] => this target helps with tagging a new major release and
## generating changelogs.
##
## Broadly speaking, it does the following:
## - Ensures local copy of the repo matches the upstream
## by running `git-fetch` target as a dependency.
## - creats and pushes the new major release tag.
## - generate a changelog with the help of `convco`.
## - stages the changelog.
## - makes a Convential Commit and pushes the changelog
## to master.
##
## Keep in mind that the developer running this target
## must be able to tag and push directly to the master branch.

alias mar := major-release

major-release: git-fetch
    #!/usr/bin/env bash
    set -euo pipefail
    IFS=':' read -a paths <<< "$(printenv PATH)" ;
    [[ ! " ${paths[@]} " =~ " ${HOME}/bin " ]] && export PATH="${PATH}:${HOME}/bin" || true;
    pushd "{{ justfile_directory() }}" > /dev/null 2>&1
    git checkout "{{ MASTER_BRANCH_NAME }}"
    git pull
    git tag -a "v{{ MAJOR_VERSION }}" -m 'major release {{ MAJOR_VERSION }}'
    git push origin --tags
    if command -- convco -h > /dev/null 2>&1 ; then
      convco changelog > CHANGELOG.md
      git add CHANGELOG.md
      if command -- pre-commit -h > /dev/null 2>&1 ; then
        pre-commit || true
        git add CHANGELOG.md
      fi
      git commit -m 'docs(changelog): updated changelog for v{{ MAJOR_VERSION }}'
      git push
    fi
    just git-fetch
    popd > /dev/null 2>&1

## [ NOTE ] => this target is used for getting the next minor release tag
## following Semantic Versioning specs.
## it uses `convco` to get the next tag; in case there are no git tags
## or for some reason, `convco` was not found in PATH,
## it will fallback to default `0.0.1`.

MINOR_VERSION := `[[ -n $(git tag -l | head -n 1 ) ]] && convco version --minor 2>/dev/null || echo '0.0.1'`

## [ NOTE ] => this target helps with tagging a new minor release and
## generating changelogs.
##
## Broadly speaking, it does the following:
## - Ensures local copy of the repo matches the upstream
## by running `git-fetch` target as a dependency.
## - creats and pushes the new minor release tag.
## - generate a changelog with the help of `convco`.
## - stages the changelog.
## - makes a Convential Commit and pushes the changelog
## to master.
##
## Keep in mind that the developer running this target
## must be able to tag and push directly to the master branch.

alias mir := minor-release

minor-release: git-fetch
    #!/usr/bin/env bash
    set -euo pipefail
    IFS=':' read -a paths <<< "$(printenv PATH)" ;
    [[ ! " ${paths[@]} " =~ " ${HOME}/bin " ]] && export PATH="${PATH}:${HOME}/bin" || true;
    pushd "{{ justfile_directory() }}" > /dev/null 2>&1
    git checkout "{{ MASTER_BRANCH_NAME }}"
    git pull
    git tag -a "v{{ MINOR_VERSION }}" -m 'minor release {{ MINOR_VERSION }}'
    git push origin --tags
    if command -- convco -h > /dev/null 2>&1 ; then
      convco changelog > CHANGELOG.md
      git add CHANGELOG.md
      if command -- pre-commit -h > /dev/null 2>&1 ; then
        pre-commit || true
        git add CHANGELOG.md
      fi
      git commit -m 'docs(changelog): updated changelog for v{{ MINOR_VERSION }}'
      git push
      just git-fetch
    fi
    popd > /dev/null 2>&1

## [ NOTE ] => this target is used for getting the next patch release tag
## following Semantic Versioning specs.
## it uses `convco` to get the next tag; in case there are no git tags
## or for some reason, `convco` was not found in PATH,
## it will fallback to default `0.0.1`.

PATCH_VERSION := `[[ -n $(git tag -l | head -n 1 ) ]] && convco version --patch 2>/dev/null || echo '0.0.1'`

## [ NOTE ] => this target helps with tagging a new patch release and
## generating changelogs.
##
## Broadly speaking, it does the following:
## - Ensures local copy of the repo matches the upstream
## by running `git-fetch` target as a dependency.
## - creats and pushes the new patch release tag.
## - generate a changelog with the help of `convco`.
## - stages the changelog.
## - makes a Convential Commit and pushes the changelog
## to master.
##
## Keep in mind that the developer running this target
## must be able to tag and push directly to the master branch.

alias pr := patch-release

patch-release: git-fetch
    #!/usr/bin/env bash
    set -euo pipefail
    IFS=':' read -a paths <<< "$(printenv PATH)" ;
    [[ ! " ${paths[@]} " =~ " ${HOME}/bin " ]] && export PATH="${PATH}:${HOME}/bin" || true;
    pushd "{{ justfile_directory() }}" > /dev/null 2>&1
    git checkout "{{ MASTER_BRANCH_NAME }}"
    git pull
    git tag -a "v{{ PATCH_VERSION }}" -m 'patch release {{ PATCH_VERSION }}'
    git push origin --tags
    if command -- convco -h > /dev/null 2>&1 ; then
      convco changelog > CHANGELOG.md
      git add CHANGELOG.md
      if command -- pre-commit -h > /dev/null 2>&1 ; then
        pre-commit || true
        git add CHANGELOG.md
      fi
      git commit -m 'docs(changelog): updated changelog for v{{ MINOR_VERSION }}'
      git push
    fi
    just git-fetch
    popd > /dev/null 2>&1
