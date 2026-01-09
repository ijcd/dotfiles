#!/bin/sh
# Make all scripts in ~/.local/bin executable after chezmoi apply
chmod +x ~/.local/bin/* 2>/dev/null || true
