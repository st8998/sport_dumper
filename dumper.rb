# encoding: utf-8

require 'nokogiri'
require 'faraday'
require 'json'
require 'csv'
require 'open-uri'
require 'fileutils'

require 'active_support/all'

conn = Faraday.new(:url => 'http://www.bodybuilding.com') do |faraday|
  faraday.request :url_encoded # form-encode POST params
  faraday.response :logger # log requests to STDOUT
  faraday.adapter Faraday.default_adapter # make requests with Net::HTTP
end
#

# 0..59 pages by 15 in each

define_method :get_page do |page = 0|
  all = conn.post('/exercises/ajax/getfinderdata',
      params: 'muscleID=13,3,18,5,17,4,15,6,9,7,1,12,2,11,14,10,8;exerciseTypeID=2,6,4,7,1,3,5;equipmentID=9,14,2,10,5,6,4,15,1,8,11,3,7;mechanicTypeID=1,2,11;force=Push,Pull,Static,N/A;sport=Yes,No;levelID=1,3,2',
      orderByField: 'exerciseName',
      orderByDirection: 'ASC',
      page: page)

  JSON.parse(all.body)['htmlCode']
end

define_method :parse_list do |html|
  out = []

  dom = Nokogiri::HTML(html)

  dom.css('.altExerciseLight, .altExercise').each do |ex|
    out << {
        male_thumbs: [ex.css('#Male a:first-child img').first['src'], ex.css('#Male a:last-child img').first['src']],
        female_thumbs: [ex.css('#Female a:first-child img').first['src'], ex.css('#Female a:last-child img').first['src']],
        url: ex.css('#Male a:first-child').first['href']
    }
  end

  out
end

define_method :exercise_list do
  exercises = []

  (0..59).each do |page|
    exercises += parse_list(get_page(page*15))
  end

  exercises
end

define_method :get_ex_page do |url|
  conn.get(url).body
end

def n attr
  attr.strip.downcase.gsub(' ', '_').gsub('/', '-')
end

def tag attr
  '#'+n(attr)
end

def extract_many fragment
  Nokogiri::HTML(fragment).css('a').map(&:content).map(&method(:tag)).join(',').presence || ''
end

def extract_one fragment
  tag Nokogiri::HTML(fragment).css('a').first.content.presence || ''
end

define_method :parse_ex_page do |html|
  dom = Nokogiri::HTML(html)

  out = {
      code: n(dom.css('#exerciseDetails h1').first.text),
      name: dom.css('#exerciseDetails h1').first.text
  }

  fragments = dom.css('#exerciseDetails p')[-1].to_html.split('<br>')

  fragment = proc do |pat|
    fragments.find do |fr|
      fr =~ /#{pat}/
    end
  end

  out[:type] = extract_one(fragment['Type'])
  out[:main_muscle] = extract_many(fragment['Main Muscle'])
  out[:other_muscle] = extract_many(fragment['Other Muscles'])
  out[:equipment] = extract_many(fragment['Equipment'])
  out[:mechanics_type] = extract_many(fragment['Mechanics Type'])
  out[:level] = extract_many(fragment['Level'])
  out[:force] = extract_many(fragment['Force'])

  out[:description] = dom.css('.guideContent ol li').map(&:text).map(&:strip)

  out[:male_images] = dom.css('#Male .thickbox').map { |n| n['href'] }
  out[:female_images] = dom.css('#Female .thickbox').map { |n| n['href'] }

  out[:guide_image] = dom.css('.guideImage img').first['src']

  out
end

define_method :dump_image do |url, name|
  filename = "out/images/#{name}"

  unless File.exist?(filename)
    open(url) do |f|
      File.open(filename, 'wb') { |file| file.puts(f.read) }
    end
  end
end

define_method :dump_description do |lines, name|
  File.open("out/#{name}", 'w') do |file|
    file.puts '<ol>'
    lines.each { |line| file.puts("<li>#{line}</li>") }
    file.puts '</ol>'
  end
end

define_method :dump_exercises do |limit|
  FileUtils.mkdir_p('out/images')

  CSV.open('out/exercises.csv', 'w') do |csv|
    csv << ['номер', 'код', 'Название', 'Основные мышцы', 'Синергисты', 'Тип оборудования', 'Тип движения', 'Тип усилия', 'Сложность', 'Картинки (м)', 'Картинги (ж)', 'Мини (м)', 'Мини (ж)', 'Описание', 'Ссылка на страничку']

    list = parse_list(get_page)
    i = 0

    list.each do |ex|
      if i < limit
        data = parse_ex_page(get_ex_page(ex[:url]))

        next if data[:type] != '#strength'

        data[:male_images] = ['']+data[:male_images] if data[:male_images].size > 0
        data[:female_images] = ['']+data[:female_images] if data[:female_images].size > 0

        csv << [
            i+1,
            data[:code],
            data[:name].strip,
            data[:main_muscle],
            data[:other_muscle],
            data[:equipment],
            data[:mechanics_type],
            data[:force],
            data[:level],


            data[:male_images].map.with_index do |url, i|
              if i == 0
                "#{data[:main_muscle][1..-1]}.gif".tap { |name| dump_image(data[:guide_image], name) }
              else
                "#{data[:code]}_pic_male_#{i}.jpg".tap { |name| dump_image(url, name) }
              end
            end.join(','),

            data[:female_images].map.with_index do |url, i|
              if i == 0
                "#{data[:main_muscle][1..-1]}.gif".tap { |name| dump_image(data[:guide_image], name) }
              else
                "#{data[:code]}_pic_male_#{i}.jpg".tap { |name| dump_image(url, name) }
              end
            end.join(','),

            ex[:male_thumbs].map.with_index do |url, i|
              "#{data[:code]}_pic_small_male_#{i+1}.jpg".tap { |name| dump_image(url, name) }
            end.join(','),

            ex[:female_thumbs].map.with_index do |url, i|
              "#{data[:code]}_pic_small_female_#{i+1}.jpg".tap { |name| dump_image(url, name) }
            end.join(','),

            "#{data[:code]}_en.html".tap { |name| dump_description(data[:description], name) },

            ex[:url]
        ]

        i += 1
      end
    end
  end
end


dump_exercises(15)


# var link = document.createElement('a');
# var file = $('.BBCOMVideoEmbed embed').attr('flashvars').match(/http.*mp4/)[0];
# link.href = file;
# link.download = file.match(/\w+\.mp4$/)[0];
# document.body.appendChild(link);
# link.click()
