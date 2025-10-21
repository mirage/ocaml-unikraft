# SPDX-License-Identifier: MIT
# Copyright (c) 2025 Samuel Hym, Tarides <samuel@tarides.com>

# CONFIGURATION
#################

# Target platform: qemu, firecracker or xen
OCUKPLAT ?= qemu
# Target architecture: x86_64 or arm64
OCUKARCH ?= x86_64
STDARCH := $(subst arm64,aarch64,$(OCUKARCH))
# Unikraft external libraries (musl, lwip) to include
OCUKEXTLIBS ?= musl
# Options for the configuration (available options: debug, 9pfs)
OCUKCONFIGOPTS ?=
# Installation prefix for OCaml
prefix ?= $$PWD/_build

EMPTY =
SPACE = $(EMPTY) $(EMPTY)

BLDLIB := _build/lib
BLDSHARE := _build/share
BLDBIN := _build/bin
# The following can be overriden to build the toolchain using installed backends
LIB := $(BLDLIB)
SHARE := $(BLDSHARE)
BIN := $(BLDBIN)

# Absolute path to the Unikraft sources
UNIKRAFT ?= $(LIB)/unikraft
ifeq ("$(filter /%,$(UNIKRAFT))","")
override UNIKRAFT := $$PWD/$(UNIKRAFT)
endif
# Absolute path to the musl wrapper sources for Unikraft
UNIKRAFTMUSL ?= $(LIB)/unikraft-musl
ifeq ("$(filter /%,$(UNIKRAFTMUSL))","")
override UNIKRAFTMUSL := $$PWD/$(UNIKRAFTMUSL)
endif

# Create a symbolic link
SYMLINK := ln -sf

BACKENDPKG := ocaml-unikraft-backend-$(OCUKPLAT)-$(OCUKARCH)
TOOLCHAINPKG := ocaml-unikraft-toolchain-$(OCUKARCH)
OCAMLPKG := ocaml-unikraft-$(OCUKARCH)
BELIBDIR := $(LIB)/$(BACKENDPKG)
BEBLDLIBDIR := $(BLDLIB)/$(BACKENDPKG)
SHAREDIR := $(SHARE)/$(BACKENDPKG)
BLDSHAREDIR := $(BLDSHARE)/$(BACKENDPKG)
# Dummy files that are touched when the backend and the compiler have been built
BACKENDBUILT := _build/$(OCUKPLAT)-$(OCUKARCH)_built
OCAMLBUILT := _build/ocaml_built

.PHONY: all
all: compiler


# BUILD OF DUMMYKERNEL
########################

LIBMUSL := _build/libs/musl
MUSLARCHIVE := $(wildcard $(UNIKRAFTMUSL)/musl-*.tar.gz)
MUSLARCHIVEPATH := $(BEBLDLIBDIR)/libmusl/$(notdir $(MUSLARCHIVE))

OCUKEXTLIBSDEPS := $(addprefix _build/libs/,$(OCUKEXTLIBS))
OCUKEXTLIBSARCHIVES :=
ifneq ("$(findstring musl,$(OCUKEXTLIBS))","")
OCUKEXTLIBSARCHIVES := $(OCUKEXTLIBSARCHIVES) $(MUSLARCHIVEPATH)
endif

# The suffix has the form `-liba+libb+libc-optx+opty`
CONFIG_SUFFIX := \
   $(subst $(SPACE),,\
       $(patsubst %,-%,\
           $(subst $(SPACE),+,$(OCUKEXTLIBS))\
           $(subst $(SPACE),+,$(OCUKCONFIGOPTS))))

CONFIG := dummykernel/$(OCUKPLAT)-$(OCUKARCH)$(CONFIG_SUFFIX).fullconfig

UKMAKE := umask 0022 && \
   $(MAKE) -C $(BEBLDLIBDIR) \
       CONFIG_UK_BASE="$(UNIKRAFT)/" \
       O="$$PWD/$(BEBLDLIBDIR)/" \
       A="$$PWD/dummykernel/" \
       L="$(subst $(SPACE),:,$(addprefix $$PWD/,$(OCUKEXTLIBSDEPS)))" \
       N=dummykernel \
       C="$$PWD/$(CONFIG)"

# Main build rule for the dummy kernel
$(BACKENDBUILT): $(CONFIG) | $(BEBLDLIBDIR)/Makefile $(LIB)/unikraft \
    $(OCUKEXTLIBSDEPS) $(OCUKEXTLIBSARCHIVES)
	+$(UKMAKE) sub_make_exec=1
	touch $@

