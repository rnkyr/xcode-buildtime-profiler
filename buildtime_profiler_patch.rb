#!/usr/bin/env ruby

require 'xcodeproj'
require 'cocoapods'
require 'fileutils'

class String
def red;            "\e[31m#{self}\e[0m" end
def green;          "\e[32m#{self}\e[0m" end
def cyan;           "\e[36m#{self}\e[0m" end
def gray;           "\e[37m#{self}\e[0m" end
end

$log_time_before_build_phase_name = '[Build time profiler] Log time before build'.freeze
$log_time_after_build_phase_name = '[Build time profiler] Log time after build'.freeze
$counter_build_phase_name = '[Build time profiler] Build times counter'.freeze
$summary_build_phase_name = '[Build time profiler] Summary'.freeze

def remove_build_phases(project_path)
    project = Xcodeproj::Project.open(project_path)
    puts "Cleaning project at path: #{project_path}".cyan
    project.targets.each do |target|
        remove_existing_build_phase(target, $log_time_before_build_phase_name)
        remove_existing_build_phase(target, $log_time_after_build_phase_name)
        remove_existing_build_phase(target, $summary_build_phase_name)
        remove_existing_build_phase(target, $counter_build_phase_name)
    end
    project.save
end

def inject_build_time_profiling_build_phases(project_path, summary_target_name)
    project = Xcodeproj::Project.open(project_path)
    puts "Patching project at path: #{project_path}".gray
    project.targets.each do |target|
        create_leading_build_phase(target, $log_time_before_build_phase_name)
        create_trailing_build_phase(target, $log_time_after_build_phase_name)
        if target.name.eql? summary_target_name
            create_counter_build_phase(target, $counter_build_phase_name)
            create_summary_build_phase(target, $summary_build_phase_name)
        end
    end

    project.save
end

def create_leading_build_phase(target, build_phase_name)
    remove_existing_build_phase(target, build_phase_name)
    build_phase = create_build_phase(target, build_phase_name)
    shift_build_phase_leftwards(target, build_phase)
    inject_shell_code_into_build_phase(target, build_phase, true)
end

def create_trailing_build_phase(target, build_phase_name)
    remove_existing_build_phase(target, build_phase_name)
    build_phase = create_build_phase(target, build_phase_name)
    inject_shell_code_into_build_phase(target, build_phase, false)
end

def create_counter_build_phase(target, build_phase_name)
    remove_existing_build_phase(target, build_phase_name)
    build_phase = create_build_phase(target, build_phase_name)
    counterfile = $build_time_logs_output_dir + "/counter"
    build_phase.shell_script = <<-SH.strip_heredoc
val=0
[ -e #{counterfile} ] && read -d $'\x04' val < #{counterfile}
[ -e #{counterfile} ] && rm #{counterfile}
echo $((val + 1)) >> #{counterfile}
        SH
end

def create_summary_build_phase(target, build_phase_name)
    remove_existing_build_phase(target, build_phase_name)
    build_phase = create_build_phase(target, build_phase_name)
    summary_file = $build_time_logs_output_dir + "/summary.json"
    report_file = File.dirname($summary_script_path) + '/report.html'
    command = "ruby #{$report_builder_script_path} #{summary_file} && open #{report_file}"
    build_phase.shell_script = <<-SH.strip_heredoc
summary=$(ruby #{$summary_script_path} "#{$build_time_logs_output_dir}")
terminal-notifier -sound default -title "Build time profiler" -message "$summary" -execute "#{command}"
        SH
end

def remove_existing_build_phase(target, build_phase_name)
    existing_build_phase = target.shell_script_build_phases.find do |build_phase|
        build_phase.name.end_with?(build_phase_name)
    end
    if !existing_build_phase.nil?
        target.build_phases.delete(existing_build_phase)
    end
end

def create_build_phase(target, build_phase_name)
    build_phase = Pod::Installer::UserProjectIntegrator::TargetIntegrator
        .create_or_update_build_phase(target, build_phase_name)
    return build_phase
end

def shift_build_phase_leftwards(target, build_phase)
    target.build_phases.unshift(build_phase).uniq! unless target.build_phases.first == build_phase
end

def inject_shell_code_into_build_phase(target, build_phase, is_build_phase_leading)
    tmpfile = $build_time_logs_output_dir + "/tmp_#{target}"
    ofile = $build_time_logs_output_dir + "/t_#{target}"
    if is_build_phase_leading
	    build_phase.shell_script = <<-SH.strip_heredoc
[ -e #{tmpfile} ] && rm #{tmpfile}
timestamp=`echo "$(date +%s)" | bc`
echo "${timestamp}" >> #{tmpfile}
	    SH
    else
	    build_phase.shell_script = <<-SH.strip_heredoc
timestamp=`echo "$(date +%s)" | bc`
val=0
read -d $'\x04' val < #{tmpfile}
dif=$((timestamp - val))
sum=0
[ -e #{ofile} ] && read -d $'\x04' sum < #{ofile}
> #{ofile}
rm #{tmpfile}
echo $((dif + sum)) >> #{ofile}
	    SH
    end
end

def patch
    inject_build_time_profiling_build_phases($project_path, $project_name)
    inject_build_time_profiling_build_phases($pods_path, $project_name)
end

def clean_up
    remove_build_phases($project_path)
    remove_build_phases($pods_path)
end

$project_name = "MyProject"
$project_dir = "/Users/rkyr/dev/iOS/#{$project_name}"
current_dir = File.dirname(__FILE__)
$summary_script_path = current_dir + '/buildtime_profiler_summarize.rb'
$report_builder_script_path = current_dir + '/buildtime_reporter.rb'

$build_time_logs_output_dir = current_dir + "/#{$project_name}-logs"
$project_path = "#{$project_dir}/#{$project_name}.xcodeproj"
$pods_path = "#{$project_dir}/Pods/Pods.xcodeproj"

puts "project name: ".green + $project_name.red
puts "project directory: ".green + $project_dir.red
puts "summary script path: ".green + $summary_script_path.red

if ARGV.empty? or ARGV[0].eql? "patch"
    patch
elsif ARGV[0].eql? "clean"
    clean_up
end