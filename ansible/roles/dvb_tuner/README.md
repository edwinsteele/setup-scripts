# dvb_tuner

Loads the DVB-USB kernel driver stack needed for the Elgato EyeTV
Diversity (USB `0fd9:0011`, a dual DVB-T tuner) to work at all on
Rocky/RHEL 9. **This role does not build the driver** - see below for why -
it only checks the build exists for the running kernel, loads it, and
persists that across reboots. Building it is a manual, one-time-per-kernel
step, documented here.

## Why this is needed, and why it's manual

Rocky/RHEL 9's kernel ships **zero DVB drivers** - not just this specific
tuner's, none at all. `kernel-modules-core` only carries webcam-class V4L
drivers (`uvc`, `gspca`, `cx231xx`, ...); there's no `dvb-core`, no
`dvb-frontends`. This isn't Rocky-specific breakage, it's a deliberate
RHEL-family scoping decision.

The obvious fix - LinuxTV's `media_build` project, historically the
standard way to build DVB drivers out-of-tree - is **officially
unmaintained upstream** ("the decision was made to stop maintaining this,"
per its own README as of 2026). Its old GitHub mirrors self-update
themselves against the dead canonical repo and end up broken.

So the actual fix is building the driver source directly, hand-patched for
RHEL's headers. That patching is inherently tied to a specific kernel
snapshot - RHEL labels its kernel "5.14," but backports large amounts of
newer upstream kernel-internals work onto that frozen ABI version for
subsystems it actually ships. DVB was never one of those, so the driver
source is stuck at genuine v5.14-era APIs while everything around it moves
on. **A future kernel bump (e.g. Rocky 9.8 -> 9.9) may need different
patches than the ones below**, since RHEL may have backported more by
then. An earlier version of this role vendored a fully patched source tree
into the repo; that was reverted in favour of documenting the method here,
since a stale vendored tree for the wrong kernel is worse than no tree at
all - it invites re-running something that looks automated but silently
builds against wrong assumptions.

## Build recipe

Run this on the target host (root or sudo) whenever `dvb_core.ko` etc.
don't exist yet for the running kernel (this role's checks will tell you
if so).

**1. Prerequisites:**
```
dnf install -y kernel-devel gcc make
```
`kernel-devel`'s version MUST exactly match `uname -r` - if not, `dnf
update && reboot` first.

**2. Fetch source, pinned to the `v5.14` tag** (matches the vintage RHEL's
headers were originally derived from - not `master`, which is too new and
breaks differently):
```
git clone --filter=blob:none --no-checkout --depth=1 --branch v5.14 \
  https://github.com/torvalds/linux.git linux-dvb-src
cd linux-dvb-src
git sparse-checkout init --cone
git sparse-checkout set drivers/media/dvb-core drivers/media/usb/dvb-usb \
  drivers/media/dvb-frontends drivers/media/tuners include/media
git checkout v5.14
```

**3. Copy into one flat build directory** (no subdirectories - everything
uses quoted `#include "x.h"` for siblings):
- `drivers/media/dvb-core/*.c` **except** `dvb_net.c` and `dvb_vb2.c` -
  both are optional (IP-over-broadcast net interface; zero-copy mmap
  streaming) and had diverged too far from RHEL's headers to patch cheaply
  the last time this was done. Plain `read()`-based streaming doesn't need
  either.
- `drivers/media/usb/dvb-usb/{dib0700_core,dib0700_devices,dvb-usb-dvb,
  dvb-usb-firmware,dvb-usb-i2c,dvb-usb-init,dvb-usb-remote,usb-urb}.c` +
  `{dib0700,dib07x0,dvb-usb,dvb-usb-common}.h`
- `drivers/media/dvb-frontends/{dib7000p,dib0070,dibx000_common}.c` + their
  `.h`, **plus** the `.h` only (no `.c`) for every *other* chip
  `dib0700_devices.c` references in its combined ~26-device table -
  `dib3000mc dib7000m dib8000 dib9000 mt2060 mt2266 mxl5007t s5h1411
  lgdt3305 mn88472 tda18250 dib0090` (from `dvb-frontends/`) +
  `mt2060 mt2266 xc5000 xc4000 mxl5007t tda18250` (from `tuners/`) +
  `tuner-xc2028.h`/`tuner-xc2028-types.h` (**not** `xc2028.h` - the
  filename changed upstream at some point; check the actual
  `dib0700_devices.c` you're compiling for its real `#include` lines
  rather than trusting a separately-fetched reference copy) + `dvb-pll.h`.
  These headers only need to exist for the file to compile - their own
  built-in `#if IS_REACHABLE(CONFIG_X) / real decl / #else / static inline
  no-op / #endif` stubs satisfy the linker for chips we don't build real
  drivers for (see the `-D` flags in the Makefile below).
