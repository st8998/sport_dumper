require 'minitest/autorun'
require './dumper'

class TestDumper < Minitest::Test

  def setup
    @list_html = File.read('./test_response.html')
    @ex_html = File.read('./test_response_ex.html')
  end

  def test_get_page
    skip
    html = get_page

    assert_instance_of String, html
    assert_equal @list_html, html
  end

  def test_parse_list
    data = parse_list(@list_html)

    assert_equal 15, data.size

    item = data.first
    assert_equal 'http://www.bodybuilding.com/exercises/exerciseImages/sequences/2001/Male/t/2001_1.jpg', item[:male_thumbs][0]
    assert_equal 'http://www.bodybuilding.com/exercises/exerciseImages/sequences/2001/Male/t/2001_2.jpg', item[:male_thumbs][1]
    assert_equal 'http://www.bodybuilding.com/exercises/exerciseImages/sequences/2001/Male/t/2001_1.jpg', item[:female_thumbs][0]
    assert_equal 'http://www.bodybuilding.com/exercises/exerciseImages/sequences/2001/Male/t/2001_2.jpg', item[:female_thumbs][1]
  end

  def test_get_all_pages
    skip
    list = exercise_list

    assert_equal 871, list.size
  end

  def test_parse_ex_page
    data = parse_ex_page(@ex_html)

    assert_equal 'alternating_floor_press', data[:code]
    assert_equal '#chest', data[:main_muscle]
    assert_equal '#abdominals,#shoulders,#triceps', data[:other_muscle]
    assert_equal '#kettlebells', data[:equipment]
    assert_equal '#compound', data[:mechanics_type]
    assert_equal '#push', data[:force]
    assert_equal '#beginner', data[:level]

    assert_equal 'Lie on the floor with two kettlebells next to your shoulders.', data[:description][0]
    assert_equal 4, data[:description].size

    assert_equal 'http://www.bodybuilding.com/exercises/exerciseImages/sequences/534/Male/l/534_1.jpg', data[:male_images][0]
    assert_equal 3, data[:male_images].size

    assert_equal 'http://www.bodybuilding.com/exercises/exerciseImages/sequences/534/Female/l/534_1.jpg', data[:female_images][0]
    assert_equal 3, data[:female_images].size
  end

end