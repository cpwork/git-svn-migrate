#!/bin/bash

# Copyright 2010 John Albin Wilkins.
# Available under the GPL v2 license. See LICENSE.txt.

#Heavily modified by Cole Palmer to migrate to functions

script=`basename $0`;

# Set defaults for any optional parameters or arguments.
url_file='';
authors_file='';
tmp_file="tmp_authors_transform.txt";

function pause()
{
    read -p "
    ${1}
    Press ENTER to continue ...
" -s;
}

function print_debug_info()
{
    echo "";
    echo "----DEBUG INFO----";
    echo "$script";
    echo "URL_FILE = ${url_file}";
    echo "authors_file = ${authors_file}";
    echo "----DEBUG INFO----";
    echo "";
}

function print_usage()
{
    echo "
    USAGE: $script --url-file=<filename> [--authors_file=<filename>]

    For more info, see: $script --help
";
}

function print_help()
{
    echo "
    $script - Retrieves Subversion usernames from a list of URLs
              for use in a git-svn-migrate (or git-svn) conversion.

SYNOPSIS
    $script [options]

DESCRIPTION
    The $script utility creates a list of Subversion committers
    from a list of Subversion URLs from thto Git using the
    specified authors list. The url-file parameter is required.
    If the authors_file parameter is not specified the authors
    will be displayed in standard output.

    The following options are available:

    -u <filename>, --url-file=<filename>, --url-file <filename>
        Specify the file containing the Subversion repository list.

    -a <filename>, --authors-file=<filename>, --authors-file <filename>,
        -d <filename>, --destination=<filename>, --destination <filename>
        Specify the file to store the authors transformation data into.
        Defaults to standard output.

    ---------------------------------------------------------------------
    -------------------------------REMOVED-------------------------------
    ---------------------------------------------------------------------

    -u=<filename>, -a=<filename>, -d=<filename>
        Unable to find sufficient documentation to port these parameters
        to BASH's getopts.

    ---------------------------------------------------------------------
    -------------------------------REMOVED-------------------------------
    ---------------------------------------------------------------------


BASIC EXAMPLES
    # Use the long parameter names
    $script --url-file=my-repository-list.txt --authors-file=authors-file.txt

    # Use the long parameter names and implicit authors-file parameter
    $script --url-file=my-repository-list.txt authors-file.txt

    # Use short parameter names and redirect standard output
    $script -u my-repository-list.txt > authors-file.txt

SEE ALSO
    git-svn-migrate.sh
";
}

function process_parameters()
{
    local OPTIND=1; # Reset is necessary if getopts was used previously in the script.
    local opt;

    while getopts "ha:u:d:-:" opt; do
        case "${opt}" in
            u)      url_file="${OPTARG}";;
            a)      authors_file="${OPTARG}";;
            d)      authors_file="${OPTARG}";;
            h)      print_help; exit;;

            #Handle long style arguments
            -)  case "${OPTARG}" in
                    url-file)       val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); url_file="${val}";;
                    url-file=*)     val="${OPTARG#*=}"; url_file="${val}";;

                    authors-file)   val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); authors_file="${val}";;
                    authors-file=*) val="${OPTARG#*=}"; authors_file="${val}";;

                    destination)    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 )); authors_file="${val}";;
                    destination=*)  val="${OPTARG#*=}"; authors_file="${val}";;

                    help)           print_help; exit;;
                    usage)          print_usage; exit;;

                    *)
                        if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                            echo "Invalid option --${OPTARG}" >&2
                        fi
                        ;;
                esac;;

            \?)     echo "Invalid option: -$OPTARG" >&2;;
        esac
    done

    #maintain backward compatibility with option
    #to set the destination without specifying a parameter
    #NOTE: MUST BE FINAL PARAMETER
    shift $(($OPTIND - 1))
    printf "Remaining arguments are: %s\n" "$*"
    if [[ "$*" != '' ]]; then
        authors_file="$*";
    fi
}

function validate_input()
{
    # Check for required parameters.
    if [[ "${url_file}" == '' ]]; then
        print_usage;
        exit 1;
    fi

    # Check for valid file.
    if [[ ! -f "${url_file}" ]]; then
        echo "Specified URL file \"${url_file}\" does not exist or is not a file." >&2;
        echo $usage >&2;
        exit 1;
    fi
}

function process_authors()
{
    # Process each URL in the repository list.
    touch $tmp_file;
    sed -e 's/#.*//; /^[[:space:]]*$/d' "${url_file}" | while read line
    do
        # Check for 2-field format:  Name [tab] URL
        name=`echo $line | awk '{print $1}'`;
        url=`echo $line | awk '{print $2}'`;
        # Check for simple 1-field format:  URL
        if [[ "${url}" == '' ]]; then
        url="{$name}";
        name=`basename ${url}`;
        fi
        # Process the log of each Subversion URL.
        echo "Processing \"${name}\" repository at ${url}..." >&2;
        /bin/echo -n "  " >&2;
        svn log -q "${url}" | awk -F '|' '/^r/ {sub("^ ", "", $2); sub(" $", "", $2); print $2" = "$2" <"$2">"}' | sort -u >> "${tmp_file}";
        echo "Done." >&2;
    done
}

function save_authors_transform()
{
    # Process temp file one last time to show results.
    if [[ "${authors_file}" == '' ]]; then
        # Display on standard output.
        cat "${tmp_file}" | sort -u;
    else
        # Output to the specified destination file.
        cat "${tmp_file}" | sort -u > "${authors_file}";
    fi
    rm "$tmp_file";
}

#Actual script execution starts here
process_parameters "$@";
#print_debug_info; #uncomment to verify parameters passed to script
validate_input;
process_authors;
save_authors_transform;