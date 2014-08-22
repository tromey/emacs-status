VERSION := 1.0
PACKAGE := status

PV = $(PACKAGE)-$(VERSION)

all: $(PV).tar

.PHONY: $(PV).tar

$(PV).tar: status-pkg.el
	@rm -rf $(PV)
	mkdir $(PV)
	cp *.el *.png $(PV)
	tar -cf $(PV).tar $(PV)
	rm -rf $(PV)

status-pkg.el: status-pkg.el.in
	sed 's/@VERSION@/$(VERSION)/' < status-pkg.el.in > tmp
	mv tmp status-pkg.el

