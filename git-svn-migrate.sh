#!/bin/bash

# Copyright 2010-2011 John Albin Wilkins and contributors.
# Available under the GPL v2 license. See LICENSE.txt.

#Heavily modified by Cole Palmer to migrate to functions
#and use BASH's builtin getopts.

script=`basename $0`;
dir=`pwd`/`dirname $0`;

# Set defaults for any optional parameters or arguments.
url_file='';
authors_file='';
destination='.';
ignore_file='';
gitinit_params='';
gitsvn_params='';
no_stdlayout='';
is_quiet=''
remote_prefix="origin/"


function pause()
{
    read -p "
    ${1}
    Press ENTER to continue ...
" -s
}

function print_usage()
{
    echo "
    USAGE: $script $script --url-file=my-repository-list.txt --authors-file=authors-file.txt [--destination=/var/git]

    For more info, see: $script --help
"
}

function print_help()
{
    echo "
    $script - Migrates Subversion repositories to Git

SYNOPSIS
    $script [options] [arguments]

DESCRIPTION
    The $script utility migrates a list of Subversion
    repositories to Git using the specified authors list. The
    url-file and authors-file parameters are required. The
    destination folder is optional and can be specified as an
    argument or as a named parameter.

    The following options are available:

    -u <filename>, --url-file=<filename>, --url-file <filename>
        Specify the file containing the Subversion repository list.

    -a <filename>, --authors-file=[filename], --authors-file [filename]
        Specify the file containing the authors transformation data.

    -d <folder>, --destination=<folder>, --destination <folder>
        The directory where the new Git repositories should be
        saved. Defaults to the current directory.

    -i <filename>, --ignore-file=<filename>, --ignore-file <filename>
        The location of a .gitignore file to add to all repositories.

    -T <trunk_subdir> --trunk=<trunk_subdir>, --trunk <trunk_subdir>
    -t <tags_subdir> --tags=<tags_subdir>, --tags <tags_subdir>
    -b <branches_subdir>, --branches=<branches_subdir>, --branches <branches_subdir>
        These are optional command-line options for init.
        git svn --help for more info.
 
    -p <\"prefix\">, --prefix=<\"prefix\">, --prefix <\"prefix\">
        Set the remote references prefix for git svn. Defaults to
        \"origin/\" to force old versions of git to match git 2.0+
        behavior. See git svn --help for more information.

    --no-minimize-url
        Pass the '--no-minimize-url' parameter to git-svn. See
        git svn --help for more info.

    --quiet
        By default this script is rather verbose since it outputs each revision
        number as it is processed from Subversion. Since conversion can sometimes
        take hours to complete, this output can be useful. However, this option
        will surpress that output.

    --no-metadata
        By default, all converted log messages will include a line starting with
        'git-svn-id:' Use this option to get rid of that data.
        This option is **NOT** recommended as it makes it difficult to
        track down old references to SVN revision numbers in existing
        documentation, bug reports and archives. If you plan to
        eventually migrate from SVN to git and are certain about
        dropping SVN history, consider git-filter-branch(1) instead.
        See git svn --help for a fuller discussion on this option.

    --no-stdlayout
        By default, $script passes the --stdlayout option to
        git-svn clone. This option suppresses that behavior. See git svn --help
        for more information.

    --shared[=(false|true|umask|group|all|world|everybody|0xxx)]
        Specify that the generated git repositories are to be shared amongst
        several users. See git init --help for more info about this option.

    --use-svm-props
        See git svn --help for more info.

    --use-svnsync-props
        See git svn --help for more info.


        Any additional options are ignored at this time. Feel free to
        ipmrove this script and get this working again.



    ---------------------------------------------------------------------
    -------------------------------REMOVED-------------------------------
    ---------------------------------------------------------------------

    -u=<filename>, -a=<filename>, -d=<filename>, -i=<filename>,
    -b=<branches_subdir>, -t=<tags_subdir>, -T=<trunk_subdir>,
        Unable to find sufficient documentation to port these parameters
        to BASH's getopts.


        Any additional options are assumed to be git-svn options
        and will be passed along to that utility directly.
        See git svn --help for more info about its options.

    ---------------------------------------------------------------------
    -------------------------------REMOVED-------------------------------
    ---------------------------------------------------------------------



BASIC EXAMPLES
    # Use the long parameter names
    $script --url-file=my-repository-list.txt --authors-file=authors-file.txt --destination=/var/git

    # Use short parameter names
    $script -u my-repository-list.txt -a authors-file.txt -d /var/git

SEE ALSO
    fetch-svn-authors.sh
"
}

