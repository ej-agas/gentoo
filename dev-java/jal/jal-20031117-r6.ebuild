# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

JAVA_PKG_IUSE="doc source"

inherit java-pkg-2 java-pkg-simple

DESCRIPTION="Partial port of the C++ Standard Template Library"
HOMEPAGE="http://vigna.dsi.unimi.it/jal"
SRC_URI="https://dev.gentoo.org/~monsieurp/packages/${P}.tar.gz"

LICENSE="HPND"
SLOT="0"
KEYWORDS="~amd64 ~x86"

CP_DEPEND="dev-java/ant-core:0"

RDEPEND="
	${CP_DEPEND}
	>=virtual/jre-1.8:*"

DEPEND="
	${CP_DEPEND}
	>=virtual/jdk-1.8:*"

S="${WORKDIR}/${P}"

JAVA_SRC_DIR="src/jal"

src_prepare() {
	default

	# Generate sources.
	./instantiate -n byte bytes || die
	./instantiate -n short shorts || die
	./instantiate -n char chars || die
	./instantiate -n int ints || die
	./instantiate -n long longs || die
	./instantiate -n float floats || die
	./instantiate -n double doubles || die
	./instantiate Object objects || die
	./instantiate String strings || die

	mkdir -p src/jal || die
	mv bytes shorts chars ints longs floats doubles objects strings src/jal || die
}
