VERSION ?= 0.0.3
DIST_DIR ?= dist
TARGET = netbsd-10.1-mac68k
TCL805_INSTALLER ?= packaging/windows98/runtime/tcl805.exe
WINDOWS_AMD64_RUNTIME ?= packaging/windows-amd64/runtime/tcltk86-win10-amd64.tgz
LINUX_AMD64_RUNTIME ?= packaging/linux-amd64/runtime/tcltk86-bookworm-amd64.deb
MACOS_AMD64_RUNTIME ?= packaging/macos/runtime/tcltk9-macos-universal.tgz
CLASSIC_MAC_TOOLCHAIN ?= packaging/classic-mac/toolchain/TclTk_8.3.4_FullInstall.bin
NETBSD_M68K_RUNTIME_PACKAGES = \
	packaging/netbsd/runtime/brotli-1.1.0.tgz \
	packaging/netbsd/runtime/fontconfig-2.15.0.tgz \
	packaging/netbsd/runtime/freetype2-2.13.3.tgz \
	packaging/netbsd/runtime/libXft-2.3.9.tgz \
	packaging/netbsd/runtime/png-1.6.49.tgz \
	packaging/netbsd/runtime/sqlite3-3.49.2.tgz \
	packaging/netbsd/runtime/tcl-8.6.16nb2.tgz \
	packaging/netbsd/runtime/tk-8.6.16.tgz

.PHONY: all installers icons macos-installer macos-amd64-runtime macos-amd64-installer netbsd-mac68k netbsd-mac68k-installer client-netbsd-mac68k server-netbsd-mac68k windows95-installer windows95-installer-iso windows-amd64-installer windows-amd64-installer-iso linux-amd64-installer-iso windows98-test-kit windows98-test-iso classic-mac-wrapper-inputs classic-mac-68k-installer classic-mac-ppc-installer classic-mac-installers test clean

all: netbsd-mac68k

installers: macos-installer macos-amd64-installer windows95-installer windows-amd64-installer linux-amd64-installer-iso netbsd-mac68k-installer classic-mac-installers

icons:
	sh packaging/icons/build.sh

macos-installer: icons
	VERSION=$(VERSION) DIST_DIR=$(DIST_DIR) sh packaging/macos/build.sh

macos-amd64-runtime:
	@test -f "$(MACOS_AMD64_RUNTIME)" || sh packaging/macos/build-x86-runtime.sh "$(MACOS_AMD64_RUNTIME)"

macos-amd64-installer: icons macos-amd64-runtime
	VERSION=$(VERSION) DIST_DIR=$(DIST_DIR) MACOS_ARCH=x86_64 MACOS_OUTPUT_ARCH=amd64 MACOS_DEPLOYMENT_TARGET=10.13 MACOS_RUNTIME_ARCHIVE="$(abspath $(MACOS_AMD64_RUNTIME))" sh packaging/macos/build.sh
netbsd-mac68k: client-netbsd-mac68k server-netbsd-mac68k
client-netbsd-mac68k: $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET).tar.gz
server-netbsd-mac68k: $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET).tar.gz

windows98-test-kit: $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit.zip

windows98-test-iso: windows98-test-kit
	@test -f "$(TCL805_INSTALLER)" || { echo "Set TCL805_INSTALLER to the downloaded tcl805.exe path" >&2; exit 1; }
	rm -rf $(DIST_DIR)/retrochat-windows98-cd
	mkdir -p $(DIST_DIR)/retrochat-windows98-cd
	cp "$(TCL805_INSTALLER)" $(DIST_DIR)/retrochat-windows98-cd/tcl805.exe
	cp -R $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit $(DIST_DIR)/retrochat-windows98-cd/RETROCHAT
	rm -f $(DIST_DIR)/retrochat-$(VERSION)-windows98-test.iso
	hdiutil makehybrid -iso -joliet -o $(DIST_DIR)/retrochat-$(VERSION)-windows98-test.iso $(DIST_DIR)/retrochat-windows98-cd

windows95-installer: icons
	@test -f "$(TCL805_INSTALLER)" || { echo "Set TCL805_INSTALLER to the downloaded tcl805.exe path" >&2; exit 1; }
	@command -v makensis >/dev/null 2>&1 || { echo "Windows 95/98 setup build requires makensis" >&2; exit 1; }
	mkdir -p $(DIST_DIR)
	DIST_DIR=$(DIST_DIR) sh packaging/windows98/build-launchers.sh
	VERSION=$(VERSION) DIST_DIR=$(DIST_DIR) TCL805_INSTALLER="$(abspath $(TCL805_INSTALLER))" sh packaging/windows/build-msi.sh i386
	makensis -DVERSION=$(VERSION) -DTCL805_INSTALLER="$(abspath $(TCL805_INSTALLER))" packaging/windows98/RetroChat.nsi
	rm -f $(DIST_DIR)/RetroChat-client.exe $(DIST_DIR)/RetroChat-server.exe

