# syntax = docker/dockerfile:1.3-labs
# vim: filetype=dockerfile softtabstop=2 tabstop=2 shiftwidth=2 fenc=utf-8 fileformat=unix expandtab
# hadolint ignore=DL3007
FROM fjolsvin/convco:latest AS convco
# hadolint ignore=DL3007
FROM fjolsvin/jsonfmt:latest AS jsonfmt
# hadolint ignore=DL3007
FROM fjolsvin/helix:latest AS helix
FROM alpine:edge
# ────────────────────────────────────────────────────────────────────────────────
SHELL ["/bin/ash", "-o", "pipefail", "-c"]
# ────────────────────────────────────────────────────────────────────────────────
USER root
ENV TERM xterm
RUN \
  ( \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" ; \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" ; \
  echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" ; \
  echo "http://dl-cdn.alpinelinux.org/alpine/v3.14/main" ; \
  echo "http://dl-cdn.alpinelinux.org/alpine/v3.14/community" ; \
  echo "http://dl-cdn.alpinelinux.org/alpine/v3.13/main" ; \
  echo "http://dl-cdn.alpinelinux.org/alpine/v3.13/community" ; \
  ) | tee /etc/apk/repositories > /dev/null  \
  && apk add --no-cache "bash~=5" "ca-certificates~=20191127"
# ────────────────────────────────────────────────────────────────────────────────
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# ────────────────────────────────────────────────────────────────────────────────
RUN  \
  apk add --no-cache \
    tokei~=12 \
    starship~=1 \
    fd~=8 \
    ripgrep~=13 \
    ripgrep-bash-completion~=13 \
    delta~=0 \
    exa~=0 \
    bat~=0 \
    fzf~=0 \
    fzf-bash-completion~=0 \
    glow~=1 \
    rcm~=1 \
    nerd-fonts~=2 \
    npm~=14 \
    yarn~=1 \
    acl~=2 \
    docker~=20 \
    docker-compose~=1 \
    mkfontscale~=1 \
    ncurses~=6 \
    ncurses-dev~=6 \
    ncurses-static~=6 \
    sudo~=1 \
    curl~=7 \
    jq~=1 \
    python3~=3 \
    py3-pip~=20 \
    py3-setuptools~=52 \
    py3-wheel~=0 \
    coreutils~=9 \
    findutils~=4 \
    moreutils~=0 \
    unzip~=6 \
    consul~=1 \
    libcap~=2 \
    vault~=1 \
    alpine-sdk~=1 \
    make~=4 \
    musl-dev~=1 \
    go~=1 \
    just~=0 \
    bash-completion~=2 \
    git~=2 \
    openssl~=1
# ─── CREATE VSCODE USER ─────────────────────────────────────────────────────────
USER "root"
ARG UID="1000"
ARG USER="vscode"
ENV USER ${USER}
ENV HOME="/home/${USER}"
ENV SHELL="/bin/bash"
RUN adduser \
    --disabled-password \
    --home "${HOME}" \
    --uid ${UID} \
    --shell "${SHELL}" \
    ${USER} \
    && echo "${USER}:${USER}" | chpasswd

# ────────────────────────────────────────────────────────────────────────────────
# this ensures vscode user can switch to su without password
USER "root"
RUN \
    adduser "${USER}" wheel \
    && addgroup sudo > /dev/null 2>&1 || true ; adduser "${USER}" sudo \
    && addgroup vault > /dev/null 2>&1 || true ; adduser "${USER}" vault \
    && addgroup consul > /dev/null 2>&1 || true ; adduser "${USER}" consul \
    && addgroup docker > /dev/null 2>&1 || true ; adduser "${USER}" docker \
    && echo "${USER} ALL=(ALL) NOPASSWD: ALL" >> "/etc/sudoers" \
    && visudo --check > /dev/null 2>&1
