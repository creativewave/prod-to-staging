# prod-to-staging
Description: copy production files and database to staging.
Usage:
```sh
/home/user/prod-to-staging.sh -i /var/www/prod db_prod -o /var/www/staging db_staging
```
Or create a cron job to run daily:
```sh
crontab -e
@daily /home/user/prod-to-staging.sh -u root -p root -i /var/www/prod db_prod -o /var/www/staging db_staging -r www.domain staging.domain
```
