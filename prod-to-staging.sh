#!/bin/bash

# Error codes.
E_PARAMS=10
E_DB=11

# Default parameters
db_user='root'
db_passwd='root'
prompt=true

# Helper
function display_help {
  cat <<EOF
Usage:
  ./prod-to-staging.sh -i <dir_name> <db_name> -o <db_name> <db_name> [-option] [-option <argument>]

Duplicates production directory and database.

Commands:
  -y, --yes       Run without prompts.
  -i, --input     Production directory path and database name.
  -o, --output    Staging directory path and database name.
  -u, --user      Database username (default to "root").
  -p, --password  Database password (default to "root").
  -r, --replace   Search and replace in database and .htaccess (./prod-to-staging.sh ... -r search replace).
EOF
}

# Parse and assign given parameters.
while : ; do
  case $1 in
    -h|--help)
      display_help
      exit
      ;;
    -y|--yes)
      prompt=false
      shift
      ;;
    -i|--input)
      dir_prod=${2%/}
      db_prod=$3
      shift 3
      ;;
    -o|--output)
      dir_staging=${2%/}
      db_staging=$3
      shift 3
      ;;
    -u|--user)
      db_user=$2
      shift 2
      ;;
    -p|--password)
      db_passwd=$2
      shift 2
      ;;
    -r|--replace)
      search=$2
      replace=$3
      shift 3
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Error: unknown option \"$1\"" >&2
      exit $E_PARAMS
      ;;
    *)
      break
      ;;
  esac
done

# Check given parameters.
if [[ -z $dir_prod || -z $db_prod || -z $dir_staging || -z $db_staging ]]; then
  echo 'Error: missing parameter (./prod-to-staging.sh -h to display help)' >&2
  exit $E_PARAMS
elif [[ ! -d $dir_prod ]]; then
  echo "Error: $dir_prod does not exist or is not a directory." >&2
  exit $E_PARAMS
elif [[ ! -d $dir_staging ]]; then
  echo "Error: $dir_staging does not exist or is not a directory." >&2
  exit $E_PARAMS
elif [[ $dir_prod == "$dir_staging" ]]; then
  echo 'Error: staging and production directories should be different.'
  exit $E_PARAMS
fi

# Clear staging directory and copy production files inside it.
if [[ $prompt == true ]]; then
  echo -ne "Are you sure you want to empty $dir_staging? (y/n) "
  read confirmed
  if [[ ! $confirmed =~ ^(y|Y).*$ ]]; then
    echo 'Operation aborted.'
    exit
  fi
fi
echo 'Clearing staging directory...'
rm -rf "$dir_staging"
echo 'Copying production files...'
cp -pR "$dir_prod" `dirname "$dir_staging"`
# rm -f "$dir_staging"/themes/"$theme"/cache/{*.css,*.js}

# Dump, transform (optional), and import database.
echo 'Dumping database...'
if [[ $prompt == true ]]; then
  echo 'Enter database password: '
  read -s db_passwd
fi
mysqldump --add-drop-table -u "$db_user" --password="$db_passwd" "$db_prod" > prod-to-staging.sql
if [[ $? -gt 0 ]]; then
  echo 'Error: could not connect to database or production database name does not exist.' >&2
  exit $E_DB
fi
if [[ $prompt == true && -z $search && -z $replace  ]]; then
  echo -n 'Would you like to replace a string in database and htaccess? (y/n) '
  read confirmed
  if [[ $confirmed =~ ^(y|Y).*$ ]]; then
    echo -n 'Which string would you like to replace in database and htaccess? '
    read search
    echo -n 'Which string would you like to use as a replacement? '
    read replace
  fi
fi
if [[ -n $search && -n $replace ]]; then
  echo "Replacing $search by $replace in database and .htaccess..."
  sed -i "s/$search/$replace/g" {prod-to-staging.sql,"$dir_staging"/.htaccess}
fi
echo 'Importing database...'
mysql -u "$db_user" --password="$db_passwd" "$db_staging" < prod-to-staging.sql
if [[ $? -eq 0 ]]; then
  echo 'Production successfully copied to staging!'
else
  echo 'Error: staging database name does not exist.' >&2
  exit $E_DB
fi
rm -f prod-to-staging.sql
exit
