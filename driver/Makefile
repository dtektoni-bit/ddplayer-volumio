# SPDX-License-Identifier: GPL-2.0-only
#
# Makefile for ddplayer DAC out-of-tree kernel module
#

obj-m += snd-soc-ddplayer-dac.o
snd-soc-ddplayer-dac-objs := ddplayer_dac.o

# DT overlay
dtbo-y += ddplayer-dac.dtbo

KDIR ?= /lib/modules/$(shell uname -r)/build
ARCH ?= arm64
CROSS_COMPILE ?=

# DTC flags for overlay compilation
DTC ?= dtc
DTC_FLAGS := -@ -I dts -O dtb -W no-unit_address_vs_reg

.PHONY: all module dt clean install help

all: module dt

module:
	$(MAKE) -C $(KDIR) M=$(CURDIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules

dt: ddplayer-dac.dtbo

%.dtbo: %.dts
	$(DTC) $(DTC_FLAGS) -o $@ $<

clean:
	$(MAKE) -C $(KDIR) M=$(CURDIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) clean
	rm -f *.dtbo

install: module dt
	$(MAKE) -C $(KDIR) M=$(CURDIR) ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) modules_install
	@# Bookworm uses /boot/firmware/overlays, older OS uses /boot/overlays
	@if [ -d "$(DESTDIR)/boot/firmware/overlays" ]; then \
		install -D -m 0644 ddplayer-dac.dtbo $(DESTDIR)/boot/firmware/overlays/ddplayer-dac.dtbo; \
	else \
		install -D -m 0644 ddplayer-dac.dtbo $(DESTDIR)/boot/overlays/ddplayer-dac.dtbo; \
	fi
	depmod -a

help:
	@echo "Targets:"
	@echo "  all      - Build module and device tree overlay"
	@echo "  module   - Build kernel module only"
	@echo "  dt       - Build device tree overlay only"
	@echo "  clean    - Remove build artifacts"
	@echo "  install  - Install module and overlay (run as root)"
	@echo ""
	@echo "Variables:"
	@echo "  KDIR           - Kernel build directory (default: /lib/modules/$$(uname -r)/build)"
	@echo "  ARCH           - Target architecture (default: arm64)"
	@echo "  CROSS_COMPILE  - Cross compiler prefix (default: empty)"
