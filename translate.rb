require 'json'

contents = File.read(ARGV[0])
lines = contents.split("\n")

result = {
  vars: {},
  constraints: {},
  outputs: {}
}

lines.each do |line|
  if line.start_with?('#')
    toptoks = line.split('=')
    value = toptoks[1]
    toks = toptoks[0].split('#')
    type = toks[1]
    name = toks[2]
    if type == 'var'
      result[:vars][name] = value
    elsif type == 'constraint'
      result[:constraints][name] = value
    elsif type == 'show'
      result[:outputs][name] = value
    elsif type == 'top'
      result[name] = value
    end
  end
end

puts result.to_json