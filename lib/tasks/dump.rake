# psql -d postgres -c "CREATE USER updatebot"
# psql -d postgres -c "ALTER USER updatebot WITH SUPERUSER;"

desc 'Dump database and Redis'
task :dump => :environment do |t, args|
  month_ago_backup = 1.month.ago.strftime('%Y-%m')
  timestamp = Time.now.strftime('%Y-%m-%d-%H-%M-%S')
  system("rm /srv/backup/db/steemhunt-#{month_ago_backup}-*.sql*")
  system("/usr/lib/postgresql/9.5/bin/pg_dump -d steemhunt > /srv/backup/db/steemhunt-#{timestamp}.sql")
  system("gzip /srv/backup/db/steemhunt-#{timestamp}.sql")
  system("chmod 640 /srv/backup/db/steemhunt-#{timestamp}.sql.gz")
  puts ' -- Steemhunt database backup complete'

  puts 'Finished database and Redis dump'
end
