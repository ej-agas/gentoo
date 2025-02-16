# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

JAVA_PKG_IUSE="doc source"

inherit java-pkg-2 java-pkg-simple

DESCRIPTION="A toolkit for list transformations"
HOMEPAGE="http://www.glazedlists.com/"
SRC_URI="http://java.net/downloads/${PN}/${P}/${P}-source_java15.zip -> ${P}.zip"
LICENSE="|| ( LGPL-2.1 MPL-1.1 )"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE=""

RDEPEND="
	>=virtual/jre-1.8:*"

DEPEND="
	>=virtual/jdk-1.8:*"

BDEPEND="
	app-arch/unzip"

JAVA_SRC_DIR="source"

JAVA_ENCODING="ISO-8859-1"
