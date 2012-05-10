Oats.info "Running #{Oats.test.name}"
total = Oats.data['count']
interval = Oats.data['interval']
total.times do |i|
  Oats.info "Count is #{i}"
  sleep interval
end