function process_parameters()
{
    local OPTIND=1; # Reset is necessary if getopts was used previously in the script.
    local opt;

    while getopts "hvqsa:u:d:-:i:T:t:b:" opt; do
        case "${opt}" in
            u)      url_file="${OPTARG}";;
            a)      authors_file="${OPTARG}";;
            d)      destination="${OPTARG}";;
            i)      ignore_file="${OPTARG}";;
            T)      gitsvn_params="${gitsvn_params} --trunk=${OPTARG}";;
            t)      gitsvn_params="${gitsvn_params} --tags=${OPTARG}";;
            b)      gitsvn_params="${gitsvn_params} --branches=${OPTARG}";;
            s)      no_stdlayout='';;
            p)      remote_prefix="${OPTARG}";;
            q)      is_quiet="true";;
            v)      is_quiet='';;
            h)      print_help; exit;;

            #Handle long style arguments
            -)  case "${OPTARG}" in
                    url-file)           val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); url_file="${val}";;
                    url-file=*)         val="${OPTARG#*=}"; url_file="${val}";;

                    authors-file)       val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); authors_file="${val}";;
                    authors-file=*)     val="${OPTARG#*=}"; authors_file="${val}";;

                    destination)        val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); destination="${val}";;
                    destination=*)      val="${OPTARG#*=}"; destination="${val}";;

                    ignore-file)        val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); ignore_file="${val}";;
                    ignore-file=*)      val="${OPTARG#*=}"; ignore_file="${val}";;

                    prefix)        val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); remote_prefix="${val}";;
                    prefix=*)      val="${OPTARG#*=}"; remote_prefix="${val}";;

                    trunk)              val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); gitsvn_params="${gitsvn_params} --trunk=${OPTARG}";;
                    trunk=*)            val="${OPTARG#*=}"; gitsvn_params="${gitsvn_params} --trunk=${OPTARG}";;

                    tags)               val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); gitsvn_params="${gitsvn_params} --tags=${OPTARG}";;
                    tags=*)             val="${OPTARG#*=}"; gitsvn_params="${gitsvn_params} --tags=${OPTARG}";;

                    branches)           val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); gitsvn_params="${gitsvn_params} --branches=${OPTARG}";;
                    branches=*)         val="${OPTARG#*=}"; gitsvn_params="${gitsvn_params} --branches=${OPTARG}";;

                    no-minimize-url)    gitsvn_params="$gitsvn_params --no-minimize-url";;

                    no-metadata)        gitsvn_params="$gitsvn_params --no-metadata";;
                    use-svm-props)      gitsvn_params="$gitsvn_params --use-svm-props";;
                    use-svnsync-props)  gitsvn_params="$gitsvn_params --use-svnsync-props";;
                    no-stdlayout)       no_stdlayout="true";;
                    quiet)              is_quiet="true";;
                    verbose)            is_quiet='';;

                    shared)             val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ));
                                        if [[ "${val}" == '' ]]; then
                                            gitinit_params="--shared";
                                        else
                                            gitinit_params="--shared=${val}";
                                        fi
                                        ;;

                    shared=*)           val="${OPTARG#*=}";
                                        if [[ "${val}" == '' ]]; then
                                            gitinit_params="--shared";
                                        else
                                            gitinit_params="--shared=${val}";
                                        fi
                                        ;;

                    help)               print_help; exit;;
                    usage)              print_usage; exit;;

                    *) 
                        # # Pass any unknown parameters to git-svn directly.
                        # val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ));
                        # if [[ ${val} == '' ]]; then
                        #     gitsvn_params="${gitsvn_params} --${OPTARG}";
                        # elif [[ ${#parameter} -gt 1 ]]; then
                        #     gitsvn_params="${gitsvn_params} --${parameter}=${val}";
                        # else
                        #     gitsvn_params="${gitsvn_params} --${OPTARG} ${val}";
                        # fi
                        ;;
                esac;;

            *) 
                # # Pass any unknown parameters to git-svn directly.
                # val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ));
                # if [[ ${val} == '' ]]; then
                #     gitsvn_params="${gitsvn_params} --${opt}";
                # elif [[ ${#parameter} -gt 1 ]]; then
                #     gitsvn_params="${gitsvn_params} --${parameter}=${val}";
                # else
                #     gitsvn_params="${gitsvn_params} --${opt} ${val}";
                # fi
                ;;

            \?)     echo "Invalid option: -$OPTARG" >&2;;
        esac
    done
}

function validate_parameters()
{
    # Check for required parameters.
    if [[ "${url_file}" == '' || "${authors_file}" == '' ]]; then
        print_usage;
        exit 1;
    fi

    #Change to absolute paths
    url_file="${PWD}/${url_file}";
    authors_file="${PWD}/${authors_file}";

    # Check for valid files.
    if [[ ! -f "${url_file}" ]]; then
        echo "Specified URL file \"${url_file}\" does not exist or is not a file." >&2;
        print_usage;
        exit 1;
    fi

    if [[ ! -f "${authors_file}" ]]; then
        echo "Specified authors file \"${authors_file}\" does not exist or is not a file." >&2;
        print_usage;
        exit 1;
    fi
}

