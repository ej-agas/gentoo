# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit pax-utils python-utils-r1

PYPY_PV=${PV%_p*}
MY_P=pypy2.7-v${PYPY_PV/_}
PATCHSET="pypy2.7-gentoo-patches-${PV/_rc/rc}"

DESCRIPTION="A fast, compliant alternative implementation of the Python language"
HOMEPAGE="https://www.pypy.org/"
SRC_URI="https://buildbot.pypy.org/pypy/${MY_P}-src.tar.bz2
	https://dev.gentoo.org/~mgorny/dist/python/${PATCHSET}.tar.xz"
S="${WORKDIR}/${MY_P}-src"

LICENSE="MIT"
# pypy -c 'import sysconfig; print sysconfig.get_config_var("SOABI")'
SLOT="0/73"
KEYWORDS="~amd64 ~arm64 ~ppc64 ~x86 ~amd64-linux ~x86-linux"
IUSE="bzip2 gdbm +jit ncurses sqlite tk"

RDEPEND="
	|| (
		>=dev-python/pypy-exe-${PYPY_PV}:${PYPY_PV}[bzip2?,ncurses?]
		>=dev-python/pypy-exe-bin-${PYPY_PV}:${PYPY_PV}
	)
	dev-libs/openssl:0=
	gdbm? ( sys-libs/gdbm:0= )
	sqlite? ( dev-db/sqlite:3= )
	tk? (
		dev-lang/tk:0=
		dev-tcltk/tix:0=
	)
	!<dev-python/pypy-bin-7.3.0:0"
DEPEND="${RDEPEND}"

src_prepare() {
	local PATCHES=(
		"${WORKDIR}/${PATCHSET}"
	)
	default
}

src_compile() {
	# copy over to make sys.prefix happy
	cp -p "${BROOT}"/usr/lib/pypy2.7/pypy-c-${PYPY_PV} pypy-c || die
	cp -p "${BROOT}"/usr/lib/pypy2.7/include/${PYPY_PV}/* include/ || die
	# (not installed by pypy)
	rm pypy/module/cpyext/include/_numpypy/numpy/README || die
	mv pypy/module/cpyext/include/* include/ || die
	mv pypy/module/cpyext/parse/*.h include/ || die
	pax-mark m pypy-c

	# verify the subslot
	local soabi=$(./pypy-c -c 'import sysconfig; print sysconfig.get_config_var("SOABI")')
	[[ ${soabi#pypy-} == ${SLOT#*/} ]] || die "update subslot to ${soabi}"

	einfo "Generating caches and CFFI modules ..."

	# Generate Grammar and PatternGrammar pickles.
	./pypy-c -c "import lib2to3.pygram, lib2to3.patcomp; lib2to3.patcomp.PatternCompiler()" \
		|| die "Generation of Grammar and PatternGrammar pickles failed"

	# Generate cffi modules
	# Please keep in sync with pypy/tool/build_cffi_imports.py!
	cffi_targets=( pypy_util ssl audioop syslog pwdgrp resource )
	use gdbm && cffi_targets+=( gdbm )
	use ncurses && cffi_targets+=( curses )
	use sqlite && cffi_targets+=( sqlite3 )
	use tk && cffi_targets+=( tkinter/tklib )

	local t
	# all modules except tkinter output to .
	# tkinter outputs to the correct dir ...
	cd lib_pypy || die
	for t in "${cffi_targets[@]}"; do
		# tkinter doesn't work via -m
		../pypy-c "_${t}_build.py" || die "Failed to build CFFI bindings for ${t}"
	done

	# Verify that CFFI module list is up-to-date
	local expected_cksum=2d3acf18
	local local_cksum=$(../pypy-c -c '
from pypy_tools.build_cffi_imports import cffi_build_scripts as x;
import binascii, json;
print("%08x" % (binascii.crc32(json.dumps(x)),))')
	if [[ ${local_cksum} != ${expected_cksum} ]]; then
		die "Please verify cffi_targets and update checksum to ${local_cksum}"
	fi

	# Cleanup temporary objects
	find -name "_cffi_*.[co]" -delete || die
	find -type d -empty -delete || die
}

src_test() {
	# (unset)
	local -x PYTHONDONTWRITEBYTECODE=
	local -x COLUMNS=80

	local ignored_tests=(
		# network
		--ignore=lib-python/2.7/test/test_urllibnet.py
		--ignore=lib-python/2.7/test/test_urllib2net.py
		# lots of free space
		--ignore=lib-python/2.7/test/test_zipfile64.py

		# broken by expat-2.4.5
		--ignore=lib-python/2.7/test/test_minidom.py
		--ignore=lib-python/2.7/test/test_xml_etree.py
		--ignore=lib-python/2.7/test/test_xml_etree_c.py
	)

	./pypy-c ./pypy/test_all.py --pypy=./pypy-c -vv \
		"${ignored_tests[@]}" lib-python || die
}

src_install() {
	local dest=/usr/lib/pypy2.7
	einfo "Installing PyPy ..."
	dosym pypy-c-${PYPY_PV} "${dest}/pypy-c"
	insinto "${dest}"
	# preserve mtimes to avoid obsoleting caches
	insopts -p
	doins -r include lib_pypy lib-python

	# replace copied headers with symlinks
	for x in "${BROOT}"/usr/lib/pypy2.7/include/${PYPY_PV}/*; do
		dosym "${PYPY_PV}/${x##*/}" "${dest}/include/${x##*/}"
	done

	dosym ../lib/pypy2.7/pypy-c /usr/bin/pypy
	dodoc README.rst

	if ! use gdbm; then
		rm -r "${ED}${dest}"/lib_pypy/gdbm.py \
			"${ED}${dest}"/lib-python/*2.7/test/test_gdbm.py || die
	fi
	if ! use sqlite; then
		rm -r "${ED}${dest}"/lib-python/*2.7/sqlite3 \
			"${ED}${dest}"/lib_pypy/_sqlite3.py \
			"${ED}${dest}"/lib-python/*2.7/test/test_sqlite.py || die
	fi
	if ! use tk; then
		rm -r "${ED}${dest}"/lib-python/*2.7/{idlelib,lib-tk} \
			"${ED}${dest}"/lib_pypy/_tkinter \
			"${ED}${dest}"/lib-python/*2.7/test/test_{tcl,tk,ttk*}.py || die
	fi

	local -x EPYTHON=pypy
	local -x PYTHON=${ED}${dest}/pypy-c-${PYPY_PV}
	# temporarily copy to build tree to facilitate module builds
	cp -p "${BROOT}${dest}/pypy-c-${PYPY_PV}" "${PYTHON}" || die

	echo "EPYTHON='${EPYTHON}'" > epython.py || die
	python_moduleinto /usr/lib/pypy2.7/site-packages
	python_domodule epython.py

	einfo "Byte-compiling Python standard library..."
	python_optimize "${ED}${dest}"

	# remove to avoid collisions
	rm "${PYTHON}" || die
}
