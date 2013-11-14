require "rubygems"
require "bundler/setup"
require "pom/version"
require "ostruct"
require 'terminal-notifier'

module Pom

  extend self

  #! /usr/bin/ruby
  options = ARGV
  if options.include?('--help') || options.include?('-h')
    puts "A simple pomodoro timer in ruby."
    puts "Usage:"
    puts "$ pom [-l INT -t TIME -u NUM_UPDATES]"
    puts "INT: number of pomodoros before long break occurs"
    puts "TIME: time (in minutes) of a single pomodoro"
    exit
  end

  pomodoro_time = 25 # minutes
  if i = options.index('-t')
    pomodoro_time = options[i+1].to_i
    if pomodoro_time == 0
      puts "Invalid time specified."
      exit(1)
    end
  end

  @long_interval = 4 # minutes
  if i = options.index('-l')
    @long_interval = options[i+1].to_i
    if @long_interval == 0
      puts "Invalid interval specified."
      exit(1)
    end
  end

  @num_updates = 100
  if i = options.index('-u')
    @num_updates = options[i+1].to_i
    if @num_updates < 0
      puts "Invalid number of updates specified."
      exit(1)
    end
  end

  def beep
    system "afplay #{File.join(File.dirname(__FILE__),"../resources/beep.m4a")}"
  end

  notifier = 'terminal-notifier -title Pomodoro -message '
  pomodoro = OpenStruct.new(:name => 'Pomodoro', :time => pomodoro_time * 60, :message => 'Pomodoro Time is up!', :notifier => notifier)
  short_break = OpenStruct.new(:name => 'Short break', :time => 5 * 60, :message => 'Pomodoro Break is up!', :notifier => notifier)
  long_break = OpenStruct.new(:name => 'Long break', :time => 15 * 60, :message => 'Pomodoro Break is up!', :notifier => notifier)

  def start(chunk)
    puts "\n#{chunk.name}!"
    puts "started: #{Time.now.strftime('%H:%M')} (duration: #{chunk.time/60}m)"
  end

  def progress(time, number_of_updates)
    duration = 1.0 * time / number_of_updates
    progress_bar = ''


    0.upto(number_of_updates) do |i|
      percentage = (i * 1.0 / number_of_updates * 100).to_i
      progress_bar << '|' << '==' * i << '  ' * (number_of_updates - i) << "| #{percentage}%\r"

      print progress_bar
      $stdout.flush

      minutes_left = ((time - duration * i) / 60.0).ceil
      adium_away minutes_left

      sleep duration
    end
  end

  def display_stats
    puts "\nYou've completed #{@pomodoro_count} full pomodoros."
    adium_back
    exit 0
  end

  def long_break_time?
    @pomodoro_count % @long_interval == 0
  end

  def finish(chunk)
    `#{chunk.notifier} "#{chunk.message}" -sender com.apple.Terminal`
    beep
    adium_back
  end

  def runit(chunk)
    start(chunk)
    progress(chunk.time, @num_updates)
    finish(chunk)
  end

  def adium_away(time)
    osascript <<-END
      tell application "Adium"
        go away with message "Heads-down on work for #{time} more minutes"
      end tell
    END
  end

  def adium_back
    osascript <<-END
      tell application "Adium"
        go available
      end tell
    END
  end

  def osascript(script)
    system 'osascript', *script.split(/\n/).map { |line| ['-e', line] }.flatten
  end

  trap('INT') { display_stats }

  @pomodoro_count = 0
  loop do
    runit(pomodoro)
    @pomodoro_count += 1
    long_break_time? ? runit(long_break) : runit(short_break)
  end

end
