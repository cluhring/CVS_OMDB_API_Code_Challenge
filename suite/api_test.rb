require File.expand_path('../support/test_helper', __dir__)

require 'minitest/autorun'

class ApiTest < Minitest::Test
include RequestHelper

	def test_no_api_key
		request('GET', '?', {params: {'apikey' => '', 't' => 'Space Jam'}}, 'http://www.omdbapi.com/')
		#byebug
		assert_includes((400..499), last_response.status,
			msg = "FAIL: Expected HTTP Response not received: Unauthorized. Found: #{last_response.status}")
	end

  #2: Add an assertion to test_no_api_key to ensure the response at runtime matches what is 
  #   currently displayed with the api key missing
  def test_api_key_yes
  	request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 't' => 'Space Jam'}},
  		'http://www.omdbapi.com/')
  	assert_equal(200, last_response.status, 
  		msg = 'FAIL: 200 HTTP Response not received: Successful Response')
  end

 		#3: Extend api_test.rb by creating a test that performs a search on 'thomas'.
	def test_imdb_search_thomas_results
		request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 's' => 'thomas'}},
			'http://www.omdbapi.com/')

  	#A: Verify all titles are a relevant match
  	thomas_key_array = []
  	thomas_results = JSON.parse(last_response.payload).dig('Search')
  	thomas_results.each {|tom_result|
  		tom_title = tom_result.dig('Title')
  		assert_includes(tom_title.upcase, 'THOMAS', "OMDB api search for thomas did not find title w/ THOMAS")
  		thomas_key_array << tom_result.keys
  	}
  	
  	#B: Verify keys include Title, Year, imdbID, Type, and Poster for all records in the response
  	expected_keys = ["Title", "Year", "imdbID", "Type", "Poster"]

  	thomas_key_array.each {|thomas_result_keys| 
  		assert_equal(expected_keys, thomas_result_keys, "FAIL: Response does not include expected Keys")
  	}

   	#C: Verify values are all of the correct object class
   	thomas_results.each { |tom_result|
			expected_keys.each { |key| 
  			assert_equal(String, tom_result.dig(key).class,
  			 "Incorrect Value Class found for Key: #{key} in Result: #{tom_result.dig('Title')}")
  			 #D: Verify year matches correct format
  			if key == "Year" 
  				assert(tom_result.dig(key).match('[\d{4}]'), 'FAIL: Year is not 4 Numbers')
  			end
  		}
  	}
 	end

  #4: Add a test that uses the i parameter to verify each title on page 1 is accessible via imdbID
  def test_imdb_id_search									#Parks and Rec
  	request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 'i' => 'tt1266020', 'Season' => '1'}},
  		'http://www.omdbapi.com/')
  	# find imdb# & Title of each Season 1 Parks & Rec episode - save in array as hash
  	episode_array = JSON.parse(last_response.payload).dig('Episodes')
  	imdbID_title_array = episode_array.map{|x| {x.dig('imdbID') => x.dig('Title')}}
  	imdbID_title_array.each {|idtitlehash| 
  		# search for episode by imdb
  		request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 'i' => idtitlehash.keys[0]}},
  			'http://www.omdbapi.com/')
  		# confirm titles matches
  		assert_equal(idtitlehash.values[0], JSON.parse(last_response.payload).dig("Title"),
  			"FAIL: imdbID search not finding expected Title")
  	}
  end

 #  #5: Add a test that verifies none of the poster links on page 1 are broken
  def test_star_wars_poster_links
		# search for 'star' movies - page 1
		request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 's' => 'star', 'page' => 1}},
			'http://www.omdbapi.com/')
		movie_array = JSON.parse(last_response.payload).dig('Search')
		# save poster urls into array
		poster_array = movie_array.map {|star_movie| star_movie.dig('Poster') }
		# verify urls return 200 HTTP response
		poster_array.each {|star_poster| 
			response = Net::HTTP.get_response(URI.parse(star_poster)).code
			assert_equal('200', response, 'FAIL: broken url found: ' + star_poster)
		}
	end

  #6: Add a test that verifies there are no duplicate records across the first 5 pages
  def test_duplicate_records
  	pages = [1,2,3,4,5]
  	# create array of hashes w/ 5 pages of star results
  	all_results = pages.map {|pg| 
  		request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 's' => 'star', 'page' => pg}},
  			'http://www.omdbapi.com/')
  		page_results = JSON.parse(last_response.payload).dig('Search')
  	}
  	# should be fifty - get 50 imdb #s
  	fifty_movies = all_results.flatten.count
  	all_imdbs = all_results.flatten.map {|star_movie|
  		star_movie.dig('imdbID')
  	}
  	# delete duplicate values - count
  	fifty_imdbs = all_imdbs.uniq.count
  	# collect all duplicate imdbs found
  	duplicates = all_imdbs.find_all {|x| all_imdbs.count(x) > 1 }
  	# confirm original 50 results = count after deleted duplicates
  	# note which imdbs were duplicates if assertion fails
  	assert_equal(fifty_movies, fifty_imdbs, 
  		'FAIL: Duplicates found in 5 Pages of Star Search Records: ' + duplicates.to_s)
  end

  #7: Add a test that verifies something you are curious about with regard to movies or data in the database.
  #Some Seasons didn't have any Episodes: "Mickey Mouse", "Teenage Mutant Ninja Turtles", "Spider-Man", "Alvin and the Chipmunks",
  def test_longest_running_cartoons
  	cartoons = ["Looney Tunes", "Scooby-Doo", "The Simpsons", "South Park",
  		"My Little Pony", "The Smurfs", "Thomas the Tank Engine", 
  		"The Flintstones", "Tom and Jerry", "Curious George", "Daniel Tiger's Neighborhood", 
  		"Dora the Explorer", "PJ Masks"]
  	cartoon_data_array = []
  	cartoons.each {|cartoon|
  		total_episodes_per_cartoon = 0
  		request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 's' => cartoon, "type" => "series"}},
  			'http://www.omdbapi.com/')
  		page_one_series = JSON.parse(last_response.payload).dig("Search")
  		# find out how man series have been made for each cartoon (was seeing 11 Mickey Mouse series)
  		total_series = JSON.parse(last_response.payload).dig("totalResults")
  		# calculate how many pages the series will take (1-10 = 1, 11-20 = 2)
  		tens = total_series.to_i / 10
  		remainder = (total_series.to_i % 10 > 0) ? 1 : 0
  		total_pages = tens + remainder
  		# get all imdb#s for each cartoon series
  		if total_pages < 2
  			cartoon_series_imdbIDs = page_one_series.map {|series|
  				series.dig("imdbID")
  			}
  		else
  			cartoon_series_imdbIDs = page_one_series.map {|series|
  				series.dig("imdbID")
  			}
  			request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 's' => cartoon,
  				'type' => 'series', 'page' => '2'}},'http://www.omdbapi.com/')
  			page_two_series = JSON.parse(last_response.payload).dig("Search")
  			page_two_series.map {|series|
  				cartoon_series_imdbIDs << series.dig("imdbID")
  			}
  		end
  		# find number of seasons for each cartoon - fetch/dig episode count for each season - add season episodes
  		cartoon_series_imdbIDs.map{|imdb|
  			request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 'i' => imdb}},
  				'http://www.omdbapi.com/')
  			totalSeasons = JSON.parse(last_response.payload).dig("totalSeasons").to_i
  			total_episodes_per_series = 0
  			# map through seasons - saving episode count for each season
  			(1..totalSeasons).map{|season_num|
  				request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 'i' => imdb, 
  					'season' => season_num}},'http://www.omdbapi.com/')
  				episodes_per_season = JSON.parse(last_response.payload).dig("Episodes").count
						# add all season episodes per series
						total_episodes_per_series += episodes_per_season
					}
  			# add up all episodes
  			total_episodes_per_cartoon += total_episodes_per_series
  		}
  		#save episode count
  		cartoon_data_array << [cartoon, total_episodes_per_cartoon]
  	}
  	#reverse sort
  	ranked_cartoons = cartoon_data_array.sort_by{|k,v| -v}
  	assert_equal('The Simpsons', ranked_cartoons[0][0], "FAIL: The Simpsons was overtaken by " + ranked_cartoons[0][0])
  end	
end