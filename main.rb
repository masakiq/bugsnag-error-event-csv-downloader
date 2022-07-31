require 'bugsnag/api'
require 'csv'
require 'pry'

client = Bugsnag::Api::Client.new(auth_token: ENV['BUGSNAG_PERSONAL_AUTH_TOKEN'])

organizations = client.organizations
organization_id = organizations.first.id
projects = client.projects(organization_id)

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

puts 'Input Bugsnag error id.'
print '> '
error_id = gets.chomp
if error_id.empty?
  puts 'No error id inputed.'
  exit 1
end
puts "Selected error id: #{error_id}"
puts

base_time = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')

events = []
begin
  events.concat(client.error_events(selected_project.id, error_id, per_page: 100, base: base_time, full_reports: true))
rescue Bugsnag::Api::NotFound
  puts 'Error id not found in Bugsnag.'
  exit 1
end
until client.last_response.rels[:next].nil?
  base_time = client.last_response.data.last.received_at.strftime('%Y-%m-%dT%H:%M:%SZ')
  events.concat(client.error_events(selected_project.id, error_id, per_page: 100, base: base_time, full_reports: true))
end
events.uniq!(&:id)

def event_title
  [
    'event.id',
    'event.received_at',
    'event.severity',
    'exception.errorClass',
    'exception.message',
    'exception.type',
    'event.request.url',
    'event.request.clientIp',
    'event.request.httpMethod',
    'event.request.referer',
    'X-Amzn-Trace-Id',
    'headers.to_h',
    'params.to_h',
    'user_id',
    'media',
    'event.app.releaseStage',
    'event.app.type',
    'event.app.version',
    'event.user.to_h',
    'event.device.to_h',
    'event.metaData.to_h',
    'event.breadcrumbs.to_h',
    'event.url'
  ]
end

def event_row(event)
  exception = event.exceptions.first
  headers = event.request.headers
  params = event.request.params
  [
    event.id,
    event.received_at,
    event.severity,
    exception.errorClass,
    exception.message,
    exception.type,
    # exception.stacktrace.to_h,
    event.request.url,
    event.request.clientIp,
    event.request.httpMethod,
    event.request.referer,
    headers&.key?('X-Amzn-Trace-Id') ? headers['X-Amzn-Trace-Id'] : '',
    headers&.to_h,
    params&.to_h,
    params&.key?('user_id') ? headers['user_id'] : '',
    params&.key?('media') ? headers['media'] : '',
    event.app.releaseStage,
    event.app.type,
    event.app.version,
    event.user&.to_h,
    event.device&.to_h,
    event.metaData&.to_h,
    event.breadcrumbs&.to_h,
    event.url
  ]
end

def generate_csv(events)
  CSV.generate do |csv|
    csv << event_title
    events.each do |event|
      csv << event_row(event)
    end
  end
end

result = generate_csv(events)
File.write('tmp/result.csv', result)
