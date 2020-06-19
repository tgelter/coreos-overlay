# Copyright 1999-2020 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI="6"

if [[ ${PV} == 9999* ]]; then
	EGIT_REPO_URI="${SELINUX_GIT_REPO:-https://anongit.gentoo.org/git/proj/hardened-refpolicy.git}"
	EGIT_BRANCH="${SELINUX_GIT_BRANCH:-master}"
	EGIT_CHECKOUT_DIR="${WORKDIR}/refpolicy"

	inherit git-r3
else
	SRC_URI="https://github.com/SELinuxProject/refpolicy/releases/download/RELEASE_${PV/./_}/refpolicy-${PV}.tar.bz2
			https://dev.gentoo.org/~perfinion/patches/${PN}/patchbundle-${PN}-${PVR}.tar.bz2"
	KEYWORDS="~amd64 -arm ~arm64 ~mips ~x86"
fi

HOMEPAGE="https://wiki.gentoo.org/wiki/Project:SELinux"
DESCRIPTION="SELinux policy for core modules"

IUSE="systemd +unconfined"

PDEPEND="unconfined? ( sec-policy/selinux-unconfined )"
DEPEND="=sec-policy/selinux-base-${PVR}[systemd?]"
RDEPEND="$DEPEND"

MODS="application authlogin bootloader clock consoletype cron dmesg fstools getty hostname hotplug init iptables libraries locallogin logging lvm miscfiles modutils mount mta netutils nscd portage raid rsync selinuxutil setrans ssh staff storage su sysadm sysnetwork systemd tmpfiles udev userdomain usermanage unprivuser xdg"
LICENSE="GPL-2"
SLOT="0"
S="${WORKDIR}/"

# Code entirely copied from selinux-eclass (cannot inherit due to dependency on
# itself), when reworked reinclude it. Only postinstall (where -b base.pp is
# added) needs to remain then.

pkg_pretend() {
	for i in ${POLICY_TYPES}; do
		if [[ "${i}" == "targeted" ]] && ! use unconfined; then
			die "If you use POLICY_TYPES=targeted, then USE=unconfined is mandatory."
		fi
	done
}

src_prepare() {
	local modfiles

	if [[ ${PV} != 9999* ]]; then
		einfo "Applying SELinux policy updates ... "
		eapply -p0 "${WORKDIR}/0001-full-patch-against-stable-release.patch"
	fi

	eapply_user

	# Collect only those files needed for this particular module
	for i in ${MODS}; do
		modfiles="$(find ${S}/refpolicy/policy/modules -iname $i.te) $modfiles"
		modfiles="$(find ${S}/refpolicy/policy/modules -iname $i.fc) $modfiles"
	done

	for i in ${POLICY_TYPES}; do
		mkdir "${S}"/${i} || die "Failed to create directory ${S}/${i}"
		cp "${S}"/refpolicy/doc/Makefile.example "${S}"/${i}/Makefile \
			|| die "Failed to copy Makefile.example to ${S}/${i}/Makefile"

		cp ${modfiles} "${S}"/${i} \
			|| die "Failed to copy the module files to ${S}/${i}"
	done
}

src_compile() {
	for i in ${POLICY_TYPES}; do
		emake BINDIR="${ROOT}/usr/bin" NAME=$i SHAREDIR="${ROOT%/}"/usr/share/selinux \
			LD_LIBRARY_PATH="${ROOT}/usr/lib64:${LD_LIBRARY_PATH}" -C "${S}"/${i}
	done
}

src_install() {
	local BASEDIR="/usr/share/selinux"

	for i in ${POLICY_TYPES}; do
		for j in ${MODS}; do
			einfo "Installing ${i} ${j} policy package"
			insinto ${BASEDIR}/${i}
			doins "${S}"/${i}/${j}.pp
		done
	done
}