_build/libs/musl:
	@if test -z "$(MUSLARCHIVE)" ; then \
	    echo "Cannot find lib-musl sources;" \
	        "set UNIKRAFTMUSL=... in your $(MAKE) call"; \
	    false; \
	fi
	mkdir -p $(dir $@)
	$(SYMLINK) "$(UNIKRAFTMUSL)" $@

$(MUSLARCHIVEPATH): $(MUSLARCHIVE)
	@if test -z "$<" ; then \
	    echo "Cannot find lib-musl sources;" \
	        "set UNIKRAFTMUSL=... in your $(MAKE) call"; \
	    false; \
	fi
	mkdir -p $(dir $@)
	cp $< $@

# Enabled only on Linux (requirement of the olddefconfig target) and in
# development (no need to rebuild the configuration in release)
$(CONFIG): dummykernel/$(OCUKPLAT)-$(OCUKARCH)$(CONFIG_SUFFIX).config \
    | $(BEBLDLIBDIR)/Makefile $(OCUKEXTLIBSDEPS)
	if [ -e .git -a "`uname`" = Linux ]; then \
	    cp $< $@; \
	    $(UKMAKE) olddefconfig; \
	    sed -e '/Unikraft.*Configuration/d' \
	        -e '/CONFIG_UK_FULLVERSION/d' \
	        -e '/CONFIG_HOST_ARCH/d' \
	        -e '/CONFIG_UK_BASE/d' \
	        -e '/CONFIG_UK_APP/d' \
	        -i $@ ; \
	else \
	    touch $@; \
	fi

# Build the intermediate configuration file from configuration chunks
CONFIG_CHUNKS := arch/$(OCUKARCH) plat/$(OCUKPLAT)
CONFIG_CHUNKS += libs/base
CONFIG_CHUNKS += $(addprefix libs/,$(OCUKEXTLIBS))
CONFIG_CHUNKS += opts/base
CONFIG_CHUNKS += $(addprefix opts/,$(OCUKCONFIGOPTS))

dummykernel/$(OCUKPLAT)-$(OCUKARCH)$(CONFIG_SUFFIX).config: \
  $(addprefix dummykernel/config/, $(CONFIG_CHUNKS))
	cat $^ > $@

.PHONY: fullconfig
fullconfig: $(CONFIG)

# Rebuild all the full configurations
.PHONY: fullconfigs
fullconfigs:
	+for p in qemu firecracker; do \
	  for a in x86_64 arm64; do \
	    for l in musl; do \
	      for o in "" debug 9pfs "debug 9pfs"; do \
	        $(MAKE) OCUKPLAT="$$p" OCUKARCH="$$a" OCUKEXTLIBS="$$l" \
	          OCUKCONFIGOPTS="$$o" fullconfig ; \
	      done \
	    done \
	  done \
	done

$(BEBLDLIBDIR)/Makefile: | $(BEBLDLIBDIR) $(LIB)/unikraft
	test -e "$(UNIKRAFT)/Makefile"
	$(SYMLINK) "$(UNIKRAFT)/Makefile" $@

# Trampoline target to build a Unikraft Makefile target, such as menuconfig,
# with all the proper options set
%.unikraft: | $(CONFIG) $(BEBLDLIBDIR)/Makefile $(LIB)/unikraft \
    $(OCUKEXTLIBSDEPS) $(OCUKEXTLIBSARCHIVES)
	+$(UKMAKE) $*


# EXTRACTION OF BUILD INFO
############################
# Learn how to build a unikernel: flags for the compiler, for the linker, how to
# post-process the image, ...

$(BEBLDLIBDIR)/appdummykernel/dummymain.o.cmd: $(BACKENDBUILT) ;

# Use an implicit rule to generate all files in one rule
.PRECIOUS: $(BLDSHARE)/%/cflags $(BLDSHARE)/%/cc $(BLDSHARE)/%/toolprefix
$(BLDSHARE)/%/cflags $(BLDSHARE)/%/cc $(BLDSHARE)/%/toolprefix: \
    _build/lib/%/appdummykernel/dummymain.o.cmd $(BACKENDBUILT) | $(BLDSHAREDIR)
	bash extract_cc_opts.sh "$(UNIKRAFT)" "$$PWD/$(BEBLDLIBDIR)" $< \
	    $(BLDSHARE)/$*/cflags $(BLDSHARE)/$*/cc $(BLDSHARE)/$*/toolprefix

# This rule depends on $(BACKENDBUILT) rather than the .cmd file since its
# exact name can vary depending on the backend (namely with an extra `.elf`
# extension on xen)
$(BLDSHAREDIR)/ldflags: $(BACKENDBUILT) | $(BLDSHAREDIR)
	bash extract_cc_opts.sh "$(UNIKRAFT)" "$$PWD/$(BEBLDLIBDIR)" \
	    "$(BEBLDLIBDIR)/"dummykernel_*.dbg.cmd $@

