PKGDIR=com/fourjs/qrcode

LIBS=\
 $(PKGDIR)/qrcode_common.42m\
 $(PKGDIR)/qrcode.42m\
 $(PKGDIR)/qrcode_read.42m

TESTS=\
 $(PKGDIR)/test_qrcode.42m

all: $(LIBS) $(TESTS)

$(PKGDIR)/qrcode_common.42m: qrcode_common.4gl
	fglcomp -Wall -M --output-dir . qrcode_common.4gl

$(PKGDIR)/qrcode.42m: qrcode.4gl $(PKGDIR)/qrcode_common.42m
	fglcomp -Wall -M --output-dir . qrcode.4gl

$(PKGDIR)/qrcode_read.42m: qrcode_read.4gl $(PKGDIR)/qrcode_common.42m
	fglcomp -Wall -M --output-dir . qrcode_read.4gl

$(PKGDIR)/test_qrcode.42m: test_qrcode.4gl $(PKGDIR)/qrcode.42m $(PKGDIR)/qrcode_read.42m
	fglcomp -Wall -M --output-dir . test_qrcode.4gl

clean::
	rm -rf com *.42m *.42f

ARGS ?=

test: $(PKGDIR)/test_qrcode.42m
	fglrun $(PKGDIR)/test_qrcode.42m $(ARGS)
