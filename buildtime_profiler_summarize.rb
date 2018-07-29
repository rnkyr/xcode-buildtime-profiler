require 'json'
require 'date'

$build_time_logs_output_dir = ARGV[0]

$summary_file_path = $build_time_logs_output_dir + '/summary.json'
$counter_file_path = $build_time_logs_output_dir + "/counter"
$targets = {}

def prepare_summary
	$builds = File.read($counter_file_path).scan(/\d+/).first.to_i
	$time = 0
	Dir.foreach($build_time_logs_output_dir) do |item|
	  next unless item.start_with?("t_")
	  file_contents = File.read($build_time_logs_output_dir + '/' + item)
	  target_time = file_contents.scan(/\d+/).first.to_i
	  $time += target_time
	  target = item
	  target.slice! "t_"
	  $targets[target] = target_time
	end
	file_time = File.file?($summary_file_path) ? File.birthtime($summary_file_path) : Time.now
	$start_date = file_time.strftime("%d/%m/%y %H:%M")
	$summary = "#{time_summary($time)} spent starting from #{$start_date} (#{$builds} builds)"
end

def time_summary(time)
	hours = (time / 60 / 60).to_i
	minutes = (time / 60 - 60 * hours).to_i
	seconds = (time - minutes * 60 - hours * 60 * 60).to_i
	h = ""
	m = ""
	s = "#{seconds}s"
	if hours > 0
		h = "#{hours}h "
		m = "#{minutes}m "
	elsif minutes > 0
		m = "#{minutes}m "
	end
	"#{h}#{m}#{s}"
end

def update_stats
	if File.file?($summary_file_path)
		file = File.read($summary_file_path)
		json = JSON.parse(file)
	else
		json = {}
	end
	json['summary'] = $summary
	json['last_update'] = Time.now.strftime("%d/%m/%y %H:%M")
	json['start_date'] = $start_date
	json['per_target'] = $targets
	last_time = json['time']
	last_builds = json['builds']
	last_date = json['last_date']
	json['days'] = {} unless json.key?('days')
	today = Time.now.strftime("%d/%m/%y")
	json['days'][today] = {
		'builds' => $builds,
		'time' => $time
	}
	File.open($summary_file_path, "w") do |f|
		f.write(JSON.pretty_generate(json))
	end
end

prepare_summary
update_stats

puts $summary