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

CONFIG_FILE=$(DESTDIR)$(PREFIX)/etc/multitail.conf
INSTALLED_BIN_FILE=$(DESTDIR)$(PREFIX)/bin/multitail
INSTALLED_MAN_FILE=$(DESTDIR)$(PREFIX)/share/man/man1/multitail.1
INSTALLED_DOCS_DIR=$(DESTDIR)$(PREFIX)/share/doc/multitail-$(VERSION)
INSTALLED_FILES="$(INSTALLED_BIN_FILE)" "$(INSTALLED_MAN_FILE)" "$(CONFIG_FILE)" "$(INSTALLED_DOCS_DIR)/"

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
	mkdir -p "$$(dirname $(CONFIG_FILE))"
	mkdir -p "$$(dirname $(INSTALLED_BIN_FILE))"
	mkdir -p "$$(dirname $(INSTALLED_MAN_FILE))"
	mkdir -p "$(INSTALLED_DOCS_DIR)"
	cp multitail "$(INSTALLED_BIN_FILE)"
	cp multitail.1 "$(INSTALLED_MAN_FILE)"
	cp *.md manual*.html "$(INSTALLED_DOCS_DIR)"
	cp multitail.conf "$(CONFIG_FILE)"
	ls -oAhFO $(INSTALLED_FILES)

uninstall: clean
	rm -rfv $(INSTALLED_FILES)

clean:
	rm -f $(OBJS) multitail core gmon.out *.da *.d ccmultitail

package: clean
	# source package
	rm -rf multitail-$(VERSION)*
	mkdir multitail-$(VERSION)
	cp -a conversion-scripts *.conf *.c *.h multitail.1 manual*.html Makefile makefile.* INSTALL license.txt readme.txt thanks.txt version multitail-$(VERSION)
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

