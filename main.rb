# frozen_string_literal: true

require 'bugsnag/api'
require 'csv'
require 'json'
require 'jsonpath'
begin
  require 'pry'
rescue LoadError
  # do nothing
end

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

## check exists tmp/csv_map.json
csv_map = {}
begin
  csv_map_file = File.read('tmp/csv_map.json')
  csv_map = JSON.parse(csv_map_file)
rescue Errno::ENOENT
  puts 'tmp/csv_map.json not found.'
rescue JSON::ParserError
  puts 'tmp/csv_map.json is not valid JSON.'
end

## generate tmp/csv_map.json
if csv_map.empty?
  puts 'Do you want to generate a CSV map file?'
  print 'If yes, enter "y" > '
  yes_or_no = gets.chomp
  if yes_or_no != 'y'
    puts 'Abort CSV map generation.'
    exit
  end

  puts
  puts 'Do you want to include "stacktrace" to a CSV map file?'
  print 'If yes, enter "y" > '
  need_stacktrace = gets.chomp == 'yes'

  puts
  puts 'Do you want to include "breadcrumbs" to a CSV map file?'
  print 'If yes, enter "y" > '
  need_breadcrumbs = gets.chomp == 'yes'

  begin
    # Bugsnag API document --- List the Events on an Error
    # https://bugsnagapiv2.docs.apiary.io/#reference/errors/events/list-the-events-on-an-error
    events = client.error_events(
      selected_project.id,
      error_id,
      per_page: 30,
      full_reports: true
    )
    all_paths = []
    events.each do |event|
      json = JSON.parse(event.to_h.to_json)
      all_path = JsonPath.fetch_all_path(json)
      all_paths.concat(all_path)
    end
    all_paths.uniq!

    # size = all_paths.size
    # all_paths.reject!.with_index do |all_path, i|
    #   next_index = i + 1
    #   next if next_index == size

    #   next_all_path = all_paths[next_index]
    #   next_all_path.start_with?(all_path)
    # end

    # all_paths.reject!.with_index do |all_path, i|
    #   previouse_index = i - 1
    #   next if previouse_index.negative?

    #   previouse_all_path = all_paths[previouse_index]
    #   previouse_all_path.start_with?(all_path)
    # end

    unless need_stacktrace
      all_paths.reject! do |all_path|
        all_path.include?('stacktrace')
      end
    end

    unless need_breadcrumbs
      all_paths.reject! do |all_path|
        all_path.include?('breadcrumbs')
      end
    end

    csv_map = all_paths[1..].map { |path| { header: path, path: path } }
    csv_map_file = File.new('tmp/tmp_csv_map.json', 'w')
    csv_map_file.puts(csv_map.to_json)
    csv_map_file.close
    system('cat tmp/tmp_csv_map.json | jq > tmp/csv_map.json')
    system('rm tmp/tmp_csv_map.json')

    puts 'Generated tmp/csv_map.json. Please edit it.'
    exit
  rescue Bugsnag::Api::NotFound
    puts 'Error id not found in Bugsnag.'
    exit 1
  end
end

## get error events
start_time = Time.now
events = []
begin
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
    puts "Currently #{events.size} events downloaded, in progress..."
  rescue Bugsnag::Api::RateLimitExceeded => e
    # Bugsnag API document --- Rate Limiting
    # https://bugsnagapiv2.docs.apiary.io/#introduction/rate-limiting
    retry_after = e.instance_variable_get(:@response).response_headers['retry-after'].to_i
    puts "RateLimitExceeded Retry-After: #{retry_after} seconds"
    sleep retry_after
  end
end
puts "Downloaded #{events.size} events, in #{Time.now - start_time} seconds."
puts

## generate CSV from events
csv = CSV.generate do |rows|
  headers = csv_map.map { |m| m['header'] }
  rows << headers
  events.each do |event|
    paths = csv_map.map { |m| m['path'] }
    row = paths.map do |path|
      json_path = JsonPath.new(path)
      json = event.to_h.to_json
      json_path.on(json).join(',')
    end
    rows << row
  end
end

File.write('tmp/result.csv', csv)
puts 'Generated CSV file: tmp/result.csv'
