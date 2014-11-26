VERSION := 1.1
PACKAGE := status

PV = $(PACKAGE)-$(VERSION)

all: $(PV).tar

.PHONY: $(PV).tar

$(PV).tar: status-pkg.el
	@rm -rf $(PV)
	mkdir $(PV)
	cp *.el *.png *.py $(PV)
	tar -cf $(PV).tar $(PV)
	rm -rf $(PV)

status-pkg.el: status-pkg.el.in Makefile
	sed 's/@VERSION@/$(VERSION)/' < status-pkg.el.in > tmp
	mv tmp status-pkg.el

