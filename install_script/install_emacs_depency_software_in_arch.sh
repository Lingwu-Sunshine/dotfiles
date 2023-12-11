#!/bin/bash
#############################################################
# Install packages for Archlinux or its derived editions (e.g. Manjaro).
# Author: Vincent Zhang <seagle0128@gmail.com>
# URL: https://github.com/seagle0128/dotfiles
#############################################################

# Packages
packages=(
    ctags
    #org-download
    xclip
    #color-rg所用
    ripgrep

    libpoppler
    #更纱字体
    ttc-iosevka

    #eaf 翻译依赖软件
    crow-translate

    #dirvish
    fd poppler ffmpegthumbnailer mediainfo imagemagick tar unzip exa
    #vterm
    cmake libtool-bin
    #emacs-rime: librime(pacman系) 或 librime-dev(apt系)
    librime

    #C/C++
    gcc clangd clang g++ gdb cmake


)

# Use colors, but only if connected to a terminal, and that terminal
# supports them.
if command -v tput >/dev/null 2>&1; then
    ncolors=$(tput colors)
fi
if [ -t 1 ] && [ -n "$ncolors" ] && [ "$ncolors" -ge 8 ]; then
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    BOLD="$(tput bold)"
    NORMAL="$(tput sgr0)"
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    BOLD=""
    NORMAL=""
fi

function check() {
    if ! command -v yay >/dev/null 2>&1 && ! command -v pacman >/dev/null 2>&1; then
        echo "${RED}Error: not Archlinux or its devrived edition.${NORMAL}" >&2
        exit 1
    fi
}

function install() {
    CMD=''
    if command -v yay >/dev/null 2>&1; then
        # CMD='yay -Ssu --noconfirm'
        CMD='yay -S --noconfirm' #进行安装软件
    elif command -v pacman >/dev/null 2>&1; then
        # CMD='sudo pacman -Ssu --noconfirm'
        CMD='sudo pacman -S --noconfirm' #进行安装软件
    else
        echo "${RED}Error: not Archlinux or its devrived edition.${NORMAL}" >&2
        exit 1
    fi

    for p in ${packages[@]}; do
        printf "\n${BLUE}➜ Installing ${p}...${NORMAL}\n"
        ${CMD} ${p}
    done
}

function main() {
    check
    install
}

main