function process_svn_repositories()
{
    # Process each URL in the repository list.
    working_dir=`pwd`;
    tmp_destination="`mktemp --directory --dry-run ${working_dir}/tmp-git-repo_XXXXXXXX`";
    mkdir -p "${destination}";
    destination=`cd "${destination}"; pwd`; #Absolute path.

    # Ensure temporary repository location is empty.
    if [[ -e "${tmp_destination}" ]]; then
        echo "Temporary repository location \"${tmp_destination}\" already exists. Exiting." >&2;
        exit 1;
    fi

    mkdir -p "${tmp_destination}";

    sed -e 's/#.*//; /^[[:space:]]*$/d' $url_file | while read line
    do
        # Check for 2-field format:  Name [tab] URL
        name=`echo $line | awk '{print $1}'`;
        url=`echo $line | awk '{print $2}'`;

        #enhancement by Shan Ul Haq. added a third parameter to have git remote repository
        # format : Name [tab] SVN URL [tab] GIT url
        git_remote=`echo $line | awk '{print $3}'`;

        #non-standard layout for the svn repository. if this is available then use it. otherwise use standard layout.
        #provide the non-standar layout as 4th parameter in this format: "Branches|Tags|Trunk"
        non_standard_layout=`echo $line | awk '{print $4}'`;
        set -- "${non_standard_layout}" 
        IFS="|"; declare -a Array=($*) 
        layout_branches="${Array[0]}" 
        layout_tags="${Array[1]}"
        layout_trunk="${Array[2]}"

        # Check for simple 1-field format:  URL
        if [[ $url == '' ]]; then
            url="${name}";
            name=`basename $url`;
        fi

        # Process each Subversion URL.
        echo >&2;
        echo "At $(date)..." >&2;
        echo "Processing \"${name}\" repository at $url..." >&2;
        echo "Description: ${name}" >&2;

        # Init the final bare repository.
        mkdir -p "${destination}/${name}.git";
        cd "${destination}/${name}.git";

        if [[ "${gitinit_params}" != '' ]]; then
            git init --bare "${gitinit_params}";
        else
            git init --bare;
        fi
        git symbolic-ref HEAD refs/heads/trunk;

        # Clone the original Subversion repository to a temp repository.
        cd "${working_dir}";
        echo "- Cloning repository..." >&2;
        git_svn_clone="git svn clone \"${url}\" --prefix=\"${remote_prefix}\" -A \"${authors_file}\" --authors-prog=\"${dir}/svn-lookup-author.sh\"  --preserve-empty-dirs --placeholder-filename=\".gitkeep\"";

        if [[ "${non_standard_layout}" == '' ]]; then
          	if [[ -z "${no_stdlayout}" ]]; then
                git_svn_clone="${git_svn_clone} --stdlayout";
          	fi
        else
        	  #if non-standard svn repo layout parameters are provided, then use those
        	  git_svn_clone="${git_svn_clone} --trunk=/${layout_trunk} --branches=/${layout_branches} --tags=/${layout_tags}";
        fi

        if [[ "${is_quiet}" != '' ]]; then
            git_svn_clone="${git_svn_clone} --quiet";
        fi            

        git_svn_clone="${git_svn_clone} ${gitsvn_params} ${tmp_destination}";
        $git_svn_clone;

        # Create .gitignore file.
        echo "- Converting svn:ignore properties into a .gitignore file..." >&2;
        if [[ "${ignore_file}" != '' ]]; then
            cp "${ignore_file}" "${tmp_destination}/.gitignore";
        fi
        cd "${tmp_destination}";
        git svn show-ignore --id trunk >> .gitignore;
        if [ -s .gitignore ]; then
            git add .gitignore;
            git commit --author="git-svn-migrate <nobody@example.org>" -m 'Convert svn:ignore properties to .gitignore.';
        fi

        # Push to final bare repository and remove temp repository.
        echo "- Pushing to new bare repository..." >&2;
        git remote add bare "${destination}/${name}.git";
        git config remote.bare.push 'refs/remotes/*:refs/heads/*';
        git push bare;
        # Push the .gitignore commit that resides on master.
        git push bare master:trunk;
        cd "${working_dir}";
        rm -r "${tmp_destination}";

        # Rename Subversion's "trunk" branch to Git's standard "master" branch.
        cd "${destination}/${name}.git";
        git branch -M trunk master;

        # Remove bogus branches of the form "name@REV".
        git for-each-ref --format='%(refname)' refs/heads | grep '@[0-9][0-9]*' | cut -d / -f 3- |
        while read ref
        do
            git branch -D "${ref}";
        done

        # Convert git-svn tag branches to proper tags.
        echo "- Converting svn tag directories to proper git tags..." >&2;
        git for-each-ref --format='%(refname)' refs/heads/tags | cut -d / -f 4 |
        while read ref
        do
            git tag -a "${ref}" -m "Convert \"${ref}\" to a proper git tag." "refs/heads/tags/${ref}";
            git branch -D "tags/${ref}";
        done

        #this is the enhancements done by Shan Ul Haq. Following code will read the remote provided in the URL list
        #and will add as origin in the said repository and will push with mirror options
        #UPDATE: only preform this action if a remote is listed in the file
        if [[ $git_remote != '' ]]; then
            git remote add origin $git_remote
            git push --mirror origin
        fi

        echo "- Conversion completed at $(date)." >&2;
    done
}

process_parameters "$@";
validate_parameters;
process_svn_repositories;