windows95-installer-iso: windows95-installer
	rm -rf $(DIST_DIR)/retrochat-windows95-plus-installer-cd
	mkdir -p $(DIST_DIR)/retrochat-windows95-plus-installer-cd
	cp $(DIST_DIR)/retrochat-$(VERSION)-windows-i386.msi $(DIST_DIR)/retrochat-windows95-plus-installer-cd/RETROCHAT.MSI
	cp "$(TCL805_INSTALLER)" $(DIST_DIR)/retrochat-windows95-plus-installer-cd/TCL805.EXE
	sh packaging/normalize-text.sh crlf LICENSE $(DIST_DIR)/retrochat-windows95-plus-installer-cd/LICENSE.TXT
	rm -f $(DIST_DIR)/retrochat-$(VERSION)-windows-i386.iso
	hdiutil makehybrid -iso -joliet -o $(DIST_DIR)/retrochat-$(VERSION)-windows-i386.iso $(DIST_DIR)/retrochat-windows95-plus-installer-cd
	rm -rf $(DIST_DIR)/retrochat-windows95-plus-installer-cd
	rm -f $(DIST_DIR)/RetroChat-client.exe $(DIST_DIR)/RetroChat-server.exe

windows-amd64-installer: icons
	@test -f "$(WINDOWS_AMD64_RUNTIME)" || { echo "Missing $(WINDOWS_AMD64_RUNTIME)" >&2; exit 1; }
	VERSION=$(VERSION) DIST_DIR=$(DIST_DIR) WINDOWS_AMD64_RUNTIME="$(abspath $(WINDOWS_AMD64_RUNTIME))" sh packaging/windows-amd64/build.sh
	rm -rf $(DIST_DIR)/windows-amd64-runtime
	rm -f $(DIST_DIR)/RetroChat-amd64-client.exe $(DIST_DIR)/RetroChat-amd64-server.exe

windows-amd64-installer-iso: windows-amd64-installer
	rm -rf $(DIST_DIR)/retrochat-windows-amd64-cd
	mkdir -p $(DIST_DIR)/retrochat-windows-amd64-cd
	cp $(DIST_DIR)/retrochat-$(VERSION)-windows-amd64.msi $(DIST_DIR)/retrochat-windows-amd64-cd/RETROCHAT.MSI
	sh packaging/normalize-text.sh crlf packaging/windows-amd64/README.txt $(DIST_DIR)/retrochat-windows-amd64-cd/README.TXT
	sh packaging/normalize-text.sh crlf LICENSE $(DIST_DIR)/retrochat-windows-amd64-cd/LICENSE.TXT
	rm -f $(DIST_DIR)/retrochat-$(VERSION)-windows-amd64.iso
	hdiutil makehybrid -iso -joliet -o $(DIST_DIR)/retrochat-$(VERSION)-windows-amd64.iso $(DIST_DIR)/retrochat-windows-amd64-cd
	rm -rf $(DIST_DIR)/retrochat-windows-amd64-cd $(DIST_DIR)/windows-amd64-runtime
	rm -f $(DIST_DIR)/RetroChat-amd64-client.exe $(DIST_DIR)/RetroChat-amd64-server.exe

linux-amd64-installer-iso: icons
	@test -f "$(LINUX_AMD64_RUNTIME)" || { echo "Missing $(LINUX_AMD64_RUNTIME)" >&2; exit 1; }
	VERSION=$(VERSION) DIST_DIR=$(DIST_DIR) LINUX_AMD64_RUNTIME="$(abspath $(LINUX_AMD64_RUNTIME))" sh packaging/linux-amd64/build.sh

netbsd-mac68k-installer: netbsd-mac68k packaging/netbsd/install.sh packaging/netbsd/retrochat-client.in packaging/netbsd/retrochat-server.in $(NETBSD_M68K_RUNTIME_PACKAGES)
	rm -rf $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer
	mkdir -p $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer
	cp $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET).tar.gz $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/CLIENT.TGZ
	cp $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET).tar.gz $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/SERVER.TGZ
	sh packaging/normalize-text.sh lf packaging/netbsd/INSTALL.txt $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/INSTALL.txt
	sed 's/@VERSION@/$(VERSION)/g' packaging/netbsd/install.sh > $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/INSTALL.SH
	cp packaging/netbsd/retrochat-client.in $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/CLIENT.IN
	cp packaging/netbsd/retrochat-server.in $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/SERVER.IN
	COPYFILE_DISABLE=1 tar --no-xattrs -C packaging/netbsd/runtime -czf $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/RUNTIME.TGZ $(notdir $(NETBSD_M68K_RUNTIME_PACKAGES))
	chmod 755 $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/INSTALL.SH
	sh packaging/normalize-text.sh lf LICENSE $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/LICENSE.txt
	rm -f $(DIST_DIR)/retrochat-$(VERSION)-netbsd-mac68k.iso
	hdiutil makehybrid -iso -joliet -o $(DIST_DIR)/retrochat-$(VERSION)-netbsd-mac68k.iso $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer
	rm -rf $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET) $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)
	rm -f $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET).tar.gz $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET).tar.gz

