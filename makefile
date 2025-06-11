KEXT      := CodecCommander.kext
DIST      := CodecCommander
BUILDDIR  := ./Build/Products

VERSION_ERA	:= $(shell ./print_version.sh)
VERSION_MODULE	:= $(shell ./print_module_version.sh)

ifeq ($(VERSION_ERA),10.10-)
  INSTDIR := /System/Library/Extensions
endif
ifeq ($(VERSION_ERA),10.11-10.15)
  INSTDIR := /Library/Extensions
endif

ifeq ($(VERSION_ERA),10.10-)
  BINDIR := /usr/bin
else
  BINDIR := /usr/local/bin
endif

# on 11+ we stub out all install steps
ifeq ($(VERSION_ERA),11+)
.PHONY: install install_debug update_kernelcache
install install_debug update_kernelcache:
	@echo "Install/update skipped on macOS $(shell sw_vers -productVersion)"
else
# only for 10.10- through 10.15:
.PHONY: update_kernelcache install_debug install

update_kernelcache:
	sudo touch /System/Library/Extensions
	sudo kextcache -update-volume /

install_debug:
	if [ ! -d $(BINDIR) ]; then sudo mkdir -p $(BINDIR); fi
	sudo cp $(BUILDDIR)/Debug/CodecCommanderClient $(BINDIR)/hda-verb
	if [ "`which tag`" != "" ]; then sudo tag -a Purple $(BINDIR)/hda-verb; fi
	sudo rm -Rf $(INSTDIR)/$(KEXT)
	sudo cp -R $(BUILDDIR)/Debug/$(KEXT) $(INSTDIR)
	if [ "`which tag`" != "" ]; then sudo tag -a Purple $(INSTDIR)/$(KEXT); fi
	$(MAKE) update_kernelcache

install:
	if [ ! -d $(BINDIR) ]; then sudo mkdir -p $(BINDIR); fi
	sudo cp $(BUILDDIR)/Release/CodecCommanderClient $(BINDIR)/hda-verb
	if [ "`which tag`" != "" ]; then sudo tag -a Blue $(BINDIR)/hda-verb; fi
	sudo rm -Rf $(INSTDIR)/$(KEXT)
	sudo cp -R $(BUILDDIR)/Release/$(KEXT) $(INSTDIR)
	if [ "`which tag`" != "" ]; then sudo tag -a Blue $(INSTDIR)/$(KEXT); fi
	$(MAKE) update_kernelcache
endif

# common bits below ----------------------------------------------------

ifeq ($(findstring 32,$(BITS)),32)
OPTIONS:=$(OPTIONS) -arch i386
endif

ifeq ($(findstring 64,$(BITS)),64)
OPTIONS:=$(OPTIONS) -arch x86_64
endif

OPTIONS += -scheme CodecCommander

.PHONY: all clean distribute

all:
	xcodebuild build $(OPTIONS) -configuration Debug
	xcodebuild build $(OPTIONS) -configuration Release

clean:
	xcodebuild clean $(OPTIONS) -configuration Debug
	xcodebuild clean $(OPTIONS) -configuration Release

distribute:
	if [ -e ./Distribute ]; then rm -r ./Distribute; fi
	mkdir ./Distribute
	cp -R $(BUILDDIR)/Debug ./Distribute
	cp -R $(BUILDDIR)/Release ./Distribute
	cp README.md ./Distribute/Debug
	cp README.md ./Distribute/Release
	cp LICENSE ./Distribute/Debug
	cp LICENSE ./Distribute/Release
	find ./Distribute -path *.DS_Store -delete
	find ./Distribute -path *.dSYM -exec echo rm -r {} \; >/tmp/org.voodoo.rm.dsym.sh
	chmod +x /tmp/org.voodoo.rm.dsym.sh
	/tmp/org.voodoo.rm.dsym.sh
	rm /tmp/org.voodoo.rm.dsym.sh
	ditto -c -k --sequesterRsrc --zlibCompressionLevel 9 ./Distribute/Release ./Archive_Release.zip
	ditto -c -k --sequesterRsrc --zlibCompressionLevel 9 ./Distribute/Debug ./Archive_Debug.zip
	mv ./Archive_Release.zip ./Distribute/$(DIST)-$(VERSION_MODULE)-RELEASE.zip
	mv ./Archive_Debug.zip ./Distribute/$(DIST)-$(VERSION_MODULE)-DEBUG.zip