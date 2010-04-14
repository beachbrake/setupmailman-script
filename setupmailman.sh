#!/bin/bash

# Store the current directory
SCRIPTDIR=`pwd`

# Postfix Config file
POSTFIXCONF=/etc/postfix/master.cf

# Mailman Apache Setup
MAILMANAPACHECONF=/etc/mailman/apache.conf
# Apache sites-enabled setup
APACHESITES=/etc/apache2/sites-enabled/mailman

# Mailman DIRs
MAILMANCONFDIR=/etc/mailman
MAILMANDATADIR=/var/lib/mailman
MAILMANCODEDIR=/usr/lib/mailman


function install_python-markdown {
    echo "Installing python-markdown"
    aptitude install -y python-markdown >> setupmailman.log
}

function install_python-psycopg2 {
    echo "Installing python-psycopg2"
    aptitude install -y python-psycopg2 >> setupmailman.log
}

function install_python-storm {
    echo "Installing python-storm"
    aptitude install -y python-storm >> setupmailman.log
}

function install_postgresql {
    echo "Installing PostgreSQL"
    aptitude install -y postgresql >> setupmailman.log
}

function install_mailman {
    echo "Intalling MailMan, Postfix and Apache2"
    aptitude install -y mailman postfix
}

function install_bazaar {
    echo "Installing Bazaar"
    aptitude install -y bzr >> setupmailman.log
}

function install_mailx {
    echo "Installing mailx"
    aptitude install -y heirloom-mailx >> setupmailman.log
}

function edit_postgres {
echo "Creating PostgreSQL user mailman"
sudo -u postgres createuser -s -d -R mailman

echo "Altering Role"
sudo -u postgres psql << EOF
alter user mailman password 'mailman';
EOF
}

function edit_postfix {
    echo "Editing Postfix Configuration"
    cat postfix.cnf.add >> $POSTFIXCONF

    echo "Restarting Postfix"
    /etc/init.d/postfix restart
}

function edit_apache {
    echo "Adding MailMan config to Apache sites"
    cp $MAILMANAPACHECONF $APACHESITES

    echo "Restarting Apache"
    /etc/init.d/apache2 restart
}

function setup_mailman {
    echo "Creating directory in Mailman Code Directory"
    mkdir $MAILMANCODEDIR/templates

    echo "Copying English templates"
    mv $MAILMANCONFDIR/en $MAILMANCODEDIR/templates/

    echo "Moving old templates symlink"
    mv $MAILMANDATADIR/templates $MAILMANDATADIR/templates.old

    echo "Creating new symbolic link to templates"
    ln -s $MAILMANCODEDIR/templates $MAILMANDATADIR/templates

    echo "Shifting to MailMan Code Directory"
    cd $MAILMANCODEDIR

    echo "Checking out Systers Mailman code. This could take a while."
    bzr checkout lp:systers .

    echo "Applying Patch"
    patch $MAILMANCODEDIR/Mailman/mm_cfg.py $SCRIPTDIR/mm_cfg.patch

    echo "Fixing permissions"
    $MAILMANCODEDIR/bin/check_perms -f >> setupmailman.log

    echo "Creating newlist mailman"
    newlist -q mailman root@localhost.localdomain 1234 >> setupmailman.log

    echo "Creating newlist systers-admin"
    newlist -q systers-admin root@localhost.localdomain 1234 >> setupmailman.log

    echo "Copying and generating new alias DB"
    $MAILMANCODEDIR/bin/genaliases -q >> /etc/aliases
    newaliases

    echo "Starting Mailman"
    /etc/init.d/mailman start
}



echo "Starting install process"

if [ ! -e setupmailman.log ]; then
    touch setupmailman.log;
fi



echo ""
echo "Will install all packages now"

install_python-markdown
install_python-psycopg2
install_python-storm
install_postgresql
install_mailman
install_bazaar
install_mailx



echo ""
echo "Will edit all configuration now"

edit_postgres
edit_postfix
edit_apache



echo ""
echo "Will setup mailman now"
setup_mailman



echo ""
echo "Done!"
