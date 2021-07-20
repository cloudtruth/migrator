#!/usr/bin/env ruby

require 'json'

def run(cmd)
  result = %x(#{cmd})
  raise "Command failed: #{cmd}" unless $?.success?
  result
end

if run(%Q(cloudtruth --version)) !~ /0\.5/
  puts "Export needs cloudtruth cli == 0.5.x"
  exit 1
end

json = {}

puts "Fetching integrations"
integrations = JSON.parse(run(%Q(cloudtruth integrations list --format json --values)))
json = json.merge(integrations)

puts "Fetching environments"
environments=JSON.parse(run(%Q(cloudtruth environments list --format json --values)))
json = json.merge(environments)

puts "Fetching projects"
projects=JSON.parse(run(%Q(cloudtruth projects list --format json --values)))
json = json.merge(projects)

envs = environments['environment'].collect {|e| e['Name'] }
json['project'].each do |project|
  envs.each do |env|
    project_name = project["Name"]
    puts "Fetching parameters for project='#{project_name}' environment='#{env}'"

    begin
      params=JSON.parse(run(%Q(cloudtruth --project '#{project_name}' --env '#{env}' parameters list --format json --values --secrets)))
      params_dynamic=JSON.parse(run(%Q(cloudtruth --project '#{project_name}' --env '#{env}' parameters list --format json --values --secrets --dynamic)))
      params_dynamic['parameter'].each do |pd|
        found = params['parameter'].find {|p| p['Name'] == pd['Name'] }
        found.merge!(pd) if found
      end
    rescue JSON::ParserError => e
      case e.message
      when /No dynamic parameters/
        puts "No dynamic parameters"
      when /No parameters found/
        puts "No parameters found"
        next
      else
        raise
      end
    end

    project['parameter'] ||= {}
    project['parameter'][env] = params['parameter']
  end
end

File.write("export.json", JSON.pretty_generate(json))
