require 'json'
require 'erb'

$summary_json_path = ARGV[0]

file = File.read($summary_json_path)
json = JSON.parse(file)

@summary = json['summary']
@targets = json['per_target'].map { |key, value|  { 'name' => key, 'value' => value } }
@times = []
@builds = []
@builds_per_day = []
@time_per_day = []
last_time = 0
last_builds = 0
json['days'].each do |key, value|
	@times.push({'day' => key, 'value' => value['time']})
	@builds.push({'day' => key, 'value' => value['builds']})
	@time_per_day.push({'day' => key, 'value' => value['time'] - last_time})
	@builds_per_day.push({'day' => key, 'value' => value['builds'] - last_builds})
	last_time = value['time']
	last_builds = value['builds']
end

template = File.read(File.dirname(__FILE__) + '/buildtime_report_template.html.erb')
result = ERB.new(template).result(binding)

File.open(File.dirname(__FILE__) + '/report.html', 'w+') do |f|
  f.write result
end