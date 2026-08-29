puts "Accounts: #{Account.count}"
puts "Inboxes: #{Inbox.count}"
Channel::Api.find_each do |c|
  puts "Channel::Api id: #{c.id}, account: #{c.account_id}, webhook_url: #{c.webhook_url}"
end
