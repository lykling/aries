# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=5
PYTHON_COMPAT=( python{2_6,2_7} )
PYTHON_REQ_USE='sqlite?'
inherit eutils unpacker versionator distutils vcs-snapshot

DESCRIPTION="A next-generation open source cloud storage system, with advanced support for file syncing, privacy protection and teamwork"
HOMEPAGE="http://seafile.com/home/"
BASE_URL="http://seafile.googlecode.com/files"
MY_P="seafile-server_${PV}"
ARCH_NAME_I386="${MY_P}_i386.tar.gz"
ARCH_NAME_AMD64="${MY_P}_x86-64.tar.gz"
ARCH_NAME="${MY_P}_x86-64.tar.gz"
SRC_URI="amd64? ( ${BASE_URL}/${MY_P}_x86-64.tar.gz )
	x86? ( ${BASE_URL}/${MY_P}_i386.tar.gz )"

LICENSE="GPL-3 Apache"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="-postgres +mysql +apache -nginx"

DEPEND="virtual/python-imaging
	dev-python/simplejson
	dev-python/setuptools
	dev-db/sqlite:3
	postgres? ( dev-python/psycopg:2 )
	mysql? ( >=dev-python/mysql-python-1.2.3 )
	apache? ( www-servers/apache:2 )
	nginx? ( www-servers/nginx dev-python/flup )"
RDEPEND="${DEPEND}
	sys-libs/libselinux"

S="${WORKDIR}"

src_unpack() {
	local archpkg="${ARCH_NAME}"
	if use amd64; then
		archpkg="${ARCH_NAME_AMD64}"
	fi
	if use x86; then
		archpkg="${ARCH_NAME_I386}"
	fi
	unpack "${archpkg}"
}

src_prepare() {
	true;
}

src_compile() {
	true;
}

src_install() {
	local archpkg="${ARCH_NAME}"
	if use amd64; then
		archpkg="${ARCH_NAME_AMD64}"
	fi
	if use x86; then
		archpkg="${ARCH_NAME_I386}"
	fi
	into /opt/seafile/${MY_P//_/-}/seafile
	dobin ${MY_P//_/-}/seafile/bin/* || die

	exeinto /opt/seafile/${MY_P//_/-}
	doexe ${MY_P//_/-}/*.sh || die

	insinto /opt/seafile
	doins -r ${MY_P//_/-} || die

	insinto /opt/seafile/installed
	doins -r ${DISTDIR}/${archpkg} || die

	newinitd ${FILESDIR}/seafile-initd seafile
	if use nginx; then
		insinto /etc/nginx/vhosts
		doins ${FILESDIR}/seafile-nginx.conf 

		sed -e "s/apache/nginx"
	fi
}

pkg_postinst() {
	elog
	elog "init script: /etc/init.d/seafile"
	elog
	elog "Setup:"
	elog "emerge --config =${CATEGORY}/${PF}"
	elog
	elog "see more in https://github.com/haiwen/seafile/wiki"
}

pkg_postrm() {
	elog
}

pkg_config() {
	cd /opt/seafile/${MY_P//_/-}
	chmod +x /opt/seafile/${MY_P//_/-}/seafile/bin/*
	sh ./setup-seafile.sh
	if [[ $? != 0 ]]; then
		eerror "config fail!"
	else
		elog "config directorys:"
		elog "	server: /opt/seafile/ccnet"
		elog "	database: /opt/seafile/seafile-data"
		elog "	seahub: /opt/seafile/${MY_P//_/-}/seahub"
	fi
	if use postgres; then
		cat >> /opt/seafile/ccnet/ccnet.conf << EOF

[Database]
ENGINE=pgsql
HOST=localhost
USER=seafile
PASSWD=seafile
DB=ccnet_db
EOF
		elog
		sed -e "s/type=.*/type=pgsql/" -i /opt/seafile/seafile-data/seafile.conf
		sed -e "s/host=.*/host=localhost/" -i /opt/seafile/seafile-data/seafile.conf
		sed -e "s/user=.*/user=seafile/" -i /opt/seafile/seafile-data/seafile.conf
		sed -e "s/password=.*/password=seafile/" -i /opt/seafile/seafile-data/seafile.conf
		sed -e "s/db_name=.*/db_name=seafile_db/" -i /opt/seafile/seafile-data/seafile.conf
		elog
		cat >> /opt/seafile/seahub_settings.py << EOF

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME' : 'seahub_db',
        'USER' : 'seafile',
        'PASSWORD' : 'seafile',
        'HOST' : 'localhost',
    }
}
EOF
		local INSTALLPATH="/opt/seafile/${MY_P//_/-}"
		elog "you should sync your postgres database by following commands"
		elog "	export CCNET_CONF_DIR=/opt/seafile/ccnet"
		elog "	export SEAFILE_CONF_DIR=/opt/seafile/seafile-data"
		elog "	INSTALLPATH=${INSTALLPATH}"
		elog "	export PYTHONPATH=\${INSTALLPATH}/seafile/lib/python2.6/site-packages:\${INSTALLPATH}/seafile/lib64/python2.6/site-packages:\${INSTALLPATH}/seahub/thirdpart:\$PYTHONPATH"
		elog "	cd /opt/seafile/${MY_P//_/-}/seahub"
		elog "	python manage.py syncdb"
		elog "and create an admin user for seahub"
		elog "	cd /opt/seafile/${MY_P//_/-}/seahub"
		elog "	python manage.py createsuperuser"
		elog "then start seahub with command:"
		elog "	seahub.sh start-fastcgi"
	fi
	if use nginx; then
		mkdir -p /etc/nginx/vhosts
		sed -e "s/\${MY_P}/${MY_P//_/-}/g" -i /etc/nginx/vhosts/seafile-nginx.conf
	fi
}
