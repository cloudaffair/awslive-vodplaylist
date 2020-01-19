require 'aws-sdk-medialive'
require 'aws-sdk-lambda'
require 'aws-sdk-cloudwatchevents'
require 'json'


def lambda_handler(event:, context:)
  state = nil
  channel_id = nil
  puts "Event #{event}"
  if event["detail-type"] == "MediaLive Channel State Change"
    puts "Event : #{event}"
    state = event["detail"]["state"]
    channel_arn = event["detail"]["channel_arn"]
    role_arn = ENV["role_arn"]
    channel_id = channel_arn.split(":").last
    puts "channel ID : #{channel_id}  State : #{state}"
  end

  if !channel_id.nil?
    @medialiveclient = Aws::MediaLive::Client.new
    @cloudwatcheventsclient = Aws::CloudWatchEvents::Client.new
    @lambdaclient = Aws::Lambda::Client.new
    channel_info = @medialiveclient.describe_channel({ :channel_id => "#{channel_id}" })
    playlist = channel_info[:tags]["playlist"] rescue nil
    if state == "RUNNING"
      puts "Inputlooper Lambda to be created"

      lambda_create_response = @lambdaclient.create_function({
                                                                 function_name: "#{channel_id}_ip_switch_lambda",
                                                                 runtime: "ruby2.5",
                                                                 role: "#{role_arn}",
                                                                 handler: "awslive_lambda_inputswitch.lambda_handler",
                                                                 code: {
                                                                     #zip_file: "deps/awslive-lambda-inputswitch.zip"
                                                                     s3_bucket: "live-elemental-clipping-test",
                                                                     s3_key: "awslive-lambda-inputswitch.zip"
                                                                 },
                                                                 environment: {
                                                                     variables: {
                                                                         "channel_id" => channel_id
                                                                     }
                                                                 }
                                                             })
      puts "Lambda Create Response #{lambda_create_response[:function_arn]}"

      @lambdaclient.invoke({
                               :function_name => "#{channel_id}_ip_switch_lambda",
                               :invocation_type => "Event",
                               :log_type => "None",
                               :client_context => "Input Switch",
                               :payload => { initial: true }.to_json
                           })

      rule_response = @cloudwatcheventsclient.put_rule({
                                                           name: "#{channel_id}_ip_switch_rule",
                                                           schedule_expression: "rate(1 minute)"
                                                       })
      puts "rule create Response #{rule_response}"
      target_response = @cloudwatcheventsclient.put_targets({
                                                                rule: "#{channel_id}_ip_switch_rule",
                                                                targets: [ {
                                                                               id: "#{channel_id}-ID",
                                                                               arn: "#{lambda_create_response[:function_arn]}"
                                                                           }
                                                                ]
                                                            })
      puts "Target Rsponse #{target_response}"

      add_permission_response = @lambdaclient.add_permission({
                                                                 action: "lambda:InvokeFunction",
                                                                 function_name: "#{channel_id}_ip_switch_lambda",
                                                                 principal: "events.amazonaws.com",
                                                                 source_arn: "#{rule_response[:rule_arn]}",
                                                                 statement_id: "#{Time.now.to_i}"
                                                             })
      puts "add Permission Response #{add_permission_response}"

    elsif state == "STOPPED"
      puts "deprovision Inputlooper Lambda"
      resp = @lambdaclient.delete_function({
                                               function_name: "#{channel_id}_ip_switch_lambda"
                                           })
      puts "deprovisioning targets"
      @cloudwatcheventsclient.remove_targets({
          rule: "#{channel_id}_ip_switch_rule",
          ids: ["#{channel_id}-ID"]
                                             })

      puts "deproivision rule created"
      @cloudwatcheventsclient.delete_rule({
                                              name: "#{channel_id}_ip_switch_rule"
                                          })
    end
  end
end