$(BLDSHAREDIR)/.suffix: $(BACKENDBUILT) | $(BLDSHAREDIR)
	suffix=`basename "$(BEBLDLIBDIR)"/dummykernel_*.dbg` ; \
	    printf %s "$${suffix#*.}" > $@

# Post-processing steps
# We rebuild the final image in verbose mode, to extract the post-processing
# steps (we redirect the log into a file because the verbose mode is really
# really verbose)
# We copy the config preserving the timestamp to avoid rebuilds due to silly
# changes, but we still log the diff so that if something really changed, we can
# debug it
$(BLDSHAREDIR)/.poststeps.log: $(BACKENDBUILT) | $(BLDSHAREDIR)
	if ! diff -u $(CONFIG) $(BEBLDLIBDIR)/config ; then \
	    cp -p $(CONFIG) $(BEBLDLIBDIR)/config; \
	fi
	+$(UKMAKE) sub_make_exec=1 -W "$$PWD/$(BEBLDLIBDIR)"/dummykernel_*.dbg \
	    --no-print-directory V=1 > $@

$(BLDSHAREDIR)/poststeps: $(BLDSHAREDIR)/.poststeps.log $(BLDSHAREDIR)/.suffix
	sed -e '/^[*A-Z]/d' \
	    -e '/^cmp.*fullconfig.*config/d' \
	    -e '/sh provided_syscalls.in/d' \
	    -e '/sh libraries.in/d' $(BLDSHAREDIR)/.poststeps.log \
	| bash extract_postprocessing.sh "$(UNIKRAFT)" \
	    "$$PWD/$(BEBLDLIBDIR)" \
	    dummykernel_$(subst firecracker,fc,$(OCUKPLAT))-$(OCUKARCH) \
	    $(BLDSHAREDIR)/.suffix > $@

.PHONY: backend
backend: $(BACKENDBUILT) \
    $(addprefix $(BLDSHAREDIR)/,cc cflags ldflags poststeps toolprefix)


# TOOLCHAIN
#############

SHAREDIRS := $(wildcard $(SHARE)/ocaml-unikraft-backend-*-$(OCUKARCH))
ifeq ("$(strip $(SHAREDIRS))","")
SHAREDIRS := $(BLDSHAREDIR)
endif
CONFIGFILES := $(foreach d,$(SHAREDIRS),\
    $(addprefix $(d)/,cc cflags ldflags poststeps toolprefix))

TOOLCHAIN := gcc cc ar as ld nm objcopy objdump ranlib readelf strip
TOOLCHAIN := $(foreach tool,$(TOOLCHAIN),$(STDARCH)-unikraft-ocaml-$(tool))
BLDTOOLCHAIN := $(addprefix $(BLDBIN)/,$(TOOLCHAIN))
TOOLCHAIN := $(addprefix $(BIN)/,$(TOOLCHAIN))

$(BLDBIN)/$(STDARCH)-unikraft-ocaml-%: gen_toolchain_tool.sh $(CONFIGFILES) \
    | $(BLDBIN)
	./gen_toolchain_tool.sh $(OCUKARCH) $(SHARE) $* > $@
	chmod +x $@

.PHONY: toolchain
toolchain: $(BLDTOOLCHAIN)


# OCAML COMPILER
##################

