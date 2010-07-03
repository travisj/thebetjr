#!/usr/bin/ruby

require 'json'
require 'net/http'
require 'grit'

class TheBet
	attr_reader :dir

	def initialize(options)
		@dir = options['dir'] || './'
		@url = 'http://espn.go.com/mlb/standings/_/year/2010/seasontype/2'
		@scores = Hash.new
		@specifics = Hash.new
		@date = DateTime::now.strftime("%Y-%m-%d")

		load_json_configs
		get_current_standings
		write_files
		send_to_git
	end

	private 

	def load_json_configs
		@teams = JSON.parse(IO.read(@dir + '/_json/teams.json'))
		@picks = JSON.parse(IO.read(@dir + '/_json/picks.json'))
		@players = JSON.parse(IO.read(@dir + '/_json/players.json'))
		@history = JSON.parse(IO.read(@dir + '/_json/history.json'))

		@players.each do |key, value|
			@scores[key] = 0
		end
	end

	def get_current_standings
		resp = Net::HTTP.get_response(URI.parse(@url))
		resp.body.scan(/<a href="http:\/\/espn.go.com\/mlb\/team\/_\/name\/(.*?)\/(.*?)">(.*?)<\/a><\/td><td>(.*?)<\/td><td>(.*?)<\/td>/) do |match|
			owner = @picks[match[0]]['owner'] if !@picks[match[0]].nil?
			if owner
				choice = @picks[match[0]]['choice'] == 'l' ? 4 : 3
				@scores[owner] += Integer(match[choice])
				@specifics[match[0]] = Integer(match[choice])
			end
		end
	end

	def write_files
		@history[@date] = Hash.new
		page = "---\nlayout: post\n"
		@scores.each do |owner, score|
			@history[@date][owner] = score
			page += owner + ': ' + score.to_s + "\n"
		end
		@specifics.each do |team, score|
			page += "#{team}: #{score}\n"
		end
		page += "---\n"

		File.open(@dir + '/_posts/' + @date + '-Results.markdown', 'w') {|f| f.write(page)}
		File.open(@dir + '/_json/history.json', 'w') {|f| f.write(@history.to_json)}
	end

	def send_to_git
		g = Grit::Repo.new(@dir)
		g.add('.')
		g.commit_index('commit')
		cmd = "push origin gh-pages"
		g.repo.git.run('', cmd, '', {}, "")
	end
end



if __FILE__ == $0
	require 'optparse'
	options = Hash.new
	optparse = OptionParser.new do|opts|
		opts.on("-d", "--dir=[ARG]", "pages directory") do |opt|
			options['dir'] = opt
		end
	end
	optparse.parse!(ARGV)
	thebet = TheBet.new(options)
end
