#!/bin/sh

useradd -G wheel -e 9999-12-31 ansible
ANSIBLEHOME=`cat /etc/passwd|grep ansible|awk -F: '{print $6}'`
echo -e 'ansible\tALL=(ALL)\tNOPASSWD: ALL' >> /etc/sudoers
visudo -c
mkdir -p $ANSIBLEHOME/.ssh
echo %%SSHKEY%% >> $ANSIBLEHOME/.ssh/authorized_keys
chown -R ansible:ansible $ANSIBLEHOME/.ssh
chmod 700 $ANSIBLEHOME/.ssh
chmod 600 $ANSIBLEHOME/.ssh/authorized_keys
