# Use bash for nicer scripting
SHELL := /usr/bin/env bash
PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
INSTALL := $(PROJECT_ROOT)/scripts/install.sh
UNINSTALL := $(PROJECT_ROOT)/scripts/uninstall.sh
SERVICE := keyboard-layout-autoswitch.service
UNIT_PATH := $(HOME)/.config/systemd/user/$(SERVICE)
CONF_DIR := $(if $(XDG_CONFIG_HOME),$(XDG_CONFIG_HOME),$(HOME)/.config)/kb-autoswitch
CONF_FILE := $(CONF_DIR)/config.env

.PHONY: help install uninstall status logs restart enable disable detect config-show check

help:
	@echo "Targets:"
	@echo "  make install       - run installer (prompts for devices/layouts)"
	@echo "  make uninstall     - stop & disable service, remove files"
	@echo "  make status        - show service status"
	@echo "  make logs          - tail service logs"
	@echo "  make restart       - restart service"
	@echo "  make enable        - enable & start service"
	@echo "  make disable       - disable & stop service"
	@echo "  make detect        - list keyboard-like devices"
	@echo "  make config-show   - print current config file"
	@echo "  make check         - check dependencies and GNOME availability"

install:
	@bash "$(INSTALL)"

uninstall:
	@bash "$(UNINSTALL)"

status:
	@systemctl --user status "$(SERVICE)" || true

logs:
	@journalctl --user -u "$(SERVICE)" -f

restart:
	@systemctl --user restart "$(SERVICE)" || (echo "Service not installed? Try: make install" && false)

enable:
	@systemctl --user enable --now "$(SERVICE)"

disable:
	@systemctl --user disable --now "$(SERVICE)" || true

detect:
	@bash scripts/detect-devices.sh

config-show:
	@if [[ -f "$(CONF_FILE)" ]]; then cat "$(CONF_FILE)"; else echo "No config at $(CONF_FILE). Run: make install"; fi

check:
	@echo "Checking dependencies..."
	@command -v gawk >/dev/null 2>&1 && echo "  gawk: OK" || echo "  gawk: MISSING"
	@command -v libinput >/dev/null 2>&1 && echo "  libinput: OK" || echo "  libinput: MISSING (package: libinput-tools)"
	@command -v python3 >/dev/null 2>&1 && echo "  python3: OK" || echo "  python3: MISSING"
	@gsettings get org.gnome.desktop.input-sources sources >/dev/null 2>&1 && echo "  gsettings: OK (GNOME)" || echo "  gsettings: NOT AVAILABLE (Need GNOME)"
	@echo "Config file: $(CONF_FILE)"
	@[[ -f "$(CONF_FILE)" ]] || echo "  (run 'make install' to create it)"
