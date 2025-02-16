# Copyright 1999-2022 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit desktop flag-o-matic perl-module

DESCRIPTION="dvd::rip is a graphical frontend for transcode"
HOMEPAGE="https://www.exit1.org/dvdrip/"
SRC_URI="https://www.exit1.org/dvdrip/dist/${P}.tar.gz"

SLOT="0"
KEYWORDS="amd64 ~ppc ~ppc64 ~x86"
IUSE="ffmpeg fping mplayer ogg subtitles vcd vorbis xine xvid"

DEPEND=">=dev-perl/Event-ExecFlow-0.64
	>=dev-perl/Event-RPC-0.89
	dev-perl/Gtk2
	>=dev-perl/gtk2-ex-formfactory-0.65
	>=dev-perl/libintl-perl-1.16
	>=media-video/transcode-1.1.0[dvd,jpeg,mp3,ogg,vorbis]
	virtual/imagemagick-tools
	>=virtual/perl-podlators-2.5.3
"
RDEPEND="${DEPEND}
	x11-libs/gdk-pixbuf:2[jpeg]
	x11-libs/gtk+:2
	ffmpeg? ( media-video/ffmpeg:0 )
	fping? ( >=net-analyzer/fping-2.2 )
	mplayer? ( media-video/mplayer )
	ogg? ( media-sound/ogmtools )
	subtitles? ( media-video/subtitleripper )
	vcd? (
		media-video/transcode[mjpeg]
		>=media-video/mjpegtools-1.6.0
	)
	vorbis? ( media-sound/vorbis-tools )
	xine? ( media-video/xine-ui )
	xvid? ( media-video/xvid4conf )
	>=media-video/lsdvd-0.15
"

DOCS=( "Changes*" Credits README TODO )

PATCHES=(
	"${FILESDIR}"/${P}-r5-fix_parallel_make.patch
)

src_prepare() {
	# bug #333739
	sed -i -e 's:$(CC):$(CC) $(OTHERLDFLAGS):' src/Makefile || die

	default

	# Fix default device for >=udev-180, bug #224559
	sed -i -e 's:/dev/dvd:/dev/cdrom:' lib/Video/DVDRip/Config.pm || die
}

src_configure() {
	filter-flags -ftracer

	# bug #255269
	export SKIP_UNPACK_REQUIRED_MODULES=1

	perl-module_src_configure
}

src_install() {
	newicon lib/Video/DVDRip/icon.xpm dvdrip.xpm
	make_desktop_entry dvdrip dvd::rip

	perl-module_src_install
}

pkg_postinst() {
	# bug #173924
	if use fping; then
		ewarn "For dvdrip-master to work correctly with cluster mode,"
		ewarn "the fping binary must be setuid."
		ewarn ""
		ewarn "Run this command to fix it:"
		ewarn "chmod u=rwsx,g=rx,o=rx ${EROOT}/usr/sbin/fping"
		ewarn ""
		ewarn "Note that this is a security risk when enabled."
	fi
}
