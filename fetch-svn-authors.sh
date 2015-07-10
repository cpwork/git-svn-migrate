#!/bin/bash

# Copyright 2010 John Albin Wilkins.
# Available under the GPL v2 license. See LICENSE.txt.

#Heavily modified by Cole Palmer to migrate to functions

script=`basename $0`;

# Set defaults for any optional parameters or arguments.
destination='';

function pause()
{
    read -p "
    ${1}
    Press ENTER to continue ...
" -s
}

function print_debug_info()
{
    echo "$script"
    echo "URL_FILE = $url_file"
    echo "destination = $destination"
}

function print_usage()
{
    echo "
    USAGE: $script --url-file=<filename> --destination=<filename>

    For more info, see: $script --help
"
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
    If the destination parameter is not specified the authors
    will be displayed in standard output.

    The following options are available:

    -u=<filename>, -u <filename>,
    --url-file=<filename>, --url-file <filename>
        Specify the file containing the Subversion repository list.

    -a=<filename>, -a <filename>,
    --authors-file=[filename], --authors-file [filename]
        Specify the file containing the authors transformation data.

    -d=<folder>, -d <folder,
    --destination=<folder>, --destination <folder>
        The directory where the new Git repositories should be
        saved. Defaults to the current directory.

BASIC EXAMPLES
    # Use the long parameter names
    $script --url-file=my-repository-list.txt --destination=authors-file.txt

    # Use short parameter names and redirect standard output
    $script -u my-repository-list.txt > authors-file.txt

SEE ALSO
    git-svn-migrate.sh
"
}

function process_parameters()
{
    OPTIND=1 # Reset is necessary if getopts was used previously in the script.

    while getopts "u:d:h" opt; do
      case $opt in
        u)      url_file=$OPTARG;;
        d)      destination=$OPTARG;;
        h)      print_help; exit;;
        
        #Handle long style arguments
        -)  case "${OPTARG}" in
                url-file)
                    #url_file=$value;;
                    val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                    echo "Parsing option: '--${OPTARG}', value: '${val}'" >&2;
                    ;;
                url-file=*)
                    #url_file=$value;;
                    val=${OPTARG#*=}
                    opt=${OPTARG%=$val}
                    echo "Parsing option: '--${opt}', value: '${val}'" >&2
                    ;;
                *)
                    if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                    fi
                    ;;
            esac;;

        \?)     echo "Invalid option: -$OPTARG" >&2;;
      esac
    done
}

process_parameters
exit;

# Process parameters.
until [[ -z "$1" ]]; do
  option=$1;
  # Strip off leading '--' or '-'.
  if [[ ${option:0:1} == '-' ]]; then
    if [[ ${option:0:2} == '--' ]]; then
      tmp=${option:2};
    else
      tmp=${option:1};
    fi
  else
    # Any argument given is assumed to be the destination folder.
    tmp="destination=$option";
  fi
  parameter=${tmp%%=*}; # Extract option's name.
  value=${tmp##*=};     # Extract option's value.
  case $parameter in
    # Some parameters don't require a value.
    #no-minimize-url ) ;;

    # If a value is expected, but not specified inside the parameter, grab the next param.
    * )
      if [[ $value == $tmp ]]; then
        if [[ ${2:0:1} == '-' ]]; then
          # The next parameter is a new option, so unset the value.
          value='';
        else
          value=$2;
          shift;
        fi
      fi
      ;;
  esac

  case $parameter in
    url-file )     url_file=$value;;
    destination )  destination=$value;;

    help )         print_help; exit;;

    usage )        print_usage; exit;;

    * )            echo "Unknown option: $option" >&2; print_usage; exit 1;;
  esac

  # Remove the processed parameter.
  shift;
done

# Check for required parameters.
if [[ $url_file == '' ]]; then
  echo $usage >&2;
  exit 1;
fi
# Check for valid file.
if [[ ! -f $url_file ]]; then
  echo "Specified URL file \"$url_file\" does not exist or is not a file." >&2;
  echo $usage >&2;
  exit 1;
fi


# Process each URL in the repository list.
tmp_file="tmp-authors-transform.txt";
touch $tmp_file;
while read line
do
  # Check for 2-field format:  Name [tab] URL
  name=`echo $line | awk '{print $1}'`;
  url=`echo $line | awk '{print $2}'`;
  # Check for simple 1-field format:  URL
  if [[ $url == '' ]]; then
    url=$name;
    name=`basename $url`;
  fi
  # Process the log of each Subversion URL.
  echo "Processing \"$name\" repository at $url..." >&2;
  /bin/echo -n "  " >&2;
  svn log -q $url | awk -F '|' '/^r/ {sub("^ ", "", $2); sub(" $", "", $2); print $2" = "$2" <"$2">"}' | sort -u >> $tmp_file;
  echo "Done." >&2;
done < $url_file

# Process temp file one last time to show results.
if [[ $destination == '' ]]; then
  # Display on standard output.
  cat $tmp_file | sort -u;
else
  # Output to the specified destination file.
  cat $tmp_file | sort -u > $destination;
fi
rm $tmp_file;
