json.meta do
  json.mine_count @conversations_count[:mine_count]
  json.leads_count @conversations_count[:leads_count]
  json.assigned_count @conversations_count[:assigned_count]
  json.unassigned_count @conversations_count[:unassigned_count]
  json.all_count @conversations_count[:all_count]
end
