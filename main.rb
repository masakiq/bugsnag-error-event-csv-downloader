require 'bugsnag/api'
require 'csv'
require 'pry'
require './csv_map'

client = Bugsnag::Api::Client.new(auth_token: ENV['BUGSNAG_PERSONAL_AUTH_TOKEN'])

## select organization
organizations = client.organizations
organization_slugs = organizations.map(&:slug)
puts 'Select organization'
selected_organization_slug = `echo #{organization_slugs.join ' '} | tr " " "\n" | fzf`.chomp
if selected_organization_slug.empty?
  puts 'No organization selected.'
  exit 1
end
selected_organization = organizations.find do |organization|
  organization.slug == selected_organization_slug
end
puts "Selected organization: #{selected_organization.name}"
puts

## select project
projects = client.projects(selected_organization.id)
project_slugs = projects.map(&:slug)
puts 'Select project'
selected_project_slug = `echo #{project_slugs.join ' '} | tr " " "\n" | fzf`.chomp
if selected_project_slug.empty?
  puts 'No project selected.'
  exit 1
end
selected_project = projects.find do |project|
  project.slug == selected_project_slug
end
puts "Selected project: #{selected_project.name}"
puts

## input Bugsnag error id
puts 'Input Bugsnag error id.'
print '> '
error_id = gets.chomp
if error_id.empty?
  puts 'No error id inputed.'
  exit 1
end
puts "Selected error id: #{error_id}"
puts

## get error events
start_time = Time.now
events = []
begin
  # Bugsnag API document --- List the Events on an Error
  # https://bugsnagapiv2.docs.apiary.io/#reference/errors/events/list-the-events-on-an-error
  base_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
  error_events = client.error_events(
    selected_project.id,
    error_id,
    base: base_time,
    full_reports: true
  )
  events.concat(error_events)
rescue Bugsnag::Api::NotFound
  puts 'Error id not found in Bugsnag.'
  exit 1
end
until client.last_response.rels[:next].nil?
  begin
    base_time = client.last_response.data.last.received_at.strftime('%Y-%m-%dT%H:%M:%SZ')
    error_events = client.error_events(
      selected_project.id,
      error_id,
      base: base_time,
      full_reports: true
    )
    events.concat(error_events)
    events.uniq!(&:id)
    puts "Currently #{events.size} events in progress..."
  rescue Bugsnag::Api::RateLimitExceeded => e
    # Bugsnag API document --- Rate Limiting
    # https://bugsnagapiv2.docs.apiary.io/#introduction/rate-limiting
    retry_after = e.instance_variable_get(:@response).response_headers['retry-after'].to_i
    puts "RateLimitExceeded Retry-After: #{retry_after} seconds"
    sleep retry_after
  end
end
end_time = Time.now
puts "Time elapsed: #{end_time - start_time} seconds"
puts

## generate CSV from events
csv = CSV.generate do |rows|
  headers = CSV_MAP.map { |m| m[:header] }
  rows << headers
  events.each do |event|
    value_paths = CSV_MAP.map { |m| m[:value_path] }
    row = value_paths.map do |value_path|
      eval(value_path, binding, __FILE__, __LINE__) # rubocop:disable Security/Eval
    end
    rows << row
  end
end

File.write('tmp/result.csv', csv)
puts 'Generated CSV file: tmp/result.csv'
