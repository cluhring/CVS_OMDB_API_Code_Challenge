require File.expand_path('../support/test_helper', __dir__)

require 'minitest/autorun'

class ApiTest < Minitest::Test
	include RequestHelper

	def test_no_api_key
		request('GET', '?', {params: {'apikey' => '', 't' => 'Space Jam'}}, 'http://www.omdbapi.com/')
		assert_equal(401, last_response.status, 
			msg = 'FAIL: 401 HTTP Response not received: Unauthorized. The request requires user authentication')
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
	def test_api_key_name_equals_thomas
		request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 't' => 'Thomas'}},
			'http://www.omdbapi.com/')

  	#A: Verify all titles are a relevant match
  	assert_equal('Thomas', JSON.parse(last_response.payload).fetch('Title'), 
  		msg = 'FAIL: OMDb API search by "Title" = "Thomas" does not return a movie named Thomas')
  	
  	#B: Verify keys include Title, Year, imdbID, Type, and Poster for all records in the response
  	expectedKeys = ["Title", "Year", "imdbID", "Type", "Poster"]
  	key_array = JSON.parse(last_response.payload).keys
  	expectedKeys.each {|x| 
  		assert(key_array.include?(x), "FAIL: Response does not include expected Key: " + x)
  	}

   	#C: Verify values are all of the correct object class
   	key_array.each {|x| 
   		if x == "Ratings"
   			assert_equal(Array, JSON.parse(last_response.payload).fetch(x).class,
   				'FAIL: Incorrect Value Class found for Key: ' + x)
   		elsif x == "Year"
   			assert_equal(String, JSON.parse(last_response.payload).fetch(x).class,
   				'FAIL: Incorrect Value Class found for Key: ' + x)
   		#D: Verify year matches correct format
   		assert(JSON.parse(last_response.payload).fetch(x).match('[\d{4}]'), 'FAIL: Year is not 4 Numbers')
   	else 
   		assert_equal(String, JSON.parse(last_response.payload).fetch(x).class,
   			'FAIL: Incorrect Value Class found for Key: ' + x)
   	end
   	}
 	end

  #4: Add a test that uses the i parameter to verify each title on page 1 is accessible via imdbID
  def test_api_key_name_equals_thomas											#Parks and Rec
  	request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 'i' => 'tt1266020', 'Season' => '1'}},
  		'http://www.omdbapi.com/')
  	# find imdb# & Title of each Season 1 Parks & Rec episode - save in array as hash
  	episode_array = JSON.parse(last_response.payload).fetch('Episodes')
  	imdbID_title_array = episode_array.map{|x| {x.fetch('imdbID') => x.fetch('Title')}}
  	imdbID_title_array.each {|idtitlehash| 
  		# search for episode by imdb
  		request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 'i' => idtitlehash.keys[0]}},
  			'http://www.omdbapi.com/')
  		# confirm titles matches
  		assert_equal(idtitlehash.values[0], JSON.parse(last_response.payload).fetch("Title"),
  			"FAIL: imdbID search not finding expected Title")
  	}
  end

  #5: Add a test that verifies none of the poster links on page 1 are broken
  def test_star_wars_poster_links
		# search for 'star' movies - page 1
		request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 's' => 'star', 'page' => 1}},
			'http://www.omdbapi.com/')
		movie_array = JSON.parse(last_response.payload).fetch('Search')
		# save poster urls into array
		poster_array = movie_array.map {|star_movie| star_movie.fetch('Poster') }
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
  		page_results = JSON.parse(last_response.payload).fetch('Search')
  	}
  	# should be fifty - get 50 imdb #s
  	fifty_movies = all_results.flatten.count
  	all_imdbs = all_results.flatten.map {|star_movie|
  		star_movie.fetch('imdbID')
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
  			page_one_series = JSON.parse(last_response.payload).fetch("Search")
  		# find out how man series have been made for each cartoon (was seeing 11 Mickey Mouse series)
  		total_series = JSON.parse(last_response.payload).fetch("totalResults")
  		# calculate how many pages the series will take (1-10 = 1, 11-20 = 2)
  		tens = total_series.to_i / 10
  		remainder = (total_series.to_i % 10 > 0) ? 1 : 0
  		total_pages = tens + remainder
  		# get all imdb#s for each cartoon series
  		if total_pages < 2
  			cartoon_series_imdbIDs = page_one_series.map {|series|
  				series.fetch("imdbID")
  			}
  		else
  			cartoon_series_imdbIDs = page_one_series.map {|series|
  				series.fetch("imdbID")
  			}
  			request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 's' => cartoon,
  				'type' => 'series', 'page' => '2'}},'http://www.omdbapi.com/')
  			page_two_series = JSON.parse(last_response.payload).fetch("Search")
  			page_two_series.map {|series|
  				cartoon_series_imdbIDs << series.fetch("imdbID")
  			}
  		end
  		# find number of seasons for each cartoon - fetch episode count for each season - add season episodes
  		cartoon_series_imdbIDs.map{|imdb|
  			request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 'i' => imdb}},
  				'http://www.omdbapi.com/')
  			totalSeasons = JSON.parse(last_response.payload).fetch("totalSeasons").to_i
  			total_episodes_per_series = 0
  			# map through seasons - saving episode count for each season
  			(1..totalSeasons).map{|season_num|
  				request('GET', '?', {params: {'apikey' => ENV['OMDBKEY'], 'i' => imdb, 
  					'season' => season_num}},'http://www.omdbapi.com/')
  				episodes_per_season = JSON.parse(last_response.payload).fetch("Episodes").count
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