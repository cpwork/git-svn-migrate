#!/bin/bash

AUTHORS=./authors.txt
REPOS=./sample-repository-list.txt
LOG=./migration_log_`date %F_%T`.txt

(./git-svn-migrate -a ${AUTHORS} -r ${REPOS} 2>&1) | (tee -a ${LOG})
