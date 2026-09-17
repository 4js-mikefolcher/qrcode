# qrcode -- build, test and demo targets.
#
#   make            compile the package and the demo program
#   make deps       install dev dependencies (fglunit) via fglpkg
#   make test       run the unit suites; live goqr.me tests skip
#   make test-net   run everything, including live goqr.me calls
#   make test-junit write JUnit XML for CI
#   make demo       run the demo program (ARGS="<payload>")
#   make clean      remove every build artifact

PKGDIR  = com/fourjs/qrcode
TESTDIR = tests
MERGED  = .fglpkg/merged
FGLUNIT = $(MERGED)/com/fourjs/fglunit

# The package under test, its dev dependencies and the test modules all have
# to be importable, at compile time as well as at run time.
export FGLLDPATH := $(CURDIR):$(CURDIR)/$(MERGED):$(CURDIR)/$(TESTDIR)

LIBS = \
 $(PKGDIR)/qrcode_common.42m\
 $(PKGDIR)/qrcode.42m\
 $(PKGDIR)/qrcode_read.42m

DEMO = $(PKGDIR)/test_qrcode.42m

SUITES  = test_qrcode_common test_qrcode_options test_qrcode_api test_qrcode_net
RUNNERS = $(addprefix $(TESTDIR)/,$(addsuffix .run.42m,$(SUITES)))

all: $(LIBS) $(DEMO)

# --- package ----------------------------------------------------------

$(PKGDIR)/qrcode_common.42m: qrcode_common.4gl
	fglcomp -Wall -M --output-dir . qrcode_common.4gl

$(PKGDIR)/qrcode.42m: qrcode.4gl $(PKGDIR)/qrcode_common.42m
	fglcomp -Wall -M --output-dir . qrcode.4gl

$(PKGDIR)/qrcode_read.42m: qrcode_read.4gl $(PKGDIR)/qrcode_common.42m
	fglcomp -Wall -M --output-dir . qrcode_read.4gl

$(DEMO): test_qrcode.4gl $(PKGDIR)/qrcode.42m $(PKGDIR)/qrcode_read.42m
	fglcomp -Wall -M --output-dir . test_qrcode.4gl

# --- dev dependencies -------------------------------------------------

deps:
	fglpkg install

# Fail with a useful message rather than a compiler error when the dev
# dependency has not been installed yet.
$(FGLUNIT)/FglUnit.42m:
	@echo "fglunit is not installed -- run 'make deps' first" >&2
	@exit 1

# --- tests ------------------------------------------------------------

# Each suite is a plain module of PUBLIC FUNCTION test*() cases; fglunit-gen
# writes the MAIN and the registrations, so adding a test case needs no
# bookkeeping anywhere else.
# fglcomp writes the .42m to the working directory, not beside the source,
# so --output-dir keeps the suites out of the project root.
$(TESTDIR)/%.run.42m: $(TESTDIR)/%.4gl $(LIBS) $(FGLUNIT)/FglUnit.42m
	fglcomp -Wall -M --output-dir $(TESTDIR) $<
	fglrun $(FGLUNIT)/fglunit_gen.42m $<
	fglcomp -Wall -M --output-dir $(TESTDIR) $(TESTDIR)/$*.run.4gl

test: all $(RUNNERS)
	fglrun $(FGLUNIT)/fglunit_run.42m $(RUNNERS)

test-net: all $(RUNNERS)
	QRCODE_NET_TESTS=1 fglrun $(FGLUNIT)/fglunit_run.42m $(RUNNERS)

test-junit: all $(RUNNERS)
	fglrun $(FGLUNIT)/fglunit_run.42m --junit qrcode-tests.xml $(RUNNERS)

# --- demo -------------------------------------------------------------

ARGS ?=

demo: $(DEMO)
	fglrun $(DEMO) $(ARGS)

clean:
	rm -rf com
	rm -f *.42m *.42f qrcode-tests.xml
	rm -f $(TESTDIR)/*.42m $(TESTDIR)/*.run.4gl

.PHONY: all deps test test-net test-junit demo clean
