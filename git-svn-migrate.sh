#!/bin/bash

# Copyright 2010-2011 John Albin Wilkins and contributors.
# Available under the GPL v2 license. See LICENSE.txt.

#Heavily modified by Cole Palmer to migrate to functions

script=`basename $0`;
dir=`pwd`/`dirname $0`;

# Set defaults for any optional parameters or arguments.
destination='.';
gitinit_params='';
gitsvn_params='';


function pause()
{
    read -p "
    ${1}
    Press ENTER to continue ...
" -s
}

function svn-lookup-author()
{
	echo "$1 <$1>";
}

function print_usage()
{
    echo "
    USAGE: $script --url-file=<filename> --authors-file=<filename> [destination folder]

    For more info, see: $script --help
"
}

functon print_help()
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

    -u=<filename>, -u <filename>,
    --url-file=<filename>, --url-file <filename>
        Specify the file containing the Subversion repository list.

    -a=<filename>, -a <filename>,
    --authors-file=[filename], --authors-file [filename]
        Specify the file containing the authors transformation data.

    -d=<folder>, -d <folder>,
    --destination=<folder>, --destination <folder>
        The directory where the new Git repositories should be
        saved. Defaults to the current directory.

    -i=<filename>, -i <filename>,
    --ignore-file=<filename>, --ignore-file <filename>
        The location of a .gitignore file to add to all repositories.

    -T=<trunk_subdir>, -T <trunk_subdir>
    --trunk=<trunk_subdir>, --trunk <trunk_subdir>
    -t=<tags_subdir>, -t <tags_subdir>
    --tags=<tags_subdir>, --tags <tags_subdir>
    -b=<branches_subdir>, -b <branches_subdir>
    --branches=<branches_subdir>, --branches <branches_subdir>
        These are optional command-line options for init.
        git svn --help for more info.

    --no-minimize-url
        Pass the "--no-minimize-url" parameter to git-svn. See
        git svn --help for more info.

    --quiet
        By default this script is rather verbose since it outputs each revision
        number as it is processed from Subversion. Since conversion can sometimes
        take hours to complete, this output can be useful. However, this option
        will surpress that output.

    --no-metadata
        By default, all converted log messages will include a line starting with
        "git-svn-id:" which makes it easy to track down old references to
        Subversion revision numbers in existing documentation, bug reports and
        archives. Use this option to get rid of that data.
        This option is NOT recommended as it makes it difficult to
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

    Any additional options are assumed to be git-svn options and will be passed
    along to that utility directly. Some useful git-svn options are:
        --trunk --tags --branches --no-minimize-url
    See git svn --help for more info about its options.

    --use-svm-props
        See git svn --help for more info.

    --use-svnsync-props
        See git svn --help for more info.

BASIC EXAMPLES
    # Use the long parameter names
    $script --url-file=my-repository-list.txt --authors-file=authors-file.txt --destination=/var/git

    # Use short parameter names
    $script -u my-repository-list.txt -a authors-file.txt /var/git

SEE ALSO
    fetch-svn-authors.sh
"
}


