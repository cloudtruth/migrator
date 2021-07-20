#!/usr/bin/env ruby

require 'json'

def run(cmd)
  result = %x(#{cmd})
  raise "Command failed: #{cmd}" unless $?.success?
  result
end

if run(%Q(cloudtruth --version)) !~ /1\.0/
  puts "Import needs cloudtruth cli == 1.0.x"
  exit 1
end

json = JSON.load(File.read("export.json"))

puts "Create integrations in UI before proceeding"
puts json['integration']
print "Hit enter to continue"
gets

puts "Creating environments"
json['environment'].each do |env|
  puts "Creating '#{env['Name']}'"
  run(%Q(cloudtruth environments set --desc '#{env['Description']}' --parent '#{env['Parent']}' '#{env['Name']}'))
end

puts "Creating projects"
json['project'].each do |proj|
  puts "Creating '#{proj['Name']}'"
  run(%Q(cloudtruth projects set --desc '#{proj['Description']}' '#{proj['Name']}'))

  proj['parameter'].each do |env, param|
    puts "Creating parameter name='#{param['Name']}' for env='#{env}'"
    if param['Source'] == env
      cmd = "cloudtruth --project '#{proj['Name']}' --env '#{env}' parameter set --desc '#{param['Description']}' --value '#{param['Value']}' --secret '#{param['Secret']}' '#{param['Name']}'"
      if param['JMES'].blank?
        cmd <<  " --value '#{param['Value']}'"
      else
        cmd << " --fqn '#{param['FQN']}' --jmes '#{param['JMES']}'"
      end
      cmd << " '#{param['Name']}'"
      run(cmd)
    else
      puts "Param value for '#{param['Name']}' doesn't exist in this environment"
    end

  end

end

