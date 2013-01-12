require 'open-uri'
require 'rubygems'
require 'json'

class UserHistory

	@username
	@comments
	@max_comment_pages_to_scan
	@comment_pages_scanned
	@markov_phraseology_lookup
	@subreddits
	@debug
	
	attr_accessor :username, :comment_pages_scanned, :max_comment_pages_to_scan, :debug

	def initialize(username, maxpages=50, debug=false)
		@username = username
		@max_comment_pages_to_scan = maxpages
		@comment_pages_scanned = 0
		@debug = debug
		@comments = {}
	end

	# :cache_only only retrieves previously cached comments (no network traffic)
	# :cache_first returns cached values if available, otherwise builds cache from reddit
	# :cache_update updates cache with new comments from reddit (loads comments from reddit until it finds one it already has cached)
	# :cache_full_refresh updates cache the same as :cache_update, but also refreshes already-cached comments from reddit's API (eg, in case they've changed in any way)
	# :cache_wipe clears the entire cache (DANGER WILL ROBINSON!) for the user, and rebuilds it from scratch from reddit's API
	def comments(cache=:cache_first)
		return @comments unless (@comments.empty? || [:cache_update, :cache_full_refresh, :cache_wipe].include?(cache))

		json = nil
		after = ''

		cachefilename = "cache/#{@username}.cached_comments"
		
		if cache != :cache_wipe
			if File.exist? cachefilename
				File.open(cachefilename, "rb") { |f| @comments = Marshal.load(f) }
			end
		end

		if cache == :cache_only || (cache == :cache_first && !@comments.empty?)
			return @comments
		end

		while after && ((@max_comment_pages_to_scan == 0) || (@comment_pages_scanned < @max_comment_pages_to_scan)) do
			url = "http://www.reddit.com/user/#{@username}/comments/.json?after=#{after}"
			sleep 2 # Be a responsible bot and strictly limit requests to reddit to at most 1 every 2 seconds, as per the API guidelines
			puts "Fetching page #{@comment_pages_scanned}\t#{url}" if @debug
			open(url) do |page|
				if page.status[0].to_i != 200
					puts "Couldn't retrieve page #{@comment_pages_scanned}\t#{url} (status: #{page.status[0].to_i})!"
					after = nil
				else
					@comment_pages_scanned += 1
					json = JSON.parse(page.read)
					if json.has_key?('data') && json['data'].has_key?('after')
						after = json['data']['after']
					else
						puts "No 'after' on page #{@comment_pages_scanned}" if @debug
						after = ""
					end
					if json.has_key?('data') && json['data'].has_key?('children')
						new_comments = json['data']['children'].map { |comment| comment['data'] }
						new_comments.each do |comment|
							if cache == :cache_update && @comments.has_key?(comment['id'])
								after = nil
								break
							else
								@comments[comment['id']] = comment
							end
						end
					else
						puts "Error: No 'data' or 'children' on page #{@comment_pages_scanned}:"
						ap json
					end
				end
			end
		end

		if @comments.length > 0 # Don't bother to write cache file unless we actually have something to put in it
			File.open(cachefilename, "wb") { |f| Marshal.dump(@comments, f) }
		end

		@comments
	end

	def comment_stats
		words = 0

		self.comments.each do |id, comment|
			words += comment['body'].split(/[\s\[\]]+/).length
		end

		{
			:comments => @comments.length,
			:words => words
		}
	end

	def markov_phraseology_lookup
		return @markov_phraseology_lookup unless @markov_phraseology_lookup.nil?

		@markov_phraseology_lookup = {}

		self.comments.each do |id, comment|

			prevword = "<start>"
			comment['body'].split(/[\s\[\]]+/).each do |word|
				word = word[/[a-zA-Z0-9].*/] || word	# Strip non-alphanum chars from front of string
				word = word[/.*[a-zA-Z0-9]/] || word	# Strip non-alphanum chars from end of string
				if word
					if !@markov_phraseology_lookup.has_key?(prevword)
						@markov_phraseology_lookup[prevword] = {}
					end
					if !@markov_phraseology_lookup[prevword].has_key?(word)
						@markov_phraseology_lookup[prevword][word] = 1
					else
						@markov_phraseology_lookup[prevword][word] += 1
					end
					prevword = word
				end
			end
		end
		@markov_phraseology_lookup
	end

	def subreddits
		return @subreddits unless @subreddits.nil?

		@subreddits = {}

		self.comments.each { |id, comment| @subreddits[comment['subreddit']] = (@subreddits.has_key?(comment['subreddit']) ? @subreddits[comment['subreddit']]+1 : 1 ) }

		@subreddits
	end

	def votes
		return { :up => @total_ups, :down => @total_downs } unless (@total_ups.nil? || @total_downs.nil?)

		@total_ups = @total_downs = 0

		self.comments.each do |id, comment|
			@total_ups += comment['ups']
			@total_downs += comment['downs']
		end

		{ :up => @total_ups, :down => @total_downs }
	end
end