# ─── INSTALL TERRAFORM ──────────────────────────────────────────────────────────
WORKDIR /tmp
ARG TERRAFORM_VERSION=1.1.2
RUN curl -O -L \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"  && \
  # Unzip
  unzip "terraform_${TERRAFORM_VERSION}_linux_amd64.zip" && \
  # Move to local bin
  mv "terraform" "/usr/local/bin/" && \
  # Make it executable
  chmod +x "/usr/local/bin/terraform" && \
  # Check that it's installed
  terraform --version && \
  # cleanup
  rm -rf /tmp/terraform*
# ─── INSTALL TFLINT ─────────────────────────────────────────────────────────────
USER "root"
RUN \
    curl -s "https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh" | bash \
    && tflint --version 
# ─── INSTALL GO TOOLCHAIN ───────────────────────────────────────────────────────
USER "root"
#  ──── GOLANG SETUP ─────────────────────────────────────────────────
USER root
ENV PATH /usr/local/go/bin:$PATH
ARG GOLANG_VERSION="1.17"
RUN \
  apkArch="$(apk --print-arch)"; \
  case "$apkArch" in \
    'x86_64') \
      export GOARCH='amd64' GOOS='linux'; \
      ;; \
    'aarch64') \
      export GOARCH='arm64' GOOS='linux'; \
      ;; \
    *) exit 1 ;; \
  esac; \
  apk add --no-cache --virtual .build-deps \
    bash \
    gcc \
    gnupg \
    go \
    musl-dev \
    openssl \
  && wget -qO "/tmp/go.tgz" "https://dl.google.com/go/go${GOLANG_VERSION}.src.tar.gz" \
  && tar -C /usr/local -xzf /tmp/go.tgz \
  && rm /tmp/go.tgz \
  && ( \
    cd /usr/local/go/src; \
    export GOROOT_BOOTSTRAP="$(go env GOROOT)" GOHOSTOS="$GOOS" GOHOSTARCH="$GOARCH"; \
    ./make.bash; \
  ) \
  && go install -race std \
  && apk del --no-network .build-deps \
  && go version
ENV GOPATH="/go"
ENV PATH="${GOPATH}/bin:${PATH}"
RUN \
  mkdir -p \
    "${GOPATH}/src" \
    "${GOPATH}/bin" \
  && chmod -R 777 "${GOPATH}" \
  && chown -R "$(id -u ${USER}):$(id -g ${USER})" "${GOPATH}"
# ─── INSTALL TERRASCAN ──────────────────────────────────────────────────────────
USER "root"
RUN \
  rm -rf "/tmp/terrascan" \
  && git clone "https://github.com/accurics/terrascan" "/tmp/terrascan" \
  && make -C "/tmp/terrascan" build \
  && mv -f "/tmp/terrascan/bin/terrascan" "/usr/local/bin/terrascan" \
  && terrascan version \
  && rm -rf "/tmp/terrascan" \
  && chown -R "$(id -u ${USER}):$(id -g ${USER})" "${GOPATH}"
USER "${USER}"
RUN \
  terrascan init
# ─── INSTALL TFSEC ──────────────────────────────────────────────────────────────
USER "${USER}"
RUN \
    go install github.com/aquasecurity/tfsec/cmd/tfsec@latest \
    && tfsec --version 
# ─── INSTALL PRE COMMIT AND CHECKOV ─────────────────────────────────────────────
USER "root"
RUN \
  apk add --no-cache \
    util-linux~=2 \
    libffi-dev~=3 \
    python3-dev~=3 \
    py3-cffi~=1 \
    gcc~=11 \
    py3-pip~=21 \
    py3-cryptography~=3
# ────────────────────────────────────────────────────────────────────────────────
ENV PATH="${PATH}:${HOME}/.local/bin"
USER "${USER}"
RUN \
  python3 -m pip install --no-cache-dir \
    pre-commit=="2.16.0" \
    checkov=="2.0.693" \
  && pre-commit -h \
  && checkov -h