classic-mac-68k-installer: icons
	VERSION=$(VERSION) DIST_DIR=$(DIST_DIR) sh packaging/classic-mac/build-68k.sh

classic-mac-ppc-installer: icons
	VERSION=$(VERSION) DIST_DIR=$(DIST_DIR) sh packaging/classic-mac/build-ppc.sh

classic-mac-installers: classic-mac-68k-installer classic-mac-ppc-installer

classic-mac-wrapper-inputs:
	sh packaging/classic-mac/prepare-wrappers.sh

$(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit.zip: client.tcl server.tcl server-gui.tcl lib/protocol.tcl LICENSE tests/platform.test tests/protocol.test tests/relay.test assets/icons/png/client/client-tray.gif assets/icons/png/server/server-tray.gif assets/icons/windows/client.ico assets/icons/windows/server.ico packaging/windows98/README.txt
	rm -rf $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit
	mkdir -p $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/lib
	mkdir -p $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/tests
	cp client.tcl server.tcl server-gui.tcl $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/
	mkdir -p $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/assets/icons/png/client
	mkdir -p $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/assets/icons/png/server
	cp assets/icons/png/client/client-tray.gif $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/assets/icons/png/client/
	cp assets/icons/png/server/server-tray.gif $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/assets/icons/png/server/
	mkdir -p $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/assets/icons/windows
	cp assets/icons/windows/client.ico assets/icons/windows/server.ico $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/assets/icons/windows/
	cp lib/protocol.tcl $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/lib/
	cp tests/platform.test tests/protocol.test tests/relay.test $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/tests/
	sh packaging/normalize-text.sh crlf packaging/windows98/README.txt $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/README.txt
	sh packaging/normalize-text.sh crlf LICENSE $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/LICENSE.txt
	cd $(DIST_DIR) && zip -qr retrochat-$(VERSION)-windows98-test-kit.zip retrochat-$(VERSION)-windows98-test-kit

$(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET).tar.gz: client.tcl lib/protocol.tcl LICENSE assets/icons/png/client/client-tray.gif assets/icons/netbsd/client-16.png assets/icons/netbsd/client-32.png assets/icons/netbsd/client-48.png assets/icons/netbsd/client-256.png packaging/netbsd/README.mac68k packaging/netbsd/retrochat-client
	rm -rf $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)
	mkdir -p $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/lib
	cp client.tcl $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/
	cp lib/protocol.tcl $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/lib/
	mkdir -p $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/assets/icons/png/client
	cp assets/icons/png/client/client-tray.gif $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/assets/icons/png/client/
	mkdir -p $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/assets/icons/netbsd
	cp assets/icons/netbsd/client-*.png $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/assets/icons/netbsd/
	cp packaging/netbsd/README.mac68k $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/README.txt
	cp LICENSE $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/LICENSE.txt
	cp packaging/netbsd/retrochat-client $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/
	chmod 755 $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/retrochat-client
	COPYFILE_DISABLE=1 tar --no-xattrs -C $(DIST_DIR) -czf $@ retrochat-client-$(VERSION)-$(TARGET)

$(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET).tar.gz: server.tcl server-gui.tcl lib/protocol.tcl LICENSE assets/icons/png/server/server-tray.gif assets/icons/netbsd/server-16.png assets/icons/netbsd/server-32.png assets/icons/netbsd/server-48.png assets/icons/netbsd/server-256.png packaging/netbsd/README.mac68k packaging/netbsd/retrochat-server
	rm -rf $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)
	mkdir -p $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/lib
	cp server.tcl server-gui.tcl $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/
	cp lib/protocol.tcl $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/lib/
	mkdir -p $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/assets/icons/png/server
	cp assets/icons/png/server/server-tray.gif $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/assets/icons/png/server/
	mkdir -p $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/assets/icons/netbsd
	cp assets/icons/netbsd/server-*.png $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/assets/icons/netbsd/
	cp packaging/netbsd/README.mac68k $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/README.txt
	cp LICENSE $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/LICENSE.txt
	cp packaging/netbsd/retrochat-server $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/
	chmod 755 $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/retrochat-server
	COPYFILE_DISABLE=1 tar --no-xattrs -C $(DIST_DIR) -czf $@ retrochat-server-$(VERSION)-$(TARGET)

test:
	tclsh tests/platform.test
	tclsh tests/protocol.test
	tclsh tests/classic-filenames.test
	tclsh tests/server-history.test
	tclsh tests/server-admin.test

clean:
	rm -rf $(DIST_DIR)
