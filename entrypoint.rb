#!/usr/env/bin

puts 'hello'

p ARGV
exit 0

contents = ARGV.read

File.write("input.s", contents)

exec "ruby stretcher.rb input.s"

