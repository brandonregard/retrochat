VERSION ?= 0.0.2
DIST_DIR ?= dist
TARGET = netbsd-10.1-mac68k
TCL805_INSTALLER ?= packaging/windows98/runtime/tcl805.exe
CLASSIC_MAC_TOOLCHAIN ?= packaging/classic-mac/toolchain/TclTk_8.3.4_FullInstall.bin

.PHONY: all installers icons macos-installer netbsd-mac68k netbsd-mac68k-installer client-netbsd-mac68k server-netbsd-mac68k windows95-installer windows95-installer-iso windows98-test-kit windows98-test-iso classic-mac-wrapper-inputs classic-mac-68k-installer classic-mac-ppc-installer classic-mac-installers test clean

all: netbsd-mac68k

installers: macos-installer windows95-installer-iso netbsd-mac68k-installer classic-mac-installers

icons:
	sh packaging/icons/build.sh

macos-installer: icons
	VERSION=$(VERSION) DIST_DIR=$(DIST_DIR) sh packaging/macos/build.sh
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
	mkdir -p $(DIST_DIR)
	DIST_DIR=$(DIST_DIR) sh packaging/windows98/build-launchers.sh
	makensis -DVERSION=$(VERSION) -DTCL805_INSTALLER="$(abspath $(TCL805_INSTALLER))" packaging/windows98/RetroChat.nsi

windows95-installer-iso: windows95-installer
	rm -rf $(DIST_DIR)/retrochat-windows95-plus-installer-cd
	mkdir -p $(DIST_DIR)/retrochat-windows95-plus-installer-cd
	cp $(DIST_DIR)/retrochat-$(VERSION)-windows-95-plus-setup.exe $(DIST_DIR)/retrochat-windows95-plus-installer-cd/SETUP.EXE
	rm -f $(DIST_DIR)/retrochat-$(VERSION)-windows.iso
	hdiutil makehybrid -iso -joliet -o $(DIST_DIR)/retrochat-$(VERSION)-windows.iso $(DIST_DIR)/retrochat-windows95-plus-installer-cd

netbsd-mac68k-installer: netbsd-mac68k
	rm -rf $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer
	mkdir -p $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer
	cp $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET).tar.gz $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/
	cp $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET).tar.gz $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/
	cp packaging/netbsd/INSTALL.txt $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer/
	rm -f $(DIST_DIR)/retrochat-$(VERSION)-netbsd-mac68k.iso
	hdiutil makehybrid -iso -joliet -o $(DIST_DIR)/retrochat-$(VERSION)-netbsd-mac68k.iso $(DIST_DIR)/retrochat-$(VERSION)-netbsd-10.1-mac68k-installer

classic-mac-68k-installer: icons
	VERSION=$(VERSION) DIST_DIR=$(DIST_DIR) sh packaging/classic-mac/build-68k.sh

classic-mac-ppc-installer: icons
	VERSION=$(VERSION) DIST_DIR=$(DIST_DIR) sh packaging/classic-mac/build-ppc.sh

classic-mac-installers: classic-mac-68k-installer classic-mac-ppc-installer

classic-mac-wrapper-inputs:
	sh packaging/classic-mac/prepare-wrappers.sh

$(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit.zip: client.tcl server.tcl server-gui.tcl lib/protocol.tcl tests/platform.test tests/protocol.test tests/relay.test assets/icons/png/client/client-tray.gif assets/icons/png/server/server-tray.gif assets/icons/windows/client.ico assets/icons/windows/server.ico packaging/windows98/README.txt
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
	cp packaging/windows98/README.txt $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/
	cd $(DIST_DIR) && zip -qr retrochat-$(VERSION)-windows98-test-kit.zip retrochat-$(VERSION)-windows98-test-kit

$(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET).tar.gz: client.tcl lib/protocol.tcl assets/icons/png/client/client-tray.gif assets/icons/netbsd/client-16.png assets/icons/netbsd/client-32.png assets/icons/netbsd/client-48.png assets/icons/netbsd/client-256.png packaging/netbsd/README.mac68k packaging/netbsd/retrochat-client
	rm -rf $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)
	mkdir -p $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/lib
	cp client.tcl $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/
	cp lib/protocol.tcl $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/lib/
	mkdir -p $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/assets/icons/png/client
	cp assets/icons/png/client/client-tray.gif $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/assets/icons/png/client/
	mkdir -p $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/assets/icons/netbsd
	cp assets/icons/netbsd/client-*.png $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/assets/icons/netbsd/
	cp packaging/netbsd/README.mac68k $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/README.txt
	cp packaging/netbsd/retrochat-client $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/
	chmod 755 $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/retrochat-client
	tar -C $(DIST_DIR) -czf $@ retrochat-client-$(VERSION)-$(TARGET)

$(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET).tar.gz: server.tcl server-gui.tcl lib/protocol.tcl assets/icons/png/server/server-tray.gif assets/icons/netbsd/server-16.png assets/icons/netbsd/server-32.png assets/icons/netbsd/server-48.png assets/icons/netbsd/server-256.png packaging/netbsd/README.mac68k packaging/netbsd/retrochat-server
	rm -rf $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)
	mkdir -p $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/lib
	cp server.tcl server-gui.tcl $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/
	cp lib/protocol.tcl $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/lib/
	mkdir -p $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/assets/icons/png/server
	cp assets/icons/png/server/server-tray.gif $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/assets/icons/png/server/
	mkdir -p $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/assets/icons/netbsd
	cp assets/icons/netbsd/server-*.png $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/assets/icons/netbsd/
	cp packaging/netbsd/README.mac68k $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/README.txt
	cp packaging/netbsd/retrochat-server $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/
	chmod 755 $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/retrochat-server
	tar -C $(DIST_DIR) -czf $@ retrochat-server-$(VERSION)-$(TARGET)

test:
	tclsh tests/platform.test
	tclsh tests/protocol.test
	tclsh tests/classic-filenames.test
	tclsh tests/server-history.test

clean:
	rm -rf $(DIST_DIR)