# ─── USER DOTFILES ──────────────────────────────────────────────────────────────
USER "${USER}"
ENV EDITOR="hx"
ENV VISUAL="hx"
ENV PATH="${PATH}:/usr/local/bin"
ENV COLORTERM="truecolor"
# using ~ for $HOME here returns permission denied error
RUN \
  go env -w "GO111MODULE=on" \
  && go env -w "CGO_ENABLED=0" \
  && go env -w "CGO_LDFLAGS=-s -w -extldflags '-static'" \
  && git clone "https://github.com/wfxr/forgit" "${HOME}/.forgit" \
  && git clone https://github.com/bigH/git-fuzzy "${HOME}/.git-fuzzy" \
  && chmod a+x ${HOME}/.git-fuzzy/bin/* \
  && mkdir -p "${HOME}/.ssh" \
  && touch "${HOME}/.ssh/config" \
  && git clone "https://github.com/da-moon/.dotfiles.git" "${HOME}/.dotfiles" \
  && rcup -f ; \
  echo '[ -r "/var/run/docker.sock" ] && sudo setfacl -m "$(id -u "${USER}")":rw "/var/run/docker.sock";' >> "${HOME}/.profile" \
  && echo '[ -r "${HOME}/.bashrc" ] && . "${HOME}/.bashrc"' >> "${HOME}/.profile" ; \
  echo "#!/usr/bin/env bash" > "${HOME}/.environment" ; \
  [ -d "${HOME}/.env.d" ] && while read -r i; do \
  sed -e '/^\s*#/d' "$i" | tee -a "${HOME}/.environment" > /dev/null \
  && printf "\n" >> "${HOME}/.environment" ; \
  done < <(find "${HOME}/.env.d/" -name '*.sh') ; \
  echo "#!/usr/bin/env bash" > "${HOME}/.bash_functions" ; \
  [ -d "${HOME}/.profile.d" ] && while read -r i; do \
  sed -e '/^\s*#/d' "$i" | tee -a "${HOME}/.bash_functions" > /dev/null \
  && printf "\n" >> "${HOME}/.bash_functions" ; \
  done < <(find "${HOME}/.profile.d/" -name '*.sh') ; \
  echo "#!/usr/bin/env bash" > "${HOME}/.bash_aliases" ; \
  [ -d "${HOME}/.alias.d" ] && while read -r i; do \
  sed -e '/^\s*#/d' "$i" | tee -a "${HOME}/.bash_aliases" > /dev/null \
  && printf "\n" >> "${HOME}/.bash_aliases" ; \
  done < <(find "${HOME}/.alias.d/" -name '*.sh') ;
# ────────────────────────────────────────────────────────────────────────────────
COPY --chmod=0755 --from=jsonfmt /workspace /usr/local/bin
COPY --chmod=0755 --from=convco /workspace /usr/local/bin
COPY --chmod=0755 --from=helix /workspace/hx /usr/local/bin/hx
VOLUME "/var/run/docker.sock"
# ────────────────────────────────────────────────────────────────────────────────
USER root
RUN \
  convco -h \
  && jsonfmt -h \
  && hx -h \
  && setcap cap_ipc_lock= "/usr/sbin/vault" \
  && chown -R "$(id -u "${USER}"):$(id -g "${USER}")" "${HOME}" \
  && yarn cache clean --all \
  && npm -g cache clean --force > /dev/null 2>&1 \
  && rm -rf \
    "${HOME}/.cache/go-build" \
    /tmp/* \
    /usr/src \
    /usr/local/go/pkg/*/cmd \
    /usr/local/go/pkg/bootstrap \
    /usr/local/go/pkg/obj \
    /usr/local/go/pkg/tool/*/api \
    /usr/local/go/pkg/tool/*/go_bootstrap \
    /usr/local/go/src/cmd/dist/dist
# ────────────────────────────────────────────────────────────────────────────────
USER "${USER}"
ARG WORKDIR="/workspace"
ENV WORKDIR "${WORKDIR}"
WORKDIR "${WORKDIR}"
ENTRYPOINT [ "/bin/bash" ]