- `include/media/dvb_math.h` -> a local `media/` subdirectory (not flat),
  so `#include <media/dvb_math.h>` resolves via `-I$(src)`. **Don't
  actually build `dvb_math.c`** - `intlog2`/`intlog10`, its only two
  symbols, are already exported by `vmlinux` on this kernel; building it
  too causes a "exported twice" modpost error.

**4. Makefile:**
```makefile
obj-m += dvb-core.o
dvb-core-objs := dvbdev.o dmxdev.o dvb_demux.o dvb_ca_en50221.o dvb_frontend.o dvb_ringbuffer.o

obj-m += dvb-usb.o
dvb-usb-objs := dvb-usb-firmware.o dvb-usb-init.o dvb-usb-urb.o dvb-usb-i2c.o dvb-usb-dvb.o dvb-usb-remote.o usb-urb.o

obj-m += dvb-usb-dib0700.o
dvb-usb-dib0700-objs := dib0700_core.o dib0700_devices.o

obj-m += dibx000_common.o
obj-m += dib7000p.o
obj-m += dib0070.o

ccflags-y += -I$(src) -DCONFIG_DVB_DIB7000P=1 -DCONFIG_DVB_TUNER_DIB0070=1

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules
install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install
	depmod -a
clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
```
The two `-DCONFIG_...=1` flags force the *real* declaration path in
`dib7000p.h`/`dib0070.h` (the only two chips actually built); every other
chip header's config symbol is left undefined, so it falls through to its
own safe no-op stub instead - this is what avoids needing all ~15 other
chips' full driver source.

**5. Patches, if the build fails** (each one was a real compile/link
error the last time this was done - fix by iterating build -> read error
-> patch -> rebuild, don't apply these blind if the errors you actually
hit are different):

- `class_create(THIS_MODULE, "dvb")` -> `class_create("dvb")`, and
  `dvb_uevent`/`dvb_devnode` in `dvbdev.c` gaining `const struct device *`
  - RHEL's headers have a newer `class_create()`/device-callback API than
    v5.14.
- `from_timer(` -> `timer_container_of(` in `dmxdev.c` - renamed upstream,
  RHEL has the rename.
- `USB_PID_*` macro renames in `dib0700_devices.c`'s device table -
  RHEL's `include/media/dvb-usb-ids.h` has renamed several since v5.14;
  GCC's "did you mean" suggestions usually give the new names directly.
- rc-core (IR remote) support stripped: `rc-core.ko` isn't shipped by RHEL
  either. In `dvb-usb-remote.c`, gut `rc_core_dvb_usb_remote_init()` to
  `return 0;` and remove the `rc_unregister_device()` call in
  `dvb_usb_remote_exit()`'s else-branch. In `dib0700_core.c` and
  `dib0700_devices.c`, add `#define rc_repeat(dev) do {} while (0)` and
  `#define rc_keydown(dev, protocol, scancode, toggle) do {} while (0)`
  right after their `#include`s (must be macros, not `static` function
  redefinitions - the real `rc-core.h` declarations are already in scope
  via `dvb-usb.h`, so `static` conflicts on linkage). Physical IR remote
  buttons on the tuner won't work; tuning/recording is unaffected.

**6. Build and install:**
```
make
sudo make install    # modules_install + depmod -a
```
Module signing will fail/skip harmlessly (no signing key configured) -
unsigned modules load fine since Secure Boot/lockdown isn't enforcing on
this host.

**7. Re-run this ansible role** (or just `modprobe` the modules listed in
`defaults/main.yml` directly) to load them and persist across reboots.

## Verifying it worked

```
ls /dev/dvb/adapter0 /dev/dvb/adapter1   # each should show demux0 dvr0 frontend0
dvbv5-scan -a 0 <scanfile>                # confirms actual signal lock, not just driver load
```

`v4l-utils` (for `dvbv5-scan`) isn't in Rocky's default repos either -
it's in CRB (`dnf config-manager --set-enabled crb`), and doesn't bundle
scan-table files - fetch a channel list from
[tvheadend/dtv-scan-tables](https://github.com/tvheadend/dtv-scan-tables)
(e.g. `dvb-t/au-ALL` for Australia) if you need one for manual testing.
