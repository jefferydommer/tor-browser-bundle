all: clean prep build

build:
	./mkbundle-linux.sh
	./mkbundle-windows.sh
	./mkbundle-mac.sh
	./hash-bundles.sh

prep:
	./check-prerequisites.sh
	torsocks ./fetch-inputs.sh ../../gitian-builder/inputs/

clean:
	rm -f ../../gitian-builder/inputs/*gbuilt*
	rm -f ../../gitian-builder/inputs/*.yml
	rm -f ../../gitian-builder/inputs/bundle.inputs
	rm -f ../../gitian-builder/inputs/versions

vmclean:
	rm -rf ../../gitian-builder/*.qcow2

distclean: vmclean
	rm -rf ../../gitian-builder/inputs/*