# Extract sources from the ocaml-src package and apply patches if there any in
# `patches/<OCaml version>/`
ocaml:
# First make sure the ocaml directory doesn't exist, otherwise the cp would
# create an ocaml-src subdirectory
	test ! -d $@
	cp -r "$$(ocamlfind query ocaml-src)" $@
	VERSION="$$(head -n1 ocaml/VERSION)" ; \
	if test -d "patches/$$VERSION" ; then \
	  opatch -v -C $@ "patches/$$VERSION"/*; \
	fi

# We add $(BLDBIN) inconditionnally, even when using the installed toolchain: as
# the $(BLDBIN) directory should not be built, it will just be ignored
ocaml/Makefile.config: $(TOOLCHAIN) | ocaml
	PREFIX="$(prefix)" ; \
	cd ocaml && \
	  PATH="$$PWD/../$(BLDBIN):$$PATH" \
	  ./configure \
		--target=$(STDARCH)-unikraft-ocaml \
		--prefix="$$PREFIX/lib/$(OCAMLPKG)" \
		--disable-shared \
		--disable-ocamldoc \
		--without-zstd

$(OCAMLBUILT): ocaml/Makefile.config | _build
	PATH="$$PWD/$(BLDBIN):$$PATH" \
	  $(MAKE) -C ocaml crossopt OLDS="-o yacc/ocamlyacc -o lex/ocamllex"
	touch $@

OCAMLFIND_CONF := _build/unikraft_$(OCUKARCH).conf
$(OCAMLFIND_CONF): gen_ocamlfind_conf.sh $(OCAMLBUILT)
	./gen_ocamlfind_conf.sh $(OCUKARCH) "$(prefix)" > $@

.PHONY: compiler
compiler: $(OCAMLBUILT) $(OCAMLFIND_CONF) _build/empty


# OCAMLFIND TOOLCHAIN WITH A DEFAULT ARCHITECTURE
###################################################

# This assumes that the OCaml compiler has been installed, as it will ensure it
# can find the compiler where it is expected within $(prefix)
_build/unikraft.conf: | _build
	./gen_ocamlfind_conf.sh default $(OCUKARCH) "$(prefix)" > $@

# INSTALL
###########

$(BACKENDPKG).install: gen_backend_install.sh $(BACKENDBUILT) \
    $(addprefix $(SHAREDIR)/,cc cflags ldflags poststeps toolprefix)
	./gen_backend_install.sh $(OCUKPLAT)-$(OCUKARCH) > $@

ocaml-unikraft-toolchain-$(OCUKARCH).install: gen_toolchain_install.sh \
    $(BLDTOOLCHAIN)
	./gen_toolchain_install.sh $(OCUKARCH) $(BLDTOOLCHAIN) > $@

ocaml-unikraft-$(OCUKARCH).install: gen_dot_install.sh \
    $(OCAMLFIND_CONF) _build/empty
	./gen_dot_install.sh $(OCUKARCH) > $@

ocaml-unikraft-default-$(OCUKARCH).install: _build/unikraft.conf
	printf 'lib_root: [\n  "%s" { "%s" }\n]\n' $< \
	  findlib.conf.d/unikraft.conf > $@

.PHONY: install-ocaml
install-ocaml:
	ln -sf "$$(command -v ocamllex)" ocaml/lex/ocamllex
	ln -sf "$$(command -v ocamlyacc)" ocaml/yacc/ocamlyacc
	$(MAKE) -C ocaml installcross


# MISC
########

_build/empty: | _build
	touch $@

# This rule doesn't use variables such as $(SHARE) etc. as we want to create
# the directories only in _build: if SHARE is explicitly set to a different
# (installation) directory, we should really not try to create it
# The use case is building only one OPAM package using already installed OPAM
# packages
ALLDIRS := $(BACKENDPKG) $(OCAMLPKG) $(TOOLCHAINPKG) $(TOOLCHAINPKG)/include
ALLDIRS := bin lib $(addprefix lib/,$(ALLDIRS)) share share/$(BACKENDPKG)
ALLDIRS := _build $(addprefix _build/,$(ALLDIRS))
ALLDIRS := $(ALLDIRS) $(addsuffix /,$(ALLDIRS))
$(ALLDIRS):
	mkdir -p $@

_build/lib/unikraft: | _build/lib
	@if test "$(UNIKRAFT)" '=' "$$PWD"/$@ ; then \
	    echo "Cannot find Unikraft sources;" \
	        "set UNIKRAFT=... in your $(MAKE) call"; \
	    false; \
	fi
	$(SYMLINK) "$(UNIKRAFT)" $@

# Build and install a compiler in _build (assuming you set none of the
# variables: prefix, BIN, LIB, SHARE)
.PHONY: localbuild
localbuild: compiler
	$(MAKE) install-ocaml
	$(MAKE) _build/unikraft.conf
	@echo 'Now run:'
	@echo '  export PATH="$(prefix)/bin:$$PATH";' \
	    'export OCAMLFIND_CONF="$$PWD/_build/unikraft.conf"'
	@echo 'in your shell session to be able to use the unikraft toolchain.'

# Run the examples with a local build, setting PATH and OCAMLFIND_CONF for that
.PHONY: localtests
localtests:
	pwd="$$PWD" ; \
	  cd examples/all/ && \
	  PATH="$$pwd/$(BLDBIN):$$PATH" \
	  OCAMLFIND_CONF="$$pwd/_build/unikraft.conf" \
	  dune runtest

.PHONY: opams
opams:
	ocaml gen_opams.ml

.PHONY: clean
clean:
	rm -rf _build
	if [ -d ocaml ] ; then $(MAKE) -C ocaml clean ; fi

.PHONY: distclean
distclean: clean
# Don't remove the ocaml directory itself, to play nicer with
# development in there
	if [ -d ocaml ] ; then $(MAKE) -C ocaml distclean ; fi
