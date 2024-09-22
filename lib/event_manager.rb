require 'csv'
require 'google/apis/civicinfo_v2'
require 'erb'
require 'time'
require 'date'
require 'pry-byebug'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5,"0")[0..4]
end

def legislators_by_zipcode(zip)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zip,
      levels: 'country',
      roles: ['legislatorUpperBody', 'legislatorLowerBody']
    ).officials
  rescue
    'You can find your representatives by visiting www.commoncause.org/take-action/find-elected-officials'
  end
end

def save_thank_you_letter(id, template)
  Dir.mkdir('output') unless Dir.exist?('output')

  filename = "output/thanks_#{id}.html"

  File.open(filename,'w') do |file|
    file.puts template
  end
end

def check_phone_number(number)
  number = number.gsub(/\D/,'')
  if number[0] == 1 || number.to_s.length == 10
    number = number.split(//).last(10).join("").to_s
  else
    "wrong number"
  end
end

def save_phone_number(id, template)
  Dir.mkdir('output_phone') unless Dir.exist?('output_phone')
  filename = "output_phone/phone_#{id}.txt"

  File.open(filename,'w') do |file|
    file.puts template
  end
end

def convert_date_into_hour_and_day(csv_file)
   array_output = Array.new(2) {Array.new}

  csv_file.each_with_index do |row,idc|
    time_registered = row[:regdate].split(" ")[1]
    time_registered = Time.parse(time_registered).strftime("%k").to_s
    dow_init = row[:regdate].split(" ")[0]
    dow = Date.strptime(dow_init,"%m/%d/%Y").strftime('%A')
    # binding.pry
  
    array_output.first << time_registered
    array_output.last <<  dow
  end
  array_output
end


def group_registered_by_unit(hours_array)
  hours_array.reduce(Hash.new(0)) do |accum, instance|
    accum[instance] += 1
    accum
  end
  .sort_by {|time| time[1]}.reverse! 
end

def output_message_times(array_times)
  puts "\nBreakout registrations by time of the day:"
  array_times.each_with_index do |hour, idx|
    puts "Between #{hour[0].to_i}-#{hour[0].to_i+1}, #{hour[1]} people registered  "
  end
end

def output_message_days(array_days)
  puts "\nThe days with most people registering were:"
  array_days.each_with_index do |days, idx|
    puts "#{idx+1}.- #{days[0]} with #{days[2]} registrations."
  end
end


puts 'EventManager initialized.'

contents = CSV.open('event_attendees.csv', headers: true, header_converters: :symbol)

#calculate dow registered & time registered
day_and_time_array = convert_date_into_hour_and_day(contents)
group_day_of_week = group_registered_by_unit(day_and_time_array[1])[0..2]
instances_time = group_registered_by_unit(day_and_time_array[0])[0..2]

template_letter = File.read('form_letter.erb')
erb_template = ERB.new template_letter

template_number = File.read('phone_numbers.erb')
erb_phone = ERB.new template_number

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  phone_number = check_phone_number(row[:homephone])

  zipcode = clean_zipcode(row[:zipcode])

  legislators = legislators_by_zipcode(zipcode)

  form_letter = erb_template.result(binding)
  form_number = erb_phone.result(binding)

  save_thank_you_letter(id, form_letter)
  save_phone_number(id, form_number)
end

puts 'calculating times and dates'
output_message_times(instances_time)
output_message_days(group_day_of_week)