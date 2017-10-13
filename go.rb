#!/usr/bin/env ruby
require 'bundler'
Bundler.require :default

app_names = ARGV

unless app_names.present?
  puts "Pass space-separated list of instance names to update Logentries notifications verbosity"
  exit
end
puts "These are the instance names to update Logentries notifications verbosity: #{app_names.to_sentence} "

Capybara.register_driver :selenium do |app|
  Capybara::Selenium::Driver.new(
    app, browser: :chrome,
    desired_capabilities: Selenium::WebDriver::Remote::Capabilities.chrome('loggingPrefs' =>
                                                                           {'performance' => 'ALL'}))
end
b = Capybara::Session.new :selenium
b.visit 'https://dashboard.heroku.com'

print "Waiting for you to complete the login to Heroku management UI"
loop do
  break if b.current_url[/dashboard.heroku.com\/(teams|apps)/]
  sleep 5; print '.'
end
puts



def extract_api_key browser, app_name
  b = browser
  b.visit "https://dashboard.heroku.com/apps/#{app_name}/resources"
  sleep 15
  b.visit b.all('a').find {|e| e.text[/Logentries/i]}['href']
  # sleep 15
  # b.click_on 'Tags & Alerts'
  reqs = b.driver.browser.manage.logs.get :performance
  headers = reqs.reverse.map {|e| JSON.parse(e.message)['message'].
                             try {|e| e['params']}.
                             try {|e| e['request']}.
                             try {|e| e['headers']} }.
              compact
  token = headers.flat_map(&:to_a).find {|a,b| a[/api-key/i]}.last
end

TagsToDisable = [
  'Attach error', # your console doesn't work, lol
  # 'Connection closed w/o response', #critical h13, wtf you can do about it
  'Exit timeout', # do not care, as long as it's dead. Sorry about your cleanup logic. What's really affected are some client requests though.
  'Memory quota exceeded', # do not care, let's watch over client-related metrics
  'No web processes running', # :(
  # 'Request Interrupted', # same as h13, I wonder what you gonna do about it
]

BugMeRarely = {
  "actions" => [
    {
      "enabled" => true,
      "min_matches_count" => 100,
      "min_matches_period" => "15Minute",
      # "min_report_count" => 100,
      # "min_report_period" => "Day",
    } ] }
TagsToUpdate = {
  'High Response Time'  => BugMeRarely.merge({"patterns" => [ "service>20000" ]}) ,
  'Request timeout'     => BugMeRarely,
  'Request Interrupted' => BugMeRarely,
  'Connection closed w/o response' => BugMeRarely,
}



app_names.each do |app_name|
  puts "Processing #{app_name}. Step #1 - getting API Token"
  api_token = extract_api_key b, app_name

  puts "Step #2 - Updating Alert settings of Tags with token #{api_token}"

  ts = JSON.parse RestClient.get 'https://rest.logentries.com/management/tags',
    {'x-api-key' => api_token}

  ts['tags'].select {|e| e['name'].in? TagsToDisable}.
    map! {|e| e['actions'][0]['enabled'] = false; e}.
    each {|e|
      puts "Disabling #{e['name']} alert."
      RestClient.put "https://rest.logentries.com/management/tags/#{e['id']}",
        {tag: e}.to_json,
        {'x-api-key' => api_token,
         'content-type' => 'json'}}

  ts['tags'].select {|e| e['name'].in? TagsToUpdate}.
    map {|e| e.merge('patterns' => (TagsToUpdate[e['name']]['patterns'] || e['patterns'])).
               merge('actions'  => [e['actions'].first.
                                    deep_merge(TagsToUpdate[e['name']]['actions'].first)])}.
    each {|e|
      puts "Updating #{e['name']} alert."
      RestClient.put "https://rest.logentries.com/management/tags/#{e['id']}",
        {tag: e}.to_json,
        {'x-api-key' => api_token,
         'content-type' => 'json'}}
end
