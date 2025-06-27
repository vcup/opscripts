#! /bin/nu
# @/db-tsf
# depends: nushell mariadb
use std log

def main [dbname: string, ssh_cfg: string] {}

def 'main get dbnames' [--host: string = '127.0.0.1', --port = 3306, --user: string = 'root', --password: string = '123']: nothing -> list<string> {
  get-dbnames $host $port $user $password
}
def 'main batch dump' [...dbnames: string, --host: string = '127.0.0.1', --port = 3306, --user: string = 'root', --password: string = '123', --dir: string = 'db-tsf/dumps']: nothing -> nothing {
  $dbnames | db-batch-dump $host $port $user $password $dir
  return
}
def 'main batch pump' [...dbnames: string, --host: string = '127.0.0.1', --port = 3306, --user: string = 'root', --password: string = '123' --dir: string = 'db-tsf/dumps']: nothing -> nothing {
  $dbnames | db-batch-pump $host $port $user $password $dir
  return
}
def 'main dump' [dbname: string, --host: string = '127.0.0.1', --port = 3306, --user: string = 'root', --password: string = '123' --dir: string = 'db-tsf/dumps']: nothing -> nothing {
  $dbname | db-dump $host $port $user $password $dir
  return
}
def 'main pump' [dbname: string, --host: string = '127.0.0.1', --port = 3306, --user: string = 'root', --password: string = '123' --dir: string = 'db-tsf/dumps']: nothing -> nothing {
  $dbname | db-pump $host $port $user $password $dir
  return
}

def get-dbnames [host: string, port: int, user: string, password: string]: nothing -> list<string> {
  let dbnames_sql = ("SELECT schema_name
    FROM information_schema.schemata
    WHERE schema_name NOT IN ('information_schema', 'mysql', 'performance_schema', 'test', 'sys')
    ORDER BY schema_name;")

  let dbnames_str = ($dbnames_sql | mariadb -h $host -P $port -u $user -p($password))

  $dbnames_str | lines | skip 1
}

def db-batch-dump [host: string, port: int, user: string, password: string, dir: string]: list<string> -> nothing {
  mkdir $dir
  let dbnames: list<string> = $in
  let dbnames = if ($dbnames | is-empty) {
    get-dbnames $host $port $user $password
  } else { $dbnames }

  $dbnames | each {
    $in | db-dump $host $port $user $password $dir
  }
}
def db-batch-pump [host: string, port: int, user: string, password: string dir: string]: list<string> -> nothing {
  mkdir $dir
  let dbnames: list<string> = $in
  let dbnames = if ($dbnames | is-empty) {
    ls $dir | get name | path parse | where extension == 'sql' | get stem
  } else { $dbnames }

  $dbnames | each { $in | db-pump $host $port $user $password $dir }
}

def db-dump [host: string, port: int, user: string, password: string dir: string]: string -> nothing {
  let dbname: string = $in
  log info $'dumping data for ($dbname)'
  (
  mariadb-dump -h $host -P $port -u $user -p($password)
    --single-transaction
    --complete-insert
    --routines
    --triggers
    $dbname
  ) | save -f ($dir | path join $'($dbname).sql')
}
def db-pump [host: string, port, user: string, password: string dir: string]: string -> nothing {
  let dbname: string = $in
  log info $'pumping data for ($dbname)'
  $'CREATE DATABASE IF NOT EXISTS ($dbname);' | mariadb -h $host -P $port -u $user -p($password)
  open -r ($dir | path join $'($dbname).sql') | mariadb -h $host -P $port -u $user -p($password) -D($dbname)
}

