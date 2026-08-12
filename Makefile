VERSION ?= 0.1.0
DIST_DIR ?= dist
TARGET = netbsd-10.1-mac68k

.PHONY: all macos-installer netbsd-mac68k client-netbsd-mac68k server-netbsd-mac68k windows98-test-kit windows98-test-iso windows98-installer windows98-installer-iso test clean

all: netbsd-mac68k

macos-installer:
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

windows98-installer:
	@test -f "$(TCL805_INSTALLER)" || { echo "Set TCL805_INSTALLER to the downloaded tcl805.exe path" >&2; exit 1; }
	mkdir -p $(DIST_DIR)
	makensis -DVERSION=$(VERSION) -DTCL805_INSTALLER="$(TCL805_INSTALLER)" packaging/windows98/RetroChat.nsi

windows98-installer-iso: windows98-installer
	rm -rf $(DIST_DIR)/retrochat-windows98-installer-cd
	mkdir -p $(DIST_DIR)/retrochat-windows98-installer-cd
	cp $(DIST_DIR)/RetroChat-$(VERSION)-Windows98-Setup.exe $(DIST_DIR)/retrochat-windows98-installer-cd/SETUP.EXE
	rm -f $(DIST_DIR)/RetroChat-$(VERSION)-Windows98-Installer.iso
	hdiutil makehybrid -iso -joliet -o $(DIST_DIR)/RetroChat-$(VERSION)-Windows98-Installer.iso $(DIST_DIR)/retrochat-windows98-installer-cd

$(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit.zip: client.tcl server.tcl lib/protocol.tcl tests/platform.test tests/protocol.test tests/relay.test packaging/windows98/README.txt
	rm -rf $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit
	mkdir -p $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/lib
	mkdir -p $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/tests
	cp client.tcl server.tcl $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/
	cp lib/protocol.tcl $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/lib/
	cp tests/platform.test tests/protocol.test tests/relay.test $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/tests/
	cp packaging/windows98/README.txt $(DIST_DIR)/retrochat-$(VERSION)-windows98-test-kit/
	cd $(DIST_DIR) && zip -qr retrochat-$(VERSION)-windows98-test-kit.zip retrochat-$(VERSION)-windows98-test-kit

$(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET).tar.gz: client.tcl lib/protocol.tcl packaging/netbsd/README.mac68k packaging/netbsd/retrochat-client
	rm -rf $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)
	mkdir -p $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/lib
	cp client.tcl $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/
	cp lib/protocol.tcl $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/lib/
	cp packaging/netbsd/README.mac68k $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/README.txt
	cp packaging/netbsd/retrochat-client $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/
	chmod 755 $(DIST_DIR)/retrochat-client-$(VERSION)-$(TARGET)/retrochat-client
	tar -C $(DIST_DIR) -czf $@ retrochat-client-$(VERSION)-$(TARGET)

$(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET).tar.gz: server.tcl lib/protocol.tcl packaging/netbsd/README.mac68k packaging/netbsd/retrochat-server
	rm -rf $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)
	mkdir -p $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/lib
	cp server.tcl $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/
	cp lib/protocol.tcl $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/lib/
	cp packaging/netbsd/README.mac68k $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/README.txt
	cp packaging/netbsd/retrochat-server $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/
	chmod 755 $(DIST_DIR)/retrochat-server-$(VERSION)-$(TARGET)/retrochat-server
	tar -C $(DIST_DIR) -czf $@ retrochat-server-$(VERSION)-$(TARGET)

test:
	tclsh tests/platform.test
	tclsh tests/protocol.test

clean:
	rm -rf $(DIST_DIR)
