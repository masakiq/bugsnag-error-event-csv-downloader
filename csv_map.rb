# frozen_string_literal: true

CSV_MAP = [
  {
    header: 'event_id',
    value_path: 'event.id'
  },
  {
    header: 'received_at',
    value_path: 'event.received_at'
  },
  {
    header: 'severity',
    value_path: 'event.severity'
  },
  {
    header: 'errorClass',
    value_path: 'event.exceptions.first.errorClass'
  },
  {
    header: 'message',
    value_path: 'event.exceptions.first.message'
  },
  {
    header: 'event_exceptions_first_type',
    value_path: 'event.exceptions.first.type'
  },
  # {
  #   header: 'stacktrace',
  #   value_path: 'event.exceptions.first.stacktrace.to_h'
  # },
  {
    header: 'event_request_url',
    value_path: 'event.request.url'
  },
  {
    header: 'clientIp',
    value_path: 'event.request.clientIp'
  },
  {
    header: 'httpMethod',
    value_path: 'event.request.httpMethod'
  },
  {
    header: 'referer',
    value_path: 'event.request.referer'
  },
  {
    header: 'X-Amzn-Trace-Id',
    value_path: 'event.request.headers&.dig("X-Amzn-Trace-Id") || ""'
  },
  {
    header: 'headers',
    value_path: 'event.request.headers&.to_h'
  },
  {
    header: 'params',
    value_path: 'event.request.params&.to_h'
  },
  {
    header: 'headers_user_id',
    value_path: 'event.request.headers&.dig("user_id") || ""'
  },
  {
    header: 'params_user_id',
    value_path: 'event.request.params&.dig("user_id") || ""'
  },
  {
    header: 'headers_media',
    value_path: 'event.request.headers&.dig("media") || ""'
  },
  {
    header: 'params_media',
    value_path: 'event.request.params&.dig("media") || ""'
  },
  {
    header: 'releaseStage',
    value_path: 'event.app.releaseStage'
  },
  {
    header: 'event_app_type',
    value_path: 'event.app.type'
  },
  {
    header: 'version',
    value_path: 'event.app.version'
  },
  {
    header: 'user',
    value_path: 'event&.user&.to_h'
  },
  {
    header: 'device',
    value_path: 'event&.device&.to_h'
  },
  {
    header: 'metaData',
    value_path: 'event&.metaData&.to_h'
  },
  {
    header: 'breadcrumbs',
    value_path: 'event&.breadcrumbs&.map { |b| b&.to_h }'
  },
  {
    header: 'event_url',
    value_path: 'event.url'
  }
].freeze
