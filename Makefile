include Makefile.common
include version

PLATFORM:=$(shell uname)
CPPFLAGS:=$(shell pkg-config --cflags ncurses)
NCURSES_LIB:=$(shell pkg-config --libs ncurses)
DEBUG?=#XXX -g -D_DEBUG ###-pg -Wpedantic ## -pg #-fprofile-arcs
# pkg-config --libs --cflags ncurses
# -D_DEFAULT_SOURCE -D_XOPEN_SOURCE=600 -lncurses -ltinfo

UTF8_SUPPORT:=yes
DESTDIR?=
PREFIX:=$(shell brew --prefix)

BINDIR=$(PREFIX)/bin
SHAREDIR=$(PREFIX)/share
MANDIR=$(SHAREDIR)/man
MAN1DIR=$(MANDIR)/man1
DOCDIR=$(SHAREDIR)/doc/multitail-$(VERSION)

SYSCONFDIR=$(PREFIX)/etc
CONFIG_FILE=$(SYSCONFDIR)/multitail.conf
INSTALLED_BIN_FILE=$(DESTDIR)$(PREFIX)/bin/multitail
INSTALLED_CONFIG_FILE=$(DESTDIR)$(CONFIG_FILE)
INSTALLED_MAN_FILE=$(DESTDIR)$(PREFIX)/share/man/man1/multitail.1
INSTALLED_DOCS_DIR=$(DESTDIR)$(PREFIX)/share/doc/multitail-$(VERSION)
INSTALLED_FILES="$(INSTALLED_BIN_FILE)" "$(INSTALLED_MAN_FILE)" "$(INSTALLED_CONFIG_FILE)" "$(INSTALLED_DOCS_DIR)/"
CONFIG_DIR=$(SYSCONFDIR)/multitail

INSTALL = install
INSTALL_DATA = $(INSTALL) -m 0644
INSTALL_EXEC = $(INSTALL) -m 0755
INSTALL_DIR = mkdir -pv

CC?=gcc
CFLAGS+=-Wall -Wno-unused-parameter -funsigned-char -O3
CPPFLAGS+=-D$(PLATFORM) -DVERSION=\"$(VERSION)\" $(DEBUG) -DCONFIG_FILE=\"$(CONFIG_FILE)\" -D_FORTIFY_SOURCE=2

# build dependency files while compile (*.d)
CPPFLAGS+= -MMD -MP


ifeq ($(PLATFORM),Darwin)
    LDFLAGS+=-lpanel $(NCURSES_LIB) -lutil -lm
else
ifeq ($(UTF8_SUPPORT),yes)
    LDFLAGS+=-lpanelw -lncursesw -lutil -lm
    CPPFLAGS+=-DUTF8_SUPPORT
else
    LDFLAGS+=-lpanel -lncurses -lutil -lm
endif
endif


OBJS:=utils.o mt.o error.o my_pty.o term.o scrollback.o help.o mem.o cv.o selbox.o stripstring.o color.o misc.o ui.o exec.o diff.o config.o cmdline.o globals.o history.o clipboard.o
DEPENDS:= $(OBJS:%.o=%.d)

.PHONY: all check install uninstall coverity clean distclean package debug
all: multitail

multitail: $(OBJS)
	$(CC) $(OBJS) $(LDFLAGS) -o multitail

ccmultitail: $(OBJS)
	ccmalloc --no-wrapper -Wextra $(CC) $(OBJS) $(LDFLAGS) -o ccmultitail

install: multitail
	$(INSTALL_DIR) $(DESTDIR)$(BINDIR)
	$(INSTALL_DIR) $(DESTDIR)$(MAN1DIR)
	$(INSTALL_DIR) $(DESTDIR)$(DOCDIR)
	$(INSTALL_EXEC) multitail $(DESTDIR)$(BINDIR)
	$(INSTALL_DATA) multitail.1 $(DESTDIR)$(MAN1DIR)/multitail.1
	$(INSTALL_DATA) AUTHORS INSTALL README.md manual*.html $(DESTDIR)$(DOCDIR)
	#
	### COPIED multitail.conf.new, YOU NEED TO REPLACE THE multitail.conf
	### YOURSELF WITH THE NEW FILE
	#
	$(INSTALL_DIR) $(DESTDIR)$(CONFIG_DIR)
	$(INSTALL_DATA) multitail.conf $(DESTDIR)$(CONFIG_FILE)
	#
	# There's a mailinglist!
	# Send an e-mail to minimalist@vanheusden.com with in the subject
	# 'subscribe multitail' to subscribe.
	#
	# you might want to run 'make thanks' now :-)
	# http://www.vanheusden.com/wishlist.php
	#
	# How do YOU use multitail? Please send me an e-mail so that I can
	# update the examples page.
	ls -oAhFO $(INSTALLED_FILES)

uninstall: clean
	rm -f $(DESTDIR)$(BINDIR)/multitail
	rm -f $(DESTDIR)$(MAN1DIR)/multitail.1
	rm -f $(DESTDIR)$(CONFIG_FILE)
	rm -rf $(DESTDIR)$(CONFIG_DIR)
	rm -rf $(DESTDIR)$(DOCDIR)
	rm -rfv $(INSTALLED_FILES)

clean:
	rm -f $(OBJS) multitail core gmon.out *.da *.d ccmultitail

package: clean
	# source package
	rm -rf multitail-$(VERSION)*
	mkdir multitail-$(VERSION)
	cp -a *.conf *.c *.h multitail.1 manual*.html Makefile makefile.* AUTHORS INSTALL README.md version multitail-$(VERSION)
	tar czf multitail-$(VERSION).tgz multitail-$(VERSION)
	rm -rf multitail-$(VERSION)

### cppcheck: unusedFunction check can't be used with '-j' option. Disabling unusedFunction check.
check:
	#XXX TBD to use cppechk --check-config $(CPPFLAGS) -I/usr/include
	cppcheck --std=c99 --verbose --force --enable=all --inconclusive --template=gcc \
		'--suppress=variableScope' --xml --xml-version=2 . 2> cppcheck.xml
	cppcheck-htmlreport --file=cppcheck.xml --report-dir=cppcheck
	make clean
	-scan-build make

coverity:
	make clean
	rm -rf cov-int
	CC=gcc cov-build --dir cov-int make all
	tar vczf ~/site/coverity/multitail.tgz README cov-int/
	putsite -q
	/home/folkert/.coverity-mt.sh

distclean: clean
	rm -rf cov-int cppcheck cppcheck.xml *.d *~ tags

debug:
	@echo "CONFIG_FILE=$(CONFIG_FILE)"
	@echo "DEBUG=$(DEBUG)"
	@echo "INSTALLED_BIN_FILE=$(INSTALLED_BIN_FILE)"
	@echo "INSTALLED_DOCS_DIR=$(INSTALLED_DOCS_DIR)"
	@echo "INSTALLED_FILES=$(INSTALLED_FILES)"
	@echo "INSTALLED_MAN_FILE=$(INSTALLED_MAN_FILE)"
	@echo "OBJS=$(OBJS)"

# include dependency files for any other rule:
ifneq ($(filter-out clean distclean,$(MAKECMDGOALS)),)
-include $(DEPENDS)
endif

