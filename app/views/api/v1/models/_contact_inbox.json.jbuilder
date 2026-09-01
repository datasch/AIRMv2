json.source_id PhoneMaskerService.can_view_full_phone? ? resource.source_id : PhoneMaskerService.mask_if_phone(resource.source_id)
json.inbox do
  json.partial! 'api/v1/models/inbox_slim', formats: [:json], resource: resource.inbox
end
