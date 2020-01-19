require 'awslive-inputlooper'
require 'aws-sdk-medialive'

def lambda_handler(event:, context:)
  puts "Event : #{event}"
  puts "Channel ID : #{ENV['channel_id']}"
  @medialiveclient = Aws::MediaLive::Client.new
  channel_info = @medialiveclient.describe_channel({ :channel_id => "#{ENV['channel_id']}" })
  playlist = channel_info[:tags]["playlist"] rescue nil
  force_immd = event["initial"].nil? ? nil : true
  puts "Force immed Flag #{force_immd}"
  if !playlist.nil? && channel_info.state == "RUNNING"
    inputlooper = Awslive::InputLooper.new("#{ENV['channel_id']}")
    inputlooper.set_log_flag(true)
    playlist = playlist.split("=")
    puts "Current Playlist info #{playlist}"
    inputlooper.update_playlist(playlist)
    inputlooper.switch_input(force_immd)
  else
    puts "No Playlist or the status of the channel is not RUNNING"
  end
end