require 'ap'

require './user-history'





def compare_markov_lookups(table1, table2)
	puts "#{ARGV[0]}: #{table1.keys.length} words (case-sensitive)"
	puts "#{ARGV[1]}: #{table2.keys.length} words (case-sensitive)"

	# Remove words not used by both users, so we can do a like:like comparison on phraseology (trying to cut down on the small sample-set problem where it's easy for two accounts to use different words even if they're the same person)
	#table1.keep_if { |key, value| table2.has_key?(key) }
	#table2.keep_if { |key, value| table1.has_key?(key) }
end

def compare_common_subreddits(user1, user2)
	#common_subs = (user1.subreddits.keys.keep_if { |sub_name| user2.subreddits.has_key?(sub_name) }).sort
	common_subs = (user1.subreddits.keys+user2.subreddits.keys).uniq.sort

	#puts "Subreddits: #{user1.username}:#{user1.subreddits.length}, #{user2.username}:#{user2.subreddits.length}"

	#puts "Common subreddits: #{common_subs}"

	puts "Subreddit name      #{user1.username[0..18]}"+(" "*(20-user1.username[0..18].length))+"#{user2.username[0..18]}"

	highest_value = (user1.subreddits.values+user2.subreddits.values).max

	common_subs.each do |sub_name|

		#puts sub_name

		s = sub_name[0..20]
		s += (" "*(20-s.length))

		significant = 0

		[user1, user2].each do |user|
			user.subreddits

			comments_in_sub = user.subreddits[sub_name]

			sub_fraction = comments_in_sub.to_f/highest_value.to_f

			if (sub_fraction*10.0).round(0) >= 1
				significant += 1
			end

			graphline = "|" + ("#"*(sub_fraction*10.0).round(0))	#+" "+sub_fraction.round(3).to_s
			padding = (" "*(20-graphline.length))

			s += graphline+padding
		end

		if significant > 0
			puts s
		end
	end
end

if ARGV[0]

	user1 = UserHistory.new(ARGV[0], ARGV[1].to_i)

	user1.comments()
	puts "Username: #{user1.username}"
	puts "Comments: #{user1.comments.length}"
	puts "Unique words: #{user1.markov_phraseology_lookup.length}"
	total_words = user1.comments.values.map { |comment| comment['body'].split(/[\s\[\]]+/).length }.reduce(:+)
	puts "Total words: #{total_words}"
	puts "Net karma: #{user1.votes[:up]-user1.votes[:down]}"
	subreddits_by_frequency = user1.subreddits.sort { |a, b| b[1] <=> a[1] }.map { |sub| "#{sub[0]} (#{sub[1]})" }
	puts "Posts in subreddits: #{subreddits_by_frequency.join(', ')}"

else
	puts "Usage: #{__FILE__} username1 [max_comment_pages]"
end