# Process parameters.
until [[ -z "$1" ]]; do
  option=$1;
  # Strip off leading '--' or '-'.
  if [[ ${option:0:1} == '-' ]]; then
    flag_delimiter='-';
    if [[ ${option:0:2} == '--' ]]; then
      tmp=${option:2};
      flag_delimiter='--';
    else
      tmp=${option:1};
    fi
  else
    # Any argument given is assumed to be the destination folder.
    tmp="destination=$option";
  fi
  parameter=${tmp%%=*}; # Extract option's name.
  value=${tmp##*=};     # Extract option's value.
  # If a value is expected, but not specified inside the parameter, grab the next param.
  if [[ $value == $tmp ]]; then
    if [[ ${2:0:1} == '-' ]]; then
      # The next parameter is a new option, so unset the value.
      value='';
    else
      value=$2;
      shift;
    fi
  fi

  case $parameter in
    u )                url_file=$value;;
    url-file )         url_file=$value;;
    a )                authors_file=$value;;
    authors-file )     authors_file=$value;;
    d )                destination=$value;;
    destination )      destination=$value;;
    i )                ignore_file=$value;;
    ignore-file )      ignore_file=$value;;
    T )                gitsvn_params="$gitsvn_params --trunk=$value";;
    trunk )            gitsvn_params="$gitsvn_params --trunk=$value";;
    t )                gitsvn_params="$gitsvn_params --tags=$value";;
    tags )             gitsvn_params="$gitsvn_params --tags=$value";;
    b )                gitsvn_params="$gitsvn_params --branches=$value";;
    branches )         gitsvn_params="$gitsvn_params --branches=$value";;
    no-minimize-url )  gitsvn_params="$gitsvn_params --no-minimize-url";;
    no-metadata )      gitsvn_params="$gitsvn_params --no-metadata";;
    use-svm-props )    gitsvn_params="$gitsvn_params --use-svm-props";;
    use-svnsync-props) gitsvn_params="$gitsvn_params --use-svnsync-props";;
    no-stdlayout )     no_stdlayout="true";;
    shared )          if [[ $value == '' ]]; then
                        gitinit_params="--shared";
                      else
                        gitinit_params="--shared=$value";
                      fi
                      ;;

    h )            print_help; exit;;
    help )         print_help; exit;;

    usage )        print_usage; exit;;

    * ) # Pass any unknown parameters to git-svn directly.
        if [[ $value == '' ]]; then
          gitsvn_params="$gitsvn_params $flag_delimiter$parameter";
        elif [[ ${#parameter} -gt 1 ]]; then
          gitsvn_params="$gitsvn_params $flag_delimiter$parameter=$value";
        else
          gitsvn_params="$gitsvn_params $flag_delimiter$parameter $value";
        fi;;
  esac

  # Remove the processed parameter.
  shift;
done

exit

# Check for required parameters.
if [[ $url_file == '' || $authors_file == '' ]]; then
  echo -e $usage >&2;
  exit 1;
fi
# Check for valid files.
if [[ ! -f $url_file ]]; then
  echo "Specified URL file \"$url_file\" does not exist or is not a file." >&2;
  echo -e $usage >&2;
  exit 1;
fi
if [[ ! -f $authors_file ]]; then
  echo "Specified authors file \"$authors_file\" does not exist or is not a file." >&2;
  echo -e $usage >&2;
  exit 1;
fi


# Process each URL in the repository list.
pwd=`pwd`;
tmp_destination="`mktemp --directory --dry-run $pwd/tmp-git-repoXXXXXXXX`";
mkdir -p "$destination";
destination=`cd "$destination"; pwd`; #Absolute path.

# Ensure temporary repository location is empty.
if [[ -e $tmp_destination ]]; then
  echo "Temporary repository location \"$tmp_destination\" already exists. Exiting." >&2;
  exit 1;
fi

sed -e 's/#.*//; /^[[:space:]]*$/d' $url_file | while read line
do
  # Check for 2-field format:  Name [tab] URL
  name=`echo $line | awk '{print $1}'`;
  url=`echo $line | awk '{print $2}'`;

  #enhancement by Shan Ul Haq. added a third parameter to have git remote repository
  # formate : Name [tab] SVN URL [tab] GIT url
  git_remote=`echo $line | awk '{print $3}'`;

  #non-standard layout for the svn repository. if this is available then use it. otherwise use standard layout.
  #provide the non-standar layout as 4th parameter in this format: "Branches|Tags|Trunk"
  non_standard_layout=`echo $line | awk '{print $4}'`;
  set -- "$non_standard_layout" 
  IFS="|"; declare -a Array=($*) 
  layout_branches="${Array[0]}" 
  layout_tags="${Array[1]}"
  layout_trunk="${Array[2]}"


  # Check for simple 1-field format:  URL
  if [[ $url == '' ]]; then
    url=$name;
    name=`basename $url`;
  fi
  # Process each Subversion URL.
  echo >&2;
  echo "At $(date)..." >&2;
  echo "Processing \"$name\" repository at $url..." >&2;
  echo "Description: $name" >&2;

  # Init the final bare repository.
  mkdir "$destination/$name.git";
  cd "$destination/$name.git";
  git init --bare $gitinit_params;
  git symbolic-ref HEAD refs/heads/trunk;

  # Clone the original Subversion repository to a temp repository.
  cd "$pwd";
  echo "- Cloning repository..." >&2;
  git_svn_clone="git svn clone \"$url\" -A \"$authors_file\" --authors-prog=\"$dir/svn-lookup-author.sh\"  --preserve-empty-dirs --placeholder-filename=".gitkeep"";

  if [[ $non_standard_layout == '' ]]; then
  	if [[ -z $no_stdlayout ]]; then
    	git_svn_clone="$git_svn_clone --stdlayout";
  	fi
  else
  	#if non-standard svn repo layout parameters are provided, then use those
  	git_svn_clone="$git_svn_clone --trunk=/$layout_trunk --branches=/$layout_branches --tags=/$layout_tags";
  fi

  git_svn_clone="$git_svn_clone --quiet $gitsvn_params $tmp_destination";
  $git_svn_clone;

  # Create .gitignore file.
  echo "- Converting svn:ignore properties into a .gitignore file..." >&2;
  if [[ $ignore_file != '' ]]; then
    cp "$ignore_file" "$tmp_destination/.gitignore";
  fi
  cd "$tmp_destination";
  git svn show-ignore --id trunk >> .gitignore;
  if [ -s .gitignore ]; then
    git add .gitignore;
    git commit --author="git-svn-migrate <nobody@example.org>" -m 'Convert svn:ignore properties to .gitignore.';
  fi

  # Push to final bare repository and remove temp repository.
  echo "- Pushing to new bare repository..." >&2;
  git remote add bare "$destination/$name.git";
  git config remote.bare.push 'refs/remotes/*:refs/heads/*';
  git push bare;
  # Push the .gitignore commit that resides on master.
  git push bare master:trunk;
  cd "$pwd";
  rm -r "$tmp_destination";

  # Rename Subversion's "trunk" branch to Git's standard "master" branch.
  cd "$destination/$name.git";
  git branch -M trunk master;

  # Remove bogus branches of the form "name@REV".
  git for-each-ref --format='%(refname)' refs/heads | grep '@[0-9][0-9]*' | cut -d / -f 3- |
  while read ref
  do
    git branch -D "$ref";
  done

  # Convert git-svn tag branches to proper tags.
  echo "- Converting svn tag directories to proper git tags..." >&2;
  git for-each-ref --format='%(refname)' refs/heads/tags | cut -d / -f 4 |
  while read ref
  do
    git tag -a "$ref" -m "Convert \"$ref\" to a proper git tag." "refs/heads/tags/$ref";
    git branch -D "tags/$ref";
  done

  #this is the enhancements done by Shan Ul Haq. Following code will read the remote provided in the URL list
  #and will add as origin in the said repository and will push with mirror options
  #UPDATE: only preform this action if a remote is listed in the file
  if [[ $git_remote != '' ]]; then
    git remote add origin $git_remote

    #push whole repository with mirror option
    git push --mirror origin
  fi
  
  echo "- Conversion completed at $(date)." >&2;
done
