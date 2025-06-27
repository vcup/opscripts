#! /usr/bin/nu
# @/dev-tools
# depends: nushell
use std log

def set-by-path [record: record, value: any, ...path: string]: nothing -> any {
  # let record: record = $in
  if ($path | is-empty) { return $value }
  let key: string = $path | first
  let path = $path | skip 1
  if ($key in $record) {
    $record | update $key {
      let rec: record = if ($path | is-empty) { { } } else { $in }
      # if ($path | is-empty) { { } } else { $in } | set-by-path $value ...$path
      set-by-path $rec $value ...$path
    }
  } else {
    # $record | insert $key { { } | set-by-path $value ...$path }
    $record | insert $key { set-by-path {} $value ...$path }
  }
}

def save-json [file: string]: any -> nothing {
  $in | to json | save -f $file
}

def config-json [--file (-f): string = 'appsettings.json', ...path: string]: any -> nothing {
  let config = set-by-path (open $file) $in ...$path
  $config | save-json $file
  return
}

def 'main config' [value: any, --file (-f): string = 'appsettings.json', ...path: string]: nothing -> nothing {
  $value | config-json $file ...$path
  return
}
